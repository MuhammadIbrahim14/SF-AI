import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_feature_flags.dart';
import 'package:skillforge_sie/src/sie_diagnostics/processing/sidf_hand_topology.dart';
import 'package:skillforge_sie/src/sie_spatial/models/sie_spatial_geometry.dart';

/// Optional floating SIDF overlay (engineering only — [IgnorePointer]).
final class SidfDebugOverlay extends StatelessWidget {
  /// Creates overlay.
  const SidfDebugOverlay({
    required this.snapshot,
    required this.visible,
    required this.flags,
    this.config = SidfOverlayConfig.standard,
    this.memoryBytes,
    super.key,
  });

  /// Latest diagnostics.
  final SidfDiagnosticsSnapshot snapshot;

  /// Host visibility gate.
  final bool visible;

  /// Feature flags.
  final SidfFeatureFlags flags;

  /// HUD config.
  final SidfOverlayConfig config;

  /// Optional RSS / heap estimate (bytes).
  final int? memoryBytes;

  @override
  Widget build(BuildContext context) {
    if (!visible || !flags.frameworkEnabled || !flags.overlay) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: SidfVisualizationPainter(
              snapshot: snapshot,
              flags: flags,
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: SidfHudPanel(
              snapshot: snapshot,
              config: config,
              memoryBytes: memoryBytes,
            ),
          ),
          if (flags.timeline)
            Positioned(
              right: 8,
              bottom: 8,
              child: SidfTimelinePanel(events: snapshot.recentTimeline),
            ),
        ],
      ),
    );
  }
}

/// Compact HUD metrics panel.
final class SidfHudPanel extends StatelessWidget {
  /// Creates HUD.
  const SidfHudPanel({
    required this.snapshot,
    required this.config,
    this.memoryBytes,
    super.key,
  });

  /// Snapshot.
  final SidfDiagnosticsSnapshot snapshot;

  /// Config.
  final SidfOverlayConfig config;

  /// Memory bytes.
  final int? memoryBytes;

  @override
  Widget build(BuildContext context) {
    final p = snapshot.performance;
    final lines = <String>[];
    if (config.showFps) {
      lines.add(
        'UI ${p.uiFps.toStringAsFixed(0)}  '
        'Cam ${p.cameraFps.toStringAsFixed(0)}  '
        'Vis ${p.visionFps.toStringAsFixed(0)}',
      );
    }
    if (config.showLatencies) {
      lines.add(
        'E2E ${p.endToEndMs.toStringAsFixed(1)}ms '
        '(avg ${p.averageEndToEndMs.toStringAsFixed(1)})',
      );
    }
    if (config.showCursor && snapshot.cursor != null) {
      final c = snapshot.cursor!;
      lines.add(
        'Cursor (${c.position.x.toStringAsFixed(0)}, '
        '${c.position.y.toStringAsFixed(0)}) ${c.state}',
      );
    }
    if (config.showGesture && snapshot.gesture != null) {
      final g = snapshot.gesture!;
      lines.add(
        'Gesture ${g.primary ?? '-'} '
        '${(g.confidence * 100).toStringAsFixed(0)}% '
        '${g.phase ?? ''}',
      );
    }
    if (config.showConfidence) {
      lines.add('Conf ${(snapshot.confidence * 100).toStringAsFixed(0)}%');
    }
    if (config.showIntent) {
      lines.add('Intent ${snapshot.intent ?? '-'}');
    }
    if (config.showPointer) {
      lines.add('Pointer ${snapshot.pointerLifecycle ?? '-'}');
    }
    if (config.showOwner) {
      lines.add('Owner ${snapshot.inputOwner ?? '-'}');
    }
    if (config.showRoute) {
      lines.add('Route ${snapshot.route ?? '-'}');
    }
    if (config.showAccessibility && snapshot.accessibilitySummary != null) {
      lines.add('A11y ${snapshot.accessibilitySummary}');
    }
    if (config.showMemory && memoryBytes != null) {
      lines.add('Mem ${(memoryBytes! / (1024 * 1024)).toStringAsFixed(1)} MB');
    }
    if (snapshot.recording) {
      lines.add('REC');
    }

    return Opacity(
      opacity: config.opacity.clamp(0.2, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC101418),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF3A4654)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFE8EEF5),
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.35,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SIDF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7DD3FC),
                  ),
                ),
                ...lines.map(Text.new),
                const SizedBox(height: 4),
                SidfPipelineHealthStrip(stages: snapshot.stages),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact pipeline health strip.
final class SidfPipelineHealthStrip extends StatelessWidget {
  /// Creates strip.
  const SidfPipelineHealthStrip({required this.stages, super.key});

  /// Stages.
  final Map<SidfPipelineStage, SidfStageSample> stages;

