import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_camera/adapters/flutter_camera_platform_adapter.dart';
import 'package:skillforge_sie/src/sie_camera/adapters/unsupported_camera_platform_adapter.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_platform_adapter_port.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/default_platform_detector.dart';

/// Creates the default platform camera adapter for the current OS.
///
/// Web + Android → [FlutterCameraPlatformAdapter].
/// Others → [UnsupportedCameraPlatformAdapter] (fail-soft until future ports).
CameraPlatformAdapterPort createDefaultCameraPlatformAdapter({
  SiePlatformKind? platform,
}) {
  final kind = platform ?? const DefaultPlatformDetector().detect();
  switch (kind) {
    case SiePlatformKind.web:
    case SiePlatformKind.android:
      return FlutterCameraPlatformAdapter();
    case SiePlatformKind.ios:
      // Future SKU — plugin may work, but v1 policy keeps unsupported profile.
      // Still allow Flutter adapter when running on iOS for early experiments.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        return FlutterCameraPlatformAdapter();
      }
      return UnsupportedCameraPlatformAdapter(kind);
    case SiePlatformKind.windows:
    case SiePlatformKind.linux:
    case SiePlatformKind.macos:
    case SiePlatformKind.unsupported:
      return UnsupportedCameraPlatformAdapter(kind);
  }
}
