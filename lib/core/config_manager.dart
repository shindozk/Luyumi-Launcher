import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ConfigManager {
  static const String _defaultAuthDomain = 'sanasol.ws';

  Future<String> getAppDir() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA']; // Changed from LOCALAPPDATA to APPDATA (Roaming)
      if (appData != null) {
        return path.join(appData, 'LuyumiLauncher');
      }
    }
    // Fallback or other platforms
    final docDir = await getApplicationDocumentsDirectory();
    return path.join(docDir.path, 'LuyumiLauncher');
  }

  Future<String> getDefaultAppDirPath() async {
    return getAppDir();
  }

  Future<String> _configFilePath() async {
    final appDir = await getAppDir();
    return path.join(appDir, 'config.json');
  }

  Future<Map<String, dynamic>> loadConfig() async {
    final file = File(await _configFilePath());
    if (!await file.exists()) {
      return {};
    }
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveConfig(Map<String, dynamic> update) async {
    final current = await loadConfig();
    current.addAll(update);
    await saveConfigObject(current);
  }

  Future<void> saveConfigObject(Map<String, dynamic> config) async {
    final file = File(await _configFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config));
  }

  Future<String> getAuthDomain() async {
    final env = Platform.environment['HYTALE_AUTH_DOMAIN'];
    if (env != null && env.trim().isNotEmpty) {
      return env.trim();
    }
    final config = await loadConfig();
    final domain = config['authDomain'];
    if (domain is String && domain.trim().isNotEmpty) {
      return domain.trim();
    }
    return _defaultAuthDomain;
  }

  Future<String> getAuthServerUrl() async {
    final domain = await getAuthDomain();
    return 'https://sessions.$domain';
  }

  Future<String> getGameDir() async {
    final appDir = await getAppDir();
    return path.join(appDir, 'release', 'package', 'game', 'latest');
  }
  
  Future<String> getToolsDir() async {
    final appDir = await getAppDir();
    return path.join(appDir, 'butler');
  }

  Future<String> getJavaPath() async {
    return await loadJavaPath();
  }

  Future<String> getJreDir() async {
    final appDir = await getAppDir();
    return path.join(appDir, 'release', 'package', 'jre', 'latest');
  }

  Future<void> saveAuthDomain(String? domain) async {
    await saveConfig({'authDomain': (domain == null || domain.trim().isEmpty) ? _defaultAuthDomain : domain.trim()});
  }

  Future<void> saveUsername(String? username) async {
    await saveConfig({'username': (username == null || username.trim().isEmpty) ? 'LuyumiPlayer' : username.trim()});
  }

  Future<String> loadUsername() async {
    final config = await loadConfig();
    final value = config['username'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return 'LuyumiPlayer';
  }

  Future<void> saveChatUsername(String? chatUsername) async {
    await saveConfig({'chatUsername': chatUsername ?? ''});
  }

  Future<String> loadChatUsername() async {
    final config = await loadConfig();
    final value = config['chatUsername'];
    if (value is String) {
      return value;
    }
    return '';
  }

  Future<void> saveChatColor(String? color) async {
    await saveConfig({'chatColor': color ?? '#3498db'});
  }

  Future<String> loadChatColor() async {
    final config = await loadConfig();
    final value = config['chatColor'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return '#3498db';
  }

  Future<void> saveJavaPath(String? javaPath) async {
    await saveConfig({'javaPath': (javaPath ?? '').trim()});
  }

  Future<String> loadJavaPath() async {
    final config = await loadConfig();
    final activeId = config['activeProfileId'];
    final profiles = config['profiles'];
    if (activeId is String && profiles is Map && profiles.containsKey(activeId)) {
      final profile = profiles[activeId];
      if (profile is Map) {
        final profileJava = profile['javaPath'];
        if (profileJava is String && profileJava.isNotEmpty) {
          return profileJava;
        }
      }
    }
    final value = config['javaPath'];
    if (value is String) {
      return value;
    }
    return '';
  }

  Future<void> saveInstallPath(String? installPath) async {
    await saveConfig({'installPath': (installPath ?? '').trim()});
  }

  Future<String> loadInstallPath() async {
    final config = await loadConfig();
    final value = config['installPath'];
    if (value is String) {
      return value;
    }
    return '';
  }

  Future<void> saveDiscordRpc(bool enabled) async {
    await saveConfig({'discordRPC': enabled});
  }

  Future<void> saveCloseLauncherOnStart(bool enabled) async {
    await saveConfig({'closeLauncherOnStart': enabled});
  }

  Future<bool> loadCloseLauncherOnStart() async {
    final config = await loadConfig();
    final value = config['closeLauncherOnStart'];
    if (value is bool) {
      return value;
    }
    return false;
  }

  Future<bool> loadDiscordRpc() async {
    final config = await loadConfig();
    final value = config['discordRPC'];
    if (value is bool) {
      return value;
    }
    return true;
  }

  Future<void> saveLanguage(String? language) async {
    await saveConfig({'language': language ?? 'en'});
  }

  Future<String> loadLanguage() async {
    final config = await loadConfig();
    final value = config['language'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return 'en';
  }

  Future<void> saveModsToConfig(List<dynamic> mods) async {
    final config = await loadConfig();
    final activeId = config['activeProfileId'];
    final profiles = config['profiles'];
    if (activeId is String && profiles is Map && profiles.containsKey(activeId)) {
      final profile = Map<String, dynamic>.from(profiles[activeId]);
      profile['mods'] = mods;
      profiles[activeId] = profile;
      config['profiles'] = profiles;
    } else {
      config['installedMods'] = mods;
    }
    await saveConfigObject(config);
  }

  Future<List<dynamic>> loadModsFromConfig() async {
    final config = await loadConfig();
    final activeId = config['activeProfileId'];
    final profiles = config['profiles'];
    if (activeId is String && profiles is Map && profiles.containsKey(activeId)) {
      final profile = profiles[activeId];
      if (profile is Map && profile['mods'] is List) {
        return List<dynamic>.from(profile['mods']);
      }
    }
    final mods = config['installedMods'];
    if (mods is List) {
      return List<dynamic>.from(mods);
    }
    return [];
  }

  Future<bool> isFirstLaunch() async {
    final config = await loadConfig();
    final hasLaunched = config['hasLaunchedBefore'];
    if (hasLaunched is bool) {
      return !hasLaunched;
    }
    const keys = ['installPath', 'username', 'javaPath', 'chatUsername', 'userUuids'];
    final hasUserData = keys.any(config.containsKey) || config.isNotEmpty;
    return !hasUserData;
  }

  Future<void> markAsLaunched() async {
    await saveConfig({
      'hasLaunchedBefore': true,
      'firstLaunchDate': DateTime.now().toUtc().toIso8601String()
    });
  }

  Future<String> getUuidForUser(String username) async {
    final config = await loadConfig();
    final userUuids = Map<String, dynamic>.from(config['userUuids'] ?? {});
    final existing = userUuids[username];
    if (existing is String && existing.isNotEmpty) {
      return existing;
    }
    final newUuid = const Uuid().v4();
    userUuids[username] = newUuid;
    config['userUuids'] = userUuids;
    await saveConfigObject(config);
    return newUuid;
  }

  Future<String> getCurrentUuid() async {
    final username = await loadUsername();
    return getUuidForUser(username);
  }

  Future<Map<String, dynamic>> getAllUuidMappings() async {
    final config = await loadConfig();
    final value = config['userUuids'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  Future<String> setUuidForUser(String username, String uuidValue) async {
    final config = await loadConfig();
    final userUuids = Map<String, dynamic>.from(config['userUuids'] ?? {});
    userUuids[username] = uuidValue;
    config['userUuids'] = userUuids;
    await saveConfigObject(config);
    return uuidValue;
  }

  Future<String> generateNewUuid() async {
    return const Uuid().v4();
  }

  Future<bool> deleteUuidForUser(String username) async {
    final config = await loadConfig();
    final userUuids = Map<String, dynamic>.from(config['userUuids'] ?? {});
    if (!userUuids.containsKey(username)) {
      return false;
    }
    userUuids.remove(username);
    config['userUuids'] = userUuids;
    await saveConfigObject(config);
    return true;
  }

  Future<String> resetCurrentUserUuid() async {
    final username = await loadUsername();
    final newUuid = const Uuid().v4();
    return setUuidForUser(username, newUuid);
  }

  Future<void> saveGpuPreference(String? preference) async {
    await saveConfig({'gpuPreference': preference ?? 'auto'});
  }

  Future<String> loadGpuPreference() async {
    final config = await loadConfig();
    final value = config['gpuPreference'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return 'auto';
  }

  Future<String> getConfigFilePath() async {
    return _configFilePath();
  }

  Future<String> getCacheDir() async {
    final appDir = await getAppDir();
    final dir = path.join(appDir, 'cache');
    await Directory(dir).create(recursive: true);
    return dir;
  }

  Future<String> getUserDataDir() async {
    final gameDir = await getGameDir();
    return path.join(gameDir, 'userData');
  }


  Future<String> getModsPath() async {
    final gameDir = await getGameDir();
    return path.join(gameDir, 'mods');
  }

  Future<String?> findClientPath(String gameDir) async {
    final candidates = <String>[];
    if (Platform.isWindows) {
      candidates.addAll([
        path.join(gameDir, 'Hytale.exe'),
        path.join(gameDir, 'Client', 'Hytale.exe'),
        path.join(gameDir, 'HytaleClient.exe'),
      ]);
    } else if (Platform.isLinux) {
      candidates.addAll([
        path.join(gameDir, 'Hytale.x86_64'),
        path.join(gameDir, 'Client', 'Hytale.x86_64'),
        path.join(gameDir, 'Hytale'),
        path.join(gameDir, 'Client', 'Hytale'),
      ]);
    } else if (Platform.isMacOS) {
       candidates.addAll([
        path.join(gameDir, 'Hytale.app'),
        path.join(gameDir, 'Client', 'Hytale.app'),
      ]);
    }
    
    for (final c in candidates) {
      if (await File(c).exists() || await Directory(c).exists()) {
        return c;
      }
    }
    return null;
  }

}
