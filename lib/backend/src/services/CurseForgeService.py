import os
import json
import requests
from ..services.DownloadService import DownloadService
from ..services.LoggerService import LoggerService

class CurseForgeService:
    API_KEY = os.environ.get('CURSEFORGE_API_KEY', '')
    BASE_URL = 'https://api.curseforge.com/v1'
    GAME_ID = 70216  # Hytale Game ID on CurseForge (verified via API)
    
    @classmethod
    def get_headers(cls):
        """Get headers for CurseForge API requests"""
        return {
            'x-api-key': cls.API_KEY,
            'Accept': 'application/json'
        }
    
    @classmethod
    def check_api_key(cls):
        """Check if API key is configured"""
        if not cls.API_KEY or cls.API_KEY.strip() == '':
            LoggerService.error("[CurseForgeService] ❌ API_KEY not configured!")
            LoggerService.error("[CurseForgeService] Add to .env: CURSEFORGE_API_KEY=your_key_here")
            return False
        
        # Proactively discover game ID once key is confirmed
        cls.discover_game_id()
        
        LoggerService.info(f"[CurseForgeService] ✓ API key configured (length: {len(cls.API_KEY)})")
        return True

    @classmethod
    def discover_game_id(cls):
        """Discover Hytale's game ID from CurseForge API"""
        if not cls.API_KEY or cls.API_KEY.strip() == '':
            return cls.GAME_ID
            
        try:
            url = f"{cls.BASE_URL}/games"
            headers = cls.get_headers()
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                games = response.json().get('data', [])
                hytale = next((g for g in games if g.get('slug', '').lower() == 'hytale'), None)
                if hytale:
                    found_id = hytale.get('id')
                    if found_id != cls.GAME_ID:
                        LoggerService.info(f"[CurseForgeService] Dynamic Hytale ID found: {found_id} (Current hardcoded: {cls.GAME_ID})")
                        cls.GAME_ID = found_id
                    return found_id
            return cls.GAME_ID
        except Exception as e:
            LoggerService.error(f"[CurseForgeService] Error discovering game ID: {e}")
            return cls.GAME_ID

    @classmethod
    def get_mod(cls, mod_id):
        """Get specific mod details"""
        if not cls.check_api_key():
            return None
            
        try:
            url = f"{cls.BASE_URL}/mods/{mod_id}"
            headers = cls.get_headers()
            LoggerService.info(f"[CurseForgeService] Fetching mod details for ID: {mod_id}")
            response = requests.get(url, headers=headers, timeout=15)
            
            if response.status_code == 200:
                return response.json().get('data')
            
            LoggerService.error(f"[CurseForgeService] Mod details failed ({response.status_code}): {response.text}")
            return None
        except Exception as e:
            LoggerService.error(f"[CurseForgeService] Exception getting mod details: {e}")
            return None

    @classmethod
    def search_mods(cls, query='', index=0, page_size=20, sort_field=6, sort_order='desc'):
        """
        Search for mods on CurseForge API
        
        Args:
            query: Search filter (empty = popular mods)
            index: 0-based page index
            page_size: Results per page (max 50)
            sort_field: 6 = Most Downloaded (Popular)
            sort_order: 'asc' or 'desc'
        
        Returns:
            dict with 'data' (list of mods) and 'pagination' info
        """
        
        # Check API key first
        if not cls.check_api_key():
            return {"data": [], "pagination": {"totalCount": 0}}
        
        # Validate and sanitize inputs
        page_size = min(int(page_size), 50)  # Max 50 per API
        index = max(0, int(index))  # Ensure non-negative
        sort_field = int(sort_field)
        sort_order = 'desc' if str(sort_order).lower() in ['desc', 'descending'] else 'asc'
        query = str(query).strip() if query else ''
        
        # Build API request parameters
        params = {
            'gameId': cls.GAME_ID,  # 70216 = Hytale
            'pageSize': page_size,
            'index': index,
            'sortField': sort_field,
            'sortOrder': sort_order
        }
        
        # Only add search filter if query provided
        if query:
            params['searchFilter'] = query
        
        # Log request details
        LoggerService.info("")
        LoggerService.info("="*70)
        LoggerService.info("[CurseForgeService] 🔍 MOD SEARCH REQUEST")
        LoggerService.info("="*70)
        LoggerService.info(f"Query: '{query}' (empty = popular mods)")
        LoggerService.info(f"Game ID: {cls.GAME_ID} (Hytale)")
        LoggerService.info(f"Page: {(index // page_size) + 1} (Index: {index}, Size: {page_size})")
        LoggerService.info(f"Sort: Field {sort_field}, Order {sort_order}")
        LoggerService.info("-"*70)
        
        try:
            # Make request to CurseForge API v1
            url = f"{cls.BASE_URL}/mods/search"
            headers = cls.get_headers()
            
            LoggerService.info(f"Sending: GET {url}")
            LoggerService.info(f"Params: {json.dumps(params, indent=2)}")
            
            response = requests.get(
                url,
                params=params,
                headers=headers,
                timeout=15
            )
            
            LoggerService.info(f"Response Status: {response.status_code}")
            
            # Handle different status codes
            if response.status_code == 401:
                LoggerService.error("[CurseForgeService] ❌ ERROR 401: Unauthorized")
                LoggerService.error("[CurseForgeService] API key is invalid or expired!")
                LoggerService.error("[CurseForgeService] Get new key from: https://console.curseforge.com/")
                return {"data": [], "pagination": {"totalCount": 0, "error": "API key invalid"}}
            
            elif response.status_code == 403:
                LoggerService.error("[CurseForgeService] ❌ ERROR 403: Forbidden")
                LoggerService.error("[CurseForgeService] API key does not have permission")
                return {"data": [], "pagination": {"totalCount": 0, "error": "No permission"}}
            
            elif response.status_code == 404:
                LoggerService.error("[CurseForgeService] ❌ ERROR 404: Not Found")
                LoggerService.error("[CurseForgeService] Invalid endpoint or game ID")
                return {"data": [], "pagination": {"totalCount": 0, "error": "Not found"}}
            
            elif response.status_code != 200:
                LoggerService.error(f"[CurseForgeService] ❌ ERROR {response.status_code}")
                LoggerService.error(f"Response: {response.text[:500]}")
                return {"data": [], "pagination": {"totalCount": 0, "error": f"HTTP {response.status_code}"}}
            
            # Parse successful response
            data = response.json()
            mods = data.get('data', [])
            pagination = data.get('pagination', {})
            total_count = pagination.get('totalCount', 0)
            
            LoggerService.info(f"✅ SUCCESS: Found {len(mods)} mods (Total available: {total_count})")
            
            # Log first 3 mods
            if mods:
                LoggerService.info("-"*70)
                LoggerService.info("TOP MODS IN RESULT:")
                for i, mod in enumerate(mods[:3], 1):
                    LoggerService.info(f"{i}. {mod.get('name', 'Unknown')}")
                    LoggerService.info(f"   ID: {mod.get('id')}, Downloads: {mod.get('downloadCount', 0):,}")
            
            LoggerService.info("="*70)
            LoggerService.info("")
            
            return data
        
        except requests.exceptions.Timeout:
            LoggerService.error("[CurseForgeService] ❌ TIMEOUT: API took too long to respond (15s)")
            LoggerService.error("[CurseForgeService] Try again in a moment")
            return {"data": [], "pagination": {"totalCount": 0, "error": "Timeout"}}
        
        except requests.exceptions.ConnectionError:
            LoggerService.error("[CurseForgeService] ❌ CONNECTION ERROR: Cannot reach CurseForge API")
            LoggerService.error("[CurseForgeService] Check your internet connection")
            LoggerService.error("[CurseForgeService] Try: ping api.curseforge.com")
            return {"data": [], "pagination": {"totalCount": 0, "error": "Connection failed"}}
        
        except requests.exceptions.RequestException as e:
            LoggerService.error(f"[CurseForgeService] ❌ REQUEST ERROR: {str(e)}")
            return {"data": [], "pagination": {"totalCount": 0, "error": str(e)}}
        
        except ValueError as e:
            LoggerService.error(f"[CurseForgeService] ❌ PARSE ERROR: Invalid JSON response")
            LoggerService.error(f"[CurseForgeService] Response: {response.text[:200]}")
            return {"data": [], "pagination": {"totalCount": 0, "error": "Invalid response"}}
        
        except Exception as e:
            LoggerService.error(f"[CurseForgeService] ❌ UNEXPECTED ERROR: {str(e)}")
            import traceback
            LoggerService.error(f"Traceback: {traceback.format_exc()}")
            return {"data": [], "pagination": {"totalCount": 0, "error": str(e)}}

    @classmethod
    def get_mod_description(cls, mod_id):
        """Get mod HTML description"""
        if not cls.check_api_key():
            return ""
            
        try:
            url = f"{cls.BASE_URL}/mods/{mod_id}/description"
            headers = cls.get_headers()
            LoggerService.info(f"[CurseForgeService] Fetching mod description for ID: {mod_id}")
            response = requests.get(url, headers=headers, timeout=15)
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    return data.get('data', "")
                except:
                    return response.text
            
            LoggerService.error(f"[CurseForgeService] Mod description failed ({response.status_code})")
            return ""
        except Exception as e:
            LoggerService.error(f"[CurseForgeService] Exception getting mod description: {e}")
            return ""

    @classmethod
    def install_mod(cls, download_url, file_name, destination_dir):
        try:
            if not os.path.exists(destination_dir):
                os.makedirs(destination_dir, exist_ok=True)
            
            file_path = os.path.join(destination_dir, file_name)
            print(f"Downloading mod to: {file_path}")
            
            DownloadService.download_file(download_url, file_path)
            
            return {"success": True, "path": file_path}
        except Exception as e:
            print(f"Install mod error: {e}")
            raise e
