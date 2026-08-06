import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_engine_config.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_viewport_geometry.dart';

/// Fitted content rectangle inside the safe view.
final class SieContentLayout {
  /// Creates layout.
  const SieContentLayout({
    required this.content,
    required this.safe,
  });

  /// Letterboxed / covered content rect in view coordinates.
  final SieSpatialRect content;

  /// Safe area after margins.
  final SieSpatialRect safe;
}

/// Deterministic stage-by-stage coordinate pipeline.
///
/// Camera → Normalized → Viewport → Screen → Flutter.
final class SieSpatialTransformPipeline {
  /// Creates the pipeline.
  const SieSpatialTransformPipeline(this.config);

  /// Engine config.
  final SieSpatialEngineConfig config;

  /// Computes content layout for [viewport].
  ///
  /// Throws [ArgumentError] when viewport is invalid.
  SieContentLayout layout(SieViewportGeometry viewport) {
    if (!viewport.isValid) {
      throw ArgumentError('Invalid viewport geometry');
    }
    final safe = viewport.contentSafeRect;
    if (safe.width <= 0 || safe.height <= 0) {
      throw ArgumentError('Safe viewport has zero area');
    }

    final aspect = viewport.orientedCameraAspect;
    final viewAspect = safe.width / safe.height;
    late double contentW;
    late double contentH;
    late double offsetX;
    late double offsetY;

    switch (viewport.fitMode) {
      case SieViewportFitMode.contain:
        if (aspect > viewAspect) {
          contentW = safe.width;
          contentH = safe.width / aspect;
          offsetX = safe.left;
          offsetY = safe.top + (safe.height - contentH) / 2;
        } else {
          contentH = safe.height;
          contentW = safe.height * aspect;
          offsetX = safe.left + (safe.width - contentW) / 2;
          offsetY = safe.top;
        }
      case SieViewportFitMode.cover:
        if (aspect > viewAspect) {
          contentH = safe.height;
          contentW = safe.height * aspect;
          offsetX = safe.left + (safe.width - contentW) / 2;
          offsetY = safe.top;
        } else {
          contentW = safe.width;
          contentH = safe.width / aspect;
          offsetX = safe.left;
          offsetY = safe.top + (safe.height - contentH) / 2;
        }
    }

    return SieContentLayout(
      content: SieSpatialRect(
        left: offsetX,
        top: offsetY,
        width: contentW,
        height: contentH,
      ),
      safe: safe,
    );
  }

  /// Stage 1→2: camera image-normalized → upright normalized (+ optional mirror).
  SieSpatialPoint2D toNormalized({
    required double cameraX,
    required double cameraY,
    required SieCameraOrientation orientation,
    required bool mirrorHorizontal,
  }) {
    final upright = _applyOrientation(cameraX, cameraY, orientation);
    final mx = mirrorHorizontal ? (1.0 - upright.x) : upright.x;
    return SieSpatialPoint2D(mx, upright.y);
  }

  /// Stage 2→3: normalized → viewport-local pixels (0..contentW).
  SieSpatialPoint2D toViewport({
    required SieSpatialPoint2D normalized,
    required SieSpatialRect content,
  }) {
    return SieSpatialPoint2D(
      normalized.x * content.width,
      normalized.y * content.height,
    );
  }

  /// Stage 3→4: viewport-local → screen / full-view logical pixels.
  SieSpatialPoint2D toScreen({
    required SieSpatialPoint2D viewportLocal,
    required SieSpatialRect content,
  }) {
    return SieSpatialPoint2D(
      content.left + viewportLocal.x,
      content.top + viewportLocal.y,
    );
  }

  /// Stage 4→5: screen → Flutter logical (clamp optional).
  ({SieSpatialPoint2D point, bool outOfBounds}) toFlutter({
    required SieSpatialPoint2D screen,
    required SieContentLayout layout,
  }) {
    var outOfBounds = !layout.content.contains(screen);
    if (config.clampToSafeMargins && !layout.safe.contains(screen)) {
      outOfBounds = true;
    }

    var x = screen.x;
    var y = screen.y;
    if (config.clampToViewport) {
      final r = config.clampToSafeMargins ? layout.safe : layout.content;
      x = x.clamp(r.left, r.right).toDouble();
      y = y.clamp(r.top, r.bottom).toDouble();
    }
    return (point: SieSpatialPoint2D(x, y), outOfBounds: outOfBounds);
  }

  /// Full pipeline for one landmark.
  ({
    SieSpatialPoint2D camera,
    SieSpatialPoint2D normalized,
    SieSpatialPoint2D viewport,
    SieSpatialPoint2D screen,
    SieSpatialPoint2D flutter,
    bool outOfBounds,
  }) transformPoint({
    required double cameraX,
    required double cameraY,
    required SieViewportGeometry viewport,
    required SieContentLayout layout,
  }) {
    final camera = SieSpatialPoint2D(cameraX, cameraY);
    final normalized = toNormalized(
      cameraX: cameraX,
      cameraY: cameraY,
      orientation: viewport.orientation,
      mirrorHorizontal: config.resolveMirror(viewport),
    );
    final viewportLocal = toViewport(
      normalized: normalized,
      content: layout.content,
    );
    final screen = toScreen(
      viewportLocal: viewportLocal,
      content: layout.content,
    );
    final flutter = toFlutter(screen: screen, layout: layout);
    return (
      camera: camera,
      normalized: normalized,
      viewport: viewportLocal,
      screen: screen,
      flutter: flutter.point,
      outOfBounds: flutter.outOfBounds,
    );
  }

  static SieSpatialPoint2D _applyOrientation(
    double x,
    double y,
    SieCameraOrientation orientation,
  ) {
    return switch (orientation) {
      SieCameraOrientation.rotation0 => SieSpatialPoint2D(x, y),
      SieCameraOrientation.rotation90 => SieSpatialPoint2D(y, 1.0 - x),
      SieCameraOrientation.rotation180 => SieSpatialPoint2D(1.0 - x, 1.0 - y),
      SieCameraOrientation.rotation270 => SieSpatialPoint2D(1.0 - y, x),
    };
  }
}
