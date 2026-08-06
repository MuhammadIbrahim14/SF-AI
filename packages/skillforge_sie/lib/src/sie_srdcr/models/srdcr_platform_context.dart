import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_permission_port.dart';

/// Platform context held in the registry (not a heavyweight service).
final class SrdcrPlatformContext {
  /// Creates context.
  const SrdcrPlatformContext(this.platform);

  /// Platform kind.
  final SiePlatformKind platform;
}

/// Always-granted camera permission (tests / desktop stubs).
final class SrdcrGrantedCameraPermission implements CameraPermissionPort {
  /// Creates port.
  const SrdcrGrantedCameraPermission();

  @override
  Future<SiePermissionStatus> check() async => SiePermissionStatus.granted;

  @override
  Future<SiePermissionStatus> request() async => SiePermissionStatus.granted;

  @override
  Future<bool> openSettings() async => false;
}
