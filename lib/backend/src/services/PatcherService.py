import os
import json
import zipfile
import shutil
from datetime import datetime
from ..utils.paths import find_client_path
from .ConfigService import ConfigService
from .LoggerService import LoggerService

ORIGINAL_DOMAIN = 'hytale.com'
DEFAULT_NEW_DOMAIN = 'sanasol.ws'

class PatcherService:
    PATCHED_FLAG = '.patched_custom'

    @staticmethod
    def get_target_domain():
        return ConfigService.get_auth_domain()

    @classmethod
    def get_new_domain(cls):
        domain = cls.get_target_domain()
        if len(domain) != len(ORIGINAL_DOMAIN):
            LoggerService.warning(f"Domain \"{domain}\" length ({len(domain)}) doesn't match original \"{ORIGINAL_DOMAIN}\" ({len(ORIGINAL_DOMAIN)})")
            LoggerService.warning(f"Using default domain: {DEFAULT_NEW_DOMAIN}")
            return DEFAULT_NEW_DOMAIN
        return domain

    @staticmethod
    def string_to_utf16le(s: str) -> bytes:
        return s.encode('utf-16le')

    @staticmethod
    def string_to_utf8(s: str) -> bytes:
        return s.encode('utf-8')

    @staticmethod
    def find_all_occurrences(buffer: bytearray, pattern: bytes):
        positions = []
        pos = 0
        while True:
            pos = buffer.find(pattern, pos)
            if pos == -1:
                break
            positions.append(pos)
            pos += 1
        return positions

    @classmethod
    def find_and_replace_domain_utf8(cls, data: bytearray, old_domain: str, new_domain: str):
        count = 0
        old_utf8 = cls.string_to_utf8(old_domain)
        new_utf8 = cls.string_to_utf8(new_domain)
        
        positions = cls.find_all_occurrences(data, old_utf8)
        
        for pos in positions:
            data[pos:pos+len(new_utf8)] = new_utf8
            count += 1
            
        return count

    @classmethod
    def find_and_replace_domain_smart(cls, data: bytearray, old_domain: str, new_domain: str):
        count = 0
        old_utf16_no_last = cls.string_to_utf16le(old_domain[:-1])
        new_utf16_no_last = cls.string_to_utf16le(new_domain[:-1])
        
        old_last_char_byte = ord(old_domain[-1])
        new_last_char_byte = ord(new_domain[-1])
        
        positions = cls.find_all_occurrences(data, old_utf16_no_last)
        
        for pos in positions:
            last_char_pos = pos + len(old_utf16_no_last)
            if last_char_pos + 1 > len(data):
                continue
                
            last_char_first_byte = data[last_char_pos]
            
            if last_char_first_byte == old_last_char_byte:
                data[pos:pos+len(new_utf16_no_last)] = new_utf16_no_last
                data[last_char_pos] = new_last_char_byte
                count += 1
                
        return count

    @classmethod
    def find_server_path(cls, game_dir: str):
        candidates = [
            os.path.join(game_dir, 'Server', 'HytaleServer.jar'),
            os.path.join(game_dir, 'Server', 'server.jar')
        ]
        for candidate in candidates:
            if os.path.exists(candidate):
                return candidate
        return None

    @classmethod
    def patch_server(cls, server_path: str, new_domain: str):
        try:
            temp_path = server_path + '.tmp'
            old_utf8 = cls.string_to_utf8(ORIGINAL_DOMAIN)
            
            total_count = 0
            
            with zipfile.ZipFile(server_path, 'r') as zin:
                with zipfile.ZipFile(temp_path, 'w') as zout:
                    for item in zin.infolist():
                        data = zin.read(item.filename)
                        name = item.filename
                        
                        if (name.endswith('.class') or name.endswith('.properties') or 
                            name.endswith('.json') or name.endswith('.xml') or name.endswith('.yml')):
                            
                            if old_utf8 in data:
                                mutable_data = bytearray(data)
                                count = cls.find_and_replace_domain_utf8(mutable_data, ORIGINAL_DOMAIN, new_domain)
                                if count > 0:
                                    data = mutable_data
                                    total_count += count
                        
                        zout.writestr(item, data)
            
            if total_count > 0:
                shutil.move(temp_path, server_path)
                return True
            else:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                return False
                
        except Exception as err:
            LoggerService.error(f"Error patching server {os.path.basename(server_path)}: {err}")
            if os.path.exists(server_path + '.tmp'):
                os.remove(server_path + '.tmp')
        return False

    @classmethod
    def patch_file(cls, file_path: str, new_domain: str):
        try:
            with open(file_path, 'rb') as f:
                data = bytearray(f.read())
            
            count_utf8 = cls.find_and_replace_domain_utf8(data, ORIGINAL_DOMAIN, new_domain)
            count_smart = cls.find_and_replace_domain_smart(data, ORIGINAL_DOMAIN, new_domain)
            
            total_count = count_utf8 + count_smart
            
            if total_count > 0:
                with open(file_path, 'wb') as f:
                    f.write(data)
                
                # Restore/Ensure executable permissions on Linux/Mac
                if os.name != 'nt':
                    import stat
                    st = os.stat(file_path)
                    os.chmod(file_path, st.st_mode | stat.S_IEXEC)

                LoggerService.info(f"Patched {os.path.basename(file_path)}: {total_count} occurrences replaced.")
                return True
        except Exception as err:
            LoggerService.error(f"Error patching {file_path}: {err}")
        return False

    @classmethod
    def is_patched_already(cls, file_path: str, new_domain: str):
        patch_flag_file = file_path + cls.PATCHED_FLAG
        if os.path.exists(patch_flag_file):
            try:
                with open(patch_flag_file, 'r', encoding='utf-8') as f:
                    flag_data = json.load(f)
                if flag_data.get('targetDomain') == new_domain:
                    bin_stats = os.stat(file_path)
                    flag_stats = os.stat(patch_flag_file)
                    if bin_stats.st_mtime > flag_stats.st_mtime:
                        LoggerService.info(f"Binary {os.path.basename(file_path)} is newer than patch flag. Repatching...")
                        return False
                    return True
            except Exception:
                pass
        return False

    @classmethod
    def mark_as_patched(cls, file_path: str, new_domain: str):
        patch_flag_file = file_path + cls.PATCHED_FLAG
        flag_data = {
            "patchedAt": datetime.now().isoformat(),
            "originalDomain": ORIGINAL_DOMAIN,
            "targetDomain": new_domain,
            "patcherVersion": "1.0.0"
        }
        with open(patch_flag_file, 'w', encoding='utf-8') as f:
            json.dump(flag_data, f, indent=2)

    @classmethod
    def ensure_client_patched(cls, game_dir: str):
        new_domain = cls.get_new_domain()
        LoggerService.info(f"[PatcherService] Ensuring client is patched for domain: {new_domain}")

        client_candidates = [
            find_client_path(game_dir),
            os.path.join(game_dir, 'Client', 'Hytale.exe'),
            os.path.join(game_dir, 'Client', 'HytaleClient.exe'),
            os.path.join(game_dir, 'Client', 'HytaleClient'), # Linux/Mac
        ]
        # Filter None and duplicates
        unique_candidates = list(set([c for c in client_candidates if c]))

        for client_path in unique_candidates:
            if os.path.exists(client_path):
                if not cls.is_patched_already(client_path, new_domain):
                    LoggerService.info(f"[PatcherService] Patching {os.path.basename(client_path)}...")
                    success = cls.patch_file(client_path, new_domain)
                    if success:
                        cls.mark_as_patched(client_path, new_domain)
                else:
                    LoggerService.info(f"[PatcherService] {os.path.basename(client_path)} already patched.")

        server_path = cls.find_server_path(game_dir)
        if server_path and os.path.exists(server_path):
            if not cls.is_patched_already(server_path, new_domain):
                LoggerService.info(f"[PatcherService] Patching server {os.path.basename(server_path)}...")
                success = cls.patch_server(server_path, new_domain)
                if success:
                    cls.mark_as_patched(server_path, new_domain)
            else:
                LoggerService.info(f"[PatcherService] {os.path.basename(server_path)} already patched.")
