import 'package:camera/camera.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_camera_inventory.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_inventory_port.dart';

/// Uses the official `camera` plugin to enumerate devices (no stream).
final class FlutterCameraInventory implements CameraInventoryPort {
  /// Creates the inventory adapter.
  const FlutterCameraInventory();

  @override
  Future<SieCameraInventory> probe() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return SieCameraInventory.empty();

      var front = false;
      var back = false;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) front = true;
        if (c.lensDirection == CameraLensDirection.back) back = true;
      }
      return SieCameraInventory(
        probed: true,
        deviceCount: cameras.length,
        hasFrontCamera: front,
        hasBackCamera: back,
      );
    } catch (e) {
      return SieCameraInventory(
        probed: true,
        deviceCount: 0,
        hasFrontCamera: false,
        hasBackCamera: false,
        errorMessage: e.toString(),
      );
    }
  }
}
