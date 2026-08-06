import 'dart:async';

import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_event.dart';
import 'package:skillforge_sie/src/sie_pointer/logging/sie_pointer_logger.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_bridge_status.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_enums.dart';
import 'package:skillforge_sie/src/sie_pointer/models/sie_pointer_event.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/flutter_pointer_bridge_port.dart';
import 'package:skillforge_sie/src/sie_pointer/ports/pointer_injection_port.dart';
import 'package:skillforge_sie/src/sie_pointer/processing/sie_pointer_translator.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Production Flutter Pointer Bridge.
///
/// Translates Virtual Cursor + Intent snapshots into Flutter-compatible pointer
/// events. Never synthesizes gestures or UI business logic.
final class SieFlutterPointerBridge implements FlutterPointerBridgePort {
  /// Creates the bridge.
  SieFlutterPointerBridge({
    SiePointerBridgeConfig config = SiePointerBridgeConfig.standard,
    PointerInjectionPort injector = const NopPointerInjector(),
    SiePointerLogger logger = const DeveloperSiePointerLogger(),
  })  : _logger = logger,
        _injector = injector,
        _translator = SiePointerTranslator(config: config);

  final SiePointerLogger _logger;
  final SiePointerTranslator _translator;
  PointerInjectionPort _injector;

  final StreamController<SiePointerBridgeStatus> _statusController =
      StreamController<SiePointerBridgeStatus>.broadcast();
  final StreamController<SiePointerBridgeSnapshot> _snapshotController =
      StreamController<SiePointerBridgeSnapshot>.broadcast();
  final StreamController<SiePointerEvent> _eventController =
      StreamController<SiePointerEvent>.broadcast();

  StreamSubscription<SieCursorSnapshot>? _cursorSub;
  StreamSubscription<SieIntentFrameSnapshot>? _intentSub;
  SieIntentFrameSnapshot? _latestIntents;
  SiePointerBridgeStatus _status = SiePointerBridgeStatus.idle();
  SiePointerBridgeMetrics _metrics = const SiePointerBridgeMetrics();
  final List<double> _processingSamples = [];
  bool _disposed = false;
  SiePointerLifecycleState? _prevLifecycle;

  @override
  Stream<SiePointerBridgeStatus> get status => _statusController.stream;

  @override
  Stream<SiePointerBridgeSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<SiePointerEvent> get events => _eventController.stream;

  @override
  SiePointerBridgeStatus get currentStatus => _status;

  @override
  SiePointerBridgeMetrics get metrics => _metrics;

  @override
  SiePointerBridgeConfig get config => _translator.config;

  @override
  PointerInjectionPort get injector => _injector;

