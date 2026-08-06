import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieNormalizedLandmark _nlm(
  int index,
  double x,
  double y, {
  double z = 0,
}) =>
    SieNormalizedLandmark(index: index, x: x, y: y, z: z);

List<SieNormalizedLandmark> _landmarksAt(double x, double y) {
  return List.generate(
    21,
    (i) => _nlm(i, i == 8 ? x : 0.4 + i * 0.001, i == 8 ? y : 0.5),
  );
}

SieHandLandmarkSnapshot _usableHand({
  double tipX = 0.5,
  double tipY = 0.5,
  SieHandedness handedness = SieHandedness.right,
  double confidence = 0.91,
  int handId = 0,
}) {
  return SieHandLandmarkSnapshot(
    handId: handId,
    handedness: handedness,
    handednessScore: confidence,
    handConfidence: confidence,
    landmarks: _landmarksAt(tipX, tipY),
    validationState: SieLandmarkValidationState.valid,
    wasStabilized: true,
  );
}

SieLandmarkFrameSnapshot _frame({
  List<SieHandLandmarkSnapshot>? hands,
  int sequence = 7,
  DateTime? timestamp,
}) {
  return SieLandmarkFrameSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12, 0, 0),
    frameSequence: sequence,
    visionTrackingState: SieVisionTrackingState.tracking,
    hands: hands ?? [_usableHand()],
    validationState: SieLandmarkValidationState.valid,
    processingMs: 1.2,
    visionInferenceMs: 8,
  );
}

SieViewportGeometry _view({
  double w = 800,
  double h = 600,
  double aspect = 16 / 9,
  double dpr = 1,
  SieCameraOrientation orientation = SieCameraOrientation.rotation0,
  SieViewportFitMode fit = SieViewportFitMode.contain,
  bool mirror = false,
  double marginL = 0,
  double marginT = 0,
  double marginR = 0,
  double marginB = 0,
}) {
  return SieViewportGeometry(
    viewWidth: w,
    viewHeight: h,
    cameraAspectRatio: aspect,
    devicePixelRatio: dpr,
    orientation: orientation,
    fitMode: fit,
    mirrorHorizontal: mirror,
    marginLeft: marginL,
    marginTop: marginT,
    marginRight: marginR,
    marginBottom: marginB,
  );
}

