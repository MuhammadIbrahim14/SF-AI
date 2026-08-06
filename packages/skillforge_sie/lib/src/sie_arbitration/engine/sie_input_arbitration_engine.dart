import 'dart:async';

import 'package:skillforge_sie/src/sie_arbitration/logging/sie_arbitration_logger.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_engine_status.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_policy.dart';
import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_snapshot.dart';
import 'package:skillforge_sie/src/sie_arbitration/ports/input_arbitration_engine_port.dart';
import 'package:skillforge_sie/src/sie_arbitration/processing/sie_arbitration_resolver.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Production Input Arbitration Engine — ownership coordination only.
final class SieInputArbitrationEngine implements InputArbitrationEnginePort {
  /// Creates the engine.
  SieInputArbitrationEngine({
    SieArbitrationPolicy policy = SieArbitrationPolicy.lastActiveWins,
    SieArbitrationContext? context,
    SieArbitrationLogger logger = const DeveloperSieArbitrationLogger(),
  })  : _logger = logger,
        _resolver = SieArbitrationResolver(policy: policy),
        _context = context ?? SieArbitrationContext.dashboard();

  final SieArbitrationLogger _logger;
  final SieArbitrationResolver _resolver;
  SieArbitrationContext _context;

  final StreamController<SieArbitrationEngineStatus> _statusController =
      StreamController<SieArbitrationEngineStatus>.broadcast();
  final StreamController<SieArbitrationSnapshot> _snapshotController =
      StreamController<SieArbitrationSnapshot>.broadcast();

  StreamSubscription<SieArbitrationFrameInput>? _sub;
  SieArbitrationEngineStatus _status = SieArbitrationEngineStatus.idle();
  SieArbitrationEngineMetrics _metrics = const SieArbitrationEngineMetrics();
  final List<double> _processingSamples = [];
  bool _disposed = false;
  int _seq = 0;

  @override
  Stream<SieArbitrationEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieArbitrationSnapshot> get snapshots => _snapshotController.stream;

  @override
  SieArbitrationEngineStatus get currentStatus => _status;

  @override
  SieArbitrationEngineMetrics get metrics => _metrics;

  @override
  SieArbitrationPolicy get policy => _resolver.policy;

  @override
  SieArbitrationContext get context => _context;

  @override
  SieInputSource get owner => _resolver.owner;

  @override
  bool get forwardsSiePointers => _resolver.owner == SieInputSource.sie;

  void _emitStatus(SieArbitrationEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({
    SieArbitrationPolicy? policy,
    SieArbitrationContext? context,
  }) async {
    _ensureNotDisposed();
    if (policy != null) {
      _resolver.setPolicy(policy);
    }
    if (context != null) {
      _context = context;
    }
    _resolver.reset();
    _metrics = const SieArbitrationEngineMetrics();
    _seq = 0;
    _logger.info('engine_initialized', {
      'policy': _resolver.policy.id.name,
      'route': _context.routeKind.name,
    });
    _emitStatus(
      SieArbitrationEngineStatus(
        health: SieArbitrationEngineHealth.healthy,
        initialized: true,
        running: false,
        owner: SieInputSource.none,
        policyId: _resolver.policy.id,
        lastEvent: 'initialized',
      ),
    );
  }

  @override
  Future<void> start(Stream<SieArbitrationFrameInput> claimFrames) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SieArbitrationEngineHealth.healthy,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = claimFrames.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('claim_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieArbitrationEngineHealth.error,
            lastError:
                SieArbitrationEngineFailure(message: e.toString(), cause: e),
            lastEvent: 'claim_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieArbitrationSnapshot process(SieArbitrationFrameInput input) {
    final sw = Stopwatch()..start();
    try {
      _context = input.context;
      final previous = _resolver.owner;
      final decision = _resolver.resolve(
        claims: input.claims,
        context: input.context,
      );
      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final snap = SieArbitrationSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        owner: decision.owner,
        previousOwner: previous,
        reason: decision.reason,
        policyId: _resolver.policy.id,
        routeKind: input.context.routeKind,
        forwardsSiePointers: decision.owner == SieInputSource.sie,
        traditionalActive: decision.owner.isTraditional,
        conflictCount: decision.conflictCount,
        allowedSources: Set.unmodifiable(input.context.allowedSources),
        sourceClaim: decision.trigger,
        processingMs: processingMs,
        metadata: {
          'paused': input.context.paused,
          'focused': input.context.windowFocused,
        },
      );

      _noteProcessed(snap);
      _logSignificant(snap);
      _maybeUpdateStatus(snap);
      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieArbitrationEngineHealth.degraded,
          lastError:
              SieArbitrationEngineFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieArbitrationSnapshot.idle(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
      );
    }
  }

  @override
  SieArbitrationSnapshot reportClaim(SieInputActivityClaim claim) {
    _seq++;
    return process(
      SieArbitrationFrameInput(
        timestamp: claim.timestamp,
        frameSequence: _seq,
        claims: [claim],
        context: _context,
      ),
    );
  }

