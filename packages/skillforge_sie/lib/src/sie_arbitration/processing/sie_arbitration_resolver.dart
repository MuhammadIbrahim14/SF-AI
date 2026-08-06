import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_policy.dart';

/// Internal resolution outcome.
final class SieArbitrationDecision {
  /// Creates decision.
  const SieArbitrationDecision({
    required this.owner,
    required this.reason,
    required this.conflictCount,
    this.trigger,
  });

  /// Owner.
  final SieInputSource owner;

  /// Reason.
  final SieOwnershipReason reason;

  /// Conflicts.
  final int conflictCount;

  /// Trigger claim.
  final SieInputActivityClaim? trigger;
}

/// Deterministic ownership resolver (ADR-019 aware).
final class SieArbitrationResolver {
  /// Creates resolver.
  SieArbitrationResolver({
    SieArbitrationPolicy policy = SieArbitrationPolicy.lastActiveWins,
  }) : _policy = policy;

  SieArbitrationPolicy _policy;
  SieInputSource _owner = SieInputSource.none;
  final Map<SieInputSource, DateTime> _lastActivity = {};
  final Map<SieInputSource, bool> _availability = {
    for (final s in SieInputSource.values)
      if (s != SieInputSource.none) s: s.isVersion1,
  };

  /// Policy.
  SieArbitrationPolicy get policy => _policy;

  /// Current owner.
  SieInputSource get owner => _owner;

  /// Set policy.
  void setPolicy(SieArbitrationPolicy policy) => _policy = policy;

  /// Reset.
  void reset() {
    _owner = SieInputSource.none;
    _lastActivity.clear();
    for (final s in SieInputSource.values) {
      if (s != SieInputSource.none) {
        _availability[s] = s.isVersion1;
      }
    }
  }

  /// Resolve one frame.
  SieArbitrationDecision resolve({
    required List<SieInputActivityClaim> claims,
    required SieArbitrationContext context,
  }) {
    var conflicts = 0;
    SieInputActivityClaim? trigger;

    // Global pause / focus.
    if (context.paused) {
      final prev = _owner;
      _owner = SieInputSource.none;
      return SieArbitrationDecision(
        owner: SieInputSource.none,
        reason: prev == SieInputSource.none
            ? SieOwnershipReason.none
            : SieOwnershipReason.paused,
        conflictCount: 0,
      );
    }
    if (!context.windowFocused && _policy.releaseOnFocusLoss) {
      final prev = _owner;
      _owner = SieInputSource.none;
      return SieArbitrationDecision(
        owner: SieInputSource.none,
        reason: prev == SieInputSource.none
            ? SieOwnershipReason.none
            : SieOwnershipReason.focusLost,
        conflictCount: 0,
      );
    }

    // Ingest claims.
    for (final c in claims) {
      trigger ??= c;
      if (c.source.isFuture && !_policy.futureModalitiesEnabled) {
        continue;
      }
      if (c.kind == SieInputActivityKind.disconnect || !c.available) {
        _availability[c.source] = false;
        if (_owner == c.source) {
          _owner = SieInputSource.none;
          return SieArbitrationDecision(
            owner: SieInputSource.none,
            reason: SieOwnershipReason.deviceUnavailable,
            conflictCount: 0,
            trigger: c,
          );
        }
        continue;
      }
      _availability[c.source] = true;

      if (c.kind == SieInputActivityKind.lostTracking &&
          c.source == SieInputSource.sie &&
          _policy.releaseSieOnLostTracking) {
        if (_owner == SieInputSource.sie) {
          _owner = SieInputSource.none;
          return SieArbitrationDecision(
            owner: SieInputSource.none,
            reason: SieOwnershipReason.lostTracking,
            conflictCount: 0,
            trigger: c,
          );
        }
        continue;
      }

      if (c.kind == SieInputActivityKind.releaseOwnership) {
        if (_owner == c.source) {
          _owner = SieInputSource.none;
          return SieArbitrationDecision(
            owner: SieInputSource.none,
            reason: SieOwnershipReason.released,
            conflictCount: 0,
            trigger: c,
          );
        }
        continue;
      }

      // Activity — record timestamp.
      if (c.kind != SieInputActivityKind.presence) {
        _lastActivity[c.source] = c.timestamp;
      } else {
        _lastActivity.putIfAbsent(c.source, () => c.timestamp);
      }
    }

    // Drop owner if route no longer allows.
    if (_owner != SieInputSource.none && !context.allows(_owner)) {
      _owner = SieInputSource.none;
      return SieArbitrationDecision(
        owner: SieInputSource.none,
        reason: SieOwnershipReason.routeRestricted,
        conflictCount: 0,
        trigger: trigger,
      );
    }

    // Policy selection.
    final decision = switch (_policy.id) {
      SieArbitrationPolicyId.lockedOwnership =>
        _resolveLocked(context, claims, conflicts),
      SieArbitrationPolicyId.manualOverride =>
        _resolveManual(context, claims, conflicts),
      SieArbitrationPolicyId.accessibilityPriority =>
        _resolveAccessibility(context, claims, conflicts),
      SieArbitrationPolicyId.applicationPolicy =>
        _resolveApplication(context, claims, conflicts),
      SieArbitrationPolicyId.lastActiveWins =>
        _resolveLastActive(context, claims, conflicts),
    };

    return decision;
  }

