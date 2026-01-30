import 'dart:async';
import 'dart:developer' as developer;
import '../services/log_service.dart';

class Logger {
  static final StreamController<LogEntry> _logStreamController = StreamController<LogEntry>.broadcast();
  static Stream<LogEntry> get onLog => _logStreamController.stream;

  static void _emit(String level, String message, String source) {
    _logStreamController.add(LogEntry(
      timestamp: DateTime.now().toIso8601String(),
      level: level,
      message: message,
      source: source,
    ));
  }

  static void info(String message, [String name = 'Luyumi']) {
    developer.log(message, name: name, level: 800);
    _emit('info', message, name);
  }

  static void warning(String message, [String name = 'Luyumi']) {
    developer.log(message, name: name, level: 900);
    _emit('warn', message, name);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String name = 'Luyumi']) {
    developer.log(message, name: name, error: error, stackTrace: stackTrace, level: 1000);
    _emit('error', '$message${error != null ? '\n$error' : ''}', name);
  }
  
  static void debug(String message, [String name = 'Luyumi']) {
    developer.log(message, name: name, level: 500);
    _emit('debug', message, name);
  }
}
