import 'package:uuid/uuid.dart';
import '../config_manager.dart';

class ProfileManager {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final config = await ConfigManager().loadConfig();
    final profiles = config['profiles'];
    if (profiles == null || (profiles is Map && profiles.isEmpty)) {
      await _migrateLegacyConfig(config);
    }
    _initialized = true;
  }

  static Future<void> _migrateLegacyConfig(Map<String, dynamic> config) async {
    const defaultProfileId = "default";
    final now = DateTime.now().toUtc().toIso8601String();
    final mods = config['installedMods'] ?? [];
    final javaPath = config['javaPath'] ?? "";
    
    final defaultProfile = {
      "id": defaultProfileId,
      "name": "Default",
      "created": now,
      "lastUsed": now,
      "mods": mods,
      "javaPath": javaPath,
      "gameOptions": {
        "minMemory": "1G",
        "maxMemory": "4G",
        "args": []
      }
    };
    
    final newConfig = Map<String, dynamic>.from(config);
    newConfig['profiles'] = {defaultProfileId: defaultProfile};
    newConfig['activeProfileId'] = defaultProfileId;
    
    await ConfigManager().saveConfigObject(newConfig);
  }

  static Future<Map<String, dynamic>> createProfile(String name) async {
    if (name.trim().isEmpty) {
      throw Exception("Name cannot be blank");
    }
    final config = await ConfigManager().loadConfig();
    final profiles = Map<String, dynamic>.from(config['profiles'] ?? {});
    final profileId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    
    final profile = {
      "id": profileId,
      "name": name.trim(),
      "created": now,
      "lastUsed": now,
      "mods": [],
      "javaPath": "",
      "gameOptions": {
        "minMemory": "1G",
        "maxMemory": "4G",
        "args": []
      }
    };
    
    profiles[profileId] = profile;
    config['profiles'] = profiles;
    await ConfigManager().saveConfigObject(config);
    return profile;
  }

  static Future<List<Map<String, dynamic>>> getProfiles() async {
    final config = await ConfigManager().loadConfig();
    final profiles = config['profiles'];
    if (profiles is Map) {
      return profiles.values.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getProfile(String profileId) async {
    final config = await ConfigManager().loadConfig();
    final profiles = config['profiles'];
    if (profiles is Map) {
      final profile = profiles[profileId];
      if (profile != null) {
        return Map<String, dynamic>.from(profile);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getActiveProfile() async {
    final config = await ConfigManager().loadConfig();
    final activeId = config['activeProfileId'];
    final profiles = config['profiles'];
    
    if (profiles == null || (profiles is Map && profiles.isEmpty)) {
      return null;
    }
    
    if (activeId != null && profiles is Map && profiles.containsKey(activeId)) {
      return Map<String, dynamic>.from(profiles[activeId]);
    }
    
    if (profiles is Map && profiles.isNotEmpty) {
      return Map<String, dynamic>.from(profiles.values.first);
    }
    return null;
  }

  static Future<Map<String, dynamic>> activateProfile(String profileId) async {
    final config = await ConfigManager().loadConfig();
    final profiles = Map<String, dynamic>.from(config['profiles'] ?? {});
    
    if (!profiles.containsKey(profileId)) {
      throw Exception("Profile not found");
    }
    
    final profile = Map<String, dynamic>.from(profiles[profileId]);
    profile['lastUsed'] = DateTime.now().toUtc().toIso8601String();
    profiles[profileId] = profile;
    
    config['profiles'] = profiles;
    config['activeProfileId'] = profileId;
    await ConfigManager().saveConfigObject(config);
    return profile;
  }

  static Future<bool> deleteProfile(String profileId) async {
    final config = await ConfigManager().loadConfig();
    final profiles = Map<String, dynamic>.from(config['profiles'] ?? {});
    final activeId = config['activeProfileId'];
    
    if (activeId == profileId) {
      throw Exception("Cannot delete the active profile");
    }
    if (profiles.length <= 1) {
      throw Exception("Cannot delete the only remaining profile");
    }
    if (!profiles.containsKey(profileId)) {
      return false;
    }
    
    profiles.remove(profileId);
    config['profiles'] = profiles;
    await ConfigManager().saveConfigObject(config);
    return true;
  }

  static Future<Map<String, dynamic>> updateProfile(String profileId, Map<String, dynamic> updates) async {
    final config = await ConfigManager().loadConfig();
    final profiles = Map<String, dynamic>.from(config['profiles'] ?? {});
    
    if (!profiles.containsKey(profileId)) {
      throw Exception("Profile not found");
    }
    
    final profile = Map<String, dynamic>.from(profiles[profileId]);
    final allowed = {"name", "javaPath", "gameOptions", "mods"};
    
    for (final entry in updates.entries) {
      if (allowed.contains(entry.key)) {
        profile[entry.key] = entry.value;
      }
    }
    
    profiles[profileId] = profile;
    config['profiles'] = profiles;
    await ConfigManager().saveConfigObject(config);
    return profile;
  }
}
