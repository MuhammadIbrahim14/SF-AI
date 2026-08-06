import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('SieLatencyStats', () {
    test('empty samples → empty distribution', () {
      expect(SieLatencyStats.fromSamples(const []), SieLatencyDistribution.empty);
    });

    test('computes avg / median / p95 / p99 / min / max', () {
      final samples = List<double>.generate(100, (i) => i.toDouble());
      final d = SieLatencyStats.fromSamples(samples);
      expect(d.count, 100);
      expect(d.minMs, 0);
      expect(d.maxMs, 99);
      expect(d.averageMs, closeTo(49.5, 0.01));
      expect(d.medianMs, closeTo(49.5, 0.01));
      expect(d.p95Ms, greaterThan(d.medianMs));
      expect(d.p99Ms, greaterThanOrEqualTo(d.p95Ms));
      expect(d.p99Ms, lessThanOrEqualTo(d.maxMs));
    });
  });

  group('SIDF telemetry percentiles', () {
    test('aggregator exposes p95/p99 on snapshot', () {
      final agg = SidfTelemetryAggregator(windowSize: 20);
      for (var i = 1; i <= 20; i++) {
        agg.noteEndToEnd(i.toDouble());
        agg.noteStage(SidfPipelineStage.gesture, i * 0.1);
      }
      final snap = agg.snapshot(DateTime.utc(2026, 7, 17));
      expect(snap.averageEndToEndMs, closeTo(10.5, 0.01));
      expect(snap.medianEndToEndMs, greaterThan(0));
      expect(snap.p95EndToEndMs, greaterThan(snap.medianEndToEndMs));
      expect(snap.p99EndToEndMs, greaterThanOrEqualTo(snap.p95EndToEndMs));
      expect(snap.minEndToEndMs, 1);
      expect(snap.maxEndToEndMs, 20);
      expect(snap.stageLatenciesMs[SidfPipelineStage.gesture], isNotNull);
    });

    test('timeline ring buffer drops oldest in O(1) path', () {
      final tl = SidfEventTimeline(capacity: 8);
      for (var i = 0; i < 20; i++) {
        tl.add(
          SidfTimelineEvent(
            timestamp: DateTime.utc(2026, 7, 17, 0, 0, i),
            category: SidfTimelineCategory.lifecycle,
            name: 'e$i',
          ),
        );
      }
      expect(tl.length, 8);
      expect(tl.events.first.name, 'e12');
      expect(tl.events.last.name, 'e19');
    });
  });
}
