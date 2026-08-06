import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_policy.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';

/// Pure policy sync helpers (no I/O).
abstract final class SieIntegrationPolicySync {
  /// Build arbitration context from route policy + a11y.
  static SieArbitrationContext arbitrationContext({
    required SieRoutePolicy policy,
    required bool accessibilityMode,
    required bool paused,
    required bool windowFocused,
  }) {
    final base = switch (policy.capabilityKind) {
      SieRouteCapabilityKind.marketing => SieArbitrationContext.marketing(),
      SieRouteCapabilityKind.dashboard => SieArbitrationContext.dashboard(),
      SieRouteCapabilityKind.courses => SieArbitrationContext.dashboard(),
      SieRouteCapabilityKind.admin => SieArbitrationContext.admin(),
      SieRouteCapabilityKind.authentication =>
        SieArbitrationContext.authentication(),
      SieRouteCapabilityKind.payment => SieArbitrationContext.payment(),
      SieRouteCapabilityKind.custom => SieArbitrationContext.dashboard(),
    };

    final sieOn = policy.allowsSie;
    final allowed = sieOn
        ? {
            ...base.allowedSources,
            if (!base.allowedSources.contains(SieInputSource.sie))
              SieInputSource.sie,
          }
        : base.allowedSources
            .where((s) => s != SieInputSource.sie)
            .toSet();

    return base.copyWith(
      routeKind: policy.capabilityKind,
      allowedSources: allowed,
      sieEnabled: sieOn,
      accessibilityMode: accessibilityMode,
      paused: paused,
      windowFocused: windowFocused,
    );
  }

  /// Build intent context from route policy.
  static SieIntentContext intentContext({
    required SieRoutePolicy policy,
    required SieAccessibilityState accessibility,
    required bool sieEnabled,
    required bool paused,
    required bool platformAllowsSie,
    SieIntentPolicy intentPolicy = SieIntentPolicy.standard,
  }) {
    var effectivePolicy = intentPolicy;
    if (accessibility.dwellMode) {
      effectivePolicy = SieIntentPolicy.accessibility;
    }
    return SieIntentContext(
      route: policy.capability,
      securityLevel: policy.securityLevel,
      policy: effectivePolicy,
      sieEnabled: sieEnabled && policy.allowsSie,
      paused: paused,
      platformAllowsSie: platformAllowsSie,
    );
  }

  /// Resolve degradation from availability + security + host flag.
  static SieDegradationReason resolveDegradation({
    required bool hostSieEnabled,
    required SieRoutePolicy policy,
    required SieInteractionAvailability availability,
    required bool permissionGranted,
  }) {
    if (!hostSieEnabled) return SieDegradationReason.hostDisabled;
    if (policy.securityLevel == SieSecurityLevel.l4Irreversible) {
      return SieDegradationReason.securityRestricted;
    }
    if (!policy.allowsSie) return SieDegradationReason.routeDisabled;
    if (!availability.platformAllowsSie || !availability.sieSupported) {
      return SieDegradationReason.platformUnsupported;
    }
    if (!permissionGranted || !availability.cameraPermissionGranted) {
      return SieDegradationReason.permissionDenied;
    }
    if (!availability.cameraAvailable) {
      return SieDegradationReason.cameraUnavailable;
    }
    if (!availability.handTrackingEnabled || !availability.gesturesEnabled) {
      return SieDegradationReason.visionUnavailable;
    }
    if (!availability.cursorEnabled) {
      return SieDegradationReason.featureDisabled;
    }
    return SieDegradationReason.none;
  }

  /// Effective SIE enablement after all gates.
  static bool effectiveSieEnabled({
    required bool hostSieEnabled,
    required SieRoutePolicy policy,
    required SieInteractionAvailability availability,
    required bool permissionGranted,
  }) {
    final reason = resolveDegradation(
      hostSieEnabled: hostSieEnabled,
      policy: policy,
      availability: availability,
      permissionGranted: permissionGranted,
    );
    return reason == SieDegradationReason.none;
  }
}
