import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_context.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_engine_status.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';

/// Intent Engine port — sole authority for gesture → interaction intent semantics.
///
/// Purpose: produce immutable [SieIntentEvent]s only (no PointerEvents / UI).
/// Inputs: [SieGestureFrameSnapshot] / [SieGestureEvent] from Gesture Engine.
/// Outputs: intent event / snapshot streams (not Riverpod — ADR-008).
abstract interface class IntentEnginePort {
  /// Low-frequency status.
  Stream<SieIntentEngineStatus> get status;

  /// High-frequency frame snapshots — **not** Riverpod.
  Stream<SieIntentFrameSnapshot> get snapshots;

  /// Discrete actionable (+ optional suppression diagnostic) events — **not** Riverpod.
  Stream<SieIntentEvent> get events;

  /// Latest status.
  SieIntentEngineStatus get currentStatus;

  /// Latest metrics.
  SieIntentEngineMetrics get metrics;

  /// Active context.
  SieIntentContext get context;

  /// Active intent policy.
  SieIntentPolicy get policy;

  /// Prepare engine.
  Future<void> initialize({
    SieIntentContext? context,
    SieIntentPolicy? policy,
  });

  /// Attach to Gesture Engine snapshots.
  Future<void> start(Stream<SieGestureFrameSnapshot> gestureSnapshots);

  /// Detach.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous evaluate for tests / replay.
  SieIntentFrameSnapshot process(SieGestureFrameSnapshot input);

  /// Update interaction context (route / security / hover / pause).
  Future<void> updateContext(SieIntentContext context);

  /// Switch intent policy.
  Future<void> setPolicy(SieIntentPolicy policy);

  /// Emit PauseSIE (host / session).
  Future<void> pauseSession();

  /// Emit ResumeSIE (host / session).
  Future<void> resumeSession();
}
