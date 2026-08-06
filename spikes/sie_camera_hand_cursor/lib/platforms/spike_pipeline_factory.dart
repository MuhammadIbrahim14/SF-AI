import 'package:sie_camera_hand_cursor/platforms/spike_pipeline.dart';
import 'package:sie_camera_hand_cursor/platforms/spike_pipeline_stub.dart'
    if (dart.library.html) 'package:sie_camera_hand_cursor/platforms/spike_pipeline_web.dart'
    if (dart.library.io) 'package:sie_camera_hand_cursor/platforms/spike_pipeline_io.dart';

SpikePipeline createSpikePipeline() => createPlatformSpikePipeline();
