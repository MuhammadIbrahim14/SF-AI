import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';

/// Immutable permission state for host / Riverpod (ADR-008 — low frequency).
///
/// Purpose: drive permission UX without embedding OS plugins in widgets.
final class SiePermissionSnapshot {
  /// Creates a permission snapshot.
  const SiePermissionSnapshot({
    required this.status,
    required this.canRequest,
    required this.needsSettings,
    this.guidanceTitle,
    this.guidanceBody,
    this.lastErrorCode,
  });

  /// Initial unknown state before probe.
  factory SiePermissionSnapshot.unknown() => const SiePermissionSnapshot(
        status: SiePermissionStatus.unknown,
        canRequest: true,
        needsSettings: false,
        guidanceTitle: 'Camera access',
        guidanceBody:
            'SkillForge AI Spatial Interaction needs the camera only while SIE is on. '
            'Video is processed on-device and is not stored for analytics.',
      );

  /// Builds guidance-aware snapshot from [status].
  factory SiePermissionSnapshot.fromStatus(SiePermissionStatus status) {
    final base = SiePermissionSnapshot.unknown();
    switch (status) {
      case SiePermissionStatus.granted:
        return SiePermissionSnapshot(
          status: status,
          canRequest: false,
          needsSettings: false,
          guidanceTitle: base.guidanceTitle,
          guidanceBody: 'Camera permission granted. You can pause or stop SIE anytime.',
        );
      case SiePermissionStatus.denied:
        return SiePermissionSnapshot(
          status: status,
          canRequest: true,
          needsSettings: false,
          guidanceTitle: 'Allow camera to use Spatial Interaction',
          guidanceBody:
              'SIE is optional. Without camera permission, continue with mouse or touch.',
        );
      case SiePermissionStatus.permanentlyDenied:
        return const SiePermissionSnapshot(
          status: SiePermissionStatus.permanentlyDenied,
          canRequest: false,
          needsSettings: true,
          guidanceTitle: 'Camera blocked in system settings',
          guidanceBody:
              'Open system or site settings, enable camera for SkillForge, then return and retry.',
        );
      case SiePermissionStatus.restricted:
        return const SiePermissionSnapshot(
          status: SiePermissionStatus.restricted,
          canRequest: false,
          needsSettings: true,
          guidanceTitle: 'Camera restricted',
          guidanceBody:
              'Camera access is restricted on this device. Use mouse or touch instead.',
        );
      case SiePermissionStatus.notApplicable:
        return const SiePermissionSnapshot(
          status: SiePermissionStatus.notApplicable,
          canRequest: false,
          needsSettings: false,
          guidanceTitle: 'Camera not applicable',
          guidanceBody: 'This platform does not expose a camera permission for SIE.',
        );
      case SiePermissionStatus.error:
        return const SiePermissionSnapshot(
          status: SiePermissionStatus.error,
          canRequest: true,
          needsSettings: false,
          guidanceTitle: 'Could not read camera permission',
          guidanceBody: 'Something went wrong checking permission. You can retry.',
          lastErrorCode: 'sie.permission.error',
        );
      case SiePermissionStatus.unknown:
        return base;
    }
  }

  /// Current status.
  final SiePermissionStatus status;

  /// Whether [SiePermissionManager.requestCameraPermission] may prompt.
  final bool canRequest;

  /// Whether the user must open OS/site settings.
  final bool needsSettings;

  /// Short title for host dialogs.
  final String? guidanceTitle;

  /// Body copy aligned with IDS privacy expectations.
  final String? guidanceBody;

  /// Optional last error code.
  final String? lastErrorCode;
}
