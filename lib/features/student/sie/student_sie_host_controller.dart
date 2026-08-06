import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Lifecycle-only logger for Student SIE host (no learning activity).
final class StudentSieHostLogger {
  /// Creates logger.
  const StudentSieHostLogger();

  /// Info lifecycle event.
  void info(String event, [Map<String, Object?>? data]) {
    if (kDebugMode) {
      debugPrint('[student.sie] $event ${data ?? const {}}');
    }
  }

  /// Warning.
  void warn(String event, [Map<String, Object?>? data]) {
    if (kDebugMode) {
      debugPrint('[student.sie][warn] $event ${data ?? const {}}');
    }
  }

  /// Error / fallback.
  void error(String event, [Map<String, Object?>? data, Object? cause]) {
    if (kDebugMode) {
      debugPrint('[student.sie][error] $event ${data ?? {}} cause=$cause');
    }
  }
}

/// Host controller — bootstraps SRDCR, PRF, and activates Student routes.
///
/// SIE is optional: failures degrade to traditional input only.
final class StudentSieHostController {
  /// Creates controller.
  StudentSieHostController({
    required this.root,
    this.logger = const StudentSieHostLogger(),
    this.segment = PrfUserSegment.betaTesters,
    this.startPipeline = false,
  });

  /// Composition root (owned by providers).
  final SrdcrPort root;

  /// Logger.
  final StudentSieHostLogger logger;

  /// Rollout segment.
  final PrfUserSegment segment;

  /// Whether to start the high-frequency camera pipeline.
  final bool startPipeline;

  bool _started = false;
  bool _available = false;
  String? _activeRouteId;
  String? _pendingRouteId;
  String? _lastFailure;
  Future<void> _queue = Future<void>.value();

  /// Whether SIE host stack is available.
  bool get isAvailable => _available;

  /// Last failure message (if any).
  String? get lastFailure => _lastFailure;

  /// Active SIE route id.
  String? get activeRouteId => _activeRouteId;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Bootstrap once for the Student Module session.
  Future<bool> ensureStarted({
    required SiePlatformKind platform,
    required String userKey,
  }) =>
      _serialized(() async {
        if (_started && _available) return true;
        if (_started && !_available) {
          if (!_isRecoverableBootstrapFailure(_lastFailure)) return false;
          _started = false;
        }
        _started = true;
        try {
          await root.bootstrap(platform: platform);
          await root.rollout.initialize(
            platform: platform,
            segment: segment,
            userKey: userKey,
            routeId: SieSkillForgeRouteCatalog.studentDashboard.routeId,
          );
          if (startPipeline) {
            try {
              await root.startRuntimePipeline();
              _lastFailure = null;
            } catch (e) {
              _lastFailure = '$e';
              logger.warn('runtime_pipeline_deferred', {'error': '$e'});
              await root.integration.notifyCapabilities(
                availability: SieInteractionAvailability.traditionalOnly,
              );
            }
          } else {
            _lastFailure = null;
          }
          // Accessibility from CPMF defaults (host may setProfiles later).
          await root.cpmf.setProfiles(const [CpmfProfileId.standard]);
          _available = true;
          logger.info('route_activation_ready', {
            'segment': segment.name,
            'platform': platform.name,
          });
          final pending = _pendingRouteId;
          if (pending != null) {
            _pendingRouteId = null;
            await _activateRouteUnlocked(pending);
          }
          return true;
        } catch (e, st) {
          _available = false;
          _lastFailure = '$e';
          if (_isRecoverableBootstrapFailure(_lastFailure)) {
            _started = false;
          }
          logger.error('integration_failed', {'phase': 'bootstrap'}, e);
          assert(() {
            debugPrint('$st');
            return true;
          }());
          return false;
        }
      });

  /// Activate SIE policy for a Student route (no-op if unavailable).
  Future<void> activateRoute(String routeId) => _serialized(() async {
        if (!_available) {
          _pendingRouteId = routeId;
          return;
        }
        await _activateRouteUnlocked(routeId);
      });

  Future<void> _activateRouteUnlocked(String routeId) async {
    if (_activeRouteId == routeId) return;
    try {
      final snap = await root.rollout.activateRoute(routeId);
      _activeRouteId = routeId;
      logger.info('route_activation', {
        'routeId': routeId,
        'sieEnabled': snap.sieEnabled,
        'decision': snap.decision.name,
      });
    } catch (e) {
      logger.error('route_activation_failed', {'routeId': routeId}, e);
      try {
        await root.integration.activateRoute(routeId);
        _activeRouteId = routeId;
      } catch (e2) {
        logger.error('policy_fallback_failed', {'routeId': routeId}, e2);
      }
    }
  }

  /// Sync accessibility preferences into Integration + CPMF.
  Future<void> applyAccessibility({
    required bool reducedMotion,
    required bool largeCursor,
    required bool highContrast,
    bool dwellMode = false,
    bool leftHanded = false,
  }) =>
      _serialized(() async {
        if (!_available) return;
        final profiles = <CpmfProfileId>[CpmfProfileId.standard];
        if (reducedMotion) profiles.add(CpmfProfileId.reducedMotion);
        if (largeCursor) profiles.add(CpmfProfileId.largeCursor);
        if (highContrast) profiles.add(CpmfProfileId.highContrast);
        if (dwellMode) profiles.add(CpmfProfileId.dwellMode);
        if (leftHanded) profiles.add(CpmfProfileId.leftHanded);
        try {
          await root.cpmf.setProfiles(profiles);
          await root.integration.setAccessibility(
            SieAccessibilityState(
              reducedMotion: reducedMotion,
              largeCursor: largeCursor,
              highContrast: highContrast,
              dwellMode: dwellMode,
            ),
          );
          logger.info('policy_changes', {
            'profiles': profiles.map((e) => e.name).toList(),
          });
        } catch (e) {
          logger.error('accessibility_sync_failed', null, e);
        }
      });

