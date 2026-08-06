import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieCursorSnapshot _cursor({
  required SieSpatialPoint2D position,
  SieSpatialPoint2D? rawPosition,
  SieCursorState state = SieCursorState.moving,
  SieCursorVisibilityMode visibility = SieCursorVisibilityMode.visible,
  double opacity = 1,
  int sequence = 1,
  String? hoverTargetId,
  SieTrackingReliabilityState tracking = SieTrackingReliabilityState.stable,
  SieInteractionMode mode = SieInteractionMode.moving,
  DateTime? timestamp,
}) {
  return SieCursorSnapshot(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    position: position,
    rawPosition: rawPosition ?? position,
    velocity: SieSpatialPoint2D.zero,
    direction: SieSpatialPoint2D.zero,
    acceleration: 0,
    state: state,
    visibility: visibility,
    opacity: opacity,
    theme: SieCursorThemeId.standard,
    interactionMode: mode,
    trackingState: tracking,
    hoverTargetId: hoverTargetId,
  );
}

SieIntentEvent _ie({
  required SieIntentKind kind,
  SieIntentPhase phase = SieIntentPhase.active,
  SieSpatialPoint2D? position,
  double axisDelta = 0,
  String? targetId,
  int sequence = 1,
  DateTime? timestamp,
}) {
  return SieIntentEvent(
    timestamp: timestamp ?? DateTime.utc(2026, 7, 17, 12),
    frameSequence: sequence,
    kind: kind,
    phase: phase,
    sourceGesture: null,
    confidence: 1,
    trackingState: SieTrackingReliabilityState.stable,
    securityLevel: SieSecurityLevel.l1Standard,
    routeKind: SieRouteCapabilityKind.dashboard,
    policyId: SieIntentPolicyId.standard,
    position: position,
    axisDelta: axisDelta,
    targetId: targetId,
  );
}

SieFlutterPointerBridge _bridge({PointerInjectionPort? injector}) {
  return SieFlutterPointerBridge(
    logger: const NopSiePointerLogger(),
    injector: injector ?? RecordingPointerInjector(),
  );
}

