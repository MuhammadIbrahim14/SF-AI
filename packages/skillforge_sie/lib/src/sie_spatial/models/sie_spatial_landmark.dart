import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Per-landmark coordinates across all transformation stages.
final class SieSpatialLandmark {
  /// Creates a spatial landmark.
  const SieSpatialLandmark({
    required this.index,
    required this.camera,
    required this.normalized,
    required this.viewport,
    required this.screen,
    required this.flutter,
    required this.outOfBounds,
    this.z = 0,
    this.visibility,
    this.presence,
  });

  /// Landmark topology index.
  final int index;

  /// Camera-space (image-normalized, pre orientation/mirror).
  final SieSpatialPoint2D camera;

  /// Normalized upright + mirrored content space [0,1].
  final SieSpatialPoint2D normalized;

  /// Viewport / content-rect local pixels.
  final SieSpatialPoint2D viewport;

  /// Screen / full-view logical pixels (pre final clamp identity for v1).
  final SieSpatialPoint2D screen;

  /// Flutter logical coordinates (canonical for cursor / hit-test).
  final SieSpatialPoint2D flutter;

  /// Relative depth preserved from landmarks.
  final double z;

  /// Preserved visibility.
  final double? visibility;

  /// Preserved presence.
  final double? presence;

  /// Whether Flutter point left the content rect before clamping.
  final bool outOfBounds;
}
