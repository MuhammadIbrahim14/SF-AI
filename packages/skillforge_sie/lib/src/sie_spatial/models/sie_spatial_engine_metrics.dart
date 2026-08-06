/// Engineering metrics for the Spatial Coordinate Engine.
final class SieSpatialEngineMetrics {
  /// Creates metrics.
  const SieSpatialEngineMetrics({
    this.framesProcessed = 0,
    this.landmarksTransformed = 0,
    this.outOfBoundsCount = 0,
    this.averageProcessingMs = 0,
    this.lastProcessingMs = 0,
    this.viewportUpdates = 0,
    this.orientationChanges = 0,
    this.invalidViewportEvents = 0,
  });

  /// Frames processed.
  final int framesProcessed;

  /// Landmarks transformed.
  final int landmarksTransformed;

  /// Out-of-bounds before clamp (cumulative).
  final int outOfBoundsCount;

  /// Mean transform time.
  final double averageProcessingMs;

  /// Last transform time.
  final double lastProcessingMs;

  /// Viewport update count.
  final int viewportUpdates;

  /// Orientation change count.
  final int orientationChanges;

  /// Times mapping was skipped due to invalid viewport.
  final int invalidViewportEvents;

  /// Copy with overrides.
  SieSpatialEngineMetrics copyWith({
    int? framesProcessed,
    int? landmarksTransformed,
    int? outOfBoundsCount,
    double? averageProcessingMs,
    double? lastProcessingMs,
    int? viewportUpdates,
    int? orientationChanges,
    int? invalidViewportEvents,
  }) {
    return SieSpatialEngineMetrics(
      framesProcessed: framesProcessed ?? this.framesProcessed,
      landmarksTransformed:
          landmarksTransformed ?? this.landmarksTransformed,
      outOfBoundsCount: outOfBoundsCount ?? this.outOfBoundsCount,
      averageProcessingMs: averageProcessingMs ?? this.averageProcessingMs,
      lastProcessingMs: lastProcessingMs ?? this.lastProcessingMs,
      viewportUpdates: viewportUpdates ?? this.viewportUpdates,
      orientationChanges: orientationChanges ?? this.orientationChanges,
      invalidViewportEvents:
          invalidViewportEvents ?? this.invalidViewportEvents,
    );
  }
}
