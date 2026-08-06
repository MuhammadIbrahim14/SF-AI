import 'package:skillforge_sie/src/sie_camera/logging/sie_camera_logger.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Classifies and logs camera failures for recovery decisions.
final class SieCameraErrorManager {
  /// Creates the error manager.
  SieCameraErrorManager({required SieCameraLogger logger}) : _logger = logger;

  final SieCameraLogger _logger;

  /// Wraps an unknown error into a [SieFailure].
  SieFailure wrap(Object error, {String event = 'camera_error'}) {
    _logger.error(event, {'type': error.runtimeType.toString()}, error);
    if (error is SieFailure) return error;
    return SieCameraEngineFailure(
      code: 'sie.camera.runtime',
      message: error.toString(),
      cause: error,
    );
  }

  /// Whether [failure] suggests a full re-initialize may help.
  bool shouldReinitialize(SieFailure failure) {
    return failure.code == 'sie.camera.runtime' ||
        failure.code == 'sie.camera.unavailable' ||
        failure is SieCameraUnavailableFailure;
  }

  /// Whether permission-related.
  bool isPermissionFailure(SieFailure failure) {
    return failure is SiePermissionDeniedFailure ||
        failure.code.startsWith('sie.permission');
  }
}
