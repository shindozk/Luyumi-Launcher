import os
import shutil
import subprocess
import platform
from .ButlerService import ButlerService

class ExtractionService:
    
    @staticmethod
    def validate_pwr_file(pwr_path):
        # print(f"[ExtractionService] Validating PWR file: {pwr_path}")

        if not os.path.exists(pwr_path):
            raise Exception(f"PWR file not found: {pwr_path}")

        if not os.path.isfile(pwr_path):
            raise Exception(f"PWR path is not a file: {pwr_path}")

        min_size = 10 * 1024 * 1024 # 10MB
        size = os.path.getsize(pwr_path)
        if size < min_size:
            raise Exception(f"PWR file suspiciously small: {size} bytes")

        # Check readability
        try:
            with open(pwr_path, 'rb') as f:
                f.read(1024)
        except Exception:
            raise Exception(f"PWR file is not readable: {pwr_path}")

        return True

    @staticmethod
    def extract_pwr(pwr_file, target_dir, butler_path, on_progress=None, skip_if_installed=True):
        # print(f"[ExtractionService] Starting extraction of {pwr_file} to {target_dir}")

        ExtractionService.validate_pwr_file(pwr_file)
        
        # Optionally skip extraction if client already exists (install-only scenario)
        if skip_if_installed:
            existing_client = ExtractionService.find_client_path(target_dir)
            if existing_client and os.path.exists(existing_client):
                try:
                    client_size = os.path.getsize(existing_client)
                except Exception:
                    client_size = 0
                if client_size < 20 * 1024 * 1024:
                    existing_client = None
                else:
                    pass
            if existing_client and os.path.exists(existing_client):
                 print(f"[ExtractionService] Game already installed at {target_dir}, skipping extraction")
                 if on_progress: on_progress("Game already installed, skipping extraction", 100)
                 
                 # Cleanup staging if exists
                 staging_dir = os.path.join(target_dir, 'staging-temp')
                 if os.path.exists(staging_dir):
                      shutil.rmtree(staging_dir, ignore_errors=True)
                 
                 return True

        staging_dir = os.path.join(target_dir, 'staging-temp')
        
        try:
            if on_progress: on_progress("Preparing staging directory...", 10)
            
            if os.path.exists(staging_dir):
                shutil.rmtree(staging_dir, ignore_errors=True)
            os.makedirs(staging_dir, exist_ok=True)
            
            # Create target directory if not exists
            os.makedirs(target_dir, exist_ok=True)

            if not os.path.exists(butler_path):
                 raise Exception(f"Butler not found at: {butler_path}")

            if on_progress: on_progress("Extracting files (Butler)...", 30)
            
            startupinfo = None
            if os.name == 'nt':
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

            # Use Butler apply with --staging-dir as in the old backend
            # Command: butler apply --staging-dir <staging> <pwr> <target>
            cmd = [
                butler_path, 
                'apply', 
                '--staging-dir', 
                staging_dir, 
                pwr_file, 
                target_dir
            ]
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                startupinfo=startupinfo,
                text=True
            )
            
            try:
                stdout, stderr = process.communicate(timeout=600)
            except subprocess.TimeoutExpired:
                process.kill()
                stdout, stderr = process.communicate()
                raise Exception("Butler extraction timed out (10 minutes)")
            
            if process.returncode != 0:
                error_msg = (stderr or "").strip() or (stdout or "").strip() or "Unknown Butler error"
                raise Exception(f"Butler extraction failed: {error_msg}")
            
            if on_progress: on_progress("Finalizing installation...", 90)

            # Ensure executable permissions on Linux/Mac
            if platform.system() != 'Windows':
                ExtractionService._ensure_executable_permissions(target_dir)

            # Cleanup staging directory
            shutil.rmtree(staging_dir, ignore_errors=True)
            
            return True

        except Exception as e:
            print(f"Extraction failed: {e}")
            # Cleanup
            if os.path.exists(staging_dir):
                shutil.rmtree(staging_dir, ignore_errors=True)
            # Propagate the exception with message
            raise e

    @staticmethod
    def _ensure_executable_permissions(game_dir):
        import stat
        candidates = ExtractionService.get_client_candidates(game_dir)
        for candidate in candidates:
            if os.path.exists(candidate):
                try:
                    st = os.stat(candidate)
                    os.chmod(candidate, st.st_mode | stat.S_IEXEC)
                    # print(f"[ExtractionService] Set executable permission for: {candidate}")
                except Exception as e:
                    print(f"[ExtractionService] Failed to set executable permission for {candidate}: {e}")

    @staticmethod
    def validate_extracted_game(game_dir):
        # Check for key files
        # Windows: HytaleClient.exe or Client/HytaleClient.exe
        # We need to be flexible
        
        client_path = ExtractionService.find_client_path(game_dir)
        if client_path:
             return {"valid": True, "issues": []}

        return {"valid": False, "issues": ["Executable not found"]}

    @staticmethod
    def find_client_path(game_dir):
        candidates = ExtractionService.get_client_candidates(game_dir)
        for candidate in candidates:
            if os.path.exists(candidate) and os.path.isfile(candidate):
                # print(f"[ExtractionService] Found client at: {candidate}")
                return candidate
        return None

    @staticmethod
    def get_client_candidates(game_dir):
        candidates = []
        system = platform.system()
        if system == 'Windows':
            candidates.append(os.path.join(game_dir, 'Client', 'HytaleClient.exe'))
            candidates.append(os.path.join(game_dir, 'HytaleClient.exe')) # Fallback
            candidates.append(os.path.join(game_dir, 'Hytale', 'Client', 'HytaleClient.exe'))
        elif system == 'Darwin':
            candidates.append(os.path.join(game_dir, 'Client', 'Hytale.app', 'Contents', 'MacOS', 'HytaleClient'))
            candidates.append(os.path.join(game_dir, 'Client', 'HytaleClient'))
            candidates.append(os.path.join(game_dir, 'Hytale.app', 'Contents', 'MacOS', 'HytaleClient'))
        else:
            candidates.append(os.path.join(game_dir, 'Client', 'HytaleClient'))
            candidates.append(os.path.join(game_dir, 'HytaleClient'))
            
        return candidates
