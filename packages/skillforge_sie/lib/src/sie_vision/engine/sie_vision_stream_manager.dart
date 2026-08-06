import 'dart:async';

import 'package:skillforge_sie/src/sie_vision/models/sie_vision_result.dart';

/// Broadcasts vision results; drops when consumers/backends are saturated.
final class SieVisionStreamManager {
  /// Creates the manager.
  SieVisionStreamManager();

  final StreamController<SieVisionResult> _controller =
      StreamController<SieVisionResult>.broadcast();

  /// Result stream.
  Stream<SieVisionResult> get stream => _controller.stream;

  /// Publishes a result if the controller is open.
  void publish(SieVisionResult result) {
    if (_controller.isClosed) return;
    _controller.add(result);
  }

  /// Closes the stream.
  Future<void> dispose() => _controller.close();
}
