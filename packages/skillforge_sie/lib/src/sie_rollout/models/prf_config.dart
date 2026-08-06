import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';

/// Independent PRF feature flags (immutable).
final class PrfFeatureFlags {
  /// Creates flags.
  const PrfFeatureFlags({
    this.enableSie = false,
    this.experimentalGestures = false,
    this.twoHandTracking = false,
    this.eyeTracking = false,
    this.voiceControl = false,
    this.debugOverlay = false,
    this.accessibilityFeatures = true,
    this.betaFeatures = false,
  });

  /// All off (safe).
  static const PrfFeatureFlags disabled = PrfFeatureFlags();

  /// Conservative production defaults.
  static const PrfFeatureFlags productionDefaults = PrfFeatureFlags(
    enableSie: true,
    accessibilityFeatures: true,
  );

  /// Dev / QA profile.
  static const PrfFeatureFlags development = PrfFeatureFlags(
    enableSie: true,
    experimentalGestures: true,
    twoHandTracking: true,
    debugOverlay: true,
    accessibilityFeatures: true,
    betaFeatures: true,
  );

  /// Master SIE.
  final bool enableSie;

  /// Experimental gestures.
  final bool experimentalGestures;

  /// Two-hand.
  final bool twoHandTracking;

  /// Future eye tracking (never auto-on).
  final bool eyeTracking;

  /// Future voice (never auto-on).
  final bool voiceControl;

  /// Debug overlay.
  final bool debugOverlay;

  /// Accessibility.
  final bool accessibilityFeatures;

  /// Beta pack.
  final bool betaFeatures;

  /// Lookup.
  bool isEnabled(PrfFeatureFlagId id) => switch (id) {
        PrfFeatureFlagId.enableSie => enableSie,
        PrfFeatureFlagId.experimentalGestures => experimentalGestures,
        PrfFeatureFlagId.twoHandTracking => twoHandTracking,
        PrfFeatureFlagId.eyeTracking => eyeTracking,
        PrfFeatureFlagId.voiceControl => voiceControl,
        PrfFeatureFlagId.debugOverlay => debugOverlay,
        PrfFeatureFlagId.accessibilityFeatures => accessibilityFeatures,
        PrfFeatureFlagId.betaFeatures => betaFeatures,
      };

  /// Map snapshot.
  Map<String, bool> asMap() => {
        for (final id in PrfFeatureFlagId.values) id.name: isEnabled(id),
      };

  /// Copy.
  PrfFeatureFlags copyWith({
    bool? enableSie,
    bool? experimentalGestures,
    bool? twoHandTracking,
    bool? eyeTracking,
    bool? voiceControl,
    bool? debugOverlay,
    bool? accessibilityFeatures,
    bool? betaFeatures,
  }) {
    return PrfFeatureFlags(
      enableSie: enableSie ?? this.enableSie,
      experimentalGestures: experimentalGestures ?? this.experimentalGestures,
      twoHandTracking: twoHandTracking ?? this.twoHandTracking,
      eyeTracking: eyeTracking ?? this.eyeTracking,
      voiceControl: voiceControl ?? this.voiceControl,
      debugOverlay: debugOverlay ?? this.debugOverlay,
      accessibilityFeatures:
          accessibilityFeatures ?? this.accessibilityFeatures,
      betaFeatures: betaFeatures ?? this.betaFeatures,
    );
  }

  /// Merge overlay (non-null wins).
  PrfFeatureFlags merge(PrfFeatureFlags? overlay) {
    if (overlay == null) return this;
    return copyWith(
      enableSie: overlay.enableSie,
      experimentalGestures: overlay.experimentalGestures,
      twoHandTracking: overlay.twoHandTracking,
      eyeTracking: overlay.eyeTracking,
      voiceControl: overlay.voiceControl,
      debugOverlay: overlay.debugOverlay,
      accessibilityFeatures: overlay.accessibilityFeatures,
      betaFeatures: overlay.betaFeatures,
    );
  }
}

/// Platform maturity policy map.
final class PrfPlatformPolicy {
  /// Creates policy.
  const PrfPlatformPolicy({
    this.web = PrfPlatformMaturity.stable,
    this.android = PrfPlatformMaturity.stable,
    this.ios = PrfPlatformMaturity.experimental,
    this.windows = PrfPlatformMaturity.beta,
    this.macos = PrfPlatformMaturity.experimental,
    this.linux = PrfPlatformMaturity.disabled,
  });

  /// Defaults matching prompt example.
  static const PrfPlatformPolicy defaults = PrfPlatformPolicy();

  /// Web.
  final PrfPlatformMaturity web;