  SieArbitrationDecision _resolveLocked(
    SieArbitrationContext context,
    List<SieInputActivityClaim> claims,
    int conflicts,
  ) {
    final locked = context.lockedSource;
    if (locked == null || locked == SieInputSource.none) {
      return _resolveLastActive(context, claims, conflicts);
    }
    if (!context.allows(locked) || !(_availability[locked] ?? false)) {
      _owner = SieInputSource.none;
      return SieArbitrationDecision(
        owner: SieInputSource.none,
        reason: SieOwnershipReason.deviceUnavailable,
        conflictCount: conflicts,
      );
    }
    _owner = locked;
    return SieArbitrationDecision(
      owner: locked,
      reason: SieOwnershipReason.locked,
      conflictCount: conflicts,
    );
  }

  SieArbitrationDecision _resolveManual(
    SieArbitrationContext context,
    List<SieInputActivityClaim> claims,
    int conflicts,
  ) {
    final manual = context.manualSource;
    if (manual == null || manual == SieInputSource.none) {
      return _resolveLastActive(context, claims, conflicts);
    }
    if (!context.allows(manual) || !(_availability[manual] ?? false)) {
      _owner = SieInputSource.none;
      return SieArbitrationDecision(
        owner: SieInputSource.none,
        reason: SieOwnershipReason.routeRestricted,
        conflictCount: conflicts,
      );
    }
    _owner = manual;
    return SieArbitrationDecision(
      owner: manual,
      reason: SieOwnershipReason.manual,
      conflictCount: conflicts,
    );
  }

  SieArbitrationDecision _resolveAccessibility(
    SieArbitrationContext context,
    List<SieInputActivityClaim> claims,
    int conflicts,
  ) {
    // Future a11y device would win first when enabled.
    if (_policy.futureModalitiesEnabled &&
        context.allows(SieInputSource.accessibilityDevice) &&
        (_availability[SieInputSource.accessibilityDevice] ?? false) &&
        _lastActivity.containsKey(SieInputSource.accessibilityDevice)) {
      _owner = SieInputSource.accessibilityDevice;
      return const SieArbitrationDecision(
        owner: SieInputSource.accessibilityDevice,
        reason: SieOwnershipReason.acquired,
        conflictCount: 0,
      );
    }
    // Prefer traditional when accessibilityMode.
    if (context.accessibilityMode) {
      final trad = _newestAmong(
        context,
        (s) => s.isTraditional,
      );
      if (trad != null) {
        var reason = SieOwnershipReason.acquired;
        var c = conflicts;
        if (_owner == SieInputSource.sie && trad.isTraditional) {
          reason = SieOwnershipReason.traditionalSupremacy;
          c++;
        }
        _owner = trad;
        return SieArbitrationDecision(
          owner: trad,
          reason: reason,
          conflictCount: c,
        );
      }
    }
    return _resolveLastActive(context, claims, conflicts);
  }

