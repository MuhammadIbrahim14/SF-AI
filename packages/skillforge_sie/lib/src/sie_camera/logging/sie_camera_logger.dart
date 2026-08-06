import 'package:flutter/foundation.dart';

/// Structured logging sink for the Camera Engine.
///
/// Purpose: startup/shutdown/errors/recovery without per-frame spam.
abstract interface class SieCameraLogger {
  /// Informational lifecycle event.
  void info(String event, [Map<String, Object?>? data]);

  /// Recoverable issue.
  void warn(String event, [Map<String, Object?>? data]);

  /// Failure.
  void error(String event, [Map<String, Object?>? data, Object? cause]);
}

/// Default logger using [debugPrint] (no frame payloads).
final class DeveloperSieCameraLogger implements SieCameraLogger {
  /// Creates the logger.
  const DeveloperSieCameraLogger();

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
    final buf = StringBuffer('[sie.camera][$level] $event');
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
final class NopSieCameraLogger implements SieCameraLogger {
  /// Creates a no-op logger.
  const NopSieCameraLogger();

  @override
  void info(String event, [Map<String, Object?>? data]) {}

  @override
  void warn(String event, [Map<String, Object?>? data]) {}

  @override
  void error(String event, [Map<String, Object?>? data, Object? cause]) {}
}
