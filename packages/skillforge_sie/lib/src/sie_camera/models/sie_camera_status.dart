import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lifecycle_state.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';

/// Immutable camera status snapshot for host / Riverpod (low frequency).
final class SieCameraStatus {
  /// Creates a status snapshot.
  const SieCameraStatus({
    required this.state,
    this.selected,
    this.available = const [],
    this.error,
    this.droppedFrames = 0,
    this.emittedFrames = 0,
    this.lastEvent,
  });

  /// Idle empty status.
  factory SieCameraStatus.idle() => const SieCameraStatus(
        state: SieCameraLifecycleState.idle,
      );

  /// Current lifecycle state.
  final SieCameraLifecycleState state;

  /// Selected device when known.
  final SieCameraDeviceInfo? selected;

  /// Last discovery result.
  final List<SieCameraDeviceInfo> available;

  /// Last failure if [state] is error (or soft warning).
  final SieFailure? error;

  /// Frames dropped due to back-pressure since last start.
  final int droppedFrames;

  /// Frames emitted since last start.
  final int emittedFrames;

  /// Short last lifecycle event label for diagnostics.
  final String? lastEvent;

  /// Copy with field overrides.
  SieCameraStatus copyWith({
    SieCameraLifecycleState? state,
    SieCameraDeviceInfo? selected,
    bool clearSelected = false,
    List<SieCameraDeviceInfo>? available,
    SieFailure? error,
    bool clearError = false,
    int? droppedFrames,
    int? emittedFrames,
    String? lastEvent,
  }) {
    return SieCameraStatus(
      state: state ?? this.state,
      selected: clearSelected ? null : (selected ?? this.selected),
      available: available ?? this.available,
      error: clearError ? null : (error ?? this.error),
      droppedFrames: droppedFrames ?? this.droppedFrames,
      emittedFrames: emittedFrames ?? this.emittedFrames,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}
