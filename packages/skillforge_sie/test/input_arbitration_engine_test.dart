import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieInputArbitrationEngine _engine({
  SieArbitrationPolicy policy = SieArbitrationPolicy.lastActiveWins,
  SieArbitrationContext? context,
}) {
  return SieInputArbitrationEngine(
    policy: policy,
    context: context,
    logger: const NopSieArbitrationLogger(),
  );
}

SieInputActivityClaim _claim({
  required SieInputSource source,
  SieInputActivityKind kind = SieInputActivityKind.move,
  DateTime? timestamp,
  bool available = true,
}) {
  return SieInputActivityClaim(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    source: source,
    kind: kind,
    available: available,
  );
}

void main() {
  group('IAE — ownership', () {
    test('Mouse claim acquires ownership', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.reportClaim(_claim(source: SieInputSource.mouse));
      expect(snap.owner, SieInputSource.mouse);
      expect(snap.traditionalActive, isTrue);
      expect(snap.forwardsSiePointers, isFalse);
      await engine.dispose();
    });

    test('Touch, Keyboard, SIE each acquire when alone', () async {
      for (final source in [
        SieInputSource.touch,
        SieInputSource.keyboard,
        SieInputSource.sie,
      ]) {
        final engine = _engine();
        await engine.initialize();
        final snap = engine.reportClaim(_claim(source: source));
        expect(snap.owner, source, reason: '$source');
        expect(snap.forwardsSiePointers, source == SieInputSource.sie);
        await engine.dispose();
      }
    });

    test('Last active wins between sequential claims', () async {
      final engine = _engine();
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      engine.reportClaim(
        _claim(source: SieInputSource.sie, timestamp: t0),
      );
      final snap = engine.reportClaim(
        _claim(
          source: SieInputSource.mouse,
          timestamp: t0.add(const Duration(milliseconds: 100)),
        ),
      );
      expect(snap.owner, SieInputSource.mouse);
      expect(snap.previousOwner, SieInputSource.sie);
      await engine.dispose();
    });
  });

  group('IAE — conflicts & ADR-019', () {
    test('Simultaneous mouse + SIE → traditional wins', () async {
      final engine = _engine();
      await engine.initialize();
      final t = DateTime.utc(2026, 7, 17, 12, 0, 0, 10);
      final snap = engine.process(
        SieArbitrationFrameInput(
          timestamp: t,
          frameSequence: 1,
          context: SieArbitrationContext.dashboard(),
          claims: [
            _claim(source: SieInputSource.sie, timestamp: t),
            _claim(
              source: SieInputSource.mouse,
              timestamp: t.add(const Duration(milliseconds: 5)),
            ),
          ],
        ),
      );
      expect(snap.owner, SieInputSource.mouse);
      expect(snap.reason, SieOwnershipReason.traditionalSupremacy);
      expect(snap.forwardsSiePointers, isFalse);
      await engine.dispose();
    });

    test('Touch during SIE ownership takes over', () async {
      final engine = _engine();
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      engine.reportClaim(_claim(source: SieInputSource.sie, timestamp: t0));
      final snap = engine.reportClaim(
        _claim(
          source: SieInputSource.touch,
          kind: SieInputActivityKind.press,
          timestamp: t0.add(const Duration(milliseconds: 50)),
        ),
      );
      expect(snap.owner, SieInputSource.touch);
      expect(
        snap.reason == SieOwnershipReason.traditionalSupremacy ||
            snap.reason == SieOwnershipReason.conflictResolved ||
            snap.reason == SieOwnershipReason.acquired,
        isTrue,
      );
      await engine.dispose();
    });
  });

  group('IAE — route & policies', () {
    test('Payment route rejects SIE ownership', () async {
      final engine = _engine(context: SieArbitrationContext.payment());
      await engine.initialize(context: SieArbitrationContext.payment());
      final snap = engine.reportClaim(_claim(source: SieInputSource.sie));
      expect(snap.owner, isNot(SieInputSource.sie));
      expect(snap.forwardsSiePointers, isFalse);
      final mouse = engine.reportClaim(_claim(source: SieInputSource.mouse));
      expect(mouse.owner, SieInputSource.mouse);
      await engine.dispose();
    });

    test('Authentication route forbids SIE', () async {
      final engine = _engine(context: SieArbitrationContext.authentication());
      await engine.initialize(
        context: SieArbitrationContext.authentication(),
      );
      engine.reportClaim(_claim(source: SieInputSource.keyboard));
      final sie = engine.reportClaim(_claim(source: SieInputSource.sie));
      expect(sie.owner, isNot(SieInputSource.sie));
      await engine.dispose();
    });

    test('Route change strips disallowed owner', () async {
      final engine = _engine();
      await engine.initialize();
      engine.reportClaim(_claim(source: SieInputSource.sie));
      expect(engine.owner, SieInputSource.sie);
      await engine.updateContext(SieArbitrationContext.payment());
      expect(engine.owner, isNot(SieInputSource.sie));
      await engine.dispose();
    });

    test('Locked ownership ignores newer claims', () async {
      final engine = _engine(
        policy: SieArbitrationPolicy.lockedOwnership,
        context: SieArbitrationContext.dashboard().copyWith(
          lockedSource: SieInputSource.keyboard,
        ),
      );
      await engine.initialize(
        policy: SieArbitrationPolicy.lockedOwnership,
        context: SieArbitrationContext.dashboard().copyWith(
          lockedSource: SieInputSource.keyboard,
        ),
      );
      // Seed keyboard activity so lock can engage
      engine.reportClaim(_claim(source: SieInputSource.keyboard));
      final snap = engine.reportClaim(_claim(source: SieInputSource.mouse));
      expect(snap.owner, SieInputSource.keyboard);
      expect(snap.reason, SieOwnershipReason.locked);
      await engine.dispose();
    });

    test('Manual override selects source', () async {
      final engine = _engine(
        policy: SieArbitrationPolicy.manualOverride,
        context: SieArbitrationContext.dashboard().copyWith(
          manualSource: SieInputSource.touch,
        ),
      );
      await engine.initialize(
        policy: SieArbitrationPolicy.manualOverride,
        context: SieArbitrationContext.dashboard().copyWith(
          manualSource: SieInputSource.touch,
        ),
      );
      final snap = engine.reportClaim(_claim(source: SieInputSource.mouse));
      expect(snap.owner, SieInputSource.touch);
      expect(snap.reason, SieOwnershipReason.manual);
      await engine.dispose();
    });

    test('Accessibility priority prefers traditional when a11y mode', () async {
      final engine = _engine(
        policy: SieArbitrationPolicy.accessibilityPriority,
        context: SieArbitrationContext.dashboard().copyWith(
          accessibilityMode: true,
        ),
      );
      await engine.initialize(
        policy: SieArbitrationPolicy.accessibilityPriority,
        context: SieArbitrationContext.dashboard().copyWith(
          accessibilityMode: true,
        ),
      );
      final t0 = DateTime.utc(2026, 7, 17, 12);
      engine.reportClaim(
        _claim(source: SieInputSource.sie, timestamp: t0),
      );
      engine.reportClaim(
        _claim(
          source: SieInputSource.mouse,
          timestamp: t0.add(const Duration(milliseconds: 10)),
        ),
      );
      // Re-evaluate under a11y policy with empty claims uses last activity
      final snap = engine.process(
        SieArbitrationFrameInput(
          timestamp: t0.add(const Duration(milliseconds: 20)),
          frameSequence: 3,
          context: SieArbitrationContext.dashboard().copyWith(
            accessibilityMode: true,
          ),
          claims: const [],
        ),
      );
      expect(snap.owner, SieInputSource.mouse);
      await engine.dispose();
    });

    test('Future voice claim is ignored in v1', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.reportClaim(
        _claim(source: SieInputSource.voice, kind: SieInputActivityKind.press),
      );
      expect(snap.owner, isNot(SieInputSource.voice));
      await engine.dispose();
    });
  });

  group('IAE — LostTracking & disconnect', () {
    test('SIE LostTracking releases SIE ownership', () async {
      final engine = _engine();
      await engine.initialize();
      engine.reportClaim(_claim(source: SieInputSource.sie));
      expect(engine.owner, SieInputSource.sie);
      final snap = engine.reportClaim(
        _claim(
          source: SieInputSource.sie,
          kind: SieInputActivityKind.lostTracking,
        ),
      );
      expect(snap.owner, SieInputSource.none);
      expect(snap.reason, SieOwnershipReason.lostTracking);
      expect(snap.forwardsSiePointers, isFalse);
      expect(engine.metrics.lostOwnershipEvents, greaterThan(0));
      await engine.dispose();
    });

    test('Device disconnect releases owner', () async {
      final engine = _engine();
      await engine.initialize();
      engine.reportClaim(_claim(source: SieInputSource.mouse));
      final snap = engine.reportClaim(
        _claim(
          source: SieInputSource.mouse,
          kind: SieInputActivityKind.disconnect,
          available: false,
        ),
      );
      expect(snap.owner, SieInputSource.none);
      expect(snap.reason, SieOwnershipReason.deviceUnavailable);
      await engine.dispose();
    });

    test('Focus loss releases ownership', () async {
      final engine = _engine();
      await engine.initialize();
      engine.reportClaim(_claim(source: SieInputSource.touch));
      final snap = engine.process(
        SieArbitrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          frameSequence: 2,
          context: SieArbitrationContext.dashboard().copyWith(
            windowFocused: false,
          ),
          claims: const [],
        ),
      );
      expect(snap.owner, SieInputSource.none);
      expect(snap.reason, SieOwnershipReason.focusLost);
      await engine.dispose();
    });

    test('Paused releases ownership', () async {
      final engine = _engine();
      await engine.initialize();
      engine.reportClaim(_claim(source: SieInputSource.sie));
      final snap = engine.process(
        SieArbitrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          frameSequence: 2,
          context: SieArbitrationContext.dashboard().copyWith(paused: true),
          claims: const [],
        ),
      );
      expect(snap.owner, SieInputSource.none);
      expect(snap.reason, SieOwnershipReason.paused);
      await engine.dispose();
    });
  });

  group('IAE — determinism & performance', () {
    test('Identical claim frames yield identical owners', () async {
      final a = _engine();
      final b = _engine();
      await a.initialize();
      await b.initialize();
      final t = DateTime.utc(2026, 7, 17, 12);
      final input = SieArbitrationFrameInput(
        timestamp: t,
        frameSequence: 1,
        context: SieArbitrationContext.dashboard(),
        claims: [
          _claim(source: SieInputSource.keyboard, timestamp: t),
          _claim(
            source: SieInputSource.sie,
            timestamp: t.add(const Duration(milliseconds: 2)),
          ),
        ],
      );
      expect(a.process(input).owner, b.process(input).owner);
      await a.dispose();
      await b.dispose();
    });

    test('500 decisions under soft budget', () async {
      final engine = _engine();
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        engine.process(
          SieArbitrationFrameInput(
            timestamp: t0.add(Duration(milliseconds: i)),
            frameSequence: i,
            context: SieArbitrationContext.dashboard(),
            claims: [
              _claim(
                source: i.isEven ? SieInputSource.mouse : SieInputSource.sie,
                timestamp: t0.add(Duration(milliseconds: i)),
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
      final controller = StreamController<SieArbitrationFrameInput>();
      final received = <SieArbitrationSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      await engine.start(controller.stream);
      controller.add(
        SieArbitrationFrameInput(
          timestamp: DateTime.utc(2026, 7, 17, 12),
          frameSequence: 1,
          context: SieArbitrationContext.dashboard(),
          claims: [_claim(source: SieInputSource.mouse)],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isNotEmpty);
      expect(received.first.owner, SieInputSource.mouse);
      await sub.cancel();
      await controller.close();
      await engine.dispose();
    });

    test('releaseOwnership clears owner', () async {
      final engine = _engine();
      await engine.initialize();
      engine.reportClaim(_claim(source: SieInputSource.mouse));
      final snap = await engine.releaseOwnership();
      expect(snap.owner, SieInputSource.none);
      await engine.dispose();
    });
  });
}
