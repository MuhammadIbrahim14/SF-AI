/// SkillForge AI — Spatial Interaction Engine (`skillforge_sie`).
///
/// Public barrel for Stable host-facing and platform-capability APIs.
///
/// Deep imports of `package:skillforge_sie/src/...` are forbidden for app code
/// (see Implementation Architecture §8).
library;

// Core
export 'src/sie_core/platform_kind.dart';
export 'src/sie_core/sie_permission_status.dart';
export 'src/sie_core/sie_failures.dart';

// Config / feature flags
export 'src/sie_config/sie_feature_id.dart';
export 'src/sie_config/sie_feature_flags.dart';
export 'src/sie_config/sie_platform_profile.dart';
export 'src/sie_config/sie_config_snapshot.dart';

// Platform models
export 'src/sie_platform/models/sie_platform_capabilities.dart';
export 'src/sie_platform/models/sie_permission_snapshot.dart';
export 'src/sie_platform/models/sie_unsupported_reason.dart';
export 'src/sie_platform/models/sie_camera_inventory.dart';

// Ports
export 'src/sie_platform/ports/platform_detector_port.dart';
export 'src/sie_platform/ports/capability_probe_port.dart';
export 'src/sie_platform/ports/camera_permission_port.dart';
export 'src/sie_platform/ports/camera_inventory_port.dart';

// Services
export 'src/sie_platform/services/sie_platform_capability_service.dart';
export 'src/sie_platform/services/sie_permission_manager.dart';
export 'src/sie_platform/services/sie_feature_flag_service.dart';

// Default adapters (host may replace via DI)
export 'src/sie_platform/adapters/default_platform_detector.dart';
export 'src/sie_platform/adapters/flutter_capability_probe.dart';
export 'src/sie_platform/adapters/flutter_camera_permission_adapter.dart';
export 'src/sie_platform/adapters/flutter_camera_inventory.dart';

// Riverpod (session / capability / permission / config only — ADR-008)
export 'src/sie_platform/providers/sie_platform_providers.dart';

// Camera Engine (Prompt 08) — frames via CameraPort.frames, not Riverpod
export 'src/sie_camera/models/sie_camera_lens_direction.dart';
export 'src/sie_camera/models/sie_camera_image_format.dart';
export 'src/sie_camera/models/sie_camera_device_info.dart';
export 'src/sie_camera/models/sie_camera_config.dart';
export 'src/sie_camera/models/sie_camera_lifecycle_state.dart';
export 'src/sie_camera/models/sie_camera_frame.dart';
export 'src/sie_camera/models/sie_camera_status.dart';
export 'src/sie_camera/ports/camera_port.dart';
export 'src/sie_camera/ports/camera_platform_adapter_port.dart';
export 'src/sie_camera/selection/sie_camera_selection_strategy.dart';
export 'src/sie_camera/logging/sie_camera_logger.dart';
export 'src/sie_camera/engine/sie_camera_engine.dart';
export 'src/sie_camera/adapters/camera_adapter_factory.dart';
export 'src/sie_camera/adapters/flutter_camera_platform_adapter.dart';
export 'src/sie_camera/adapters/unsupported_camera_platform_adapter.dart';
export 'src/sie_camera/adapters/fake_camera_platform_adapter.dart';
export 'src/sie_camera/providers/sie_camera_providers.dart';

// Vision Provider (Prompt 09) — landmarks via VisionRuntimePort.results, not Riverpod
export 'src/sie_vision/models/sie_vision_enums.dart';
export 'src/sie_vision/models/sie_hand_landmark.dart';
export 'src/sie_vision/models/sie_detected_hand.dart';
export 'src/sie_vision/models/sie_vision_result.dart';
export 'src/sie_vision/models/sie_vision_status.dart';
export 'src/sie_vision/models/sie_vision_metrics.dart';
export 'src/sie_vision/models/sie_vision_config.dart';
export 'src/sie_vision/ports/vision_runtime_port.dart';
export 'src/sie_vision/ports/hand_landmarker_backend_port.dart';
export 'src/sie_vision/logging/sie_vision_logger.dart';
export 'src/sie_vision/engine/sie_vision_provider.dart';
export 'src/sie_vision/adapters/hand_landmarker_backend_factory.dart';
export 'src/sie_vision/adapters/mock_hand_landmarker_backend.dart';
export 'src/sie_vision/adapters/unsupported_hand_landmarker_backend.dart';
export 'src/sie_vision/providers/sie_vision_providers.dart';

