import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/log_service.dart';
import '../utils/logger.dart';

class LogsProvider with ChangeNotifier {
  final LogService _logService = LogService();

  List<LogEntry> _logs = [];
  Timer? _pollTimer;
  StreamSubscription<LogEntry>? _flutterLogSubscription;
  bool _isLoading = false;
  String? _lastTimestamp;

  List<LogEntry> get logs => _logs;
  bool get isLoading => _isLoading;

  /// Initialize the provider and start listening to frontend logs
  void init() {
    // Listen to Flutter logs
    _flutterLogSubscription?.cancel();
    _flutterLogSubscription = Logger.onLog.listen((log) {
      _logs.add(log);
      // Sort by timestamp to ensure correct order
      _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Keep only the last 1000 logs
      if (_logs.length > 1000) {
        _logs = _logs.sublist(_logs.length - 1000);
      }
      notifyListeners();
    });
  }

  /// Start polling logs from backend
  void startBackendPolling({Duration interval = const Duration(milliseconds: 500)}) {
    if (_pollTimer != null && _pollTimer!.isActive) {
      return; // Already polling
    }

    // Don't clear logs here to preserve frontend logs captured during init
    // _logs.clear(); 
    
    // Reset backend timestamp to ensure we get fresh logs from backend
    _lastTimestamp = null;

    // Initial fetch
    _fetchLogs();

    // Poll for new logs
    _pollTimer = Timer.periodic(interval, (_) {
      _fetchLogs();
    });

    notifyListeners();
  }

  /// Stop polling logs
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _flutterLogSubscription?.cancel();
    _flutterLogSubscription = null;
  }

  /// Fetch all logs
  Future<void> fetchAllLogs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final newLogs = await _logService.getAllLogs();
      _logs = newLogs;
      if (_logs.isNotEmpty) {
        _lastTimestamp = _logs.last.timestamp;
      }
    } catch (e) {
      debugPrint('Error fetching all logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch recent logs
  Future<void> fetchRecentLogs({int limit = 50}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newLogs = await _logService.getRecentLogs(limit: limit);
      _logs = newLogs;
      if (_logs.isNotEmpty) {
        _lastTimestamp = _logs.last.timestamp;
      }
    } catch (e) {
      debugPrint('Error fetching recent logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch logs by level
  Future<void> fetchLogsByLevel(String level) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newLogs = await _logService.getLogsByLevel(level);
      _logs = newLogs;
    } catch (e) {
      debugPrint('Error fetching logs by level: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    try {
      final success = await _logService.clearLogs();
      if (success) {
        _logs.clear();
        _lastTimestamp = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
  }

  /// Private method to fetch logs (for polling)
  Future<void> _fetchLogs() async {
    try {
      late List<LogEntry> newLogs;

      if (_lastTimestamp == null) {
        // First fetch, get recent logs
        newLogs = await _logService.getRecentLogs(limit: 100);
      } else {
        // Fetch logs since last timestamp
        newLogs = await _logService.getLogsSince(_lastTimestamp!);
      }

      if (newLogs.isNotEmpty) {
        _logs.addAll(newLogs);
        // Track the last backend log timestamp for polling
        _lastTimestamp = newLogs.last.timestamp;

        // Sort by timestamp to ensure correct order
        _logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Keep only the last 1000 logs to avoid memory issues
        if (_logs.length > 1000) {
          _logs = _logs.sublist(_logs.length - 1000);
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error polling logs: $e');
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
