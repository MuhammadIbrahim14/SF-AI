import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieGestureEvent _ge({
  required SieGestureKind kind,
  SieGesturePhase phase = SieGesturePhase.recognized,
  double confidence = 0.95,
  SieTrackingReliabilityState tracking = SieTrackingReliabilityState.stable,
  int sequence = 1,
  double progress = 0,
  double axisDelta = 0,
  SieSpatialPoint2D? position,
  DateTime? timestamp,
}) {
  return SieGestureEvent(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    kind: kind,
    phase: phase,
    confidence: confidence,
    trackingState: tracking,
    handId: 0,
    durationMs: 100,
    policyId: SieGesturePolicyId.standard,
    progress: progress,
    axisDelta: axisDelta,
    position: position ?? const SieSpatialPoint2D(0.5, 0.4),
  );
}

SieGestureFrameSnapshot _gf({
  List<SieGestureEvent> events = const [],
  SieGestureActivity activity = SieGestureActivity.none,
  SieTrackingReliabilityState tracking = SieTrackingReliabilityState.stable,
  int sequence = 1,
  SieGestureKind? primaryKind,
  SieGesturePhase primaryPhase = SieGesturePhase.idle,
  DateTime? timestamp,
}) {
  return SieGestureFrameSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    trackingState: tracking,
    activity: activity,
    primaryKind: primaryKind,
    primaryPhase: primaryPhase,
    events: events,
    processingMs: 0.2,
    policyId: SieGesturePolicyId.standard,
  );
}

SieIntentEngine _engine({
  SieIntentContext? context,
  SieIntentPolicy policy = SieIntentPolicy.standard,
}) {
  return SieIntentEngine(
    context: context,
    policy: policy,
    logger: const NopSieIntentLogger(),
    emitSuppressionDiagnostics: true,
  );
}

