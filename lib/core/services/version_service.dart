import 'dart:async';
import 'package:path/path.dart' as path;
import '../managers/game_manager.dart';
import '../models/game_progress.dart';
import '../models/version_info.dart';
import '../models/game_status.dart';
import '../models/first_launch_status.dart';
import '../models/launcher_update_info.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import '../utils/file_manager.dart';
import '../config_manager.dart';
import '../services/settings_service.dart';
import 'backend_service.dart';

class VersionService {
  static const String _patchRootUrl = 'https://game-patches.hytale.com/patches';

  Future<VersionInfo> getLatestVersion() async {
    try {
      final data = await BackendService.getClientVersion();
      final version = data['client_version'];
      final downloadUrl = data['download_url'];

      if (version is! String || version.trim().isEmpty) {
        throw Exception('Invalid version payload from backend');
      }

      // Use backend provided URL if available, otherwise build locally (fallback)
      final url = (downloadUrl is String && downloadUrl.isNotEmpty)
          ? downloadUrl
          : _buildPatchUrl(version.trim(), channel: 'release');

      return VersionInfo(latestVersion: version.trim(), downloadUrl: url);
    } catch (e) {
      Logger.error('Failed to fetch latest version info via backend', e);
      rethrow;
    }
  }

  String _buildPatchUrl(String version, {required String channel}) {
    final osName = PlatformUtils.getOsName();
    final arch = _resolvePatchArch();
    final fileName = version.endsWith('.pwr') ? version : '$version.pwr';
    return '$_patchRootUrl/$osName/$arch/$channel/0/$fileName';
  }

  String _resolvePatchArch() {
    final arch = PlatformUtils.getArch().toLowerCase();
    if (arch.contains('arm64')) return 'arm64';
    return 'amd64';
  }

  Future<GameStatus> getGameStatus() async {
    try {
      final health = await BackendService.getGameStatus();
      final latest = health['latestVersion'] as String? ?? '0.1.0-release';
      final installed = health['installed'] ?? false;

      // Basic check: if installed, assume up to date for now unless we store local version.
      // Ideally backend sends 'version' of installed game.
      // For now, we update 'latestVersion' in the UI.

      return GameStatus(
        installed: installed,
        corrupted: health['corrupted'] ?? false,
        reasons: List<String>.from(health['reasons'] ?? []),
        gameDir: health['gameDir'],
        clientPath: health['clientPath'],
        updateAvailable: false, // TODO: Store installed version to compare
        latestVersion: latest,
      );
    } catch (e) {
      return GameStatus(
        installed: false,
        corrupted: false,
        reasons: [e.toString()],
        updateAvailable: false,
        latestVersion: '0.1.0-release',
      );
    }
  }

  Future<Map<String, dynamic>> getRunningGameStatus() async {
    final backendStatus = await BackendService.getRunningGameStatus();
    
    if (backendStatus['isRunning'] == true) {
      // 1. Prefer Backend Start Time (Works in Release Mode)
      if (backendStatus['startTime'] != null) {
        final ms = backendStatus['startTime'];
        if (ms is num) {
          // Frontend expects Seconds, Backend sends Milliseconds
          return {
            ...backendStatus,
            'startTime': (ms / 1000).floor(),
          };
        }
      }

      // 2. Fallback to Local State (Debug/Legacy)
      final localStatus = await GameManager.getRunningGameStatus();
      if (localStatus['isRunning'] == true && localStatus['startTime'] != null) {
        final localStart = localStatus['startTime'];
        
        // Handle ISO String from GameManager
        if (localStart is String) {
          try {
            final dt = DateTime.parse(localStart);
            return {
              ...backendStatus,
              'startTime': (dt.millisecondsSinceEpoch / 1000).floor(),
            };
          } catch (_) {}
        }
        // Handle Int/Num (Seconds)
        else if (localStart is num) {
           return {
            ...backendStatus,
            'startTime': localStart.toInt(),
          };
        }
      }
      return backendStatus;
    }
    
    return {'isRunning': false};
  }

  Future<bool> uninstallGame() async {
    return await BackendService.uninstallGame();
  }

