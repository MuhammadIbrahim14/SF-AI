/// Browser / OS environment facts needed before camera use.
///
/// Purpose: probe secure context and media API presence without streaming.
/// Inputs: none.
/// Outputs: [EnvironmentCapabilityFacts].
/// Failure behavior: adapters return conservative `false` flags; no throws.
abstract interface class CapabilityProbePort {
  /// Collects environment capability facts.
  Future<EnvironmentCapabilityFacts> probe();
}

/// Raw environment facts from [CapabilityProbePort].
final class EnvironmentCapabilityFacts {
  /// Creates facts.
  const EnvironmentCapabilityFacts({
    required this.secureContext,
    required this.mediaDevicesApiAvailable,
    required this.cameraPermissionApiAvailable,
  });

  /// HTTPS / localhost (or non-web always true).
  final bool secureContext;

  /// MediaDevices / equivalent available.
  final bool mediaDevicesApiAvailable;

  /// Permission API path available for camera.
  final bool cameraPermissionApiAvailable;
}
