import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_status.dart';

/// Stable Camera Engine port consumed by future Vision modules (Document 04).
///
/// Purpose: discovery, lifecycle, and opaque frame delivery — never CV.
/// Inputs: [SieCameraConfig], permission already granted by host/session.
/// Outputs: [status], [frames], control futures.
/// Failure behavior: methods complete with [SieFailure] via status / thrown
/// typed failures; never crash the isolate for plugin errors when recoverable.
abstract interface class CameraPort {
  /// Low-frequency status snapshots (safe for Riverpod).
  Stream<SieCameraStatus> get status;

  /// High-frequency frames — **not** for Riverpod (ADR-008).
  Stream<SieCameraFrame> get frames;

  /// Latest status synchronously.
  SieCameraStatus get currentStatus;

  /// Active config.
  SieCameraConfig get config;

  /// Enumerate cameras (may request OS listing; does not start stream).
  Future<List<SieCameraDeviceInfo>> discover();

  /// Initialize preferred camera (ready, not streaming).
  Future<void> initialize({SieCameraConfig? config});

  /// Start continuous frame streaming.
  Future<void> start();

  /// Pause streaming; keep session resources when possible.
  Future<void> pause();

  /// Resume after [pause].
  Future<void> resume();

  /// Stop streaming and release the active controller (discoverable again).
  Future<void> stop();

  /// Terminal dispose — engine becomes unusable.
  Future<void> dispose();

  /// Attempt recovery after error / disconnect / permission restore.
  Future<void> recover();
}
