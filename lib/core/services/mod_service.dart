import '../models/mod_model.dart';
import '../utils/logger.dart';
import 'backend_service.dart';

class ModService {
  Future<List<ModModel>> getMods(String profileId) async {
    try {
      final modsData = await BackendService.getMods(profileId);

      return modsData
          .map((m) => ModModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      Logger.error('Error fetching mods: $e');
    }
    return [];
  }

  Future<bool> toggleMod(String profileId, String modId, bool enabled) async {
    try {
      // Find filename first
      final mods = await getMods(profileId);
      final mod = mods.firstWhere(
        (m) => m.id == modId,
        orElse: () => ModModel(
          id: '',
          name: '',
          version: '',
          description: '',
          author: '',
          enabled: false,
          fileName: '',
          fileSize: 0,
          dateInstalled: '',
          curseForgeId: null,
          curseForgeFileId: null,
          missing: false,
        ),
      );

      if (mod.id.isEmpty) return false;

      return await BackendService.toggleMod(profileId, mod.fileName, enabled);
    } catch (e) {
      Logger.error('Error toggling mod: $e');
      return false;
    }
  }

  Future<bool> uninstallMod(String profileId, String modId) async {
    try {
      final mods = await getMods(profileId);
      final mod = mods.firstWhere(
        (m) => m.id == modId,
        orElse: () => ModModel(
          id: '',
          name: '',
          version: '',
          description: '',
          author: '',
          enabled: false,
          fileName: '',
          fileSize: 0,
          dateInstalled: '',
          curseForgeId: null,
          curseForgeFileId: null,
          missing: false,
        ),
      );

      if (mod.id.isEmpty) return false;

      return await BackendService.uninstallMod(profileId, mod.fileName);
    } catch (e) {
      Logger.error('Error uninstalling mod: $e');
      return false;
    }
  }

  Future<bool> syncMods(String profileId) async {
    return true;
  }

  Future<Map<String, dynamic>> searchMods(
    String query, {
    int index = 0,
    int pageSize = 20,
    int sortField = 6,
    String sortOrder = 'desc',
  }) async {
    Logger.info(
      '[ModService] searchMods (Backend): query="$query", index=$index, pageSize=$pageSize',
    );

    try {
      final result = await BackendService.searchMods(
        query: query,
        index: index,
        pageSize: pageSize,
        sortField: sortField,
        sortOrder: sortOrder,
      );

      return result;
    } catch (e) {
      Logger.error('[ModService] searchMods (Backend) failed: $e');
      return {};
    }
  }

  Future<bool> installModCF(
    String downloadUrl,
    String fileName,
    String profileId, {
    Map<String, dynamic>? modInfo,
  }) async {
    return await BackendService.installModCF(
      downloadUrl,
      fileName,
      profileId,
      modInfo: modInfo,
    );
  }

  Future<ModModel?> getModDetails(int modId) async {
    try {
      final result = await BackendService.getModDetails(modId);
      final data = result?['data'];

      if (data != null) {
        // Fetch full HTML description as well
        final description = await BackendService.getModDescription(modId);

        final mod = ModModel.fromJson(Map<String, dynamic>.from(data));

        // Return a copy with the full description
        return ModModel(
          id: mod.id,
          name: mod.name,
          version: mod.version,
          description: description.isNotEmpty ? description : mod.description,
          summary: mod.summary,
          author: mod.author,
          enabled: mod.enabled,
          fileName: mod.fileName,
          fileSize: mod.fileSize,
          dateInstalled: mod.dateInstalled,
          curseForgeId: mod.curseForgeId,
          curseForgeFileId: mod.curseForgeFileId,
          missing: mod.missing,
          logoUrl: mod.logoUrl,
          downloadCount: mod.downloadCount,
          categories: mod.categories,
        );
      }
    } catch (e) {
      Logger.error('Error getting mod details via backend: $e');
    }
    return null;
  }

  Future<bool> openModsFolder(String profileId) async {
    return await BackendService.openModsFolder(profileId);
  }
}
