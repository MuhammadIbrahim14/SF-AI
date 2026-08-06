import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestration_snapshot.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_status.dart';
import 'package:skillforge_sie/src/sie_orchestrator/ports/interaction_dispatch_port.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Interaction Orchestrator — single gateway into SkillForge AI.
///
/// Coordinates lifecycle, focus, a11y, routing, and gated dispatch.
/// Does not perform CV, gesture recognition, cursor math, or arbitration.
abstract interface class InteractionOrchestratorPort {
  /// Low-frequency status.
  Stream<SieOrchestratorStatus> get status;

  /// High-frequency orchestration snapshots — **not** Riverpod.
  Stream<SieOrchestrationSnapshot> get snapshots;

  /// Latest status.
  SieOrchestratorStatus get currentStatus;

  /// Latest metrics.
  SieOrchestratorMetrics get metrics;

  /// Active context.
  SieOrchestrationContext get context;

  /// Whether interaction delivery is enabled.
  bool get interactionEnabled;

  /// Current mode.
  SieOrchestrationMode get mode;

  /// Prepare.
  Future<void> initialize({
    SieOrchestrationContext? context,
    InteractionDispatchPort? dispatcher,
  });

  /// Attach to arbitration snapshots; optional SIE pointer event stream.
  Future<void> start({
    required Stream<SieArbitrationSnapshot> arbitrationSnapshots,
    Stream<List<SiePointerEvent>>? siePointerBatches,
  });

  /// Detach.
  Future<void> stop();

  /// Release.
  Future<void> dispose();

  /// Synchronous evaluate (tests / replay).
  SieOrchestrationSnapshot process(SieOrchestrationFrameInput input);

  /// Update lifecycle.
  Future<void> setLifecycle(SieAppLifecycleState lifecycle);

  /// Update route + security.
  Future<void> setRoute({
    required SieRouteCapabilityKind routeKind,
    SieSecurityLevel? securityLevel,
  });

  /// Update focus.
  Future<void> setFocus(SieFocusState focus);

  /// Update modal surface.
  Future<void> setModal(SieModalKind modal);

  /// Update accessibility.
  Future<void> setAccessibility(SieAccessibilityState accessibility);

  /// Update feature availability (graceful degradation).
  Future<void> setAvailability(SieInteractionAvailability availability);

  /// Enable / disable interaction delivery.
  Future<void> setInteractionEnabled(bool enabled);

  /// Replace dispatcher.
  Future<void> setDispatcher(InteractionDispatchPort dispatcher);

  /// Mark recovery completed (LostTracking / camera / permission).
  Future<void> notifyRecoveryCompleted();
}
