import 'package:flutter/material.dart';
import 'package:sie_camera_hand_cursor/models/spike_models.dart';

class CursorOverlayPainter extends CustomPainter {
  CursorOverlayPainter({
    required this.cursor,
    required this.landmarks,
    required this.showLandmarks,
    required this.mirrorPreview,
  });

  final CursorState cursor;
  final List<SpikeLandmark> landmarks;
  final bool showLandmarks;
  final bool mirrorPreview;

  static const _connections = <List<int>>[
    [0, 1, 2, 3, 4],
    [0, 5, 6, 7, 8],
    [0, 9, 10, 11, 12],
    [0, 13, 14, 15, 16],
    [0, 17, 18, 19, 20],
    [5, 9, 13, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (showLandmarks && landmarks.length >= 21) {
      final pts = <Offset>[];
      for (final lm in landmarks) {
        var nx = lm.x;
        if (mirrorPreview) nx = 1.0 - nx;
        pts.add(Offset(nx * size.width, lm.y * size.height));
      }
      final bone = Paint()
        ..color = const Color(0xAA22D3EE)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (final chain in _connections) {
        for (var i = 0; i < chain.length - 1; i++) {
          canvas.drawLine(pts[chain[i]], pts[chain[i + 1]], bone);
        }
      }
      final joint = Paint()..color = const Color(0xFFF8FAFC);
      for (final p in pts) {
        canvas.drawCircle(p, 3.2, joint);
      }
      canvas.drawCircle(pts[8], 6, Paint()..color = const Color(0xFFF472B6));
    }

    if (!cursor.visible) return;

    final c = Offset(cursor.x, cursor.y);
    canvas.drawCircle(
      c,
      22,
      Paint()
        ..color = const Color(0x3322D3EE)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      10,
      Paint()
        ..color = const Color(0xFF22D3EE)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(c, 4, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawCircle(
      c,
      22,
      Paint()
        ..color = const Color(0xFF22D3EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CursorOverlayPainter oldDelegate) {
    return oldDelegate.cursor.x != cursor.x ||
        oldDelegate.cursor.y != cursor.y ||
        oldDelegate.cursor.visible != cursor.visible ||
        oldDelegate.landmarks != landmarks ||
        oldDelegate.showLandmarks != showLandmarks;
  }
}
