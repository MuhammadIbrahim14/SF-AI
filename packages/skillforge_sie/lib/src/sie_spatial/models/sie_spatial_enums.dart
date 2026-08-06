/// How camera content is fitted into the Flutter view.
enum SieViewportFitMode {
  /// Letterbox / pillarbox — preserve aspect (default).
  contain,

  /// Fill view and crop overflow.
  cover,
}

/// Camera / sensor orientation used for upright mapping.
enum SieCameraOrientation {
  /// 0° — upright.
  rotation0,

  /// 90° clockwise.
  rotation90,

  /// 180°.
  rotation180,

  /// 270° clockwise (90° counter-clockwise).
  rotation270,
}

/// Mirror policy for front / user-facing cameras.
enum SieMirrorPolicy {
  /// No mirroring.
  none,

  /// Mirror horizontally (selfie default).
  horizontal,

  /// Host decides via [SieViewportGeometry.mirrorHorizontal].
  configurable,
}

/// Spatial engine health.
enum SieSpatialEngineHealth {
  /// Not started.
  idle,

  /// Ready / processing.
  healthy,

  /// Recoverable issues (invalid viewport, etc.).
  degraded,

  /// Fatal.
  error,

  /// Disposed.
  disposed,
}

/// Extension helpers for orientation degrees.
extension SieCameraOrientationX on SieCameraOrientation {
  /// Degrees clockwise.
  int get degrees => switch (this) {
        SieCameraOrientation.rotation0 => 0,
        SieCameraOrientation.rotation90 => 90,
        SieCameraOrientation.rotation180 => 180,
        SieCameraOrientation.rotation270 => 270,
      };

  /// Build from sensor orientation degrees.
  static SieCameraOrientation fromDegrees(int degrees) {
    final d = ((degrees % 360) + 360) % 360;
    return switch (d) {
      90 => SieCameraOrientation.rotation90,
      180 => SieCameraOrientation.rotation180,
      270 => SieCameraOrientation.rotation270,
      _ => SieCameraOrientation.rotation0,
    };
  }
}
