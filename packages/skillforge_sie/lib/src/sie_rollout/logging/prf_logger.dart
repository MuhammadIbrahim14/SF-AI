import 'package:flutter/foundation.dart';

/// Structured PRF logging (significant events only).
abstract interface class PrfLogger {
  /// Info.
  void info(String event, [Map<String, Object?>? data]);

  /// Warning.
  void warn(String event, [Map<String, Object?>? data]);

  /// Error.
  void error(String event, [Map<String, Object?>? data, Object? cause]);
}

/// Default logger.
final class DeveloperPrfLogger implements PrfLogger {
  /// Creates logger.
  const DeveloperPrfLogger();

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
    final buf = StringBuffer('[sie.prf][$level] $event');
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

/// No-op.
final class NopPrfLogger implements PrfLogger {
  /// Creates logger.
  const NopPrfLogger();

  @override
  void info(String event, [Map<String, Object?>? data]) {}

  @override
  void warn(String event, [Map<String, Object?>? data]) {}

  @override
  void error(String event, [Map<String, Object?>? data, Object? cause]) {}
}
