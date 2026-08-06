import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieSpatialLandmark _lm({
  int index = 8,
  double x = 400,
  double y = 300,
  double nx = 0.5,
  double ny = 0.5,
}) {
  return SieSpatialLandmark(
    index: index,
    camera: SieSpatialPoint2D(nx, ny),
    normalized: SieSpatialPoint2D(nx, ny),
    viewport: SieSpatialPoint2D(x, y),
    screen: SieSpatialPoint2D(x, y),
    flutter: SieSpatialPoint2D(x, y),
    outOfBounds: false,
    z: index * 0.01,
    visibility: 0.9,
    presence: 0.95,
  );
}

SieSpatialHandSnapshot _hand({
  double x = 400,
  double y = 300,
  SieHandedness handedness = SieHandedness.right,
  double confidence = 0.9,
}) {
  return SieSpatialHandSnapshot(
    handId: 0,
    handedness: handedness,
    handednessScore: confidence,
    handConfidence: confidence,
    landmarks: [
      for (var i = 0; i < 21; i++)
        _lm(
          index: i,
          x: i == 8 ? x : x + i,
          y: i == 8 ? y : y + i * 0.5,
        ),
    ],
  );
}

SieSpatialFrameSnapshot _spatial({
  List<SieSpatialHandSnapshot>? hands,
  double viewW = 800,
  double viewH = 600,
  int sequence = 3,
  DateTime? timestamp,
}) {
  return SieSpatialFrameSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 8, 0, 0),
    frameSequence: sequence,
    visionTrackingState: SieVisionTrackingState.tracking,
    viewport: SieViewportGeometry(
      viewWidth: viewW,
      viewHeight: viewH,
      cameraAspectRatio: 16 / 9,
    ),
    hands: hands ?? [_hand()],
    processingMs: 0.5,
  );
}

