import os
import hashlib
import re
import shutil
from datetime import datetime
from .ModManager import ModManager
from .ProfileService import ProfileService
from .DownloadService import DownloadService

class ModService:
    @staticmethod
    def get_profile_mods_path(profile_id):
        return ModManager.get_profile_mods_path(profile_id)

    @staticmethod
    def generate_mod_id(filename):
        return hashlib.md5(filename.encode()).hexdigest()[:8]

    @staticmethod
    def extract_mod_name(filename):
        name = os.path.splitext(filename)[0]
        # Remove version numbers roughly
        name = re.sub(r'-v?\d+\.[\d\.]+.*$', '', name, flags=re.IGNORECASE)
        name = re.sub(r'-\d+\.[\d\.]+.*$', '', name, flags=re.IGNORECASE)
        name = name.replace('-', ' ').replace('_', ' ')
        return name.title() or 'Unknown Mod'

    @staticmethod
    def extract_version(filename):
        match = re.search(r'v?(\d+\.[\d\.]+)', filename)
        return match.group(1) if match else None

    @classmethod
    def load_installed_mods(cls, profile_id):
        try:
            # 1. Get current profile config
            profile = ProfileService.get_profiles().get(profile_id)
            if not profile:
                return []

            config_mods = profile.get('mods', [])
            
            profile_mods_path = cls.get_profile_mods_path(profile_id)
            profile_disabled_mods_path = os.path.join(os.path.dirname(profile_mods_path), 'DisabledMods')

            if not os.path.exists(profile_mods_path):
                os.makedirs(profile_mods_path, exist_ok=True)
            if not os.path.exists(profile_disabled_mods_path):
                os.makedirs(profile_disabled_mods_path, exist_ok=True)

            final_mods = []
            processed_file_names = set()

            # 2. Scan disk for current state
            def is_mod_file(f):
                return f.endswith('.jar') or f.endswith('.zip')

            enabled_files = [f for f in os.listdir(profile_mods_path) if is_mod_file(f)]
            disabled_files = [f for f in os.listdir(profile_disabled_mods_path) if is_mod_file(f)]

            all_files = []
            for f in enabled_files:
                all_files.append({"fileName": f, "enabled": True, "path": os.path.join(profile_mods_path, f)})
            for f in disabled_files:
                all_files.append({"fileName": f, "enabled": False, "path": os.path.join(profile_disabled_mods_path, f)})

            # 3. Process existing config mods
            for mod_config in config_mods:
                file_name = mod_config.get('fileName')
                file_on_disk = next((f for f in all_files if f['fileName'] == file_name), None)
                
                if file_on_disk:
                    # Found on disk - update status and path, keep metadata
                    mod_entry = mod_config.copy()
                    mod_entry.update({
                        "enabled": file_on_disk['enabled'],
                        "filePath": file_on_disk['path'],
                        "missing": False
                    })
                    final_mods.append(mod_entry)
                    processed_file_names.add(file_name)
                else:
                    # Not found on disk -> Missing
                    mod_entry = mod_config.copy()
                    mod_entry.update({
                        "filePath": None,
                        "missing": True
                    })
                    final_mods.append(mod_entry)
                    processed_file_names.add(file_name)

            # 4. Add new files found on disk that weren't in config
            for file_info in all_files:
                if file_info['fileName'] not in processed_file_names:
                    final_mods.append({
                        "id": cls.generate_mod_id(file_info['fileName']),
                        "fileName": file_info['fileName'],
                        "name": cls.extract_mod_name(file_info['fileName']),
                        "version": cls.extract_version(file_info['fileName']),
                        "enabled": file_info['enabled'],
                        "filePath": file_info['path'],
                        "description": 'Locally installed mod',
                        "author": 'Unknown',
                        "dateInstalled": datetime.utcnow().isoformat() + "Z",
                        "missing": False,
                        "manual": True 
                    })

            return final_mods
        except Exception as error:
            print(f'Failed to load mods: {error}')
            return []

    @classmethod
    def get_mod_details(cls, mod_id):
        from .CurseForgeService import CurseForgeService
        try:
            return CurseForgeService.get_mod(mod_id)
        except Exception as e:
            print(f"Failed to get mod details for {mod_id}: {e}")
            return None

    @classmethod
    def toggle_mod(cls, profile_id, file_name, enable):
        try:
            profile_mods_path = cls.get_profile_mods_path(profile_id)
            profile_disabled_mods_path = os.path.join(os.path.dirname(profile_mods_path), 'DisabledMods')

            source_path = os.path.join(profile_disabled_mods_path if enable else profile_mods_path, file_name)
            dest_path = os.path.join(profile_mods_path if enable else profile_disabled_mods_path, file_name)

            # 1. Move file
            if os.path.exists(source_path):
                dest_dir = os.path.dirname(dest_path)
                if not os.path.exists(dest_dir):
                    os.makedirs(dest_dir, exist_ok=True)
                shutil.move(source_path, dest_path)
            elif os.path.exists(dest_path):
                # Already in target location
                pass
            else:
                return False # File not found anywhere

            # 2. Update Config
            profile = ProfileService.get_profiles().get(profile_id)
            if profile:
                mods = cls.load_installed_mods(profile_id) # Reload to get fresh state
                
                # Find the mod and force update its enabled state
                mod_found = False
                for mod in mods:
                    if mod['fileName'] == file_name:
                        mod['enabled'] = enable
                        mod_found = True
                        break
                
                if mod_found:
                    ProfileService.update_profile(profile_id, {"mods": mods})
            
            # 3. Sync Symlink
            ModManager.sync_mods_for_profile(profile_id)

            return True
        except Exception as error:
            print(f'Toggle mod failed: {error}')
            return False

    @classmethod
    def download_mod(cls, profile_id, url, file_name, mod_info=None):
        try:
            profile_mods_path = cls.get_profile_mods_path(profile_id)
            dest_path = os.path.join(profile_mods_path, file_name)

            DownloadService.download_file(url, dest_path)

            # Update profile
            profile = ProfileService.get_profiles().get(profile_id)
            if profile:
                new_mod = {
                    "id": mod_info.get('id') if mod_info else cls.generate_mod_id(file_name),
                    "fileName": file_name,
                    "name": mod_info.get('name') if mod_info else cls.extract_mod_name(file_name),
                    "version": mod_info.get('version') if mod_info else cls.extract_version(file_name),
                    "description": mod_info.get('description', 'Downloaded Mod'),
                    "author": mod_info.get('author', 'Unknown'),
                    "curseForgeId": mod_info.get('curseForgeId') if mod_info else None,
                    "curseForgeFileId": mod_info.get('curseForgeFileId') if mod_info else None,
                    "dateInstalled": datetime.utcnow().isoformat() + "Z",
                    "enabled": True,
                    "missing": False
                }

                current_mods = profile.get('mods', [])
                # Remove existing entry for this filename
                other_mods = [m for m in current_mods if m.get('fileName') != file_name]
                other_mods.append(new_mod)
                
                ProfileService.update_profile(profile_id, {"mods": other_mods})

            # Sync Symlink
            ModManager.sync_mods_for_profile(profile_id)

            return {"success": True, "path": dest_path}
        except Exception as e:
            print(f'Download mod failed: {e}')
            return {"success": False, "error": str(e)}

    @classmethod
    def uninstall_mod(cls, profile_id, file_name):
        try:
            profile_mods_path = cls.get_profile_mods_path(profile_id)
            profile_disabled_mods_path = os.path.join(os.path.dirname(profile_mods_path), 'DisabledMods')
            
            paths_to_check = [
                os.path.join(profile_mods_path, file_name),
                os.path.join(profile_disabled_mods_path, file_name)
            ]
            
            deleted = False
            for p in paths_to_check:
                if os.path.exists(p):
                    os.remove(p)
                    deleted = True
            
            if deleted:
                # Update config
                profile = ProfileService.get_profiles().get(profile_id)
                if profile:
                    current_mods = profile.get('mods', [])
                    new_mods = [m for m in current_mods if m.get('fileName') != file_name]
                    ProfileService.update_profile(profile_id, {"mods": new_mods})
                
                ModManager.sync_mods_for_profile(profile_id)
                return True
            
            return False
        except Exception as e:
            print(f"Uninstall failed: {e}")
            return False



