import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_snapshot.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_flags.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_id.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Accessibility preferences (host-reported; appearance/policy only).
final class SieAccessibilityState {
  /// Creates state.
  const SieAccessibilityState({
    this.reducedMotion = false,
    this.highContrast = false,
    this.largeCursor = false,
    this.dwellMode = false,
    this.screenReader = false,
    this.keyboardNavigation = false,
  });

  /// Defaults.
  static const SieAccessibilityState defaults = SieAccessibilityState();

  /// Reduced motion.
  final bool reducedMotion;

  /// High contrast.
  final bool highContrast;

  /// Large cursor preference.
  final bool largeCursor;

  /// Dwell select mode.
  final bool dwellMode;

  /// Screen reader active.
  final bool screenReader;

  /// Prefer keyboard navigation.
  final bool keyboardNavigation;

  /// Copy.
  SieAccessibilityState copyWith({
    bool? reducedMotion,
    bool? highContrast,
    bool? largeCursor,
    bool? dwellMode,
    bool? screenReader,
    bool? keyboardNavigation,
  }) {
    return SieAccessibilityState(
      reducedMotion: reducedMotion ?? this.reducedMotion,
      highContrast: highContrast ?? this.highContrast,
      largeCursor: largeCursor ?? this.largeCursor,
      dwellMode: dwellMode ?? this.dwellMode,
      screenReader: screenReader ?? this.screenReader,
      keyboardNavigation: keyboardNavigation ?? this.keyboardNavigation,
    );
  }
}

/// Feature / platform availability for graceful degradation.
final class SieInteractionAvailability {
  /// Creates availability.
  const SieInteractionAvailability({
    this.cameraAvailable = true,
    this.cameraPermissionGranted = true,
    this.sieSupported = true,
    this.gesturesEnabled = true,
    this.cursorEnabled = true,
    this.handTrackingEnabled = true,
    this.platformAllowsSie = true,
  });

  /// Fully available.
  static const SieInteractionAvailability full = SieInteractionAvailability();

  /// Desktop / no camera — traditional only.
  static const SieInteractionAvailability traditionalOnly =
      SieInteractionAvailability(
    cameraAvailable: false,
    cameraPermissionGranted: false,
    sieSupported: false,
    gesturesEnabled: false,
    cursorEnabled: false,
    handTrackingEnabled: false,
    platformAllowsSie: false,
  );

  /// Camera present.
  final bool cameraAvailable;

  /// Permission.
  final bool cameraPermissionGranted;

  /// Platform SIE support.
  final bool sieSupported;

  /// Gesture feature flag.
  final bool gesturesEnabled;

  /// Cursor feature flag.
  final bool cursorEnabled;

  /// Hand tracking flag.
  final bool handTrackingEnabled;

  /// Platform capability allows SIE.
  final bool platformAllowsSie;

  /// Whether SIE path may run at all.
  bool get sieOperational =>
      platformAllowsSie &&
      sieSupported &&
      cameraAvailable &&
      cameraPermissionGranted &&
      handTrackingEnabled &&
      (gesturesEnabled || cursorEnabled);

  /// Build from feature flags + probes.
  factory SieInteractionAvailability.fromFlags({
    required SieFeatureFlags flags,
    bool cameraAvailable = true,
    bool cameraPermissionGranted = true,
    bool sieSupported = true,
    bool platformAllowsSie = true,
  }) {
    return SieInteractionAvailability(
      cameraAvailable: cameraAvailable,
      cameraPermissionGranted: cameraPermissionGranted,
      sieSupported: sieSupported,
      gesturesEnabled: flags.isEnabled(SieFeatureId.gestures),
      cursorEnabled: flags.isEnabled(SieFeatureId.cursor),
      handTrackingEnabled: flags.isEnabled(SieFeatureId.handTracking) &&
          flags.isEnabled(SieFeatureId.camera),
      platformAllowsSie: platformAllowsSie,
    );
  }

  /// Copy.
  SieInteractionAvailability copyWith({
    bool? cameraAvailable,
    bool? cameraPermissionGranted,
    bool? sieSupported,
    bool? gesturesEnabled,
    bool? cursorEnabled,
    bool? handTrackingEnabled,
    bool? platformAllowsSie,
  }) {
    return SieInteractionAvailability(
      cameraAvailable: cameraAvailable ?? this.cameraAvailable,
      cameraPermissionGranted:
          cameraPermissionGranted ?? this.cameraPermissionGranted,
      sieSupported: sieSupported ?? this.sieSupported,
      gesturesEnabled: gesturesEnabled ?? this.gesturesEnabled,
      cursorEnabled: cursorEnabled ?? this.cursorEnabled,
      handTrackingEnabled: handTrackingEnabled ?? this.handTrackingEnabled,
      platformAllowsSie: platformAllowsSie ?? this.platformAllowsSie,
    );
  }
}

