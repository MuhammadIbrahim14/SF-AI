import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_bridge_status.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Mutable lifecycle owner for a single SIE pointer (multi-pointer-ready slot).
final class SiePointerSlot {
  /// Creates slot.
  SiePointerSlot({required this.pointerId});

  /// Pointer id.
  int pointerId;

  /// Whether added to Flutter arena.
  bool added = false;

  /// Primary pressed.
  bool pressed = false;

  /// Hovering.
  bool hovering = false;

  /// Last position.
  SieSpatialPoint2D position = SieSpatialPoint2D.zero;

  /// Position where primary button went down (tap stability).
  SieSpatialPoint2D? pressOrigin;

  /// Hover target.
  String? hoverTargetId;

  /// Coarse lifecycle.
  SiePointerLifecycleState lifecycle = SiePointerLifecycleState.absent;

  /// Reset soft state (keeps id).
  void softReset() {
    added = false;
    pressed = false;
    hovering = false;
    hoverTargetId = null;
    pressOrigin = null;
    lifecycle = SiePointerLifecycleState.absent;
  }
}

/// Translates cursor + intents → ordered [SiePointerEvent]s.
final class SiePointerTranslator {
  /// Creates translator.
  SiePointerTranslator({
    SiePointerBridgeConfig config = SiePointerBridgeConfig.standard,
  }) : _config = config,
       _slot = SiePointerSlot(pointerId: config.basePointerId);

  SiePointerBridgeConfig _config;
  final SiePointerSlot _slot;
  int _generation = 0;
  int _recreations = 0;
  int _lostCleanups = 0;

  /// Config.
  SiePointerBridgeConfig get config => _config;

  /// Slot (tests).
  SiePointerSlot get slot => _slot;

  /// Recreation count.
  int get recreations => _recreations;

  /// Lost cleanups.
  int get lostCleanups => _lostCleanups;

  /// Update config.
  void setConfig(SiePointerBridgeConfig config) {
    _config = config;
    if (!_slot.added) {
      _slot.pointerId = config.basePointerId + _generation;
    }
  }

  /// Reset.
  void reset() {
    _slot.softReset();
    _slot.position = SieSpatialPoint2D.zero;
    _generation = 0;
    _slot.pointerId = _config.basePointerId;
    _recreations = 0;
    _lostCleanups = 0;
  }

