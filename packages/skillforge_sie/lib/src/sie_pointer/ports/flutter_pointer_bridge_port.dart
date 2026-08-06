import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_bridge_status.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/pointer_injection_port.dart';

/// Flutter Pointer Bridge — sole gateway from SIE cursor/intents to pointer semantics.
///
/// Does not recognize gestures, smooth cursors, or run business logic.
abstract interface class FlutterPointerBridgePort {
  /// Low-frequency status.
  Stream<SiePointerBridgeStatus> get status;

  /// High-frequency bridge snapshots — **not** Riverpod.
  Stream<SiePointerBridgeSnapshot> get snapshots;

  /// Discrete pointer events — **not** Riverpod.
  Stream<SiePointerEvent> get events;

  /// Latest status.
  SiePointerBridgeStatus get currentStatus;

  /// Latest metrics.
  SiePointerBridgeMetrics get metrics;

  /// Config.
  SiePointerBridgeConfig get config;

  /// Active injector.
  PointerInjectionPort get injector;

  /// Prepare.
  Future<void> initialize({
    SiePointerBridgeConfig? config,
    PointerInjectionPort? injector,
  });

  /// Attach to Virtual Cursor snapshots; optional intent frames for scroll/select edges.
  Future<void> start({
    required Stream<SieCursorSnapshot> cursorSnapshots,
    Stream<SieIntentFrameSnapshot>? intentSnapshots,
  });

  /// Detach.
  Future<void> stop();

  /// Release.
  Future<void> dispose();

  /// Synchronous translate (tests / replay).
  SiePointerBridgeSnapshot process(SiePointerBridgeInput input);

  /// Update config.
  Future<void> setConfig(SiePointerBridgeConfig config);

  /// Replace injector.
  Future<void> setInjector(PointerInjectionPort injector);
}
