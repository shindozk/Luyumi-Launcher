import os
import json
from ..utils.paths import get_resolved_app_dir
from ..utils.platform import is_windows

class InstallationDetectionService:
    @staticmethod
    def get_detailed_game_status(game_dir: str):
        details = {
            "installed": False,
            "fullyExtracted": False,
            "corrupted": False,
            "clientPath": None,
            "clientSize": 0,
            "installedVersion": None,
            "issues": [],
            "details": {}
        }

        if not os.path.exists(game_dir):
            details["issues"].append("Game directory not found")
            return details

        # Check for executable
        client_exe = "HytaleClient.exe" if is_windows() else "HytaleClient"
        # Look in likely locations
        candidates = [
            os.path.join(game_dir, client_exe),
            os.path.join(game_dir, "Client", client_exe),
            os.path.join(game_dir, "Hytale", "Client", client_exe)
        ]

        found_exe = None
        for cand in candidates:
            if os.path.exists(cand):
                found_exe = cand
                break
        
        if found_exe:
            details["clientPath"] = found_exe
            details["installed"] = True
            try:
                details["clientSize"] = os.path.getsize(found_exe)
            except:
                pass
        else:
            details["issues"].append("Game executable not found")

        # Check metadata
        metadata_path = os.path.join(game_dir, "luyumi_metadata.json")
        if os.path.exists(metadata_path):
            try:
                with open(metadata_path, 'r', encoding='utf-8') as f:
                    meta = json.load(f)
                    details["installedVersion"] = meta.get("version")
            except:
                pass
        
        # If we have an exe but no metadata, we might assume it's some version
        if details["installed"] and not details["installedVersion"]:
             # Fallback logic if needed, or leave as None
             pass

        return details
