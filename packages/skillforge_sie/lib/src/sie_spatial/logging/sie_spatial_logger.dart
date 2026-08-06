import 'package:flutter/foundation.dart';

/// Structured logging for the Spatial Coordinate Engine.
abstract interface class SieSpatialLogger {
  /// Info.
  void info(String event, [Map<String, Object?>? data]);

  /// Warning.
  void warn(String event, [Map<String, Object?>? data]);

  /// Error.
  void error(String event, [Map<String, Object?>? data, Object? cause]);
}

/// Default [debugPrint] logger.
final class DeveloperSieSpatialLogger implements SieSpatialLogger {
  /// Creates the logger.
  const DeveloperSieSpatialLogger();

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
    final buf = StringBuffer('[sie.spatial][$level] $event');
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
final class NopSieSpatialLogger implements SieSpatialLogger {
  /// Creates a no-op logger.
  const NopSieSpatialLogger();

  @override
  void info(String event, [Map<String, Object?>? data]) {}

  @override
  void warn(String event, [Map<String, Object?>? data]) {}

  @override
  void error(String event, [Map<String, Object?>? data, Object? cause]) {}
}
