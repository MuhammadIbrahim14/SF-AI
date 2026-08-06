import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';
import 'package:sie_camera_hand_cursor/pipeline/cursor_mapper.dart';
import 'package:sie_camera_hand_cursor/pipeline/metrics_collector.dart';
import 'package:sie_camera_hand_cursor/platforms/spike_pipeline.dart';
import 'package:sie_camera_hand_cursor/platforms/spike_pipeline_factory.dart';
import 'package:sie_camera_hand_cursor/ui/cursor_overlay_painter.dart';
import 'package:sie_camera_hand_cursor/ui/debug_hud.dart';

class SpikeHomeScreen extends StatefulWidget {
  const SpikeHomeScreen({super.key});

  @override
  State<SpikeHomeScreen> createState() => _SpikeHomeScreenState();
}

class _SpikeHomeScreenState extends State<SpikeHomeScreen>
    with SingleTickerProviderStateMixin {
  late final SpikePipeline _pipeline;
  late final CursorMapper _mapper;
  late final MetricsCollector _metrics;

  SpikeMetrics _hud = SpikeMetrics.empty('…');
  CursorState _cursor = const CursorState(
    x: 0,
    y: 0,
    visible: false,
    rawX: 0,
    rawY: 0,
  );
  List<SpikeLandmark> _landmarks = const [];
  String? _error;
  bool _running = false;
  bool _starting = false;
  bool _showLandmarks = true;
  double _smoothing = 0.35;
  DateTime? _startWatch;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _pipeline = createSpikePipeline();
    _mapper = CursorMapper(smoothing: _smoothing, mirrorX: true);
    _metrics = MetricsCollector(_pipeline.platformId);
    _hud = SpikeMetrics.empty(_pipeline.platformId);
    _pipeline.onFrameCaptured = _metrics.markCameraFrame;
    _ticker = createTicker((_) {
      _metrics.onCursorTick();
      if (mounted) {
        setState(() {
          _hud = _metrics.build(
            state: _mapper.state,
            handDetected: _hud.handDetected,
            confidence: _hud.confidence,
            lossCount: _mapper.lossCount,
            lastRecoveryMs: _mapper.lastRecoveryMs,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _pipeline.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _running) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    _startWatch = DateTime.now();
    _mapper.reset();
    _metrics.reset();
    _metrics.markSessionStart();

    try {
      await _pipeline.start(onSample: _onSample);
      final startup = DateTime.now().difference(_startWatch!);
      _metrics.noteStartup(startup);
      _ticker?.start();
      setState(() {
        _running = true;
        _starting = false;
        _hud = _hud.copyWith(trackingState: TrackingState.searching);
      });
    } catch (e) {
      final denied = e.toString().contains('PERMISSION');
      setState(() {
        _starting = false;
        _running = false;
        _error = denied
            ? 'Camera permission denied. Enable camera and retry.'
            : 'Start failed: $e';
        _hud = _hud.copyWith(
          trackingState:
              denied ? TrackingState.permissionDenied : TrackingState.error,
        );
      });
    }
  }

  Future<void> _stop() async {
    _ticker?.stop();
    await _pipeline.stop();
    setState(() {
      _running = false;
      _cursor = const CursorState(
        x: 0,
        y: 0,
        visible: false,
        rawX: 0,
        rawY: 0,
      );
      _landmarks = const [];
      _hud = _hud.copyWith(trackingState: TrackingState.idle, handDetected: false);
    });
  }

  void _onSample(SpikeHandSample sample) {
    if (!mounted) return;
    _metrics.onVisionSample(sample);
    final size = MediaQuery.sizeOf(context);
    final cursor = _mapper.update(
      sample: sample,
      screenW: size.width,
      screenH: size.height,
    );
    setState(() {
      _cursor = cursor;
      _landmarks = sample.landmarks;
      _hud = _metrics.build(
        state: _mapper.state,
        handDetected: sample.detected,
        confidence: sample.confidence,
        lossCount: _mapper.lossCount,
        lastRecoveryMs: _mapper.lastRecoveryMs,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _pipeline.buildPreview(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (preview != null)
            Positioned.fill(child: preview)
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B1220), Color(0xFF132337), Color(0xFF0F172A)],
                ),
              ),
            ),
          // Soft veil so cursor stays readable over camera
          if (preview != null)
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: CursorOverlayPainter(
                cursor: _cursor,
                landmarks: _landmarks,
                showLandmarks: _showLandmarks && _running,
                mirrorPreview: true,
              ),
            ),
          ),
          DebugHud(metrics: _hud),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _Controls(
              running: _running,
              starting: _starting,
              showLandmarks: _showLandmarks,
              smoothing: _smoothing,
              error: _error,
              onStart: _start,
              onStop: _stop,
              onToggleLandmarks: (v) => setState(() => _showLandmarks = v),
              onSmoothing: (v) {
                setState(() {
                  _smoothing = v;
                  _mapper.smoothing = v;
                });
              },
            ),
          ),
          if (_pipeline.platformId == 'web')
            const Positioned(
              right: 12,
              top: 12,
              child: Text(
                'Web preview → bottom-right PiP',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.running,
    required this.starting,
    required this.showLandmarks,
    required this.smoothing,
    required this.error,
    required this.onStart,
    required this.onStop,
    required this.onToggleLandmarks,
    required this.onSmoothing,
  });

  final bool running;
  final bool starting;
  final bool showLandmarks;
  final double smoothing;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final ValueChanged<bool> onToggleLandmarks;
  final ValueChanged<double> onSmoothing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF00B1220),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SIE Tech Spike — Camera + Landmarks + Virtual Cursor',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Point with index fingertip. No click/drag/scroll in this spike.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Color(0xFFF87171))),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: starting || running ? null : onStart,
                  icon: starting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.videocam),
                  label: Text(starting ? 'Starting…' : 'Start'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: running ? onStop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('Landmarks'),
                  selected: showLandmarks,
                  onSelected: onToggleLandmarks,
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  'Smoothing',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: smoothing,
                    min: 0.1,
                    max: 0.9,
                    onChanged: onSmoothing,
                  ),
                ),
                Text(
                  smoothing.toStringAsFixed(2),
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
