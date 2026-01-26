import '../models/mod_model.dart';
import '../utils/logger.dart';
import 'backend_service.dart';

class ModService {
  Future<List<ModModel>> getMods(String profileId) async {
    try {
      final modsData = await BackendService.getMods(profileId);

      return modsData
          .map(
            (m) => ModModel.fromJson({
              'id': m['id'],
              'name': m['name'] ?? m['fileName'],
              'fileName': m['fileName'],
              'enabled': m['enabled'],
              'version': m['version'] ?? '',
              'description': m['description'] ?? '',
              'author': m['author'] ?? '',
              'fileSize': m['fileSize'] ?? 0,
              'dateInstalled': m['dateInstalled'] ?? DateTime.now().toIso8601String(),
              'curseForgeId': m['curseForgeId'],
              'curseForgeFileId': m['curseForgeFileId'],
              'missing': m['missing'] ?? false,
            }),
          )
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
    // Trigger sync endpoint if we implement it in BackendService
    // For now, launch game triggers it.
    // But we can add BackendService.syncMods(profileId) later.
    return true;
  }

  Future<Map<String, dynamic>> searchMods(
    String query, {
    int index = 0,
    int pageSize = 20,
    int sortField = 6,
    String sortOrder = 'desc',
  }) async {
    return await BackendService.searchMods(
      query: query,
      index: index,
      pageSize: pageSize,
      sortField: sortField,
      sortOrder: sortOrder,
    );
  }

  Future<bool> installModCF(String downloadUrl, String fileName, String profileId) async {
    return await BackendService.installModCF(downloadUrl, fileName, profileId);
  }

  Future<bool> openModsFolder(String profileId) async {
    return await BackendService.openModsFolder(profileId);
  }
}
