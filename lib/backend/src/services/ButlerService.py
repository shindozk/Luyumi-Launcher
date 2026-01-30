import os
import shutil
import zipfile
import stat
import platform
import subprocess
from ..utils.paths import get_resolved_app_dir
from ..utils.platform import get_os, get_arch
from .DownloadService import DownloadService

class ButlerService:
    TOOLS_DIR = os.path.join(get_resolved_app_dir(), 'butler')

    @staticmethod
    def _generate_download_urls(os_name, arch):
        urls = []
        mirrors = [
            'https://broth.itch.zone/butler',
            'https://dl.itch.ovh/butler',
            'https://storage.googleapis.com/broth/butler'
        ]

        path_suffix = ''
        if os_name == 'windows':
            path_suffix = 'windows-amd64/LATEST/archive/default'
        elif os_name == 'darwin':
            if arch == 'arm64':
                # For Apple Silicon, try arm64 first, then amd64
                path_suffix = 'darwin-arm64/LATEST/archive/default'
            else:
                path_suffix = 'darwin-amd64/LATEST/archive/default'
        elif os_name == 'linux':
            if arch == 'arm64':
                 path_suffix = 'linux-arm64/LATEST/archive/default'
            else:
                 path_suffix = 'linux-amd64/LATEST/archive/default'
        else:
            raise Exception('Operating system not supported')

        # Generate URLs
        if os_name == 'darwin' and arch == 'arm64':
             # Special case for Mac ARM64: add arm64 mirrors then amd64 mirrors
             for mirror in mirrors:
                 urls.append(f"{mirror}/darwin-arm64/LATEST/archive/default")
             for mirror in mirrors:
                 urls.append(f"{mirror}/darwin-amd64/LATEST/archive/default")
        elif os_name == 'linux' and arch == 'arm64':
             # Linux ARM64: try arm64 first, then amd64 (fallback, though unlikely to run)
             for mirror in mirrors:
                 urls.append(f"{mirror}/linux-arm64/LATEST/archive/default")
             for mirror in mirrors:
                 urls.append(f"{mirror}/linux-amd64/LATEST/archive/default")
        else:
             for mirror in mirrors:
                 urls.append(f"{mirror}/{path_suffix}")
        
        return urls

    @staticmethod
    def install_butler(tools_dir=None, on_progress=None):
        if tools_dir is None:
            tools_dir = ButlerService.TOOLS_DIR

        if not os.path.exists(tools_dir):
            os.makedirs(tools_dir, exist_ok=True)

        butler_name = 'butler.exe' if platform.system() == 'Windows' else 'butler'
        butler_path = os.path.join(tools_dir, butler_name)
        zip_path = os.path.join(tools_dir, 'butler.zip')

        # Kill any existing butler processes to allow overwrite
        ButlerService._kill_existing_butler()

        if os.path.exists(butler_path):
            # Basic validation: check if file is not empty
            if os.path.getsize(butler_path) > 0:
                return butler_path
            else:
                try:
                    os.remove(butler_path)
                except:
                    pass

        os_name = get_os()
        arch = get_arch()
        urls = ButlerService._generate_download_urls(os_name, arch)

        # Cleanup old zip if exists
        if os.path.exists(zip_path):
            try:
                os.remove(zip_path)
            except:
                pass

        # print('Fetching Butler tool...')
        last_error = None
        for url in urls:
            try:
                DownloadService.download_file(url, zip_path, max_retries=3, timeout=60, resumable=False, on_progress=on_progress)
                last_error = None
                
                # Verify zip integrity immediately
                if not zipfile.is_zipfile(zip_path):
                    raise Exception("Downloaded file is not a valid zip")
                
                break
            except Exception as e:
                last_error = e
                print(f"[ButlerService] Download failed for {url}: {e}")
                if os.path.exists(zip_path):
                    try:
                        os.remove(zip_path)
                    except:
                        pass

        curl_error = None
        if last_error or not os.path.exists(zip_path):
            # Try fallback with curl (system command)
            print("[ButlerService] Python download failed, trying system curl...")
            
            # Ensure we have curl
            try:
                subprocess.run(['curl', '--version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            except:
                print("[ButlerService] Curl not found on system.")
                raise Exception(f"Failed to download Butler. Python error: {last_error}. Curl not found.")

            curl_success = False
            for url in urls:
                try:
                    print(f"[ButlerService] Trying curl with {url}")
                    subprocess.run(
                        [
                            'curl',
                            '-L',
                            '--ipv4',
                            '--retry', '3',
                            '--retry-delay', '2',
                            '--connect-timeout', '30',
                            '--max-time', '120',
                            '-o', zip_path,
                            url
                        ],
                        check=True,
                        capture_output=True
                    )
                    
                    if os.path.exists(zip_path) and os.path.getsize(zip_path) > 1000:
                        if zipfile.is_zipfile(zip_path):
                            curl_success = True
                            last_error = None
                            break
                        else:
                            print(f"[ButlerService] Curl downloaded invalid zip from {url}")
                    else:
                        print(f"[ButlerService] Curl download from {url} produced empty/missing file")
                
                except Exception as e_curl:
                    print(f"[ButlerService] Curl failed for {url}: {e_curl}")
            
            if not curl_success:
                 curl_error = "All curl attempts failed."

        if last_error or not os.path.exists(zip_path):
            error_msg = f"Failed to download Butler. Python error: {last_error}"
            if curl_error:
                error_msg += f". Curl error: {curl_error}"
            raise Exception(error_msg)

        # print('Unpacking Butler...')
        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(tools_dir)
        except Exception as e:
            try:
                os.remove(zip_path)
            except:
                pass
            raise Exception(f"Invalid Butler archive (extraction failed): {e}")

        # Verify extraction
        if not os.path.exists(butler_path):
             # Maybe it's in a subfolder?
             # Look for butler.exe recursively in tools_dir
             found_butler = None
             for root, dirs, files in os.walk(tools_dir):
                 if butler_name in files:
                     found_butler = os.path.join(root, butler_name)
                     break
             
             if found_butler:
                 # Move it to tools_dir
                 try:
                     shutil.move(found_butler, butler_path)
                 except Exception as e:
                     print(f"Failed to move butler from subfolder: {e}")
             else:
                 raise Exception(f"Butler binary not found after extraction in {tools_dir}")

        if platform.system() != 'Windows':
            st = os.stat(butler_path)
            os.chmod(butler_path, st.st_mode | stat.S_IEXEC)

        try:
            os.remove(zip_path)
        except:
            pass

        return butler_path

    @staticmethod
    def _kill_existing_butler():
        if platform.system() == 'Windows':
            try:
                subprocess.run(['taskkill', '/F', '/IM', 'butler.exe'], 
                             stdout=subprocess.DEVNULL, 
                             stderr=subprocess.DEVNULL)
            except:
                pass
        else:
            try:
                subprocess.run(['pkill', 'butler'], 
                             stdout=subprocess.DEVNULL, 
                             stderr=subprocess.DEVNULL)
            except:
                pass


    @staticmethod
    def run_butler(args, tools_dir=None):
        butler_path = ButlerService.install_butler(tools_dir)
        
        # print(f"Running butler: {butler_path} {' '.join(args)}")
        
        # Suppress window on Windows
        startupinfo = None
        if platform.system() == 'Windows':
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

        process = subprocess.Popen(
            [butler_path] + args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            startupinfo=startupinfo,
            text=True
        )
        
        stdout, stderr = process.communicate()
        
        if process.returncode != 0:
            raise Exception(f"Butler failed with code {process.returncode}: {stderr}")
            
        return stdout
