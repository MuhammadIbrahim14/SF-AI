import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_sensitivity_parameters.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_enums.dart';

/// Camera domain tunables (authoritative for engines).
final class CpmfCameraDomain {
  /// Creates domain.
  const CpmfCameraDomain({
    this.targetFps = 30,
    this.preferredWidth = 1280,
    this.preferredHeight = 720,
    this.preferFrontCamera = true,
  });

  /// Defaults.
  static const CpmfCameraDomain defaults = CpmfCameraDomain();

  /// Target FPS.
  final int targetFps;

  /// Preferred width.
  final int preferredWidth;

  /// Preferred height.
  final int preferredHeight;

  /// Front camera preference.
  final bool preferFrontCamera;

  /// Copy.
  CpmfCameraDomain copyWith({
    int? targetFps,
    int? preferredWidth,
    int? preferredHeight,
    bool? preferFrontCamera,
  }) {
    return CpmfCameraDomain(
      targetFps: targetFps ?? this.targetFps,
      preferredWidth: preferredWidth ?? this.preferredWidth,
      preferredHeight: preferredHeight ?? this.preferredHeight,
      preferFrontCamera: preferFrontCamera ?? this.preferFrontCamera,
    );
  }
}

/// Vision domain tunables.
final class CpmfVisionDomain {
  /// Creates domain.
  const CpmfVisionDomain({
    this.targetFps = 20,
    this.maxHands = 1,
    this.minDetectionConfidence = 0.5,
  });

  /// Defaults.
  static const CpmfVisionDomain defaults = CpmfVisionDomain();

  /// Target FPS.
  final int targetFps;

  /// Max hands (v1 = 1).
  final int maxHands;

  /// Min detection confidence.
  final double minDetectionConfidence;

  /// Copy.
  CpmfVisionDomain copyWith({
    int? targetFps,
    int? maxHands,
    double? minDetectionConfidence,
  }) {
    return CpmfVisionDomain(
      targetFps: targetFps ?? this.targetFps,
      maxHands: maxHands ?? this.maxHands,
      minDetectionConfidence:
          minDetectionConfidence ?? this.minDetectionConfidence,
    );
  }
}

/// Performance domain.
final class CpmfPerformanceDomain {
  /// Creates domain.
  const CpmfPerformanceDomain({
    this.maxEndToEndLatencyMs = 40,
    this.minUiFps = 24,
    this.minCameraFps = 15,
  });

  /// Defaults.
  static const CpmfPerformanceDomain defaults = CpmfPerformanceDomain();

  /// Max e2e latency.
  final double maxEndToEndLatencyMs;

  /// Min UI FPS.
  final double minUiFps;

  /// Min camera FPS.
  final double minCameraFps;

  /// Copy.
  CpmfPerformanceDomain copyWith({
    double? maxEndToEndLatencyMs,
    double? minUiFps,
    double? minCameraFps,
  }) {
    return CpmfPerformanceDomain(
      maxEndToEndLatencyMs: maxEndToEndLatencyMs ?? this.maxEndToEndLatencyMs,
      minUiFps: minUiFps ?? this.minUiFps,
      minCameraFps: minCameraFps ?? this.minCameraFps,
    );
  }
}

/// Security domain (IDS levels — frozen semantics).
final class CpmfSecurityDomain {
  /// Creates domain.
  const CpmfSecurityDomain({
    this.defaultLevel = SieSecurityLevel.l1Standard,
    this.disableSnapAtL3 = true,
    this.disableSelectAtL3 = true,
    this.disableSieAtL4 = true,
  });

  /// Defaults (IDS-aligned).
  static const CpmfSecurityDomain defaults = CpmfSecurityDomain();

  /// Default level when unspecified.
  final SieSecurityLevel defaultLevel;

  /// Disable snap on L3+.
  final bool disableSnapAtL3;

  /// Disable gesture select on L3+.
  final bool disableSelectAtL3;

  /// Disable SIE entirely on L4.
  final bool disableSieAtL4;
}

/// Diagnostics domain.
final class CpmfDiagnosticsDomain {
  /// Creates domain.
  const CpmfDiagnosticsDomain({
    this.sidfEnabled = false,
    this.overlayEnabled = false,
    this.structuredLogging = true,
  });

  /// Production defaults.
  static const CpmfDiagnosticsDomain production = CpmfDiagnosticsDomain();