  Future<Map<String, dynamic>> installGameWithProgress(
    void Function(GameProgress) onProgress,
  ) async {
    onProgress(GameProgress("Preparing installation...", 0));
    
    // Start polling in background
    Timer? timer;
    final completer = Completer<void>();
    
    timer = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      final progress = await BackendService.getInstallProgress();
      final percentValue = (progress['percent'] as num?)?.toDouble() ?? 0;
      final messageValue = progress['message'] as String? ?? '';
      final statusValue = progress['status'] as String? ?? 'idle';
      if (!completer.isCompleted &&
          (statusValue != 'idle' ||
              percentValue > 0 ||
              messageValue.isNotEmpty)) {
        onProgress(GameProgress(messageValue, percentValue));
      }
    });

    try {
      final result = await BackendService.installGame();
      completer.complete();
      timer.cancel();
      
      final success = result['success'] == true;
      final error = result['error'];
      onProgress(
        GameProgress(
          success ? "Installation complete" : "Installation failed",
          100,
        ),
      );
      return {
        'success': success,
        if (error != null) 'error': error
      };
    } catch (e) {
      completer.complete();
      timer.cancel();
      onProgress(GameProgress("Installation failed: $e", 100));
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  Future<bool> updateGameWithProgress(
    void Function(GameProgress) onProgress,
  ) async {
    onProgress(GameProgress("Preparing update...", 0));

    // Start polling in background
    Timer? timer;
    final completer = Completer<void>();
    
    timer = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      final progress = await BackendService.getInstallProgress();
      final percentValue = (progress['percent'] as num?)?.toDouble() ?? 0;
      final messageValue = progress['message'] as String? ?? '';
      final statusValue = progress['status'] as String? ?? 'idle';
      if (!completer.isCompleted &&
          (statusValue != 'idle' ||
              percentValue > 0 ||
              messageValue.isNotEmpty)) {
        onProgress(GameProgress(messageValue, percentValue));
      }
    });

    try {
      final result = await BackendService.updateGame();
      completer.complete();
      timer.cancel();

      final success = result['success'] == true;
      onProgress(
        GameProgress(success ? "Update complete" : "Update failed", 100),
      );
      return success;
    } catch (e) {
      completer.complete();
      timer.cancel();
      onProgress(GameProgress("Update failed: $e", 100));
      return false;
    }
  }

  Future<bool> repairGame(void Function(GameProgress) onProgress) async {
    onProgress(GameProgress("Preparing repair...", 0));
    
    // Start polling in background
    Timer? timer;
    final completer = Completer<void>();
    
    timer = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      final progress = await BackendService.getInstallProgress();
      final percentValue = (progress['percent'] as num?)?.toDouble() ?? 0;
      final messageValue = progress['message'] as String? ?? '';
      final statusValue = progress['status'] as String? ?? 'idle';
      if (!completer.isCompleted &&
          (statusValue != 'idle' ||
              percentValue > 0 ||
              messageValue.isNotEmpty)) {
        onProgress(GameProgress(messageValue, percentValue));
      }
    });

    try {
      final result = await BackendService.repairGame();
      completer.complete();
      timer.cancel();

      final success = result['success'] == true;
      onProgress(
        GameProgress(success ? "Repair complete" : "Repair failed", 100),
      );
      return success;
    } catch (e) {
      completer.complete();
      timer.cancel();
      onProgress(GameProgress("Repair failed: $e", 100));
      return false;
    }
  }

  Future<FirstLaunchStatus> getFirstLaunchStatus() async {
    try {
      // Prefer config-based check; fallback to prefs
      final isFirst = await ConfigManager().isFirstLaunch();
      return FirstLaunchStatus(
        isFirstLaunch: isFirst,
        needsUpdate: isFirst,
        error: null,
      );
    } catch (e) {
      return FirstLaunchStatus(
        isFirstLaunch: false,
        needsUpdate: false,
        error: e.toString(),
      );
    }
  }

  Future<FirstLaunchStatus> acceptFirstLaunchUpdate() async {
    try {
      await ConfigManager().markAsLaunched();
      return FirstLaunchStatus(
        isFirstLaunch: false,
        needsUpdate: false,
        error: null,
      );
    } catch (e) {
      return FirstLaunchStatus(
        isFirstLaunch: false,
        needsUpdate: false,
        error: e.toString(),
      );
    }
  }

  Future<void> setCloseLauncherOnStart(bool value) async {
    await SettingsService().setCloseLauncherOnStart(value);
  }

  Future<bool> getCloseLauncherOnStart() async {
    return await SettingsService().getCloseLauncherOnStart();
  }

  Future<bool> setInstallPath(String installPath) async {
    try {
      await ConfigManager().saveInstallPath(installPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openGameFolder() async {
    final status = await BackendService.getGameStatus();
    final gameDir = status['gameDir'] ?? await ConfigManager().getGameDir();
    return await FileManager.openFolder(gameDir);
  }

  Future<LauncherUpdateInfo?> checkLauncherUpdates() async {
    // TODO: Implement actual launcher update check
    return LauncherUpdateInfo(
      updateAvailable: false,
      version: "1.0.0",
      downloadUrl: "",
    );
  }

  Future<String> getLogs() async {
    try {
      final logs = await BackendService.get('/api/game/logs');
      return logs is String ? logs : "";
    } catch (_) {
      return "";
    }
  }

  Future<bool> openLogsFolder() async {
    try {
      final gameDir = await ConfigManager().getGameDir();
      final logsDir = path.join(gameDir, "logs");
      return await FileManager.openFolder(logsDir);
    } catch (_) {
      return false;
    }
  }
}