  /// Android.
  final PrfPlatformMaturity android;

  /// iOS.
  final PrfPlatformMaturity ios;

  /// Windows.
  final PrfPlatformMaturity windows;

  /// macOS.
  final PrfPlatformMaturity macos;

  /// Linux.
  final PrfPlatformMaturity linux;

  /// Maturity for [kind].
  PrfPlatformMaturity maturityOf(SiePlatformKind kind) => switch (kind) {
        SiePlatformKind.web => web,
        SiePlatformKind.android => android,
        SiePlatformKind.ios => ios,
        SiePlatformKind.windows => windows,
        SiePlatformKind.macos => macos,
        SiePlatformKind.linux => linux,
        SiePlatformKind.unsupported => PrfPlatformMaturity.disabled,
      };

  /// Whether platform may run SIE at all.
  bool allows(SiePlatformKind kind) =>
      maturityOf(kind) != PrfPlatformMaturity.disabled;

  /// Copy.
  PrfPlatformPolicy copyWith({
    PrfPlatformMaturity? web,
    PrfPlatformMaturity? android,
    PrfPlatformMaturity? ios,
    PrfPlatformMaturity? windows,
    PrfPlatformMaturity? macos,
    PrfPlatformMaturity? linux,
  }) {
    return PrfPlatformPolicy(
      web: web ?? this.web,
      android: android ?? this.android,
      ios: ios ?? this.ios,
      windows: windows ?? this.windows,
      macos: macos ?? this.macos,
      linux: linux ?? this.linux,
    );
  }
}

/// Segment allow-list for staged rollout.
final class PrfSegmentPolicy {
  /// Creates policy.
  const PrfSegmentPolicy({
    this.allowed = const {
      PrfUserSegment.internalDevelopers,
      PrfUserSegment.qaTeam,
      PrfUserSegment.betaTesters,
      PrfUserSegment.publicUsers,
      PrfUserSegment.premiumUsers,
      PrfUserSegment.enterpriseCustomers,
      PrfUserSegment.administrators,
    },
  });

  /// Internal + QA only.
  static const PrfSegmentPolicy internalOnly = PrfSegmentPolicy(
    allowed: {
      PrfUserSegment.internalDevelopers,
      PrfUserSegment.qaTeam,
    },
  );

  /// Beta+.
  static const PrfSegmentPolicy betaAndAbove = PrfSegmentPolicy(
    allowed: {
      PrfUserSegment.internalDevelopers,
      PrfUserSegment.qaTeam,
      PrfUserSegment.betaTesters,
    },
  );

  /// Allowed segments.
  final Set<PrfUserSegment> allowed;

  /// Whether [segment] is allowed.
  bool allows(PrfUserSegment segment) => allowed.contains(segment);
}

/// Performance / telemetry thresholds (configurable).
final class PrfPerformanceThresholds {
  /// Creates thresholds.
  const PrfPerformanceThresholds({
    this.minAverageFps = 24,
    this.minCameraFps = 15,
    this.minTrackingStability = 0.7,
    this.minGestureConfidence = 0.55,
    this.maxCursorLatencyMs = 40,
    this.maxProcessingLatencyMs = 35,
    this.maxCpuUsage = 0.85,
    this.maxMemoryMb = 512,
    this.maxLostTrackingRate = 0.25,
    this.maxFalseClickRate = 0.08,
    this.maxCrashRate = 0.01,
  });

  /// Defaults.
  static const PrfPerformanceThresholds defaults = PrfPerformanceThresholds();

  /// Min UI FPS.
  final double minAverageFps;

  /// Min camera FPS.
  final double minCameraFps;

  /// Min tracking stability 0–1.
  final double minTrackingStability;

  /// Min gesture confidence.
  final double minGestureConfidence;

  /// Max cursor latency.
  final double maxCursorLatencyMs;

  /// Max processing latency.
  final double maxProcessingLatencyMs;

  /// Max CPU 0–1.
  final double maxCpuUsage;

  /// Max memory MB.
  final double maxMemoryMb;

  /// Max lost-tracking rate.
  final double maxLostTrackingRate;

  /// Max false-click rate.
  final double maxFalseClickRate;

  /// Max crash rate.
  final double maxCrashRate;
}

/// Kill switch state.
final class PrfKillSwitch {
  /// Creates kill switch.
  const PrfKillSwitch({
    this.localActive = false,
    this.remoteActive = false,
    this.developmentOverride = false,
    this.qaOverride = false,
  });

  /// Clear.
  static const PrfKillSwitch clear = PrfKillSwitch();

  /// Local emergency.
  final bool localActive;

