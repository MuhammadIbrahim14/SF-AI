import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_platform/ports/platform_detector_port.dart';

/// Default [PlatformDetectorPort] using Flutter foundation APIs.
final class DefaultPlatformDetector implements PlatformDetectorPort {
  /// Creates the detector.
  const DefaultPlatformDetector();

  @override
  SiePlatformKind detect() {
    if (kIsWeb) return SiePlatformKind.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => SiePlatformKind.android,
      TargetPlatform.iOS => SiePlatformKind.ios,
      TargetPlatform.windows => SiePlatformKind.windows,
      TargetPlatform.linux => SiePlatformKind.linux,
      TargetPlatform.macOS => SiePlatformKind.macos,
      TargetPlatform.fuchsia => SiePlatformKind.unsupported,
    };
  }
}
