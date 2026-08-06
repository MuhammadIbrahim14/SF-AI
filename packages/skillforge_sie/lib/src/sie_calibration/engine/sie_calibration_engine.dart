import 'dart:async';

import 'package:skillforge_sie/src/sie_calibration/logging/sie_calibration_logger.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibrated_snapshot.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_engine_status.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_session.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_camera_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_display_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_handedness_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_interaction_zone_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_user_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/persistence/calibration_store_port.dart';
import 'package:skillforge_sie/src/sie_calibration/persistence/sie_calibration_migrator.dart';
import 'package:skillforge_sie/src/sie_calibration/ports/calibration_engine_port.dart';
import 'package:skillforge_sie/src/sie_calibration/processing/sie_calibration_transform_pipeline.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_frame_snapshot.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Production Calibration Engine — personalizes spatial coordinates.
///
/// Does not classify gestures or drive the cursor.
final class SieCalibrationEngine implements CalibrationEnginePort {
  /// Creates the engine.
  SieCalibrationEngine({
    CalibrationStorePort? store,
    SieCalibrationLogger logger = const DeveloperSieCalibrationLogger(),
    SieCalibrationMigrator migrator = const SieCalibrationMigrator(),
    SieCalibrationTransformPipeline pipeline =
        const SieCalibrationTransformPipeline(),
  })  : _store = store ?? InMemoryCalibrationStore(),
        _logger = logger,
        _migrator = migrator,
        _pipeline = pipeline;

  final CalibrationStorePort _store;
  final SieCalibrationLogger _logger;
  final SieCalibrationMigrator _migrator;
  final SieCalibrationTransformPipeline _pipeline;

  final StreamController<SieCalibrationEngineStatus> _statusController =
      StreamController<SieCalibrationEngineStatus>.broadcast();
  final StreamController<SieCalibratedFrameSnapshot> _snapshotController =
      StreamController<SieCalibratedFrameSnapshot>.broadcast();

  StreamSubscription<SieSpatialFrameSnapshot>? _sub;
  SieCalibrationEngineStatus _status = SieCalibrationEngineStatus.idle();
  SieCalibrationEngineMetrics _metrics = const SieCalibrationEngineMetrics();
  SieCalibrationProfile _profile = SieCalibrationProfile.identity();
  SieCalibrationSession? _session;
  final List<double> _processingSamples = [];
  bool _disposed = false;
  bool _persistedLoaded = false;

  @override
  Stream<SieCalibrationEngineStatus> get status => _statusController.stream;

  @override
  Stream<SieCalibratedFrameSnapshot> get snapshots =>
      _snapshotController.stream;

  @override
  SieCalibrationEngineStatus get currentStatus => _status;

  @override
  SieCalibrationEngineMetrics get metrics => _metrics;

  @override
  SieCalibrationProfile get activeProfile => _profile;

  void _emitStatus(SieCalibrationEngineStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  SieCalibrationAvailability _availabilityFor(SieCalibrationProfile p) {
    if (_session != null &&
        _session!.phase != SieCalibrationSessionPhase.idle &&
        _session!.phase != SieCalibrationSessionPhase.complete &&
        _session!.phase != SieCalibrationSessionPhase.failed) {
      return SieCalibrationAvailability.calibrating;
    }
    if (p.isIdentity) return SieCalibrationAvailability.defaults;
    return SieCalibrationAvailability.ready;
  }

  @override
  Future<void> initialize({bool loadPersisted = true}) async {
    _ensureNotDisposed();
    if (loadPersisted) {
      await load();
    } else if (!_persistedLoaded) {
      _profile = SieCalibrationProfile.identity();
    }
    _logger.info('engine_initialized', {
      'profileId': _profile.profileId,
      'identity': _profile.isIdentity,
    });
    _emitStatus(
      _status.copyWith(
        health: _profile.isValid
            ? (_profile.isIdentity
                ? SieCalibrationEngineHealth.degraded
                : SieCalibrationEngineHealth.healthy)
            : SieCalibrationEngineHealth.degraded,
        initialized: true,
        running: false,
        availability: _availabilityFor(_profile),
        activeProfile: _profile,
        sessionPhase: SieCalibrationSessionPhase.idle,
        lastEvent: 'initialized',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> start(Stream<SieSpatialFrameSnapshot> spatialSnapshots) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _sub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: _profile.isIdentity
            ? SieCalibrationEngineHealth.degraded
            : SieCalibrationEngineHealth.healthy,
        availability: _availabilityFor(_profile),
        activeProfile: _profile,
        lastEvent: 'started',
        clearError: true,
      ),
    );
    _sub = spatialSnapshots.listen(
      (frame) {
        final snap = process(frame);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('spatial_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SieCalibrationEngineHealth.error,
            lastError: SieCalibrationEngineFailure(
              message: e.toString(),
              cause: e,
            ),
            lastEvent: 'spatial_stream_error',
          ),
        );
      },
    );
  }

