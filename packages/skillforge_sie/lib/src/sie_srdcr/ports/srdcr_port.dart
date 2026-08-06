import 'package:skillforge_sie/src/sie_arbitration/ports/input_arbitration_engine_port.dart';
import 'package:skillforge_sie/src/sie_calibration/ports/calibration_engine_port.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_port.dart';
import 'package:skillforge_sie/src/sie_cpmf/ports/cpmf_port.dart';
import 'package:skillforge_sie/src/sie_confidence/ports/confidence_engine_port.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_cursor/ports/virtual_cursor_engine_port.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_gesture/ports/gesture_engine_port.dart';
import 'package:skillforge_sie/src/sie_intent/ports/intent_engine_port.dart';
import 'package:skillforge_sie/src/sie_integration/ports/sie_integration_port.dart';
import 'package:skillforge_sie/src/sie_landmarks/ports/landmark_engine_port.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_orchestrator_port.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/flutter_pointer_bridge_port.dart';
import 'package:skillforge_sie/src/sie_rollout/ports/progressive_rollout_port.dart';
import 'package:skillforge_sie/src/sie_spatial/ports/spatial_coordinate_engine_port.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_registry_snapshot.dart';
import 'package:skillforge_sie/src/sie_srdcr/processing/srdcr_service_registry.dart';
import 'package:skillforge_sie/src/sie_vision/ports/vision_runtime_port.dart';

/// Host-facing composition root port.
abstract interface class SrdcrPort {
  /// Status stream (Riverpod-safe).
  Stream<SrdcrStatus> get status;

  /// Snapshot stream.
  Stream<SrdcrRegistrySnapshot> get snapshots;

  /// Current status.
  SrdcrStatus get currentStatus;

  /// Latest snapshot.
  SrdcrRegistrySnapshot get latestSnapshot;

  /// Underlying registry (read-only inspection after bootstrap).
  SrdcrServiceRegistry get registry;

  /// Whether ready.
  bool get isReady;

  /// Register catalog + factories, validate, construct, initialize frameworks.
  Future<void> bootstrap({
    required SiePlatformKind platform,
    Map<SrdcrServiceId, SrdcrFactory>? overrides,
  });

  /// Bind and start the high-frequency runtime pipeline (optional).
  Future<void> startRuntimePipeline();

  /// Graceful shutdown (reverse order).
  Future<void> shutdown();

  /// Resolve a typed service (after bootstrap).
  T resolve<T extends Object>(SrdcrServiceId id);

  /// Typed accessors (composition root API — not service locator for apps;
  /// host uses Integration/PRF; tests/tools may resolve).
  /// CPMF.
  CpmfPort get cpmf;

  /// SIDF.
  SidfDiagnosticsPort get diagnostics;

  /// Camera.
  CameraPort get camera;

  /// Vision.
  VisionRuntimePort get vision;

  /// Landmarks.
  LandmarkEnginePort get landmarks;

  /// Spatial.
  SpatialCoordinateEnginePort get spatial;

  /// Calibration.
  CalibrationEnginePort get calibration;

  /// Confidence.
  ConfidenceEnginePort get confidence;

  /// Gestures.
  GestureEnginePort get gestures;

  /// Intent.
  IntentEnginePort get intent;

  /// Cursor.
  VirtualCursorEnginePort get cursor;

  /// Pointer bridge.
  FlutterPointerBridgePort get pointer;

  /// Arbitration.
  InputArbitrationEnginePort get arbitration;

  /// Orchestrator.
  InteractionOrchestratorPort get orchestrator;

  /// Integration.
  SieIntegrationPort get integration;

  /// Progressive rollout.
  ProgressiveRolloutPort get rollout;

  /// Diagnostics report for SIDF.
  Map<String, Object?> diagnosticsReport();

  /// Dispose.
  Future<void> dispose();
}
