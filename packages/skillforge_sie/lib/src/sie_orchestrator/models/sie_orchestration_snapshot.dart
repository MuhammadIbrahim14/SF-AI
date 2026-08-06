import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Immutable orchestration snapshot — canonical app interaction state.
final class SieOrchestrationSnapshot {
  /// Creates snapshot.
  const SieOrchestrationSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.lifecycle,
    required this.mode,
    required this.routeKind,
    required this.securityLevel,
    required this.owner,
    required this.focus,
    required this.accessibility,
    required this.availability,
    required this.modal,
    required this.interactionEnabled,
    required this.sieDispatchEnabled,
    required this.decision,
    required this.dispatchedEvents,
    required this.processingMs,
    this.metadata = const {},
  });

  /// Idle.
  factory SieOrchestrationSnapshot.idle({
    required DateTime timestamp,
    int frameSequence = 0,
  }) {
    return SieOrchestrationSnapshot(
      timestamp: timestamp,
      frameSequence: frameSequence,
      lifecycle: SieAppLifecycleState.cold,
      mode: SieOrchestrationMode.disabled,
      routeKind: SieRouteCapabilityKind.dashboard,
      securityLevel: SieSecurityLevel.l1Standard,
      owner: SieInputSource.none,
      focus: SieFocusState.defaults,
      accessibility: SieAccessibilityState.defaults,
      availability: SieInteractionAvailability.full,
      modal: SieModalKind.none,
      interactionEnabled: false,
      sieDispatchEnabled: false,
      decision: SieDispatchDecision.blockedDisabled,
      dispatchedEvents: const [],
      processingMs: 0,
    );
  }

  /// Timestamp.
  final DateTime timestamp;

  /// Sequence.
  final int frameSequence;

  /// Lifecycle.
  final SieAppLifecycleState lifecycle;

  /// Mode.
  final SieOrchestrationMode mode;

  /// Route.
  final SieRouteCapabilityKind routeKind;

  /// Security.
  final SieSecurityLevel securityLevel;

  /// Input owner from arbitration.
  final SieInputSource owner;

  /// Focus.
  final SieFocusState focus;

  /// Accessibility.
  final SieAccessibilityState accessibility;

  /// Availability.
  final SieInteractionAvailability availability;

  /// Modal.
  final SieModalKind modal;

  /// Master enabled.
  final bool interactionEnabled;

  /// Whether SIE events were eligible this frame.
  final bool sieDispatchEnabled;

  /// Dispatch decision.
  final SieDispatchDecision decision;

  /// Events actually dispatched (ordered).
  final List<SiePointerEvent> dispatchedEvents;

  /// Processing ms.
  final double processingMs;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Count dispatched.
  int get dispatchedCount => dispatchedEvents.length;
}
