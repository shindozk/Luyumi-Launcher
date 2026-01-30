import sys
import os

# Add the backend directory to Python path to ensure imports work in Release mode
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# Add diagnostic logs for Release builds
print(f"[Backend Startup] Current Working Dir: {os.getcwd()}")
print(f"[Backend Startup] Backend Dir: {backend_dir}")
print(f"[Backend Startup] Python Path: {sys.path}")

try:
    from fastapi import FastAPI
    from src.services.LoggerService import LoggerService
except ImportError as e:
    print(f"[Backend Startup] CRITICAL IMPORT ERROR: {e}")
    print(f"[Backend Startup] Contents of {backend_dir}: {os.listdir(backend_dir)}")
    src_path = os.path.join(backend_dir, 'src')
    if os.path.exists(src_path):
        print(f"[Backend Startup] src/ exists and contains: {os.listdir(src_path)}")
    else:
        print(f"[Backend Startup] src/ directory MISSING!")
    sys.exit(1)

LoggerService.initialize()

app = FastAPI()

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    try:
        # Initialize profiles (create default if needed)
        ProfileService.init()
        LoggerService.info("Profiles initialized")
        
        # Sync mods for the active profile on startup
        active_profile = ProfileService.get_active_profile()
        if active_profile:
            ModManager.sync_mods_for_profile(active_profile['id'])
            LoggerService.info(f"Mods synced for profile: {active_profile['id']}")
    except Exception as e:
        LoggerService.error(f"Startup event failed: {e}")
        import traceback
        LoggerService.error(traceback.format_exc())
    
    yield
    # Shutdown logic goes here if needed

app = FastAPI(lifespan=lifespan)
try:
    from src.services.ProfileService import ProfileService
    from src.services.ModManager import ModManager
    from src.services.SkinMonitorService import SkinMonitorService
    from src.routes import game, version, auth, news, logs, mods, java, skins
    
    app.include_router(game.router)
    app.include_router(version.router)
    app.include_router(auth.router)
    app.include_router(news.router)
    app.include_router(logs.router)
    app.include_router(mods.router)
    app.include_router(java.router)
    app.include_router(skins.router)
except Exception as e:
    LoggerService.error(f"Failed to import routes: {e}")
    import traceback
    LoggerService.error(traceback.format_exc())

@app.get("/.well-known/jwks.json")
def get_root_jwks():
    from src.services.JWTService import JWTService
    from fastapi.responses import JSONResponse
    return JSONResponse(
        content=JWTService.get_jwks(),
        media_type="application/jwk-set+json"
    )

@app.get("/")
def read_root():
    return {
        "message": "Luyumi Backend (Python) is running",
        "status": "online"
    }

if __name__ == "__main__":
    import uvicorn
    # In production, we might want to disable reload
    uvicorn.run(app, host="127.0.0.1", port=8080)