  @override
  SieCalibratedFrameSnapshot process(SieSpatialFrameSnapshot input) {
    final sw = Stopwatch()..start();
    try {
      final viewW = input.viewport.viewWidth;
      final viewH = input.viewport.viewHeight;
      final profile = _session?.draft ?? _profile;

      if (input.hands.isEmpty) {
        final empty = SieCalibratedFrameSnapshot.empty(
          timestamp: input.timestamp,
          frameSequence: input.frameSequence,
          visionTrackingState: input.visionTrackingState,
          profile: profile,
          processingMs: sw.elapsedMicroseconds / 1000.0,
          viewWidth: viewW,
          viewHeight: viewH,
        );
        _noteProcessed(empty.processingMs, 0);
        return empty;
      }

      final hands = <SieCalibratedHandSnapshot>[
        for (final hand in input.hands)
          _pipeline.transformHand(
            hand: hand,
            profile: profile,
            viewWidth: viewW,
            viewHeight: viewH,
          ),
      ];
      var landmarkCount = 0;
      for (final h in hands) {
        landmarkCount += h.landmarks.length;
      }

      final processingMs = sw.elapsedMicroseconds / 1000.0;
      _noteProcessed(processingMs, landmarkCount);

      return SieCalibratedFrameSnapshot(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.visionTrackingState,
        profile: profile,
        hands: List.unmodifiable(hands),
        processingMs: processingMs,
        viewWidth: viewW,
        viewHeight: viewH,
      );
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SieCalibrationEngineHealth.degraded,
          lastError: SieCalibrationEngineFailure(
            message: e.toString(),
            cause: e,
          ),
          lastEvent: 'process_anomaly',
        ),
      );
      return SieCalibratedFrameSnapshot.empty(
        timestamp: input.timestamp,
        frameSequence: input.frameSequence,
        visionTrackingState: input.visionTrackingState,
        profile: _profile,
        processingMs: sw.elapsedMicroseconds / 1000.0,
        viewWidth: input.viewport.viewWidth,
        viewHeight: input.viewport.viewHeight,
      );
    }
  }

  void _noteProcessed(double processingMs, int landmarkCount) {
    _processingSamples.add(processingMs);
    if (_processingSamples.length > 60) {
      _processingSamples.removeAt(0);
    }
    final avg = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;
    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      landmarksCalibrated: _metrics.landmarksCalibrated + landmarkCount,
      lastProcessingMs: processingMs,
      averageProcessingMs: avg,
    );
  }

  @override
  Future<void> beginSession({
    SieCalibrationSessionPhase phase =
        SieCalibrationSessionPhase.firstRun,
  }) async {
    _ensureNotDisposed();
    if (!_status.initialized) await initialize();
    final now = DateTime.now().toUtc();
    _session = SieCalibrationSession(
      phase: phase,
      startedAt: now,
      baseline: _profile,
    );
    _logger.info('calibration_created', {
      'phase': phase.name,
      'profileId': _session!.draft.profileId,
    });
    _emitStatus(
      _status.copyWith(
        sessionPhase: phase,
        availability: SieCalibrationAvailability.calibrating,
        activeProfile: _profile,
        lastEvent: 'session_started',
        clearError: true,
      ),
    );
  }

  void _requireSession() {
    if (_session == null) {
      throw SieCalibrationEngineFailure(
        message: 'No active calibration session',
      );
    }
  }

  @override
  Future<void> updateUserCalibration(SieUserCalibration user) async {
    _ensureNotDisposed();
    if (!user.isValid) {
      throw SieCalibrationEngineFailure(message: 'Invalid user calibration');
    }
    if (_session != null) {
      _session!.applyUser(user);
      _logger.info('calibration_updated', {'section': 'user'});
      return;
    }
    await applyProfile(
      _profile.copyWith(
        user: user,
        updatedAt: DateTime.now().toUtc(),
        isIdentity: false,
      ),
    );
  }

  @override
  Future<void> updateCameraCalibration(SieCameraCalibration camera) async {
    _ensureNotDisposed();
    if (!camera.isValid) {
      throw SieCalibrationEngineFailure(message: 'Invalid camera calibration');
    }
    if (_session != null) {
      _session!.applyCamera(camera);
      _logger.info('calibration_updated', {'section': 'camera'});
      return;
    }
    await applyProfile(
      _profile.copyWith(
        camera: camera,
        updatedAt: DateTime.now().toUtc(),
        isIdentity: false,
      ),
    );
  }

  @override
  Future<void> updateDisplayCalibration(SieDisplayCalibration display) async {
    _ensureNotDisposed();
    if (!display.isValid) {
      throw SieCalibrationEngineFailure(message: 'Invalid display calibration');
    }
    if (_session != null) {
      _session!.applyDisplay(display);
      _logger.info('calibration_updated', {'section': 'display'});
      return;
    }
    await applyProfile(
      _profile.copyWith(
        display: display,
        updatedAt: DateTime.now().toUtc(),
        isIdentity: false,
      ),
    );
  }

  @override
  Future<void> updateHandednessCalibration(
    SieHandednessCalibration handedness,
  ) async {
    _ensureNotDisposed();
    if (_session != null) {
      _session!.applyHandedness(handedness);
      _logger.info('calibration_updated', {'section': 'handedness'});
      return;
    }
    await applyProfile(
      _profile.copyWith(
        handedness: handedness,
        updatedAt: DateTime.now().toUtc(),
        isIdentity: false,
      ),
    );
  }

  @override
  Future<void> updateInteractionZone(
    SieInteractionZoneCalibration zone,
  ) async {
    _ensureNotDisposed();
    if (!zone.isValid) {
      throw SieCalibrationEngineFailure(message: 'Invalid interaction zone');
    }
    if (_session != null) {
      _session!.applyInteractionZone(zone);
      _logger.info('calibration_updated', {'section': 'interactionZone'});
      return;
    }
    await applyProfile(
      _profile.copyWith(
        interactionZone: zone,
        updatedAt: DateTime.now().toUtc(),
        isIdentity: false,
      ),
    );
  }

  @override
  Future<void> setSensitivityProfile(SieSensitivityProfileId profile) async {
    _ensureNotDisposed();
    if (_session != null) {
      _session!.applySensitivity(profile);
      _logger.info('profile_changed', {'sensitivity': profile.name});
      return;
    }
    _logger.info('profile_changed', {'sensitivity': profile.name});
    await applyProfile(
      _profile.copyWith(
        sensitivity: profile,
        updatedAt: DateTime.now().toUtc(),
        isIdentity: false,
      ),
    );
  }

  @override
  void recordSessionSample(SieSpatialPoint2D normalizedPoint) {
    _ensureNotDisposed();
    _requireSession();
    _session!.recordSample(normalizedPoint);
  }

  @override
  Future<SieCalibrationProfile> completeSession({bool persist = true}) async {
    _ensureNotDisposed();
    _requireSession();
    final session = _session!;
    session.phase = SieCalibrationSessionPhase.validating;
    _emitStatus(
      _status.copyWith(
        sessionPhase: SieCalibrationSessionPhase.validating,
        lastEvent: 'validating',
      ),
    );

    if (!session.isDraftValid || !session.validateSamples()) {
      session.phase = SieCalibrationSessionPhase.failed;
      _logger.warn('calibration_updated', {'result': 'validation_failed'});
      _emitStatus(
        _status.copyWith(
          sessionPhase: SieCalibrationSessionPhase.failed,
          health: SieCalibrationEngineHealth.degraded,
          lastError: SieCalibrationEngineFailure(
            message: 'Calibration session validation failed',
          ),
          lastEvent: 'session_failed',
        ),
      );
      throw SieCalibrationEngineFailure(
        message: 'Calibration session validation failed',
      );
    }

    final completed = session.draft.copyWith(
      validated: true,
      isIdentity: false,
      updatedAt: DateTime.now().toUtc(),
      schemaVersion: kSieCalibrationSchemaVersion,
    );
    _session = null;
    await applyProfile(completed, persist: persist);
    _metrics = _metrics.copyWith(
      sessionCompletions: _metrics.sessionCompletions + 1,
    );
    _logger.info('calibration_updated', {
      'result': 'complete',
      'profileId': completed.profileId,
    });
    _emitStatus(
      _status.copyWith(
        sessionPhase: SieCalibrationSessionPhase.complete,
        availability: SieCalibrationAvailability.ready,
        activeProfile: _profile,
        health: SieCalibrationEngineHealth.healthy,
        lastEvent: 'session_complete',
        clearError: true,
        clearRecalibration: true,
      ),
    );
    return completed;
  }

  @override
  Future<void> cancelSession() async {
    _ensureNotDisposed();
    if (_session == null) return;
    _session = null;
    _logger.info('calibration_updated', {'result': 'cancelled'});
    _emitStatus(
      _status.copyWith(
        sessionPhase: SieCalibrationSessionPhase.failed,
        availability: _availabilityFor(_profile),
        activeProfile: _profile,
        lastEvent: 'session_cancelled',
      ),
    );
  }

  @override
  Future<void> applyProfile(
    SieCalibrationProfile profile, {
    bool persist = true,
  }) async {
    _ensureNotDisposed();
    if (!profile.isValid) {
      throw SieCalibrationEngineFailure(message: 'Invalid calibration profile');
    }
    _profile = profile;
    if (persist && !profile.isIdentity) {
      await save();
    }
    _logger.info('calibration_updated', {
      'profileId': profile.profileId,
      'sensitivity': profile.sensitivity.name,
    });
    _emitStatus(
      _status.copyWith(
        activeProfile: _profile,
        availability: _availabilityFor(_profile),
        health: profile.isIdentity
            ? SieCalibrationEngineHealth.degraded
            : SieCalibrationEngineHealth.healthy,
        lastEvent: 'profile_applied',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> resetProfile({bool persist = true}) async {
    _ensureNotDisposed();
    _session = null;
    _profile = SieCalibrationProfile.identity(now: DateTime.now().toUtc());
    if (persist) {
      await _store.clearActive();
      _logger.info('calibration_reset');
    }
    _emitStatus(
      _status.copyWith(
        activeProfile: _profile,
        availability: SieCalibrationAvailability.defaults,
        sessionPhase: SieCalibrationSessionPhase.idle,
        health: SieCalibrationEngineHealth.degraded,
        lastEvent: 'reset',
        clearError: true,
        clearRecalibration: true,
      ),
    );
  }

  @override
  Future<void> save() async {
    _ensureNotDisposed();
    try {
      await _store.saveActive(_profile);
      _metrics = _metrics.copyWith(profileSaves: _metrics.profileSaves + 1);
      _logger.info('calibration_updated', {'persist': 'save'});
    } catch (e) {
      _logger.error('persist_error', null, e);
      throw SieCalibrationEngineFailure(
        message: 'Failed to save calibration',
        cause: e,
      );
    }
  }

  @override
  Future<SieCalibrationProfile?> load() async {
    _ensureNotDisposed();
    try {
      final raw = await _store.loadActiveRaw();
      if (raw == null) {
        _profile = SieCalibrationProfile.identity();
        _persistedLoaded = true;
        return null;
      }
      final migrated = _migrator.migrate(raw);
      if ((raw['schemaVersion'] as num?)?.toInt() !=
          migrated.schemaVersion) {
        await _store.saveActive(migrated);
        _metrics = _metrics.copyWith(migrations: _metrics.migrations + 1);
        _logger.info('schema_migration', {
          'from': raw['schemaVersion'],
          'to': migrated.schemaVersion,
        });
      }
      _profile = migrated;
      _persistedLoaded = true;
      _metrics = _metrics.copyWith(profileLoads: _metrics.profileLoads + 1);
      _logger.info('calibration_updated', {
        'persist': 'load',
        'profileId': migrated.profileId,
      });
      return migrated;
    } on FormatException catch (e) {
      _logger.warn('mapping_error', {'reason': e.message});
      _profile = SieCalibrationProfile.identity();
      _persistedLoaded = true;
      recommendRecalibration(SieRecalibrationReason.missingOrCorrupt);
      _emitStatus(
        _status.copyWith(
          health: SieCalibrationEngineHealth.degraded,
          availability: SieCalibrationAvailability.missing,
          activeProfile: _profile,
          lastError: SieCalibrationEngineFailure(
            message: 'Corrupted calibration data: ${e.message}',
            cause: e,
          ),
          lastEvent: 'load_corrupt',
        ),
      );
      return null;
    } catch (e) {
      _logger.error('persist_error', null, e);
      throw SieCalibrationEngineFailure(
        message: 'Failed to load calibration',
        cause: e,
      );
    }
  }

  @override
  void recommendRecalibration(SieRecalibrationReason reason) {
    _ensureNotDisposed();
    _metrics = _metrics.copyWith(
      recalibrationRequests: _metrics.recalibrationRequests + 1,
    );
    _logger.info('recalibration_requested', {'reason': reason.name});
    _emitStatus(
      _status.copyWith(
        recalibrationRecommended: true,
        recalibrationReason: reason,
        lastEvent: 'recalibration_recommended',
      ),
    );
  }

  @override
  void clearRecalibrationRecommendation() {
    _ensureNotDisposed();
    _emitStatus(
      _status.copyWith(
        clearRecalibration: true,
        lastEvent: 'recalibration_cleared',
      ),
    );
  }

  @override
  void notifyEnvironmentChange(SieRecalibrationReason reason) {
    // Never silently alter calibration during interaction.
    recommendRecalibration(reason);
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _sub?.cancel();
    _sub = null;
    _logger.info('engine_stopped');
    _emitStatus(
      _status.copyWith(
        running: false,
        health: SieCalibrationEngineHealth.healthy,
        lastEvent: 'stopped',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    _session = null;
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SieCalibrationEngineHealth.disposed,
        running: false,
        initialized: false,
        lastEvent: 'disposed',
      ),
    );
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieCalibrationEngineFailure(
        message: 'Calibration engine is disposed.',
      );
    }
  }
}
