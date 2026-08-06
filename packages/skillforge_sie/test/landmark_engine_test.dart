import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieHandLandmark _lm(double x, double y, [double z = 0]) =>
    SieHandLandmark(x: x, y: y, z: z);

List<SieHandLandmark> _valid21({double tipX = 0.5, double tipY = 0.4}) {
  return List<SieHandLandmark>.generate(21, (i) {
    if (i == 8) return _lm(tipX, tipY);
    return _lm(0.45 + i * 0.001, 0.55 + i * 0.001, i * 0.01);
  });
}

SieDetectedHand _hand({
  List<SieHandLandmark>? landmarks,
  SieHandedness handedness = SieHandedness.right,
  double confidence = 0.9,
  int index = 0,
}) {
  return SieDetectedHand(
    landmarks: landmarks ?? _valid21(),
    handedness: handedness,
    handednessScore: confidence,
    handConfidence: confidence,
    index: index,
  );
}

SieVisionResult _vision({
  List<SieDetectedHand>? hands,
  int sequence = 1,
  DateTime? timestamp,
}) {
  final ts = timestamp ?? DateTime.utc(2026, 7, 17, 12, 0, 0);
  final h = hands ?? [_hand()];
  return SieVisionResult(
    timestamp: ts,
    frameSequence: sequence,
    hands: h,
    trackingState: h.isEmpty
        ? SieVisionTrackingState.searching
        : SieVisionTrackingState.tracking,
    inferenceMs: 8,
    detected: h.isNotEmpty,
  );
}

