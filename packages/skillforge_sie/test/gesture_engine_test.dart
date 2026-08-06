import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieCalibratedLandmark _lm(int index, double x, double y) {
  return SieCalibratedLandmark(
    index: index,
    originalFlutter: SieSpatialPoint2D(x * 800, y * 600),
    calibrated: SieSpatialPoint2D(x * 800, y * 600),
    normalizedCalibrated: SieSpatialPoint2D(x, y),
    inDeadZone: false,
    inRestZone: false,
    clamped: false,
  );
}

/// Build 21 landmarks with controllable thumb/index tips and finger curl.
List<SieCalibratedLandmark> _handLandmarks({
  required double pinch,
  required bool open,
  required bool fist,
  double tipX = 0.5,
  double tipY = 0.4,
}) {
  final wrist = const SieSpatialPoint2D(0.5, 0.7);
  final landmarks = <SieCalibratedLandmark>[];
  for (var i = 0; i < 21; i++) {
    var p = SieSpatialPoint2D(wrist.x, wrist.y);
    if (i == 0) {
      p = wrist;
    } else if (i == 4) {
      // thumb tip — offset from index by pinch distance
      p = SieSpatialPoint2D(tipX - pinch, tipY);
    } else if (i == 8) {
      p = SieSpatialPoint2D(tipX, tipY);
    } else if (i == 5 || i == 9 || i == 13 || i == 17) {
      // MCPs
      p = SieSpatialPoint2D(0.42 + (i % 5) * 0.04, 0.55);
    } else if (i == 12 || i == 16 || i == 20) {
      if (fist) {
        p = SieSpatialPoint2D(0.45 + (i % 3) * 0.02, 0.58);
      } else if (open) {
        p = SieSpatialPoint2D(0.35 + (i - 12) * 0.05, 0.25);
      } else {
        p = SieSpatialPoint2D(tipX, tipY + 0.05);
      }
    } else {
      p = SieSpatialPoint2D(0.48 + i * 0.001, 0.6);
    }
    landmarks.add(_lm(i, p.x, p.y));
  }
  // Ensure index tip exact
  landmarks[8] = _lm(8, tipX, tipY);
  landmarks[4] = _lm(4, tipX - pinch, tipY);
  if (open && !fist) {
    landmarks[12] = _lm(12, tipX + 0.02, tipY - 0.2);
    landmarks[16] = _lm(16, tipX + 0.06, tipY - 0.18);
    landmarks[20] = _lm(20, tipX + 0.10, tipY - 0.15);
  }
  if (fist) {
    final mcpY = 0.55;
    landmarks[5] = _lm(5, 0.45, mcpY);
    landmarks[9] = _lm(9, 0.50, mcpY);
    landmarks[13] = _lm(13, 0.55, mcpY);
    landmarks[17] = _lm(17, 0.60, mcpY);
    landmarks[8] = _lm(8, 0.45, mcpY + 0.015);
    landmarks[12] = _lm(12, 0.50, mcpY + 0.015);
    landmarks[16] = _lm(16, 0.55, mcpY + 0.015);
    landmarks[20] = _lm(20, 0.60, mcpY + 0.015);
    landmarks[4] = _lm(4, 0.43, mcpY + 0.01);
    landmarks[0] = _lm(0, 0.50, 0.72);
  }
  return landmarks;
}

SieCalibratedHandSnapshot _calHand({
  required double pinch,
  bool open = false,
  bool fist = false,
  double tipX = 0.5,
  double tipY = 0.4,
  double confidence = 0.95,
}) {
  return SieCalibratedHandSnapshot(
    handId: 0,
    handedness: SieHandedness.right,
    handednessScore: confidence,
    handConfidence: confidence,
    landmarks: _handLandmarks(
      pinch: pinch,
      open: open,
      fist: fist,
      tipX: tipX,
      tipY: tipY,
    ),
    resolvedHandedness: SieCalibratedHandedness.right,
    mirrored: false,
  );
}

SieConfidenceFrameSnapshot _conf({
  required List<SieCalibratedHandSnapshot> hands,
  DateTime? timestamp,
  int sequence = 1,
  SieTrackingReliabilityState tracking =
      SieTrackingReliabilityState.stable,
  bool gestureReady = true,
  bool mayConsume = true,
  bool commitsSuppressed = false,
  double overall = 0.9,
}) {
  return SieConfidenceFrameSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12, 0, 0),
    frameSequence: sequence,
    visionTrackingState: SieVisionTrackingState.tracking,
    trackingState: tracking,
    overallConfidence: overall,
    sources: const SieConfidenceSources(
      vision: 0.9,
      landmarkQuality: 0.9,
      landmarkCompleteness: 1,
      calibrationValidity: 1,
      temporalStability: 0.9,
      trackingContinuity: 0.9,
    ),
    temporalStabilityScore: 0.9,
    frameValidation: SieConfidenceFrameValidation.valid,
    policyId: SieConfidencePolicyId.standard,
    recovery: commitsSuppressed
        ? const SieRecoveryStatus(
            inRecovery: true,
            elapsedMs: 100,
            remainingMs: 400,
            commitsSuppressed: true,
          )
        : SieRecoveryStatus.none,
    gestureReady: gestureReady,
    mayConsume: mayConsume,
    processingMs: 0.5,
    hands: hands,
    viewWidth: 800,
    viewHeight: 600,
    smoothedConfidence: overall,
  );
}

