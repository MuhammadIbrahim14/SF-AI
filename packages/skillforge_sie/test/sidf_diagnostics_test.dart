import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

final class _CapturingSidfLogger implements SidfLogger {
  final List<Map<String, Object?>> payloads = [];

  @override
  void log(
    SidfLogLevel level,
    String event, [
    Map<String, Object?>? data,
  ]) {
    final safe = <String, Object?>{};
    if (data != null) {
      for (final e in data.entries) {
        final k = e.key.toLowerCase();
        if (k.contains('framebytes') ||
            k.contains('imagebytes') ||
            k.contains('pixels') ||
            k.contains('yuv') ||
            k == 'rgba' ||
            k.contains('rawframe')) {
          continue;
        }
        safe[e.key] = e.value;
      }
    }
    payloads.add({'event': event, ...safe});
  }
}

SidfDiagnosticsFramework _sidf({
  SidfFeatureFlags? flags,
  SidfLogger? logger,
}) {
  return SidfDiagnosticsFramework(
    flags: flags ?? SidfFeatureFlags.debugAll,
    logger: logger ?? const NopSidfLogger(),
  );
}

void main() {
  group('SIDF — feature flags', () {
    test('disabled profile observes nothing', () async {
      final sidf = _sidf(flags: SidfFeatureFlags.disabled);
      await sidf.initialize();
      expect(sidf.flags.isObserving, isFalse);
      expect(sidf.currentStatus.enabled, isFalse);

      sidf.recordTimeline(
        SidfTimelineEvent(
          timestamp: DateTime.utc(2026, 7, 17),
          category: SidfTimelineCategory.lifecycle,
          name: 'camera_started',
        ),
      );
      expect(sidf.timeline, isEmpty);
      await sidf.dispose();
    });

    test('debugAll enables observation; recording remains opt-in by default profile',
        () {
      expect(SidfFeatureFlags.debugAll.frameworkEnabled, isTrue);
      expect(SidfFeatureFlags.debugAll.overlay, isTrue);
      final profile = SidfFeatureFlags.forBuildMode(forceEnable: true);
      expect(profile.frameworkEnabled, isTrue);
      expect(profile.recording, isFalse);
    });
  });

  group('SIDF — overlay lifecycle', () {
    test('overlay visibility gated by flags', () async {
      final sidf = _sidf(
        flags: SidfFeatureFlags.debugAll.copyWith(overlay: true),
      );
      await sidf.initialize();
      expect(sidf.currentStatus.overlayVisible, isTrue);

      await sidf.setOverlayVisible(false);
      expect(sidf.currentStatus.overlayVisible, isFalse);

      await sidf.setFlags(SidfFeatureFlags.disabled);
      await sidf.setOverlayVisible(true);
      expect(sidf.currentStatus.overlayVisible, isFalse);
      await sidf.dispose();
    });

    testWidgets('overlay paints HUD when visible', (tester) async {
      final snap = SidfDiagnosticsSnapshot.empty(DateTime.utc(2026, 7, 17));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidfDebugOverlay(
              snapshot: snap,
              visible: true,
              flags: SidfFeatureFlags.debugAll,
            ),
          ),
        ),
      );
      expect(find.text('SIDF'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidfDebugOverlay(
              snapshot: snap,
              visible: false,
              flags: SidfFeatureFlags.debugAll,
            ),
          ),
        ),
      );
      expect(find.text('SIDF'), findsNothing);
    });
  });

  group('SIDF — metrics & timeline', () {
    test('rolling average and stage latencies are accurate', () async {
      final sidf = _sidf();
      await sidf.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      sidf.noteCameraFrame(t0);
      sidf.noteCameraFrame(t0.add(const Duration(milliseconds: 40)));
      sidf.noteVisionFrame(t0);
      sidf.noteVisionFrame(t0.add(const Duration(milliseconds: 50)));
      sidf.noteUiFps(60);
      sidf.noteEndToEndLatency(10);
      sidf.noteEndToEndLatency(20);
      sidf.ingestStage(
        SidfStageSample(
          stage: SidfPipelineStage.gesture,
          health: SidfStageHealth.healthy,
          timestamp: t0,
          processingMs: 4.5,
        ),
      );
      final snap = sidf.publish();
      expect(snap.performance.averageEndToEndMs, closeTo(15, 0.01));
      expect(snap.performance.endToEndMs, 20);
      expect(snap.performance.cameraFps, closeTo(25, 0.1));
      expect(snap.performance.visionFps, closeTo(20, 0.1));
      expect(snap.performance.uiFps, 60);
      expect(
        snap.stages[SidfPipelineStage.gesture]?.processingMs,
        4.5,
      );
      expect(
        snap.performance.stageLatenciesMs[SidfPipelineStage.gesture],
        4.5,
      );
      await sidf.dispose();
    });

    test('timeline preserves chronological order', () async {
      final sidf = _sidf();
      await sidf.initialize();
      final names = [
        'camera_started',
        'hand_detected',
        'tracking_stable',
        'pinch_armed',
        'pinch_commit',
        'pointer_down',
        'button_activated',
        'release',
      ];
      var i = 0;
      for (final name in names) {
        sidf.recordTimeline(
          SidfTimelineEvent(
            timestamp: DateTime.utc(2026, 7, 17, 12, 0, i++),
            category: SidfTimelineCategory.gesture,
            name: name,
          ),
        );
      }
      expect(sidf.timeline.map((e) => e.name).toList(), names);
      await sidf.dispose();
    });
  });

  group('SIDF — recording & exports', () {
    test('recording lifecycle without raw camera frames', () async {
      final sidf = _sidf(
        flags: SidfFeatureFlags.debugAll.copyWith(recording: true),
      );
      await sidf.initialize();
      await sidf.startRecording();
      expect(sidf.currentStatus.recording, isTrue);
      expect(sidf.currentStatus.health, SidfFrameworkHealth.recording);

      sidf.ingestCursor(
        SidfCursorDebug(
          timestamp: DateTime.utc(2026, 7, 17),
          position: const SieSpatialPoint2D(10, 20),
          state: 'hovering',
        ),
      );
      sidf.ingestGesture(
        SidfGestureDebug(
          timestamp: DateTime.utc(2026, 7, 17),
          primary: 'pinchSelect',
          confidence: 0.9,
        ),
      );
      sidf.publish();

      final session = await sidf.stopRecording();
      expect(session, isNotNull);
      expect(session!.isActive, isFalse);
      final json = session.toJson();
      expect(json['privacy'], isA<Map>());
      final privacy = json['privacy']! as Map;
      expect(privacy['rawCameraFrames'], isFalse);
      expect(json.containsKey('frames'), isFalse);
      expect(json.containsKey('images'), isFalse);
      expect(sidf.currentStatus.recording, isFalse);
      await sidf.dispose();
    });

    test('recording rejected when flag off', () async {
      final sidf = _sidf(
        flags: SidfFeatureFlags.debugAll.copyWith(recording: false),
      );
      await sidf.initialize();
      expect(
        () => sidf.startRecording(),
        throwsA(isA<SieDiagnosticsFailure>()),
      );
      await sidf.dispose();
    });

    test('exports JSON / CSV / health report', () async {
      final sidf = _sidf();
      await sidf.initialize();
      sidf.ingestIntent('select');
      sidf.ingestOwner('sie');
      sidf.ingestConfidence(0.88);
      sidf.ingestStage(
        SidfStageSample(
          stage: SidfPipelineStage.camera,
          health: SidfStageHealth.healthy,
          timestamp: DateTime.utc(2026, 7, 17),
          processingMs: 2,
          label: 'ok',
        ),
      );
      sidf.noteEndToEndLatency(12);
      sidf.recordTimeline(
        SidfTimelineEvent(
          timestamp: DateTime.utc(2026, 7, 17),
          category: SidfTimelineCategory.lifecycle,
          name: 'camera_started',
        ),
      );
      sidf.publish();

      final json = sidf.exportJson();
      expect(json['type'], 'sidf.diagnostics');
      expect((json['privacy'] as Map)['rawCameraFrames'], isFalse);
      final snap = json['snapshot'] as Map;
      expect(snap['intent'], 'select');
      expect(snap['owner'], 'sie');
      expect(snap['confidence'], 0.88);

      final csv = sidf.exportPerformanceCsv();
      expect(csv.split('\n').first, contains('endToEndMs'));
      expect(csv.contains('12'), isTrue);

      final timelineCsv = sidf.exportTimelineCsv();
      expect(timelineCsv.contains('camera_started'), isTrue);

      final health = sidf.exportHealthReport();
      expect(health.contains('SIDF System Health Report'), isTrue);
      expect(health.contains('camera'), isTrue);
      await sidf.dispose();
    });
  });

  group('SIDF — privacy & overhead', () {
    test('logger strips raw frame keys', () {
      final logger = _CapturingSidfLogger();
      logger.log(SidfLogLevel.info, 'probe', {
        'ok': 1,
        'frameBytes': [1, 2, 3],
        'rawFrame': 'secret',
        'imageBytes': 'x',
      });
      expect(logger.payloads.single.containsKey('ok'), isTrue);
      expect(logger.payloads.single.containsKey('frameBytes'), isFalse);
      expect(logger.payloads.single.containsKey('rawFrame'), isFalse);
      expect(logger.payloads.single.containsKey('imageBytes'), isFalse);
    });

    test('disabled framework has near-zero ingest side effects', () async {
      final sidf = _sidf(flags: SidfFeatureFlags.disabled);
      await sidf.initialize();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5000; i++) {
        sidf.ingestStage(
          SidfStageSample(
            stage: SidfPipelineStage.vision,
            health: SidfStageHealth.healthy,
            timestamp: DateTime.utc(2026, 7, 17),
            processingMs: 1,
          ),
        );
        sidf.ingestIntent('select');
        sidf.noteEndToEndLatency(5);
      }
      sw.stop();
      expect(sidf.timeline, isEmpty);
      expect(sidf.latestSnapshot.intent, isNull);
      // Guardrail: 5k no-op ingests should stay well under 200ms on CI.
      expect(sw.elapsedMilliseconds, lessThan(200));
      await sidf.dispose();
    });

    test('pipeline inspector reflects all stages', () async {
      final sidf = _sidf();
      await sidf.initialize();
      final now = DateTime.utc(2026, 7, 17);
      for (final stage in SidfPipelineStage.values) {
        sidf.ingestStage(
          SidfStageSample(
            stage: stage,
            health: SidfStageHealth.healthy,
            timestamp: now,
            processingMs: 1,
          ),
        );
      }
      final snap = sidf.publish();
      expect(snap.stages.length, SidfPipelineStage.values.length);
      expect(
        snap.stages.values.every((s) => s.health == SidfStageHealth.healthy),
        isTrue,
      );
      await sidf.dispose();
    });
  });

  group('SIDF — visualization helpers', () {
    test('hand topology includes fingertips and bones', () {
      expect(SidfHandTopology.fingertips, containsAll([4, 8, 12, 16, 20]));
      expect(SidfHandTopology.bones, isNotEmpty);
      expect(sidfEstimateCpuLoad(averageEndToEndMs: 8.0), lessThan(1));
      expect(sidfEstimateCpuLoad(averageEndToEndMs: 33.0), 1.0);
    });
  });
}
