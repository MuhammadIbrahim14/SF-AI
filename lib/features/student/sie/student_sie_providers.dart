import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_ai/features/settings/providers/settings_providers.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/providers/admin_provider.dart';
import 'package:skillforge_ai/providers/user_provider.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Master switch — Student SIE host (optional; traditional input always works).
///
/// Driven by Admin Platform Settings `sieGloballyEnabled` (Firestore).
/// Defaults to ON when settings have not loaded yet.
final studentSieHostEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(platformSettingsProvider).value;
  return settings?.sieGloballyEnabled ?? true;
});

/// Syncs Admin global On/Off into the live PRF kill switch / feature flag.
final studentSieGlobalControlSyncProvider = Provider<void>((ref) {
  final enabled = ref.watch(studentSieHostEnabledProvider);
  final controller = ref.watch(studentSieHostControllerProvider);
  ref.listen<bool>(studentSieHostEnabledProvider, (prev, next) {
    if (prev == next) return;
    unawaited(controller.applyGlobalEnablement(next));
  });
  // Apply once when host becomes available after bootstrap.
  ref.listen(studentSieBootstrapProvider, (prev, next) {
    next.whenData((ok) {
      if (ok) unawaited(controller.applyGlobalEnablement(enabled));
    });
  });
});

/// Use fake camera / mock vision (CI, desktop without camera, widget tests).
final studentSieUseTestDoublesProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  final p = defaultTargetPlatform;
  return p != TargetPlatform.android && p != TargetPlatform.iOS;
});

/// Whether to start the high-frequency runtime pipeline after bootstrap.
///
/// Debug Web/Android: live camera + hand tracking for visual use.
/// Release / desktop: opt-in only (traditional input always works).
final studentSieStartPipelineProvider = Provider<bool>((ref) {
  if (!kDebugMode) return false;
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android;
});

/// Rollout segment for Student Phase 1.
final studentSieSegmentProvider = Provider<PrfUserSegment>((ref) {
  if (kDebugMode) return PrfUserSegment.internalDevelopers;
  return PrfUserSegment.betaTesters;
});

/// Detected platform for SRDCR / PRF.
final studentSiePlatformProvider = Provider<SiePlatformKind>((ref) {
  if (kIsWeb) return SiePlatformKind.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => SiePlatformKind.android,
    TargetPlatform.windows => SiePlatformKind.windows,
    TargetPlatform.iOS => SiePlatformKind.unsupported,
    _ => SiePlatformKind.unsupported,
  };
});

/// Composition root owned by the Student Module (Phase 1).
final studentSieCompositionRootProvider = Provider<SrdcrPort>((ref) {
  final root = SieServiceRegistryCompositionRoot(
    useTestDoubles: ref.watch(studentSieUseTestDoublesProvider),
    logger: kDebugMode
        ? const DeveloperSrdcrLogger()
        : const NopSrdcrLogger(),
  );
  ref.onDispose(() {
    unawaited(root.dispose());
  });
  return root;
});

/// Student SIE host controller.
final studentSieHostControllerProvider = Provider<StudentSieHostController>((
  ref,
) {
  final controller = StudentSieHostController(
    root: ref.watch(studentSieCompositionRootProvider),
    segment: ref.watch(studentSieSegmentProvider),
    startPipeline: ref.watch(studentSieStartPipelineProvider),
  );
  ref.onDispose(() {
    unawaited(controller.stop());
  });
  return controller;
});

/// Bootstraps Student SIE when enabled; exposes availability.
final studentSieBootstrapProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(studentSieHostEnabledProvider)) return false;
  final user = ref.watch(currentUserProvider).value;
  final userKey = user?.uid ?? 'anonymous-student';
  final controller = ref.watch(studentSieHostControllerProvider);
  final ok = await controller.ensureStarted(
    platform: ref.watch(studentSiePlatformProvider),
    userKey: userKey,
  );
  if (ok) {
    final motion = ref.watch(motionSettingsStreamProvider).value;
    await controller.applyAccessibility(
      reducedMotion: motion?.reducedMotion == true,
      largeCursor: false,
      highContrast: false,
    );
  }
  return ok;
});

/// Bumped after [StudentSieHostController.activateRoute] so HUD rebuilds.
final studentSieRouteEpochProvider =
    NotifierProvider<StudentSieRouteEpoch, int>(StudentSieRouteEpoch.new);

/// Increments when a SIE route policy is activated (HUD refresh).
final class StudentSieRouteEpoch extends Notifier<int> {
  @override
  int build() => 0;

  /// Notify listeners that [StudentSieHostController.activeRouteId] changed.
  void bump() => state++;
}

/// Low-frequency Student SIE availability (Riverpod-safe).
final studentSieAvailabilityProvider = Provider<({
  bool hostEnabled,
  bool available,
  bool sieEnabled,
  String? activeRouteId,
  String? lastFailure,
})>((ref) {
  ref.watch(studentSieBootstrapProvider);
  ref.watch(studentSieRouteEpochProvider);
  final controller = ref.watch(studentSieHostControllerProvider);
  final hostEnabled = ref.watch(studentSieHostEnabledProvider);
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
