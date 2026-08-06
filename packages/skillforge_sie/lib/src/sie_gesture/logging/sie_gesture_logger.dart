import 'package:flutter/foundation.dart';

/// Structured logging for the Gesture Engine.
abstract interface class SieGestureLogger {
  /// Info.
  void info(String event, [Map<String, Object?>? data]);

  /// Warning.
  void warn(String event, [Map<String, Object?>? data]);

  /// Error.
  void error(String event, [Map<String, Object?>? data, Object? cause]);
}

/// Default [debugPrint] logger.
final class DeveloperSieGestureLogger implements SieGestureLogger {
  /// Creates the logger.
  const DeveloperSieGestureLogger();

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
    final buf = StringBuffer('[sie.gesture][$level] $event');
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
final class NopSieGestureLogger implements SieGestureLogger {
  /// Creates a no-op logger.
  const NopSieGestureLogger();

  @override
  void info(String event, [Map<String, Object?>? data]) {}

  @override
  void warn(String event, [Map<String, Object?>? data]) {}

  @override
  void error(String event, [Map<String, Object?>? data, Object? cause]) {}
}
