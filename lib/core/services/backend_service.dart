import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class BackendService {
  static const String baseUrl = 'http://localhost:8080';
  static const Duration timeout = Duration(seconds: 10);

  static Future<bool> isOnline() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Auth
  static Future<Map<String, dynamic>> login(String name, String uuid) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/game-session/child'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'uuid': uuid,
              'scopes': ['hytale:server', 'hytale:client'],
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Auth failed: ${response.body}');
      }
    } catch (e) {
      Logger.error('Backend auth failed: $e');
      rethrow;
    }
  }

  // Game Launch
  static Future<Map<String, dynamic>> launchGame({
    required String playerName,
    required String uuid,
    required String identityToken,
    required String sessionToken,
    String? javaPath,
    String? gameDir,
    int? width,
    int? height,
    bool? fullscreen,
    String? server,
    String? profileId,
    String? gpuPreference,
  }) async {
    final uri = Uri.parse('$baseUrl/api/game/launch');
    final body = {
      'playerName': playerName,
      'uuid': uuid,
      'identityToken': identityToken,
      'sessionToken': sessionToken,
      if (javaPath != null) 'javaPath': javaPath,
      if (gameDir != null) 'gameDir': gameDir,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fullscreen != null) 'fullscreen': fullscreen,

      if (server != null) 'server': server,
      if (profileId != null) 'profileId': profileId,
      if (gpuPreference != null) 'gpuPreference': gpuPreference,
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Backend returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      Logger.error('Failed to request game launch: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRunningGameStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/game/status/running'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Don't log error here as it runs periodically and spams logs if backend is down
    }
    return {'isRunning': false};
  }

  static Future<Map<String, dynamic>> getGameStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/game/status'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to fetch game status: $e');
    }
    return {
      'installed': false,
      'corrupted': false,
      'reasons': ['Backend unavailable'],
    };
  }

  static Future<Map<String, dynamic>> installGame({String? version}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/game/install'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({if (version != null) 'version': version}),
          )
          .timeout(const Duration(minutes: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      Logger.error('Failed to install game: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getInstallProgress() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/game/install/progress'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to get install progress: $e');
    }
    return {'percent': 0, 'message': '', 'status': 'idle'};
  }

  static Future<Map<String, dynamic>> updateGame({String? version}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/game/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({if (version != null) 'version': version}),
          )
          .timeout(const Duration(minutes: 20));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to update game: $e');
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> repairGame({String? version}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/game/repair'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({if (version != null) 'version': version}),
          )
          .timeout(const Duration(minutes: 20));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to repair game: $e');
    }
    return {'success': false};
  }

  static Future<bool> uninstallGame() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/game/uninstall'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(minutes: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      Logger.error('Failed to uninstall game: $e');
    }
    return false;
  }

  // News
  static Future<List<dynamic>> getNews() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/news'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to fetch news: $e');
    }
    return [];
  }

  // Version
  static Future<Map<String, dynamic>> getClientVersion() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/version/client'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to fetch version: $e');
    }
    return {'client_version': '0.1.0-release', 'download_url': ''};
  }

  // Mods
  static Future<List<dynamic>> getMods(String profileId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/mods/$profileId'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to fetch mods: $e');
    }
    return [];
  }

  static Future<bool> toggleMod(
    String profileId,
    String fileName,
    bool enable,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mods/toggle'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'profileId': profileId,
              'fileName': fileName,
              'enable': enable,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      Logger.error('Failed to toggle mod: $e');
    }
    return false;
  }

  static Future<bool> downloadMod(
    String profileId,
    String url,
    String fileName,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mods/download'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'profileId': profileId,
              'url': url,
              'fileName': fileName,
            }),
          )
          .timeout(const Duration(minutes: 5)); // Longer timeout for downloads

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      Logger.error('Failed to download mod: $e');
    }
    return false;
  }

  static Future<bool> uninstallMod(String profileId, String fileName) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mods/uninstall'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'profileId': profileId, 'fileName': fileName}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      Logger.error('Failed to uninstall mod: $e');
    }
    return false;
  }

  static Future<bool> openModsFolder(String profileId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mods/openFolder'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'profileId': profileId}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      Logger.error('Failed to open mods folder: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>> searchMods({
    String query = '',
    int index = 0,
    int pageSize = 20,
    int sortField = 6, // Popularity by default (Hytale-F2P uses 6)
    String sortOrder = 'desc',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mods/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'index': index,
              'pageSize': pageSize,
              'sortField': sortField,
              'sortOrder': sortOrder,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        Logger.error('Backend search mods error: ${response.body}');
      }
    } catch (e) {
      Logger.error('Failed to search mods: $e');
    }
    return {};
  }

  static Future<bool> installModCF(
    String downloadUrl,
    String fileName,
    String profileId,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mods/install-cf'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'downloadUrl': downloadUrl,
              'fileName': fileName,
              'profileId': profileId,
            }),
          )
          .timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      Logger.error('Failed to install mod from CF: $e');
    }
    return false;
  }

  // Java
  static Future<Map<String, dynamic>> detectJava() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/java/detect'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      Logger.error('Failed to detect java: $e');
    }
    return {};
  }

  static Future<String?> resolveJava(String path) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/java/resolve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'path': path}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['resolved'];
      }
    } catch (e) {
      Logger.error('Failed to resolve java: $e');
    }
    return null;
  }

  /// Generic GET request
  static Future<dynamic> get(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      Logger.error('GET $endpoint failed: $e');
      rethrow;
    }
  }

  /// Generic POST request
  static Future<dynamic> post(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      Logger.error('POST $endpoint failed: $e');
      rethrow;
    }
  }
}
