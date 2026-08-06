import 'dart:async';

import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';

/// Broadcasts frames with latest-only back-pressure.
///
/// Purpose: avoid unbounded queues when vision is slower than capture.
final class SieCameraStreamManager {
  /// Creates a stream manager.
  SieCameraStreamManager({this.maxQueuedFrames = 1});

  /// Max pending frames before drops (typically 1).
  final int maxQueuedFrames;

  final StreamController<SieCameraFrame> _controller =
      StreamController<SieCameraFrame>.broadcast();

  int _sequence = 0;
  int _dropped = 0;
  int _emitted = 0;
  bool _busy = false;
  SieCameraFrame? _pending;

  /// Frame stream for consumers.
  Stream<SieCameraFrame> get stream => _controller.stream;

  /// Dropped frame count since [resetCounters].
  int get droppedFrames => _dropped;

  /// Emitted frame count since [resetCounters].
  int get emittedFrames => _emitted;

  /// Resets counters (e.g. on start).
  void resetCounters() {
    _dropped = 0;
    _emitted = 0;
    _sequence = 0;
    _pending = null;
    _busy = false;
  }

  /// Enqueues a frame; drops older pending frames under load.
  void publish(SieCameraFrame frame) {
    if (_controller.isClosed) return;

    final tagged = SieCameraFrame(
      timestamp: frame.timestamp,
      width: frame.width,
      height: frame.height,
      format: frame.format,
      planes: frame.planes,
      rotationDegrees: frame.rotationDegrees,
      cameraId: frame.cameraId,
      sequence: ++_sequence,
      platformImage: frame.platformImage,
    );

    if (maxQueuedFrames <= 1) {
      if (_busy) {
        _dropped++;
        _pending = tagged;
        return;
      }
      _emit(tagged);
      return;
    }

    // Bounded queue depth > 1: keep only the newest overflow.
    if (_busy) {
      _dropped++;
      _pending = tagged;
      return;
    }
    _emit(tagged);
  }

  void _emit(SieCameraFrame frame) {
    _busy = true;
    _emitted++;
    try {
      _controller.add(frame);
    } finally {
      _busy = false;
      final pending = _pending;
      if (pending != null) {
        _pending = null;
        // Schedule microtask to avoid deep recursion under burst.
        scheduleMicrotask(() => publish(pending));
      }
    }
  }

  /// Closes the broadcast stream.
  Future<void> dispose() async {
    _pending = null;
    await _controller.close();
  }
}
