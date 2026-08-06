import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_platform/models/sie_unsupported_reason.dart';

/// Base type for recoverable SIE platform failures.
///
/// Failures must not crash the host app (fail-open for core SkillForge product).
sealed class SieFailure implements Exception {
  /// Creates a failure with a stable [code] and human [message].
  SieFailure({required this.code, required this.message});

  /// Stable machine-readable code (e.g. `sie.platform.unsupported`).
  final String code;

  /// Human-readable summary for logs / host UX (not raw video / PII).
  final String message;

  @override
  String toString() => 'SieFailure($code): $message';
}

/// Platform cannot run SIE (or a required submodule).
final class SieUnsupportedPlatformFailure extends SieFailure {
  /// Creates an unsupported-platform failure.
  SieUnsupportedPlatformFailure({
    required this.platform,
    required this.reason,
    String? message,
  }) : super(
          code: 'sie.platform.unsupported',
          message: message ??
              'SIE is not available on ${platform.displayName}: ${reason.name}',
        );

  /// Detected platform.
  final SiePlatformKind platform;

  /// Structured reason for host messaging.
  final SieUnsupportedReason reason;
}

/// Camera API or device inventory is missing.
final class SieCameraUnavailableFailure extends SieFailure {
  /// Creates a camera-unavailable failure.
  SieCameraUnavailableFailure({String? message})
      : super(
          code: 'sie.camera.unavailable',
          message: message ?? 'No usable camera was detected for SIE.',
        );
}

/// User denied or OS blocked camera permission.
final class SiePermissionDeniedFailure extends SieFailure {
  /// Creates a permission-denied failure.
  SiePermissionDeniedFailure({
    required this.permanent,
    String? message,
  }) : super(
          code: permanent
              ? 'sie.permission.permanently_denied'
              : 'sie.permission.denied',
          message: message ??
              (permanent
                  ? 'Camera permission is permanently denied. Open settings to continue.'
                  : 'Camera permission was denied. SIE remains optional.'),
        );

  /// When `true`, retrying [request] will not show a system prompt.
  final bool permanent;
}

/// Browser / secure-context / missing API limitation.
final class SieBrowserLimitationFailure extends SieFailure {
  /// Creates a browser-limitation failure.
  SieBrowserLimitationFailure({required super.message})
      : super(code: 'sie.browser.limitation');
}

/// Unexpected adapter error wrapped for host consumption.
final class SieUnexpectedFailure extends SieFailure {
  /// Creates an unexpected failure.
  SieUnexpectedFailure({required super.message, this.cause})
      : super(code: 'sie.unexpected');

  /// Optional underlying error (never frames / images).
  final Object? cause;
}

/// Camera engine lifecycle / streaming failure.
final class SieCameraEngineFailure extends SieFailure {
  /// Creates a camera-engine failure.
  SieCameraEngineFailure({
    required super.code,
    required super.message,
    this.cause,
  });

  /// Optional underlying error.
  final Object? cause;
}

/// Streaming is not supported on this platform adapter.
final class SieCameraStreamingUnsupportedFailure extends SieFailure {
  /// Creates a streaming-unsupported failure.
  SieCameraStreamingUnsupportedFailure({String? message})
      : super(
          code: 'sie.camera.streaming_unsupported',
          message: message ??
              'Continuous camera frame streaming is not available on this platform.',
        );
}

/// Invalid lifecycle transition.
final class SieCameraLifecycleFailure extends SieFailure {
  /// Creates a lifecycle failure.
  SieCameraLifecycleFailure({required super.message})
      : super(code: 'sie.camera.lifecycle');
}

/// Vision / MediaPipe backend failure.
final class SieVisionFailure extends SieFailure {
  /// Creates a vision failure.
  SieVisionFailure({
    required super.code,
    required super.message,
    this.cause,
  });

  /// Optional underlying error.
  final Object? cause;
}

/// Vision backend failed to initialize (model / WASM / native).
final class SieVisionInitFailure extends SieFailure {
  /// Creates an init failure.
  SieVisionInitFailure({required super.message, this.cause})
      : super(code: 'sie.vision.init');