void main() {
  group('SieCalibrationProfile persistence', () {
    test('round-trips JSON', () {
      final now = DateTime.utc(2026, 7, 17);
      final profile = SieCalibrationProfile(
        profileId: 'p1',
        schemaVersion: kSieCalibrationSchemaVersion,
        createdAt: now,
        updatedAt: now,
        sensitivity: SieSensitivityProfileId.precision,
        user: const SieUserCalibration(armLengthScale: 1.1),
        camera: const SieCameraCalibration(offsetX: 0.02),
        display: const SieDisplayCalibration(browserZoom: 1.25),
        handedness: const SieHandednessCalibration(
          preference: SieCalibratedHandedness.left,
        ),
        interactionZone: const SieInteractionZoneCalibration(edgeMargin: 0.03),
        validated: true,
      );
      final restored = SieCalibrationProfile.fromJson(profile.toJson());
      expect(restored.profileId, 'p1');
      expect(restored.sensitivity, SieSensitivityProfileId.precision);
      expect(restored.user.armLengthScale, 1.1);
      expect(restored.camera.offsetX, 0.02);
      expect(restored.display.browserZoom, 1.25);
      expect(restored.handedness.preference, SieCalibratedHandedness.left);
      expect(restored.validated, isTrue);
    });

    test('fromJson rejects corruption', () {
      expect(
        () => SieCalibrationProfile.fromJson({'profileId': ''}),
        throwsFormatException,
      );
    });
  });

  group('SieCalibrationMigrator', () {
    test('accepts current schema', () {
      const migrator = SieCalibrationMigrator();
      final p = SieCalibrationProfile.identity(
        now: DateTime.utc(2026, 1, 1),
      );
      final out = migrator.migrate(p.toJson());
      expect(out.schemaVersion, kSieCalibrationSchemaVersion);
    });

    test('rejects future schema', () {
      const migrator = SieCalibrationMigrator();
      final raw = SieCalibrationProfile.identity(
        now: DateTime.utc(2026, 1, 1),
      ).toJson();
      raw['schemaVersion'] = 99;
      expect(() => migrator.migrate(raw), throwsFormatException);
    });
  });

  group('SieCalibrationTransformPipeline', () {
    const pipeline = SieCalibrationTransformPipeline();

    test('identity profile keeps center near center', () {
      final profile = SieCalibrationProfile.identity(
        now: DateTime.utc(2026, 1, 1),
      );
      final out = pipeline.transformLandmark(
        landmark: _lm(x: 400, y: 300),
        profile: profile,
        viewWidth: 800,
        viewHeight: 600,
        mirrorX: false,
      );
      expect(out.calibrated.x, closeTo(400, 40));
      expect(out.calibrated.y, closeTo(300, 40));
      expect(out.originalFlutter.x, 400);
    });

    test('left mirror flips X', () {
      final profile = SieCalibrationProfile.identity(
        now: DateTime.utc(2026, 1, 1),
      ).copyWith(
        isIdentity: false,
        handedness: const SieHandednessCalibration(
          preference: SieCalibratedHandedness.left,
          mirrorInteractionForLeft: true,
        ),
      );
      final hand = pipeline.transformHand(
        hand: _hand(x: 200, y: 300, handedness: SieHandedness.left),
        profile: profile,
        viewWidth: 800,
        viewHeight: 600,
      );
      expect(hand.mirrored, isTrue);
      expect(hand.resolvedHandedness, SieCalibratedHandedness.left);
      // 200 → nx 0.25 → after comfort map & mirror should move rightward
      expect(hand.indexFingertip!.calibrated.x, greaterThan(400));
    });

    test('precision vs fast gain diverge from center', () {
      final base = SieCalibrationProfile.identity(
        now: DateTime.utc(2026, 1, 1),
      );
      final tip = _lm(x: 500, y: 300);
      final precision = pipeline.transformLandmark(
        landmark: tip,
        profile: base.copyWith(sensitivity: SieSensitivityProfileId.precision),
        viewWidth: 800,
        viewHeight: 600,
        mirrorX: false,
      );
      final fast = pipeline.transformLandmark(
        landmark: tip,
        profile: base.copyWith(sensitivity: SieSensitivityProfileId.fast),
        viewWidth: 800,
        viewHeight: 600,
        mirrorX: false,
      );
      final dPrecision = (precision.calibrated.x - 400).abs();
      final dFast = (fast.calibrated.x - 400).abs();
      expect(dFast, greaterThan(dPrecision));
    });

    test('camera offset shifts normalized result', () {
      final base = SieCalibrationProfile.identity(
        now: DateTime.utc(2026, 1, 1),
      );
      final a = pipeline.transformLandmark(
        landmark: _lm(x: 400, y: 300),
        profile: base,
        viewWidth: 800,
        viewHeight: 600,
        mirrorX: false,
      );
      final b = pipeline.transformLandmark(
        landmark: _lm(x: 400, y: 300),
        profile: base.copyWith(
          camera: const SieCameraCalibration(offsetX: 0.1),
        ),
        viewWidth: 800,
        viewHeight: 600,
        mirrorX: false,
      );
      expect(a.calibrated.x, isNot(closeTo(b.calibrated.x, 1)));
    });
  });

  group('SieCalibrationEngine', () {
    late InMemoryCalibrationStore store;
    late SieCalibrationEngine engine;

    setUp(() {
      store = InMemoryCalibrationStore();
      engine = SieCalibrationEngine(
        store: store,
        logger: const NopSieCalibrationLogger(),
      );
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('first-run session completes and persists', () async {
      await engine.initialize(loadPersisted: false);
      await engine.beginSession();
      await engine.updateUserCalibration(
        const SieUserCalibration(armLengthScale: 1.2),
      );
      await engine.updateHandednessCalibration(
        const SieHandednessCalibration(
          preference: SieCalibratedHandedness.right,
        ),
      );
      // Samples inside comfort zone
      engine.recordSessionSample(const SieSpatialPoint2D(0.5, 0.5));
      engine.recordSessionSample(const SieSpatialPoint2D(0.4, 0.4));
      engine.recordSessionSample(const SieSpatialPoint2D(0.6, 0.5));
      final profile = await engine.completeSession();
      expect(profile.validated, isTrue);
      expect(profile.user.armLengthScale, 1.2);
      expect(engine.activeProfile.isIdentity, isFalse);

      final loaded = await store.loadActive();
      expect(loaded?.user.armLengthScale, 1.2);
    });

    test('load restores persisted profile', () async {
      final now = DateTime.utc(2026, 7, 1);
      await store.saveActive(
        SieCalibrationProfile.identity(now: now).copyWith(
          profileId: 'saved',
          isIdentity: false,
          validated: true,
          sensitivity: SieSensitivityProfileId.accessibility,
        ),
      );
      await engine.initialize(loadPersisted: true);
      expect(engine.activeProfile.profileId, 'saved');
      expect(
        engine.activeProfile.sensitivity,
        SieSensitivityProfileId.accessibility,
      );
      expect(engine.metrics.profileLoads, 1);
    });

    test('corrupt store falls back to identity and recommends recalibration',
        () async {
      await store.saveActiveRaw({'schemaVersion': 1, 'profileId': ''});
      await engine.initialize(loadPersisted: true);
      expect(engine.activeProfile.isIdentity, isTrue);
      expect(engine.currentStatus.recalibrationRecommended, isTrue);
      expect(
        engine.currentStatus.recalibrationReason,
        SieRecalibrationReason.missingOrCorrupt,
      );
    });

    test('reset clears persistence', () async {
      await engine.initialize(loadPersisted: false);
      await engine.applyProfile(
        SieCalibrationProfile.identity(now: DateTime.utc(2026, 1, 1)).copyWith(
          profileId: 'u',
          isIdentity: false,
          validated: true,
        ),
      );
      await engine.resetProfile();
      expect(engine.activeProfile.isIdentity, isTrue);
      expect(await store.loadActive(), isNull);
    });

    test('profile switching changes sensitivity only', () async {
      await engine.initialize(loadPersisted: false);
      await engine.setSensitivityProfile(SieSensitivityProfileId.tremorTolerant);
      expect(
        engine.activeProfile.sensitivity,
        SieSensitivityProfileId.tremorTolerant,
      );
    });

    test('preserves timestamp and confidence metadata', () async {
      await engine.initialize(loadPersisted: false);
      final ts = DateTime.utc(2026, 2, 3, 4, 5, 6);
      final out = engine.process(
        _spatial(
          timestamp: ts,
          sequence: 99,
          hands: [_hand(confidence: 0.81)],
        ),
      );
      expect(out.timestamp, ts);
      expect(out.frameSequence, 99);
      expect(out.hands.first.handConfidence, 0.81);
      expect(out.hands.first.handednessScore, 0.81);
      expect(out.calibrationVersion, kSieCalibrationSchemaVersion);
    });

    test('left/right modes resolve handedness', () async {
      await engine.initialize(loadPersisted: false);
      await engine.updateHandednessCalibration(
        const SieHandednessCalibration(
          preference: SieCalibratedHandedness.left,
          mirrorInteractionForLeft: true,
        ),
      );
      final out = engine.process(
        _spatial(hands: [_hand(handedness: SieHandedness.left, x: 200)]),
      );
      expect(out.hands.first.resolvedHandedness, SieCalibratedHandedness.left);
      expect(out.hands.first.mirrored, isTrue);
    });

    test('display scaling / browser zoom affects coordinates', () async {
      await engine.initialize(loadPersisted: false);
      final base = engine.process(_spatial(hands: [_hand(x: 500)]));
      await engine.updateDisplayCalibration(
        const SieDisplayCalibration(scaleX: 1.4, browserZoom: 1.0),
      );
      final scaled = engine.process(_spatial(hands: [_hand(x: 500)]));
      expect(
        (scaled.primaryHand!.indexFingertip!.calibrated.x - 400).abs(),
        greaterThan(
          (base.primaryHand!.indexFingertip!.calibrated.x - 400).abs(),
        ),
      );
    });

    test('window resize uses new view size', () async {
      await engine.initialize(loadPersisted: false);
      final small = engine.process(_spatial(viewW: 400, viewH: 300));
      final large = engine.process(_spatial(viewW: 1200, viewH: 900));
      expect(
        large.primaryHand!.indexFingertip!.calibrated.x,
        greaterThan(small.primaryHand!.indexFingertip!.calibrated.x),
      );
    });

    test('camera change recommends recalibration without mutating profile',
        () async {
      await engine.initialize(loadPersisted: false);
      final before = engine.activeProfile;
      engine.notifyEnvironmentChange(SieRecalibrationReason.cameraChanged);
      expect(engine.currentStatus.recalibrationRecommended, isTrue);
      expect(identical(engine.activeProfile, before) ||
          engine.activeProfile.profileId == before.profileId, isTrue);
      expect(
        engine.activeProfile.updatedAt,
        before.updatedAt,
      );
    });

    test('identical input yields identical output', () async {
      await engine.initialize(loadPersisted: false);
      await engine.setSensitivityProfile(SieSensitivityProfileId.standard);
      final input = _spatial(hands: [_hand(x: 350, y: 280)]);
      final a = engine.process(input);
      final b = engine.process(input);
      expect(
        a.primaryHand!.indexFingertip!.calibrated.x,
        b.primaryHand!.indexFingertip!.calibrated.x,
      );
      expect(
        a.primaryHand!.indexFingertip!.calibrated.y,
        b.primaryHand!.indexFingertip!.calibrated.y,
      );
    });

    test('stream start emits calibrated snapshots', () async {
      await engine.initialize(loadPersisted: false);
      final controller = StreamController<SieSpatialFrameSnapshot>();
      final received = <SieCalibratedFrameSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      await engine.start(controller.stream);
      controller.add(_spatial());
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.first.hasHand, isTrue);
      await engine.stop();
      await sub.cancel();
      await controller.close();
    });

    test('performance: 500 frames under soft budget', () async {
      await engine.initialize(loadPersisted: false);
      final input = _spatial();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        engine.process(input);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(engine.metrics.averageProcessingMs, lessThan(5));
    });

    test('cancel session does not apply draft', () async {
      await engine.initialize(loadPersisted: false);
      await engine.beginSession();
      await engine.updateUserCalibration(
        const SieUserCalibration(armLengthScale: 2.0),
      );
      await engine.cancelSession();
      expect(engine.activeProfile.user.armLengthScale, 1.0);
    });

    test('partial recalibration updates subset', () async {
      await engine.initialize(loadPersisted: false);
      await engine.beginSession(
        phase: SieCalibrationSessionPhase.partialRecalibration,
      );
      await engine.updateCameraCalibration(
        const SieCameraCalibration(anglePitchDegrees: 8),
      );
      engine.recordSessionSample(const SieSpatialPoint2D(0.5, 0.5));
      engine.recordSessionSample(const SieSpatialPoint2D(0.45, 0.5));
      engine.recordSessionSample(const SieSpatialPoint2D(0.55, 0.48));
      final p = await engine.completeSession();
      expect(p.camera.anglePitchDegrees, 8);
    });
  });
}