// Landmark Engine (Prompt 10) — snapshots via LandmarkEnginePort.snapshots
export 'src/sie_landmarks/models/sie_landmark_enums.dart';
export 'src/sie_landmarks/models/sie_landmark_engine_config.dart';
export 'src/sie_landmarks/models/sie_normalized_landmark.dart';
export 'src/sie_landmarks/models/sie_hand_landmark_snapshot.dart';
export 'src/sie_landmarks/models/sie_landmark_frame_snapshot.dart';
export 'src/sie_landmarks/models/sie_landmark_engine_status.dart';
export 'src/sie_landmarks/models/sie_landmark_engine_metrics.dart';
export 'src/sie_landmarks/ports/landmark_engine_port.dart';
export 'src/sie_landmarks/processing/sie_landmark_validator.dart';
export 'src/sie_landmarks/processing/sie_landmark_normalizer.dart';
export 'src/sie_landmarks/processing/sie_landmark_stabilizer.dart';
export 'src/sie_landmarks/logging/sie_landmark_logger.dart';
export 'src/sie_landmarks/engine/sie_landmark_engine.dart';
export 'src/sie_landmarks/providers/sie_landmark_providers.dart';

// Spatial Coordinate Engine (Prompt 11) — snapshots via SpatialCoordinateEnginePort
export 'src/sie_spatial/models/sie_spatial_enums.dart';
export 'src/sie_spatial/models/sie_spatial_geometry.dart';
export 'src/sie_spatial/models/sie_viewport_geometry.dart';
export 'src/sie_spatial/models/sie_spatial_engine_config.dart';
export 'src/sie_spatial/models/sie_spatial_landmark.dart';
export 'src/sie_spatial/models/sie_spatial_hand_snapshot.dart';
export 'src/sie_spatial/models/sie_spatial_frame_snapshot.dart';
export 'src/sie_spatial/models/sie_spatial_engine_status.dart';
export 'src/sie_spatial/models/sie_spatial_engine_metrics.dart';
export 'src/sie_spatial/ports/spatial_coordinate_engine_port.dart';
export 'src/sie_spatial/processing/sie_spatial_transform_pipeline.dart';
export 'src/sie_spatial/logging/sie_spatial_logger.dart';
export 'src/sie_spatial/engine/sie_spatial_coordinate_engine.dart';
export 'src/sie_spatial/providers/sie_spatial_providers.dart';

// Calibration Engine (Prompt 12) — snapshots via CalibrationEnginePort
export 'src/sie_calibration/models/sie_calibration_enums.dart';
export 'src/sie_calibration/models/sie_user_calibration.dart';
export 'src/sie_calibration/models/sie_camera_calibration.dart';
export 'src/sie_calibration/models/sie_display_calibration.dart';
export 'src/sie_calibration/models/sie_handedness_calibration.dart';
export 'src/sie_calibration/models/sie_interaction_zone_calibration.dart';
export 'src/sie_calibration/models/sie_sensitivity_parameters.dart';
export 'src/sie_calibration/models/sie_calibration_profile.dart';
export 'src/sie_calibration/models/sie_calibrated_snapshot.dart';
export 'src/sie_calibration/models/sie_calibration_session.dart';
export 'src/sie_calibration/models/sie_calibration_engine_status.dart';
export 'src/sie_calibration/persistence/calibration_store_port.dart';
export 'src/sie_calibration/persistence/sie_calibration_migrator.dart';
export 'src/sie_calibration/ports/calibration_engine_port.dart';
export 'src/sie_calibration/processing/sie_calibration_transform_pipeline.dart';
export 'src/sie_calibration/logging/sie_calibration_logger.dart';
export 'src/sie_calibration/engine/sie_calibration_engine.dart';
export 'src/sie_calibration/providers/sie_calibration_providers.dart';

