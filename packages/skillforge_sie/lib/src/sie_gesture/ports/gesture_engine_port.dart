import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_snapshot.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_engine_status.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_event.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';

/// Gesture Engine port — authoritative gesture recognition.
///
/// Purpose: classify IDS gestures only (no cursor / intents / UI).
/// Inputs: [SieConfidenceFrameSnapshot] from Confidence Engine.
/// Outputs: [SieGestureEvent] / [SieGestureFrameSnapshot] streams (not Riverpod).
abstract interface class GestureEnginePort {
  /// Low-frequency status.
  Stream<SieGestureEngineStatus> get status;

  /// High-frequency frame snapshots — **not** Riverpod (ADR-008).
  Stream<SieGestureFrameSnapshot> get snapshots;

  /// Discrete gesture events — **not** Riverpod.
  Stream<SieGestureEvent> get events;

  /// Latest status.
  SieGestureEngineStatus get currentStatus;

  /// Latest metrics.
  SieGestureEngineMetrics get metrics;

  /// Active policy.
  SieGesturePolicy get policy;

  /// Prepare engine.
  Future<void> initialize({SieGesturePolicy? policy});

  /// Attach to Confidence Engine snapshots.
  Future<void> start(Stream<SieConfidenceFrameSnapshot> confidenceSnapshots);

  /// Detach.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous evaluate for tests / replay.
  SieGestureFrameSnapshot process(SieConfidenceFrameSnapshot input);

  /// Switch policy.
  Future<void> setPolicy(SieGesturePolicy policy);
}
