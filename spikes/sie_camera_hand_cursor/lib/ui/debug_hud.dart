import 'package:flutter/material.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';

class DebugHud extends StatelessWidget {
  const DebugHud({super.key, required this.metrics});

  final SpikeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final latencyOk = metrics.latencyMs > 0 && metrics.latencyMs < 80;
    final latencyWarn = metrics.latencyMs >= 80 && metrics.latencyMs < 120;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xE10B1220),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF22D3EE), width: 1.2),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12.5,
              color: Color(0xFFE2E8F0),
              height: 1.35,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SIE SPIKE HUD',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22D3EE),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                _line('Platform', metrics.platform),
                _line('State', metrics.trackingState.name),
                _line('Hand', metrics.handDetected ? 'YES' : 'NO'),
                _line('Confidence', metrics.confidence.toStringAsFixed(2)),
                _line('Camera FPS', metrics.cameraFps.toStringAsFixed(1)),
                _line('Vision FPS', metrics.visionFps.toStringAsFixed(1)),
                _line('Cursor FPS', metrics.cursorFps.toStringAsFixed(1)),
                _line(
                  'Latency ms',
                  metrics.latencyMs.toStringAsFixed(1),
                  color: latencyOk
                      ? const Color(0xFF4ADE80)
                      : latencyWarn
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFF87171),
                ),
                _line('Infer ms', metrics.inferMs.toStringAsFixed(1)),
                _line('Startup ms', metrics.startupMs.toStringAsFixed(0)),
                _line('Session s', metrics.sessionSeconds.toStringAsFixed(0)),
                _line('Loss count', '${metrics.lossCount}'),
                _line(
                  'Last recover ms',
                  metrics.lastRecoveryMs.toStringAsFixed(0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: color ?? const Color(0xFFF8FAFC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
