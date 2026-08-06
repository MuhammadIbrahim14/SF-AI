import 'dart:typed_data';

import 'package:skillforge_sie/src/sie_camera/models/sie_camera_image_format.dart';

/// One plane of an opaque camera buffer.
///
/// Purpose: pass bytes to vision adapters without interpreting content.
final class SieCameraPlane {
  /// Creates a plane view.
  SieCameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });

  /// Raw bytes (may be a view into plugin memory — consume promptly).
  final Uint8List bytes;

  /// Row stride.
  final int bytesPerRow;

  /// Optional bytes per pixel.
  final int? bytesPerPixel;
}

/// A single captured frame for downstream vision (no CV in this module).
///
/// Purpose: stable DTO across [CameraPort.frames].
/// Inputs: platform adapter conversion.
/// Outputs: dimensions + opaque planes + timing metadata.
/// Failure behavior: never created on error paths; stream errors use
/// [SieCameraStatus].
final class SieCameraFrame {
  /// Creates a frame.
  const SieCameraFrame({
    required this.timestamp,
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.rotationDegrees,
    required this.cameraId,
    this.sequence = 0,
    this.platformImage,
  });

  /// Capture / enqueue time.
  final DateTime timestamp;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Buffer format label.
  final SieCameraImageFormat format;

  /// Opaque planes (YUV / BGRA / …).
  final List<SieCameraPlane> planes;

  /// Sensor / display rotation hint for vision (degrees).
  final int rotationDegrees;

  /// Source camera id.
  final String cameraId;

  /// Monotonic sequence from the stream manager (gaps = drops).
  final int sequence;

  /// Opaque native buffer for vision adapters only (e.g. plugin `CameraImage`).
  ///
  /// Landmark / Gesture / Host layers must ignore this field. It enables
  /// zero-copy MediaPipe handoff on Android without leaking plugin types
  /// into higher modules.
  final Object? platformImage;
}
