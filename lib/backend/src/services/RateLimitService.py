import time
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Tuple
from .LoggerService import LoggerService

class RateLimitService:
    """Rate limiting service to prevent brute force attacks"""
    
    # Storage: {ip_or_username: [(timestamp, attempts_in_window)]}
    _login_attempts = defaultdict(list)
    _register_attempts = defaultdict(list)
    
    # Configuration
    MAX_LOGIN_ATTEMPTS = 5  # Max attempts
    LOGIN_WINDOW_SECONDS = 300  # 5 minutes
    MAX_REGISTER_ATTEMPTS = 3
    REGISTER_WINDOW_SECONDS = 3600  # 1 hour
    
    @classmethod
    def _clean_old_attempts(cls, attempts: list, window_seconds: int) -> list:
        """Remove attempts older than the window"""
        current_time = time.time()
        return [attempt_time for attempt_time in attempts if current_time - attempt_time < window_seconds]
    
    @classmethod
    def check_login_rate_limit(cls, identifier: str) -> Tuple[bool, str]:
        """
        Check if login attempt is allowed
        
        Args:
            identifier: IP address or username
            
        Returns:
            Tuple (allowed, message)
        """
        current_time = time.time()
        
        # Clean old attempts
        cls._login_attempts[identifier] = cls._clean_old_attempts(
            cls._login_attempts[identifier],
            cls.LOGIN_WINDOW_SECONDS
        )
        
        # Check limit
        attempts_count = len(cls._login_attempts[identifier])
        
        if attempts_count >= cls.MAX_LOGIN_ATTEMPTS:
            remaining_seconds = int(cls.LOGIN_WINDOW_SECONDS - (current_time - cls._login_attempts[identifier][0]))
            message = f"Too many login attempts. Try again in {remaining_seconds} seconds."
            LoggerService.warning(f"[RateLimitService] Login rate limit exceeded for: {identifier}")
            return False, message
        
        # Record this attempt
        cls._login_attempts[identifier].append(current_time)
        
        return True, "OK"
    
    @classmethod
    def check_register_rate_limit(cls, identifier: str) -> Tuple[bool, str]:
        """
        Check if registration attempt is allowed
        
        Args:
            identifier: IP address
            
        Returns:
            Tuple (allowed, message)
        """
        current_time = time.time()
        
        # Clean old attempts
        cls._register_attempts[identifier] = cls._clean_old_attempts(
            cls._register_attempts[identifier],
            cls.REGISTER_WINDOW_SECONDS
        )
        
        # Check limit
        attempts_count = len(cls._register_attempts[identifier])
        
        if attempts_count >= cls.MAX_REGISTER_ATTEMPTS:
            remaining_seconds = int(cls.REGISTER_WINDOW_SECONDS - (current_time - cls._register_attempts[identifier][0]))
            message = f"Too many registration attempts. Try again in {remaining_seconds // 60} minutes."
            LoggerService.warning(f"[RateLimitService] Register rate limit exceeded for: {identifier}")
            return False, message
        
        # Record this attempt
        cls._register_attempts[identifier].append(current_time)
        
        return True, "OK"
    
    @classmethod
    def reset_login_attempts(cls, identifier: str) -> None:
        """Reset login attempts for identifier after successful login"""
        if identifier in cls._login_attempts:
            del cls._login_attempts[identifier]
            LoggerService.info(f"[RateLimitService] Reset login attempts for: {identifier}")
    
    @classmethod
    def reset_register_attempts(cls, identifier: str) -> None:
        """Reset register attempts for identifier after successful registration"""
        if identifier in cls._register_attempts:
            del cls._register_attempts[identifier]
            LoggerService.info(f"[RateLimitService] Reset register attempts for: {identifier}")
    
    @classmethod
    def get_stats(cls) -> dict:
        """Get current rate limit statistics"""
        return {
            "login_attempts": dict(cls._login_attempts),
            "register_attempts": dict(cls._register_attempts),
            "max_login_attempts": cls.MAX_LOGIN_ATTEMPTS,
            "login_window_seconds": cls.LOGIN_WINDOW_SECONDS,
            "max_register_attempts": cls.MAX_REGISTER_ATTEMPTS,
            "register_window_seconds": cls.REGISTER_WINDOW_SECONDS,
        }
