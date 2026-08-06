/// Stable feature identifiers for SIE modules.
///
/// Purpose: allow hosts to enable/disable modules without changing engine logic
/// (`sie.` config domain — Document 04 §9).
enum SieFeatureId {
  /// Camera capture subsystem (not streaming itself — capability gate).
  camera,

  /// Hand-tracking / vision provider.
  handTracking,

  /// Virtual cursor (Approach A).
  cursor,

  /// Gesture recognition / intent emission.
  gestures,

  /// Diagnostics counters and health publishing.
  diagnostics,

  /// Developer debug overlay (off by default in release).
  debugOverlay,
}

/// Extension for config key mapping.
extension SieFeatureIdX on SieFeatureId {
  /// Config key under the `sie.feature.*` namespace.
  String get configKey => switch (this) {
        SieFeatureId.camera => 'sie.feature.camera',
        SieFeatureId.handTracking => 'sie.feature.handTracking',
        SieFeatureId.cursor => 'sie.feature.cursor',
        SieFeatureId.gestures => 'sie.feature.gestures',
        SieFeatureId.diagnostics => 'sie.feature.diagnostics',
        SieFeatureId.debugOverlay => 'sie.feature.debugOverlay',
      };
}