  /// Development.
  static const CpmfDiagnosticsDomain development = CpmfDiagnosticsDomain(
    sidfEnabled: true,
    overlayEnabled: true,
  );

  /// SIDF master.
  final bool sidfEnabled;

  /// Overlay.
  final bool overlayEnabled;

  /// Structured logs.
  final bool structuredLogging;

  /// Copy.
  CpmfDiagnosticsDomain copyWith({
    bool? sidfEnabled,
    bool? overlayEnabled,
    bool? structuredLogging,
  }) {
    return CpmfDiagnosticsDomain(
      sidfEnabled: sidfEnabled ?? this.sidfEnabled,
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      structuredLogging: structuredLogging ?? this.structuredLogging,
    );
  }
}

/// Immutable multi-domain configuration bundle (authoritative for engines).
final class CpmfConfigurationBundle {
  /// Creates bundle.
  const CpmfConfigurationBundle({
    required this.version,
    required this.schemaVersion,
    required this.createdAt,
    this.compatibilityVersion = kCpmfSchemaVersion,
    this.camera = CpmfCameraDomain.defaults,
    this.vision = CpmfVisionDomain.defaults,
    this.gestures = SieGestureThresholds.standard,
    this.gesturePolicyId = SieGesturePolicyId.standard,
    this.dwellSelectEnabled = false,
    this.swipeNavigationEnabled = false,
    this.cursor = SieCursorMotionConfig.standard,
    this.cursorTheme = SieCursorThemeId.standard,
    this.confidence = SieConfidenceThresholds.standard,
    this.sensitivity = const SieSensitivityParameters(
      gain: 1.0,
      deadZoneBoost: 0,
      edgeSoftness: 0.15,
      tremorDamping: 0,
    ),
    this.handedness = SieCalibratedHandedness.auto,
    this.accessibility = SieAccessibilityState.defaults,
    this.security = CpmfSecurityDomain.defaults,
    this.performance = CpmfPerformanceDomain.defaults,
    this.diagnostics = CpmfDiagnosticsDomain.production,
    this.rolloutCanary = PrfCanaryPhase.p100,
    this.changeHistory = const [],
    this.metadata = const {},
  });