  /// Remote (future).
  final bool remoteActive;

  /// Dev override forces enable past kill (dev only).
  final bool developmentOverride;

  /// QA override forces enable past kill (QA only).
  final bool qaOverride;

  /// Effective kill (overrides can bypass for allowed segments).
  bool isActive({required PrfUserSegment segment}) {
    final killed = localActive || remoteActive;
    if (!killed) return false;
    if (developmentOverride &&
        segment == PrfUserSegment.internalDevelopers) {
      return false;
    }
    if (qaOverride && segment == PrfUserSegment.qaTeam) {
      return false;
    }
    return true;
  }

  /// Copy.
  PrfKillSwitch copyWith({
    bool? localActive,
    bool? remoteActive,
    bool? developmentOverride,
    bool? qaOverride,
  }) {
    return PrfKillSwitch(
      localActive: localActive ?? this.localActive,
      remoteActive: remoteActive ?? this.remoteActive,
      developmentOverride: developmentOverride ?? this.developmentOverride,
      qaOverride: qaOverride ?? this.qaOverride,
    );
  }
}

/// Aggregated immutable PRF configuration.
final class PrfConfig {
  /// Creates config.
  const PrfConfig({
    this.flags = PrfFeatureFlags.productionDefaults,
    this.platforms = PrfPlatformPolicy.defaults,
    this.segments = const PrfSegmentPolicy(),
    this.thresholds = PrfPerformanceThresholds.defaults,
    this.killSwitch = PrfKillSwitch.clear,
    this.canaryPhase = PrfCanaryPhase.p100,
    this.experimentId,
    this.source = PrfConfigSource.localDefaults,
  });

  /// Safe disabled.
  static const PrfConfig disabled = PrfConfig(
    flags: PrfFeatureFlags.disabled,
    canaryPhase: PrfCanaryPhase.off,
  );

  /// Flags.
  final PrfFeatureFlags flags;

  /// Platforms.
  final PrfPlatformPolicy platforms;

  /// Segments.
  final PrfSegmentPolicy segments;

  /// Thresholds.
  final PrfPerformanceThresholds thresholds;

  /// Kill switch.
  final PrfKillSwitch killSwitch;

  /// Canary phase.
  final PrfCanaryPhase canaryPhase;

  /// Optional A/B experiment id.
  final String? experimentId;

  /// Winning config source label.
  final PrfConfigSource source;

  /// Copy.
  PrfConfig copyWith({
    PrfFeatureFlags? flags,
    PrfPlatformPolicy? platforms,
    PrfSegmentPolicy? segments,
    PrfPerformanceThresholds? thresholds,
    PrfKillSwitch? killSwitch,
    PrfCanaryPhase? canaryPhase,
    String? experimentId,
    bool clearExperiment = false,
    PrfConfigSource? source,
  }) {
    return PrfConfig(
      flags: flags ?? this.flags,
      platforms: platforms ?? this.platforms,
      segments: segments ?? this.segments,
      thresholds: thresholds ?? this.thresholds,
      killSwitch: killSwitch ?? this.killSwitch,
      canaryPhase: canaryPhase ?? this.canaryPhase,
      experimentId:
          clearExperiment ? null : (experimentId ?? this.experimentId),
      source: source ?? this.source,
    );
  }
}

/// Route rollout mode (aligned with Integration / IDS).
abstract final class PrfRouteCatalog {
  /// Whether route allows SIE under rollout (uses Integration catalog).
  static bool allowsSie(String routeId) {
    final policy = _lookup(routeId);
    if (policy == null) return false;
    if (policy.securityLevel == SieSecurityLevel.l4Irreversible) return false;
    return policy.allowsSie;
  }

  /// Mode for diagnostics.
  static SieRouteSieMode modeOf(String routeId) =>
      _lookup(routeId)?.mode ?? SieRouteSieMode.disabled;

  static SieRoutePolicy? _lookup(String routeId) {
    for (final p in SieSkillForgeRouteCatalog.defaults) {
      if (p.routeId == routeId) return p;
    }
    // Common aliases
    return switch (routeId) {
      'account.deletion' || 'admin.critical' => const SieRoutePolicy(
          routeId: 'admin.critical',
          displayName: 'Admin Critical',
          mode: SieRouteSieMode.disabled,
          capabilityKind: SieRouteCapabilityKind.admin,
          securityLevel: SieSecurityLevel.l4Irreversible,
          sieEnabled: false,
        ),
      'course.viewer' => SieSkillForgeRouteCatalog.courses,
      'student.payments' || 'payments.checkout' => SieSkillForgeRouteCatalog.payments,
      _ => null,
    };
  }
}
