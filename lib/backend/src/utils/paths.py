import os
import sys
import json
from .platform import is_windows, is_mac, is_linux

def get_app_dir():
    app_name = "LuyumiLauncher"
    if is_windows():
        base = os.environ.get('APPDATA')
        if not base:
            base = os.path.join(os.path.expanduser('~'), 'AppData', 'Roaming')
        return os.path.join(base, app_name)
    elif is_mac():
        return os.path.join(os.path.expanduser('~'), 'Library', 'Application Support', app_name)
    elif is_linux():
        return os.path.join(os.path.expanduser('~'), '.local', 'share', app_name)
    else:
        return os.path.join(os.path.expanduser('~'), '.config', app_name)

def get_resolved_app_dir():
    app_name = "LuyumiLauncher"
    app_dir = get_app_dir()
    config_paths = [os.path.join(app_dir, 'config.json')]
    
    if is_windows():
        roaming = os.environ.get('APPDATA')
        if roaming:
            roaming_dir = os.path.join(roaming, app_name)
            if roaming_dir != app_dir:
                config_paths.append(os.path.join(roaming_dir, 'config.json'))
    
    for config_path in config_paths:
        try:
            if os.path.exists(config_path):
                with open(config_path, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                install_path = config.get('installPath')
                if install_path and str(install_path).strip():
                    return os.path.join(str(install_path).strip(), app_name)
        except Exception:
            pass
    
    return app_dir

def expand_home(path_str: str):
    if not path_str:
        return path_str
    return os.path.expanduser(path_str)

def get_profiles_dir():
    return os.path.join(get_resolved_app_dir(), 'profiles')

def find_client_path(game_dir: str):
    candidates = [
        os.path.join(game_dir, "Hytale.exe"),
        os.path.join(game_dir, "Client", "Hytale.exe"),
        os.path.join(game_dir, "HytaleClient.exe"),
        os.path.join(game_dir, "Client", "HytaleClient.exe"),
        # Linux/Mac candidates
        os.path.join(game_dir, "HytaleClient"),
        os.path.join(game_dir, "Client", "HytaleClient"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None

def get_game_dir():
    return os.path.join(get_resolved_app_dir(), 'Hytale')

def get_game_mods_path():
    return os.path.join(get_game_dir(), 'mods')

def get_user_data_dir():
    r"""
    Get the UserData directory for the launcher.
    Always returns the launcher's base directory UserData, not affected by custom install paths.
    
    Windows: C:\Users\{user}\AppData\Roaming\LuyumiLauncher\userData
    Linux: ~/.local/share/LuyumiLauncher/userData
    macOS: ~/Library/Application Support/LuyumiLauncher/userData
    """
    return os.path.join(get_app_dir(), 'userData')