  void _noteProcessed(SieArbitrationSnapshot snap) {
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    final avg = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    final transition = snap.ownershipChanged ? 1 : 0;
    final lost = (snap.reason == SieOwnershipReason.lostTracking ||
            snap.reason == SieOwnershipReason.deviceUnavailable ||
            snap.reason == SieOwnershipReason.focusLost ||
            snap.reason == SieOwnershipReason.paused)
        ? 1
        : 0;

    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      ownershipTransitions: _metrics.ownershipTransitions + transition,
      conflictsResolved: _metrics.conflictsResolved + snap.conflictCount,
      lostOwnershipEvents: _metrics.lostOwnershipEvents + lost,
      averageProcessingMs: avg,
      lastProcessingMs: snap.processingMs,
    );
  }

  void _logSignificant(SieArbitrationSnapshot snap) {
    if (!snap.ownershipChanged &&
        snap.reason != SieOwnershipReason.conflictResolved &&
        snap.reason != SieOwnershipReason.traditionalSupremacy) {
      return;
    }
    if (snap.owner != SieInputSource.none && snap.ownershipChanged) {
      _logger.info('owner_acquired', {
        'owner': snap.owner.name,
        'previous': snap.previousOwner.name,
        'reason': snap.reason.name,
      });
    } else if (snap.owner == SieInputSource.none &&
        snap.previousOwner != SieInputSource.none) {
      _logger.info('owner_released', {
        'previous': snap.previousOwner.name,
        'reason': snap.reason.name,
      });
    }
    if (snap.conflictCount > 0 ||
        snap.reason == SieOwnershipReason.traditionalSupremacy) {
      _logger.info('ownership_conflict', {
        'owner': snap.owner.name,
        'reason': snap.reason.name,
        'conflicts': snap.conflictCount,
      });
    }
    if (snap.reason == SieOwnershipReason.lostTracking) {
      _logger.info('lost_tracking_ownership_release');
    }
  }

  void _maybeUpdateStatus(SieArbitrationSnapshot snap) {
    if (snap.owner != _status.owner ||
        snap.policyId != _status.policyId) {
      _emitStatus(
        _status.copyWith(
          owner: snap.owner,
          policyId: snap.policyId,
          health: SieArbitrationEngineHealth.healthy,
          lastEvent: 'ownership_state',
        ),
      );
    }
  }

  @override
  Future<void> setPolicy(SieArbitrationPolicy policy) async {
    _ensureNotDisposed();
    _resolver.setPolicy(policy);
    _logger.info('policy_change', {'policy': policy.id.name});
    _emitStatus(
      _status.copyWith(
        policyId: policy.id,
        lastEvent: 'policy_changed',
        clearError: true,
      ),
    );
    // Re-evaluate with empty claims.
    process(
      SieArbitrationFrameInput(
        timestamp: DateTime.now().toUtc(),
        frameSequence: ++_seq,
        claims: const [],
        context: _context,
      ),
    );
  }

  @override
  Future<void> updateContext(SieArbitrationContext context) async {
    _ensureNotDisposed();
    final prevRoute = _context.routeKind;
    _context = context;
    if (prevRoute != context.routeKind) {
      _logger.info('policy_change', {
        'route': context.routeKind.name,
      });
    }
    process(
      SieArbitrationFrameInput(
        timestamp: DateTime.now().toUtc(),
        frameSequence: ++_seq,
        claims: const [],
        context: context,
      ),
    );
  }

  @override
  Future<SieArbitrationSnapshot> releaseOwnership({
    SieOwnershipReason reason = SieOwnershipReason.released,
  }) async {
    _ensureNotDisposed();
    final current = _resolver.owner;
    if (current == SieInputSource.none) {
      return SieArbitrationSnapshot(
        timestamp: DateTime.now().toUtc(),
        frameSequence: ++_seq,
        owner: SieInputSource.none,
        previousOwner: SieInputSource.none,
        reason: SieOwnershipReason.none,
        policyId: _resolver.policy.id,
        routeKind: _context.routeKind,
        forwardsSiePointers: false,
        traditionalActive: false,
        allowedSources: Set.unmodifiable(_context.allowedSources),
      );
    }
    return process(
      SieArbitrationFrameInput(
        timestamp: DateTime.now().toUtc(),
        frameSequence: ++_seq,
        claims: [
          SieInputActivityClaim(
            timestamp: DateTime.now().toUtc(),
            source: current,
            kind: SieInputActivityKind.releaseOwnership,
          ),
        ],
        context: _context,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _sub?.cancel();
    _sub = null;
    _logger.info('engine_stopped');
    _emitStatus(
      _status.copyWith(
        running: false,
        health: SieArbitrationEngineHealth.healthy,
        lastEvent: 'stopped',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    _resolver.reset();
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieArbitrationEngineHealth.disposed,
        running: false,
        initialized: false,
        owner: SieInputSource.none,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieArbitrationEngineFailure(
        message: 'Arbitration engine is disposed.',
      );
    }
  }
}