void main() {
  group('SieLandmarkValidator', () {
    const validator = SieLandmarkValidator(SieLandmarkEngineConfig.sieDefaults);

    test('accepts full 21-point hand', () {
      expect(validator.validateHand(_hand()).isValid, isTrue);
    });

    test('rejects invalid landmark count', () {
      final r = validator.validateHand(
        _hand(landmarks: List.generate(10, (i) => _lm(0.1 * i, 0.2))),
      );
      expect(r.isValid, isFalse);
      expect(r.reason, SieLandmarkRejectionReason.invalidCount);
    });

    test('rejects NaN coordinates', () {
      final bad = _valid21();
      bad[3] = _lm(double.nan, 0.5);
      final r = validator.validateHand(_hand(landmarks: bad));
      expect(r.reason, SieLandmarkRejectionReason.nanValue);
    });

    test('rejects infinite coordinates', () {
      final bad = _valid21();
      bad[5] = _lm(double.infinity, 0.5);
      final r = validator.validateHand(_hand(landmarks: bad));
      expect(r.reason, SieLandmarkRejectionReason.infiniteValue);
    });

    test('rejects out-of-range coordinates', () {
      final bad = _valid21();
      bad[2] = _lm(5.0, 0.5);
      final r = validator.validateHand(_hand(landmarks: bad));
      expect(r.reason, SieLandmarkRejectionReason.outOfRange);
    });

    test('rejects collapsed structure', () {
      final collapsed = List.generate(21, (_) => _lm(0.5, 0.5));
      final r = validator.validateHand(_hand(landmarks: collapsed));
      expect(r.reason, SieLandmarkRejectionReason.collapsedStructure);
    });

    test('rejects corrupted confidence', () {
      final hand = SieDetectedHand(
        landmarks: _valid21(),
        handedness: SieHandedness.left,
        handednessScore: double.nan,
        handConfidence: 0.8,
      );
      expect(
        validator.validateHand(hand).reason,
        SieLandmarkRejectionReason.corrupted,
      );
    });
  });

  group('SieLandmarkNormalizer', () {
    test('clamps into unit square and flags degraded', () {
      const normalizer = SieLandmarkNormalizer(SieLandmarkEngineConfig.sieDefaults);
      final raw = _valid21();
      raw[0] = _lm(-0.1, 1.1);
      final out = normalizer.normalize(raw);
      expect(out.wasClamped, isTrue);
      expect(out.landmarks[0].x, 0.0);
      expect(out.landmarks[0].y, 1.0);
      expect(out.landmarks[0].index, 0);
    });

    test('preserves ordering indices', () {
      const normalizer = SieLandmarkNormalizer(SieLandmarkEngineConfig.sieDefaults);
      final out = normalizer.normalize(_valid21());
      expect(out.landmarks.length, 21);
      for (var i = 0; i < 21; i++) {
        expect(out.landmarks[i].index, i);
      }
    });
  });

  group('SieLandmarkStabilizer', () {
    test('smooths toward new tip without inventing timestamps', () {
      final stabilizer = SieLandmarkStabilizer(
        const SieLandmarkEngineConfig(stabilizationAlpha: 0.5),
      );
      const normalizer = SieLandmarkNormalizer(SieLandmarkEngineConfig.sieDefaults);
      final a = normalizer.normalize(_valid21(tipX: 0.2, tipY: 0.2)).landmarks;
      final b = normalizer.normalize(_valid21(tipX: 0.8, tipY: 0.8)).landmarks;
      stabilizer.stabilize(handId: 0, current: a);
      final second = stabilizer.stabilize(handId: 0, current: b);
      expect(second.applied, isTrue);
      expect(second.landmarks[8].x, greaterThan(0.2));
      expect(second.landmarks[8].x, lessThan(0.8));
    });

    test('reset clears history', () {
      final stabilizer = SieLandmarkStabilizer(SieLandmarkEngineConfig.sieDefaults);
      const normalizer = SieLandmarkNormalizer(SieLandmarkEngineConfig.sieDefaults);
      final a = normalizer.normalize(_valid21()).landmarks;
      stabilizer.stabilize(handId: 0, current: a);
      stabilizer.reset();
      final again = stabilizer.stabilize(handId: 0, current: a);
      expect(again.applied, isFalse);
    });
  });

  group('SieLandmarkEngine', () {
    test('preserves timestamp, sequence, handedness, confidence', () {
      final engine = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      final ts = DateTime.utc(2026, 1, 2, 3, 4, 5, 6);
      final snap = engine.process(
        _vision(
          timestamp: ts,
          sequence: 42,
          hands: [
            _hand(handedness: SieHandedness.left, confidence: 0.77),
          ],
        ),
      );
      expect(snap.timestamp, ts);
      expect(snap.frameSequence, 42);
      expect(snap.primaryHand?.handedness, SieHandedness.left);
      expect(snap.primaryHand?.handConfidence, 0.77);
      expect(snap.primaryHand?.handednessScore, 0.77);
      expect(snap.visionInferenceMs, 8);
      expect(snap.hasUsableHand, isTrue);
    });

    test('empty vision yields empty validation state', () {
      final engine = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      final snap = engine.process(_vision(hands: const []));
      expect(snap.validationState, SieLandmarkValidationState.empty);
      expect(snap.hands, isEmpty);
    });

    test('rejects corrupted hand gracefully', () {
      final engine = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      final bad = _valid21();
      bad[1] = _lm(double.nan, 0.2);
      final snap = engine.process(_vision(hands: [_hand(landmarks: bad)]));
      expect(snap.validationState, SieLandmarkValidationState.rejected);
      expect(snap.hasUsableHand, isFalse);
      expect(engine.metrics.handsRejected, 1);
    });

    test('multi-hand keeps usable and rejects independently', () {
      final engine = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      final bad = List.generate(5, (i) => _lm(0.1 * i, 0.1));
      final snap = engine.process(
        _vision(
          hands: [
            _hand(index: 0),
            _hand(index: 1, landmarks: bad),
          ],
        ),
      );
      expect(snap.usableHands, hasLength(1));
      expect(snap.hands.where((h) => !h.isUsable), hasLength(1));
    });

    test('stream start publishes snapshots', () async {
      final engine = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      await engine.initialize();
      final received = <SieLandmarkFrameSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      final controller = StreamController<SieVisionResult>();
      await engine.start(controller.stream);
      controller.add(_vision(sequence: 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isNotEmpty);
      expect(received.last.frameSequence, 7);
      await engine.stop();
      await sub.cancel();
      await controller.close();
      await engine.dispose();
    });

    test('dispose is idempotent and blocks process via ensure on start', () async {
      final engine = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      await engine.dispose();
      await engine.dispose();
      expect(
        () => engine.initialize(),
        throwsA(isA<SieLandmarkEngineFailure>()),
      );
    });

    test('stabilization reduces tip jump vs raw', () {
      final engine = SieLandmarkEngine(
        config: const SieLandmarkEngineConfig(stabilizationAlpha: 0.3),
        logger: const NopSieLandmarkLogger(),
      );
      final a = engine.process(
        _vision(hands: [_hand(landmarks: _valid21(tipX: 0.1, tipY: 0.1))]),
      );
      final b = engine.process(
        _vision(hands: [_hand(landmarks: _valid21(tipX: 0.9, tipY: 0.9))]),
      );
      final tip = b.primaryHand!.landmarks[8];
      expect(a.primaryHand!.wasStabilized, isFalse);
      expect(b.primaryHand!.wasStabilized, isTrue);
      expect(tip.x, lessThan(0.9));
      expect(tip.x, greaterThan(0.1));
    });
  });
}