void main() {
  group('SieSpatialTransformPipeline', () {
    const pipeline = SieSpatialTransformPipeline(SieSpatialEngineConfig(
      mirrorPolicy: SieMirrorPolicy.configurable,
      clampToViewport: false,
      clampToSafeMargins: false,
    ));

    test('contain letterboxes wide camera into shorter view', () {
      final viewport = _view();
      final layout = pipeline.layout(viewport);
      expect(layout.content.width, closeTo(800, 1e-9));
      expect(layout.content.height, closeTo(800 / (16 / 9), 1e-9));
      expect(layout.content.top, closeTo((600 - layout.content.height) / 2, 1e-9));
      expect(layout.content.left, 0);
    });

    test('contain pillarboxes tall camera into wider view', () {
      final viewport = _view(aspect: 9 / 16);
      final layout = pipeline.layout(viewport);
      expect(layout.content.height, closeTo(600, 1e-9));
      expect(layout.content.width, closeTo(600 * (9 / 16), 1e-9));
      expect(layout.content.left, closeTo((800 - layout.content.width) / 2, 1e-9));
    });

    test('cover crops wide camera', () {
      final viewport = _view(fit: SieViewportFitMode.cover);
      final layout = pipeline.layout(viewport);
      expect(layout.content.height, closeTo(600, 1e-9));
      expect(layout.content.width, closeTo(600 * (16 / 9), 1e-9));
      expect(layout.content.width, greaterThan(800));
    });

    test('camera → normalized identity at rotation0 without mirror', () {
      final n = pipeline.toNormalized(
        cameraX: 0.25,
        cameraY: 0.4,
        orientation: SieCameraOrientation.rotation0,
        mirrorHorizontal: false,
      );
      expect(n.x, 0.25);
      expect(n.y, 0.4);
    });

    test('mirroring flips X after orientation', () {
      final n = pipeline.toNormalized(
        cameraX: 0.25,
        cameraY: 0.4,
        orientation: SieCameraOrientation.rotation0,
        mirrorHorizontal: true,
      );
      expect(n.x, closeTo(0.75, 1e-12));
      expect(n.y, 0.4);
    });

    test('orientation 90 then mirror', () {
      // (0.25, 0.1) → (0.1, 0.75) then mirror X → (0.9, 0.75)
      final n = pipeline.toNormalized(
        cameraX: 0.25,
        cameraY: 0.1,
        orientation: SieCameraOrientation.rotation90,
        mirrorHorizontal: true,
      );
      expect(n.x, closeTo(0.9, 1e-12));
      expect(n.y, closeTo(0.75, 1e-12));
    });

    test('orientation 180', () {
      final n = pipeline.toNormalized(
        cameraX: 0.2,
        cameraY: 0.3,
        orientation: SieCameraOrientation.rotation180,
        mirrorHorizontal: false,
      );
      expect(n.x, closeTo(0.8, 1e-12));
      expect(n.y, closeTo(0.7, 1e-12));
    });

    test('orientation 270', () {
      final n = pipeline.toNormalized(
        cameraX: 0.2,
        cameraY: 0.3,
        orientation: SieCameraOrientation.rotation270,
        mirrorHorizontal: false,
      );
      expect(n.x, closeTo(0.7, 1e-12));
      expect(n.y, closeTo(0.2, 1e-12));
    });

    test('full pipeline maps center to view center (contain)', () {
      final viewport = _view(mirror: false);
      final layout = pipeline.layout(viewport);
      final t = pipeline.transformPoint(
        cameraX: 0.5,
        cameraY: 0.5,
        viewport: viewport,
        layout: layout,
      );
      expect(t.flutter.x, closeTo(400, 1e-9));
      expect(t.flutter.y, closeTo(300, 1e-9));
      expect(t.outOfBounds, isFalse);
    });

    test('stages are distinct and ordered', () {
      final viewport = _view(mirror: false);
      final layout = pipeline.layout(viewport);
      final t = pipeline.transformPoint(
        cameraX: 0.0,
        cameraY: 0.0,
        viewport: viewport,
        layout: layout,
      );
      expect(t.camera.x, 0);
      expect(t.normalized.x, 0);
      expect(t.viewport.x, 0);
      expect(t.screen.x, layout.content.left);
      expect(t.flutter.x, layout.content.left);
      expect(t.screen.y, layout.content.top);
    });

    test('invalid viewport throws', () {
      expect(
        () => pipeline.layout(SieViewportGeometry.unset),
        throwsArgumentError,
      );
    });
  });

  group('SieSpatialCoordinateEngine', () {
    late SieSpatialCoordinateEngine engine;

    setUp(() {
      engine = SieSpatialCoordinateEngine(
        config: const SieSpatialEngineConfig(
          mirrorPolicy: SieMirrorPolicy.configurable,
          clampToViewport: true,
          clampToSafeMargins: true,
        ),
        logger: const NopSieSpatialLogger(),
      );
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('preserves timestamp, sequence, handedness, confidence', () async {
      final ts = DateTime.utc(2026, 1, 2, 3, 4, 5);
      await engine.initialize(viewport: _view());
      final out = engine.process(
        _frame(
          timestamp: ts,
          sequence: 42,
          hands: [
            _usableHand(
              tipX: 0.5,
              tipY: 0.5,
              handedness: SieHandedness.left,
              confidence: 0.77,
              handId: 3,
            ),
          ],
        ),
      );
      expect(out.timestamp, ts);
      expect(out.frameSequence, 42);
      expect(out.hands, hasLength(1));
      expect(out.hands.first.handId, 3);
      expect(out.hands.first.handedness, SieHandedness.left);
      expect(out.hands.first.handednessScore, 0.77);
      expect(out.hands.first.handConfidence, 0.77);
      expect(out.hands.first.landmarks, hasLength(21));
    });

    test('skips rejected hands', () async {
      await engine.initialize(viewport: _view());
      final rejected = SieHandLandmarkSnapshot.rejected(
        handId: 1,
        handedness: SieHandedness.right,
        handednessScore: 0.1,
        handConfidence: 0.1,
        reason: SieLandmarkRejectionReason.invalidCount,
      );
      final out = engine.process(
        _frame(hands: [rejected, _usableHand()]),
      );
      expect(out.hands, hasLength(1));
      expect(out.hands.first.handId, 0);
    });

    test('mirroring changes flutter X', () async {
      await engine.initialize(viewport: _view(mirror: false));
      final left = engine.process(_frame(hands: [_usableHand(tipX: 0.2)]));
      engine.updateViewport(_view(mirror: true));
      final mirrored = engine.process(_frame(hands: [_usableHand(tipX: 0.2)]));
      final tipL = left.primaryHand!.indexFingertip!;
      final tipM = mirrored.primaryHand!.indexFingertip!;
      expect(tipL.flutter.x, isNot(closeTo(tipM.flutter.x, 1)));
      expect(tipM.normalized.x, closeTo(0.8, 1e-9));
    });

    test('mirror policy none ignores viewport mirror flag', () async {
      final forced = SieSpatialCoordinateEngine(
        config: const SieSpatialEngineConfig(
          mirrorPolicy: SieMirrorPolicy.none,
        ),
        logger: const NopSieSpatialLogger(),
      );
      await forced.initialize(viewport: _view(mirror: true));
      final out = forced.process(_frame(hands: [_usableHand(tipX: 0.2)]));
      expect(out.primaryHand!.indexFingertip!.normalized.x, closeTo(0.2, 1e-9));
      await forced.dispose();
    });

    test('orientation change remaps coordinates', () async {
      await engine.initialize(viewport: _view());
      final a = engine.process(_frame(hands: [_usableHand(tipX: 0.2, tipY: 0.1)]));
      engine.updateViewport(_view(orientation: SieCameraOrientation.rotation90));
      final b = engine.process(_frame(hands: [_usableHand(tipX: 0.2, tipY: 0.1)]));
      expect(
        a.primaryHand!.indexFingertip!.normalized,
        isNot(equals(b.primaryHand!.indexFingertip!.normalized)),
      );
      expect(engine.metrics.orientationChanges, greaterThan(0));
    });

    test('window resize updates mapping', () async {
      await engine.initialize(viewport: _view(w: 400, h: 300));
      final small = engine.process(_frame());
      engine.updateViewport(_view(w: 1200, h: 900));
      final large = engine.process(_frame());
      expect(
        large.primaryHand!.indexFingertip!.flutter.x,
        greaterThan(small.primaryHand!.indexFingertip!.flutter.x),
      );
      expect(engine.metrics.viewportUpdates, greaterThan(0));
    });

    test('high-DPI retains logical coordinates (DPR is diagnostic)', () async {
      await engine.initialize(viewport: _view(dpr: 1));
      final a = engine.process(_frame());
      engine.updateViewport(_view(dpr: 3));
      final b = engine.process(_frame());
      expect(
        a.primaryHand!.indexFingertip!.flutter.x,
        closeTo(b.primaryHand!.indexFingertip!.flutter.x, 1e-9),
      );
      expect(
        a.primaryHand!.indexFingertip!.flutter.y,
        closeTo(b.primaryHand!.indexFingertip!.flutter.y, 1e-9),
      );
    });

    test('clamps out-of-bounds cover overflow into safe area', () async {
      await engine.initialize(
        viewport: _view(fit: SieViewportFitMode.cover, mirror: false),
      );
      // Cover content is wider than view; corners may leave safe rect.
      final out = engine.process(
        _frame(hands: [_usableHand(tipX: 0.0, tipY: 0.5)]),
      );
      final tip = out.primaryHand!.indexFingertip!;
      expect(tip.flutter.x, greaterThanOrEqualTo(0));
      expect(tip.flutter.x, lessThanOrEqualTo(800));
    });

    test('safe margins shrink usable clamp region', () async {
      await engine.initialize(
        viewport: _view(
          mirror: false,
          marginL: 40,
          marginT: 20,
          marginR: 40,
          marginB: 20,
        ),
      );
      final out = engine.process(
        _frame(hands: [_usableHand(tipX: 0.0, tipY: 0.0)]),
      );
      final tip = out.primaryHand!.indexFingertip!;
      expect(tip.flutter.x, greaterThanOrEqualTo(40));
      expect(tip.flutter.y, greaterThanOrEqualTo(20));
    });

    test('invalid viewport yields empty recoverable snapshot', () async {
      await engine.initialize();
      final out = engine.process(_frame());
      expect(out.hands, isEmpty);
      expect(engine.currentStatus.health, SieSpatialEngineHealth.degraded);
    });

    test('identical input yields identical output', () async {
      await engine.initialize(viewport: _view());
      final input = _frame(hands: [_usableHand(tipX: 0.33, tipY: 0.66)]);
      final a = engine.process(input);
      final b = engine.process(input);
      final tipA = a.primaryHand!.indexFingertip!;
      final tipB = b.primaryHand!.indexFingertip!;
      expect(tipA.flutter.x, tipB.flutter.x);
      expect(tipA.flutter.y, tipB.flutter.y);
      expect(tipA.normalized.x, tipB.normalized.x);
    });

    test('floating-point precision at extreme corners', () async {
      await engine.initialize(viewport: _view(mirror: false));
      for (final p in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
        final out = engine.process(
          _frame(hands: [_usableHand(tipX: p.$1, tipY: p.$2)]),
        );
        final tip = out.primaryHand!.indexFingertip!;
        expect(tip.flutter.x.isFinite, isTrue);
        expect(tip.flutter.y.isFinite, isTrue);
      }
    });

    test('stream start emits spatial snapshots', () async {
      await engine.initialize(viewport: _view());
      final controller = StreamController<SieLandmarkFrameSnapshot>();
      final received = <SieSpatialFrameSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      await engine.start(controller.stream);
      controller.add(_frame());
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.first.hasHand, isTrue);
      await engine.stop();
      await sub.cancel();
      await controller.close();
    });

    test('performance: 500 frames stay under soft budget', () async {
      await engine.initialize(viewport: _view());
      final input = _frame();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        engine.process(input);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(engine.metrics.framesProcessed, 500);
      expect(engine.metrics.averageProcessingMs, lessThan(5));
    });

    test('z / visibility / presence preserved', () async {
      await engine.initialize(viewport: _view());
      final hand = SieHandLandmarkSnapshot(
        handId: 0,
        handedness: SieHandedness.right,
        handednessScore: 0.9,
        handConfidence: 0.9,
        landmarks: [
          for (var i = 0; i < 21; i++)
            SieNormalizedLandmark(
              index: i,
              x: 0.5,
              y: 0.5,
              z: i * 0.01,
              visibility: 0.8,
              presence: 0.9,
            ),
        ],
        validationState: SieLandmarkValidationState.valid,
      );
      final out = engine.process(_frame(hands: [hand]));
      final tip = out.primaryHand!.indexFingertip!;
      expect(tip.z, closeTo(0.08, 1e-12));
      expect(tip.visibility, 0.8);
      expect(tip.presence, 0.9);
    });
  });

  group('SieCameraOrientationX', () {
    test('fromDegrees wraps', () {
      expect(
        SieCameraOrientationX.fromDegrees(450),
        SieCameraOrientation.rotation90,
      );
      expect(
        SieCameraOrientationX.fromDegrees(-90),
        SieCameraOrientation.rotation270,
      );
    });
  });
}
