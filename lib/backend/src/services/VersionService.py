import requests
from ..utils.platform import get_os, get_arch

class VersionService:
    PATCH_ROOT_URL = 'https://game-patches.hytale.com/patches'
    VERSION_ENDPOINT = 'https://updates.butterlauncher.tech/versions_new.json'

    @staticmethod
    def get_version_info():
        try:
            # print('[VersionService] Fetching latest client version from API...')
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            }
            response = requests.get(VersionService.VERSION_ENDPOINT, headers=headers, timeout=10)
            if response.status_code != 200:
                print(f"[VersionService] Failed to fetch version: {response.status_code}")
                return None
            
            return response.json()
        except Exception as e:
            print(f"[VersionService] Error fetching version: {e}")
            return None

    @staticmethod
    def get_latest_version():
        """Returns the latest version ID string (e.g., '7.pwr')"""
        info = VersionService.get_version_info()
        if info and "latest_release_id" in info:
            return f"{info['latest_release_id']}.pwr"
        return "7.pwr"

    @staticmethod
    def get_last_updated():
        info = VersionService.get_version_info()
        if info and "last_updated" in info:
            return info["last_updated"]
        return "2026-01-28"

    @staticmethod
    def get_formatted_version_name():
        """Returns the display version: {last_updated}_build_release-{latest_release_id}"""
        info = VersionService.get_version_info()
        if info and "last_updated" in info and "latest_release_id" in info:
            return f"{info['last_updated']}_build_release-{info['latest_release_id']}"
        return "2026-01-28_build_release-7"

    @staticmethod
    def get_patch_url(version: str, channel: str = 'release'):
        os_name = get_os()
        arch = get_arch()
        
        # Mapping for arch if needed. Hytale patches use 'amd64' for x64
        if arch == 'x86_64' or arch == 'x64':
            arch = 'amd64'
        elif arch == 'aarch64':
            arch = 'arm64'
            
        file_name = version if version.endswith('.pwr') else f"{version}.pwr"
        
        return f"{VersionService.PATCH_ROOT_URL}/{os_name}/{arch}/{channel}/0/{file_name}"

    @staticmethod
    def is_update_available(current_version, latest_version):
        if not current_version:
            return True
        return current_version != latest_version
