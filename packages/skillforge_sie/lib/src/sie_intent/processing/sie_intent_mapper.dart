import 'dart:math' as math;

import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Select / drag interaction FSM state.
enum SieSelectDragState {
  /// Idle.
  idle,

  /// Select candidate / armed externally.
  candidate,

  /// Select active (pressed).
  selectActive,

  /// Drag prepared (pressed + moving toward threshold).
  dragPrepared,

  /// Dragging.
  dragging,
}

/// Maps gesture events → intent candidates + select/drag FSM.
final class SieIntentMapper {
  /// Creates mapper.
  SieIntentMapper();

  SieSelectDragState _selectDrag = SieSelectDragState.idle;
  SieSpatialPoint2D? _pressOrigin;
  SieSpatialPoint2D? _lastPosition;
  String? _lastHoverId;

  /// Last known tip position.
  SieSpatialPoint2D? get lastPosition => _lastPosition;

  /// Select/drag state.
  SieSelectDragState get selectDragState => _selectDrag;

  /// Reset FSM.
  void reset() {
    _selectDrag = SieSelectDragState.idle;
    _pressOrigin = null;
    _lastHoverId = null;
  }

  /// Map a gesture frame into candidates.
  List<SieIntentCandidate> mapFrame({
    required SieGestureFrameSnapshot frame,
    required SieIntentContext context,
  }) {
    final out = <SieIntentCandidate>[];

    // Continuous locomotion: follow index tip whenever we have a usable screen pos.
    final tip = frame.tipPosition ?? _positionFrom(frame) ?? _lastPosition;
    if (tip != null && _isUsableScreenPoint(tip)) {
      _lastPosition = tip;
      out.add(
        SieIntentCandidate(
          kind: SieIntentKind.moveCursor,
          phase: SieIntentPhase.active,
          confidence: frame.activity == SieGestureActivity.none ? 0.7 : 0.85,
          sourceGesture: 'openHandPoint',
          priority: 10,
          position: tip,
        ),
      );
    } else if (frame.activity == SieGestureActivity.none &&
        _lastPosition != null) {
      out.add(
        const SieIntentCandidate(
          kind: SieIntentKind.moveCursor,
          phase: SieIntentPhase.stopped,
          confidence: 0.5,
          sourceGesture: 'openHandPoint',
          priority: 10,
        ),
      );
    }

    // Hover transitions from context (host-driven target id).
    final hoverId = context.hoveredTargetId;
    if (hoverId != _lastHoverId) {
      if (_lastHoverId != null) {
        out.add(
          SieIntentCandidate(
            kind: SieIntentKind.hoverExit,
            phase: SieIntentPhase.completed,
            confidence: 1,
            sourceGesture: 'hover',
            priority: 9,
            targetId: _lastHoverId,
            position: _lastPosition,
          ),
        );
      }
      if (hoverId != null) {
        out.add(
          SieIntentCandidate(
            kind: SieIntentKind.hoverEnter,
            phase: SieIntentPhase.active,
            confidence: 1,
            sourceGesture: 'hover',
            priority: 9,
            targetId: hoverId,
            position: _lastPosition,
          ),
        );
      }
      _lastHoverId = hoverId;
    }

    for (final e in frame.events) {
      out.addAll(_mapEvent(e, context));
    }

    // Sort by priority ascending.
    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out;
  }

  List<SieIntentCandidate> _mapEvent(
    SieGestureEvent e,
    SieIntentContext context,
  ) {
    if (e.position != null) {
      _lastPosition = e.position;
    }
    final src = e.kind;
    switch (src) {
      case SieGestureKind.openHandPoint:
        if (e.phase == SieGesturePhase.recognized ||
            e.phase == SieGesturePhase.maintained) {
          return [
            SieIntentCandidate(
              kind: SieIntentKind.moveCursor,
              phase: SieIntentPhase.active,
              confidence: e.confidence,
              sourceGesture: src.name,
              priority: 10,
              position: e.position,
            ),
          ];
        }
        return const [];

      case SieGestureKind.pinchArm:
        // Arming is feedback-only at intent layer (no Select yet).
        return [
          SieIntentCandidate(
            kind: SieIntentKind.select,
            phase: SieIntentPhase.candidate,
            confidence: e.confidence,
            sourceGesture: src.name,
            priority: 6,
            progress: e.progress,
            position: e.position,
            targetId: context.hoveredTargetId,
            metadata: const {'armingOnly': true},
          ),
        ];

      case SieGestureKind.pinchCommit:
        _selectDrag = SieSelectDragState.selectActive;
        _pressOrigin = e.position ?? _lastPosition;
        return [
          SieIntentCandidate(
            kind: SieIntentKind.select,
            phase: SieIntentPhase.active,
            confidence: e.confidence,
            sourceGesture: src.name,
            priority: 6,
            position: e.position ?? _lastPosition,
            targetId: context.hoveredTargetId,
          ),
        ];

      case SieGestureKind.pinchHold:
        return _mapHold(e, context);

      case SieGestureKind.pinchRelease:
        return _mapRelease(e);

      case SieGestureKind.fistCancel:
        _selectDrag = SieSelectDragState.idle;
        _pressOrigin = null;
        return [
          SieIntentCandidate(
            kind: SieIntentKind.cancel,
            phase: SieIntentPhase.completed,
            confidence: e.confidence,
            sourceGesture: src.name,
            priority: 5,
            position: e.position,
          ),
        ];

      case SieGestureKind.scrollIntent:
        return [
          SieIntentCandidate(
            kind: SieIntentKind.scrollDelta,
            phase: e.phase == SieGesturePhase.completed
                ? SieIntentPhase.completed
                : SieIntentPhase.active,
            confidence: e.confidence,
            sourceGesture: src.name,
            priority: 8,
            axisDelta: e.axisDelta,
            position: e.position,
          ),
        ];

      case SieGestureKind.dwellSelect:
        return [
          SieIntentCandidate(
            kind: SieIntentKind.dwellSelect,
            phase: SieIntentPhase.active,
            confidence: e.confidence,
            sourceGesture: src.name,
            priority: 6,
            progress: e.progress,
            position: e.position,
            targetId: context.hoveredTargetId,
          ),
        ];

      case SieGestureKind.swipeNavigation:
        // Future-ready NavigateRelative — candidate only for suppression log.
        return [
          SieIntentCandidate(
            kind: SieIntentKind.navigateRelative,
            phase: SieIntentPhase.cancelled,
            confidence: e.confidence,
            sourceGesture: src.name,
            priority: 7,
            axisDelta: e.axisDelta,
            position: e.position,
          ),
        ];
    }
  }

