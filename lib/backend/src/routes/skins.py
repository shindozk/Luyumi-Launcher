"""
Skins and Avatars API Routes

Endpoints for monitoring, backing up, and restoring skins.
"""

import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, List, Optional
from ..services.SkinMonitorService import SkinMonitorService
from ..services.LoggerService import LoggerService

router = APIRouter(prefix="/api/skins", tags=["skins"])


class StartMonitorRequest(BaseModel):
    game_dir: str


class RestoreSkinsRequest(BaseModel):
    game_dir: str


class BackupSkinRequest(BaseModel):
    category: str  # 'CachedAvatarPreviews' or 'CachedPlayerSkins'
    filename: str


@router.post("/monitor/start")
def start_skin_monitor(req: StartMonitorRequest):
    """
    Start monitoring skins in the game directory
    
    Monitors every 3 seconds for changes and automatically backs them up
    """
    try:
        service = SkinMonitorService.get_instance()
        success = service.start_monitoring(req.game_dir)
        
        if success:
            LoggerService.info(f"[Skins Route] Monitor started for: {req.game_dir}")
            return {
                "success": True,
                "message": "Skin monitor started",
                "game_dir": req.game_dir
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to start monitor")
    except Exception as e:
        LoggerService.error(f"[Skins Route] Start monitor failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/monitor/stop")
def stop_skin_monitor():
    """Stop monitoring skins"""
    try:
        service = SkinMonitorService.get_instance()
        success = service.stop_monitoring()
        
        if success:
            LoggerService.info("[Skins Route] Monitor stopped")
            return {
                "success": True,
                "message": "Skin monitor stopped"
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to stop monitor")
    except Exception as e:
        LoggerService.error(f"[Skins Route] Stop monitor failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/monitor/status")
def get_monitor_status():
    """Get current monitor status"""
    try:
        service = SkinMonitorService.get_instance()
        
        return {
            "success": True,
            "is_monitoring": service.is_monitoring,
            "game_dir": service.game_dir,
            "monitor_interval": service.MONITOR_INTERVAL
        }
    except Exception as e:
        LoggerService.error(f"[Skins Route] Status check failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/backed-up")
def get_backed_up_skins():
    """
    Get list of all backed up skins
    
    Returns:
    {
        "success": true,
        "skins": {
            "CachedAvatarPreviews": ["file1.png", "file2.png"],
            "CachedPlayerSkins": ["skin1.png", "skin2.png"]
        },
        "total_count": 4
    }
    """
    try:
        service = SkinMonitorService.get_instance()
        skins = service.get_backed_up_skins()
        
        total = sum(len(files) for files in skins.values())
        
        LoggerService.info(f"[Skins Route] Retrieved {total} backed up skins")
        
        return {
            "success": True,
            "skins": skins,
            "total_count": total
        }
    except Exception as e:
        LoggerService.error(f"[Skins Route] Get skins failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/restore")
def restore_skins(req: RestoreSkinsRequest):
    """
    Restore all backed up skins to game userData
    
    Called before game launch to inject skins
    """
    try:
        service = SkinMonitorService.get_instance()
        success = service.restore_skins(req.game_dir)
        
        if success:
            LoggerService.info(f"[Skins Route] Skins restored to: {req.game_dir}")
            return {
                "success": True,
                "message": "Skins restored successfully"
            }
        else:
            return {
                "success": False,
                "message": "No skins to restore or restoration incomplete"
            }
    except Exception as e:
        LoggerService.error(f"[Skins Route] Restore failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/repository/clear")
def clear_repository():
    """
    Clear the entire skins repository
    
    WARNING: This deletes all backed up skins!
    """
    try:
        service = SkinMonitorService.get_instance()
        success = service.clear_repository()
        
        if success:
            LoggerService.warning("[Skins Route] Repository cleared")
            return {
                "success": True,
                "message": "Skins repository cleared"
            }
        else:
            return {
                "success": False,
                "message": "Repository was already empty"
            }
    except Exception as e:
        LoggerService.error(f"[Skins Route] Clear failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/repository/path")
def get_repository_path():
    """Get the path to the skins repository"""
    try:
        repo_dir = SkinMonitorService.get_skins_repository_dir()
        
        return {
            "success": True,
            "repository_path": repo_dir,
            "exists": os.path.exists(repo_dir)
        }
    except Exception as e:
        LoggerService.error(f"[Skins Route] Get path failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Helper route for testing
@router.post("/test")
def test_skin_backup():
    """Test skin backup functionality"""
    try:
        service = SkinMonitorService.get_instance()
        
        return {
            "success": True,
            "message": "Skin service is operational",
            "is_monitoring": service.is_monitoring,
            "game_dir": service.game_dir
        }
    except Exception as e:
        LoggerService.error(f"[Skins Route] Test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