/// Focus snapshot.
final class SieFocusState {
  /// Creates focus state.
  const SieFocusState({
    this.kind = SieFocusKind.none,
    this.windowFocused = true,
    this.targetId,
  });

  /// Defaults.
  static const SieFocusState defaults = SieFocusState();

  /// Focus kind.
  final SieFocusKind kind;

  /// OS window focus.
  final bool windowFocused;

  /// Focused target id (host).
  final String? targetId;

  /// Copy.
  SieFocusState copyWith({
    SieFocusKind? kind,
    bool? windowFocused,
    String? targetId,
    bool clearTarget = false,
  }) {
    return SieFocusState(
      kind: kind ?? this.kind,
      windowFocused: windowFocused ?? this.windowFocused,
      targetId: clearTarget ? null : (targetId ?? this.targetId),
    );
  }
}

/// Mutable host-facing orchestration context (updated via port APIs).
final class SieOrchestrationContext {
  /// Creates context.
  const SieOrchestrationContext({
    this.lifecycle = SieAppLifecycleState.cold,
    this.routeKind = SieRouteCapabilityKind.dashboard,
    this.securityLevel = SieSecurityLevel.l1Standard,
    this.interactionEnabled = true,
    this.availability = SieInteractionAvailability.full,
    this.accessibility = SieAccessibilityState.defaults,
    this.focus = SieFocusState.defaults,
    this.modal = SieModalKind.none,
    this.suspendSieInModal = true,
  });

  /// Lifecycle.
  final SieAppLifecycleState lifecycle;

  /// Route.
  final SieRouteCapabilityKind routeKind;

  /// Security.
  final SieSecurityLevel securityLevel;

  /// Master interaction switch.
  final bool interactionEnabled;

  /// Feature availability.
  final SieInteractionAvailability availability;

  /// Accessibility.
  final SieAccessibilityState accessibility;

  /// Focus.
  final SieFocusState focus;

  /// Modal.
  final SieModalKind modal;

  /// Suspend SIE dispatch while modal open.
  final bool suspendSieInModal;

  /// Whether app may receive dispatches.
  bool get mayDispatch {
    if (!interactionEnabled) return false;
    if (!focus.windowFocused) return false;
    return switch (lifecycle) {
      SieAppLifecycleState.resumed ||
      SieAppLifecycleState.foregrounding ||
      SieAppLifecycleState.starting =>
        true,
      _ => false,
    };
  }

  /// Whether SIE dispatch is allowed by context (before arbitration).
  bool get sieContextAllowed {
    if (!availability.sieOperational) return false;
    if (modal != SieModalKind.none && suspendSieInModal) return false;
    // L4: no SIE activate path at orchestrator (locomotion gated upstream).
    if (securityLevel == SieSecurityLevel.l4Irreversible) return false;
    return true;
  }

  /// Copy.
  SieOrchestrationContext copyWith({
    SieAppLifecycleState? lifecycle,
    SieRouteCapabilityKind? routeKind,
    SieSecurityLevel? securityLevel,
    bool? interactionEnabled,
    SieInteractionAvailability? availability,
    SieAccessibilityState? accessibility,
    SieFocusState? focus,
    SieModalKind? modal,
    bool? suspendSieInModal,
  }) {
    return SieOrchestrationContext(
      lifecycle: lifecycle ?? this.lifecycle,
      routeKind: routeKind ?? this.routeKind,
      securityLevel: securityLevel ?? this.securityLevel,
      interactionEnabled: interactionEnabled ?? this.interactionEnabled,
      availability: availability ?? this.availability,
      accessibility: accessibility ?? this.accessibility,
      focus: focus ?? this.focus,
      modal: modal ?? this.modal,
      suspendSieInModal: suspendSieInModal ?? this.suspendSieInModal,
    );
  }
}

/// Frame input: arbitration + optional SIE pointer batch.
final class SieOrchestrationFrameInput {
  /// Creates input.
  const SieOrchestrationFrameInput({
    required this.timestamp,
    required this.arbitration,
    this.siePointerEvents = const [],
    this.frameSequence,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Arbitration snapshot (required authority).
  final SieArbitrationSnapshot arbitration;

  /// SIE pointer events pending dispatch (Pointer Bridge output).
  final List<SiePointerEvent> siePointerEvents;

  /// Optional override sequence.
  final int? frameSequence;
}
