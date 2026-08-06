import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieIntentEvent _ie({
  required SieIntentKind kind,
  SieIntentPhase phase = SieIntentPhase.active,
  SieSpatialPoint2D? position,
  SieTrackingReliabilityState tracking = SieTrackingReliabilityState.stable,
  int sequence = 1,
  String? targetId,
  double progress = 0,
  DateTime? timestamp,
}) {
  return SieIntentEvent(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    kind: kind,
    phase: phase,
    sourceGesture: SieGestureKind.openHandPoint,
    confidence: 0.95,
    trackingState: tracking,
    securityLevel: SieSecurityLevel.l1Standard,
    routeKind: SieRouteCapabilityKind.dashboard,
    policyId: SieIntentPolicyId.standard,
    position: position,
    targetId: targetId,
    progress: progress,
  );
}

SieIntentFrameSnapshot _if({
  List<SieIntentEvent> events = const [],
  SieInteractionMode mode = SieInteractionMode.moving,
  int sequence = 1,
  DateTime? timestamp,
}) {
  return SieIntentFrameSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    mode: mode,
    events: events,
    processingMs: 0.2,
    securityLevel: SieSecurityLevel.l1Standard,
    routeKind: SieRouteCapabilityKind.dashboard,
    policyId: SieIntentPolicyId.standard,
    primaryKind: events.isEmpty ? null : events.first.kind,
  );
}

SieVirtualCursorEngine _engine({SieCursorEngineConfig? config}) {
  return SieVirtualCursorEngine(
    config: config ??
        const SieCursorEngineConfig(
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
        ),
    logger: const NopSieCursorLogger(),
  );
}

