import 'dart:async';
import 'package:uuid/uuid.dart';
import 'backend_service.dart';
import '../utils/logger.dart';

class SkinMonitorService {
  static final SkinMonitorService _instance = SkinMonitorService._internal();

  bool _isMonitoring = false;
  Timer? _statusCheckTimer;
  
  factory SkinMonitorService() {
    return _instance;
  }

  SkinMonitorService._internal();

  bool get isMonitoring => _isMonitoring;

  /// Start monitoring skins for a game directory
  Future<bool> startMonitoring(String gameDir) async {
    try {
      Logger.info('[SkinMonitor] Starting skin monitor for: $gameDir');
      
      final response = await BackendService.post(
        '/api/skins/monitor/start',
        {'game_dir': gameDir},
      );

      if (response['success'] == true) {
        _isMonitoring = true;
        Logger.info('[SkinMonitor] ✓ Monitor started');
        
        // Start periodic status check
        _startStatusCheck();
        
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to start monitoring: $e');
      return false;
    }
  }

  /// Stop monitoring skins
  Future<bool> stopMonitoring() async {
    try {
      Logger.info('[SkinMonitor] Stopping skin monitor');
      
      final response = await BackendService.post(
        '/api/skins/monitor/stop',
        {},
      );

      if (response['success'] == true) {
        _isMonitoring = false;
        _stopStatusCheck();
        Logger.info('[SkinMonitor] ✓ Monitor stopped');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to stop monitoring: $e');
      return false;
    }
  }

  /// Get current monitor status
  Future<Map<String, dynamic>> getMonitorStatus() async {
    try {
      final response = await BackendService.get('/api/skins/monitor/status');
      
      if (response['success'] == true) {
        final isMonitoring = response['is_monitoring'] ?? false;
        _isMonitoring = isMonitoring;
        return response;
      }
      return {'success': false};
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to get status: $e');
      return {'success': false};
    }
  }

  /// Get list of backed up skins
  Future<Map<String, List<String>>> getBackedUpSkins() async {
    try {
      Logger.info('[SkinMonitor] Fetching backed up skins list');
      
      final response = await BackendService.get('/api/skins/backed-up');

      if (response['success'] == true) {
        final skins = response['skins'] ?? {};
        final totalCount = response['total_count'] ?? 0;
        
        Logger.info('[SkinMonitor] Found $totalCount backed up skins');
        
        return Map<String, List<String>>.from(
          skins.map((key, value) => MapEntry(
            key,
            List<String>.from(value ?? []),
          )),
        );
      }
      return {};
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to get skins: $e');
      return {};
    }
  }

  /// Restore skins from backup
  Future<bool> restoreSkins(String gameDir) async {
    try {
      Logger.info('[SkinMonitor] Restoring skins for: $gameDir');
      
      final response = await BackendService.post(
        '/api/skins/restore',
        {'game_dir': gameDir},
      );

      if (response['success'] == true) {
        Logger.info('[SkinMonitor] ✓ Skins restored');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to restore skins: $e');
      return false;
    }
  }

  /// Clear skins repository
  Future<bool> clearRepository() async {
    try {
      Logger.warning('[SkinMonitor] Clearing skins repository');
      
      final response = await BackendService.post(
        '/api/skins/repository/clear',
        {},
      );

      if (response['success'] == true) {
        Logger.info('[SkinMonitor] ✓ Repository cleared');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to clear repository: $e');
      return false;
    }
  }

  /// Get repository path
  Future<String?> getRepositoryPath() async {
    try {
      final response = await BackendService.get('/api/skins/repository/path');

      if (response['success'] == true) {
        return response['repository_path'];
      }
      return null;
    } catch (e) {
      Logger.error('[SkinMonitor] Failed to get repository path: $e');
      return null;
    }
  }

  /// Test skin backup functionality
  Future<bool> testBackup() async {
    try {
      final response = await BackendService.post(
        '/api/skins/test',
        {},
      );

      return response['success'] == true;
    } catch (e) {
      Logger.error('[SkinMonitor] Test failed: $e');
      return false;
    }
  }

  // Private helper methods

  void _startStatusCheck() {
    _stopStatusCheck();
    
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        try {
          await getMonitorStatus();
        } catch (e) {
          Logger.debug('[SkinMonitor] Status check error: $e');
        }
      },
    );
  }

  void _stopStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  void dispose() {
    _stopStatusCheck();
  }
}
