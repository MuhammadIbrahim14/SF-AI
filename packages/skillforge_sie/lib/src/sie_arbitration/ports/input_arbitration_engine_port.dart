import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_engine_status.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_policy.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_snapshot.dart';

/// Input Arbitration Engine port — sole authority for input ownership.
///
/// Coordinates modalities only. Does not recognize gestures or emit PointerEvents.
abstract interface class InputArbitrationEnginePort {
  /// Low-frequency status.
  Stream<SieArbitrationEngineStatus> get status;

  /// High-frequency arbitration snapshots — **not** Riverpod.
  Stream<SieArbitrationSnapshot> get snapshots;

  /// Latest status.
  SieArbitrationEngineStatus get currentStatus;

  /// Latest metrics.
  SieArbitrationEngineMetrics get metrics;

  /// Active policy.
  SieArbitrationPolicy get policy;

  /// Active context.
  SieArbitrationContext get context;

  /// Current owner.
  SieInputSource get owner;

  /// Whether SIE pointer bridge output should be forwarded.
  bool get forwardsSiePointers;

  /// Prepare.
  Future<void> initialize({
    SieArbitrationPolicy? policy,
    SieArbitrationContext? context,
  });

  /// Attach to claim stream (host multiplexes mouse/touch/keyboard/SIE probes).
  Future<void> start(Stream<SieArbitrationFrameInput> claimFrames);

  /// Detach.
  Future<void> stop();

  /// Release.
  Future<void> dispose();

  /// Synchronous evaluate.
  SieArbitrationSnapshot process(SieArbitrationFrameInput input);

  /// Report a single claim (convenience; wraps process).
  SieArbitrationSnapshot reportClaim(SieInputActivityClaim claim);

  /// Update policy.
  Future<void> setPolicy(SieArbitrationPolicy policy);

  /// Update context (route / locks / manual).
  Future<void> updateContext(SieArbitrationContext context);

  /// Explicitly release current owner.
  Future<SieArbitrationSnapshot> releaseOwnership({
    SieOwnershipReason reason = SieOwnershipReason.released,
  });
}
