import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';
import 'package:skillforge_sie/src/sie_vision/util/yuv_to_rgba.dart';

SieCameraFrame _frame({int sequence = 1}) {
  return SieCameraFrame(
    timestamp: DateTime.now(),
    width: 8,
    height: 8,
    format: SieCameraImageFormat.yuv420,
    planes: [
      SieCameraPlane(bytes: Uint8List(64), bytesPerRow: 8),
    ],
    rotationDegrees: 0,
    cameraId: 'test',
    sequence: sequence,
  );
}

void main() {
  group('MockHandLandmarkerBackend', () {
    test('initialize and detect return configured hands', () async {
      final mock = MockHandLandmarkerBackend(
        handsToReturn: [MockHandLandmarkerBackend.syntheticHand()],
      );
      await mock.initialize(SieVisionConfig.sieDefaults);
      final result = await mock.detect(_frame());
      expect(result.hands, hasLength(1));
      expect(result.hands.first.hasFullLandmarkSet, isTrue);
      expect(result.hands.first.handedness, SieHandedness.right);
      await mock.dispose();
    });

    test('failOnInit throws', () async {
      final mock = MockHandLandmarkerBackend(failOnInit: true);
      expect(
        () => mock.initialize(SieVisionConfig.sieDefaults),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SieVisionProvider', () {
    test('processes camera frames into vision results', () async {
      final mock = MockHandLandmarkerBackend(
        handsToReturn: [MockHandLandmarkerBackend.syntheticHand(confidence: 0.92)],
        inferenceMs: 5,
      );
      final vision = SieVisionProvider(
        backend: mock,
        logger: const NopSieVisionLogger(),
      );
      await vision.initialize();
      expect(vision.currentStatus.initialized, isTrue);
      expect(vision.backendKind, SieVisionBackendKind.mock);

      final results = <SieVisionResult>[];
      final sub = vision.results.listen(results.add);

      final controller = StreamController<SieCameraFrame>();
      await vision.start(controller.stream);

      controller.add(_frame(sequence: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(results, isNotEmpty);
      expect(results.last.detected, isTrue);
      expect(results.last.primaryHand?.handConfidence, 0.92);
      expect(results.last.trackingState, SieVisionTrackingState.tracking);
      expect(vision.metrics.framesInferred, greaterThan(0));

      await vision.stop();
      expect(vision.currentStatus.running, isFalse);

      await sub.cancel();
      await controller.close();
      await vision.dispose();
    });

    test('emits searching/lost when no hands', () async {
      final mock = MockHandLandmarkerBackend(handsToReturn: const []);
      final vision = SieVisionProvider(
        backend: mock,
        config: const SieVisionConfig(
          recoveringTimeoutMs: 10,
          lostTimeoutMs: 30,
        ),
        logger: const NopSieVisionLogger(),
      );
      await vision.initialize();
      final results = <SieVisionResult>[];
      final sub = vision.results.listen(results.add);
      final controller = StreamController<SieCameraFrame>();
      await vision.start(controller.stream);

      controller.add(_frame(sequence: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(results.last.detected, isFalse);
      expect(
        results.last.trackingState == SieVisionTrackingState.searching ||
            results.last.trackingState == SieVisionTrackingState.lost,
        isTrue,
      );

      await sub.cancel();
      await controller.close();
      await vision.dispose();
    });

    test('multi-hand results are preserved for future', () async {
      final mock = MockHandLandmarkerBackend(
        handsToReturn: [
          MockHandLandmarkerBackend.syntheticHand(
            handedness: SieHandedness.left,
            tipX: 0.3,
          ),
          MockHandLandmarkerBackend.syntheticHand(
            handedness: SieHandedness.right,
            tipX: 0.7,
          ),
        ],
      );
      final vision = SieVisionProvider(
        backend: mock,
        config: const SieVisionConfig(numHands: 2),
        logger: const NopSieVisionLogger(),
      );
      await vision.initialize();
      final results = <SieVisionResult>[];
      final sub = vision.results.listen(results.add);
      final controller = StreamController<SieCameraFrame>();
      await vision.start(controller.stream);
      controller.add(_frame());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(results.last.handCount, 2);

      await sub.cancel();
      await controller.close();
      await vision.dispose();
    });

    test('unsupported backend fails initialize gracefully', () async {
      final vision = SieVisionProvider(
        backend: UnsupportedHandLandmarkerBackend(SiePlatformKind.windows),
        logger: const NopSieVisionLogger(),
      );
      expect(
        () => vision.initialize(),
        throwsA(isA<SieVisionInitFailure>()),
      );
      expect(vision.currentStatus.trackingState, SieVisionTrackingState.error);
      await vision.dispose();
    });

    test('detect failure is recoverable (keeps running)', () async {
      final mock = MockHandLandmarkerBackend(failOnDetect: true);
      final vision = SieVisionProvider(
        backend: mock,
        logger: const NopSieVisionLogger(),
      );
      await vision.initialize();
      final results = <SieVisionResult>[];
      final sub = vision.results.listen(results.add);
      final controller = StreamController<SieCameraFrame>();
      await vision.start(controller.stream);
      controller.add(_frame());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(vision.currentStatus.running, isTrue);
      expect(results, isNotEmpty);

      await sub.cancel();
      await controller.close();
      await vision.dispose();
    });

    test('drops frames while busy (back-pressure)', () async {
      final mock = MockHandLandmarkerBackend(
        handsToReturn: [MockHandLandmarkerBackend.syntheticHand()],
        inferenceMs: 1,
      );
      // Slow detect by failing first then succeeding - instead flood frames
      final vision = SieVisionProvider(
        backend: mock,
        logger: const NopSieVisionLogger(),
      );
      await vision.initialize();
      final controller = StreamController<SieCameraFrame>();
      await vision.start(controller.stream);
      for (var i = 0; i < 20; i++) {
        controller.add(_frame(sequence: i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vision.metrics.framesReceived, 20);
      expect(
        vision.metrics.framesDropped + vision.metrics.framesInferred,
        20,
      );

      await controller.close();
      await vision.dispose();
    });
  });

  group('yuv420ToRgba', () {
    test('produces RGBA buffer of expected size', () {
      const w = 4;
      const h = 4;
      final y = Uint8List(w * h);
      final u = Uint8List((w ~/ 2) * (h ~/ 2));
      final v = Uint8List((w ~/ 2) * (h ~/ 2));
      final rgba = yuv420ToRgba(
        width: w,
        height: h,
        y: y,
        u: u,
        v: v,
        yRowStride: w,
        uRowStride: w ~/ 2,
        vRowStride: w ~/ 2,
      );
      expect(rgba.length, w * h * 4);
    });
  });
}
