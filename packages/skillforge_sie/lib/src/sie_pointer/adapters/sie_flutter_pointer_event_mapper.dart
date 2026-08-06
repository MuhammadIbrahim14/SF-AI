import 'package:flutter/gestures.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/pointer_injection_port.dart';

/// Maps [SiePointerEvent] → Flutter [PointerEvent] for host injection.
///
/// Platform-agnostic mapping; host decides whether to dispatch via
/// `GestureBinding` or an in-app overlay hit-test path (Approach A).
abstract final class SieFlutterPointerEventMapper {
  /// Convert a single SIE event.
  static PointerEvent? toFlutter(SiePointerEvent e) {
    final position = Offset(e.position.x, e.position.y);
    final delta = Offset(e.delta.x, e.delta.y);
    final timeStamp = Duration(
      microseconds: e.timestamp.microsecondsSinceEpoch,
    );
    switch (e.kind) {
      case SiePointerEventKind.added:
        return PointerAddedEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
        );
      case SiePointerEventKind.removed:
        return PointerRemovedEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
        );
      case SiePointerEventKind.hover:
        return PointerHoverEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
          delta: delta,
        );
      case SiePointerEventKind.move:
        return PointerMoveEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
          delta: delta,
          buttons: e.buttons,
        );
      case SiePointerEventKind.down:
        return PointerDownEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
          buttons: e.buttons == 0 ? kPrimaryButton : e.buttons,
        );
      case SiePointerEventKind.up:
        return PointerUpEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
          buttons: e.buttons,
        );
      case SiePointerEventKind.cancel:
        return PointerCancelEvent(
          timeStamp: timeStamp,
          pointer: e.pointerId,
          kind: PointerDeviceKind.mouse,
          position: position,
        );
      case SiePointerEventKind.scroll:
        return PointerScrollEvent(
          timeStamp: timeStamp,
          kind: PointerDeviceKind.mouse,
          position: position,
          scrollDelta: Offset(e.scrollDelta.x, e.scrollDelta.y),
        );
    }
  }

  /// Convert a batch (skips nulls).
  static List<PointerEvent> toFlutterBatch(List<SiePointerEvent> events) {
    final out = <PointerEvent>[];
    for (final e in events) {
      final f = toFlutter(e);
      if (f != null) out.add(f);
    }
    return out;
  }
}

/// Injects via [GestureBinding.handlePointerEvent] (optional host wiring).
final class GestureBindingPointerInjector implements PointerInjectionPort {
  /// Creates injector.
  const GestureBindingPointerInjector();

  @override
  Future<void> inject(List<SiePointerEvent> events) async {
    final binding = GestureBinding.instance;
    for (final e in SieFlutterPointerEventMapper.toFlutterBatch(events)) {
      binding.handlePointerEvent(e);
    }
  }

  @override
  Future<void> flush() async {}
}
