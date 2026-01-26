import '../utils/logger.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/settings_service.dart';
import '../models/game_progress.dart';

class GameManager {
  static int? _currentPid;
  static DateTime? _gameStartTime;

  static Future<Map<String, dynamic>> launchGame({
    String? playerName,
    Function(GameProgress)? onProgress,
    String? javaPathOverride,
    String? uuidOverride,
    int? ramMb,
    String? identityToken,
    String? sessionToken,
    bool fullscreen = true,
    String? profileId,
  }) async {
    try {
      onProgress?.call(GameProgress("Checking backend connection...", 0));
      if (!await BackendService.isOnline()) {
        throw Exception(
          "Backend service is not running. Please restart the launcher.",
        );
      }

      onProgress?.call(GameProgress("Authenticating...", 20));

      // 1. Auth
      Map<String, String> tokens;
      final pid = await PlayerService.getOrCreatePlayerId();
      final userUuid = uuidOverride ?? pid;
      final pName = playerName ?? "Player";

      if (identityToken != null && sessionToken != null) {
        tokens = {'identityToken': identityToken, 'sessionToken': sessionToken};
      } else {
        final authResponse = await AuthService().login(pName, uuid: userUuid);
        tokens = {
          'identityToken': authResponse.identityToken,
          'sessionToken': authResponse.sessionToken,
        };
      }

      // 2. Resolve Java Path from Settings if not overridden
      String? effectiveJavaPath = javaPathOverride;
      try {
        if (effectiveJavaPath == null) {
          final settings = SettingsService();
          if (await settings.getCustomJavaEnabled()) {
            effectiveJavaPath = await settings.getJavaPath();
          }
        }
      } catch (e, stack) {
        Logger.error('Failed to resolve Java path from settings', e, stack);
      }

      // 3. Launch via Backend
      onProgress?.call(GameProgress("Requesting launch...", 60));

      String gpuPreference = 'auto';
      try {
        gpuPreference = await SettingsService().getGpuPreference();
      } catch (e, stack) {
        Logger.error('Failed to get GPU preference', e, stack);
      }

      final result = await BackendService.launchGame(
        playerName: pName,
        uuid: userUuid,
        identityToken: tokens['identityToken']!,
        sessionToken: tokens['sessionToken']!,
        javaPath: effectiveJavaPath,

        profileId: profileId,
        gpuPreference: gpuPreference,
        fullscreen: fullscreen,
        // gameDir: can be omitted to use default
      );

      if (result['success'] == true) {
        onProgress?.call(GameProgress("Game launched!", 100));
        _gameStartTime = DateTime.now();
        _currentPid = result['pid'];
        Logger.info("Game launched via backend. PID: $_currentPid");
        return result;
      } else {
        throw Exception(result['error'] ?? "Unknown error from backend");
      }
    } catch (e, stack) {
      Logger.error("Launch failed: $e", e, stack);
      onProgress?.call(GameProgress("Launch failed: $e", 0));
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRunningGameStatus() async {
    if (_currentPid != null) {
      // We could check if PID is still running using Process.run('ps', ...) or backend check
      // For now just return stored state
      return {
        'isRunning': true,
        'pid': _currentPid,
        'startTime': _gameStartTime?.toIso8601String(),
      };
    }
    return {'isRunning': false};
  }
}
