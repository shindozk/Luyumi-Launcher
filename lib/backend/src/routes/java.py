from fastapi import APIRouter
from pydantic import BaseModel
from ..services.JavaService import JavaService

router = APIRouter(prefix="/api/java", tags=["java"])

class JavaResolveRequest(BaseModel):
    path: str

@router.get("/detect")
def detect_java():
    # Use existing JavaService logic
    try:
        java_path = JavaService.detect_system_java()
        version = JavaService.get_java_version(java_path) if java_path else None
        return {
            "path": java_path,
            "version": version,
            "valid": java_path is not None
        }
    except:
        return {}

@router.post("/resolve")
def resolve_java(req: JavaResolveRequest):
    try:
        resolved = JavaService.resolve_java_path(req.path)
        return {"resolved": resolved}
    except:
        return {"resolved": None}
