import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieCalibratedLandmark _clm({
  int index = 8,
  double nx = 0.5,
  double ny = 0.5,
  double viewW = 800,
  double viewH = 600,
}) {
  final flutter = SieSpatialPoint2D(nx * viewW, ny * viewH);
  return SieCalibratedLandmark(
    index: index,
    originalFlutter: flutter,
    calibrated: flutter,
    normalizedCalibrated: SieSpatialPoint2D(nx, ny),
    inDeadZone: false,
    inRestZone: false,
    clamped: false,
    z: 0.01 * index,
    visibility: 0.95,
    presence: 0.95,
  );
}

SieCalibratedHandSnapshot _hand({
  double nx = 0.5,
  double ny = 0.5,
  double confidence = 0.92,
  SieHandedness handedness = SieHandedness.right,
}) {
  return SieCalibratedHandSnapshot(
    handId: 0,
    handedness: handedness,
    handednessScore: confidence,
    handConfidence: confidence,
    landmarks: [
      for (var i = 0; i < 21; i++)
        _clm(
          index: i,
          nx: i == 8 ? nx : nx + i * 0.001,
          ny: i == 8 ? ny : ny,
        ),
    ],
    resolvedHandedness: SieCalibratedHandedness.right,
    mirrored: false,
  );
}

SieCalibratedFrameSnapshot _frame({
  List<SieCalibratedHandSnapshot>? hands,
  DateTime? timestamp,
  int sequence = 1,
  SieCalibrationProfile? profile,
}) {
  final p = profile ??
      SieCalibrationProfile.identity(now: DateTime.utc(2026, 1, 1)).copyWith(
        isIdentity: false,
        validated: true,
        profileId: 'test',
      );
  return SieCalibratedFrameSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12, 0, 0),
    frameSequence: sequence,
    visionTrackingState: (hands == null || hands.isEmpty)
        ? SieVisionTrackingState.lost
        : SieVisionTrackingState.tracking,
    profile: p,
    hands: hands ?? [_hand()],
    processingMs: 0.4,
    viewWidth: 800,
    viewHeight: 600,
  );
}

/// Drive engine with N identical high-confidence frames.
List<SieConfidenceFrameSnapshot> _pump(
  SieConfidenceEngine engine, {
  required int count,
  double nx = 0.5,
  double ny = 0.5,
  double confidence = 0.92,
  DateTime? start,
}) {
  final out = <SieConfidenceFrameSnapshot>[];
  var t = start ?? DateTime.utc(2026, 7, 17, 12, 0, 0);
  for (var i = 0; i < count; i++) {
    out.add(
      engine.process(
        _frame(
          timestamp: t,
          sequence: i + 1,
          hands: [_hand(nx: nx, ny: ny, confidence: confidence)],
        ),
      ),
    );
    t = t.add(const Duration(milliseconds: 33));
  }
  return out;
}