  /// Built-in standard defaults (single source of numeric truth for CPMF).
  static final CpmfConfigurationBundle builtInDefaults = CpmfConfigurationBundle(
    version: '1.0.0',
    schemaVersion: kCpmfSchemaVersion,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  /// Semantic version string.
  final String version;

  /// Schema version.
  final int schemaVersion;

  /// Creation date.
  final DateTime createdAt;

  /// Compatibility version.
  final int compatibilityVersion;

  /// Camera.
  final CpmfCameraDomain camera;

  /// Vision.
  final CpmfVisionDomain vision;

  /// Gesture thresholds.
  final SieGestureThresholds gestures;

  /// Gesture policy id.
  final SieGesturePolicyId gesturePolicyId;

  /// Dwell select.
  final bool dwellSelectEnabled;

  /// Swipe navigation.
  final bool swipeNavigationEnabled;

  /// Cursor motion.
  final SieCursorMotionConfig cursor;

  /// Cursor theme.
  final SieCursorThemeId cursorTheme;

  /// Confidence thresholds.
  final SieConfidenceThresholds confidence;

  /// Calibration sensitivity.
  final SieSensitivityParameters sensitivity;

  /// Handedness preference.
  final SieCalibratedHandedness handedness;

  /// Accessibility.
  final SieAccessibilityState accessibility;

  /// Security.
  final CpmfSecurityDomain security;

  /// Performance.
  final CpmfPerformanceDomain performance;

  /// Diagnostics.
  final CpmfDiagnosticsDomain diagnostics;

  /// Default canary phase hint for PRF.
  final PrfCanaryPhase rolloutCanary;

  /// Change history metadata.
  final List<String> changeHistory;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Gesture policy object for engines.
  SieGesturePolicy get gesturePolicy => SieGesturePolicy(
        id: gesturePolicyId,
        thresholds: gestures,
        swipeNavigationEnabled: swipeNavigationEnabled,
        dwellSelectEnabled: dwellSelectEnabled,
      );

  /// Cursor engine config fragment.
  SieCursorEngineConfig toCursorEngineConfig({
    SieCursorDisplayBounds? bounds,
    bool snapDisabledBySecurity = false,
    bool securitySensitiveRoute = false,
  }) {
    return SieCursorEngineConfig(
      theme: cursorTheme,
      motion: cursor,
      bounds: bounds ?? SieCursorDisplayBounds.fallback,
      snapDisabledBySecurity: snapDisabledBySecurity,
      securitySensitiveRoute: securitySensitiveRoute,
    );
  }

  /// Overlay [other] on top (profile inheritance). Accessibility flags OR-merge.
  CpmfConfigurationBundle overlay(CpmfConfigurationBundle other) {
    return CpmfConfigurationBundle(
      version: other.version,
      schemaVersion: other.schemaVersion,
      createdAt: other.createdAt,
      compatibilityVersion: other.compatibilityVersion,
      camera: other.camera,
      vision: other.vision,
      gestures: other.gestures,
      gesturePolicyId: other.gesturePolicyId,
      dwellSelectEnabled: dwellSelectEnabled || other.dwellSelectEnabled,
      swipeNavigationEnabled:
          swipeNavigationEnabled || other.swipeNavigationEnabled,
      cursor: other.cursor,
      cursorTheme: other.cursorTheme,
      confidence: other.confidence,
      sensitivity: other.sensitivity,
      handedness: other.handedness,
      accessibility: SieAccessibilityState(
        reducedMotion: accessibility.reducedMotion ||
            other.accessibility.reducedMotion,
        highContrast:
            accessibility.highContrast || other.accessibility.highContrast,
        largeCursor:
            accessibility.largeCursor || other.accessibility.largeCursor,
        dwellMode: accessibility.dwellMode || other.accessibility.dwellMode,
        screenReader:
            accessibility.screenReader || other.accessibility.screenReader,
        keyboardNavigation: accessibility.keyboardNavigation ||
            other.accessibility.keyboardNavigation,
      ),
      security: other.security,
      performance: other.performance,
      diagnostics: CpmfDiagnosticsDomain(
        sidfEnabled:
            diagnostics.sidfEnabled || other.diagnostics.sidfEnabled,
        overlayEnabled:
            diagnostics.overlayEnabled || other.diagnostics.overlayEnabled,
        structuredLogging: other.diagnostics.structuredLogging,
      ),
      rolloutCanary: other.rolloutCanary,
      changeHistory: [...changeHistory, ...other.changeHistory],
      metadata: {...metadata, ...other.metadata},
    );
  }

  /// Partial overlay helpers for profiles.
  CpmfConfigurationBundle copyWith({
    String? version,
    int? schemaVersion,
    DateTime? createdAt,
    int? compatibilityVersion,
    CpmfCameraDomain? camera,
    CpmfVisionDomain? vision,
    SieGestureThresholds? gestures,
    SieGesturePolicyId? gesturePolicyId,
    bool? dwellSelectEnabled,
    bool? swipeNavigationEnabled,
    SieCursorMotionConfig? cursor,
    SieCursorThemeId? cursorTheme,
    SieConfidenceThresholds? confidence,
    SieSensitivityParameters? sensitivity,
    SieCalibratedHandedness? handedness,
    SieAccessibilityState? accessibility,
    CpmfSecurityDomain? security,
    CpmfPerformanceDomain? performance,
    CpmfDiagnosticsDomain? diagnostics,
    PrfCanaryPhase? rolloutCanary,
    List<String>? changeHistory,
    Map<String, Object?>? metadata,
  }) {
    return CpmfConfigurationBundle(
      version: version ?? this.version,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      compatibilityVersion: compatibilityVersion ?? this.compatibilityVersion,
      camera: camera ?? this.camera,
      vision: vision ?? this.vision,
      gestures: gestures ?? this.gestures,
      gesturePolicyId: gesturePolicyId ?? this.gesturePolicyId,
      dwellSelectEnabled: dwellSelectEnabled ?? this.dwellSelectEnabled,
      swipeNavigationEnabled:
          swipeNavigationEnabled ?? this.swipeNavigationEnabled,
      cursor: cursor ?? this.cursor,
      cursorTheme: cursorTheme ?? this.cursorTheme,
      confidence: confidence ?? this.confidence,
      sensitivity: sensitivity ?? this.sensitivity,
      handedness: handedness ?? this.handedness,
      accessibility: accessibility ?? this.accessibility,
      security: security ?? this.security,
      performance: performance ?? this.performance,
      diagnostics: diagnostics ?? this.diagnostics,
      rolloutCanary: rolloutCanary ?? this.rolloutCanary,
      changeHistory: changeHistory ?? this.changeHistory,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Map for diagnostics (read-only).
  Map<String, Object?> toDiagnosticsMap() => {
        'version': version,
        'schemaVersion': schemaVersion,
        'compatibilityVersion': compatibilityVersion,
        'gesturePolicy': gesturePolicyId.name,
        'dwellSelect': dwellSelectEnabled,
        'cursorSnap': cursor.snapEnabled,
        'cursorSnapRadius': cursor.snapRadius,
        'smoothingAlpha': cursor.smoothingAlpha,
        'predictionEnabled': cursor.predictionEnabled,
        'handedness': handedness.name,
        'sensitivityGain': sensitivity.gain,
        'dwellMs': gestures.dwellMs,
        'pinchCommitEnter': gestures.pinchCommitEnter,
        'recoverMs': confidence.recoverMs,
        'cameraFps': camera.targetFps,
        'visionFps': vision.targetFps,
        'sidf': diagnostics.sidfEnabled,
        'reducedMotion': accessibility.reducedMotion,
        'largeCursor': accessibility.largeCursor,
        'securityDefault': security.defaultLevel.name,
      };
}

/// Platform overlay catalog.
abstract final class CpmfPlatformOverlays {
  /// Overlay for [platform].
  static CpmfConfigurationBundle? forPlatform(SiePlatformKind platform) {
    return switch (platform) {
      SiePlatformKind.web => CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: '1.0.0-web',
          camera: const CpmfCameraDomain(targetFps: 30),
          vision: const CpmfVisionDomain(targetFps: 20),
          changeHistory: const ['platform:web'],
        ),
      SiePlatformKind.android =>
        CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: '1.0.0-android',
          camera: const CpmfCameraDomain(targetFps: 30),
          vision: const CpmfVisionDomain(targetFps: 24),
          changeHistory: const ['platform:android'],
        ),
      SiePlatformKind.windows =>
        CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: '1.0.0-windows',
          vision: const CpmfVisionDomain(targetFps: 15),
          performance: const CpmfPerformanceDomain(minCameraFps: 12),
          changeHistory: const ['platform:windows'],
        ),
      SiePlatformKind.macos => CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: '1.0.0-macos',
          changeHistory: const ['platform:macos'],
        ),
      SiePlatformKind.linux => CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: '1.0.0-linux',
          diagnostics: CpmfDiagnosticsDomain.production,
          changeHistory: const ['platform:linux'],
        ),
      SiePlatformKind.ios => CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: '1.0.0-ios',
          changeHistory: const ['platform:ios'],
        ),
      SiePlatformKind.unsupported => null,
    };
  }
}

