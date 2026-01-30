import os
import shutil
import subprocess
import json
import requests
import zipfile
import tarfile
import hashlib
import stat
from ..utils.platform import is_windows, is_mac, is_linux, get_os, get_arch
from ..utils.paths import expand_home, get_resolved_app_dir
from .DownloadService import DownloadService

class JavaService:
    JAVA_EXECUTABLE = 'java.exe' if is_windows() else 'java'

    @staticmethod
    def find_java_on_path(command_name='java'):
        return shutil.which(command_name)

    @staticmethod
    def get_mac_java_home():
        if not is_mac():
            return None
        try:
            result = subprocess.run(['/usr/libexec/java_home'], capture_output=True, text=True)
            home = result.stdout.strip()
            if not home:
                return None
            return os.path.join(home, 'bin', JavaService.JAVA_EXECUTABLE)
        except:
            return None

    @staticmethod
    def resolve_java_path(input_path: str):
        trimmed = (input_path or '').strip()
        if not trimmed:
            return None

        expanded = expand_home(trimmed)
        if expanded and os.path.exists(expanded):
            if os.path.isdir(expanded):
                candidate = os.path.join(expanded, 'bin', JavaService.JAVA_EXECUTABLE)
                return candidate if os.path.exists(candidate) else None
            return expanded

        if expanded and not os.path.isabs(expanded):
            return JavaService.find_java_on_path(trimmed)

        return None

    @staticmethod
    def detect_system_java():
        env_home = os.environ.get('JAVA_HOME')
        if env_home:
            env_java = os.path.join(env_home, 'bin', JavaService.JAVA_EXECUTABLE)
            if os.path.exists(env_java):
                return env_java

        mac_java = JavaService.get_mac_java_home()
        if mac_java and os.path.exists(mac_java):
            return mac_java

        path_java = JavaService.find_java_on_path('java')
        if path_java and os.path.exists(path_java):
            return path_java

        return None

    @staticmethod
    def get_java_version(java_path):
        if not java_path or not os.path.exists(java_path):
            return None
        try:
            # Java version info is often printed to stderr
            result = subprocess.run([java_path, '-version'], capture_output=True, text=True)
            output = result.stderr + result.stdout
            
            # Simple parsing for "version "x.y.z""
            import re
            match = re.search(r'version "([^"]+)"', output)
            if match:
                return match.group(1)
            return "Unknown"
        except:
            return None

    @staticmethod
    def get_bundled_java_path(jre_dir=None):
        if not jre_dir:
            jre_dir = os.path.join(get_resolved_app_dir(), 'install', 'release', 'package', 'jre', 'latest')
            
        candidates = [
            os.path.join(jre_dir, 'bin', JavaService.JAVA_EXECUTABLE)
        ]

        if is_mac():
            candidates.append(os.path.join(jre_dir, 'Contents', 'Home', 'bin', JavaService.JAVA_EXECUTABLE))

        for candidate in candidates:
            if os.path.exists(candidate):
                return candidate

        return None

    @staticmethod
    def download_jre(progress_callback=None):
        app_dir = get_resolved_app_dir()
        jre_dir = os.path.join(app_dir, 'install', 'release', 'package', 'jre', 'latest')
        cache_dir = os.path.join(app_dir, 'cache')
        
        if not os.path.exists(cache_dir):
            os.makedirs(cache_dir, exist_ok=True)
            
        # Check if already installed
        if JavaService.get_bundled_java_path(jre_dir):
            print("Java runtime found, skipping download")
            return

        # Determine OS/Arch for URL
        os_name = 'darwin' if is_mac() else ('windows' if is_windows() else 'linux')
        arch = get_arch()
        if arch in ['x86_64', 'amd64', 'x64']:
            arch = 'amd64'
        elif arch in ['aarch64', 'arm64']:
            arch = 'arm64'
        
        print(f"Requesting Java runtime information for {os_name}/{arch}...")
        
        try:
            response = requests.get('https://launcher.hytale.com/version/release/jre.json', headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json'
            })
            response.raise_for_status()
            jre_data = response.json()
        except Exception as e:
            raise Exception(f"Failed to fetch JRE info: {e}")

        os_data = jre_data.get('download_url', {}).get(os_name)
        if not os_data:
            raise Exception(f"Java runtime unavailable for platform: {os_name}")
            
        platform_data = os_data.get(arch)
        if not platform_data:
            raise Exception(f"Java runtime unavailable for architecture {arch} on {os_name}")
            
        url = platform_data['url']
        sha256 = platform_data['sha256']
        file_name = os.path.basename(url)
        cache_file = os.path.join(cache_dir, file_name)
        
        # Download
        if not os.path.exists(cache_file):
            if progress_callback:
                progress_callback("Fetching Java runtime...", 0)
            print("Fetching Java runtime...")
            DownloadService.download_file(url, cache_file)
            
        # Validate
        if progress_callback:
            progress_callback("Validating files...", 50)
        print("Validating files...")
        
        sha256_hash = hashlib.sha256()
        with open(cache_file, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        
        if sha256_hash.hexdigest() != sha256:
            os.remove(cache_file)
            raise Exception(f"File validation failed: expected {sha256} but got {sha256_hash.hexdigest()}")
            
        # Extract
        if progress_callback:
            progress_callback("Unpacking Java runtime...", 70)
        print("Unpacking Java runtime...")
        
        JavaService.extract_jre(cache_file, jre_dir)
        
        # Permissions
        if not is_windows():
            java_candidates = [
                os.path.join(jre_dir, 'bin', JavaService.JAVA_EXECUTABLE),
                os.path.join(jre_dir, 'Contents', 'Home', 'bin', JavaService.JAVA_EXECUTABLE)
            ]
            for java_path in java_candidates:
                if os.path.exists(java_path):
                    st = os.stat(java_path)
                    os.chmod(java_path, st.st_mode | stat.S_IEXEC)
                    
        JavaService.flatten_jre_dir(jre_dir)
        
        try:
            os.remove(cache_file)
        except:
            pass
            
        print("Java runtime ready")

    @staticmethod
    def extract_jre(archive_path, dest_dir):
        if os.path.exists(dest_dir):
            shutil.rmtree(dest_dir)
        os.makedirs(dest_dir, exist_ok=True)
        
        if archive_path.endswith('.zip'):
            with zipfile.ZipFile(archive_path, 'r') as zip_ref:
                zip_ref.extractall(dest_dir)
                if not is_windows():
                    # Restore permissions
                    for info in zip_ref.infolist():
                        extracted_path = os.path.join(dest_dir, info.filename)
                        # ZipInfo.external_attr contains permissions in the upper 16 bits
                        if info.external_attr > 0xFFFF:
                            os.chmod(extracted_path, info.external_attr >> 16)
                            
        elif archive_path.endswith('.tar.gz') or archive_path.endswith('.tgz'):
            with tarfile.open(archive_path, 'r:gz') as tar:
                tar.extractall(dest_dir)
        else:
            raise Exception(f"Archive type not supported: {archive_path}")

    @staticmethod
    def flatten_jre_dir(jre_dir):
        try:
            entries = os.listdir(jre_dir)
            if len(entries) == 1:
                nested_dir = os.path.join(jre_dir, entries[0])
                if os.path.isdir(nested_dir):
                    # Move everything from nested up
                    for item in os.listdir(nested_dir):
                        shutil.move(os.path.join(nested_dir, item), jre_dir)
                    os.rmdir(nested_dir)
        except Exception as e:
            print(f"Notice: could not restructure Java directory: {e}")
