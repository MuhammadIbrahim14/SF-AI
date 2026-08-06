import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_ai/core/utils/app_logger.dart';
import 'package:skillforge_ai/features/settings/providers/settings_providers.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_providers.dart';
import 'package:skillforge_ai/providers/user_provider.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Master switch — Admin SIE host (reuses Student SRDCR; optional).
final adminSieHostEnabledProvider = Provider<bool>((ref) => true);

/// Rollout segment for Admin Phase 5 (Security Team → Platform Admins).
final adminSieSegmentProvider = Provider<PrfUserSegment>((ref) {
  return ref.watch(studentSieSegmentProvider);
});

/// Bootstraps SIE for Admin routes via the shared Student composition root.
///
/// Reuses [studentSieHostControllerProvider] — one SRDCR per app session.
final adminSieBootstrapProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(adminSieHostEnabledProvider)) return false;
  if (!ref.watch(studentSieHostEnabledProvider)) return false;

  final user = ref.watch(currentUserProvider).value;
  final userKey = user?.uid ?? 'anonymous-admin';
  final controller = ref.watch(studentSieHostControllerProvider);
  final ok = await controller.ensureStarted(
    platform: ref.watch(studentSiePlatformProvider),
    userKey: userKey,
  );
  if (ok) {
    try {
      await controller.root.rollout.setSegment(
        ref.watch(adminSieSegmentProvider),
      );
    } catch (_) {
      AppLogger.debug('Admin SIE rollout segment could not be updated.');
    }
    final motion = ref.watch(motionSettingsStreamProvider).value;
    await controller.applyAccessibility(
      reducedMotion: motion?.reducedMotion == true,
      largeCursor: false,
      highContrast: false,
    );
  }
  return ok;
});

/// Low-frequency Admin SIE availability (Riverpod-safe / ADR-008).
final adminSieAvailabilityProvider = Provider<({
  bool hostEnabled,
  bool available,
  bool sieEnabled,
  String? activeRouteId,
  String? lastFailure,
})>((ref) {
  ref.watch(adminSieBootstrapProvider);
  ref.watch(studentSieRouteEpochProvider);
  final controller = ref.watch(studentSieHostControllerProvider);
  final hostEnabled = ref.watch(adminSieHostEnabledProvider);
  final prfEnabled = controller.isAvailable
      ? controller.root.rollout.sieEnabled
      : false;
  return (
    hostEnabled: hostEnabled,
    available: controller.isAvailable,
    sieEnabled: prfEnabled,
    activeRouteId: controller.activeRouteId,
    lastFailure: controller.lastFailure,
  );
});

/// Typed access to shared host controller for Admin tools/tests.
StudentSieHostController adminSieHostController(WidgetRef ref) =>
    ref.read(studentSieHostControllerProvider);
