import 'package:skillforge_sie/src/sie_core/platform_kind.dart';

/// Detects the current [SiePlatformKind].
///
/// Purpose: dependency-inverted platform identification for capability profiles.
/// Inputs: none (reads Flutter / embedder).
/// Outputs: [SiePlatformKind].
/// Failure behavior: never throws — returns [SiePlatformKind.unsupported].
abstract interface class PlatformDetectorPort {
  /// Returns the current platform kind.
  SiePlatformKind detect();
}
