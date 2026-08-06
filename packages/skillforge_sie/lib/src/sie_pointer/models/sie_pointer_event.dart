import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Immutable synthetic pointer event — Flutter-compatible fields.
///
/// Host / [PointerInjectionPort] maps these to `PointerEvent` subclasses.
final class SiePointerEvent {
  /// Creates event.
  const SiePointerEvent({
    required this.timestamp,
    required this.frameSequence,
    required this.pointerId,
    required this.kind,
    required this.position,
    required this.buttons,
    required this.lifecycle,
    this.delta = SieSpatialPoint2D.zero,
    this.scrollDelta = SieSpatialPoint2D.zero,
    this.hovering = false,
    this.pressed = false,
    this.hoverTargetId,
    this.sourceIntent,
    this.metadata = const {},
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Frame sequence.
  final int frameSequence;

  /// Stable SIE pointer id (device-style).
  final int pointerId;

  /// Event kind.
  final SiePointerEventKind kind;

  /// Logical position.
  final SieSpatialPoint2D position;

  /// Button bitfield ([SiePointerButtons]).
  final int buttons;

  /// Lifecycle after this event.
  final SiePointerLifecycleState lifecycle;

  /// Position delta since last move/hover.
  final SieSpatialPoint2D delta;

  /// Scroll delta (y = vertical; x reserved).
  final SieSpatialPoint2D scrollDelta;

  /// Hover active.
  final bool hovering;

  /// Primary pressed.
  final bool pressed;

  /// Hover target reference.
  final String? hoverTargetId;

  /// Source intent kind when driven by intent.
  final SieIntentKind? sourceIntent;

  /// Diagnostics.
  final Map<String, Object?> metadata;
}

/// Frame-level bridge snapshot.
final class SiePointerBridgeSnapshot {
  /// Creates snapshot.
  const SiePointerBridgeSnapshot({
    required this.timestamp,
    required this.frameSequence,
    required this.pointerId,
    required this.lifecycle,
    required this.position,
    required this.buttons,
    required this.hovering,
    required this.pressed,
    required this.events,
    required this.processingMs,
    this.hoverTargetId,
    this.cursor,
    this.sourceIntents = const [],
    this.metadata = const {},
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Frame sequence.
  final int frameSequence;

  /// Active pointer id (0 if absent).
  final int pointerId;

  /// Lifecycle.
  final SiePointerLifecycleState lifecycle;

  /// Position.
  final SieSpatialPoint2D position;

  /// Buttons.
  final int buttons;

  /// Hovering.
  final bool hovering;

  /// Pressed.
  final bool pressed;

  /// Events emitted this frame (ordered).
  final List<SiePointerEvent> events;

  /// Processing ms.
  final double processingMs;

  /// Hover target.
  final String? hoverTargetId;

  /// Source cursor snapshot.
  final SieCursorSnapshot? cursor;

  /// Source intents considered.
  final List<SieIntentEvent> sourceIntents;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Whether any events fired.
  bool get hasEvents => events.isNotEmpty;
}

/// Paired input for synchronous process / tests.
final class SiePointerBridgeInput {
  /// Creates input.
  const SiePointerBridgeInput({
    required this.cursor,
    this.intents = const [],
  });

  /// Cursor snapshot (required).
  final SieCursorSnapshot cursor;

  /// Actionable intents for this frame (scroll deltas, select edge, etc.).
  final List<SieIntentEvent> intents;
}
