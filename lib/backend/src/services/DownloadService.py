import os
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import shutil

class DownloadService:
    DEFAULT_TIMEOUT = 60  # Increased to match F2P
    DEFAULT_CHUNK_SIZE = 1024 * 1024  # 1MB
    DEFAULT_MAX_RETRIES = 3

    @staticmethod
    def download_file(url, dest_path, max_retries=DEFAULT_MAX_RETRIES, timeout=DEFAULT_TIMEOUT, resumable=True, on_progress=None):
        dest_dir = os.path.dirname(dest_path)
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir, exist_ok=True)

        attempt = 0
        last_error = None

        # Headers from Hytale F2P
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://launcher.hytale.com/',
            'Connection': 'keep-alive'
        }

        while attempt < max_retries:
            try:
                attempt += 1
                # print(f"[DownloadService] Attempt {attempt}/{max_retries} - Downloading: {url}")
                
                result = DownloadService._download_file_internal(
                    url, dest_path, timeout, resumable, on_progress, headers
                )
                
                return result
            except Exception as e:
                last_error = e
                print(f"[DownloadService] Attempt {attempt} failed: {e}")
                
                # Check if retryable (match F2P logic)
                is_retryable = False
                error_str = str(e).lower()
                retryable_keywords = ['timeout', 'stalled', 'connection', 'reset', 'refused']
                
                if any(k in error_str for k in retryable_keywords):
                    is_retryable = True
                
                if not is_retryable or attempt == max_retries:
                    break

                delay = 2 * attempt  # F2P uses 2000 * attempt (ms) -> 2 * attempt (s)
                # print(f"[DownloadService] Retrying in {delay}s...")
                time.sleep(delay)

        raise last_error or Exception("Download failed after maximum retries")

    @staticmethod
    def _download_file_internal(url, dest_path, timeout, resumable, on_progress, headers):
        temp_path = f"{dest_path}.tmp"
        downloaded_size = 0
        total_size = 0
        mode = 'wb'
        
        # Clone headers to avoid modifying the original dict
        req_headers = headers.copy()

        if not resumable and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except:
                pass

        # Check if partial download exists
        if resumable and os.path.exists(temp_path):
            downloaded_size = os.path.getsize(temp_path)
            req_headers['Range'] = f"bytes={downloaded_size}-"
            mode = 'ab'

        session = requests.Session()
        retries = Retry(total=3, backoff_factor=1, status_forcelist=[500, 502, 503, 504])
        session.mount('https://', HTTPAdapter(max_retries=retries))

        try:
            with session.get(url, headers=req_headers, stream=True, timeout=timeout) as response:
                response.raise_for_status()
                
                content_length = response.headers.get('content-length')
                if content_length:
                    total_size = downloaded_size + int(content_length)
                
                with open(temp_path, mode) as f:
                    last_chunk_time = time.time()
                    for chunk in response.iter_content(chunk_size=DownloadService.DEFAULT_CHUNK_SIZE):
                        if chunk:
                            f.write(chunk)
                            downloaded_size += len(chunk)
                            last_chunk_time = time.time()
                            if on_progress and total_size > 0:
                                percent = (downloaded_size / total_size) * 100
                                on_progress(downloaded_size, total_size, percent)
                        
                        # Stalled check (F2P uses 30s)
                        if time.time() - last_chunk_time > 30:
                            raise Exception("Download stalled (30s without data)")

            os.replace(temp_path, dest_path)
            
            return {
                "success": True,
                "path": dest_path,
                "size": downloaded_size,
                "resumed": mode == 'ab'
            }
        except Exception as e:
            raise e

    @staticmethod
    def cleanup_temp_files(dir_path):
        if os.path.exists(dir_path):
            for f in os.listdir(dir_path):
                if f.endswith(".tmp"):
                    try:
                        os.remove(os.path.join(dir_path, f))
                    except:
                        pass
