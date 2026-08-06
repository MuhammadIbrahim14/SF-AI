import 'package:skillforge_sie/src/sie_arbitration/engine/sie_input_arbitration_engine.dart';
import 'package:skillforge_sie/src/sie_arbitration/logging/sie_arbitration_logger.dart';
import 'package:skillforge_sie/src/sie_arbitration/ports/input_arbitration_engine_port.dart';
import 'package:skillforge_sie/src/sie_calibration/engine/sie_calibration_engine.dart';
import 'package:skillforge_sie/src/sie_calibration/logging/sie_calibration_logger.dart';
import 'package:skillforge_sie/src/sie_camera/adapters/camera_adapter_factory.dart';
import 'package:skillforge_sie/src/sie_camera/adapters/fake_camera_platform_adapter.dart';
import 'package:skillforge_sie/src/sie_camera/engine/sie_camera_engine.dart';
import 'package:skillforge_sie/src/sie_camera/logging/sie_camera_logger.dart';
import 'package:skillforge_sie/src/sie_cpmf/engine/sie_configuration_policy_framework.dart';
import 'package:skillforge_sie/src/sie_cpmf/logging/cpmf_logger.dart';
import 'package:skillforge_sie/src/sie_confidence/engine/sie_confidence_engine.dart';
import 'package:skillforge_sie/src/sie_confidence/logging/sie_confidence_logger.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_cursor/engine/sie_virtual_cursor_engine.dart';
import 'package:skillforge_sie/src/sie_cursor/logging/sie_cursor_logger.dart';
import 'package:skillforge_sie/src/sie_diagnostics/engine/sidf_diagnostics_framework.dart';
import 'package:skillforge_sie/src/sie_diagnostics/logging/sidf_logger.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_gesture/engine/sie_gesture_engine.dart';
import 'package:skillforge_sie/src/sie_gesture/logging/sie_gesture_logger.dart';
import 'package:skillforge_sie/src/sie_intent/engine/sie_intent_engine.dart';
import 'package:skillforge_sie/src/sie_intent/logging/sie_intent_logger.dart';
import 'package:skillforge_sie/src/sie_intent/ports/intent_engine_port.dart';
import 'package:skillforge_sie/src/sie_integration/engine/sie_integration_framework.dart';
import 'package:skillforge_sie/src/sie_integration/logging/sie_integration_logger.dart';
import 'package:skillforge_sie/src/sie_integration/ports/sie_integration_port.dart';
import 'package:skillforge_sie/src/sie_landmarks/engine/sie_landmark_engine.dart';
import 'package:skillforge_sie/src/sie_landmarks/logging/sie_landmark_logger.dart';
import 'package:skillforge_sie/src/sie_orchestrator/engine/sie_interaction_orchestrator.dart';
import 'package:skillforge_sie/src/sie_orchestrator/logging/sie_orchestrator_logger.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_orchestrator_port.dart';
import 'package:skillforge_sie/src/sie_platform/adapters/flutter_camera_permission_adapter.dart';
import 'package:skillforge_sie/src/sie_pointer/engine/sie_flutter_pointer_bridge.dart';
import 'package:skillforge_sie/src/sie_pointer/logging/sie_pointer_logger.dart';
import 'package:skillforge_sie/src/sie_rollout/engine/sie_progressive_rollout_framework.dart';
import 'package:skillforge_sie/src/sie_rollout/logging/prf_logger.dart';
import 'package:skillforge_sie/src/sie_spatial/engine/sie_spatial_coordinate_engine.dart';
import 'package:skillforge_sie/src/sie_spatial/logging/sie_spatial_logger.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_platform_context.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_service_descriptor.dart';
import 'package:skillforge_sie/src/sie_srdcr/processing/srdcr_service_registry.dart';
import 'package:skillforge_sie/src/sie_vision/adapters/hand_landmarker_backend_factory.dart';
import 'package:skillforge_sie/src/sie_vision/adapters/mock_hand_landmarker_backend.dart';
import 'package:skillforge_sie/src/sie_vision/engine/sie_vision_provider.dart';
import 'package:skillforge_sie/src/sie_vision/logging/sie_vision_logger.dart';

/// Registers default SIE factories into [registry] (composition root only).
abstract final class SrdcrDefaultRegistrations {
  /// Register catalog services with production or test-double adapters.
  static void registerAll(
    SrdcrServiceRegistry registry, {
    required SiePlatformKind platform,
    bool useTestDoubles = false,
  }) {
    for (final desc in SrdcrServiceCatalog.defaults) {
      registry.register(
        desc,
        _factoryFor(desc.id, useTestDoubles: useTestDoubles),
      );
    }
  }

