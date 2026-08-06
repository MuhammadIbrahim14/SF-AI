import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lens_direction.dart';

/// Immutable description of a discovered camera device.
///
/// Purpose: selection + diagnostics without starting a stream.
final class SieCameraDeviceInfo {
  /// Creates device info.
  const SieCameraDeviceInfo({
    required this.id,
    required this.name,
    required this.lensDirection,
    this.sensorOrientation = 0,
  });

  /// Platform camera id (plugin-specific, opaque to higher layers).
  final String id;

  /// Human-readable name when available.
  final String name;

  /// Facing direction.
  final SieCameraLensDirection lensDirection;

  /// Sensor orientation degrees (0/90/180/270).
  final int sensorOrientation;

  @override
  String toString() =>
      'SieCameraDeviceInfo(id=$id, lens=${lensDirection.name}, orient=$sensorOrientation)';
}
