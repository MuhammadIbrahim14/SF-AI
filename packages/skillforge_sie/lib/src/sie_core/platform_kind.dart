/// Identifies the runtime host OS / browser environment for SIE.
///
/// Purpose: gate platform profiles and capability expectations (Docs 02, 06).
enum SiePlatformKind {
  /// Flutter Web (Chrome/Edge primary P0).
  web,

  /// Android (P0).
  android,

  /// Windows desktop (detected; continuous camera streaming not v1-ready).
  windows,

  /// Linux desktop (best-effort / future).
  linux,

  /// macOS desktop (secondary desktop).
  macos,

  /// iOS / iPadOS (future SKU; detected for fail-soft messaging).
  ios,

  /// Anything else — SIE must fail gracefully.
  unsupported,
}

/// Extension helpers for [SiePlatformKind].
extension SiePlatformKindX on SiePlatformKind {
  /// Human-readable label for diagnostics and permission guidance.
  String get displayName => switch (this) {
        SiePlatformKind.web => 'Web',
        SiePlatformKind.android => 'Android',
        SiePlatformKind.windows => 'Windows',
        SiePlatformKind.linux => 'Linux',
        SiePlatformKind.macos => 'macOS',
        SiePlatformKind.ios => 'iOS',
        SiePlatformKind.unsupported => 'Unsupported',
      };

  /// Whether this platform is a v1 **launch** target (Web + Android).
  bool get isV1LaunchTarget =>
      this == SiePlatformKind.web || this == SiePlatformKind.android;
}
