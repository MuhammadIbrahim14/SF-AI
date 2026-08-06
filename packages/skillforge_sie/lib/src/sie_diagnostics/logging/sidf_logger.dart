import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';

/// Structured SIDF logger (never logs raw frames).
abstract interface class SidfLogger {
  /// Log at [level].
  void log(
    SidfLogLevel level,
    String event, [
    Map<String, Object?>? data,
  ]);
}

/// Default debugPrint logger.
final class DeveloperSidfLogger implements SidfLogger {
  /// Creates logger.
  const DeveloperSidfLogger({this.minLevel = SidfLogLevel.debug});

  /// Minimum level.
  final SidfLogLevel minLevel;

  @override
  void log(
    SidfLogLevel level,
    String event, [
    Map<String, Object?>? data,
  ]) {
    if (level.index < minLevel.index) return;
    final safe = <String, Object?>{};
    if (data != null) {
      for (final e in data.entries) {
        final k = e.key.toLowerCase();
        if (k.contains('framebytes') ||
            k.contains('imagebytes') ||
            k.contains('pixels') ||
            k.contains('yuv') ||
            k == 'rgba' ||
            k.contains('rawframe')) {
          continue;
        }
        safe[e.key] = e.value;
      }
    }
    debugPrint('[sie.sidf][${level.name.toUpperCase()}] $event $safe');
  }
}

/// No-op.
final class NopSidfLogger implements SidfLogger {
  /// Creates logger.
  const NopSidfLogger();

  @override
  void log(
    SidfLogLevel level,
    String event, [
    Map<String, Object?>? data,
  ]) {}
}
