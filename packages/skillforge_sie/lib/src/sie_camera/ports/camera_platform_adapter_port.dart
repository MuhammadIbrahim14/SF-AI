import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';

/// Low-level platform camera operations (plugin boundary).
///
/// Purpose: isolate `camera` / future Windows adapters from [CameraPort].
/// Engine logic must not import plugin types except via this port.
abstract interface class CameraPlatformAdapterPort {
  /// Whether this adapter can provide continuous frames on the current OS.
  bool get supportsContinuousStreaming;

  /// Enumerate devices.
  Future<List<SieCameraDeviceInfo>> listDevices();

  /// Open + initialize [device] with [config] (no streaming yet).
  Future<void> open(SieCameraDeviceInfo device, SieCameraConfig config);

  /// Begin delivering frames to [onFrame].
  Future<void> startStreaming(void Function(SieCameraFrame frame) onFrame);

  /// Stop frame callbacks; keep device open when possible.
  Future<void> stopStreaming();

  /// Optional preview pause (no-op if unsupported).
  Future<void> pausePreview();

  /// Optional preview resume.
  Future<void> resumePreview();

  /// Close device and release native resources.
  Future<void> close();

  /// Whether a device is currently open.
  bool get isOpen;
}
