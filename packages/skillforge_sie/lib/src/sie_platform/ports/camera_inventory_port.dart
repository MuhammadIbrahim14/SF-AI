import 'package:skillforge_sie/src/sie_platform/models/sie_camera_inventory.dart';

/// Enumerates cameras without starting an image stream.
///
/// Purpose: availability detection for the capability layer only.
/// Inputs: none.
/// Outputs: [SieCameraInventory].
/// Failure behavior: return inventory with [SieCameraInventory.errorMessage];
/// do not throw to callers of the service façade.
abstract interface class CameraInventoryPort {
  /// Probes available cameras.
  Future<SieCameraInventory> probe();
}