void main() {
  group('Intent Engine — official intents', () {
    test('MoveCursor from pointing activity', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _gf(
          activity: SieGestureActivity.pointing,
          events: [
            _ge(kind: SieGestureKind.openHandPoint),
          ],
          primaryKind: SieGestureKind.openHandPoint,
        ),
      );
      expect(
        snap.actionable.any((e) => e.kind == SieIntentKind.moveCursor),
        isTrue,
      );
      await engine.dispose();
    });

    test('Select from pinchCommit', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          hoveredTargetId: 'btn',
        ),
      );
      await engine.initialize();
      final snap = engine.process(
        _gf(
          activity: SieGestureActivity.pressed,
          events: [_ge(kind: SieGestureKind.pinchCommit)],
          primaryKind: SieGestureKind.pinchCommit,
        ),
      );
      final select = snap.actionable
          .where((e) => e.kind == SieIntentKind.select)
          .toList();
      expect(select, isNotEmpty);
      expect(select.first.phase, SieIntentPhase.active);
      expect(select.first.sourceGesture, SieGestureKind.pinchCommit);
      await engine.dispose();
    });

    test('SelectHold then SelectRelease', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          hoveredTargetId: 'btn',
        ),
      );
      await engine.initialize();
      engine.process(
        _gf(
          events: [_ge(kind: SieGestureKind.pinchCommit)],
          activity: SieGestureActivity.pressed,
        ),
      );
      final hold = engine.process(
        _gf(
          sequence: 2,
          events: [
            _ge(
              kind: SieGestureKind.pinchHold,
              phase: SieGesturePhase.maintained,
              position: const SieSpatialPoint2D(0.5, 0.4),
            ),
          ],
          activity: SieGestureActivity.pressed,
        ),
      );
      expect(
        hold.actionable.any((e) => e.kind == SieIntentKind.selectHold),
        isTrue,
      );
      final release = engine.process(
        _gf(
          sequence: 3,
          events: [
            _ge(
              kind: SieGestureKind.pinchRelease,
              phase: SieGesturePhase.completed,
            ),
          ],
        ),
      );
      expect(
        release.actionable.any((e) => e.kind == SieIntentKind.selectRelease),
        isTrue,
      );
      await engine.dispose();
    });

    test('BeginDrag / UpdateDrag / EndDrag after threshold', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          hoveredTargetId: 'card',
          dragThreshold: 0.04,
        ),
      );
      await engine.initialize();
      engine.process(
        _gf(
          events: [
            _ge(
              kind: SieGestureKind.pinchCommit,
              position: const SieSpatialPoint2D(0.5, 0.4),
            ),
          ],
        ),
      );
      final begin = engine.process(
        _gf(
          sequence: 2,
          events: [
            _ge(
              kind: SieGestureKind.pinchHold,
              phase: SieGesturePhase.maintained,
              position: const SieSpatialPoint2D(0.56, 0.4),
            ),
          ],
        ),
      );
      expect(
        begin.actionable.any((e) => e.kind == SieIntentKind.beginDrag),
        isTrue,
      );
      final update = engine.process(
        _gf(
          sequence: 3,
          events: [
            _ge(
              kind: SieGestureKind.pinchHold,
              phase: SieGesturePhase.maintained,
              position: const SieSpatialPoint2D(0.60, 0.42),
            ),
          ],
        ),
      );
      expect(
        update.actionable.any((e) => e.kind == SieIntentKind.updateDrag),
        isTrue,
      );
      final end = engine.process(
        _gf(
          sequence: 4,
          events: [
            _ge(
              kind: SieGestureKind.pinchRelease,
              phase: SieGesturePhase.completed,
              position: const SieSpatialPoint2D(0.62, 0.42),
            ),
          ],
        ),
      );
      expect(
        end.actionable.any((e) => e.kind == SieIntentKind.endDrag),
        isTrue,
      );
      await engine.dispose();
    });

    test('Cancel from fistCancel', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.fistCancel)]),
      );
      expect(
        snap.actionable.any((e) => e.kind == SieIntentKind.cancel),
        isTrue,
      );
      await engine.dispose();
    });

    test('ScrollDelta from scrollIntent', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _gf(
          activity: SieGestureActivity.scrolling,
          events: [
            _ge(
              kind: SieGestureKind.scrollIntent,
              phase: SieGesturePhase.maintained,
              axisDelta: -0.12,
            ),
          ],
        ),
      );
      final scroll = snap.actionable
          .where((e) => e.kind == SieIntentKind.scrollDelta)
          .single;
      expect(scroll.axisDelta, -0.12);
      await engine.dispose();
    });

    test('HoverEnter / HoverExit from context target changes', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard(),
      );
      await engine.initialize();
      await engine.updateContext(
        engine.context.copyWith(hoveredTargetId: 'a'),
      );
      final enter = engine.process(_gf(sequence: 1));
      expect(
        enter.actionable.any((e) => e.kind == SieIntentKind.hoverEnter),
        isTrue,
      );
      await engine.updateContext(
        engine.context.copyWith(hoveredTargetId: 'b'),
      );
      final swap = engine.process(_gf(sequence: 2));
      expect(
        swap.actionable.any((e) => e.kind == SieIntentKind.hoverExit),
        isTrue,
      );
      expect(
        swap.actionable.any((e) => e.kind == SieIntentKind.hoverEnter),
        isTrue,
      );
      await engine.dispose();
    });

    test('DwellSelect under accessibility policy', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          policy: SieIntentPolicy.accessibility,
          hoveredTargetId: 'link',
        ),
        policy: SieIntentPolicy.accessibility,
      );
      await engine.initialize();
      final snap = engine.process(
        _gf(
          events: [
            _ge(
              kind: SieGestureKind.dwellSelect,
              phase: SieGesturePhase.committed,
              progress: 1,
            ),
          ],
        ),
      );
      expect(
        snap.actionable.any((e) => e.kind == SieIntentKind.dwellSelect),
        isTrue,
      );
      await engine.dispose();
    });

    test('PauseSIE / ResumeSIE via session API', () async {
      final engine = _engine();
      await engine.initialize();
      final events = <SieIntentEvent>[];
      final sub = engine.events.listen(events.add);
      await engine.pauseSession();
      await engine.resumeSession();
      await Future<void>.delayed(Duration.zero);
      expect(events.any((e) => e.kind == SieIntentKind.pauseSie), isTrue);
      expect(events.any((e) => e.kind == SieIntentKind.resumeSie), isTrue);
      await sub.cancel();
      await engine.dispose();
    });
  });

  group('Intent Engine — security L0–L4', () {
    test('L3 suppresses Select from PinchCommit (payment)', () async {
      final engine = _engine(
        context: const SieIntentContext(
          route: SieRouteCapability.payment,
          securityLevel: SieSecurityLevel.l3Sensitive,
          policy: SieIntentPolicy.standard,
          hoveredTargetId: 'pay',
        ),
      );
      await engine.initialize();
      final snap = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
      );
      expect(
        snap.actionable.any((e) => e.kind == SieIntentKind.select),
        isFalse,
      );
      expect(
        snap.events.any(
          (e) =>
              e.kind == SieIntentKind.select &&
              e.suppressed &&
              (e.suppressionReason ==
                      SieIntentSuppressionReason.securityPolicy ||
                  e.suppressionReason ==
                      SieIntentSuppressionReason.routePolicy),
        ),
        isTrue,
      );
      expect(engine.metrics.securityBlocks + engine.metrics.routeBlocks, greaterThan(0));
      await engine.dispose();
    });

    test('L4 suppresses Select and Scroll', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          securityLevel: SieSecurityLevel.l4Irreversible,
          hoveredTargetId: 'x',
        ),
      );
      await engine.initialize();
      final selectSnap = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
      );
      expect(
        selectSnap.actionable.any((e) => e.kind == SieIntentKind.select),
        isFalse,
      );
      final scrollSnap = engine.process(
        _gf(
          sequence: 2,
          events: [
            _ge(kind: SieGestureKind.scrollIntent, axisDelta: 0.1),
          ],
        ),
      );
      expect(
        scrollSnap.actionable.any((e) => e.kind == SieIntentKind.scrollDelta),
        isFalse,
      );
      await engine.dispose();
    });

    test('L0/L1/L2 allow Select', () async {
      for (final level in [
        SieSecurityLevel.l0Public,
        SieSecurityLevel.l1Standard,
        SieSecurityLevel.l2Elevated,
      ]) {
        final engine = _engine(
          context: SieIntentContext(
            route: SieRouteCapability.dashboard,
            securityLevel: level,
            policy: SieIntentPolicy.standard,
            hoveredTargetId: 't',
          ),
        );
        await engine.initialize();
        final snap = engine.process(
          _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
        );
        expect(
          snap.actionable.any((e) => e.kind == SieIntentKind.select),
          isTrue,
          reason: '$level should allow Select',
        );
        await engine.dispose();
      }
    });
  });

  group('Intent Engine — route & policy', () {
    test('Authentication route blocks Select', () async {
      final engine = _engine(
        context: const SieIntentContext(
          route: SieRouteCapability.authentication,
          securityLevel: SieSecurityLevel.l3Sensitive,
          policy: SieIntentPolicy.standard,
        ),
      );
      await engine.initialize();
      final snap = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
      );
      expect(snap.actionable.any((e) => e.kind == SieIntentKind.select), isFalse);
      await engine.dispose();
    });

    test('Marketing allows Select but not Scroll', () async {
      final engine = _engine(
        context: const SieIntentContext(
          route: SieRouteCapability.marketing,
          securityLevel: SieSecurityLevel.l0Public,
          policy: SieIntentPolicy.standard,
          hoveredTargetId: 'cta',
        ),
      );
      await engine.initialize();
      final select = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
      );
      expect(select.actionable.any((e) => e.kind == SieIntentKind.select), isTrue);
      final scroll = engine.process(
        _gf(
          sequence: 2,
          events: [_ge(kind: SieGestureKind.scrollIntent, axisDelta: 0.2)],
        ),
      );
      expect(
        scroll.actionable.any((e) => e.kind == SieIntentKind.scrollDelta),
        isFalse,
      );
      await engine.dispose();
    });

    test('Restricted policy blocks drag', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          policy: SieIntentPolicy.restricted,
          hoveredTargetId: 'item',
          dragThreshold: 0.04,
        ),
        policy: SieIntentPolicy.restricted,
      );
      await engine.initialize();
      engine.process(
        _gf(
          events: [
            _ge(
              kind: SieGestureKind.pinchCommit,
              position: const SieSpatialPoint2D(0.5, 0.4),
            ),
          ],
        ),
      );
      final drag = engine.process(
        _gf(
          sequence: 2,
          events: [
            _ge(
              kind: SieGestureKind.pinchHold,
              phase: SieGesturePhase.maintained,
              position: const SieSpatialPoint2D(0.58, 0.4),
            ),
          ],
        ),
      );
      expect(
        drag.actionable.any((e) => e.kind == SieIntentKind.beginDrag),
        isFalse,
      );
      await engine.dispose();
    });

    test('Standard policy suppresses DwellSelect', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.dwellSelect)]),
      );
      expect(
        snap.actionable.any((e) => e.kind == SieIntentKind.dwellSelect),
        isFalse,
      );
      await engine.dispose();
    });

    test('Admin requires hover for Select', () async {
      final engine = _engine(
        context: const SieIntentContext(
          route: SieRouteCapability.admin,
          securityLevel: SieSecurityLevel.l2Elevated,
          policy: SieIntentPolicy.standard,
        ),
      );
      await engine.initialize();
      final blocked = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
      );
      expect(blocked.actionable.any((e) => e.kind == SieIntentKind.select), isFalse);
      await engine.updateContext(
        engine.context.copyWith(hoveredTargetId: 'admin-btn'),
      );
      final ok = engine.process(
        _gf(
          sequence: 2,
          events: [_ge(kind: SieGestureKind.pinchCommit)],
        ),
      );
      expect(ok.actionable.any((e) => e.kind == SieIntentKind.select), isTrue);
      await engine.dispose();
    });
  });

  group('Intent Engine — tracking & future', () {
    test('Recovering suppresses Select', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          hoveredTargetId: 't',
        ),
      );
      await engine.initialize();
      final snap = engine.process(
        _gf(
          tracking: SieTrackingReliabilityState.recovering,
          events: [
            _ge(
              kind: SieGestureKind.pinchCommit,
              tracking: SieTrackingReliabilityState.recovering,
            ),
          ],
        ),
      );
      expect(snap.actionable.any((e) => e.kind == SieIntentKind.select), isFalse);
      await engine.dispose();
    });

    test('LostTracking allows Cancel only among interaction intents', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _gf(
          tracking: SieTrackingReliabilityState.lostTracking,
          events: [
            _ge(
              kind: SieGestureKind.fistCancel,
              tracking: SieTrackingReliabilityState.lostTracking,
            ),
            _ge(
              kind: SieGestureKind.pinchCommit,
              tracking: SieTrackingReliabilityState.lostTracking,
            ),
          ],
        ),
      );
      expect(snap.actionable.any((e) => e.kind == SieIntentKind.cancel), isTrue);
      expect(snap.actionable.any((e) => e.kind == SieIntentKind.select), isFalse);
      await engine.dispose();
    });

    test('NavigateRelative from swipe is not activated', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _gf(
          events: [
            _ge(
              kind: SieGestureKind.swipeNavigation,
              axisDelta: 1,
            ),
          ],
        ),
      );
      expect(
        snap.actionable.any((e) => e.kind == SieIntentKind.navigateRelative),
        isFalse,
      );
      expect(
        snap.events.any(
          (e) =>
              e.kind == SieIntentKind.navigateRelative &&
              e.suppressed &&
              e.suppressionReason ==
                  SieIntentSuppressionReason.futureNotActivated,
        ),
        isTrue,
      );
      await engine.dispose();
    });

    test('Paused session suppresses Select', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(
          paused: true,
          hoveredTargetId: 't',
        ),
      );
      await engine.initialize();
      final snap = engine.process(
        _gf(events: [_ge(kind: SieGestureKind.pinchCommit)]),
      );
      expect(snap.actionable.any((e) => e.kind == SieIntentKind.select), isFalse);
      await engine.dispose();
    });
  });

  group('Intent Engine — determinism & plumbing', () {
    test('Deterministic identical inputs', () async {
      final a = _engine(
        context: SieIntentContext.dashboard().copyWith(hoveredTargetId: 't'),
      );
      final b = _engine(
        context: SieIntentContext.dashboard().copyWith(hoveredTargetId: 't'),
      );
      await a.initialize();
      await b.initialize();
      final frame = _gf(
        events: [_ge(kind: SieGestureKind.pinchCommit)],
        activity: SieGestureActivity.pressed,
      );
      final sa = a.process(frame);
      final sb = b.process(frame);
      expect(sa.actionable.map((e) => e.kind).toList(),
          sb.actionable.map((e) => e.kind).toList());
      expect(sa.primaryKind, sb.primaryKind);
      await a.dispose();
      await b.dispose();
    });

    test('Performance under budget for 200 frames', () async {
      final engine = _engine(
        context: SieIntentContext.dashboard().copyWith(hoveredTargetId: 't'),
      );
      await engine.initialize();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        engine.process(
          _gf(
            sequence: i,
            activity: SieGestureActivity.pointing,
            events: [
              _ge(
                kind: SieGestureKind.openHandPoint,
                phase: SieGesturePhase.maintained,
                sequence: i,
              ),
            ],
          ),
        );
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
      expect(engine.metrics.averageProcessingMs, lessThan(5));
      await engine.dispose();
    });

    test('Stream start delivers snapshots', () async {
      final engine = _engine();
      await engine.initialize();
      final controller = StreamController<SieGestureFrameSnapshot>();
      final received = <SieIntentFrameSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      await engine.start(controller.stream);
      controller.add(
        _gf(
          activity: SieGestureActivity.pointing,
          events: [_ge(kind: SieGestureKind.openHandPoint)],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isNotEmpty);
      await sub.cancel();
      await controller.close();
      await engine.dispose();
    });

    test('Policy gate unit — future intents denied', () {
      const gate = SieIntentPolicyGate();
      final result = gate.evaluate(
        candidate: const SieIntentCandidate(
          kind: SieIntentKind.zoomDelta,
          phase: SieIntentPhase.active,
          confidence: 1,
          sourceGesture: 'zoom',
        ),
        context: SieIntentContext.dashboard(),
      );
      expect(result.allowed, isFalse);
      expect(result.reason, SieIntentSuppressionReason.futureNotActivated);
    });

    test('Conflict resolver prefers Cancel over Select', () {
      const resolver = SieIntentConflictResolver();
      final result = resolver.resolve([
        const SieIntentCandidate(
          kind: SieIntentKind.select,
          phase: SieIntentPhase.active,
          confidence: 1,
          sourceGesture: 'pinchCommit',
          priority: 6,
        ),
        const SieIntentCandidate(
          kind: SieIntentKind.cancel,
          phase: SieIntentPhase.completed,
          confidence: 1,
          sourceGesture: 'fistCancel',
          priority: 5,
        ),
      ]);
      expect(result.primaryKind, SieIntentKind.cancel);
      expect(
        result.accepted.any((c) => c.kind == SieIntentKind.select),
        isFalse,
      );
    });
  });
}
