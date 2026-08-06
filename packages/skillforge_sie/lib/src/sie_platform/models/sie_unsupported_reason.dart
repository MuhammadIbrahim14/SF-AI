/// Why SIE (or a submodule) cannot run on the current device/browser.
enum SieUnsupportedReason {
  /// OS / embedder not in the supported matrix.
  platformNotSupported,

  /// Camera API missing or blocked by policy.
  cameraApiUnavailable,

  /// Continuous streaming not available (e.g. Windows plugin gap).
  continuousStreamingUnavailable,

  /// Browser insecure context or missing media APIs.
  browserLimitation,

  /// No camera devices enumerated.
  noCameraDevice,

  /// Permission permanently denied / restricted.
  permissionBlocked,

  /// Feature flag disabled by host/config.
  featureDisabled,

  /// Catch-all when classification is unclear.
  unknown,
}
