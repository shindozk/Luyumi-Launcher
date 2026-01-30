import 'managers/game_manager.dart';
import 'utils/logger.dart';
import 'models/game_progress.dart';

class GameLauncher {
  Future<void> launchGame({
    required String clientPath, // Unused, GameManager finds it
    required String playerName,
    required String uuid,
    required String identityToken,
    required String sessionToken,
    String? javaPathOverride,
    int ramMb = 4096,
    bool fullscreen = true, // Handled by GameManager via Settings.json
    String? profileId,
    Function(GameProgress)? onProgress,
  }) async {
    Logger.info('Requesting game launch via GameManager for $playerName...');

    try {
      await GameManager.launchGame(
        playerName: playerName,
        javaPathOverride: javaPathOverride,
        uuidOverride: uuid,
        ramMb: ramMb,
        identityToken: identityToken,
        sessionToken: sessionToken,
        profileId: profileId,
        fullscreen: fullscreen,
        onProgress: (progress) {
          Logger.info(
            "Launch progress: ${progress.message} (${progress.percent}%)",
          );
          onProgress?.call(progress);
        },
      );
      Logger.info('Game launch requested successfully.');
    } catch (e) {
      Logger.error('Error launching game: $e');
      rethrow;
    }
  }
}