void main() {
  group('Virtual Cursor — motion filtering', () {
    test('EMA smooths jittery path toward mean', () async {
      final engine = _engine(
        config: const SieCursorEngineConfig(
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
          motion: SieCursorMotionConfig(
            predictionEnabled: false,
            accelerationGain: 1,
            edgeResistance: 0,
          ),
        ),
      );
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      SieCursorSnapshot? last;
      for (var i = 0; i < 20; i++) {
        final jitter = (i.isEven ? 2.0 : -2.0);
        last = engine.process(
          _if(
            sequence: i,
            timestamp: t0.add(Duration(milliseconds: 16 * i)),
            events: [
              _ie(
                kind: SieIntentKind.moveCursor,
                position: SieSpatialPoint2D(400 + jitter, 300),
                sequence: i,
                timestamp: t0.add(Duration(milliseconds: 16 * i)),
              ),
            ],
          ),
        );
      }
      expect(last, isNotNull);
      expect((last!.position.x - 400).abs(), lessThan(5));
      expect(last.smoothingAlpha, greaterThan(0));
      await engine.dispose();
    });

    test('Invalid NaN coordinates do not corrupt position', () async {
      final engine = _engine();
      await engine.initialize();
      final ok = engine.process(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(100, 100),
            ),
          ],
        ),
      );
      final bad = engine.process(
        _if(
          sequence: 2,
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(double.nan, 100),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(ok.position.x.isFinite, isTrue);
      expect(bad.position.x.isFinite, isTrue);
      expect(bad.position.x, closeTo(ok.position.x, 50));
      await engine.dispose();
    });
  });

  group('Virtual Cursor — prediction', () {
    test('Prediction disabled during recovering', () async {
      final engine = _engine();
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      // Build velocity first.
      for (var i = 0; i < 5; i++) {
        engine.process(
          _if(
            sequence: i,
            timestamp: t0.add(Duration(milliseconds: 16 * i)),
            events: [
              _ie(
                kind: SieIntentKind.moveCursor,
                position: SieSpatialPoint2D(100.0 + i * 10, 200),
                sequence: i,
                timestamp: t0.add(Duration(milliseconds: 16 * i)),
              ),
            ],
          ),
        );
      }
      final recovering = engine.process(
        _if(
          sequence: 10,
          timestamp: t0.add(const Duration(milliseconds: 200)),
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(160, 200),
              tracking: SieTrackingReliabilityState.recovering,
              sequence: 10,
              timestamp: t0.add(const Duration(milliseconds: 200)),
            ),
          ],
        ),
      );
      expect(recovering.state, SieCursorState.recovering);
      expect(recovering.predictionOffset, SieSpatialPoint2D.zero);
      await engine.dispose();
    });

    test('Prediction clamps magnitude', () {
      const predictor = SieCursorPredictor();
      final offset = predictor.predict(
        velocity: const SieSpatialPoint2D(5, 0), // 5 px/ms * 24ms = 120
        config: const SieCursorMotionConfig(
          predictionHorizonMs: 24,
          maxPredictionPx: 12,
        ),
        enabled: true,
      );
      final mag = offset.x.abs();
      expect(mag, lessThanOrEqualTo(12.01));
    });
  });

  group('Virtual Cursor — acceleration & snap', () {
    test('Fast gain reduced while armed', () {
      const accel = SieCursorAccelerator();
      const from = SieSpatialPoint2D(0, 0);
      const to = SieSpatialPoint2D(100, 0);
      final armed = accel.applyGain(
        from: from,
        to: to,
        config: SieCursorMotionConfig.fast,
        profile: SieCursorMotionProfileId.fast,
        armed: true,
      );
      final free = accel.applyGain(
        from: from,
        to: to,
        config: SieCursorMotionConfig.fast,
        profile: SieCursorMotionProfileId.fast,
        armed: false,
      );
      expect(free.x, greaterThan(armed.x));
      expect(armed.x, closeTo(100, 0.01));
      expect(free.x, closeTo(135, 0.01));
    });

    test('Snap soft-pulls without teleport', () async {
      final engine = _engine();
      await engine.initialize();
      await engine.setSnapTargets([
        const SieCursorSnapTarget(
          id: 'btn',
          center: SieSpatialPoint2D(400, 300),
          radius: 40,
        ),
      ]);
      final snap = engine.process(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(390, 300),
            ),
          ],
        ),
      );
      expect(snap.snapped, isTrue);
      expect(snap.snapTargetId, 'btn');
      // Must not jump exactly to center in one frame with strength < 1.
      expect(snap.position.x, isNot(400));
      expect((snap.position.x - 400).abs(), lessThan(20));
      await engine.dispose();
    });

    test('Security-sensitive route disables snap', () async {
      final engine = _engine(
        config: const SieCursorEngineConfig(
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
          securitySensitiveRoute: true,
        ),
      );
      await engine.initialize();
      await engine.setSnapTargets([
        const SieCursorSnapTarget(
          id: 'btn',
          center: SieSpatialPoint2D(400, 300),
        ),
      ]);
      final snap = engine.process(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(390, 300),
            ),
          ],
        ),
      );
      expect(snap.snapped, isFalse);
      expect(snap.metadata['snapAllowed'], isFalse);
      await engine.dispose();
    });
  });

  group('Virtual Cursor — bounds & visibility', () {
    test('Clamps to display bounds', () async {
      final engine = _engine(
        config: const SieCursorEngineConfig(
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
          motion: SieCursorMotionConfig(edgeResistance: 0),
        ),
      );
      await engine.initialize();
      final snap = engine.process(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(9999, -50),
            ),
          ],
        ),
      );
      expect(snap.position.x, lessThanOrEqualTo(800));
      expect(snap.position.y, greaterThanOrEqualTo(0));
      expect(engine.metrics.clampEvents, greaterThan(0));
      await engine.dispose();
    });

    test('Multi-resolution resize updates clamp', () async {
      final engine = _engine();
      await engine.initialize();
      await engine.setDisplayBounds(
        const SieCursorDisplayBounds(width: 400, height: 300, devicePixelRatio: 2),
      );
      final snap = engine.process(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(500, 100),
            ),
          ],
        ),
      );
      expect(snap.position.x, lessThanOrEqualTo(400));
      await engine.dispose();
    });

    test('LostTracking fades cursor', () async {
      final engine = _engine();
      await engine.initialize();
      engine.process(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(200, 200),
            ),
          ],
        ),
      );
      final lost = engine.process(
        _if(
          sequence: 2,
          mode: SieInteractionMode.blocked,
          events: [
            _ie(
              kind: SieIntentKind.cancel,
              tracking: SieTrackingReliabilityState.lostTracking,
              sequence: 2,
            ),
          ],
        ),
      );
      expect(lost.state, SieCursorState.lostTracking);
      expect(lost.visibility, SieCursorVisibilityMode.faded);
      expect(lost.opacity, lessThan(1));
      await engine.dispose();
    });

    test('Paused sets paused state', () async {
      final engine = _engine();
      await engine.initialize();
      final snap = engine.process(
        _if(
          mode: SieInteractionMode.paused,
          events: [
            _ie(kind: SieIntentKind.pauseSie, phase: SieIntentPhase.completed),
          ],
        ),
      );
      expect(snap.state, SieCursorState.paused);
      await engine.dispose();
    });
  });

  group('Virtual Cursor — states & themes', () {
    test('Moving / hovering / pressed / dragging states', () async {
      final engine = _engine();
      await engine.initialize();
      final moving = engine.process(
        _if(
          mode: SieInteractionMode.moving,
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(10, 10),
            ),
          ],
        ),
      );
      expect(moving.state, SieCursorState.moving);

      final hovering = engine.process(
        _if(
          sequence: 2,
          mode: SieInteractionMode.hovering,
          events: [
            _ie(
              kind: SieIntentKind.hoverEnter,
              targetId: 'a',
              position: const SieSpatialPoint2D(20, 20),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(hovering.state, SieCursorState.hovering);
      expect(hovering.hoverTargetId, 'a');

      final pressed = engine.process(
        _if(
          sequence: 3,
          mode: SieInteractionMode.selecting,
          events: [
            _ie(
              kind: SieIntentKind.select,
              phase: SieIntentPhase.active,
              position: const SieSpatialPoint2D(20, 20),
              sequence: 3,
            ),
          ],
        ),
      );
      expect(pressed.state, SieCursorState.pressed);

      final dragging = engine.process(
        _if(
          sequence: 4,
          mode: SieInteractionMode.dragging,
          events: [
            _ie(
              kind: SieIntentKind.updateDrag,
              position: const SieSpatialPoint2D(40, 30),
              sequence: 4,
            ),
          ],
        ),
      );
      expect(dragging.state, SieCursorState.dragging);
      await engine.dispose();
    });

    test('Theme change does not alter position behaviour', () async {
      final standard = _engine(
        config: const SieCursorEngineConfig(
          theme: SieCursorThemeId.standard,
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
          motion: SieCursorMotionConfig(predictionEnabled: false),
        ),
      );
      final a11y = _engine(
        config: const SieCursorEngineConfig(
          theme: SieCursorThemeId.accessibility,
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
          motion: SieCursorMotionConfig(predictionEnabled: false),
        ),
      );
      await standard.initialize();
      await a11y.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      SieCursorSnapshot? sa;
      SieCursorSnapshot? sb;
      for (var i = 0; i < 5; i++) {
        final frame = _if(
          sequence: i,
          timestamp: t0.add(Duration(milliseconds: 16 * i)),
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: SieSpatialPoint2D(50.0 + i, 50),
              sequence: i,
              timestamp: t0.add(Duration(milliseconds: 16 * i)),
            ),
          ],
        );
        sa = standard.process(frame);
        sb = a11y.process(frame);
      }
      expect(sb!.theme, SieCursorThemeId.accessibility);
      expect(sa!.theme, SieCursorThemeId.standard);
      // Same motion config → same filtered path; theme is appearance-only.
      expect(sa.position, sb.position);
      await standard.dispose();
      await a11y.dispose();
    });

    test('Reduced motion keeps animation phase at 0', () async {
      final engine = _engine(
        config: const SieCursorEngineConfig(
          bounds: SieCursorDisplayBounds(width: 800, height: 600),
          motion: SieCursorMotionConfig(reducedMotion: true),
        ),
      );
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      SieCursorSnapshot? last;
      for (var i = 0; i < 5; i++) {
        last = engine.process(
          _if(
            sequence: i,
            mode: SieInteractionMode.hovering,
            timestamp: t0.add(Duration(milliseconds: 50 * i)),
            events: [
              _ie(
                kind: SieIntentKind.hoverEnter,
                targetId: 'x',
                position: const SieSpatialPoint2D(100, 100),
                sequence: i,
                timestamp: t0.add(Duration(milliseconds: 50 * i)),
              ),
            ],
          ),
        );
      }
      expect(last!.animationPhase, 0);
      await engine.dispose();
    });
  });

  group('Virtual Cursor — determinism & performance', () {
    test('Identical inputs yield identical positions', () async {
      final a = _engine();
      final b = _engine();
      await a.initialize();
      await b.initialize();
      final frame = _if(
        events: [
          _ie(
            kind: SieIntentKind.moveCursor,
            position: const SieSpatialPoint2D(123, 456),
          ),
        ],
      );
      final sa = a.process(frame);
      final sb = b.process(frame);
      expect(sa.position, sb.position);
      expect(sa.state, sb.state);
      await a.dispose();
      await b.dispose();
    });

    test('200 frames under soft budget', () async {
      final engine = _engine();
      await engine.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        engine.process(
          _if(
            sequence: i,
            timestamp: t0.add(Duration(milliseconds: 16 * i)),
            events: [
              _ie(
                kind: SieIntentKind.moveCursor,
                position: SieSpatialPoint2D(100 + i * 0.5, 200),
                sequence: i,
                timestamp: t0.add(Duration(milliseconds: 16 * i)),
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
      final controller = StreamController<SieIntentFrameSnapshot>();
      final received = <SieCursorSnapshot>[];
      final sub = engine.snapshots.listen(received.add);
      await engine.start(controller.stream);
      controller.add(
        _if(
          events: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(10, 10),
            ),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isNotEmpty);
      expect(received.first.position.x.isFinite, isTrue);
      await sub.cancel();
      await controller.close();
      await engine.dispose();
    });
  });
}
