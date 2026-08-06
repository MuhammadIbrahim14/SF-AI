import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestration_snapshot.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Delivers orchestration-approved SIE pointer events to Flutter.
///
/// Host implements Approach A injection (GestureBinding or overlay hit-test).
/// Traditional mouse/touch/keyboard continue via the OS — not synthesized here.
abstract interface class InteractionDispatchPort {
  /// Dispatch an ordered batch (must preserve order).
  Future<void> dispatch(List<SiePointerEvent> events);

  /// Optional notify of orchestration state (host UI / overlays).
  Future<void> onSnapshot(SieOrchestrationSnapshot snapshot);
}

/// No-op dispatcher (tests / headless).
final class NopInteractionDispatcher implements InteractionDispatchPort {
  /// Creates dispatcher.
  const NopInteractionDispatcher();

  @override
  Future<void> dispatch(List<SiePointerEvent> events) async {}

  @override
  Future<void> onSnapshot(SieOrchestrationSnapshot snapshot) async {}
}

/// Records dispatches for tests.
final class RecordingInteractionDispatcher implements InteractionDispatchPort {
  /// Creates dispatcher.
  RecordingInteractionDispatcher();

  /// All events in order.
  final List<SiePointerEvent> events = [];

  /// Batches.
  final List<List<SiePointerEvent>> batches = [];

  /// Snapshots seen.
  final List<SieOrchestrationSnapshot> snapshots = [];

  /// Clear.
  void clear() {
    events.clear();
    batches.clear();
    snapshots.clear();
  }

  @override
  Future<void> dispatch(List<SiePointerEvent> batch) async {
    if (batch.isEmpty) return;
    batches.add(List.unmodifiable(batch));
    events.addAll(batch);
  }

  @override
  Future<void> onSnapshot(SieOrchestrationSnapshot snapshot) async {
    snapshots.add(snapshot);
  }
}

/// Callback-based dispatcher.
final class CallbackInteractionDispatcher implements InteractionDispatchPort {
  /// Creates dispatcher.
  CallbackInteractionDispatcher({
    required this.onDispatch,
    this.onSnap,
  });

  /// Dispatch callback.
  final Future<void> Function(List<SiePointerEvent> events) onDispatch;

  /// Optional snapshot callback.
  final Future<void> Function(SieOrchestrationSnapshot snapshot)? onSnap;

  @override
  Future<void> dispatch(List<SiePointerEvent> events) => onDispatch(events);

  @override
  Future<void> onSnapshot(SieOrchestrationSnapshot snapshot) async {
    await onSnap?.call(snapshot);
  }
}
