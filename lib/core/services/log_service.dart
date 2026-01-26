import 'package:http/http.dart' as http;
import 'dart:convert';
import 'backend_service.dart';

class LogEntry {
  final String timestamp;
  final String level;
  final String message;
  final String? source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.source,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: json['timestamp'] as String,
      level: json['level'] as String,
      message: json['message'] as String,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'level': level,
      'message': message,
      'source': source,
    };
  }
}

class LogService {
  static String get _baseUrl => '${BackendService.baseUrl}/logs';

  /// Get all logs
  Future<List<LogEntry>> getAllLogs() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final logs = (data['logs'] as List)
            .map((log) => LogEntry.fromJson(log as Map<String, dynamic>))
            .toList();
        return logs;
      }
      return [];
    } catch (e) {
      print('Error fetching logs: $e');
      return [];
    }
  }

  /// Get recent logs
  Future<List<LogEntry>> getRecentLogs({int limit = 50}) async {
    try {
      final url = Uri.parse('$_baseUrl/recent?limit=$limit');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final logs = (data['logs'] as List)
            .map((log) => LogEntry.fromJson(log as Map<String, dynamic>))
            .toList();
        return logs;
      }
      return [];
    } catch (e) {
      print('Error fetching recent logs: $e');
      return [];
    }
  }

  /// Get logs since a specific timestamp
  Future<List<LogEntry>> getLogsSince(String timestamp) async {
    try {
      final url = Uri.parse('$_baseUrl/since?timestamp=$timestamp');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final logs = (data['logs'] as List)
            .map((log) => LogEntry.fromJson(log as Map<String, dynamic>))
            .toList();
        return logs;
      }
      return [];
    } catch (e) {
      print('Error fetching logs since timestamp: $e');
      return [];
    }
  }

  /// Get logs by level
  Future<List<LogEntry>> getLogsByLevel(String level) async {
    try {
      final url = Uri.parse('$_baseUrl/level/$level');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final logs = (data['logs'] as List)
            .map((log) => LogEntry.fromJson(log as Map<String, dynamic>))
            .toList();
        return logs;
      }
      return [];
    } catch (e) {
      print('Error fetching logs by level: $e');
      return [];
    }
  }

  /// Clear all logs
  Future<bool> clearLogs() async {
    try {
      final response = await http
          .delete(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error clearing logs: $e');
      return false;
    }
  }
}