void main() {
  final debugPolicy = SieGesturePolicy.fromId(
    SieGesturePolicyId.debug,
    swipeNavigationEnabled: false,
    dwellSelectEnabled: false,
  );

  group('SieHandFeatureExtractor', () {
    const extractor = SieHandFeatureExtractor();

    test('pinch distance tracks thumb-index separation', () {
      final wide = extractor.extract(
        hand: _calHand(pinch: 0.2, open: true),
        timestampMs: 0,
      );
      final tight = extractor.extract(
        hand: _calHand(pinch: 0.04, open: false),
        timestampMs: 0,
      );
      expect(wide.pinchDistance, greaterThan(tight.pinchDistance));
      expect(wide.valid, isTrue);
    });
  });

  group('SieGestureEngine pinch family', () {
    late SieGestureEngine engine;

    setUp(() {
      engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('arm → commit → hold → release', () async {
      await engine.initialize(policy: debugPolicy);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final events = <SieGestureEvent>[];

      // Approach arm zone
      for (var i = 0; i < 3; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  sequence: i,
                  hands: [_calHand(pinch: 0.09)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(events.any((e) => e.kind == SieGestureKind.pinchArm), isTrue);

      // Hold in commit zone past armMin + commitMin
      for (var i = 0; i < 8; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  sequence: 10 + i,
                  hands: [_calHand(pinch: 0.04)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(events.any((e) => e.kind == SieGestureKind.pinchCommit), isTrue);
      expect(events.any((e) => e.kind == SieGestureKind.pinchHold), isTrue);
      expect(engine.metrics.commitsRecognized, greaterThan(0));

      // Release
      for (var i = 0; i < 5; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  sequence: 30 + i,
                  hands: [_calHand(pinch: 0.18, open: true)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(events.any((e) => e.kind == SieGestureKind.pinchRelease), isTrue);
    });

    test('recovering suppresses pinch commit', () async {
      await engine.initialize(policy: debugPolicy);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      // Arm first without suppress
      for (var i = 0; i < 4; i++) {
        engine.process(
          _conf(
            timestamp: t,
            hands: [_calHand(pinch: 0.05)],
            commitsSuppressed: false,
          ),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      // Continue with suppress — should not count new commits ideally
      final before = engine.metrics.commitsRecognized;
      for (var i = 0; i < 10; i++) {
        engine.process(
          _conf(
            timestamp: t,
            hands: [_calHand(pinch: 0.04)],
            commitsSuppressed: true,
            tracking: SieTrackingReliabilityState.recovering,
            gestureReady: false,
          ),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(engine.metrics.commitsRecognized, before);
      expect(engine.metrics.suppressedWhileRecovering, greaterThan(0));
    });
  });

  group('SieGestureEngine fist and open hand', () {
    late SieGestureEngine engine;

    setUp(() {
      engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('recognizes fist cancel', () async {
      await engine.initialize(policy: debugPolicy);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final events = <SieGestureEvent>[];
      for (var i = 0; i < 6; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  hands: [_calHand(pinch: 0.05, fist: true)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(events.any((e) => e.kind == SieGestureKind.fistCancel), isTrue);
      expect(engine.metrics.cancelsRecognized, greaterThan(0));
    });

    test('recognizes open hand point', () async {
      await engine.initialize(policy: debugPolicy);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final events = <SieGestureEvent>[];
      for (var i = 0; i < 8; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  hands: [_calHand(pinch: 0.22, open: true)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(
        events.any((e) => e.kind == SieGestureKind.openHandPoint),
        isTrue,
      );
    });
  });

  group('SieGestureEngine scroll / dwell / swipe', () {
    test('scroll intent with vertical velocity', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize(policy: debugPolicy);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final events = <SieGestureEvent>[];
      // Seed previous tip via first frames, then move tipY
      for (var i = 0; i < 10; i++) {
        final y = 0.5 - i * 0.03;
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  hands: [
                    _calHand(pinch: 0.22, open: true, tipX: 0.5, tipY: y),
                  ],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(
        events.any((e) => e.kind == SieGestureKind.scrollIntent),
        isTrue,
      );
      await engine.dispose();
    });

    test('dwell select only when enabled', () async {
      final off = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await off.initialize();
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final offEvents = <SieGestureEvent>[];
      for (var i = 0; i < 20; i++) {
        offEvents.addAll(
          off
              .process(
                _conf(
                  timestamp: t,
                  hands: [_calHand(pinch: 0.2, open: true)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(
        offEvents.any((e) => e.kind == SieGestureKind.dwellSelect),
        isFalse,
      );
      await off.dispose();

      final onPolicy = debugPolicy.copyWith(dwellSelectEnabled: true);
      final on = SieGestureEngine(
        policy: onPolicy,
        logger: const NopSieGestureLogger(),
      );
      await on.initialize(policy: onPolicy);
      t = DateTime.utc(2026, 7, 17, 13, 0, 0);
      final onEvents = <SieGestureEvent>[];
      for (var i = 0; i < 20; i++) {
        onEvents.addAll(
          on
              .process(
                _conf(
                  timestamp: t,
                  hands: [_calHand(pinch: 0.2, open: true)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(
        onEvents.any((e) => e.kind == SieGestureKind.dwellSelect),
        isTrue,
      );
      await on.dispose();
    });

    test('swipe disabled by default', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize();
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      final events = <SieGestureEvent>[];
      for (var i = 0; i < 8; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  hands: [
                    _calHand(
                      pinch: 0.2,
                      open: true,
                      tipX: 0.2 + i * 0.08,
                      tipY: 0.4,
                    ),
                  ],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(
        events.any((e) => e.kind == SieGestureKind.swipeNavigation),
        isFalse,
      );
      await engine.dispose();
    });
  });

  group('SieGestureEngine conflicts and safety', () {
    test('fist cancel beats scroll hypothesis', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize(policy: debugPolicy);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      // Build some motion then fist
      for (var i = 0; i < 4; i++) {
        engine.process(
          _conf(
            timestamp: t,
            hands: [
              _calHand(pinch: 0.2, open: true, tipY: 0.5 - i * 0.04),
            ],
          ),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      final events = <SieGestureEvent>[];
      for (var i = 0; i < 6; i++) {
        events.addAll(
          engine
              .process(
                _conf(
                  timestamp: t,
                  hands: [_calHand(pinch: 0.04, fist: true)],
                ),
              )
              .events,
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      expect(events.any((e) => e.kind == SieGestureKind.fistCancel), isTrue);
      await engine.dispose();
    });

    test('lost tracking clears activity', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize();
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      for (var i = 0; i < 4; i++) {
        engine.process(
          _conf(timestamp: t, hands: [_calHand(pinch: 0.08)]),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      final lost = engine.process(
        _conf(
          timestamp: t,
          hands: const [],
          mayConsume: false,
          tracking: SieTrackingReliabilityState.lostTracking,
          gestureReady: false,
        ),
      );
      expect(lost.activity, SieGestureActivity.none);
      await engine.dispose();
    });

    test('stream emits events', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize();
      final controller = StreamController<SieConfidenceFrameSnapshot>();
      final received = <SieGestureEvent>[];
      final sub = engine.events.listen(received.add);
      await engine.start(controller.stream);
      var t = DateTime.utc(2026, 7, 17, 12, 0, 0);
      for (var i = 0; i < 5; i++) {
        controller.add(
          _conf(timestamp: t, hands: [_calHand(pinch: 0.05)]),
        );
        t = t.add(const Duration(milliseconds: 33));
      }
      await Future<void>.delayed(Duration.zero);
      expect(received, isNotEmpty);
      await engine.stop();
      await sub.cancel();
      await controller.close();
      await engine.dispose();
    });

    test('performance: 500 frames under soft budget', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize();
      final input = _conf(hands: [_calHand(pinch: 0.15, open: true)]);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        engine.process(input);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2500));
      expect(engine.metrics.averageProcessingMs, lessThan(5));
      await engine.dispose();
    });

    test('deterministic identical frames after warm-up', () async {
      final engine = SieGestureEngine(
        policy: debugPolicy,
        logger: const NopSieGestureLogger(),
      );
      await engine.initialize();
      final input = _conf(hands: [_calHand(pinch: 0.2, open: true)]);
      for (var i = 0; i < 10; i++) {
        engine.process(input);
      }
      final a = engine.process(input);
      final b = engine.process(input);
      expect(a.activity, b.activity);
      expect(a.primaryKind, b.primaryKind);
      await engine.dispose();
    });
  });

  group('SieGestureThresholds', () {
    test('all policies valid', () {
      for (final id in SieGesturePolicyId.values) {
        expect(SieGestureThresholds.forPolicy(id).isValid, isTrue);
      }
    });
  });
}