// Confidence Engine (Prompt 13) — snapshots via ConfidenceEnginePort
export 'src/sie_confidence/models/sie_confidence_enums.dart';
export 'src/sie_confidence/models/sie_confidence_policy.dart';
export 'src/sie_confidence/models/sie_hysteresis_gate.dart';
export 'src/sie_confidence/models/sie_confidence_sources.dart';
export 'src/sie_confidence/models/sie_confidence_snapshot.dart';
export 'src/sie_confidence/models/sie_confidence_engine_status.dart';
export 'src/sie_confidence/processing/sie_confidence_fusion.dart';
export 'src/sie_confidence/processing/sie_tracking_state_machine.dart';
export 'src/sie_confidence/processing/sie_confidence_evaluator.dart';
export 'src/sie_confidence/ports/confidence_engine_port.dart';
export 'src/sie_confidence/logging/sie_confidence_logger.dart';
export 'src/sie_confidence/engine/sie_confidence_engine.dart';
export 'src/sie_confidence/providers/sie_confidence_providers.dart';

// Gesture Engine (Prompt 14) — events via GestureEnginePort
export 'src/sie_gesture/models/sie_gesture_enums.dart';
export 'src/sie_gesture/models/sie_hand_landmark_index.dart';
export 'src/sie_gesture/models/sie_gesture_policy.dart';
export 'src/sie_gesture/models/sie_gesture_event.dart';
export 'src/sie_gesture/models/sie_gesture_engine_status.dart';
export 'src/sie_gesture/processing/sie_hand_feature_extractor.dart';
export 'src/sie_gesture/processing/sie_gesture_classifier.dart';
export 'src/sie_gesture/processing/sie_pinch_family_classifier.dart';
export 'src/sie_gesture/processing/sie_gesture_classifiers.dart';
export 'src/sie_gesture/processing/sie_gesture_conflict_resolver.dart';
export 'src/sie_gesture/processing/sie_gesture_evaluator.dart';
export 'src/sie_gesture/ports/gesture_engine_port.dart';
export 'src/sie_gesture/logging/sie_gesture_logger.dart';
export 'src/sie_gesture/engine/sie_gesture_engine.dart';
export 'src/sie_gesture/providers/sie_gesture_providers.dart';

// Intent Engine (Prompt 15) — events via IntentEnginePort
export 'src/sie_intent/models/sie_intent_enums.dart';
export 'src/sie_intent/models/sie_intent_policy.dart';
export 'src/sie_intent/models/sie_intent_context.dart';
export 'src/sie_intent/models/sie_intent_event.dart';
export 'src/sie_intent/models/sie_intent_engine_status.dart';
export 'src/sie_intent/processing/sie_intent_policy_gate.dart';
export 'src/sie_intent/processing/sie_intent_mapper.dart';
export 'src/sie_intent/processing/sie_intent_conflict_resolver.dart';
export 'src/sie_intent/ports/intent_engine_port.dart';
export 'src/sie_intent/logging/sie_intent_logger.dart';
export 'src/sie_intent/engine/sie_intent_engine.dart';
export 'src/sie_intent/providers/sie_intent_providers.dart';

