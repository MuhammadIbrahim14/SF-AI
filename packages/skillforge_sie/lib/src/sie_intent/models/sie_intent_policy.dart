import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// Which intents a route may emit.
final class SieRouteCapability {
  /// Creates capability.
  const SieRouteCapability({
    required this.kind,
    required this.allowed,
    required this.securityLevel,
    this.sieEnabled = true,
    this.requireHoverForSelect = false,
    this.allowDrag = true,
    this.allowScroll = true,
  });

  /// Route kind.
  final SieRouteCapabilityKind kind;

  /// Allowed intent kinds.
  final Set<SieIntentKind> allowed;

  /// Default security for this route.
  final SieSecurityLevel securityLevel;

  /// Whether SIE is enabled on this route.
  final bool sieEnabled;

  /// Require hover target before Select.
  final bool requireHoverForSelect;

  /// Allow drag family.
  final bool allowDrag;

  /// Allow scroll.
  final bool allowScroll;

  /// Whether [kind] is permitted.
  bool allows(SieIntentKind kind) => sieEnabled && allowed.contains(kind);

  /// Marketing preset.
  static const SieRouteCapability marketing = SieRouteCapability(
    kind: SieRouteCapabilityKind.marketing,
    securityLevel: SieSecurityLevel.l0Public,
    requireHoverForSelect: false,
    allowDrag: false,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.cancel,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
    },
  );

  /// Dashboard preset.
  static const SieRouteCapability dashboard = SieRouteCapability(
    kind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.beginDrag,
      SieIntentKind.updateDrag,
      SieIntentKind.endDrag,
      SieIntentKind.cancel,
      SieIntentKind.scrollDelta,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
      SieIntentKind.dwellSelect,
    },
  );

  /// Courses preset.
  static const SieRouteCapability courses = SieRouteCapability(
    kind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    allowDrag: true,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.beginDrag,
      SieIntentKind.updateDrag,
      SieIntentKind.endDrag,
      SieIntentKind.cancel,
      SieIntentKind.scrollDelta,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
      SieIntentKind.dwellSelect,
    },
  );

  /// Admin — restricted.
  static const SieRouteCapability admin = SieRouteCapability(
    kind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    requireHoverForSelect: true,
    allowDrag: false,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.cancel,
      SieIntentKind.scrollDelta,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
    },
  );

  /// Authentication — limited (no gesture Select for secrets).
  static const SieRouteCapability authentication = SieRouteCapability(
    kind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    sieEnabled: true,
    allowDrag: false,
    allowScroll: false,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.cancel,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
    },
  );

  /// Payment — navigation / browse only; no confirm Select.
  static const SieRouteCapability payment = SieRouteCapability(
    kind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    allowDrag: false,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.scrollDelta,
      SieIntentKind.cancel,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
    },
  );

  /// Lookup preset.
  static SieRouteCapability forKind(SieRouteCapabilityKind kind) {
    return switch (kind) {
      SieRouteCapabilityKind.marketing => marketing,
      SieRouteCapabilityKind.dashboard => dashboard,
      SieRouteCapabilityKind.courses => courses,
      SieRouteCapabilityKind.admin => admin,
      SieRouteCapabilityKind.authentication => authentication,
      SieRouteCapabilityKind.payment => payment,
      SieRouteCapabilityKind.custom => dashboard,
    };
  }
}

/// Intent policy — which intents may be generated (not gesture defs).
final class SieIntentPolicy {
  /// Creates policy.
  const SieIntentPolicy({
    required this.id,
    required this.allowed,
    this.dwellSelectEnabled = false,
    this.dragEnabled = true,
    this.futureIntentsEnabled = false,
  });

  /// Standard.
  static const SieIntentPolicy standard = SieIntentPolicy(
    id: SieIntentPolicyId.standard,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.beginDrag,
      SieIntentKind.updateDrag,
      SieIntentKind.endDrag,
      SieIntentKind.cancel,
      SieIntentKind.scrollDelta,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
    },
  );

  /// Accessibility.
  static const SieIntentPolicy accessibility = SieIntentPolicy(
    id: SieIntentPolicyId.accessibility,
    dwellSelectEnabled: true,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.beginDrag,
      SieIntentKind.updateDrag,
      SieIntentKind.endDrag,
      SieIntentKind.cancel,
      SieIntentKind.scrollDelta,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
      SieIntentKind.dwellSelect,
    },
  );

  /// Restricted.
  static const SieIntentPolicy restricted = SieIntentPolicy(
    id: SieIntentPolicyId.restricted,
    dragEnabled: false,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.cancel,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
    },
  );

  /// Debug.
  static const SieIntentPolicy debug = SieIntentPolicy(
    id: SieIntentPolicyId.debug,
    dwellSelectEnabled: true,
    allowed: {
      SieIntentKind.moveCursor,
      SieIntentKind.hoverEnter,
      SieIntentKind.hoverExit,
      SieIntentKind.select,
      SieIntentKind.selectHold,
      SieIntentKind.selectRelease,
      SieIntentKind.beginDrag,
      SieIntentKind.updateDrag,
      SieIntentKind.endDrag,
      SieIntentKind.cancel,
      SieIntentKind.scrollDelta,
      SieIntentKind.pauseSie,
      SieIntentKind.resumeSie,
      SieIntentKind.dwellSelect,
    },
  );

  /// Policy id.
  final SieIntentPolicyId id;

  /// Allowed intents.
  final Set<SieIntentKind> allowed;

  /// Dwell select permission.
  final bool dwellSelectEnabled;

  /// Drag permission.
  final bool dragEnabled;

  /// Future intents (always false in v1 activation).
  final bool futureIntentsEnabled;

  /// Whether [kind] is allowed by this policy.
  bool allows(SieIntentKind kind) {
    if (kind == SieIntentKind.dwellSelect && !dwellSelectEnabled) {
      return false;
    }
    if ((kind == SieIntentKind.beginDrag ||
            kind == SieIntentKind.updateDrag ||
            kind == SieIntentKind.endDrag) &&
        !dragEnabled) {
      return false;
    }
    if ((kind == SieIntentKind.zoomDelta ||
            kind == SieIntentKind.rotateDelta ||
            kind == SieIntentKind.navigateRelative) &&
        !futureIntentsEnabled) {
      return false;
    }
    return allowed.contains(kind);
  }

  /// Lookup.
  static SieIntentPolicy fromId(SieIntentPolicyId id) {
    return switch (id) {
      SieIntentPolicyId.standard => standard,
      SieIntentPolicyId.accessibility => accessibility,
      SieIntentPolicyId.restricted => restricted,
      SieIntentPolicyId.debug => debug,
    };
  }
}