  void _emitStatus(SiePointerBridgeStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  @override
  Future<void> initialize({
    SiePointerBridgeConfig? config,
    PointerInjectionPort? injector,
  }) async {
    _ensureNotDisposed();
    if (config != null) {
      _translator.setConfig(config);
    }
    if (injector != null) {
      _injector = injector;
    }
    _translator.reset();
    _metrics = const SiePointerBridgeMetrics();
    _latestIntents = null;
    _prevLifecycle = null;
    _logger.info('engine_initialized', {
      'pointerId': _translator.config.basePointerId,
    });
    _emitStatus(
      SiePointerBridgeStatus(
        health: SiePointerBridgeHealth.healthy,
        initialized: true,
        running: false,
        lifecycle: SiePointerLifecycleState.absent,
        pointerId: _translator.config.basePointerId,
        lastEvent: 'initialized',
      ),
    );
  }

  @override
  Future<void> start({
    required Stream<SieCursorSnapshot> cursorSnapshots,
    Stream<SieIntentFrameSnapshot>? intentSnapshots,
  }) async {
    _ensureNotDisposed();
    if (!_status.initialized) {
      await initialize();
    }
    await _cursorSub?.cancel();
    await _intentSub?.cancel();
    _logger.info('engine_started');
    _emitStatus(
      _status.copyWith(
        running: true,
        health: SiePointerBridgeHealth.healthy,
        lastEvent: 'started',
        clearError: true,
      ),
    );

    if (intentSnapshots != null) {
      _intentSub = intentSnapshots.listen(
        (frame) => _latestIntents = frame,
        onError: (Object e, StackTrace st) {
          _logger.error('intent_stream_error', null, e);
        },
      );
    }

    _cursorSub = cursorSnapshots.listen(
      (cursor) {
        final intents = _intentsFor(cursor);
        final snap = process(
          SiePointerBridgeInput(cursor: cursor, intents: intents),
        );
        if (!_snapshotController.isClosed) {
          _snapshotController.add(snap);
        }
        for (final e in snap.events) {
          if (!_eventController.isClosed) {
            _eventController.add(e);
          }
        }
      },
      onError: (Object e, StackTrace st) {
        _logger.error('cursor_stream_error', null, e);
        _emitStatus(
          _status.copyWith(
            health: SiePointerBridgeHealth.error,
            lastError:
                SiePointerBridgeFailure(message: e.toString(), cause: e),
            lastEvent: 'cursor_stream_error',
          ),
        );
      },
    );
  }

  List<SieIntentEvent> _intentsFor(SieCursorSnapshot cursor) {
    final frame = _latestIntents;
    if (frame == null) return const [];
    if (frame.frameSequence == cursor.frameSequence) {
      return frame.actionable;
    }
    // Allow closely paired frames (cursor may process slightly later).
    if ((frame.frameSequence - cursor.frameSequence).abs() <= 1) {
      return frame.actionable;
    }
    return const [];
  }

  @override
  SiePointerBridgeSnapshot process(SiePointerBridgeInput input) {
    final sw = Stopwatch()..start();
    try {
      if (!_isFinite(input.cursor.position)) {
        throw SiePointerBridgeFailure(
          message: 'Invalid cursor coordinates',
        );
      }
      final result = _translator.translate(input);
      final processingMs = sw.elapsedMicroseconds / 1000.0;
      final slot = result.slot;
      final snap = SiePointerBridgeSnapshot(
        timestamp: input.cursor.timestamp,
        frameSequence: input.cursor.frameSequence,
        pointerId: slot.added ? slot.pointerId : 0,
        lifecycle: slot.lifecycle,
        position: slot.position,
        buttons: slot.pressed
            ? SiePointerButtons.primary
            : SiePointerButtons.none,
        hovering: slot.hovering,
        pressed: slot.pressed,
        events: result.events,
        processingMs: processingMs,
        hoverTargetId: slot.hoverTargetId,
        cursor: input.cursor,
        sourceIntents: input.intents,
        metadata: {
          'recreations': _translator.recreations,
          'lostCleanups': _translator.lostCleanups,
        },
      );

      _noteProcessed(snap);
      _logSignificant(snap);
      _maybeUpdateStatus(snap);

      if (_translator.config.injectEnabled && snap.events.isNotEmpty) {
        unawaited(_safeInject(snap.events));
      }

      return snap;
    } catch (e) {
      _logger.error('process_anomaly', null, e);
      _emitStatus(
        _status.copyWith(
          health: SiePointerBridgeHealth.degraded,
          lastError: SiePointerBridgeFailure(message: e.toString(), cause: e),
          lastEvent: 'process_anomaly',
        ),
      );
      return SiePointerBridgeSnapshot(
        timestamp: input.cursor.timestamp,
        frameSequence: input.cursor.frameSequence,
        pointerId: 0,
        lifecycle: SiePointerLifecycleState.absent,
        position: input.cursor.position,
        buttons: SiePointerButtons.none,
        hovering: false,
        pressed: false,
        events: const [],
        processingMs: sw.elapsedMicroseconds / 1000.0,
        cursor: input.cursor,
        sourceIntents: input.intents,
      );
    }
  }

  Future<void> _safeInject(List<SiePointerEvent> events) async {
    try {
      await _injector.inject(events);
    } catch (e) {
      _logger.error('inject_failed', null, e);
      _emitStatus(
        _status.copyWith(
          health: SiePointerBridgeHealth.degraded,
          lastError: SiePointerBridgeFailure(message: e.toString(), cause: e),
          lastEvent: 'inject_failed',
        ),
      );
    }
  }

  void _noteProcessed(SiePointerBridgeSnapshot snap) {
    _processingSamples.add(snap.processingMs);
    if (_processingSamples.length > 60) _processingSamples.removeAt(0);
    final avg = _processingSamples.reduce((a, b) => a + b) /
        _processingSamples.length;

    var downs = _metrics.pointerDowns;
    var ups = _metrics.pointerUps;
    var scrolls = _metrics.scrolls;
    var drags = _metrics.dragsStarted;
    for (final e in snap.events) {
      switch (e.kind) {
        case SiePointerEventKind.down:
          downs++;
        case SiePointerEventKind.up:
          ups++;
        case SiePointerEventKind.scroll:
          scrolls++;
        case SiePointerEventKind.move:
          if (e.sourceIntent == SieIntentKind.beginDrag) {
            drags++;
          }
        default:
          break;
      }
    }

    _metrics = _metrics.copyWith(
      framesProcessed: _metrics.framesProcessed + 1,
      eventsEmitted: _metrics.eventsEmitted + snap.events.length,
      pointerDowns: downs,
      pointerUps: ups,
      scrolls: scrolls,
      dragsStarted: drags,
      pointerRecreations: _translator.recreations,
      lostTrackingCleanups: _translator.lostCleanups,
      averageProcessingMs: avg,
      lastProcessingMs: snap.processingMs,
    );
  }

  void _logSignificant(SiePointerBridgeSnapshot snap) {
    for (final e in snap.events) {
      switch (e.kind) {
        case SiePointerEventKind.added:
          _logger.info('pointer_created', {'id': e.pointerId});
        case SiePointerEventKind.removed:
          _logger.info('pointer_removed', {
            'id': e.pointerId,
            'reason': e.metadata['reason'],
          });
        case SiePointerEventKind.down:
          _logger.info('pointer_down', {
            'id': e.pointerId,
            'x': e.position.x,
            'y': e.position.y,
          });
        case SiePointerEventKind.up:
          _logger.info('pointer_up', {'id': e.pointerId});
        case SiePointerEventKind.scroll:
          _logger.info('scroll_started', {
            'dy': e.scrollDelta.y,
          });
        case SiePointerEventKind.cancel:
          _logger.info('lost_tracking_cleanup', {
            'id': e.pointerId,
            'reason': e.metadata['reason'],
          });
        case SiePointerEventKind.move:
          if (e.lifecycle == SiePointerLifecycleState.dragging &&
              e.sourceIntent == SieIntentKind.beginDrag) {
            _logger.info('drag_started', {'id': e.pointerId});
          }
        case SiePointerEventKind.hover:
          break;
      }
    }
  }

  void _maybeUpdateStatus(SiePointerBridgeSnapshot snap) {
    if (snap.lifecycle != _prevLifecycle ||
        snap.pressed != _status.pressed ||
        snap.hovering != _status.hovering) {
      _prevLifecycle = snap.lifecycle;
      _emitStatus(
        _status.copyWith(
          lifecycle: snap.lifecycle,
          pointerId: snap.pointerId,
          hovering: snap.hovering,
          pressed: snap.pressed,
          health: SiePointerBridgeHealth.healthy,
          lastEvent: 'pointer_state',
        ),
      );
    }
  }

  @override
  Future<void> setConfig(SiePointerBridgeConfig config) async {
    _ensureNotDisposed();
    _translator.setConfig(config);
    _logger.info('config_changed', {'pointerId': config.basePointerId});
  }

  @override
  Future<void> setInjector(PointerInjectionPort injector) async {
    _ensureNotDisposed();
    _injector = injector;
    _logger.info('injector_changed');
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await _cursorSub?.cancel();
    await _intentSub?.cancel();
    _cursorSub = null;
    _intentSub = null;
    _logger.info('engine_stopped');
    _emitStatus(
      _status.copyWith(
        running: false,
        health: SiePointerBridgeHealth.healthy,
        lastEvent: 'stopped',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _cursorSub?.cancel();
    await _intentSub?.cancel();
    _cursorSub = null;
    _intentSub = null;
    _translator.reset();
    _logger.info('engine_shutdown');
    _emitStatus(
      _status.copyWith(
        health: SiePointerBridgeHealth.disposed,
        running: false,
        initialized: false,
        lifecycle: SiePointerLifecycleState.absent,
        lastEvent: 'disposed',
      ),
    );
    await _eventController.close();
    await _snapshotController.close();
    await _statusController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SiePointerBridgeFailure(message: 'Pointer bridge is disposed.');
    }
  }

  static bool _isFinite(SieSpatialPoint2D p) =>
      p.x.isFinite && p.y.isFinite;
}