  /// Optional underlying error.
  final Object? cause;
}

/// Landmark Engine failure.
final class SieLandmarkEngineFailure extends SieFailure {
  /// Creates a landmark-engine failure.
  SieLandmarkEngineFailure({required super.message, this.cause})
      : super(code: 'sie.landmarks.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Spatial Coordinate Engine failure.
final class SieSpatialEngineFailure extends SieFailure {
  /// Creates a spatial-engine failure.
  SieSpatialEngineFailure({required super.message, this.cause})
      : super(code: 'sie.spatial.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Calibration Engine failure.
final class SieCalibrationEngineFailure extends SieFailure {
  /// Creates a calibration-engine failure.
  SieCalibrationEngineFailure({required super.message, this.cause})
      : super(code: 'sie.calibration.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Confidence Engine failure.
final class SieConfidenceEngineFailure extends SieFailure {
  /// Creates a confidence-engine failure.
  SieConfidenceEngineFailure({required super.message, this.cause})
      : super(code: 'sie.confidence.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Gesture Engine failure.
final class SieGestureEngineFailure extends SieFailure {
  /// Creates a gesture-engine failure.
  SieGestureEngineFailure({required super.message, this.cause})
      : super(code: 'sie.gesture.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Intent Engine failure.
final class SieIntentEngineFailure extends SieFailure {
  /// Creates an intent-engine failure.
  SieIntentEngineFailure({required super.message, this.cause})
      : super(code: 'sie.intent.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Virtual Cursor Engine failure.
final class SieCursorEngineFailure extends SieFailure {
  /// Creates a cursor-engine failure.
  SieCursorEngineFailure({required super.message, this.cause})
      : super(code: 'sie.cursor.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Flutter Pointer Bridge failure.
final class SiePointerBridgeFailure extends SieFailure {
  /// Creates a pointer-bridge failure.
  SiePointerBridgeFailure({required super.message, this.cause})
      : super(code: 'sie.pointer.bridge');

  /// Optional underlying error.
  final Object? cause;
}

/// Input Arbitration Engine failure.
final class SieArbitrationEngineFailure extends SieFailure {
  /// Creates an arbitration-engine failure.
  SieArbitrationEngineFailure({required super.message, this.cause})
      : super(code: 'sie.arbitration.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// Interaction Orchestrator failure.
final class SieOrchestratorFailure extends SieFailure {
  /// Creates an orchestrator failure.
  SieOrchestratorFailure({required super.message, this.cause})
      : super(code: 'sie.orchestrator.engine');

  /// Optional underlying error.
  final Object? cause;
}

/// SIDF (debug & diagnostics) failure.
final class SieDiagnosticsFailure extends SieFailure {
  /// Creates a diagnostics failure.
  SieDiagnosticsFailure({required super.message, this.cause})
      : super(code: 'sie.diagnostics.sidf');

  /// Optional underlying error.
  final Object? cause;
}

/// SIE Integration Framework failure.
final class SieIntegrationFailure extends SieFailure {
  /// Creates an integration failure.
  SieIntegrationFailure({required super.message, this.cause})
      : super(code: 'sie.integration.framework');

  /// Optional underlying error.
  final Object? cause;
}

/// Progressive Rollout Framework failure.
final class SieRolloutFailure extends SieFailure {
  /// Creates a rollout failure.
  SieRolloutFailure({required super.message, this.cause})
      : super(code: 'sie.rollout.prf');

  /// Optional underlying error.
  final Object? cause;
}

/// Configuration & Policy Management Framework failure.
final class SieCpmfFailure extends SieFailure {
  /// Creates a CPMF failure.
  SieCpmfFailure({required super.message, this.cause})
      : super(code: 'sie.cpmf.framework');

  /// Optional underlying error.
  final Object? cause;
}

/// Service Registry & Dependency Composition Root failure.
final class SieSrdcrFailure extends SieFailure {
  /// Creates an SRDCR failure.
  SieSrdcrFailure({required super.message, this.cause})
      : super(code: 'sie.srdcr.composition_root');

  /// Optional underlying error.
  final Object? cause;
}
