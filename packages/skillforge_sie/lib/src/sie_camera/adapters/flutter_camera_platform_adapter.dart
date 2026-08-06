import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_image_format.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lens_direction.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_platform_adapter_port.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// `camera` plugin adapter for Web + Android continuous streaming.
///
/// Does not interpret pixels. Converts [CameraImage] into [SieCameraFrame].
final class FlutterCameraPlatformAdapter implements CameraPlatformAdapterPort {
  /// Creates the adapter.
  FlutterCameraPlatformAdapter();

  CameraController? _controller;
  CameraDescription? _description;
  bool _streaming = false;

  @override
  bool get supportsContinuousStreaming {
    // Web + Android are v1 targets. Other OSes should use a different adapter.
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  bool get isOpen => _controller != null;

  @override
  Future<List<SieCameraDeviceInfo>> listDevices() async {
    final cameras = await availableCameras();
    return cameras.map(_mapDevice).toList(growable: false);
  }

  @override
  Future<void> open(SieCameraDeviceInfo device, SieCameraConfig config) async {
    await close();
    final cameras = await availableCameras();
    CameraDescription? match;
    for (final c in cameras) {
      if (c.name == device.id) {
        match = c;
        break;
      }
    }
    if (match == null) {
      throw SieCameraUnavailableFailure(
        message: 'Camera ${device.id} is no longer available.',
      );
    }
    _description = match;
    final controller = CameraController(
      match,
      _mapResolution(config.resolution),
      enableAudio: config.enableAudio,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _controller = controller;
  }

  @override
  Future<void> startStreaming(void Function(SieCameraFrame frame) onFrame) async {
    final controller = _controller;
    final description = _description;
    if (controller == null || description == null) {
      throw SieCameraLifecycleFailure(message: 'Camera is not open.');
    }
    if (_streaming) return;
    try {
      await controller.startImageStream((image) {
        onFrame(_mapFrame(image, description));
      });
      _streaming = true;
    } on UnimplementedError catch (e) {
      throw SieCameraStreamingUnsupportedFailure(message: e.message);
    } catch (e) {
      throw SieCameraEngineFailure(
        code: 'sie.camera.stream_start',
        message: e.toString(),
        cause: e,
      );
    }
  }

  @override
  Future<void> stopStreaming() async {
    final controller = _controller;
    if (controller == null || !_streaming) {
      _streaming = false;
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Some platforms throw if already stopped.
    }
    _streaming = false;
  }

  @override
  Future<void> pausePreview() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.pausePreview();
    } catch (_) {}
  }

  @override
  Future<void> resumePreview() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.resumePreview();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await stopStreaming();
    final controller = _controller;
    _controller = null;
    _description = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  static SieCameraDeviceInfo _mapDevice(CameraDescription d) {
    return SieCameraDeviceInfo(
      id: d.name,
      name: d.name,
      lensDirection: switch (d.lensDirection) {
        CameraLensDirection.front => SieCameraLensDirection.front,
        CameraLensDirection.back => SieCameraLensDirection.back,
        CameraLensDirection.external => SieCameraLensDirection.external,
      },
      sensorOrientation: d.sensorOrientation,
    );
  }

  static ResolutionPreset _mapResolution(SieCameraResolutionPreset r) {
    return switch (r) {
      SieCameraResolutionPreset.low => ResolutionPreset.low,
      SieCameraResolutionPreset.medium => ResolutionPreset.medium,
      SieCameraResolutionPreset.high => ResolutionPreset.high,
      SieCameraResolutionPreset.max => ResolutionPreset.max,
    };
  }

  static SieCameraFrame _mapFrame(
    CameraImage image,
    CameraDescription description,
  ) {
    final format = switch (image.format.group) {
      ImageFormatGroup.yuv420 => SieCameraImageFormat.yuv420,
      ImageFormatGroup.bgra8888 => SieCameraImageFormat.bgra8888,
      ImageFormatGroup.jpeg => SieCameraImageFormat.jpeg,
      ImageFormatGroup.nv21 => SieCameraImageFormat.unknown,
      ImageFormatGroup.unknown => SieCameraImageFormat.unknown,
    };

    final planes = image.planes
        .map(
          (p) => SieCameraPlane(
            bytes: p.bytes,
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel,
          ),
        )
        .toList(growable: false);

    return SieCameraFrame(
      timestamp: DateTime.now(),
      width: image.width,
      height: image.height,
      format: format,
      planes: planes,
      rotationDegrees: description.sensorOrientation,
      cameraId: description.name,
      platformImage: image,
    );
  }
}
