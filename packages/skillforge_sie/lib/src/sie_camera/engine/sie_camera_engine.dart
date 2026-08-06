import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:skillforge_sie/src/sie_camera/engine/sie_camera_error_manager.dart';
import 'package:skillforge_sie/src/sie_camera/engine/sie_camera_stream_manager.dart';
import 'package:skillforge_sie/src/sie_camera/logging/sie_camera_logger.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_config.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_device_info.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_frame.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_lifecycle_state.dart';
import 'package:skillforge_sie/src/sie_camera/models/sie_camera_status.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_port.dart';
import 'package:skillforge_sie/src/sie_camera/ports/camera_platform_adapter_port.dart';
import 'package:skillforge_sie/src/sie_camera/selection/sie_camera_selection_strategy.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_core/sie_permission_status.dart';
import 'package:skillforge_sie/src/sie_platform/ports/camera_permission_port.dart';

/// Production Camera Engine implementing [CameraPort].
///
/// Owns lifecycle, selection, streaming, and recovery. Does not interpret
/// pixels or depend on MediaPipe / gestures.
final class SieCameraEngine implements CameraPort {
  /// Creates the engine.
  SieCameraEngine({
    required CameraPlatformAdapterPort adapter,
    required CameraPermissionPort permissionPort,
    SieCameraConfig config = SieCameraConfig.sieDefaults,
    SieCameraSelectionStrategy selectionStrategy =
        const SieCameraSelectionStrategy(),
    SieCameraLogger logger = const DeveloperSieCameraLogger(),
  })  : _adapter = adapter,
        _permissionPort = permissionPort,
        _config = config,
        _selection = selectionStrategy,
        _logger = logger,
        _errors = SieCameraErrorManager(logger: logger),
        _streams = SieCameraStreamManager(
          maxQueuedFrames: config.maxQueuedFrames,
        );

  final CameraPlatformAdapterPort _adapter;
  final CameraPermissionPort _permissionPort;
  final SieCameraSelectionStrategy _selection;
  final SieCameraLogger _logger;
  final SieCameraErrorManager _errors;
  final SieCameraStreamManager _streams;

  final StreamController<SieCameraStatus> _statusController =
      StreamController<SieCameraStatus>.broadcast();

  SieCameraConfig _config;
  SieCameraStatus _status = SieCameraStatus.idle();
  bool _disposed = false;

  @override
  Stream<SieCameraStatus> get status => _statusController.stream;

  @override
  Stream<SieCameraFrame> get frames => _streams.stream;

  @override
  SieCameraStatus get currentStatus => _status;

  @override
  SieCameraConfig get config => _config;