  /// Kill switch / emergency disable (or clear when [active] is false).
  Future<void> activateKillSwitch({bool active = true}) =>
      _serialized(() async {
        if (!_available) return;
        await root.rollout.activateKillSwitch(active: active);
        if (active) {
          logger.warn('fallback_events', {'event': 'kill_switch'});
        } else {
          logger.info('kill_switch_cleared');
        }
      });

  /// Apply Admin global SIE master switch (PRF + feature flag).
  Future<void> applyGlobalEnablement(bool enabled) => _serialized(() async {
        if (!_available) {
          logger.info('sie_global_pending', {'enabled': enabled});
          return;
        }
        if (enabled) {
          await root.rollout.activateKillSwitch(active: false);
          await root.rollout.setRemoteKillSwitch(active: false);
          await root.rollout.setFeatureFlag(
            PrfFeatureFlagId.enableSie,
            enabled: true,
          );
          logger.info('sie_globally_enabled');
        } else {
          await root.rollout.setFeatureFlag(
            PrfFeatureFlagId.enableSie,
            enabled: false,
          );
          await root.rollout.setRemoteKillSwitch(active: true);
          await root.rollout.activateKillSwitch(active: true);
          logger.warn('sie_globally_disabled');
        }
      });

  /// Graceful stop (Student leaves / app dispose).
  Future<void> stop() => _serialized(() async {
        if (!_started) return;
        try {
          if (_available) {
            await root.shutdown();
          }
        } catch (e) {
          logger.error('shutdown_failed', null, e);
        } finally {
          _started = false;
          _available = false;
          _activeRouteId = null;
        }
      });

  /// Wire pointer injection + viewport for live visual SIE (after pipeline start).
  Future<void> ensureVisualRuntime({
    required double viewWidth,
    required double viewHeight,
  }) =>
      _serialized(() async {
        if (!_available) return;
        try {
          root.spatial.updateViewport(
            SieViewportGeometry(
              viewWidth: viewWidth,
              viewHeight: viewHeight,
              cameraAspectRatio: 16 / 9,
            ),
          );
          // Snappy motion for live testing — high alpha, no prediction/snap lag.
          // Apply motion first, then bounds (setConfig would reset bounds).
          await root.cursor.setConfig(
            const SieCursorEngineConfig(
              motionProfile: SieCursorMotionProfileId.fast,
              motion: SieCursorMotionConfig(
                smoothingAlpha: 0.78,
                minSmoothingAlpha: 0.6,
                maxSmoothingAlpha: 0.95,
                velocityAdaptive: false,
                predictionEnabled: false,
                snapEnabled: false,
                jitterEpsilon: 0.25,
                spikeThreshold: 120,
                fadeInMs: 60,
                fadeOutMs: 100,
              ),
            ),
          );
          await root.cursor.setDisplayBounds(
            SieCursorDisplayBounds(
              width: viewWidth,
              height: viewHeight,
            ),
          );
          await root.pointer.initialize(
            injector: const GestureBindingPointerInjector(),
          );
          root.arbitration.reportClaim(
            SieInputActivityClaim(
              timestamp: DateTime.now().toUtc(),
              source: SieInputSource.sie,
              kind: SieInputActivityKind.move,
            ),
          );
          await root.integration.setLifecycle(SieAppLifecycleState.resumed);
          logger.info('visual_runtime_ready', {
            'viewWidth': viewWidth,
            'viewHeight': viewHeight,
          });
        } catch (e) {
          logger.warn('visual_runtime_deferred', {'error': '$e'});
        }
      });

  /// Retry camera + gesture pipeline after the user grants permission.
  Future<bool> retryCameraPipeline({
    required SiePlatformKind platform,
    required String userKey,
  }) =>
      _serialized(() async {
        _lastFailure = null;
        if (!_available) {
          final ok = await ensureStarted(platform: platform, userKey: userKey);
          if (!ok) return false;
        }
        if (!startPipeline) return _available;
        try {
          await root.startRuntimePipeline();
          _lastFailure = null;
          return true;
        } catch (e) {
          _lastFailure = '$e';
          logger.warn('runtime_pipeline_retry_failed', {'error': '$e'});
          return false;
        }
      });

  static bool _isRecoverableBootstrapFailure(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('permission') || lower.contains('camera');
  }

  /// Diagnostics for SIDF / host settings.
  Map<String, Object?> diagnosticsReport() => {
        'available': _available,
        'started': _started,
        'activeRouteId': _activeRouteId,
        'lastFailure': _lastFailure,
        'segment': segment.name,
        if (_available) ...root.diagnosticsReport(),
        if (_available) 'prf': root.rollout.diagnosticsReport(),
        if (_available) 'integration': root.integration.diagnosticsReport(),
      };
}
