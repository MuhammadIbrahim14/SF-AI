/// Camera permission lifecycle states for SIE (IDS privacy / opt-in).
///
/// Purpose: expose a platform-neutral permission model to session + host UX.
enum SiePermissionStatus {
  /// Not yet queried this session.
  unknown,

  /// Permission not required by the OS/browser for this probe path.
  notApplicable,

  /// Can prompt the user.
  denied,

  /// User granted camera access.
  granted,

  /// User denied and the OS/browser will not show the prompt again
  /// (settings / site settings required).
  permanentlyDenied,

  /// OS restricted (parental controls, enterprise policy, etc.).
  restricted,

  /// Probe failed for an unexpected reason (see failure object on snapshot).
  error,
}

/// Whether the host may call [request] productively.
extension SiePermissionStatusX on SiePermissionStatus {
  /// `true` when a runtime prompt may still succeed.
  bool get canRequest =>
      this == SiePermissionStatus.unknown || this == SiePermissionStatus.denied;

  /// `true` when camera capture is allowed.
  bool get isGranted => this == SiePermissionStatus.granted;

  /// `true` when the user must leave the app/site settings to recover.
  bool get needsSettings =>
      this == SiePermissionStatus.permanentlyDenied ||
      this == SiePermissionStatus.restricted;
}
