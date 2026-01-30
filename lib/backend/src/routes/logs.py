from fastapi import APIRouter
from ..services.LoggerService import LoggerService

router = APIRouter(prefix="/logs")

@router.get("/")
def get_logs():
    logs = LoggerService.get_logs()
    return {
        "success": True,
        "logs": logs,
        "count": len(logs)
    }

@router.get("/recent")
def get_recent_logs(limit: int = 50):
    logs = LoggerService.get_logs(limit)
    return {
        "success": True,
        "logs": logs,
        "count": len(logs)
    }

@router.get("/since")
def get_logs_since(timestamp: str = None):
    if not timestamp:
        return {
            "success": False,
            "error": "timestamp query parameter required"
        }
    logs = LoggerService.get_logs_since(timestamp)
    return {
        "success": True,
        "logs": logs,
        "count": len(logs)
    }

@router.get("/level/{level}")
def get_logs_by_level(level: str):
    valid_levels = ["info", "warn", "error", "debug"]
    if level not in valid_levels:
        return {
            "success": False,
            "error": f"Invalid level. Must be one of: {', '.join(valid_levels)}"
        }
    logs = LoggerService.get_logs_by_level(level)
    return {
        "success": True,
        "logs": logs,
        "count": len(logs)
    }

@router.delete("/")
def clear_logs():
    LoggerService.clear_logs()
    return {
        "success": True,
        "message": "All logs cleared"
    }
