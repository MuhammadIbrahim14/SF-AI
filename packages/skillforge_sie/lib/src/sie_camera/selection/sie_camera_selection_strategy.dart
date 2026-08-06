import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lens_direction.dart';

/// Selects a camera device from a discovered list.
///
/// Purpose: configurable preference + automatic fallback.
final class SieCameraSelectionStrategy {
  /// Creates the strategy.
  const SieCameraSelectionStrategy();

  /// Picks a device for [config], or `null` when [devices] is empty.
  ///
  /// Order: explicit id → preferred lens → front → any first.
  SieCameraDeviceInfo? select({
    required List<SieCameraDeviceInfo> devices,
    required SieCameraConfig config,
  }) {
    if (devices.isEmpty) return null;

    final preferredId = config.preferredDeviceId;
    if (preferredId != null) {
      for (final d in devices) {
        if (d.id == preferredId) return d;
      }
    }

    final lens = config.preferredLens;
    if (lens != null) {
      final match = _firstWithLens(devices, lens);
      if (match != null) return match;
    }

    // Fallback chain for SIE: front → back → external → first.
    return _firstWithLens(devices, SieCameraLensDirection.front) ??
        _firstWithLens(devices, SieCameraLensDirection.back) ??
        _firstWithLens(devices, SieCameraLensDirection.external) ??
        devices.first;
  }

  static SieCameraDeviceInfo? _firstWithLens(
    List<SieCameraDeviceInfo> devices,
    SieCameraLensDirection lens,
  ) {
    for (final d in devices) {
      if (d.lensDirection == lens) return d;
    }
    return null;
  }
}