// Virtual Cursor Engine (Prompt 16) — snapshots via VirtualCursorEnginePort
export 'src/sie_cursor/models/sie_cursor_enums.dart';
export 'src/sie_cursor/models/sie_cursor_config.dart';
export 'src/sie_cursor/models/sie_cursor_snapshot.dart';
export 'src/sie_cursor/models/sie_cursor_engine_status.dart';
export 'src/sie_cursor/processing/sie_cursor_motion.dart';
export 'src/sie_cursor/processing/sie_cursor_state.dart';
export 'src/sie_cursor/processing/sie_cursor_evaluator.dart';
export 'src/sie_cursor/ports/virtual_cursor_engine_port.dart';
export 'src/sie_cursor/logging/sie_cursor_logger.dart';
export 'src/sie_cursor/engine/sie_virtual_cursor_engine.dart';
export 'src/sie_cursor/providers/sie_cursor_providers.dart';

// Flutter Pointer Bridge (Prompt 17) — events via FlutterPointerBridgePort
export 'src/sie_pointer/models/sie_pointer_enums.dart';
export 'src/sie_pointer/models/sie_pointer_event.dart';
export 'src/sie_pointer/models/sie_pointer_bridge_status.dart';
export 'src/sie_pointer/processing/sie_pointer_translator.dart';
export 'src/sie_pointer/ports/pointer_injection_port.dart';
export 'src/sie_pointer/ports/flutter_pointer_bridge_port.dart';
export 'src/sie_pointer/adapters/sie_flutter_pointer_event_mapper.dart';
export 'src/sie_pointer/logging/sie_pointer_logger.dart';
export 'src/sie_pointer/engine/sie_flutter_pointer_bridge.dart';
export 'src/sie_pointer/providers/sie_pointer_providers.dart';

// Input Arbitration Engine (Prompt 17.5) — ownership via InputArbitrationEnginePort
export 'src/sie_arbitration/models/sie_arbitration_enums.dart';
export 'src/sie_arbitration/models/sie_arbitration_policy.dart';
export 'src/sie_arbitration/models/sie_arbitration_snapshot.dart';
export 'src/sie_arbitration/models/sie_arbitration_engine_status.dart';
export 'src/sie_arbitration/processing/sie_arbitration_resolver.dart';
export 'src/sie_arbitration/ports/input_arbitration_engine_port.dart';
export 'src/sie_arbitration/logging/sie_arbitration_logger.dart';
export 'src/sie_arbitration/engine/sie_input_arbitration_engine.dart';
export 'src/sie_arbitration/providers/sie_arbitration_providers.dart';

// Interaction Orchestrator (Prompt 18) — gateway via InteractionOrchestratorPort
export 'src/sie_orchestrator/models/sie_orchestrator_enums.dart';
export 'src/sie_orchestrator/models/sie_orchestrator_context.dart';
export 'src/sie_orchestrator/models/sie_orchestration_snapshot.dart';
export 'src/sie_orchestrator/models/sie_orchestrator_status.dart';
export 'src/sie_orchestrator/processing/sie_orchestration_coordinator.dart';
export 'src/sie_orchestrator/ports/interaction_dispatch_port.dart';
export 'src/sie_orchestrator/ports/interaction_orchestrator_port.dart';
export 'src/sie_orchestrator/logging/sie_orchestrator_logger.dart';
export 'src/sie_orchestrator/engine/sie_interaction_orchestrator.dart';
export 'src/sie_orchestrator/providers/sie_orchestrator_providers.dart';

// SIDF — Spatial Interaction Debug & Diagnostics Framework (Prompt 19)
// Passive observer only — never participates in the runtime pipeline
export 'src/sie_diagnostics/models/sidf_enums.dart';
export 'src/sie_diagnostics/models/sidf_feature_flags.dart';
export 'src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
export 'src/sie_diagnostics/processing/sidf_timeline.dart';
export 'src/sie_diagnostics/processing/sie_latency_stats.dart';
export 'src/sie_diagnostics/processing/sidf_recording.dart';
export 'src/sie_diagnostics/processing/sidf_hand_topology.dart';
export 'src/sie_diagnostics/logging/sidf_logger.dart';
export 'src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
export 'src/sie_diagnostics/engine/sidf_diagnostics_framework.dart';
export 'src/sie_diagnostics/overlay/sidf_debug_overlay.dart';
export 'src/sie_diagnostics/providers/sidf_providers.dart';

