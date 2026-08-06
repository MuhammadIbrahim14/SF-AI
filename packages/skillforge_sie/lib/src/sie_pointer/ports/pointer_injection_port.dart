import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';

/// Injects translated SIE pointer events into the host Flutter input path.
///
/// Owned by the consumer (Doc 04). The bridge never talks to cameras/vision.
abstract interface class PointerInjectionPort {
  /// Deliver an ordered batch of events for one frame.
  Future<void> inject(List<SiePointerEvent> events);

  /// Optional flush / platform sync.
  Future<void> flush();
}

/// No-op injector (tests / headless).
final class NopPointerInjector implements PointerInjectionPort {
  /// Creates injector.
  const NopPointerInjector();

  @override
  Future<void> inject(List<SiePointerEvent> events) async {}

  @override
  Future<void> flush() async {}
}

/// Records injected events for tests.
final class RecordingPointerInjector implements PointerInjectionPort {
  /// Creates injector.
  RecordingPointerInjector();

  /// All events in order.
  final List<SiePointerEvent> events = [];

  /// Batches.
  final List<List<SiePointerEvent>> batches = [];

  /// Clear.
  void clear() {
    events.clear();
    batches.clear();
  }

  @override
  Future<void> inject(List<SiePointerEvent> batch) async {
    if (batch.isEmpty) return;
    batches.add(List.unmodifiable(batch));
    events.addAll(batch);
  }

  @override
  Future<void> flush() async {}
}

/// Host-supplied callback injector (maps to GestureBinding / overlay).
final class CallbackPointerInjector implements PointerInjectionPort {
  /// Creates injector.
  CallbackPointerInjector(this.onInject);

  /// Callback.
  final Future<void> Function(List<SiePointerEvent> events) onInject;

  @override
  Future<void> inject(List<SiePointerEvent> events) => onInject(events);

  @override
  Future<void> flush() async {}
}
