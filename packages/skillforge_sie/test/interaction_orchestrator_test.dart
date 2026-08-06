import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieArbitrationSnapshot _arb({
  SieInputSource owner = SieInputSource.sie,
  bool forwards = true,
  SieRouteCapabilityKind route = SieRouteCapabilityKind.dashboard,
  int sequence = 1,
  DateTime? timestamp,
  SieOwnershipReason reason = SieOwnershipReason.acquired,
}) {
  return SieArbitrationSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    owner: owner,
    previousOwner: SieInputSource.none,
    reason: reason,
    policyId: SieArbitrationPolicyId.lastActiveWins,
    routeKind: route,
    forwardsSiePointers: forwards && owner == SieInputSource.sie,
    traditionalActive: owner.isTraditional,
  );
}

SiePointerEvent _pe({
  required SiePointerEventKind kind,
  int sequence = 1,
  double x = 10,
  double y = 20,
}) {
  return SiePointerEvent(
    timestamp: DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    pointerId: 900001,
    kind: kind,
    position: SieSpatialPoint2D(x, y),
    buttons: kind == SiePointerEventKind.down || kind == SiePointerEventKind.move
        ? SiePointerButtons.primary
        : SiePointerButtons.none,
    lifecycle: SiePointerLifecycleState.hovering,
  );
}

SieInteractionOrchestrator _orch({
  InteractionDispatchPort? dispatcher,
  SieOrchestrationContext? context,
}) {
  return SieInteractionOrchestrator(
    logger: const NopSieOrchestratorLogger(),
    dispatcher: dispatcher ?? RecordingInteractionDispatcher(),
    context: context ??
        const SieOrchestrationContext(
          lifecycle: SieAppLifecycleState.resumed,
          interactionEnabled: true,
        ),
  );
}

