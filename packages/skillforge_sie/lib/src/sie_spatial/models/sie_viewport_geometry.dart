import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Immutable viewport / camera geometry for spatial mapping.
///
/// Host updates this on resize, rotation, and camera aspect changes.
final class SieViewportGeometry {
  /// Creates viewport geometry.
  const SieViewportGeometry({
    required this.viewWidth,
    required this.viewHeight,
    required this.cameraAspectRatio,
    this.devicePixelRatio = 1.0,
    this.orientation = SieCameraOrientation.rotation0,
    this.fitMode = SieViewportFitMode.contain,
    this.mirrorHorizontal = true,
    this.marginLeft = 0,
    this.marginTop = 0,
    this.marginRight = 0,
    this.marginBottom = 0,
  });

  /// Default placeholder (invalid until host sets real size).
  static const SieViewportGeometry unset = SieViewportGeometry(
    viewWidth: 0,
    viewHeight: 0,
    cameraAspectRatio: 1,
    mirrorHorizontal: true,
  );

  /// Flutter view width in logical pixels.
  final double viewWidth;

  /// Flutter view height in logical pixels.
  final double viewHeight;

  /// Camera frame width/height (pre-orientation).
  final double cameraAspectRatio;

  /// Device pixel ratio (logical transforms; retained for diagnostics).
  final double devicePixelRatio;

  /// Sensor / display orientation.
  final SieCameraOrientation orientation;

  /// How content fits the view.
  final SieViewportFitMode fitMode;

  /// Mirror X after orientation (front camera).
  final bool mirrorHorizontal;

  /// Safe margin left (logical px).
  final double marginLeft;

  /// Safe margin top.
  final double marginTop;

  /// Safe margin right.
  final double marginRight;

  /// Safe margin bottom.
  final double marginBottom;

  /// Whether dimensions are usable for mapping.
  bool get isValid =>
      viewWidth > 0 &&
      viewHeight > 0 &&
      cameraAspectRatio.isFinite &&
      cameraAspectRatio > 0 &&
      devicePixelRatio > 0;

  /// Usable inner view after margins.
  SieSpatialRect get contentSafeRect {
    final w = (viewWidth - marginLeft - marginRight).clamp(0.0, viewWidth);
    final h = (viewHeight - marginTop - marginBottom).clamp(0.0, viewHeight);
    return SieSpatialRect(
      left: marginLeft,
      top: marginTop,
      width: w.toDouble(),
      height: h.toDouble(),
    );
  }

  /// Effective content aspect after orientation (90/270 swap).
  double get orientedCameraAspect {
    final swap = orientation == SieCameraOrientation.rotation90 ||
        orientation == SieCameraOrientation.rotation270;
    return swap ? (1.0 / cameraAspectRatio) : cameraAspectRatio;
  }

  /// Copy with overrides.
  SieViewportGeometry copyWith({
    double? viewWidth,
    double? viewHeight,
    double? cameraAspectRatio,
    double? devicePixelRatio,
    SieCameraOrientation? orientation,
    SieViewportFitMode? fitMode,
    bool? mirrorHorizontal,
    double? marginLeft,
    double? marginTop,
    double? marginRight,
    double? marginBottom,
  }) {
    return SieViewportGeometry(
      viewWidth: viewWidth ?? this.viewWidth,
      viewHeight: viewHeight ?? this.viewHeight,
      cameraAspectRatio: cameraAspectRatio ?? this.cameraAspectRatio,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      orientation: orientation ?? this.orientation,
      fitMode: fitMode ?? this.fitMode,
      mirrorHorizontal: mirrorHorizontal ?? this.mirrorHorizontal,
      marginLeft: marginLeft ?? this.marginLeft,
      marginTop: marginTop ?? this.marginTop,
      marginRight: marginRight ?? this.marginRight,
      marginBottom: marginBottom ?? this.marginBottom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SieViewportGeometry &&
          viewWidth == other.viewWidth &&
          viewHeight == other.viewHeight &&
          cameraAspectRatio == other.cameraAspectRatio &&
          devicePixelRatio == other.devicePixelRatio &&
          orientation == other.orientation &&
          fitMode == other.fitMode &&
          mirrorHorizontal == other.mirrorHorizontal &&
          marginLeft == other.marginLeft &&
          marginTop == other.marginTop &&
          marginRight == other.marginRight &&
          marginBottom == other.marginBottom;

  @override
  int get hashCode => Object.hash(
        viewWidth,
        viewHeight,
        cameraAspectRatio,
        devicePixelRatio,
        orientation,
        fitMode,
        mirrorHorizontal,
        marginLeft,
        marginTop,
        marginRight,
        marginBottom,
      );
}
