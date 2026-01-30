import os
import time
import json
import psutil
import subprocess
import shutil
import threading
import stat
from datetime import datetime
from ..utils.paths import get_app_dir, get_resolved_app_dir, get_user_data_dir
from ..utils.platform import is_windows, is_linux, setup_wayland_environment, setup_gpu_environment
from .InstallationDetectionService import InstallationDetectionService
from .VersionService import VersionService
from .DownloadService import DownloadService
from .ExtractionService import ExtractionService
from .ButlerService import ButlerService
from .JavaService import JavaService
from .ProfileService import ProfileService
from .LoggerService import LoggerService
from .PatcherService import PatcherService
from .SkinMonitorService import SkinMonitorService
from .ConfigService import ConfigService
from .JWTService import JWTService

class GameService:
    install_progress = {
        "percent": 0,
        "message": "",
        "status": "idle" # idle | installing | completed | error
    }
    
    _game_start_time = None
    _backend_process = None # To keep track if we spawned it

    @classmethod
    def get_game_start_time(cls):
        return cls._game_start_time

    @classmethod
    def set_progress_state(cls, percent, message, status):
        cls.install_progress = {
            "percent": percent,
            "message": message,
            "status": status
        }

    @classmethod
    def resolve_paths(cls):
        app_dir = get_resolved_app_dir()
        default_app_dir = get_app_dir()
        return {
            "appDir": app_dir,
            "cacheDir": os.path.join(default_app_dir, 'cache'),
            "toolsDir": os.path.join(default_app_dir, 'butler'),
            "gameDir": os.path.join(app_dir, 'install', 'release', 'package', 'game', 'latest'),
            "jreDir": os.path.join(app_dir, 'install', 'release', 'package', 'jre', 'latest')
        }

    @classmethod
    def is_game_running(cls):
        process_names = ['HytaleClient.exe', 'HytaleClient']
        
        # Check running processes
        try:
            for proc in psutil.process_iter(['name']):
                try:
                    if proc.info['name'] in process_names:
                        return True
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass
        except:
            pass
        
        # If not found, clear start time
        cls._game_start_time = None
        return False

    @classmethod
    def get_game_status(cls):
        paths = cls.resolve_paths()
        game_dir = paths["gameDir"]
        
        try:
            version_info = VersionService.get_version_info()
            
            # Support both old and new JSON structure
            latest_version = "7.pwr"
            if version_info:
                if "latest_release_id" in version_info:
                    latest_version = f"{version_info['latest_release_id']}.pwr"
                elif "client_version" in version_info:
                    latest_version = version_info["client_version"]
                    
            latest_timestamp = None
            if version_info:
                latest_timestamp = version_info.get("last_updated") or version_info.get("timestamp")
            
            display_version = VersionService.get_formatted_version_name()
            formatted_version = f"Game Version: {display_version}"

            detailed_status = InstallationDetectionService.get_detailed_game_status(game_dir)
            
            installed_version = detailed_status.get("installedVersion")
            update_available = VersionService.is_update_available(installed_version, latest_version)
            
            return {
                "installed": detailed_status.get("installed", False),
                "fullyExtracted": detailed_status.get("fullyExtracted", False),
                "corrupted": detailed_status.get("corrupted", False),
                "clientPath": detailed_status.get("clientPath"),
                "clientSize": detailed_status.get("clientSize", 0),
                "reasons": detailed_status.get("issues", []),
                "gameDir": game_dir,
                "latestVersion": latest_version,
                "latestVersionTimestamp": latest_timestamp,
                "formattedVersion": formatted_version,
                "installedVersion": installed_version,
                "updateAvailable": update_available,
                "details": detailed_status.get("details", {})
            }
        except Exception as e:
            print(f"Error getting game status: {e}")
            return {
                "installed": False,
                "reasons": [str(e)],
                "latestVersion": "0.1.0-release"
            }

    @classmethod
    def install_game(cls, version=None):
        try:
            cls.set_progress_state(0, "Initializing installation...", "installing")
            
            if not version:
                version = VersionService.get_latest_version()
                
            paths = cls.resolve_paths()
            game_dir = paths["gameDir"]
            cache_dir = paths["cacheDir"]
            tools_dir = paths["toolsDir"]
            
            # Ensure Java is ready
            try:
                cls.set_progress_state(5, "Ensuring Java runtime...", "installing")
                JavaService.download_jre()
            except Exception as e:
                print(f"[GameService] Failed to ensure Java during install: {e}")
                
            # Download Patch
            pwr_file = cls._download_patch(version, cache_dir)
            
            # Apply Patch
            cls._apply_patch(pwr_file, game_dir, tools_dir, skip_if_installed=True)
            
            # Save metadata
            cls._save_version_metadata(game_dir, version)
            
            cls.set_progress_state(100, "Installation complete!", "completed")
            return {"success": True, "message": "Installation successful"}
            
        except Exception as e:
            print(f"Installation failed: {e}")
            cls.set_progress_state(0, f"Error: {str(e)}", "error")
            raise e

    @classmethod
    def update_game(cls, version=None):
        return cls.install_game(version) # Logic is same for now, overwrite

    @classmethod
    def repair_game(cls, version=None):
        try:
            cls.set_progress_state(0, "Initializing repair...", "installing")
            
            if not version:
                version = VersionService.get_latest_version()
                
            paths = cls.resolve_paths()
            game_dir = paths["gameDir"]
            cache_dir = paths["cacheDir"]
            tools_dir = paths["toolsDir"]
            
            if os.path.exists(game_dir):
                try:
                    shutil.rmtree(game_dir, ignore_errors=True)
                except Exception as e:
                    print(f"[GameService] Failed to cleanup game dir for repair: {e}")
                    pass
            
            # Ensure Java is ready
            try:
                cls.set_progress_state(5, "Ensuring Java runtime...", "installing")
                JavaService.download_jre()
            except Exception as e:
                print(f"[GameService] Failed to ensure Java during repair: {e}")

            pwr_file = cls._download_patch(version, cache_dir)
            
            cls._apply_patch(pwr_file, game_dir, tools_dir, skip_if_installed=False)
                
            cls._save_version_metadata(game_dir, version)
            
            cls.set_progress_state(100, "Repair complete!", "completed")
            return {"success": True, "message": "Repair successful"}
        except Exception as e:
            print(f"Repair failed: {e}")
            cls.set_progress_state(0, f"Error: {str(e)}", "error")
            raise e
    
    @classmethod
    def uninstall_game(cls):
        paths = cls.resolve_paths()
        game_dir = paths["gameDir"]
        
        if os.path.exists(game_dir):
            shutil.rmtree(game_dir, ignore_errors=True)
            return True
        return False

    @classmethod
    def _download_patch(cls, version, cache_dir):
        if not os.path.exists(cache_dir):
            os.makedirs(cache_dir, exist_ok=True)

        url = VersionService.get_patch_url(version)
        last_updated = VersionService.get_last_updated()
        # Use naming convention: temp_${last_updated}.pwr
        file_name = f"temp_{last_updated}.pwr"
        dest_path = os.path.join(cache_dir, file_name)
        temp_path = f"{dest_path}.tmp"

        existing_pwr = None
        try:
            pwr_files = []
            for file in os.listdir(cache_dir):
                if file.endswith('.pwr'):
                    pwr_files.append(os.path.join(cache_dir, file))
            if dest_path in pwr_files:
                pwr_files.remove(dest_path)
                pwr_files.insert(0, dest_path)
            else:
                pwr_files.sort(key=lambda p: os.path.getmtime(p), reverse=True)

            for pwr_path in pwr_files:
                try:
                    ExtractionService.validate_pwr_file(pwr_path)
                    existing_pwr = pwr_path
                    break
                except Exception:
                    try:
                        os.remove(pwr_path)
                    except Exception:
                        pass
        except Exception:
            pass

        if existing_pwr:
            cls.set_progress_state(60, f"Using cached patch: {os.path.basename(existing_pwr)}", "installing")
            return existing_pwr

        cls.set_progress_state(10, f"Downloading patch: {file_name}", "installing")
        
        def on_progress(downloaded, total, percent):
            # Map 0-100% download to 10-60% total progress
            mapped_percent = 10 + (percent * 0.5)
            mb_downloaded = int(downloaded / 1024 / 1024)
            mb_total = int(total / 1024 / 1024)
            cls.set_progress_state(int(mapped_percent), f"Downloading: {mb_downloaded}MB / {mb_total}MB", "installing")

        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass

        DownloadService.download_file(url, dest_path, resumable=False, on_progress=on_progress)

        cls.set_progress_state(60, "Download complete", "installing")

        # Cleanup old temp files
        cls._cleanup_old_patches(file_name, cache_dir)
        DownloadService.cleanup_temp_files(cache_dir)
            
        return dest_path

    @classmethod
    def _cleanup_old_patches(cls, keep_file, cache_dir):
        try:
            for file in os.listdir(cache_dir):
                if file.endswith('.pwr') and file != keep_file:
                    try:
                        os.remove(os.path.join(cache_dir, file))
                    except Exception:
                        pass
        except Exception:
            pass

    @classmethod
    def _apply_patch(cls, pwr_file, target_dir, tools_dir, skip_if_installed=True):
        cls.set_progress_state(60, "Preparing to extract...", "installing")
        
        def on_butler_progress(downloaded, total, percent):
             mb_downloaded = int(downloaded / 1024 / 1024)
             mb_total = int(total / 1024 / 1024)
             cls.set_progress_state(60, f"Downloading extraction tool: {mb_downloaded}MB / {mb_total}MB", "installing")

        butler_path = ButlerService.install_butler(tools_dir, on_progress=on_butler_progress)
        
        def on_extract_progress(message, percent):
            # Map 0-100% extraction to 60-90% total progress
            mapped_percent = 60 + ((percent or 0) * 0.3)
            cls.set_progress_state(int(mapped_percent), message, "installing")

        success = ExtractionService.extract_pwr(
            pwr_file,
            target_dir,
            butler_path,
            on_progress=on_extract_progress,
            skip_if_installed=skip_if_installed
        )
        
        if not success:
            raise Exception("Extraction failed")
            
        cls.set_progress_state(95, "Validating installation...", "installing")
        validation = ExtractionService.validate_extracted_game(target_dir)
        if not validation["valid"]:
            raise Exception(f"Validation failed: {', '.join(validation['issues'])}")

        # Keep the .pwr file for future re-installations/repairs to save bandwidth
        # try:
        #     if os.path.exists(pwr_file):
        #         os.remove(pwr_file)
        # except Exception:
        #     pass

    @classmethod
    def _save_version_metadata(cls, game_dir, version):
        metadata_path = os.path.join(game_dir, 'luyumi_metadata.json')
        try:
            with open(metadata_path, 'w') as f:
                json.dump({"version": version, "installedAt": time.time()}, f)
        except:
            pass

    @classmethod
    def get_latest_log_content(cls):
        try:
            paths = cls.resolve_paths()
            log_dir = os.path.join(paths["appDir"], "logs")
            if not os.path.exists(log_dir):
                return ""
            files = os.listdir(log_dir)
            log_files = [
                f for f in files
                if f.startswith("game-session-") and f.endswith(".log")
            ]
            if not log_files:
                return ""
            log_files.sort(
                key=lambda f: os.path.getmtime(os.path.join(log_dir, f)),
                reverse=True
            )
            latest_log = os.path.join(log_dir, log_files[0])
            with open(latest_log, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            LoggerService.error(f"Error reading game logs: {e}")
            return ""

    @classmethod
    def launch_game_with_fallback(cls, options):
        # Resolve paths
        paths = cls.resolve_paths()
        game_dir = options.get("gameDir") or paths["gameDir"]
        
        # Check java
        java_path = options.get("javaPath")
        if not java_path:
            java_path = JavaService.detect_system_java()
        
        if not java_path:
            # Try bundled/download
            try:
                print("[GameService] System Java not found, ensuring bundled Java...")
                JavaService.download_jre() 
                java_path = JavaService.get_bundled_java_path()
            except Exception as e:
                print(f"[GameService] Failed to download Java: {e}")

        if not java_path or not os.path.exists(java_path):
            raise Exception("Java executable not found. Please install Java 17+.")
            
        # Check game exe
        status = InstallationDetectionService.get_detailed_game_status(game_dir)
        # Allow launch if installed (exe found), even if metadata is missing
        if not status["installed"]:
            raise Exception("Game executable not found. Please install the game first.")
            
        client_path = status["clientPath"]
        client_dir = os.path.dirname(client_path)
        
        # Patch client before launch
        try:
            PatcherService.ensure_client_patched(game_dir)
        except Exception as e:
            # Don't block launch if patching fails but file exists
            LoggerService.warning(f"Failed to patch client: {e}. Attempting launch anyway.")

        # UserData is now stored in the launcher directory, not the game directory
        user_data_dir = get_user_data_dir()
        try:
            os.makedirs(user_data_dir, exist_ok=True)
        except Exception:
            pass

        identity_token = options.get("identityToken", "")
        session_token = options.get("sessionToken", "")

        # --- ENFORCE PERSISTENT UUID (Only if missing) ---
        # We prefer the UUID passed from the frontend (Dart) because the Auth Tokens are signed for it.
        # If we change it here, the tokens become invalid and the game crashes in Online Mode.
        # PlayerService.dart already handles persistence of the UUID.
        
        current_uuid = options.get("uuid")
        if not current_uuid:
             persistent_uuid = ConfigService.get_or_create_client_uuid()
             print(f"[GameService] No UUID provided. Using persistent client UUID: {persistent_uuid}")
             options["uuid"] = persistent_uuid
        else:
             # Trust the provided UUID (it matches the token)
             pass

        # --- PREPARE SKINS & CONFIG (Synchronous) ---
        try:
            current_uuid = options.get("uuid", "")
            current_name = options.get("playerName", "Player")
            
            SkinMonitorService.get_instance().prepare_skin_for_launch(
                user_data_dir, 
                current_uuid, 
                current_name
            )
        except Exception as e:
            LoggerService.error(f"[GameService] Skin preparation failed: {e}")

        # Get Profile Settings (Memory, JVM Args)
        profile = ProfileService.get_active_profile()
        min_mem = "1G"
        max_mem = "4G"
        user_jvm_args = []
        
        if profile and "gameOptions" in profile:
            opts = profile["gameOptions"]
            min_mem = opts.get("minMemory", "1G")
            max_mem = opts.get("maxMemory", "4G")
            user_jvm_args = opts.get("args", [])

        # Build JVM Memory Arguments
        jvm_memory_args = [f"-Xms{min_mem}", f"-Xmx{max_mem}"]
        all_jvm_args = jvm_memory_args + user_jvm_args

        # Construct Game Args
        game_args = ["--app-dir", game_dir]

        if java_path:
            game_args.extend(["--java-exec", java_path])
            
        # Server connection
        server = options.get("server")
        if server:
            game_args.extend(["--connect", server])

        # Determine Auth Mode
        # If tokens are missing or explicit offline request
        if not identity_token or not session_token or options.get("authMode") == "offline":
             print("[GameService] Launching in OFFLINE mode (No tokens provided or auth failed)")
             game_args.extend([
                "--auth-mode", "offline",
                "--uuid", options["uuid"],
                "--name", options["playerName"],
                "--user-dir", user_data_dir
            ])
        else:
             game_args.extend([
                "--auth-mode", "authenticated",
                "--uuid", options["uuid"],
                "--name", options["playerName"],
                "--identity-token", identity_token,
                "--session-token", session_token,
                "--user-dir", user_data_dir
            ])

        try:
            cls._update_client_settings(user_data_dir, options)
        except Exception as e:
            print(f"[GameService] Failed to update client settings: {e}")

        # Environment variables
        env = os.environ.copy()
        env['_JAVA_OPTIONS'] = ' '.join(all_jvm_args)
        
        # Add Wayland and GPU env vars (Linux only)
        if is_linux():
            wayland_env = setup_wayland_environment()
            env.update(wayland_env)
            
            gpu_pref = options.get('gpuPreference', 'auto')
            gpu_env = setup_gpu_environment(gpu_pref)
            env.update(gpu_env)

            # Fix for native libraries on Linux
            # Ensure the game directory is in LD_LIBRARY_PATH so native libs (like libcef.so) are found
            current_ld_path = env.get('LD_LIBRARY_PATH', '')
            # Add client_dir and potential subdirectories
            lib_paths = [
                client_dir,
                os.path.join(client_dir, 'lib'),
                os.path.join(client_dir, 'bin'),
                os.path.join(client_dir, 'natives')
            ]
            valid_lib_paths = [p for p in lib_paths if os.path.exists(p)]
            if valid_lib_paths:
                new_ld_path = os.pathsep.join(valid_lib_paths)
                if current_ld_path:
                    env['LD_LIBRARY_PATH'] = f"{new_ld_path}{os.pathsep}{current_ld_path}"
                else:
                    env['LD_LIBRARY_PATH'] = new_ld_path
        
        cwd = client_dir
        cmd = []
        
        # Launch Strategy
        if client_path.endswith('.jar'):
            # Run via Java directly
            cmd = [java_path] + all_jvm_args + ["-jar", client_path] + game_args
        else:
            # Native executable (exe or linux binary)
            if not is_windows():
                # Ensure executable permission on Linux/Mac
                try:
                    st = os.stat(client_path)
                    os.chmod(client_path, st.st_mode | stat.S_IEXEC)
                except Exception as e:
                    LoggerService.error(f"Failed to set executable permission: {e}")

            # Run Executable directly
            # We rely on _JAVA_OPTIONS for memory settings
            cmd = [client_path] + game_args

        print(f"[GameService] Launching: {' '.join(cmd)}")
        print(f"[GameService] JVM Options: {all_jvm_args}")

        log_dir = os.path.join(paths["appDir"], "logs")
        log_stream = None
        try:
            os.makedirs(log_dir, exist_ok=True)
            log_file = os.path.join(log_dir, f"game-session-{int(time.time() * 1000)}.log")
            log_stream = open(log_file, "a", encoding="utf-8", buffering=1)
            safe_options = dict(options or {})
            if "identityToken" in safe_options:
                safe_options["identityToken"] = "***"
            if "sessionToken" in safe_options:
                safe_options["sessionToken"] = "***"
            log_stream.write(f"[LAUNCH] Timestamp: {time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime())}\n")
            log_stream.write(f"[LAUNCH] Options: {json.dumps(safe_options)}\n")
            print(f"[GameService] Game logs will be written to: {log_file}")
        except Exception as e:
            LoggerService.error(f"Failed to initialize game log file: {e}")
            log_stream = None

        # Launch
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, # Capture stderr for logs
            text=True
        )
        
        cls._game_start_time = time.time() * 1000 # MS
        cls._backend_process = process

        if log_stream:
            log_stream.write(f"[LAUNCH] PID: {process.pid}\n")

        # --- START MONITORING ---
        try:
            SkinMonitorService.get_instance().start_backup_monitor(user_data_dir)
        except Exception as e:
            LoggerService.error(f"[GameService] Failed to start backup monitor: {e}")

        def stream_reader(stream, tag, level):
            try:
                for line in iter(stream.readline, ''):
                    if line == '':
                        break
                    
                    if log_stream:
                        log_stream.write(f"[{tag}] {line}")
                    LoggerService.log_entry(level, f"[{tag}] {line.rstrip()}")
            except Exception as e:
                LoggerService.error(f"Log stream error: {e}")

        if process.stdout:
            threading.Thread(target=stream_reader, args=(process.stdout, "STDOUT", "info"), daemon=True).start()
        if process.stderr:
            threading.Thread(target=stream_reader, args=(process.stderr, "STDERR", "error"), daemon=True).start()

        def exit_watcher():
            try:
                process.wait()
                if log_stream:
                    log_stream.write(f"[EXIT] Code: {process.returncode}\n")
                
                try:
                    SkinMonitorService.get_instance().force_backup()
                except Exception as e:
                    LoggerService.error(f"Failed to backup skins on exit: {e}")

                try:
                    SkinMonitorService.get_instance().stop_monitoring()
                    LoggerService.info("[GameService] SkinMonitor stopped")
                except Exception as e:
                    LoggerService.error(f"Failed to stop SkinMonitor: {e}")
                    
            finally:
                if log_stream:
                    log_stream.close()

        threading.Thread(target=exit_watcher, daemon=True).start()
        
        return process

    @classmethod
    def _ensure_user_config(cls, game_dir, user_data_dir, options):
        """
        Ensures config.json exists and contains the correct player UUID mapping.
        This fixes the issue where skins are reset because the game fails to associate
        the current session with the saved profile.
        """
        player_name = options.get("playerName")
        player_uuid = options.get("uuid")
        
        if not player_name or not player_uuid:
            return

        # Target locations: Game Root and UserData
        # Community findings suggest HytaleF2P/config.json, but we check both.
        targets = [
            os.path.join(game_dir, "config.json"),
            os.path.join(user_data_dir, "config.json")
        ]

        for config_path in targets:
            try:
                data = {}
                if os.path.exists(config_path):
                    try:
                        with open(config_path, 'r', encoding='utf-8') as f:
                            data = json.load(f)
                    except:
                        data = {}
                
                # Update userUuids
                if "userUuids" not in data:
                    data["userUuids"] = {}
                
                # Force Name -> UUID mapping
                data["userUuids"][player_name] = player_uuid
                
                with open(config_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2)
                    
                print(f"[GameService] Updated user config at {config_path}")
            except Exception as e:
                print(f"[GameService] Failed to update config at {config_path}: {e}")
    @classmethod
    def _update_client_settings(cls, user_data_dir, options):
        """
        Updates Settings.json directly to force fullscreen/resolution.
        This is more robust than CLI args which may be rejected by the client.
        """
        settings_path = os.path.join(user_data_dir, "Settings.json")
        
        settings = {}
        if os.path.exists(settings_path):
            try:
                with open(settings_path, 'r', encoding='utf-8') as f:
                    settings = json.load(f)
            except Exception as e:
                print(f"[GameService] Error reading Settings.json: {e}")
                settings = {}

        modified = False
        
        # Update Fullscreen
        should_be_fullscreen = bool(options.get("fullscreen", False))
        if settings.get("Fullscreen") != should_be_fullscreen:
            settings["Fullscreen"] = should_be_fullscreen
            modified = True
            print(f"[GameService] Updating Fullscreen to {should_be_fullscreen}")

        # Update Resolution if provided
        width = options.get("width")
        height = options.get("height")
        
        if width and height:
            try:
                w_int = int(width)
                h_int = int(height)
                if settings.get("WindowWidth") != w_int:
                    settings["WindowWidth"] = w_int
                    settings["WindowHeight"] = h_int
                    modified = True
                if settings.get("WindowHeight") != h_int:
                    settings["WindowHeight"] = h_int
                    modified = True
                print(f"[GameService] Updating Resolution to {w_int}x{h_int}")
            except ValueError:
                pass

        if modified:
            try:
                os.makedirs(user_data_dir, exist_ok=True)
                with open(settings_path, 'w', encoding='utf-8') as f:
                    json.dump(settings, f, indent=2)
                print("[GameService] Client settings updated successfully.")
            except Exception as e:
                print(f"[GameService] Error saving Settings.json: {e}")
        else:
            print("[GameService] Client settings already match options.")
