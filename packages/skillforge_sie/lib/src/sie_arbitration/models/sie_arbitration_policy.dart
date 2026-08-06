import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// Immutable activity claim from one modality (host or SIE probe).
final class SieInputActivityClaim {
  /// Creates claim.
  const SieInputActivityClaim({
    required this.timestamp,
    required this.source,
    required this.kind,
    this.available = true,
    this.sequence = 0,
    this.metadata = const {},
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Source modality.
  final SieInputSource source;

  /// Activity kind.
  final SieInputActivityKind kind;

  /// Device currently available.
  final bool available;

  /// Optional sequence.
  final int sequence;

  /// Metadata.
  final Map<String, Object?> metadata;
}

/// Route / app arbitration context.
final class SieArbitrationContext {
  /// Creates context.
  const SieArbitrationContext({
    required this.routeKind,
    required this.allowedSources,
    this.sieEnabled = true,
    this.accessibilityMode = false,
    this.paused = false,
    this.windowFocused = true,
    this.lockedSource,
    this.manualSource,
  });

  /// Default dashboard — all v1 sources.
  factory SieArbitrationContext.dashboard() => const SieArbitrationContext(
        routeKind: SieRouteCapabilityKind.dashboard,
        allowedSources: {
          SieInputSource.mouse,
          SieInputSource.touch,
          SieInputSource.keyboard,
          SieInputSource.sie,
        },
      );

  /// Marketing — all v1.
  factory SieArbitrationContext.marketing() => const SieArbitrationContext(
        routeKind: SieRouteCapabilityKind.marketing,
        allowedSources: {
          SieInputSource.mouse,
          SieInputSource.touch,
          SieInputSource.keyboard,
          SieInputSource.sie,
        },
      );

  /// Authentication — restrict SIE ownership.
  factory SieArbitrationContext.authentication() => const SieArbitrationContext(
        routeKind: SieRouteCapabilityKind.authentication,
        allowedSources: {
          SieInputSource.mouse,
          SieInputSource.touch,
          SieInputSource.keyboard,
        },
        sieEnabled: false,
      );

  /// Payment — mouse/touch only (confirm safety).
  factory SieArbitrationContext.payment() => const SieArbitrationContext(
        routeKind: SieRouteCapabilityKind.payment,
        allowedSources: {
          SieInputSource.mouse,
          SieInputSource.touch,
        },
        sieEnabled: false,
      );

  /// Admin — traditional preferred; SIE locomotion may be allowed by host.
  factory SieArbitrationContext.admin() => const SieArbitrationContext(
        routeKind: SieRouteCapabilityKind.admin,
        allowedSources: {
          SieInputSource.mouse,
          SieInputSource.touch,
          SieInputSource.keyboard,
          SieInputSource.sie,
        },
      );

  /// Route kind.
  final SieRouteCapabilityKind routeKind;

  /// Allowed owners on this route.
  final Set<SieInputSource> allowedSources;

  /// SIE subsystem enabled.
  final bool sieEnabled;

  /// Accessibility mode (boosts a11y priority policy).
  final bool accessibilityMode;

  /// App paused.
  final bool paused;

  /// Window focused.
  final bool windowFocused;

  /// Locked owner (locked policy).
  final SieInputSource? lockedSource;

  /// Manual owner (manual policy).
  final SieInputSource? manualSource;

  /// Whether [source] may own under this context.
  bool allows(SieInputSource source) {
    if (source == SieInputSource.none) return true;
    if (!source.isVersion1) return false; // future not activated
    if (source == SieInputSource.sie && !sieEnabled) return false;
    return allowedSources.contains(source);
  }

  /// Copy.
  SieArbitrationContext copyWith({
    SieRouteCapabilityKind? routeKind,
    Set<SieInputSource>? allowedSources,
    bool? sieEnabled,
    bool? accessibilityMode,
    bool? paused,
    bool? windowFocused,
    SieInputSource? lockedSource,
    bool clearLocked = false,
    SieInputSource? manualSource,
    bool clearManual = false,
  }) {
    return SieArbitrationContext(
      routeKind: routeKind ?? this.routeKind,
      allowedSources: allowedSources ?? this.allowedSources,
      sieEnabled: sieEnabled ?? this.sieEnabled,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      paused: paused ?? this.paused,
      windowFocused: windowFocused ?? this.windowFocused,
      lockedSource: clearLocked ? null : (lockedSource ?? this.lockedSource),
      manualSource: clearManual ? null : (manualSource ?? this.manualSource),
    );
  }
}

/// Arbitration policy configuration.
final class SieArbitrationPolicy {
  /// Creates policy.
  const SieArbitrationPolicy({
    required this.id,
    this.traditionalSupremacy = true,
    this.simultaneousWindowMs = 50,
    this.releaseSieOnLostTracking = true,
    this.releaseOnFocusLoss = true,
    this.futureModalitiesEnabled = false,
  });

  /// Last active wins (default; ADR-019 supremacy on ties).
  static const SieArbitrationPolicy lastActiveWins = SieArbitrationPolicy(
    id: SieArbitrationPolicyId.lastActiveWins,
  );

  /// Locked.
  static const SieArbitrationPolicy lockedOwnership = SieArbitrationPolicy(
    id: SieArbitrationPolicyId.lockedOwnership,
  );

  /// Manual.
  static const SieArbitrationPolicy manualOverride = SieArbitrationPolicy(
    id: SieArbitrationPolicyId.manualOverride,
  );

  /// Accessibility priority.
  static const SieArbitrationPolicy accessibilityPriority =
      SieArbitrationPolicy(
    id: SieArbitrationPolicyId.accessibilityPriority,
  );

  /// Application / route policy.
  static const SieArbitrationPolicy applicationPolicy = SieArbitrationPolicy(
    id: SieArbitrationPolicyId.applicationPolicy,
  );

  /// Policy id.
  final SieArbitrationPolicyId id;

  /// ADR-019: traditional beats SIE on simultaneous conflict.
  final bool traditionalSupremacy;

  /// Claims within this window are "simultaneous".
  final double simultaneousWindowMs;

  /// Release SIE owner on LostTracking.
  final bool releaseSieOnLostTracking;

  /// Release owner on focus loss.
  final bool releaseOnFocusLoss;

  /// Future modalities (always false in v1 activation).
  final bool futureModalitiesEnabled;

  /// Lookup.
  static SieArbitrationPolicy fromId(SieArbitrationPolicyId id) {
    return switch (id) {
      SieArbitrationPolicyId.lastActiveWins => lastActiveWins,
      SieArbitrationPolicyId.lockedOwnership => lockedOwnership,
      SieArbitrationPolicyId.manualOverride => manualOverride,
      SieArbitrationPolicyId.accessibilityPriority => accessibilityPriority,
      SieArbitrationPolicyId.applicationPolicy => applicationPolicy,
    };
  }
}