void main() {
  group('Pointer Bridge — lifecycle', () {
    test('Added then hover on moveCursor', () async {
      final injector = RecordingPointerInjector();
      final bridge = _bridge(injector: injector);
      await bridge.initialize(injector: injector);
      final snap = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(100, 200)),
          intents: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(100, 200),
            ),
          ],
        ),
      );
      expect(
        snap.events.map((e) => e.kind),
        contains(SiePointerEventKind.added),
      );
      expect(
        snap.events.map((e) => e.kind),
        contains(SiePointerEventKind.hover),
      );
      expect(snap.lifecycle, SiePointerLifecycleState.hovering);
      expect(
        injector.events.any((e) => e.kind == SiePointerEventKind.added),
        isTrue,
      );
      await bridge.dispose();
    });

    test('Select → Down, SelectRelease → Up', () async {
      final bridge = _bridge();
      await bridge.initialize();
      bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(50, 50)),
          intents: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(50, 50),
            ),
          ],
        ),
      );
      final down = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(50, 50),
            state: SieCursorState.pressed,
            mode: SieInteractionMode.selecting,
            sequence: 2,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.select,
              position: const SieSpatialPoint2D(50, 50),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(
        down.events.any((e) => e.kind == SiePointerEventKind.down),
        isTrue,
      );
      expect(down.pressed, isTrue);
      expect(bridge.metrics.pointerDowns, greaterThan(0));

      final up = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(50, 50),
            state: SieCursorState.hovering,
            mode: SieInteractionMode.hovering,
            sequence: 3,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.selectRelease,
              phase: SieIntentPhase.released,
              position: const SieSpatialPoint2D(50, 50),
              sequence: 3,
            ),
          ],
        ),
      );
      expect(up.events.any((e) => e.kind == SiePointerEventKind.up), isTrue);
      expect(up.pressed, isFalse);
      await bridge.dispose();
    });

    test(
      'Injects the stabilized cursor position, never raw intent coordinates',
      () async {
        final bridge = _bridge();
        await bridge.initialize();
        const stable = SieSpatialPoint2D(120, 240);
        const rawSpike = SieSpatialPoint2D(760, 40);

        final snap = bridge.process(
          SiePointerBridgeInput(
            cursor: _cursor(
              position: stable,
              rawPosition: rawSpike,
              state: SieCursorState.pressed,
              mode: SieInteractionMode.selecting,
            ),
            intents: [
              _ie(kind: SieIntentKind.moveCursor, position: rawSpike),
              _ie(kind: SieIntentKind.select, position: rawSpike),
            ],
          ),
        );

        expect(snap.events, isNotEmpty);
        expect(snap.events.every((event) => event.position == stable), isTrue);
        expect(
          snap.events.any((event) => event.kind == SiePointerEventKind.down),
          isTrue,
        );
        await bridge.dispose();
      },
    );

    test('No duplicate Down while already pressed', () async {
      final bridge = _bridge();
      await bridge.initialize();
      bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(10, 10)),
          intents: [
            _ie(
              kind: SieIntentKind.select,
              position: const SieSpatialPoint2D(10, 10),
            ),
          ],
        ),
      );
      final again = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(12, 10),
            state: SieCursorState.pressed,
            sequence: 2,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.selectHold,
              position: const SieSpatialPoint2D(12, 10),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(
        again.events.where((e) => e.kind == SiePointerEventKind.down).length,
        0,
      );
      expect(
        again.events.any((e) => e.kind == SiePointerEventKind.move),
        isFalse,
      );
      await bridge.dispose();
    });
  });

  group('Pointer Bridge — drag & scroll', () {
    test('BeginDrag / UpdateDrag / EndDrag', () async {
      final bridge = _bridge();
      await bridge.initialize();
      bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(20, 20)),
          intents: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(20, 20),
            ),
          ],
        ),
      );
      final begin = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(30, 25),
            state: SieCursorState.dragging,
            mode: SieInteractionMode.dragging,
            sequence: 2,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.beginDrag,
              position: const SieSpatialPoint2D(30, 25),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(
        begin.events.any((e) => e.kind == SiePointerEventKind.down),
        isTrue,
      );
      expect(begin.lifecycle, SiePointerLifecycleState.dragging);

      final update = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(40, 30),
            state: SieCursorState.dragging,
            sequence: 3,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.updateDrag,
              position: const SieSpatialPoint2D(40, 30),
              sequence: 3,
            ),
          ],
        ),
      );
      expect(
        update.events.any((e) => e.kind == SiePointerEventKind.move),
        isTrue,
      );
      expect(update.pressed, isTrue);

      final end = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(45, 32),
            state: SieCursorState.hovering,
            sequence: 4,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.endDrag,
              phase: SieIntentPhase.completed,
              position: const SieSpatialPoint2D(45, 32),
              sequence: 4,
            ),
          ],
        ),
      );
      expect(end.events.any((e) => e.kind == SiePointerEventKind.up), isTrue);
      expect(end.pressed, isFalse);
      await bridge.dispose();
    });

    test('ScrollDelta → scroll event', () async {
      final bridge = _bridge();
      await bridge.initialize();
      final snap = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(100, 100),
            state: SieCursorState.scrolling,
            mode: SieInteractionMode.scrolling,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.scrollDelta,
              position: const SieSpatialPoint2D(100, 100),
              axisDelta: -40,
            ),
          ],
        ),
      );
      final scroll = snap.events
          .where((e) => e.kind == SiePointerEventKind.scroll)
          .single;
      expect(
        scroll.scrollDelta.y,
        -40 * SiePointerBridgeConfig.standard.scrollPixelsGain,
      );
      expect(bridge.metrics.scrolls, 1);
      await bridge.dispose();
    });
  });

  group('Pointer Bridge — LostTracking & Cancel', () {
    test('LostTracking cancels press and removes pointer', () async {
      final bridge = _bridge();
      await bridge.initialize();
      bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(10, 10)),
          intents: [
            _ie(
              kind: SieIntentKind.select,
              position: const SieSpatialPoint2D(10, 10),
            ),
          ],
        ),
      );
      expect(bridge.currentStatus.pressed || true, isTrue);

      final lost = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(10, 10),
            state: SieCursorState.lostTracking,
            visibility: SieCursorVisibilityMode.faded,
            opacity: 0.3,
            tracking: SieTrackingReliabilityState.lostTracking,
            mode: SieInteractionMode.blocked,
            sequence: 2,
          ),
        ),
      );
      expect(
        lost.events.any((e) => e.kind == SiePointerEventKind.cancel),
        isTrue,
      );
      expect(
        lost.events.any((e) => e.kind == SiePointerEventKind.removed),
        isTrue,
      );
      expect(lost.lifecycle, SiePointerLifecycleState.absent);
      expect(bridge.metrics.lostTrackingCleanups, greaterThan(0));
      await bridge.dispose();
    });

    test('Cancel intent cancels press without remove', () async {
      final bridge = _bridge();
      await bridge.initialize();
      bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(5, 5)),
          intents: [
            _ie(
              kind: SieIntentKind.select,
              position: const SieSpatialPoint2D(5, 5),
            ),
          ],
        ),
      );
      final cancel = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(5, 5), sequence: 2),
          intents: [
            _ie(
              kind: SieIntentKind.cancel,
              phase: SieIntentPhase.completed,
              position: const SieSpatialPoint2D(5, 5),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(
        cancel.events.any((e) => e.kind == SiePointerEventKind.cancel),
        isTrue,
      );
      expect(
        cancel.events.any((e) => e.kind == SiePointerEventKind.removed),
        isFalse,
      );
      await bridge.dispose();
    });

    test('Recovering suppresses new Down from Select', () async {
      final bridge = _bridge();
      await bridge.initialize();
      bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(1, 1)),
          intents: [
            _ie(
              kind: SieIntentKind.moveCursor,
              position: const SieSpatialPoint2D(1, 1),
            ),
          ],
        ),
      );
      final rec = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(
            position: const SieSpatialPoint2D(2, 2),
            state: SieCursorState.recovering,
            visibility: SieCursorVisibilityMode.recovering,
            opacity: 0.7,
            tracking: SieTrackingReliabilityState.recovering,
            sequence: 2,
          ),
          intents: [
            _ie(
              kind: SieIntentKind.select,
              position: const SieSpatialPoint2D(2, 2),
              sequence: 2,
            ),
          ],
        ),
      );
      expect(
        rec.events.any((e) => e.kind == SiePointerEventKind.down),
        isFalse,
      );
      await bridge.dispose();
    });

    test(
      'Pointer recreated after LostTracking with new id generation',
      () async {
        final bridge = _bridge();
        await bridge.initialize();
        final first = bridge.process(
          SiePointerBridgeInput(
            cursor: _cursor(position: const SieSpatialPoint2D(8, 8)),
            intents: [
              _ie(
                kind: SieIntentKind.moveCursor,
                position: const SieSpatialPoint2D(8, 8),
              ),
            ],
          ),
        );
        final id1 = first.pointerId;
        bridge.process(
          SiePointerBridgeInput(
            cursor: _cursor(
              position: const SieSpatialPoint2D(8, 8),
              state: SieCursorState.lostTracking,
              visibility: SieCursorVisibilityMode.faded,
              opacity: 0.2,
              sequence: 2,
            ),
          ),
        );
        final again = bridge.process(
          SiePointerBridgeInput(
            cursor: _cursor(
              position: const SieSpatialPoint2D(9, 9),
              sequence: 3,
            ),
            intents: [
              _ie(
                kind: SieIntentKind.moveCursor,
                position: const SieSpatialPoint2D(9, 9),
                sequence: 3,
              ),
            ],
          ),
        );
        expect(
          again.events.any((e) => e.kind == SiePointerEventKind.added),
          isTrue,
        );
        expect(again.pointerId, isNot(id1));
        expect(bridge.metrics.pointerRecreations, greaterThan(0));
        await bridge.dispose();
      },
    );
  });

  group('Pointer Bridge — mapper & performance', () {
    test('Mapper maps all kinds', () {
      final ts = DateTime.utc(2026, 7, 17, 12);
      SiePointerEvent ev(SiePointerEventKind kind, {double dy = 0}) {
        return SiePointerEvent(
          timestamp: ts,
          frameSequence: 1,
          pointerId: 900001,
          kind: kind,
          position: const SieSpatialPoint2D(10, 20),
          buttons:
              kind == SiePointerEventKind.down ||
                  kind == SiePointerEventKind.move
              ? SiePointerButtons.primary
              : SiePointerButtons.none,
          lifecycle: SiePointerLifecycleState.hovering,
          scrollDelta: SieSpatialPoint2D(0, dy),
        );
      }

      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.added)),
        isA<PointerAddedEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.hover)),
        isA<PointerHoverEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.move)),
        isA<PointerMoveEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.down)),
        isA<PointerDownEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.up)),
        isA<PointerUpEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.cancel)),
        isA<PointerCancelEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(
          ev(SiePointerEventKind.scroll, dy: 1),
        ),
        isA<PointerScrollEvent>(),
      );
      expect(
        SieFlutterPointerEventMapper.toFlutter(ev(SiePointerEventKind.removed)),
        isA<PointerRemovedEvent>(),
      );
    });

    test('Deterministic identical inputs', () async {
      final a = _bridge();
      final b = _bridge();
      await a.initialize();
      await b.initialize();
      final input = SiePointerBridgeInput(
        cursor: _cursor(position: const SieSpatialPoint2D(33, 44)),
        intents: [
          _ie(
            kind: SieIntentKind.moveCursor,
            position: const SieSpatialPoint2D(33, 44),
          ),
        ],
      );
      final sa = a.process(input);
      final sb = b.process(input);
      expect(
        sa.events.map((e) => e.kind).toList(),
        sb.events.map((e) => e.kind).toList(),
      );
      expect(sa.position, sb.position);
      await a.dispose();
      await b.dispose();
    });

    test('200 frames under soft budget', () async {
      final bridge = _bridge();
      await bridge.initialize();
      final t0 = DateTime.utc(2026, 7, 17, 12);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        bridge.process(
          SiePointerBridgeInput(
            cursor: _cursor(
              position: SieSpatialPoint2D(100 + i * 0.5, 200),
              sequence: i,
              timestamp: t0.add(Duration(milliseconds: 16 * i)),
            ),
            intents: [
              _ie(
                kind: SieIntentKind.moveCursor,
                position: SieSpatialPoint2D(100 + i * 0.5, 200),
                sequence: i,
                timestamp: t0.add(Duration(milliseconds: 16 * i)),
              ),
            ],
          ),
        );
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
      expect(bridge.metrics.averageProcessingMs, lessThan(5));
      await bridge.dispose();
    });

    test('Stream start delivers snapshots', () async {
      final bridge = _bridge();
      await bridge.initialize();
      final controller = StreamController<SieCursorSnapshot>();
      final received = <SiePointerBridgeSnapshot>[];
      final sub = bridge.snapshots.listen(received.add);
      await bridge.start(cursorSnapshots: controller.stream);
      controller.add(_cursor(position: const SieSpatialPoint2D(1, 1)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isNotEmpty);
      await sub.cancel();
      await controller.close();
      await bridge.dispose();
    });

    test('Invalid NaN coordinates yield empty recoverable snapshot', () async {
      final bridge = _bridge();
      await bridge.initialize();
      final snap = bridge.process(
        SiePointerBridgeInput(
          cursor: _cursor(position: const SieSpatialPoint2D(double.nan, 1)),
        ),
      );
      expect(snap.events, isEmpty);
      expect(bridge.currentStatus.health, SiePointerBridgeHealth.degraded);
      await bridge.dispose();
    });
  });
}