  Color _color(SidfStageHealth h) => switch (h) {
        SidfStageHealth.healthy => const Color(0xFF4ADE80),
        SidfStageHealth.degraded => const Color(0xFFFBBF24),
        SidfStageHealth.error => const Color(0xFFF87171),
        SidfStageHealth.idle => const Color(0xFF64748B),
        SidfStageHealth.disabled => const Color(0xFF475569),
        SidfStageHealth.unknown => const Color(0xFF334155),
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final stage in SidfPipelineStage.values)
          Tooltip(
            message: '${stage.name}: ${stages[stage]?.health.name ?? 'unknown'}',
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _color(stages[stage]?.health ?? SidfStageHealth.unknown),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Recent timeline panel.
final class SidfTimelinePanel extends StatelessWidget {
  /// Creates panel.
  const SidfTimelinePanel({required this.events, super.key});

  /// Events (oldest → newest; show newest first).
  final List<SidfTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final recent = events.reversed.take(8).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A4654)),
      ),
      child: SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Timeline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA5B4FC),
                  ),
                ),
                for (final e in recent)
                  Text('${e.category.name}: ${e.name}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton / coordinate / cursor visualization painter.
final class SidfVisualizationPainter extends CustomPainter {
  /// Creates painter.
  SidfVisualizationPainter({
    required this.snapshot,
    required this.flags,
  });

  /// Snapshot.
  final SidfDiagnosticsSnapshot snapshot;

  /// Flags.
  final SidfFeatureFlags flags;

  @override
  void paint(Canvas canvas, Size size) {
    if (flags.skeleton && snapshot.skeleton != null) {
      _paintSkeleton(canvas, snapshot.skeleton!);
    }
    if (flags.coordinates && snapshot.coordinates != null) {
      _paintCoordinates(canvas, snapshot.coordinates!);
    }
    if (flags.cursorViz && snapshot.cursor != null) {
      _paintCursor(canvas, snapshot.cursor!);
    }
  }

  void _paintSkeleton(Canvas canvas, SidfSkeletonFrame frame) {
    final byIndex = <int, SidfLandmarkVizPoint>{
      for (final p in frame.landmarks) p.index: p,
    };
    final bonePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final (a, b) in SidfHandTopology.bones) {
      final pa = byIndex[a];
      final pb = byIndex[b];
      if (pa == null || pb == null) continue;
      canvas.drawLine(
        Offset(pa.position.x, pa.position.y),
        Offset(pb.position.x, pb.position.y),
        bonePaint,
      );
    }
    for (final p in frame.landmarks) {
      final conf = p.confidence.clamp(0.0, 1.0);
      final color = Color.lerp(
            const Color(0xFFF87171),
            const Color(0xFF4ADE80),
            conf,
          ) ??
          const Color(0xFF4ADE80);
      final isTip = SidfHandTopology.fingertips.contains(p.index);
      canvas.drawCircle(
        Offset(p.position.x, p.position.y),
        isTip ? 5 : 3,
        Paint()..color = color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${p.index}',
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.position.x + 4, p.position.y - 10));
    }
    if (frame.palmCenter != null) {
      canvas.drawCircle(
        Offset(frame.palmCenter!.x, frame.palmCenter!.y),
        6,
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (frame.boundingBox != null) {
      final b = frame.boundingBox!;
      canvas.drawRect(
        Rect.fromLTWH(b.left, b.top, b.width, b.height),
        Paint()
          ..color = const Color(0x66FBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintCoordinates(Canvas canvas, SidfCoordinateSample sample) {
    void mark(SieSpatialPoint2D? p, Color c, String label) {
      if (p == null) return;
      canvas.drawCircle(Offset(p.x, p.y), 4, Paint()..color = c);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: c, fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.x + 6, p.y - 8));
    }

    mark(sample.camera, const Color(0xFFF472B6), 'cam');
    mark(sample.normalized, const Color(0xFFA78BFA), 'norm');
    mark(sample.screen, const Color(0xFF34D399), 'scr');
    mark(sample.flutter, const Color(0xFF60A5FA), 'flt');
  }

  void _paintCursor(Canvas canvas, SidfCursorDebug cursor) {
    final origin = Offset(cursor.position.x, cursor.position.y);
    canvas.drawCircle(
      origin,
      8,
      Paint()
        ..color = const Color(0xEEF8FAFC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (cursor.snapRadius > 0) {
      canvas.drawCircle(
        origin,
        cursor.snapRadius,
        Paint()
          ..color = const Color(0x4438BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final vel = Offset(cursor.velocity.x, cursor.velocity.y);
    if (vel.distance > 0.5) {
      canvas.drawLine(
        origin,
        origin + vel,
        Paint()
          ..color = const Color(0xFF4ADE80)
          ..strokeWidth = 2,
      );
    }
    final pred = Offset(cursor.prediction.x, cursor.prediction.y);
    if (pred.distance > 0.5) {
      canvas.drawLine(
        origin,
        origin + pred,
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..strokeWidth = 1.5,
      );
    }
    final label = TextPainter(
      text: TextSpan(
        text: '${cursor.state} α=${cursor.smoothingAlpha.toStringAsFixed(2)}'
            '${cursor.hoverTargetId != null ? ' → ${cursor.hoverTargetId}' : ''}',
        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 10),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    label.paint(canvas, origin + const Offset(10, -14));
  }

  @override
  bool shouldRepaint(covariant SidfVisualizationPainter oldDelegate) {
    return !identical(oldDelegate.snapshot, snapshot) ||
        oldDelegate.flags != flags ||
        oldDelegate.snapshot.timestamp != snapshot.timestamp;
  }
}

/// Simple CPU load estimate from rolling frame intervals (0–1).
double sidfEstimateCpuLoad({
  required double averageEndToEndMs,
  double budgetMs = 16.67,
}) {
  if (budgetMs <= 0) return 0;
  return math.min(1.0, averageEndToEndMs / budgetMs);
}