/// Environment overlay catalog.
abstract final class CpmfEnvironmentOverlays {
  /// Overlay for [env].
  static CpmfConfigurationBundle forEnvironment(CpmfEnvironment env) {
    final base = CpmfConfigurationBundle.builtInDefaults;
    return switch (env) {
      CpmfEnvironment.development => base.copyWith(
          version: '1.0.0-dev',
          diagnostics: CpmfDiagnosticsDomain.development,
          gesturePolicyId: SieGesturePolicyId.debug,
          gestures: SieGestureThresholds.debug,
          changeHistory: const ['env:development'],
        ),
      CpmfEnvironment.testing => base.copyWith(
          version: '1.0.0-test',
          diagnostics: const CpmfDiagnosticsDomain(structuredLogging: false),
          changeHistory: const ['env:testing'],
        ),
      CpmfEnvironment.qa => base.copyWith(
          version: '1.0.0-qa',
          diagnostics: CpmfDiagnosticsDomain.development,
          changeHistory: const ['env:qa'],
        ),
      CpmfEnvironment.staging => base.copyWith(
          version: '1.0.0-staging',
          changeHistory: const ['env:staging'],
        ),
      CpmfEnvironment.production => base.copyWith(
          version: '1.0.0',
          changeHistory: const ['env:production'],
        ),
      CpmfEnvironment.enterprise => base.copyWith(
          version: '1.0.0-enterprise',
          security: const CpmfSecurityDomain(
            defaultLevel: SieSecurityLevel.l2Elevated,
          ),
          changeHistory: const ['env:enterprise'],
        ),
      CpmfEnvironment.experimental => base.copyWith(
          version: '1.0.0-experimental',
          swipeNavigationEnabled: true,
          diagnostics: CpmfDiagnosticsDomain.development,
          changeHistory: const ['env:experimental'],
        ),
    };
  }
}
