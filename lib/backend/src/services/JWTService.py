import os
import json
import base64
import time
import uuid as uuid_lib
import secrets
import requests
from typing import Optional, Dict
from datetime import datetime, timedelta
from .LoggerService import LoggerService
from .ConfigService import ConfigService

class JWTService:
    """
    Authentication Service based on Hytale F2P logic.
    Prioritizes remote authentication (Sanasol.ws) and falls back to 
    local 'fake' token generation for offline/unverified mode.
    """
    
    # Internal launcher token settings (kept for launcher session management)
    SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'luyumi_launcher_jwt_secret_key')
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    REFRESH_TOKEN_EXPIRE_DAYS = 7
    
    # Hytale Auth Settings
    AUTH_SERVER_URL = "https://sessions.sanasol.ws"
    
    # Cache for dynamic KID
    _cached_kid = None
    _kid_fetch_time = 0
    KID_CACHE_DURATION = 3600  # 1 hour

    @staticmethod
    def base64url_encode(data):
        if isinstance(data, str):
            data = data.encode('utf-8')
        return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

    @classmethod
    def fetch_current_kid(cls, base_url: str = None) -> str:
        """
        Fetches the current KID from the remote JWKS endpoint.
        Persists successful fetches to config.
        Falls back to config if remote is unreachable.
        """
        current_time = time.time()
        
        # Return cached memory value if valid
        if cls._cached_kid and (current_time - cls._kid_fetch_time < cls.KID_CACHE_DURATION):
            return cls._cached_kid

        if not base_url:
            base_url = cls.AUTH_SERVER_URL
            
        # Clean up URL to get base (remove endpoints if present)
        if "/game-session" in base_url:
            base_url = base_url.split("/game-session")[0]
        base_url = base_url.rstrip("/")
        
        # Try standard JWKS locations
        jwks_urls = [f"{base_url}/jwks.json", f"{base_url}/.well-known/jwks.json"]
        
        fetched_kid = None
        for jwks_url in jwks_urls:
            try:
                LoggerService.info(f"[JWTService] Attempting to fetch JWKS KID from {jwks_url}")
                response = requests.get(jwks_url, timeout=3)
                
                if response.status_code == 200:
                    data = response.json()
                    keys = data.get("keys", [])
                    if keys and len(keys) > 0:
                        # Get the first key's KID (usually the active signing key)
                        fetched_kid = keys[0].get("kid")
                        if fetched_kid:
                            LoggerService.info(f"[JWTService] Successfully updated KID: {fetched_kid}")
                            # Update memory cache
                            cls._cached_kid = fetched_kid
                            cls._kid_fetch_time = current_time
                            
                            # Update persistent config
                            ConfigService.save_config({"last_known_kid": fetched_kid})
                            
                            return fetched_kid
            except Exception as e:
                LoggerService.warning(f"[JWTService] Failed to fetch from {jwks_url}: {e}")
                continue
            
        # If we reached here, remote fetch failed. Try persistent config.
        LoggerService.warning("[JWTService] Could not fetch dynamic KID. Checking persistent config.")
        config = ConfigService.load_config()
        last_known_kid = config.get("last_known_kid")
        
        if last_known_kid:
             LoggerService.info(f"[JWTService] Using cached KID from config: {last_known_kid}")
             cls._cached_kid = last_known_kid
             return last_known_kid
             
        # Ultimate fallback if nothing works (to prevent crash)
        # We don't hardcode it as a constant, but we need *something* to return.
        LoggerService.error("[JWTService] No KID found in remote or config! Using emergency default.")
        return "2025-10-01-sanasol"

    @classmethod
    def fetch_remote_tokens(cls, username: str, uuid: str, auth_url: str = None) -> Optional[Dict[str, str]]:
        """
        Fetch tokens from remote auth server.
        Matches Hytale-F2P 'fetchAuthTokens' logic.
        """
        if not auth_url:
            auth_url = cls.AUTH_SERVER_URL

        # Ensure correct endpoint
        if not auth_url.endswith("/game-session/child"):
            auth_url = auth_url.rstrip("/") + "/game-session/child"

        try:
            LoggerService.info(f"[JWTService] Fetching remote tokens from {auth_url} for {username}")
            
            payload = {
                "uuid": uuid,
                "name": username,
                "scopes": ["hytale:server", "hytale:client"]
            }
            
            response = requests.post(
                auth_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                LoggerService.info("[JWTService] Successfully received remote tokens")
                return {
                    "IdentityToken": data.get("IdentityToken") or data.get("identityToken"),
                    "SessionToken": data.get("SessionToken") or data.get("sessionToken")
                }
            else:
                LoggerService.warning(f"[JWTService] Remote auth failed with status {response.status_code}: {response.text}")
                return None
                
        except Exception as e:
            LoggerService.error(f"[JWTService] Error fetching remote tokens: {e}")
            return None

    @classmethod
    def generate_local_tokens(cls, username: str, uuid: str, auth_url: str = None) -> Dict[str, str]:
        """
        Generate local tokens with fake signature.
        Matches Hytale-F2P 'generateLocalTokens' logic.
        These tokens will FAIL verification on official/secure servers but work for offline/local.
        """
        LoggerService.info("[JWTService] Using locally generated tokens (fallback mode)")
        
        if not auth_url:
            auth_url = cls.AUTH_SERVER_URL
            
        # Get dynamic KID (with fallback)
        kid = cls.fetch_current_kid(auth_url)
            
        now = int(time.time())
        exp = now + 36000 # 10 hours
        
        header = {
            "alg": "EdDSA",
            "kid": kid,
            "typ": "JWT"
        }
        
        identity_payload = {
            "sub": uuid,
            "name": username,
            "username": username,
            "entitlements": ["game.base"],
            "scope": "hytale:server hytale:client",
            "iat": now,
            "exp": exp,
            "iss": auth_url,
            "jti": str(uuid_lib.uuid4())
        }
        
        session_payload = {
            "sub": uuid,
            "scope": "hytale:server",
            "iat": now,
            "exp": exp,
            "iss": auth_url,
            "jti": str(uuid_lib.uuid4())
        }
        
        encoded_header = cls.base64url_encode(json.dumps(header))
        encoded_identity = cls.base64url_encode(json.dumps(identity_payload))
        encoded_session = cls.base64url_encode(json.dumps(session_payload))
        
        # Fake signature (random bytes) just like Hytale-F2P
        signature = cls.base64url_encode(secrets.token_bytes(64))
        
        return {
            "IdentityToken": f"{encoded_header}.{encoded_identity}.{signature}",
            "SessionToken": f"{encoded_header}.{encoded_session}.{signature}"
        }

    @classmethod
    def create_hytale_tokens(cls, username: str, uuid: str) -> Dict[str, str]:
        """
        Main entry point for Hytale tokens.
        Tries remote first, then falls back to local.
        """
        # 1. Try Remote
        tokens = cls.fetch_remote_tokens(username, uuid)
        if tokens:
            return tokens
            
        # 2. Fallback Local
        LoggerService.warning("[JWTService] Remote auth failed. Generating local fallback tokens.")
        return cls.generate_local_tokens(username, uuid)

    # --- Internal Launcher Auth Methods (Keep existing logic for Launcher UI login) ---

    @classmethod
    def create_access_token(cls, data: Dict, expires_delta: Optional[timedelta] = None) -> str:
        import jwt # local import to avoid confusion with hytale logic
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=cls.ACCESS_TOKEN_EXPIRE_MINUTES)
        
        to_encode.update({"exp": expire, "type": "access"})
        return jwt.encode(to_encode, cls.SECRET_KEY, algorithm='HS256')

    @classmethod
    def create_refresh_token(cls, data: Dict, expires_delta: Optional[timedelta] = None) -> str:
        import jwt
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(days=cls.REFRESH_TOKEN_EXPIRE_DAYS)
        
        to_encode.update({"exp": expire, "type": "refresh"})
        return jwt.encode(to_encode, cls.SECRET_KEY, algorithm='HS256')

    @classmethod
    def verify_token(cls, token: str) -> Optional[Dict]:
        import jwt
        try:
            return jwt.decode(token, cls.SECRET_KEY, algorithms=['HS256'])
        except Exception:
            return None

    @classmethod
    def create_token_pair(cls, username: str, user_id: str = None) -> Dict:
        data = {"username": username}
        if user_id:
            data["user_id"] = user_id
        
        return {
            "access_token": cls.create_access_token(data),
            "refresh_token": cls.create_refresh_token(data),
            "token_type": "bearer"
        }

    @classmethod
    def refresh_access_token(cls, refresh_token: str) -> Optional[str]:
        payload = cls.verify_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            return None
        
        data = {"username": payload.get("username"), "user_id": payload.get("user_id")}
        return cls.create_access_token(data)
