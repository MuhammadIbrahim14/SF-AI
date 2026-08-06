import 'package:flutter/widgets.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';

typedef HandSampleCallback = void Function(SpikeHandSample sample);

/// Disposable spike pipeline — camera + landmarks. Not production SIE.
abstract class SpikePipeline {
  String get platformId;

  /// Fired when a camera frame is accepted into the vision path (Android).
  void Function()? onFrameCaptured;

  /// Optional camera preview widget (Android). Web uses DOM PiP.
  Widget? buildPreview(BuildContext context);

  Future<void> start({required HandSampleCallback onSample});

  Future<void> stop();

  void dispose();
}
