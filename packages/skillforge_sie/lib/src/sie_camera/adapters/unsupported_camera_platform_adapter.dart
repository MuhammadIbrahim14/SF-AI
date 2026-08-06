import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_platform_adapter_port.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Adapter that reports streaming unsupported (Windows / Linux / etc.).
final class UnsupportedCameraPlatformAdapter
    implements CameraPlatformAdapterPort {
  /// Creates an unsupported adapter for [platform].
  UnsupportedCameraPlatformAdapter(this.platform);

  /// Platform this adapter represents.
  final SiePlatformKind platform;

  @override
  bool get supportsContinuousStreaming => false;

  @override
  bool get isOpen => false;

  @override
  Future<List<SieCameraDeviceInfo>> listDevices() async => const [];

  @override
  Future<void> open(SieCameraDeviceInfo device, SieCameraConfig config) async {
    throw SieCameraStreamingUnsupportedFailure(
      message:
          'Camera streaming is not enabled for ${platform.displayName} in SIE v1.',
    );
  }

  @override
  Future<void> startStreaming(void Function(SieCameraFrame frame) onFrame) async {
    throw SieCameraStreamingUnsupportedFailure();
  }

  @override
  Future<void> stopStreaming() async {}

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<void> close() async {}
}
