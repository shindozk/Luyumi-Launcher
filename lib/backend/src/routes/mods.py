from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Any
from ..services.ModService import ModService
from ..services.ModManager import ModManager
from ..services.CurseForgeService import CurseForgeService
from ..services.UIService import UIService

router = APIRouter(prefix="/api/mods", tags=["mods"])

class ModToggleRequest(BaseModel):
    profileId: str
    fileName: str
    enable: bool

class ModDownloadRequest(BaseModel):
    profileId: str
    url: str
    fileName: str
    modInfo: Optional[dict] = None

class ModUninstallRequest(BaseModel):
    profileId: str
    fileName: str

class ModOpenFolderRequest(BaseModel):
    profileId: str

class ModSearchRequest(BaseModel):
    query: str
    index: int
    pageSize: int
    sortField: int
    sortOrder: str

class ModInstallCFRequest(BaseModel):
    downloadUrl: str
    fileName: str
    profileId: str
    modInfo: Optional[dict] = None

@router.get("/{profile_id}")
def get_mods(profile_id: str):
    return ModService.load_installed_mods(profile_id)

@router.post("/toggle")
def toggle_mod(req: ModToggleRequest):
    success = ModService.toggle_mod(req.profileId, req.fileName, req.enable)
    return {"success": success}

@router.get("/details/{mod_id}")
def get_mod_details(mod_id: int):
    details = ModService.get_mod_details(mod_id)
    if not details:
        raise HTTPException(status_code=404, detail="Mod not found")
    return {"data": details}

@router.get("/description/{mod_id}")
def get_mod_description(mod_id: int):
    description = CurseForgeService.get_mod_description(mod_id)
    return {"data": description}

@router.post("/download")
def download_mod(req: ModDownloadRequest):
    result = ModService.download_mod(req.profileId, req.url, req.fileName, req.modInfo)
    return result

@router.post("/uninstall")
def uninstall_mod(req: ModUninstallRequest):
    success = ModService.uninstall_mod(req.profileId, req.fileName)
    return {"success": success}

@router.post("/openFolder")
def open_mods_folder(req: ModOpenFolderRequest):
    path_to_open = ModManager.get_profile_mods_path(req.profileId)
    success = UIService.open_folder(path_to_open)
    return {"success": success}

@router.post("/search")
def search_mods(req: ModSearchRequest):
    """
    Search for Hytale mods on CurseForge API
    
    Request Parameters:
    - query: Search string (empty = popular mods)
    - index: 0-based page index (multiply by pageSize for offset)
    - pageSize: Results per page (max 50)
    - sortField: Sort field (6 = Most Downloaded)
    - sortOrder: 'asc' or 'desc'
    
    Response:
    - data: Array of mod objects
    - pagination: Contains totalCount, index, pageSize
    """
    from ..services.LoggerService import LoggerService
    
    try:
        LoggerService.info("[Mods Route] /search endpoint called")
        LoggerService.info(f"[Mods Route] Parameters received:")
        LoggerService.info(f"  Query: '{req.query}'")
        LoggerService.info(f"  Index: {req.index}, PageSize: {req.pageSize}")
        LoggerService.info(f"  Sort: Field {req.sortField}, Order {req.sortOrder}")
        
        # Call CurseForgeService (which has comprehensive logging)
        results = CurseForgeService.search_mods(
            query=req.query,
            index=req.index,
            page_size=req.pageSize,
            sort_field=req.sortField,
            sort_order=req.sortOrder
        )
        
        # Log results
        mods_count = len(results.get('data', []))
        total_count = results.get('pagination', {}).get('totalCount', 0)
        error = results.get('pagination', {}).get('error')
        
        LoggerService.info(f"[Mods Route] Response prepared: {mods_count} mods, {total_count} total available")
        if error:
            LoggerService.error(f"[Mods Route] Error in response: {error}")
        
        # Return results directly to frontend
        # Frontend expects: { data: [...mods...], pagination: {...} }
        return results
        
    except Exception as e:
        LoggerService.error(f"[Mods Route] ❌ EXCEPTION in /search endpoint")
        LoggerService.error(f"[Mods Route] Error: {str(e)}")
        import traceback
        LoggerService.error(f"[Mods Route] Traceback:\n{traceback.format_exc()}")
        
        # Return gracefully instead of crashing
        return {
            "data": [],
            "pagination": {
                "totalCount": 0,
                "error": str(e)
            }
        }

@router.post("/install-cf")
def install_mod_cf(req: ModInstallCFRequest):
    try:
        # Reuse ModService.download_mod to ensure registration in profile config
        result = ModService.download_mod(req.profileId, req.downloadUrl, req.fileName, req.modInfo)
        return result
    except Exception as e:
        return {"success": False, "error": str(e)}
