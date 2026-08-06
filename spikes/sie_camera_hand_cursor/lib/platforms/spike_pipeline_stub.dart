import 'package:flutter/widgets.dart';
import 'package:sie_camera_hand_cursor/platforms/spike_pipeline.dart';

SpikePipeline createPlatformSpikePipeline() => _StubPipeline();

class _StubPipeline implements SpikePipeline {
  @override
  String get platformId => 'stub';

  @override
  void Function()? onFrameCaptured;

  @override
  Widget? buildPreview(BuildContext context) => null;

  @override
  Future<void> start({required HandSampleCallback onSample}) async {
    throw UnsupportedError('No platform pipeline bound.');
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
