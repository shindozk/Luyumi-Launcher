from fastapi import APIRouter
from ..services.VersionService import VersionService

router = APIRouter(prefix="/api/version")

@router.get("/client")
def get_client_version():
    version = VersionService.get_latest_version()
    url = VersionService.get_patch_url(version)
    formatted = VersionService.get_formatted_version_name()
    return {
        "client_version": version,
        "download_url": url,
        "formatted_version": formatted
    }

@router.get("/patch-url")
def get_patch_url(version: str = None, channel: str = 'release'):
    if not version:
        version = VersionService.get_latest_version()
    
    url = VersionService.get_patch_url(version, channel)
    return {
        "url": url
    }