  List<SieIntentCandidate> _mapHold(
    SieGestureEvent e,
    SieIntentContext context,
  ) {
    final pos = e.position ?? _lastPosition;
    final origin = _pressOrigin;
    if (pos != null && origin != null) {
      final dist = _dist(origin, pos);
      if (_selectDrag == SieSelectDragState.selectActive ||
          _selectDrag == SieSelectDragState.dragPrepared) {
        if (dist >= context.dragThreshold) {
          if (_selectDrag != SieSelectDragState.dragging) {
            _selectDrag = SieSelectDragState.dragging;
            return [
              SieIntentCandidate(
                kind: SieIntentKind.beginDrag,
                phase: SieIntentPhase.active,
                confidence: e.confidence,
                sourceGesture: e.kind.name,
                priority: 7,
                position: pos,
                targetId: context.hoveredTargetId,
              ),
            ];
          }
          return [
            SieIntentCandidate(
              kind: SieIntentKind.updateDrag,
              phase: SieIntentPhase.active,
              confidence: e.confidence,
              sourceGesture: e.kind.name,
              priority: 7,
              position: pos,
              targetId: context.hoveredTargetId,
            ),
          ];
        }
        if (dist >= context.dragThreshold * 0.5) {
          _selectDrag = SieSelectDragState.dragPrepared;
        }
        // Under drag threshold: pin to press origin so Flutter sees a tap, not a drag.
        return [
          SieIntentCandidate(
            kind: SieIntentKind.selectHold,
            phase: SieIntentPhase.active,
            confidence: e.confidence,
            sourceGesture: e.kind.name,
            priority: 6,
            position: origin,
            targetId: context.hoveredTargetId,
          ),
        ];
      }
      if (_selectDrag == SieSelectDragState.dragging) {
        return [
          SieIntentCandidate(
            kind: SieIntentKind.updateDrag,
            phase: SieIntentPhase.active,
            confidence: e.confidence,
            sourceGesture: e.kind.name,
            priority: 7,
            position: pos,
          ),
        ];
      }
    }
    return [
      SieIntentCandidate(
        kind: SieIntentKind.selectHold,
        phase: SieIntentPhase.active,
        confidence: e.confidence,
        sourceGesture: e.kind.name,
        priority: 6,
        position: pos,
        targetId: context.hoveredTargetId,
      ),
    ];
  }

  List<SieIntentCandidate> _mapRelease(SieGestureEvent e) {
    final wasDragging = _selectDrag == SieSelectDragState.dragging;
    final wasPressed = wasDragging ||
        _selectDrag == SieSelectDragState.selectActive ||
        _selectDrag == SieSelectDragState.dragPrepared;
    _selectDrag = SieSelectDragState.idle;
    _pressOrigin = null;

    // Tracking blip mid-press: complete the click (up) instead of cancel.
    // Cancel aborted taps and felt like "release does nothing".
    if (e.phase == SieGesturePhase.cancelled && !wasPressed) {
      return [
        SieIntentCandidate(
          kind: SieIntentKind.cancel,
          phase: SieIntentPhase.cancelled,
          confidence: e.confidence,
          sourceGesture: e.kind.name,
          priority: 5,
          position: e.position,
        ),
      ];
    }
    if (wasDragging) {
      return [
        SieIntentCandidate(
          kind: SieIntentKind.endDrag,
          phase: SieIntentPhase.completed,
          confidence: e.confidence,
          sourceGesture: e.kind.name,
          priority: 7,
          position: e.position,
        ),
      ];
    }
    return [
      SieIntentCandidate(
        kind: SieIntentKind.selectRelease,
        phase: SieIntentPhase.released,
        confidence: e.confidence,
        sourceGesture: e.kind.name,
        priority: 6,
        position: e.position ?? _lastPosition,
      ),
    ];
  }

  static SieSpatialPoint2D? _positionFrom(SieGestureFrameSnapshot frame) {
    if (frame.tipPosition != null && _isUsableScreenPoint(frame.tipPosition!)) {
      return frame.tipPosition;
    }
    for (final e in frame.events) {
      if (e.position != null && _isUsableScreenPoint(e.position!)) {
        return e.position;
      }
    }
    return null;
  }

  static bool _isUsableScreenPoint(SieSpatialPoint2D p) {
    if (!p.x.isFinite || !p.y.isFinite) return false;
    // Reject unset / normalized leftovers near the origin.
    return p.x.abs() > 1.0 || p.y.abs() > 1.0;
  }

  static double _dist(SieSpatialPoint2D a, SieSpatialPoint2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