  /// Translate one paired frame.
  ({List<SiePointerEvent> events, SiePointerSlot slot}) translate(
    SiePointerBridgeInput input,
  ) {
    final cursor = input.cursor;
    final intents = input.intents.where((e) => e.isActionable).toList();
    final out = <SiePointerEvent>[];
    final pos = cursor.position;
    final ts = cursor.timestamp;
    final seq = cursor.frameSequence;

    final lost =
        cursor.state == SieCursorState.lostTracking ||
        cursor.state == SieCursorState.hidden;
    final paused = cursor.state == SieCursorState.paused;
    final recovering = cursor.state == SieCursorState.recovering;

    if (lost || paused) {
      out.addAll(
        _cleanup(
          timestamp: ts,
          frameSequence: seq,
          position: _slot.added ? _slot.position : pos,
          reason: lost ? 'lost_tracking' : 'paused',
          countLost: lost,
        ),
      );
      return (events: out, slot: _slot);
    }

    // Ensure pointer exists when cursor is interactable.
    if (!_slot.added && cursor.isVisible) {
      out.add(
        _event(
          kind: SiePointerEventKind.added,
          timestamp: ts,
          frameSequence: seq,
          position: pos,
          sourceIntent: null,
        ),
      );
      _slot.added = true;
      _slot.lifecycle = SiePointerLifecycleState.idle;
      _slot.position = pos;
    }

    if (!_slot.added) {
      return (events: out, slot: _slot);
    }

    // Recovering: locomotion/hover only — no new downs.
    final allowCommit = !recovering;

    // The cursor position is the only coordinate injected into Flutter. Intent
    // positions originate from raw hand landmarks and are deliberately not used
    // here: doing so bypasses the cursor filter and lets a noisy frame move a
    // click or touch away from the displayed cursor.
    // Process intents in stable order: cancel → scroll → select/drag → move/hover
    final ordered = List<SieIntentEvent>.of(intents)
      ..sort(
        (a, b) => _intentPriority(a.kind).compareTo(_intentPriority(b.kind)),
      );

    var handledMove = false;
    for (final intent in ordered) {
      switch (intent.kind) {
        case SieIntentKind.cancel:
          out.addAll(
            _cancelPress(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
            ),
          );
        case SieIntentKind.scrollDelta:
          out.addAll(
            _ensureHoverOrMove(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
            ),
          );
          handledMove = true;
          final scrollY = intent.axisDelta * _config.scrollPixelsGain;
          // Ignore tiny scrolls that Flutter / web effectively drop.
          if (scrollY.abs() >= 1.0) {
            out.add(
              _event(
                kind: SiePointerEventKind.scroll,
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                scrollDelta: SieSpatialPoint2D(0, scrollY),
                sourceIntent: intent.kind,
                lifecycleOverride: SiePointerLifecycleState.scrolling,
              ),
            );
            _slot.lifecycle = SiePointerLifecycleState.scrolling;
          }
        case SieIntentKind.select:
          if (intent.phase == SieIntentPhase.candidate ||
              intent.phase == SieIntentPhase.ready) {
            // Armed — hover only.
            out.addAll(
              _ensureHoverOrMove(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            handledMove = true;
          } else if (intent.phase == SieIntentPhase.active && allowCommit) {
            out.addAll(
              _pointerDown(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            handledMove = true;
          }
        case SieIntentKind.dwellSelect:
          if (allowCommit) {
            out.addAll(
              _pointerDown(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            // Immediate up for dwell click semantics.
            out.addAll(
              _pointerUp(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            handledMove = true;
          }
        case SieIntentKind.selectHold:
          if (allowCommit) {
            out.addAll(
              _pointerDown(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            out.addAll(
              _movePressed(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            handledMove = true;
          }
        case SieIntentKind.selectRelease:
          out.addAll(
            _pointerUp(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
            ),
          );
          handledMove = true;
        case SieIntentKind.beginDrag:
          if (allowCommit) {
            out.addAll(
              _pointerDown(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            _slot.lifecycle = SiePointerLifecycleState.dragging;
            // Always emit a move so Flutter sees drag initiation.
            final dragPos = pos;
            final delta = _delta(dragPos);
            _slot.position = dragPos;
            out.add(
              _event(
                kind: SiePointerEventKind.move,
                timestamp: ts,
                frameSequence: seq,
                position: dragPos,
                delta: delta,
                sourceIntent: intent.kind,
                buttons: SiePointerButtons.primary,
              ),
            );
            handledMove = true;
          }
        case SieIntentKind.updateDrag:
          if (allowCommit) {
            out.addAll(
              _pointerDown(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            out.addAll(
              _movePressed(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
                dragging: true,
              ),
            );
            handledMove = true;
          }
        case SieIntentKind.endDrag:
          out.addAll(
            _movePressed(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
              dragging: true,
            ),
          );
          out.addAll(
            _pointerUp(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
            ),
          );
          handledMove = true;
        case SieIntentKind.hoverEnter:
          _slot.hoverTargetId = intent.targetId ?? _slot.hoverTargetId;
          out.addAll(
            _ensureHoverOrMove(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
            ),
          );
          handledMove = true;
        case SieIntentKind.hoverExit:
          if (intent.targetId == null ||
              intent.targetId == _slot.hoverTargetId) {
            _slot.hoverTargetId = null;
          }
          out.addAll(
            _ensureHoverOrMove(
              timestamp: ts,
              frameSequence: seq,
              position: pos,
              source: intent.kind,
            ),
          );
          handledMove = true;
        case SieIntentKind.moveCursor:
          if (intent.phase == SieIntentPhase.stopped) {
            // No motion event required.
          } else {
            out.addAll(
              _ensureHoverOrMove(
                timestamp: ts,
                frameSequence: seq,
                position: pos,
                source: intent.kind,
              ),
            );
            handledMove = true;
          }
        case SieIntentKind.pauseSie:
        case SieIntentKind.resumeSie:
        case SieIntentKind.zoomDelta:
        case SieIntentKind.rotateDelta:
        case SieIntentKind.navigateRelative:
          break;
      }
    }

    // Cursor-driven fallback when intents didn't move.
    if (!handledMove) {
      out.addAll(
        _syncFromCursorState(cursor: cursor, allowCommit: allowCommit),
      );
    } else {
      // Still sync hover target from cursor.
      if (cursor.hoverTargetId != null) {
        _slot.hoverTargetId = cursor.hoverTargetId;
      }
    }

    _slot.position = pos;
    return (events: out, slot: _slot);
  }

  List<SiePointerEvent> _syncFromCursorState({
    required SieCursorSnapshot cursor,
    required bool allowCommit,
  }) {
    final ts = cursor.timestamp;
    final seq = cursor.frameSequence;
    final pos = cursor.position;
    switch (cursor.state) {
      case SieCursorState.moving:
      case SieCursorState.hovering:
      case SieCursorState.visible:
      case SieCursorState.armed:
      case SieCursorState.recovering:
        return _ensureHoverOrMove(
          timestamp: ts,
          frameSequence: seq,
          position: pos,
          source: null,
        );
      case SieCursorState.pressed:
        if (!allowCommit) {
          return _ensureHoverOrMove(
            timestamp: ts,
            frameSequence: seq,
            position: pos,
            source: null,
          );
        }
        return [
          ..._pointerDown(
            timestamp: ts,
            frameSequence: seq,
            position: pos,
            source: null,
          ),
          ..._movePressed(
            timestamp: ts,
            frameSequence: seq,
            position: pos,
            source: null,
          ),
        ];
      case SieCursorState.dragging:
        if (!allowCommit) {
          return _ensureHoverOrMove(
            timestamp: ts,
            frameSequence: seq,
            position: pos,
            source: null,
          );
        }
        return [
          ..._pointerDown(
            timestamp: ts,
            frameSequence: seq,
            position: pos,
            source: null,
          ),
          ..._movePressed(
            timestamp: ts,
            frameSequence: seq,
            position: pos,
            source: null,
            dragging: true,
          ),
        ];
      case SieCursorState.scrolling:
        return _ensureHoverOrMove(
          timestamp: ts,
          frameSequence: seq,
          position: pos,
          source: null,
        );
      case SieCursorState.hidden:
      case SieCursorState.paused:
      case SieCursorState.lostTracking:
        return const [];
    }
  }

  List<SiePointerEvent> _cleanup({
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required String reason,
    required bool countLost,
  }) {
    if (!_slot.added && !_slot.pressed) {
      _slot.lifecycle = SiePointerLifecycleState.absent;
      return const [];
    }
    final out = <SiePointerEvent>[];
    if (_slot.pressed && _config.cancelOnLostTracking) {
      out.addAll(
        _cancelPress(
          timestamp: timestamp,
          frameSequence: frameSequence,
          position: position,
          source: null,
          meta: {'reason': reason},
        ),
      );
    } else if (_slot.pressed) {
      out.addAll(
        _pointerUp(
          timestamp: timestamp,
          frameSequence: frameSequence,
          position: position,
          source: null,
        ),
      );
    }
    if (_slot.hovering) {
      _slot.hovering = false;
      _slot.hoverTargetId = null;
    }
    if (_config.removeOnLostTracking && _slot.added) {
      out.add(
        _event(
          kind: SiePointerEventKind.removed,
          timestamp: timestamp,
          frameSequence: frameSequence,
          position: position,
          sourceIntent: null,
          lifecycleOverride: SiePointerLifecycleState.absent,
          meta: {'reason': reason},
        ),
      );
      _slot.softReset();
      _generation++;
      _slot.pointerId = _config.basePointerId + _generation;
      _recreations++;
    }
    if (countLost) _lostCleanups++;
    return out;
  }

  List<SiePointerEvent> _cancelPress({
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required SieIntentKind? source,
    Map<String, Object?> meta = const {},
  }) {
    if (!_slot.pressed && !_slot.added) return const [];
    final out = <SiePointerEvent>[];
    if (_slot.pressed ||
        _slot.lifecycle == SiePointerLifecycleState.pressed ||
        _slot.lifecycle == SiePointerLifecycleState.dragging) {
      out.add(
        _event(
          kind: SiePointerEventKind.cancel,
          timestamp: timestamp,
          frameSequence: frameSequence,
          position: position,
          sourceIntent: source,
          lifecycleOverride: SiePointerLifecycleState.cancelled,
          meta: meta,
        ),
      );
      _slot.pressed = false;
      _slot.pressOrigin = null;
      _slot.lifecycle = SiePointerLifecycleState.cancelled;
    }
    return out;
  }

  List<SiePointerEvent> _pointerDown({
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required SieIntentKind? source,
  }) {
    if (_slot.pressed) {
      return _movePressed(
        timestamp: timestamp,
        frameSequence: frameSequence,
        position: position,
        source: source,
      );
    }
    final delta = _delta(position);
    _slot.pressed = true;
    _slot.hovering = false;
    _slot.lifecycle = SiePointerLifecycleState.pressed;
    _slot.position = position;
    _slot.pressOrigin = position;
    return [
      _event(
        kind: SiePointerEventKind.down,
        timestamp: timestamp,
        frameSequence: frameSequence,
        position: position,
        delta: delta,
        sourceIntent: source,
        buttons: SiePointerButtons.primary,
      ),
    ];
  }

  List<SiePointerEvent> _pointerUp({
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required SieIntentKind? source,
  }) {
    if (!_slot.pressed) return const [];
    final delta = _delta(position);
    _slot.pressed = false;
    _slot.pressOrigin = null;
    _slot.lifecycle = SiePointerLifecycleState.hovering;
    _slot.hovering = true;
    _slot.position = position;
    return [
      _event(
        kind: SiePointerEventKind.up,
        timestamp: timestamp,
        frameSequence: frameSequence,
        position: position,
        delta: delta,
        sourceIntent: source,
        buttons: SiePointerButtons.none,
      ),
    ];
  }

  List<SiePointerEvent> _movePressed({
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required SieIntentKind? source,
    bool dragging = false,
  }) {
    if (!_slot.pressed) return const [];

    // Tap stability: while still in "pressed" (not dragging), ignore jitter
    // below tap slop so Flutter GestureDetector onTap can win.
    final origin = _slot.pressOrigin;
    if (!dragging &&
        _slot.lifecycle == SiePointerLifecycleState.pressed &&
        origin != null) {
      final dx = position.x - origin.x;
      final dy = position.y - origin.y;
      final dist = (dx * dx + dy * dy);
      final slop = _config.tapSlopPixels;
      if (dist < slop * slop) {
        _slot.position = origin;
        return const [];
      }
    }

    final delta = _delta(position);
    if (!_moved(delta)) {
      _slot.position = position;
      return const [];
    }
    if (dragging) {
      _slot.lifecycle = SiePointerLifecycleState.dragging;
    }
    _slot.position = position;
    return [
      _event(
        kind: SiePointerEventKind.move,
        timestamp: timestamp,
        frameSequence: frameSequence,
        position: position,
        delta: delta,
        sourceIntent: source,
        buttons: SiePointerButtons.primary,
      ),
    ];
  }

  List<SiePointerEvent> _ensureHoverOrMove({
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required SieIntentKind? source,
  }) {
    if (_slot.pressed) {
      return _movePressed(
        timestamp: timestamp,
        frameSequence: frameSequence,
        position: position,
        source: source,
      );
    }
    final delta = _delta(position);
    if (!_moved(delta) && _slot.hovering) {
      _slot.position = position;
      return const [];
    }
    _slot.hovering = true;
    _slot.lifecycle = SiePointerLifecycleState.hovering;
    _slot.position = position;
    if (!_config.emitHoverWhileMoving) {
      return [
        _event(
          kind: SiePointerEventKind.move,
          timestamp: timestamp,
          frameSequence: frameSequence,
          position: position,
          delta: delta,
          sourceIntent: source,
        ),
      ];
    }
    return [
      _event(
        kind: SiePointerEventKind.hover,
        timestamp: timestamp,
        frameSequence: frameSequence,
        position: position,
        delta: delta,
        sourceIntent: source,
      ),
    ];
  }

  SieSpatialPoint2D _delta(SieSpatialPoint2D position) => SieSpatialPoint2D(
    position.x - _slot.position.x,
    position.y - _slot.position.y,
  );

  bool _moved(SieSpatialPoint2D delta) =>
      delta.x.abs() >= _config.minMoveEpsilon ||
      delta.y.abs() >= _config.minMoveEpsilon;

  SiePointerEvent _event({
    required SiePointerEventKind kind,
    required DateTime timestamp,
    required int frameSequence,
    required SieSpatialPoint2D position,
    required SieIntentKind? sourceIntent,
    SieSpatialPoint2D delta = SieSpatialPoint2D.zero,
    SieSpatialPoint2D scrollDelta = SieSpatialPoint2D.zero,
    int? buttons,
    SiePointerLifecycleState? lifecycleOverride,
    Map<String, Object?> meta = const {},
  }) {
    final btn =
        buttons ??
        (_slot.pressed ? SiePointerButtons.primary : SiePointerButtons.none);
    return SiePointerEvent(
      timestamp: timestamp,
      frameSequence: frameSequence,
      pointerId: _slot.pointerId,
      kind: kind,
      position: position,
      buttons: btn,
      lifecycle: lifecycleOverride ?? _slot.lifecycle,
      delta: delta,
      scrollDelta: scrollDelta,
      hovering: _slot.hovering,
      pressed: _slot.pressed,
      hoverTargetId: _slot.hoverTargetId,
      sourceIntent: sourceIntent,
      metadata: meta,
    );
  }

  static int _intentPriority(SieIntentKind kind) {
    return switch (kind) {
      SieIntentKind.cancel => 0,
      SieIntentKind.scrollDelta => 1,
      SieIntentKind.select ||
      SieIntentKind.selectHold ||
      SieIntentKind.selectRelease ||
      SieIntentKind.dwellSelect ||
      SieIntentKind.beginDrag ||
      SieIntentKind.updateDrag ||
      SieIntentKind.endDrag => 2,
      SieIntentKind.hoverEnter || SieIntentKind.hoverExit => 3,
      SieIntentKind.moveCursor => 4,
      _ => 9,
    };
  }
}