void main() {
  group('SieHysteresisGate', () {
    test('requires enter frames before latching', () {
      final gate = SieHysteresisGate(
        enterThreshold: 0.7,
        exitThreshold: 0.5,
        enterFrames: 3,
        exitFrames: 2,
      );
      expect(gate.update(0.8), isFalse);
      expect(gate.update(0.8), isFalse);
      expect(gate.update(0.8), isTrue);
    });

    test('requires exit frames before unlatching', () {
      final gate = SieHysteresisGate(
        enterThreshold: 0.7,
        exitThreshold: 0.5,
        enterFrames: 1,
        exitFrames: 3,
        initial: true,
      );
      expect(gate.update(0.4), isTrue);
      expect(gate.update(0.4), isTrue);
      expect(gate.update(0.4), isFalse);
    });

    test('rejects inverted thresholds', () {
      expect(
        () => SieHysteresisGate(
          enterThreshold: 0.4,
          exitThreshold: 0.5,
          enterFrames: 1,
          exitFrames: 1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('SieConfidenceFusion', () {
    const fusion = SieConfidenceFusion();

    test('weakest-link is min of sources', () {
      final sources = fusion.fuse(
        frame: _frame(hands: [_hand(confidence: 0.9)]),
        temporalStability: 0.5,
        trackingContinuity: 0.8,
        thresholds: SieConfidenceThresholds.standard,
      );
      expect(sources.weakestLink, closeTo(0.5, 1e-9));
      expect(sources.vision, closeTo(0.9, 1e-9));
      expect(sources.landmarkCompleteness, closeTo(1.0, 1e-9));
    });

    test('empty hand yields zero vision', () {
      final sources = fusion.fuse(
        frame: _frame(hands: const []),
        temporalStability: 0.2,
        trackingContinuity: 0,
        thresholds: SieConfidenceThresholds.standard,
      );
      expect(sources.vision, 0);
      expect(sources.weakestLink, 0);
    });
  });

  group('SieConfidenceEngine', () {
    late SieConfidenceEngine engine;

    setUp(() {
      engine = SieConfidenceEngine(
        policy: SieConfidencePolicy.standard,
        logger: const NopSieConfidenceLogger(),
      );
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('stable tracking after enter hysteresis', () async {
      await engine.initialize();
      final frames = _pump(engine, count: 12, confidence: 0.95);
      final last = frames.last;
      expect(
        last.trackingState == SieTrackingReliabilityState.tracking ||
            last.trackingState == SieTrackingReliabilityState.stable,
        isTrue,
      );
      expect(last.mayConsume, isTrue);
      expect(last.overallConfidence, greaterThan(0.5));
      expect(last.timestamp, isNotNull);
    });

    test('lost tracking after sustained absence', () async {
      await engine.initialize();
      _pump(engine, count: 8, confidence: 0.95);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 1);
      SieConfidenceFrameSnapshot? last;
      for (var i = 0; i < 8; i++) {
        last = engine.process(
          _frame(
            timestamp: t,
            sequence: 100 + i,
            hands: const [],
          ),
        );
        t = t.add(const Duration(milliseconds: 40));
      }
      expect(last!.trackingState, SieTrackingReliabilityState.lostTracking);
      expect(last.mayConsume, isFalse);
      expect(last.commitsSuppressed, isTrue);
      expect(engine.metrics.lostTrackingCount, greaterThan(0));
    });

    test('recovering then tracking after grace (ADR-016)', () async {
      await engine.initialize(
        policy: const SieConfidencePolicy(
          id: SieConfidencePolicyId.debug,
          thresholds: SieConfidenceThresholds(
            trackEnter: 0.4,
            trackExit: 0.2,
            stableEnter: 0.7,
            stableExit: 0.5,
            degradedEnter: 0.35,
            degradedExit: 0.45,
            gestureReadyEnter: 0.5,
            gestureReadyExit: 0.3,
            recoveryEnter: 0.45,
            invalidFloor: 0.05,
            weakFloor: 0.25,
            stabilityEnter: 0.4,
            stabilityExit: 0.2,
            enterFrames: 1,
            exitFrames: 1,
            recoverMs: 200,
            lostMs: 50,
            stabilityWindow: 4,
            stabilityDeltaLimit: 0.08,
            noiseSpikeLimit: 0.5,
          ),
        ),
      );

      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      // Acquire
      for (var i = 0; i < 4; i++) {
        engine.process(
          _frame(timestamp: t, hands: [_hand(confidence: 0.9)]),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      // Lose
      SieConfidenceFrameSnapshot? lost;
      for (var i = 0; i < 4; i++) {
        lost = engine.process(_frame(timestamp: t, hands: const []));
        t = t.add(const Duration(milliseconds: 40));
      }
      expect(lost!.trackingState, SieTrackingReliabilityState.lostTracking);

      // Reacquire → Recovering
      final recovering = engine.process(
        _frame(timestamp: t, hands: [_hand(confidence: 0.9)]),
      );
      expect(
        recovering.trackingState,
        SieTrackingReliabilityState.recovering,
      );
      expect(recovering.recovery.commitsSuppressed, isTrue);
      expect(recovering.gestureReady, isFalse);

      // Before grace ends still recovering
      t = t.add(const Duration(milliseconds: 80));
      final still = engine.process(
        _frame(timestamp: t, hands: [_hand(confidence: 0.9)]),
      );
      expect(still.trackingState, SieTrackingReliabilityState.recovering);

      // After grace
      t = t.add(const Duration(milliseconds: 200));
      SieConfidenceFrameSnapshot? done;
      for (var i = 0; i < 4; i++) {
        done = engine.process(
          _frame(timestamp: t, hands: [_hand(confidence: 0.9)]),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(
        done!.trackingState == SieTrackingReliabilityState.tracking ||
            done.trackingState == SieTrackingReliabilityState.stable,
        isTrue,
      );
      expect(engine.metrics.recoveryCount, greaterThan(0));
    });

    test('degraded on low confidence while hand present', () async {
      await engine.initialize(
        policy: SieConfidencePolicy.fromId(SieConfidencePolicyId.debug),
      );
      _pump(engine, count: 8, confidence: 0.95);
      final frames = _pump(engine, count: 10, confidence: 0.42);
      final last = frames.last;
      expect(
        last.trackingState == SieTrackingReliabilityState.degraded ||
            last.frameValidation == SieConfidenceFrameValidation.weak ||
            last.frameValidation == SieConfidenceFrameValidation.invalid ||
            last.overallConfidence < 0.55,
        isTrue,
      );
    });

    test('noise spike is softened by smoother', () async {
      await engine.initialize();
      final stable = _pump(engine, count: 6, confidence: 0.9);
      final baseline = stable.last.smoothedConfidence;
      final spiked = engine.process(
        _frame(hands: [_hand(confidence: 0.1)]),
      );
      // Should not instantly collapse to 0.1
      expect(spiked.smoothedConfidence, greaterThan(0.1));
      expect(spiked.smoothedConfidence, lessThan(baseline));
    });

    test('identical input yields identical confidence after warm-up', () async {
      await engine.initialize();
      _pump(engine, count: 20, confidence: 0.9, nx: 0.5, ny: 0.5);
      final input = _frame(hands: [_hand(confidence: 0.9)]);
      final a = engine.process(input);
      final b = engine.process(input);
      expect(a.trackingState, b.trackingState);
      expect(a.overallConfidence, closeTo(b.overallConfidence, 0.02));
    });

    test('policy switch changes thresholds', () async {
      await engine.initialize();
      await engine.setPolicy(SieConfidencePolicyId.precision);
      expect(engine.policy.id, SieConfidencePolicyId.precision);
      await engine.setPolicy(SieConfidencePolicyId.accessibility);
      expect(engine.policy.id, SieConfidencePolicyId.accessibility);
    });

    test('invalid NaN confidence treated as invalid', () async {
      await engine.initialize();
      final bad = SieCalibratedHandSnapshot(
        handId: 0,
        handedness: SieHandedness.right,
        handednessScore: double.nan,
        handConfidence: double.nan,
        landmarks: [for (var i = 0; i < 21; i++) _clm(index: i)],
        resolvedHandedness: SieCalibratedHandedness.right,
        mirrored: false,
      );
      final out = engine.process(_frame(hands: [bad]));
      expect(out.overallConfidence, lessThan(0.2));
    });

    test('preserves timestamp and frame sequence', () async {
      await engine.initialize();
      final ts = DateTime.utc(2026, 3, 4, 5, 6, 7);
      final out = engine.process(
        _frame(timestamp: ts, sequence: 42, hands: [_hand()]),
      );
      expect(out.timestamp, ts);
      expect(out.frameSequence, 42);
    });

    test('stream start emits confidence snapshots', () async {
      await engine.initialize();
      final controller = StreamController<SieCalibratedFrameSnapshot>();
      final received = <SieConfidenceFrameSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      await engine.start(controller.stream);
      controller.add(_frame());
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      await engine.stop();
      await sub.cancel();
      await controller.close();
    });

    test('performance: 500 frames under soft budget', () async {
      await engine.initialize();
      final input = _frame();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        engine.process(input);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(engine.metrics.averageProcessingMs, lessThan(5));
    });

    test('setEnabled disables tracking', () async {
      await engine.initialize();
      _pump(engine, count: 5);
      engine.setEnabled(false);
      final out = engine.process(_frame());
      expect(out.trackingState, SieTrackingReliabilityState.disabled);
      expect(out.mayConsume, isFalse);
    });

    test('threshold hysteresis prevents oscillation', () async {
      await engine.initialize(
        policy: const SieConfidencePolicy(
          id: SieConfidencePolicyId.standard,
          thresholds: SieConfidenceThresholds(
            trackEnter: 0.6,
            trackExit: 0.4,
            stableEnter: 0.85,
            stableExit: 0.7,
            degradedEnter: 0.5,
            degradedExit: 0.58,
            gestureReadyEnter: 0.7,
            gestureReadyExit: 0.5,
            recoveryEnter: 0.55,
            invalidFloor: 0.1,
            weakFloor: 0.4,
            stabilityEnter: 0.7,
            stabilityExit: 0.5,
            enterFrames: 3,
            exitFrames: 3,
            recoverMs: 400,
            lostMs: 100,
            stabilityWindow: 6,
            stabilityDeltaLimit: 0.05,
            noiseSpikeLimit: 0.3,
          ),
        ),
      );
      // Hover around enter threshold without full latch
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final states = <SieTrackingReliabilityState>[];
      for (var i = 0; i < 6; i++) {
        final conf = i.isEven ? 0.61 : 0.39;
        final snap = engine.process(
          _frame(
            timestamp: t,
            hands: [_hand(confidence: conf)],
          ),
        );
        states.add(snap.trackingState);
        t = t.add(const Duration(milliseconds: 33));
      }
      // Should not flip every frame between tracking and idle/lost
      var flips = 0;
      for (var i = 1; i < states.length; i++) {
        if (states[i] != states[i - 1]) flips++;
      }
      expect(flips, lessThan(states.length - 1));
    });
  });

  group('SieConfidenceThresholds', () {
    test('all policies have valid hysteresis bands', () {
      for (final id in SieConfidencePolicyId.values) {
        expect(SieConfidenceThresholds.forPolicy(id).isValid, isTrue);
      }
    });
  });
}