void main() {
  group('Orchestrator — lifecycle & gating', () {
    test('Resumed + SIE owner dispatches pointer batch in order', () async {
      final dispatcher = RecordingInteractionDispatcher();
      final orch = _orch(dispatcher: dispatcher);
      await orch.initialize(dispatcher: dispatcher);
      final events = [
        _pe(kind: SiePointerEventKind.added),
        _pe(kind: SiePointerEventKind.hover, x: 11),
        _pe(kind: SiePointerEventKind.down, x: 12),
      ];
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: events,
        ),
      );
      expect(snap.decision, SieDispatchDecision.dispatched);
      expect(snap.dispatchedEvents.map((e) => e.kind).toList(),
          events.map((e) => e.kind).toList());
      expect(snap.mode, SieOrchestrationMode.sieActive);
      await Future<void>.delayed(Duration.zero);
      expect(dispatcher.events.map((e) => e.kind).toList(),
          events.map((e) => e.kind).toList());
      await orch.dispose();
    });

    test('Paused lifecycle blocks dispatch', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setLifecycle(SieAppLifecycleState.paused);
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.down)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedLifecycle);
      expect(snap.dispatchedEvents, isEmpty);
      await orch.dispose();
    });

    test('Window blur blocks dispatch', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setFocus(const SieFocusState(windowFocused: false));
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.hover)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedFocus);
      await orch.dispose();
    });

    test('Interaction disabled blocks all', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setInteractionEnabled(false);
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.down)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedDisabled);
      expect(snap.mode, SieOrchestrationMode.disabled);
      await orch.dispose();
    });
  });

  group('Orchestrator — arbitration & features', () {
    test('Mouse owner blocks SIE pointer forward', () async {
      final dispatcher = RecordingInteractionDispatcher();
      final orch = _orch(dispatcher: dispatcher);
      await orch.initialize(dispatcher: dispatcher);
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(owner: SieInputSource.mouse, forwards: false),
          siePointerEvents: [_pe(kind: SiePointerEventKind.down)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedArbitration);
      expect(snap.mode, SieOrchestrationMode.traditionalOnly);
      expect(dispatcher.events, isEmpty);
      await orch.dispose();
    });

    test('Camera unavailable → traditionalOnly and block SIE', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setAvailability(SieInteractionAvailability.traditionalOnly);
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.hover)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedFeature);
      expect(snap.availability.sieOperational, isFalse);
      await orch.dispose();
    });

    test('Modal suspends SIE dispatch', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setModal(SieModalKind.dialog);
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.down)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedModal);
      expect(snap.mode, SieOrchestrationMode.modal);
      await orch.dispose();
    });

    test('L4 security blocks SIE at orchestrator', () async {
      final orch = _orch(
        context: const SieOrchestrationContext(
          lifecycle: SieAppLifecycleState.resumed,
          securityLevel: SieSecurityLevel.l4Irreversible,
          interactionEnabled: true,
        ),
      );
      await orch.initialize();
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.down)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.blockedRoute);
      await orch.dispose();
    });
  });

  group('Orchestrator — route, focus, a11y, recovery', () {
    test('Route change updates snapshot', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setRoute(
        routeKind: SieRouteCapabilityKind.payment,
        securityLevel: SieSecurityLevel.l3Sensitive,
      );
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(
            owner: SieInputSource.mouse,
            route: SieRouteCapabilityKind.payment,
          ),
          siePointerEvents: const [],
        ),
      );
      expect(snap.routeKind, SieRouteCapabilityKind.payment);
      expect(snap.securityLevel, SieSecurityLevel.l3Sensitive);
      expect(orch.metrics.routeTransitions, greaterThan(0));
      await orch.dispose();
    });

    test('Accessibility state is reflected in snapshot', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setAccessibility(
        const SieAccessibilityState(
          reducedMotion: true,
          largeCursor: true,
          dwellMode: true,
        ),
      );
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(owner: SieInputSource.keyboard, forwards: false),
        ),
      );
      expect(snap.accessibility.reducedMotion, isTrue);
      expect(snap.accessibility.largeCursor, isTrue);
      expect(snap.accessibility.dwellMode, isTrue);
      await orch.dispose();
    });

    test('Focus keyboard kind recorded', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setFocus(
        const SieFocusState(
          kind: SieFocusKind.keyboard,
          windowFocused: true,
          targetId: 'field',
        ),
      );
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(owner: SieInputSource.keyboard, forwards: false),
        ),
      );
      expect(snap.focus.kind, SieFocusKind.keyboard);
      expect(snap.focus.targetId, 'field');
      await orch.dispose();
    });

    test('Recovery completed increments metric', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.notifyRecoveryCompleted();
      expect(orch.metrics.recoveryCount, 1);
      await orch.dispose();
    });

    test('Background → foreground lifecycle transitions', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setLifecycle(SieAppLifecycleState.background);
      expect(orch.context.lifecycle, SieAppLifecycleState.background);
      await orch.setLifecycle(SieAppLifecycleState.foregrounding);
      await orch.setLifecycle(SieAppLifecycleState.resumed);
      expect(orch.metrics.lifecycleTransitions, greaterThanOrEqualTo(3));
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [_pe(kind: SiePointerEventKind.hover)],
        ),
      );
      expect(snap.decision, SieDispatchDecision.dispatched);
      await orch.dispose();
    });
  });

  group('Orchestrator — ordering, stream, performance', () {
    test('Deterministic identical inputs', () async {
      final a = _orch();
      final b = _orch();
      await a.initialize();
      await b.initialize();
      final input = SieOrchestrationFrameInput(
        timestamp: DateTime.utc(2026, 7, 17, 12),
        arbitration: _arb(),
        siePointerEvents: [
          _pe(kind: SiePointerEventKind.added),
          _pe(kind: SiePointerEventKind.move, x: 5),
        ],
      );
      final sa = a.process(input);
      final sb = b.process(input);
      expect(sa.decision, sb.decision);
      expect(sa.dispatchedEvents.map((e) => e.kind).toList(),
          sb.dispatchedEvents.map((e) => e.kind).toList());
      await a.dispose();
      await b.dispose();
    });

    test('Never reorders events', () async {
      final orch = _orch();
      await orch.initialize();
      final kinds = [
        SiePointerEventKind.added,
        SiePointerEventKind.hover,
        SiePointerEventKind.down,
        SiePointerEventKind.move,
        SiePointerEventKind.up,
      ];
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(),
          siePointerEvents: [
            for (var i = 0; i < kinds.length; i++)
              _pe(kind: kinds[i], sequence: i, x: i.toDouble()),
          ],
        ),
      );
      expect(snap.dispatchedEvents.map((e) => e.kind).toList(), kinds);
      await orch.dispose();
    });

    test('Stream start processes arbitration', () async {
      final orch = _orch();
      await orch.initialize();
      final arb = StreamController<SieArbitrationSnapshot>();
      final ptr = StreamController<List<SiePointerEvent>>();
      final received = <SieOrchestrationSnapshot>[];
      final sub = orch.snapshots.listen(received.add);
      await orch.start(
        arbitrationSnapshots: arb.stream,
        siePointerBatches: ptr.stream,
      );
      ptr.add([_pe(kind: SiePointerEventKind.hover)]);
      arb.add(_arb());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isNotEmpty);
      expect(received.last.decision, SieDispatchDecision.dispatched);
      await sub.cancel();
      await arb.close();
      await ptr.close();
      await orch.dispose();
    });

    test('200 frames under soft budget', () async {
      final orch = _orch();
      await orch.initialize();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        orch.process(
          SieOrchestrationFrameInput(
            timestamp: DateTime.utc(2026, 7, 17, 12)
                .add(Duration(milliseconds: i)),
            arbitration: _arb(sequence: i),
            siePointerEvents: [
              _pe(kind: SiePointerEventKind.hover, sequence: i, x: i.toDouble()),
            ],
            frameSequence: i,
          ),
        );
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
      expect(orch.metrics.averageProcessingMs, lessThan(5));
      await orch.dispose();
    });

    test('Permission loss degrades to traditionalOnly mode', () async {
      final orch = _orch();
      await orch.initialize();
      await orch.setAvailability(
        SieInteractionAvailability.full.copyWith(
          cameraPermissionGranted: false,
        ),
      );
      final snap = orch.process(
        SieOrchestrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          arbitration: _arb(owner: SieInputSource.touch, forwards: false),
        ),
      );
      expect(snap.mode, SieOrchestrationMode.traditionalOnly);
      await orch.dispose();
    });
  });
}
