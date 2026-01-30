import os
import json
from datetime import datetime
from pathlib import Path
from typing import Optional
from .LoggerService import LoggerService

class AuditService:
    """Audit logging service for security events"""
    
    _audit_log_file = None
    
    @classmethod
    def _get_audit_log_path(cls) -> str:
        """Get path to audit log file"""
        if cls._audit_log_file is None:
            from ..utils.paths import get_app_dir
            log_dir = os.path.join(get_app_dir(), 'logs', 'audit')
            os.makedirs(log_dir, exist_ok=True)
            cls._audit_log_file = os.path.join(log_dir, 'audit.jsonl')
        return cls._audit_log_file
    
    @classmethod
    def log_login_attempt(
        cls,
        username: str,
        ip_address: str,
        success: bool,
        error_reason: Optional[str] = None
    ) -> None:
        """
        Log login attempt
        
        Args:
            username: Username attempting to login
            ip_address: IP address of the request
            success: Whether login was successful
            error_reason: Reason for failure if applicable
        """
        try:
            event = {
                "timestamp": datetime.utcnow().isoformat(),
                "event_type": "login_attempt",
                "username": username,
                "ip_address": ip_address,
                "success": success,
                "error_reason": error_reason
            }
            
            cls._write_audit_log(event)
            
            if success:
                LoggerService.info(f"[AuditService] Successful login: {username} from {ip_address}")
            else:
                LoggerService.warning(f"[AuditService] Failed login attempt: {username} from {ip_address} - {error_reason}")
                
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to log login attempt: {e}")
    
    @classmethod
    def log_register_attempt(
        cls,
        username: str,
        email: str,
        ip_address: str,
        success: bool,
        error_reason: Optional[str] = None
    ) -> None:
        """
        Log registration attempt
        
        Args:
            username: Username attempting to register
            email: Email address
            ip_address: IP address of the request
            success: Whether registration was successful
            error_reason: Reason for failure if applicable
        """
        try:
            event = {
                "timestamp": datetime.utcnow().isoformat(),
                "event_type": "register_attempt",
                "username": username,
                "email": email,
                "ip_address": ip_address,
                "success": success,
                "error_reason": error_reason
            }
            
            cls._write_audit_log(event)
            
            if success:
                LoggerService.info(f"[AuditService] Successful registration: {username} ({email}) from {ip_address}")
            else:
                LoggerService.warning(f"[AuditService] Failed registration attempt: {username} from {ip_address} - {error_reason}")
                
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to log registration attempt: {e}")
    
    @classmethod
    def log_token_refresh(
        cls,
        username: str,
        ip_address: str,
        success: bool
    ) -> None:
        """
        Log token refresh attempt
        
        Args:
            username: Username refreshing token
            ip_address: IP address of the request
            success: Whether refresh was successful
        """
        try:
            event = {
                "timestamp": datetime.utcnow().isoformat(),
                "event_type": "token_refresh",
                "username": username,
                "ip_address": ip_address,
                "success": success
            }
            
            cls._write_audit_log(event)
            
            if success:
                LoggerService.info(f"[AuditService] Token refresh: {username} from {ip_address}")
                
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to log token refresh: {e}")
    
    @classmethod
    def log_security_event(
        cls,
        event_type: str,
        username: Optional[str],
        ip_address: str,
        description: str,
        severity: str = "info"
    ) -> None:
        """
        Log custom security event
        
        Args:
            event_type: Type of security event
            username: Username if applicable
            ip_address: IP address
            description: Event description
            severity: Event severity (info, warning, critical)
        """
        try:
            event = {
                "timestamp": datetime.utcnow().isoformat(),
                "event_type": event_type,
                "username": username,
                "ip_address": ip_address,
                "description": description,
                "severity": severity
            }
            
            cls._write_audit_log(event)
            
            if severity == "critical":
                LoggerService.error(f"[AuditService] CRITICAL: {event_type} - {description}")
            elif severity == "warning":
                LoggerService.warning(f"[AuditService] {event_type} - {description}")
            else:
                LoggerService.info(f"[AuditService] {event_type} - {description}")
                
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to log security event: {e}")
    
    @classmethod
    def _write_audit_log(cls, event: dict) -> None:
        """Write event to audit log file (JSONL format)"""
        try:
            log_path = cls._get_audit_log_path()
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps(event) + '\n')
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to write audit log: {e}")
    
    @classmethod
    def get_login_history(cls, username: str, limit: int = 50) -> list:
        """
        Get login history for a user
        
        Args:
            username: Username to get history for
            limit: Maximum number of records
            
        Returns:
            List of login events
        """
        try:
            log_path = cls._get_audit_log_path()
            if not os.path.exists(log_path):
                return []
            
            events = []
            with open(log_path, 'r', encoding='utf-8') as f:
                for line in reversed(list(f)):
                    if events.__len__() >= limit:
                        break
                    try:
                        event = json.loads(line)
                        if (event.get('event_type') == 'login_attempt' and 
                            event.get('username') == username):
                            events.append(event)
                    except json.JSONDecodeError:
                        continue
            
            return list(reversed(events))
            
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to get login history: {e}")
            return []
    
    @classmethod
    def get_recent_events(cls, event_type: Optional[str] = None, limit: int = 100) -> list:
        """
        Get recent audit events
        
        Args:
            event_type: Filter by event type (optional)
            limit: Maximum number of records
            
        Returns:
            List of events
        """
        try:
            log_path = cls._get_audit_log_path()
            if not os.path.exists(log_path):
                return []
            
            events = []
            with open(log_path, 'r', encoding='utf-8') as f:
                for line in reversed(list(f)):
                    if len(events) >= limit:
                        break
                    try:
                        event = json.loads(line)
                        if event_type is None or event.get('event_type') == event_type:
                            events.append(event)
                    except json.JSONDecodeError:
                        continue
            
            return list(reversed(events))
            
        except Exception as e:
            LoggerService.error(f"[AuditService] Failed to get recent events: {e}")
            return []