// SIE Integration Framework (Prompt 20) — sole host façade (no MediaPipe coupling)
export 'src/sie_integration/models/sie_integration_enums.dart';
export 'src/sie_integration/models/sie_route_policy.dart';
export 'src/sie_integration/models/sie_student_route_catalog.dart';
export 'src/sie_integration/models/sie_teacher_route_catalog.dart';
export 'src/sie_integration/models/sie_freelancer_route_catalog.dart';
export 'src/sie_integration/models/sie_company_route_catalog.dart';
export 'src/sie_integration/models/sie_admin_route_catalog.dart';
export 'src/sie_integration/models/sie_feature_registry.dart';
export 'src/sie_integration/models/sie_integration_state.dart';
export 'src/sie_integration/processing/sie_route_registry.dart';
export 'src/sie_integration/processing/sie_integration_policy_sync.dart';
export 'src/sie_integration/logging/sie_integration_logger.dart';
export 'src/sie_integration/ports/sie_integration_port.dart';
export 'src/sie_integration/engine/sie_integration_framework.dart';
export 'src/sie_integration/adapters/sie_widget_adapters.dart';
export 'src/sie_integration/providers/sie_integration_providers.dart';

// Progressive Rollout Framework (Prompt 20.5) — sole SIE enablement authority
export 'src/sie_rollout/models/prf_enums.dart';
export 'src/sie_rollout/models/prf_config.dart';
export 'src/sie_rollout/models/prf_device_capability.dart';
export 'src/sie_rollout/models/prf_snapshot.dart';
export 'src/sie_rollout/processing/prf_evaluator.dart';
export 'src/sie_rollout/logging/prf_logger.dart';
export 'src/sie_rollout/ports/prf_remote_config_port.dart';
export 'src/sie_rollout/ports/progressive_rollout_port.dart';
export 'src/sie_rollout/engine/sie_progressive_rollout_framework.dart';
export 'src/sie_rollout/providers/sie_rollout_providers.dart';

// Configuration & Policy Management Framework (Prompt 20.6)
export 'src/sie_cpmf/models/cpmf_enums.dart';
export 'src/sie_cpmf/models/cpmf_configuration_bundle.dart';
export 'src/sie_cpmf/models/cpmf_profile_catalog.dart';
export 'src/sie_cpmf/models/cpmf_policy_context.dart';
export 'src/sie_cpmf/models/cpmf_snapshot.dart';
export 'src/sie_cpmf/processing/cpmf_composer.dart';
export 'src/sie_cpmf/logging/cpmf_logger.dart';
export 'src/sie_cpmf/ports/cpmf_remote_config_port.dart';
export 'src/sie_cpmf/ports/cpmf_port.dart';
export 'src/sie_cpmf/engine/sie_configuration_policy_framework.dart';
export 'src/sie_cpmf/providers/sie_cpmf_providers.dart';

// Service Registry & Dependency Composition Root (Prompt 20.7)
// Sole authoritative bootstrap — engines must not instantiate each other
export 'src/sie_srdcr/models/srdcr_enums.dart';
export 'src/sie_srdcr/models/srdcr_service_descriptor.dart';
export 'src/sie_srdcr/models/srdcr_registry_snapshot.dart';
export 'src/sie_srdcr/models/srdcr_platform_context.dart';
export 'src/sie_srdcr/processing/srdcr_service_registry.dart';
export 'src/sie_srdcr/processing/srdcr_default_registrations.dart';
export 'src/sie_srdcr/logging/srdcr_logger.dart';
export 'src/sie_srdcr/ports/srdcr_port.dart';
export 'src/sie_srdcr/engine/sie_service_registry_composition_root.dart';
export 'src/sie_srdcr/providers/sie_srdcr_providers.dart';