  SieArbitrationDecision _resolveApplication(
    SieArbitrationContext context,
    List<SieInputActivityClaim> claims,
    int conflicts,
  ) {
    // Route allowlist already applied; pick last active among allowed.
    return _resolveLastActive(context, claims, conflicts);
  }

  SieArbitrationDecision _resolveLastActive(
    SieArbitrationContext context,
    List<SieInputActivityClaim> claims,
    int conflicts,
  ) {
    // Gather candidates from recent claims + activity map.
    final activeClaims = claims
        .where(
          (c) =>
              c.available &&
              c.kind != SieInputActivityKind.disconnect &&
              c.kind != SieInputActivityKind.releaseOwnership &&
              c.kind != SieInputActivityKind.lostTracking &&
              context.allows(c.source) &&
              (c.source.isVersion1 || _policy.futureModalitiesEnabled),
        )
        .toList();

    if (activeClaims.isEmpty) {
      // Keep current owner if still valid.
      if (_owner != SieInputSource.none &&
          context.allows(_owner) &&
          (_availability[_owner] ?? false)) {
        return SieArbitrationDecision(
          owner: _owner,
          reason: SieOwnershipReason.none,
          conflictCount: conflicts,
        );
      }
      _owner = SieInputSource.none;
      return SieArbitrationDecision(
        owner: SieInputSource.none,
        reason: SieOwnershipReason.none,
        conflictCount: conflicts,
      );
    }

    // Sort by timestamp descending.
    activeClaims.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final newest = activeClaims.first;
    var winner = newest.source;
    var reason = SieOwnershipReason.acquired;
    var c = conflicts;

    // Simultaneous claims window — ADR-019 traditional supremacy.
    if (_policy.traditionalSupremacy) {
      final window = Duration(milliseconds: _policy.simultaneousWindowMs.round());
      final simultaneous = activeClaims.where((cl) {
        final dt = newest.timestamp.difference(cl.timestamp).abs();
        return dt <= window;
      }).toList();
      if (simultaneous.length > 1) {
        c += simultaneous.length - 1;
        final traditional = simultaneous.where((cl) => cl.source.isTraditional);
        final sie = simultaneous.where((cl) => cl.source == SieInputSource.sie);
        if (traditional.isNotEmpty && sie.isNotEmpty) {
          // Newest traditional wins.
          final tradList = traditional.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          winner = tradList.first.source;
          reason = SieOwnershipReason.traditionalSupremacy;
        } else if (simultaneous.length > 1) {
          reason = SieOwnershipReason.conflictResolved;
        }
      }
    }

    // Also: if current owner is SIE and a traditional claim arrives, traditional wins.
    if (_policy.traditionalSupremacy &&
        _owner == SieInputSource.sie &&
        winner.isTraditional) {
      reason = SieOwnershipReason.traditionalSupremacy;
      c++;
    }

    if (_owner != SieInputSource.none &&
        _owner != winner &&
        reason == SieOwnershipReason.acquired) {
      reason = SieOwnershipReason.conflictResolved;
      c++;
    }

    _owner = winner;
    _lastActivity[winner] = newest.timestamp;
    return SieArbitrationDecision(
      owner: winner,
      reason: reason,
      conflictCount: c,
      trigger: newest,
    );
  }

  SieInputSource? _newestAmong(
    SieArbitrationContext context,
    bool Function(SieInputSource) pred,
  ) {
    SieInputSource? best;
    DateTime? bestTs;
    for (final e in _lastActivity.entries) {
      if (!pred(e.key)) continue;
      if (!context.allows(e.key)) continue;
      if (!(_availability[e.key] ?? false)) continue;
      if (bestTs == null || e.value.isAfter(bestTs)) {
        bestTs = e.value;
        best = e.key;
      }
    }
    return best;
  }
}
