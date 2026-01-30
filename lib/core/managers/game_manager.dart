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
      onProgress?.call(GameProgress("Verificando conexão...", 0));
      
      final pid = await PlayerService.getOrCreatePlayerId();
      final userUuid = uuidOverride ?? pid;
      final pName = playerName ?? "Player";
      
      // 1. Always generate FRESH tokens (don't use cached tokens)
      Map<String, String> tokens;
      bool isOfflineMode = false;
      
      // Always try to get fresh tokens - ignore any provided ones for game launch
      {
        // Try online authentication first
        try {
          onProgress?.call(GameProgress("Autenticando...", 20));
          
          if (!await BackendService.isOnline()) {
            throw Exception("Backend offline");
          }
          
          final authResponse = await AuthService().login(pName, uuid: userUuid);
          tokens = {
            'identityToken': authResponse.identityToken,
            'sessionToken': authResponse.sessionToken,
          };
          Logger.info("Online authentication successful");
        } catch (e) {
          // Fallback directly to offline mode on any auth error
          // If signature verification fails, it's better to use offline than keep trying
          Logger.warning("Auth error detected, using offline mode: $e");
          onProgress?.call(GameProgress("Modo offline...", 20));
          
          isOfflineMode = true;
          
          // Generate offline tokens with proper format
          final authService = AuthService();
          final offlineSession = await authService.generateOfflineSession(pName, userUuid);
          
          tokens = {
            'identityToken': offlineSession['identityToken'] ?? '',
            'sessionToken': offlineSession['sessionToken'] ?? '',
          };
          
          Logger.info("Offline session generated - user can play offline");
        }
      }  // End of always-generate-tokens block

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
      onProgress?.call(GameProgress("Iniciando jogo...", 60));

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
      );

      if (result['success'] == true) {
        final modeLabel = isOfflineMode ? " (Offline)" : "";
        onProgress?.call(GameProgress("Jogo iniciado!$modeLabel", 100));
        _gameStartTime = DateTime.now();
        _currentPid = result['pid'];
        Logger.info("Game launched via backend. PID: $_currentPid, Mode: ${isOfflineMode ? 'Offline' : 'Online'}");
        return result;
      } else {
        throw Exception(result['error'] ?? "Unknown error from backend");
      }
    } catch (e, stack) {
      Logger.error("Launch failed: $e", e, stack);
      onProgress?.call(GameProgress("Falha ao iniciar: $e", 0));
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
