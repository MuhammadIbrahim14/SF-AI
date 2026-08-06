import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';

/// Configuration for the Spatial Coordinate Engine.
final class SieSpatialEngineConfig {
  /// Creates config.
  const SieSpatialEngineConfig({
    this.mirrorPolicy = SieMirrorPolicy.configurable,
    this.defaultMirrorHorizontal = true,
    this.clampToViewport = true,
    this.clampToSafeMargins = true,
  });

  /// SIE v1 defaults (front-camera mirror on).
  static const SieSpatialEngineConfig sieDefaults = SieSpatialEngineConfig();

  /// How mirroring is decided.
  final SieMirrorPolicy mirrorPolicy;

  /// Used when [mirrorPolicy] is [SieMirrorPolicy.configurable] and viewport
  /// does not override (viewport.mirrorHorizontal is source of truth when set).
  final bool defaultMirrorHorizontal;

  /// Clamp Flutter coordinates into the fitted content rect.
  final bool clampToViewport;

  /// Further clamp into safe margins.
  final bool clampToSafeMargins;

  /// Resolves effective mirror given viewport.
  bool resolveMirror(SieViewportGeometry viewport) {
    return switch (mirrorPolicy) {
      SieMirrorPolicy.none => false,
      SieMirrorPolicy.horizontal => true,
      SieMirrorPolicy.configurable => viewport.mirrorHorizontal,
    };
  }

  /// Copy with overrides.
  SieSpatialEngineConfig copyWith({
    SieMirrorPolicy? mirrorPolicy,
    bool? defaultMirrorHorizontal,
    bool? clampToViewport,
    bool? clampToSafeMargins,
  }) {
    return SieSpatialEngineConfig(
      mirrorPolicy: mirrorPolicy ?? this.mirrorPolicy,
      defaultMirrorHorizontal:
          defaultMirrorHorizontal ?? this.defaultMirrorHorizontal,
      clampToViewport: clampToViewport ?? this.clampToViewport,
      clampToSafeMargins: clampToSafeMargins ?? this.clampToSafeMargins,
    );
  }
}
