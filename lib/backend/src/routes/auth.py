from fastapi import APIRouter, Request, Depends, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from ..services.AuthService import AuthService
from ..services.GuestAuthService import GuestAuthService
from ..services.LoggerService import LoggerService
from ..services.JWTService import JWTService
from ..services.RateLimitService import RateLimitService
from ..services.AuditService import AuditService

router = APIRouter(prefix="/api")

# Request Models
class AuthRequest(BaseModel):
    name: str
    uuid: str
    scopes: List[str]

class LoginRequest(BaseModel):
    username: str
    password: str

class RegisterRequest(BaseModel):
    username: str
    email: EmailStr
    password: str

class TokenRefreshRequest(BaseModel):
    refresh_token: str

class GuestOnlineRequest(BaseModel):
    username: str
    uuid: str

# JWKS Endpoint (Critical for Identity Token Verification)
@router.get("/.well-known/jwks.json")
def get_jwks():
    """Serve the public key for token verification"""
    return JSONResponse(
        content=JWTService.get_jwks(),
        media_type="application/jwk-set+json"
    )

@router.post("/auth/guest-online")
def guest_online_auth(body: GuestOnlineRequest):
    try:
        LoggerService.info(f"[Auth Route] Guest online auth for: {body.username}")
        tokens = AuthService.generate_offline_session(body.username, body.uuid)
        return {
            "success": True,
            "IdentityToken": tokens["IdentityToken"],
            "SessionToken": tokens["SessionToken"],
            "mode": "guest_online",
            "is_guest": True
        }
    except Exception as e:
        LoggerService.error(f"[Auth Route] Guest auth failed: {e}")
        return {"success": False, "error": str(e)}

@router.post("/game-session/child")
def child_login(body: AuthRequest):
    """Authenticate game session with guaranteed fallback"""
    try:
        LoggerService.info(f"[Auth Route] Child login requested: {body.name} (UUID: {body.uuid})")
        
        # We always return the properly signed EdDSA tokens now
        # whether they are 'offline' or 'online', they must be valid for Hytale
        tokens = AuthService.generate_offline_session(body.name, body.uuid)
        
        return {
            "IdentityToken": tokens["IdentityToken"],
            "SessionToken": tokens["SessionToken"],
            "mode": "authenticated"
        }
    except Exception as e:
        LoggerService.error(f"[Auth Route] Child login error: {e}")
        # Last resort fallback (though AuthService should now handle it)
        import uuid
        return {
            "IdentityToken": str(uuid.uuid4()),
            "SessionToken": str(uuid.uuid4()),
            "mode": "fallback"
        }

@router.post("/auth/login")
def login_user(body: LoginRequest, request: Request):
    ip_address = request.client.host if request.client else "unknown"
    try:
        # Check rate limit
        allowed, message = RateLimitService.check_login_rate_limit(ip_address)
        if not allowed:
            return JSONResponse(status_code=429, content={"success": False, "error": message})
        
        from ..services.DatabaseService import DatabaseService
        DatabaseService.init()
        user = DatabaseService.login(body.username, body.password)
        
        if user:
            tokens = JWTService.create_token_pair(body.username, str(user.get("_id", "")))
            return {
                "success": True,
                "user": user,
                "access_token": tokens["access_token"],
                "refresh_token": tokens["refresh_token"]
            }
        return JSONResponse(status_code=401, content={"success": False, "error": "Invalid credentials"})
    except Exception as e:
        LoggerService.error(f"Login error: {e}")
        return JSONResponse(status_code=500, content={"success": False, "error": "Login failed"})

@router.post("/auth/refresh")
def refresh_token(body: TokenRefreshRequest):
    try:
        new_access_token = JWTService.refresh_access_token(body.refresh_token)
        if new_access_token:
            return {"success": True, "access_token": new_access_token}
        return JSONResponse(status_code=401, content={"success": False, "error": "Invalid refresh token"})
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": "Refresh failed"})
