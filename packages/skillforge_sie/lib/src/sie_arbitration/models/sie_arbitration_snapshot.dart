import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_policy.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// Immutable arbitration snapshot — authoritative ownership model.
final class SieArbitrationSnapshot {
  /// Creates snapshot.
  const SieArbitrationSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.owner,
    required this.previousOwner,
    required this.reason,
    required this.policyId,
    required this.routeKind,
    required this.forwardsSiePointers,
    required this.traditionalActive,
    this.conflictCount = 0,
    this.allowedSources = const {},
    this.sourceClaim,
    this.processingMs = 0,
    this.metadata = const {},
  });

  /// Idle none.
  factory SieArbitrationSnapshot.idle({
    required DateTime timestamp,
    int frameSequence = 0,
  }) {
    return SieArbitrationSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      owner: SieInputSource.none,
      previousOwner: SieInputSource.none,
      reason: SieOwnershipReason.none,
      policyId: SieArbitrationPolicyId.lastActiveWins,
      routeKind: SieRouteCapabilityKind.dashboard,
      forwardsSiePointers: false,
      traditionalActive: false,
    );
  }

  /// Timestamp.
  final DateTime timestamp;

  /// Frame / claim sequence.
  final int frameSequence;

  /// Current owner.
  final SieInputSource owner;

  /// Previous owner.
  final SieInputSource previousOwner;

  /// Transition reason.
  final SieOwnershipReason reason;

  /// Active policy.
  final SieArbitrationPolicyId policyId;

  /// Route.
  final SieRouteCapabilityKind routeKind;

  /// Whether Interaction Engine should consume SIE pointer bridge output.
  final bool forwardsSiePointers;

  /// Whether a traditional source is the owner.
  final bool traditionalActive;

  /// Conflicts resolved this decision.
  final int conflictCount;

  /// Allowed sources snapshot.
  final Set<SieInputSource> allowedSources;

  /// Triggering claim (if any).
  final SieInputActivityClaim? sourceClaim;

  /// Processing ms.
  final double processingMs;

  /// Diagnostics.
  final Map<String, Object?> metadata;

  /// Whether ownership changed this snapshot.
  bool get ownershipChanged => owner != previousOwner;
}

/// Frame input for synchronous process.
final class SieArbitrationFrameInput {
  /// Creates input.
  const SieArbitrationFrameInput({
    required this.timestamp,
    required this.claims,
    required this.context,
    this.frameSequence = 0,
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Claims this frame (may be empty = re-evaluate context only).
  final List<SieInputActivityClaim> claims;

  /// Context.
  final SieArbitrationContext context;

  /// Sequence.
  final int frameSequence;
}
