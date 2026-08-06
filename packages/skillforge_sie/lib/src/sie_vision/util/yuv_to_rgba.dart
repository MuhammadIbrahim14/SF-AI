import 'dart:typed_data';

/// Converts planar YUV420 to RGBA8888 (BT.601). Used by Web MediaPipe IMAGE mode.
Uint8List yuv420ToRgba({
  required int width,
  required int height,
  required Uint8List y,
  required Uint8List u,
  required Uint8List v,
  required int yRowStride,
  required int uRowStride,
  required int vRowStride,
}) {
  final out = Uint8List(width * height * 4);
  var oi = 0;
  for (var row = 0; row < height; row++) {
    final yRow = row * yRowStride;
    final uvRow = (row >> 1) * uRowStride;
    final vvRow = (row >> 1) * vRowStride;
    for (var col = 0; col < width; col++) {
      final yy = y[yRow + col];
      final uu = u[uvRow + (col >> 1)];
      final vv = v[vvRow + (col >> 1)];
      final c = yy - 16;
      final d = uu - 128;
      final e = vv - 128;
      final r = _clamp((298 * c + 409 * e + 128) >> 8);
      final g = _clamp((298 * c - 100 * d - 208 * e + 128) >> 8);
      final b = _clamp((298 * c + 516 * d + 128) >> 8);
      out[oi++] = r;
      out[oi++] = g;
      out[oi++] = b;
      out[oi++] = 255;
    }
  }
  return out;
}

int _clamp(int v) {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return v;
}
