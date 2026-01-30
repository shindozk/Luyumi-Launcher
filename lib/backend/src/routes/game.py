from fastapi import APIRouter, BackgroundTasks
from typing import Optional
from pydantic import BaseModel
from ..services.GameService import GameService

router = APIRouter(prefix="/api/game")

class VersionRequest(BaseModel):
    version: Optional[str] = None

class LaunchRequest(BaseModel):
    playerName: str
    uuid: str
    identityToken: str
    sessionToken: str
    javaPath: Optional[str] = None
    gameDir: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    fullscreen: Optional[bool] = None
    server: Optional[str] = None
    profileId: Optional[str] = None
    gpuPreference: Optional[str] = None

def run_install_task(version: Optional[str]):
    try:
        GameService.install_game(version)
    except Exception as e:
        print(f"Background install failed: {e}")

def run_update_task(version: Optional[str]):
    try:
        GameService.update_game(version)
    except Exception as e:
        print(f"Background update failed: {e}")

def run_repair_task(version: Optional[str]):
    try:
        GameService.repair_game(version)
    except Exception as e:
        print(f"Background repair failed: {e}")

@router.get("/status/running")
def get_running_status():
    is_running = GameService.is_game_running()
    start_time = GameService.get_game_start_time()
    return {
        "isRunning": is_running,
        "startTime": start_time
    }

@router.get("/status")
def get_status():
    return GameService.get_game_status()

@router.get("/logs")
def get_game_logs():
    return GameService.get_latest_log_content()

@router.get("/install/progress")
def get_install_progress():
    return GameService.install_progress

@router.post("/install")
def install_game(body: VersionRequest, background_tasks: BackgroundTasks):
    try:
        # Reset progress or set to initializing
        GameService.set_progress_state(0, "Initializing installation...", "installing")
        background_tasks.add_task(run_install_task, body.version)
        return {"success": True, "message": "Installation started"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/update")
def update_game(body: VersionRequest, background_tasks: BackgroundTasks):
    try:
        GameService.set_progress_state(0, "Initializing update...", "installing")
        background_tasks.add_task(run_update_task, body.version)
        return {"success": True, "message": "Update started"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/repair")
def repair_game(body: VersionRequest, background_tasks: BackgroundTasks):
    try:
        GameService.set_progress_state(0, "Initializing repair...", "installing")
        background_tasks.add_task(run_repair_task, body.version)
        return {"success": True, "message": "Repair started"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/uninstall")
def uninstall_game():
    try:
        success = GameService.uninstall_game()
        return {"success": success}
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/launch")
def launch_game(body: LaunchRequest):
    try:
        process = GameService.launch_game_with_fallback(body.dict())
        return {
            "success": True, 
            "pid": process.pid,
            "message": "Game launched successfully"
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
