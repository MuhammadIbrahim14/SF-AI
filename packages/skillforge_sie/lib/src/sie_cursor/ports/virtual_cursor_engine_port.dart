import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_engine_status.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';

/// Virtual Cursor Engine port — sole authority for cursor state.
///
/// Purpose: maintain smoothed cursor model from intents (no PointerEvents / UI).
/// Inputs: [SieIntentFrameSnapshot] from Intent Engine.
/// Outputs: [SieCursorSnapshot] stream (not Riverpod — ADR-008).
abstract interface class VirtualCursorEnginePort {
  /// Low-frequency status.
  Stream<SieCursorEngineStatus> get status;

  /// High-frequency cursor snapshots — **not** Riverpod.
  Stream<SieCursorSnapshot> get snapshots;

  /// Latest status.
  SieCursorEngineStatus get currentStatus;

  /// Latest metrics.
  SieCursorEngineMetrics get metrics;

  /// Active config.
  SieCursorEngineConfig get config;

  /// Latest snapshot (may be null before first frame).
  SieCursorSnapshot? get latestSnapshot;

  /// Prepare engine.
  Future<void> initialize({SieCursorEngineConfig? config});

  /// Attach to Intent Engine snapshots.
  Future<void> start(Stream<SieIntentFrameSnapshot> intentSnapshots);

  /// Detach.
  Future<void> stop();

  /// Release resources.
  Future<void> dispose();

  /// Synchronous evaluate for tests / replay.
  SieCursorSnapshot process(SieIntentFrameSnapshot input);

  /// Update config (theme / motion / bounds / security snap).
  Future<void> setConfig(SieCursorEngineConfig config);

  /// Update display bounds (resize / multi-resolution).
  Future<void> setDisplayBounds(SieCursorDisplayBounds bounds);

  /// Update snap targets from host hit-test (optional).
  Future<void> setSnapTargets(List<SieCursorSnapTarget> targets);

  /// Switch appearance theme only.
  Future<void> setTheme(SieCursorThemeId theme);

  /// Switch motion profile (replaces motion tunables from preset).
  Future<void> setMotionProfile(SieCursorMotionProfileId profile);
}
