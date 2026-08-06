import 'package:flutter/foundation.dart';

/// Structured logging for the Flutter Pointer Bridge.
abstract interface class SiePointerLogger {
  /// Info.
  void info(String event, [Map<String, Object?>? data]);

  /// Warning.
  void warn(String event, [Map<String, Object?>? data]);

  /// Error.
  void error(String event, [Map<String, Object?>? data, Object? cause]);
}

/// Default [debugPrint] logger.
final class DeveloperSiePointerLogger implements SiePointerLogger {
  /// Creates the logger.
  const DeveloperSiePointerLogger();

  @override
  void info(String event, [Map<String, Object?>? data]) {
    debugPrint(_format('INFO', event, data));
  }

  @override
  void warn(String event, [Map<String, Object?>? data]) {
    debugPrint(_format('WARN', event, data));
  }

  @override
  void error(String event, [Map<String, Object?>? data, Object? cause]) {
    debugPrint(_format('ERROR', event, data, cause));
  }

  static String _format(
    String level,
    String event,
    Map<String, Object?>? data, [
    Object? cause,
  ]) {
    final buf = StringBuffer('[sie.pointer][$level] $event');
    if (data != null && data.isNotEmpty) {
      buf.write(' ');
      buf.write(data);
    }
    if (cause != null) {
      buf.write(' cause=');
      buf.write(cause);
    }
    return buf.toString();
  }
}

/// Silent logger for tests.
final class NopSiePointerLogger implements SiePointerLogger {
  /// Creates a no-op logger.
  const NopSiePointerLogger();

  @override
  void info(String event, [Map<String, Object?>? data]) {}

  @override
  void warn(String event, [Map<String, Object?>? data]) {}

  @override
  void error(String event, [Map<String, Object?>? data, Object? cause]) {}
}
