import os
import json
import shutil
import threading
import time
from datetime import datetime
from typing import Dict, List, Optional, Callable
from ..utils.paths import get_user_data_dir
from .LoggerService import LoggerService

class SkinMonitorService:
    """
    Simplified Skin Monitor Service.
    
    Responsibilities:
    1. Pre-launch: Prepare game environment (Skins + Config) to ensure last used skin is loaded.
    2. Runtime: Monitor for skin changes and back them up to repository.
    """
    
    SKIN_CACHE_DIRS = ['CachedAvatarPreviews', 'CachedPlayerSkins']
    MONITOR_INTERVAL = 2.0
    
    _instance = None
    _lock = threading.Lock()
    
    def __init__(self):
        self.is_monitoring = False
        self.monitor_thread: Optional[threading.Thread] = None
        self.game_user_data_dir: Optional[str] = None
        self.repo_dir = self.get_skins_repository_dir()
        self.current_user_uuid: Optional[str] = None
        self.current_player_name: Optional[str] = None
        
        # Cache for change detection
        self.file_timestamps: Dict[str, float] = {}

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    @staticmethod
    def get_skins_repository_dir() -> str:
        repo_dir = os.path.join(get_user_data_dir(), 'skins_repository')
        os.makedirs(repo_dir, exist_ok=True)
        return repo_dir

    def _load_metadata(self) -> Dict:
        meta_path = os.path.join(self.repo_dir, "skins_metadata.json")
        if os.path.exists(meta_path):
            try:
                with open(meta_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception:
                return {}
        return {}

    def _save_metadata(self, metadata: Dict) -> None:
        meta_path = os.path.join(self.repo_dir, "skins_metadata.json")
        with open(meta_path, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)

    def prepare_skin_for_launch(self, game_user_data_dir: str, player_uuid: str, player_name: str) -> None:
        """
        CRITICAL: Called synchronously before game launch.
        Ensures the game loads the correct skin by:
        1. Finding the last active skin from the repository.
        2. Copying it to the game's cache directory with the expected filename.
        3. Updating config.json to map the player to this UUID.
        """
        self.game_user_data_dir = game_user_data_dir
        self.current_user_uuid = player_uuid
        self.current_player_name = player_name
        
        LoggerService.info(f"[SkinMonitor] Preparing skin for user: {player_name} ({player_uuid})")

        # 1. Update Config.json (User Mapping)
        self._ensure_user_config_mapping(game_user_data_dir, player_uuid, player_name)

        # 2. Restore Skin
        # We try to find the skin for this user, OR the last session skin if none specific found
        metadata = self._load_metadata()
        last_skin_filename = self._find_best_skin_to_restore(metadata, player_uuid)
        
        if last_skin_filename:
            self._inject_skin_into_game(game_user_data_dir, last_skin_filename, player_uuid)
        else:
            LoggerService.info("[SkinMonitor] No previous skin found to restore.")

    def _ensure_user_config_mapping(self, user_data_dir: str, uuid: str, name: str):
        """Forces config.json to map name -> uuid"""
        config_path = os.path.join(user_data_dir, "config.json")
        try:
            data = {}
            if os.path.exists(config_path):
                try:
                    with open(config_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                except:
                    data = {}
            
            if "userUuids" not in data:
                data["userUuids"] = {}
            
            # Update mapping
            data["userUuids"][name] = uuid
            
            # Also ensure this UUID is active
            data["lastUserUuid"] = uuid
            
            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            LoggerService.info(f"[SkinMonitor] Updated config.json mapping: {name} -> {uuid}")
        except Exception as e:
            LoggerService.error(f"[SkinMonitor] Failed to update config.json: {e}")

    def _find_best_skin_to_restore(self, metadata: Dict, target_uuid: str) -> Optional[str]:
        """
        Decide which skin file to restore.
        Priority:
        1. Skin last used by this specific UUID.
        2. Skin from 'last_session_uuid' (global).
        3. Most recently modified file in repository.
        """
        # Strategy: Look at CachedPlayerSkins category in metadata
        skins_meta = metadata.get("CachedPlayerSkins", {})
        
        # 1. Try to find by last_user_uuid
        for filename, info in skins_meta.items():
            if info.get("last_user_uuid") == target_uuid:
                return filename

        # 2. Try global last session
        last_session_uuid = metadata.get("last_session_uuid")
        if last_session_uuid:
             for filename, info in skins_meta.items():
                if info.get("last_user_uuid") == last_session_uuid:
                    return filename
        
        # 3. Fallback: Newest file in repo
        repo_skins_dir = os.path.join(self.repo_dir, "CachedPlayerSkins")
        if os.path.exists(repo_skins_dir):
            files = [f for f in os.listdir(repo_skins_dir) if os.path.isfile(os.path.join(repo_skins_dir, f))]
            if not files:
                return None
            # Sort by modification time desc
            files.sort(key=lambda x: os.path.getmtime(os.path.join(repo_skins_dir, x)), reverse=True)
            return files[0]
            
        return None

    def _inject_skin_into_game(self, game_user_data_dir: str, source_filename: str, target_uuid: str):
        """
        Copies the source skin from repo to game dir.
        IMPORTANT: Renames/Copies it to match the target UUID if needed.
        """
        src_path = os.path.join(self.repo_dir, "CachedPlayerSkins", source_filename)
        if not os.path.exists(src_path):
            return

        target_dir = os.path.join(game_user_data_dir, "CachedPlayerSkins")
        os.makedirs(target_dir, exist_ok=True)

        # We copy it as the original filename AND as the UUID.png to cover all bases
        # Some versions use hash, some use UUID.
        
        # 1. Copy as original filename (if it was a hash)
        dest_original = os.path.join(target_dir, source_filename)
        shutil.copy2(src_path, dest_original)
        
        # 2. Copy as <UUID>.png (Standard convention for many launchers/clients)
        dest_uuid = os.path.join(target_dir, f"{target_uuid}.png")
        shutil.copy2(src_path, dest_uuid)
        
        # 3. Also copy to CachedAvatarPreviews just in case
        preview_dir = os.path.join(game_user_data_dir, "CachedAvatarPreviews")
        os.makedirs(preview_dir, exist_ok=True)
        shutil.copy2(src_path, os.path.join(preview_dir, f"{target_uuid}.png"))

        LoggerService.info(f"[SkinMonitor] Restored skin {source_filename} as {target_uuid}.png")

    def start_backup_monitor(self, game_user_data_dir: str):
        """Starts the background thread to watch for changes"""
        if self.is_monitoring:
            return
        
        self.game_user_data_dir = game_user_data_dir
        self.is_monitoring = True
        
        # Initialize timestamps
        self._scan_initial_state()
        
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True, name="SkinBackupWorker")
        self.monitor_thread.start()
        LoggerService.info("[SkinMonitor] Backup monitor started.")

    def force_backup(self):
        """Force a backup check immediately"""
        self._check_and_backup()

    def stop_monitoring(self):
        self.is_monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2.0)

    def _scan_initial_state(self):
        if not self.game_user_data_dir:
            return
        for category in self.SKIN_CACHE_DIRS:
            path = os.path.join(self.game_user_data_dir, category)
            if os.path.exists(path):
                for f in os.listdir(path):
                    fp = os.path.join(path, f)
                    if os.path.isfile(fp):
                        self.file_timestamps[fp] = os.path.getmtime(fp)

    def _monitor_loop(self):
        while self.is_monitoring:
            try:
                self._check_and_backup()
                time.sleep(self.MONITOR_INTERVAL)
            except Exception as e:
                LoggerService.error(f"[SkinMonitor] Error in monitor loop: {e}")
                time.sleep(5.0)

    def _check_and_backup(self):
        if not self.game_user_data_dir:
            return

        for category in self.SKIN_CACHE_DIRS:
            dir_path = os.path.join(self.game_user_data_dir, category)
            if not os.path.exists(dir_path):
                continue
                
            current_files = set()
            for filename in os.listdir(dir_path):
                file_path = os.path.join(dir_path, filename)
                if not os.path.isfile(file_path):
                    continue
                
                current_files.add(file_path)
                mtime = os.path.getmtime(file_path)
                
                # Check if new or modified
                if file_path not in self.file_timestamps or mtime != self.file_timestamps[file_path]:
                    self.file_timestamps[file_path] = mtime
                    self._backup_file(file_path, category, filename)
            
            # Clean up cache for deleted files
            # (Optional, but keeps memory clean)
            for cached_path in list(self.file_timestamps.keys()):
                if cached_path.startswith(dir_path) and cached_path not in current_files:
                    del self.file_timestamps[cached_path]

    def _backup_file(self, src_path: str, category: str, filename: str):
        """Backs up the file to the repo and updates metadata"""
        try:
            repo_cat_dir = os.path.join(self.repo_dir, category)
            os.makedirs(repo_cat_dir, exist_ok=True)
            dest_path = os.path.join(repo_cat_dir, filename)
            
            shutil.copy2(src_path, dest_path)
            
            # Update Metadata
            metadata = self._load_metadata()
            
            # Update Last Session Info
            if self.current_user_uuid:
                metadata["last_session_uuid"] = self.current_user_uuid
            if self.current_player_name:
                metadata["last_session_player_name"] = self.current_player_name
            metadata["last_session_at"] = datetime.now().isoformat()
            
            # Update File Info
            if category not in metadata:
                metadata[category] = {}
            
            metadata[category][filename] = {
                "last_updated": datetime.now().isoformat(),
                "last_user_uuid": self.current_user_uuid,
                "last_player_name": self.current_player_name
            }
            
            self._save_metadata(metadata)
            LoggerService.info(f"[SkinMonitor] Backed up new skin: {filename}")
            
        except Exception as e:
            LoggerService.error(f"[SkinMonitor] Backup failed for {filename}: {e}")

    # Compatibility methods (to avoid breaking other imports immediately if any)
    def set_lock_state(self, locked: bool):
        pass # No longer used
    
    def restore_all_skins_from_repo(self):
        pass # Replaced by prepare_skin_for_launch

    def set_session_user(self, uuid, name):
        self.current_user_uuid = uuid
        self.current_player_name = name