  static SrdcrFactory _factoryFor(
    SrdcrServiceId id, {
    required bool useTestDoubles,
  }) {
    return switch (id) {
      SrdcrServiceId.platform => (r) {
          // Platform context is registered with concrete platform at bootstrap;
          // this placeholder is replaced via overrideFactory before construct.
          return const SrdcrPlatformContext(SiePlatformKind.unsupported);
        },
      SrdcrServiceId.diagnostics => (_) => SidfDiagnosticsFramework(
            logger: useTestDoubles
                ? const NopSidfLogger()
                : const DeveloperSidfLogger(),
          ),
      SrdcrServiceId.cpmf => (r) => SieConfigurationPolicyFramework(
            diagnostics: r(SrdcrServiceId.diagnostics) as SidfDiagnosticsPort,
            logger: useTestDoubles
                ? const NopCpmfLogger()
                : const DeveloperCpmfLogger(),
          ),
      SrdcrServiceId.camera => (r) {
          final ctx = r(SrdcrServiceId.platform) as SrdcrPlatformContext;
          return SieCameraEngine(
            adapter: useTestDoubles
                ? FakeCameraPlatformAdapter()
                : createDefaultCameraPlatformAdapter(platform: ctx.platform),
            permissionPort: useTestDoubles
                ? const SrdcrGrantedCameraPermission()
                : const FlutterCameraPermissionAdapter(),
            logger: useTestDoubles
                ? const NopSieCameraLogger()
                : const DeveloperSieCameraLogger(),
          );
        },
      SrdcrServiceId.vision => (r) {
          final ctx = r(SrdcrServiceId.platform) as SrdcrPlatformContext;
          return SieVisionProvider(
            backend: useTestDoubles
                ? MockHandLandmarkerBackend()
                : createDefaultHandLandmarkerBackend(platform: ctx.platform),
            logger: useTestDoubles
                ? const NopSieVisionLogger()
                : const DeveloperSieVisionLogger(),
          );
        },
      SrdcrServiceId.landmarks => (_) => SieLandmarkEngine(
            logger: useTestDoubles
                ? const NopSieLandmarkLogger()
                : const DeveloperSieLandmarkLogger(),
          ),
      SrdcrServiceId.spatial => (_) => SieSpatialCoordinateEngine(
            logger: useTestDoubles
                ? const NopSieSpatialLogger()
                : const DeveloperSieSpatialLogger(),
          ),
      SrdcrServiceId.calibration => (_) => SieCalibrationEngine(
            logger: useTestDoubles
                ? const NopSieCalibrationLogger()
                : const DeveloperSieCalibrationLogger(),
          ),
      SrdcrServiceId.confidence => (_) => SieConfidenceEngine(
            logger: useTestDoubles
                ? const NopSieConfidenceLogger()
                : const DeveloperSieConfidenceLogger(),
          ),
      SrdcrServiceId.gestures => (_) => SieGestureEngine(
            logger: useTestDoubles
                ? const NopSieGestureLogger()
                : const DeveloperSieGestureLogger(),
          ),
      SrdcrServiceId.intent => (_) => SieIntentEngine(
            logger: useTestDoubles
                ? const NopSieIntentLogger()
                : const DeveloperSieIntentLogger(),
          ),
      SrdcrServiceId.cursor => (_) => SieVirtualCursorEngine(
            logger: useTestDoubles
                ? const NopSieCursorLogger()
                : const DeveloperSieCursorLogger(),
          ),
      SrdcrServiceId.pointer => (_) => SieFlutterPointerBridge(
            logger: useTestDoubles
                ? const NopSiePointerLogger()
                : const DeveloperSiePointerLogger(),
          ),
      SrdcrServiceId.arbitration => (_) => SieInputArbitrationEngine(
            logger: useTestDoubles
                ? const NopSieArbitrationLogger()
                : const DeveloperSieArbitrationLogger(),
          ),
      SrdcrServiceId.orchestrator => (_) => SieInteractionOrchestrator(
            logger: useTestDoubles
                ? const NopSieOrchestratorLogger()
                : const DeveloperSieOrchestratorLogger(),
          ),
      SrdcrServiceId.integration => (r) => SieIntegrationFramework(
            orchestrator:
                r(SrdcrServiceId.orchestrator) as InteractionOrchestratorPort,
            arbitration:
                r(SrdcrServiceId.arbitration) as InputArbitrationEnginePort,
            intent: r(SrdcrServiceId.intent) as IntentEnginePort,
            diagnostics: r(SrdcrServiceId.diagnostics) as SidfDiagnosticsPort,
            logger: useTestDoubles
                ? const NopSieIntegrationLogger()
                : const DeveloperSieIntegrationLogger(),
          ),
      SrdcrServiceId.rollout => (r) => SieProgressiveRolloutFramework(
            integration: r(SrdcrServiceId.integration) as SieIntegrationPort,
            diagnostics: r(SrdcrServiceId.diagnostics) as SidfDiagnosticsPort,
            logger: useTestDoubles
                ? const NopPrfLogger()
                : const DeveloperPrfLogger(),
          ),
    };
  }
}
