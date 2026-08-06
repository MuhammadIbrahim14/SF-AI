import 'dart:async';
import 'dart:typed_data';

import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_image_format.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lens_direction.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_platform_adapter_port.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// In-memory adapter for unit tests (no hardware).
final class FakeCameraPlatformAdapter implements CameraPlatformAdapterPort {
  /// Creates a fake adapter.
  FakeCameraPlatformAdapter({
    List<SieCameraDeviceInfo>? devices,
    this.supportsContinuousStreaming = true,
    this.emitInterval = const Duration(milliseconds: 33),
  }) : devices = devices ??
            const [
              SieCameraDeviceInfo(
                id: 'fake-front',
                name: 'Fake Front',
                lensDirection: SieCameraLensDirection.front,
                sensorOrientation: 90,
              ),
              SieCameraDeviceInfo(
                id: 'fake-back',
                name: 'Fake Back',
                lensDirection: SieCameraLensDirection.back,
              ),
            ];

  /// Discoverable devices.
  List<SieCameraDeviceInfo> devices;

  /// When false, open/start throw streaming unsupported.
  @override
  bool supportsContinuousStreaming;

  /// Synthetic frame period.
  final Duration emitInterval;

  /// Force listDevices to throw.
  Object? listError;

  /// Force open to throw.
  Object? openError;

  SieCameraDeviceInfo? _openDevice;
  Timer? _timer;
  void Function(SieCameraFrame frame)? _onFrame;

  @override
  bool get isOpen => _openDevice != null;

  @override
  Future<List<SieCameraDeviceInfo>> listDevices() async {
    if (listError != null) throw listError!;
    return List.unmodifiable(devices);
  }

  @override
  Future<void> open(SieCameraDeviceInfo device, SieCameraConfig config) async {
    if (!supportsContinuousStreaming) {
      throw SieCameraStreamingUnsupportedFailure();
    }
    if (openError != null) throw openError!;
    _openDevice = device;
  }

  @override
  Future<void> startStreaming(void Function(SieCameraFrame frame) onFrame) async {
    if (_openDevice == null) {
      throw SieCameraLifecycleFailure(message: 'Fake camera not open');
    }
    _onFrame = onFrame;
    _timer?.cancel();
    _timer = Timer.periodic(emitInterval, (_) {
      final cb = _onFrame;
      final device = _openDevice;
      if (cb == null || device == null) return;
      cb(
        SieCameraFrame(
          timestamp: DateTime.now(),
          width: 64,
          height: 48,
          format: SieCameraImageFormat.yuv420,
          planes: [
            SieCameraPlane(
              bytes: Uint8List(64 * 48),
              bytesPerRow: 64,
            ),
          ],
          rotationDegrees: device.sensorOrientation,
          cameraId: device.id,
        ),
      );
    });
  }

  @override
  Future<void> stopStreaming() async {
    _timer?.cancel();
    _timer = null;
    _onFrame = null;
  }

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<void> close() async {
    await stopStreaming();
    _openDevice = null;
  }

  /// Simulates disconnect during streaming.
  Future<void> simulateDisconnect() async {
    await close();
  }
}
