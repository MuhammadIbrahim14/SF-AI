import 'package:flutter/foundation.dart';

/// Independent SIDF feature toggles (all off in release by default).
final class SidfFeatureFlags {
  /// Creates flags.
  const SidfFeatureFlags({
    this.frameworkEnabled = false,
    this.overlay = false,
    this.skeleton = false,
    this.coordinates = false,
    this.cursorViz = false,
    this.timeline = false,
    this.performanceGraphs = false,
    this.logging = false,
    this.recording = false,
  });

  /// All disabled (release-safe).
  static const SidfFeatureFlags disabled = SidfFeatureFlags();

  /// Debug profile — full toolkit (never auto-applied in release).
  static const SidfFeatureFlags debugAll = SidfFeatureFlags(
    frameworkEnabled: true,
    overlay: true,
    skeleton: true,
    coordinates: true,
    cursorViz: true,
    timeline: true,
    performanceGraphs: true,
    logging: true,
    recording: true,
  );

  /// Profile for profile/debug builds only.
  factory SidfFeatureFlags.forBuildMode({bool forceEnable = false}) {
    if (kReleaseMode && !forceEnable) return disabled;
    if (forceEnable || kDebugMode) {
      return debugAll.copyWith(recording: false); // recording opt-in
    }
    return disabled;
  }

  /// Master switch.
  final bool frameworkEnabled;

  /// Floating overlay.
  final bool overlay;

  /// Landmark skeleton.
  final bool skeleton;

  /// Coordinate stage viz.
  final bool coordinates;

  /// Cursor viz.
  final bool cursorViz;

  /// Event timeline.
  final bool timeline;

  /// Perf graphs.
  final bool performanceGraphs;

  /// Structured logging.
  final bool logging;

  /// Session recording.
  final bool recording;

  /// Whether any observation should run.
  bool get isObserving => frameworkEnabled;

  /// Copy.
  SidfFeatureFlags copyWith({
    bool? frameworkEnabled,
    bool? overlay,
    bool? skeleton,
    bool? coordinates,
    bool? cursorViz,
    bool? timeline,
    bool? performanceGraphs,
    bool? logging,
    bool? recording,
  }) {
    return SidfFeatureFlags(
      frameworkEnabled: frameworkEnabled ?? this.frameworkEnabled,
      overlay: overlay ?? this.overlay,
      skeleton: skeleton ?? this.skeleton,
      coordinates: coordinates ?? this.coordinates,
      cursorViz: cursorViz ?? this.cursorViz,
      timeline: timeline ?? this.timeline,
      performanceGraphs: performanceGraphs ?? this.performanceGraphs,
      logging: logging ?? this.logging,
      recording: recording ?? this.recording,
    );
  }
}

/// Overlay panel configuration.
final class SidfOverlayConfig {
  /// Creates config.
  const SidfOverlayConfig({
    this.showFps = true,
    this.showLatencies = true,
    this.showCursor = true,
    this.showGesture = true,
    this.showConfidence = true,
    this.showIntent = true,
    this.showPointer = true,
    this.showOwner = true,
    this.showRoute = true,
    this.showAccessibility = false,
    this.showMemory = false,
    this.opacity = 0.85,
  });

  /// Defaults.
  static const SidfOverlayConfig standard = SidfOverlayConfig();

  /// FPS.
  final bool showFps;

  /// Latencies.
  final bool showLatencies;

  /// Cursor.
  final bool showCursor;

  /// Gesture.
  final bool showGesture;

  /// Confidence.
  final bool showConfidence;

  /// Intent.
  final bool showIntent;

  /// Pointer.
  final bool showPointer;

  /// Owner.
  final bool showOwner;

  /// Route.
  final bool showRoute;

  /// A11y.
  final bool showAccessibility;

  /// Memory.
  final bool showMemory;

  /// Overlay opacity.
  final double opacity;
}