  void _emitStatus(SieCameraStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  void _setState(
    SieCameraLifecycleState state, {
    String? event,
    SieFailure? error,
    bool clearError = false,
    List<SieCameraDeviceInfo>? available,
    SieCameraDeviceInfo? selected,
    bool clearSelected = false,
  }) {
    _emitStatus(
      _status.copyWith(
        state: state,
        lastEvent: event,
        error: error,
        clearError: clearError,
        available: available,
        selected: selected,
        clearSelected: clearSelected,
        droppedFrames: _streams.droppedFrames,
        emittedFrames: _streams.emittedFrames,
      ),
    );
  }

  void _ensureNotDisposed() {
    if (_disposed || _status.state == SieCameraLifecycleState.disposed) {
      throw SieCameraLifecycleFailure(message: 'Camera engine is disposed.');
    }
  }

  Future<void> _ensurePermission() async {
    // Web: getUserMedia prompt fires when the camera adapter opens — not here.
    if (kIsWeb) return;

    final status = await _permissionPort.check();
    if (status.isGranted) return;
    final requested = await _permissionPort.request();
    if (requested.isGranted) return;
    final permanent = requested == SiePermissionStatus.permanentlyDenied ||
        requested == SiePermissionStatus.restricted;
    throw SiePermissionDeniedFailure(permanent: permanent);
  }

  @override
  Future<List<SieCameraDeviceInfo>> discover() async {
    _ensureNotDisposed();
    _setState(SieCameraLifecycleState.discovering, event: 'discover_start');
    _logger.info('discover_start');
    try {
      await _ensurePermission();
      final devices = await _adapter.listDevices();
      _setState(
        SieCameraLifecycleState.idle,
        event: 'discover_ok',
        available: List.unmodifiable(devices),
        clearError: true,
      );
      _logger.info('discover_ok', {'count': devices.length});
      return devices;
    } catch (e) {
      final failure = _errors.wrap(e, event: 'discover_failed');
      _setState(
        SieCameraLifecycleState.error,
        event: 'discover_failed',
        error: failure,
      );
      rethrow;
    }
  }

  @override
  Future<void> initialize({SieCameraConfig? config}) async {
    _ensureNotDisposed();
    if (config != null) {
      _config = config;
    }
    _logger.info('initialize_start', {
      'selection': _config.selection.name,
      'resolution': _config.resolution.name,
    });
    try {
      if (!_adapter.supportsContinuousStreaming) {
        throw SieCameraStreamingUnsupportedFailure();
      }
      await _ensurePermission();
      _setState(SieCameraLifecycleState.discovering, event: 'initialize');
      final devices = await _adapter.listDevices();
      if (devices.isEmpty) {
        throw SieCameraUnavailableFailure();
      }
      final selected = _selection.select(devices: devices, config: _config);
      if (selected == null) {
        throw SieCameraUnavailableFailure(message: 'Camera selection failed.');
      }
      if (_adapter.isOpen) {
        await _adapter.close();
      }
      await _adapter.open(selected, _config);
      _setState(
        SieCameraLifecycleState.ready,
        event: 'initialize_ok',
        available: List.unmodifiable(devices),
        selected: selected,
        clearError: true,
      );
      _logger.info('initialize_ok', {'cameraId': selected.id});
    } catch (e) {
      final failure = _errors.wrap(e, event: 'initialize_failed');
      _setState(
        SieCameraLifecycleState.error,
        event: 'initialize_failed',
        error: failure,
      );
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    _ensureNotDisposed();
    if (_status.state == SieCameraLifecycleState.streaming) return;
    if (_status.state == SieCameraLifecycleState.paused) {
      await resume();
      return;
    }
    if (_status.state != SieCameraLifecycleState.ready &&
        _status.state != SieCameraLifecycleState.error) {
      await initialize();
    }
    if (_status.state == SieCameraLifecycleState.error) {
      await initialize();
    }
    _setState(SieCameraLifecycleState.starting, event: 'start', clearError: true);
    _streams.resetCounters();
    _logger.info('stream_start');
    try {
      await _adapter.startStreaming(_onFrame);
      _setState(SieCameraLifecycleState.streaming, event: 'streaming');
      _logger.info('stream_started');
    } catch (e) {
      final failure = _errors.wrap(e, event: 'stream_start_failed');
      _setState(
        SieCameraLifecycleState.error,
        event: 'stream_start_failed',
        error: failure,
      );
      rethrow;
    }
  }

  void _onFrame(SieCameraFrame frame) {
    if (_status.state != SieCameraLifecycleState.streaming) return;
    _streams.publish(frame);
    // Throttled status: update counters occasionally via copy without spam.
    if (_streams.emittedFrames % 30 == 0) {
      _emitStatus(
        _status.copyWith(
          droppedFrames: _streams.droppedFrames,
          emittedFrames: _streams.emittedFrames,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    if (_status.state != SieCameraLifecycleState.streaming) return;
    _logger.info('stream_pause');
    try {
      await _adapter.stopStreaming();
      await _adapter.pausePreview();
      _setState(SieCameraLifecycleState.paused, event: 'paused');
    } catch (e) {
      final failure = _errors.wrap(e, event: 'pause_failed');
      _setState(SieCameraLifecycleState.error, event: 'pause_failed', error: failure);
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    _ensureNotDisposed();
    if (_status.state == SieCameraLifecycleState.streaming) return;
    if (_status.state != SieCameraLifecycleState.paused &&
        _status.state != SieCameraLifecycleState.ready) {
      throw SieCameraLifecycleFailure(
        message: 'Cannot resume from state ${_status.state.name}',
      );
    }
    _logger.info('stream_resume');
    try {
      await _adapter.resumePreview();
      _streams.resetCounters();
      await _adapter.startStreaming(_onFrame);
      _setState(SieCameraLifecycleState.streaming, event: 'resumed', clearError: true);
    } catch (e) {
      final failure = _errors.wrap(e, event: 'resume_failed');
      _setState(SieCameraLifecycleState.error, event: 'resume_failed', error: failure);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    if (_status.state == SieCameraLifecycleState.idle) return;
    _setState(SieCameraLifecycleState.stopping, event: 'stop');
    _logger.info('stream_stop');
    try {
      await _adapter.stopStreaming();
      await _adapter.close();
      _setState(
        SieCameraLifecycleState.idle,
        event: 'stopped',
        clearSelected: true,
        clearError: true,
      );
    } catch (e) {
      final failure = _errors.wrap(e, event: 'stop_failed');
      try {
        await _adapter.close();
      } catch (_) {}
      _setState(
        SieCameraLifecycleState.error,
        event: 'stop_failed',
        error: failure,
        clearSelected: true,
      );
    }
  }

  @override
  Future<void> recover() async {
    _ensureNotDisposed();
    _logger.warn('recover_start', {'state': _status.state.name});
    try {
      await _adapter.stopStreaming();
    } catch (_) {}
    try {
      await _adapter.close();
    } catch (_) {}
    await initialize(config: _config);
    await start();
    _logger.info('recover_ok');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _logger.info('dispose');
    _disposed = true;
    try {
      await _adapter.stopStreaming();
    } catch (_) {}
    try {
      await _adapter.close();
    } catch (_) {}
    await _streams.dispose();
    _setState(SieCameraLifecycleState.disposed, event: 'disposed');
    await _statusController.close();
  }
}
