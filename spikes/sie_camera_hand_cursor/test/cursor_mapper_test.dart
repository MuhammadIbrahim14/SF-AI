import 'package:flutter_test/flutter_test.dart';
import 'package:sie_camera_hand_cursor/pipeline/cursor_mapper.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';

void main() {
  test('CursorMapper mirrors X and smooths toward target', () {
    final mapper = CursorMapper(smoothing: 1.0, mirrorX: true);
    final sample = SpikeHandSample(
      detected: true,
      confidence: 0.9,
      landmarks: List.generate(
        21,
        (i) => SpikeLandmark(x: i == 8 ? 0.25 : 0.5, y: 0.4, z: 0),
      ),
      inferMs: 10,
      timestampMs: 0,
    );

    final a = mapper.update(sample: sample, screenW: 1000, screenH: 800);
    expect(a.visible, isTrue);
    // mirrored: 1 - 0.25 = 0.75 → near 750 after inset mapping
    expect(a.x, greaterThan(700));
    expect(a.x, lessThan(800));
    expect(mapper.state, TrackingState.tracking);
  });

  test('CursorMapper enters recovering then lost after absence', () async {
    final mapper = CursorMapper(smoothing: 1.0);
    final present = SpikeHandSample(
      detected: true,
      confidence: 0.9,
      landmarks: List.generate(21, (_) => const SpikeLandmark(x: 0.5, y: 0.5, z: 0)),
      inferMs: 5,
      timestampMs: 0,
    );
    mapper.update(sample: present, screenW: 800, screenH: 600);

    final absent = SpikeHandSample(
      detected: false,
      confidence: 0,
      landmarks: const [],
      inferMs: 5,
      timestampMs: 0,
    );
    mapper.update(sample: absent, screenW: 800, screenH: 600);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    mapper.update(sample: absent, screenW: 800, screenH: 600);
    expect(
      mapper.state == TrackingState.recovering || mapper.state == TrackingState.lost,
      isTrue,
    );
  });
}
