import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String format() {
    final timeStr = DateFormat('HH:mm:ss.SSS').format(timestamp);
    final levelStr = level.name.toUpperCase();
    final buffer = StringBuffer('[$timeStr][$levelStr][$tag] $message');
    if (error != null) {
      buffer.write('\nError: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nStackTrace:\n$stackTrace');
    }
    return buffer.toString();
  }
}

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const int maxLogEntries = 500;
  final List<LogEntry> _logs = [];
  final StreamController<List<LogEntry>> _controller =
      StreamController<List<LogEntry>>.broadcast();

  Stream<List<LogEntry>> get stream => _controller.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  static void info(String tag, String message) {
    _instance._log(LogLevel.info, tag, message);
  }

  static void warn(String tag, String message) {
    _instance._log(LogLevel.warning, tag, message);
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _instance._log(LogLevel.error, tag, message, error, stackTrace);
  }

  void _log(LogLevel level, String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);
    if (_logs.length > maxLogEntries) {
      _logs.removeAt(0);
    }

    _controller.add(List.unmodifiable(_logs));

    // Also print to console for development
    if (kDebugMode) {
      debugPrint(entry.format());
    }
  }

  static void clear() {
    _instance._logs.clear();
    _instance._controller.add(const []);
  }

  static String exportAll() {
    return _instance._logs.map((e) => e.format()).join('\n\n');
  }
}
