"""
Guest Authentication Service - For online guests without Hytale account
Generates tokens that work as "online" without requiring real Hytale auth
"""

from datetime import datetime, timedelta
from typing import Dict
from .LoggerService import LoggerService
from .JWTService import JWTService


class GuestAuthService:
    """
    Generates guest tokens for online play without Hytale account
    These tokens are signed with EdDSA to be valid for the game client
    """
    
    GUEST_MODE = "guest_online"
    
    @classmethod
    def generate_guest_token(cls, username: str, user_uuid: str) -> Dict:
        """
        Generate guest token that works for Hytale
        """
        try:
            LoggerService.info(f"[GuestAuthService] Generating guest online token for: {username}")
            
            # Use JWTService to create properly signed EdDSA tokens
            tokens = JWTService.create_hytale_tokens(username, user_uuid)
            
            return {
                "IdentityToken": tokens["IdentityToken"],
                "SessionToken": tokens["SessionToken"],
                "mode": cls.GUEST_MODE,
                "username": username,
                "uuid": user_uuid,
                "is_guest": True,
                "expires_at": (datetime.utcnow() + timedelta(days=30)).isoformat()
            }
        except Exception as e:
            LoggerService.error(f"[GuestAuthService] Failed to generate guest token: {e}")
            raise
