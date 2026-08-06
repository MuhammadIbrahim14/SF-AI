/// Immutable 2D point in a named coordinate space.
final class SieSpatialPoint2D {
  /// Creates a point.
  const SieSpatialPoint2D(this.x, this.y);

  /// Origin.
  static const SieSpatialPoint2D zero = SieSpatialPoint2D(0, 0);

  /// X component.
  final double x;

  /// Y component.
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SieSpatialPoint2D && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'SieSpatialPoint2D($x, $y)';
}

/// Axis-aligned rectangle in logical pixels.
final class SieSpatialRect {
  /// Creates a rect.
  const SieSpatialRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Left edge.
  final double left;

  /// Top edge.
  final double top;

  /// Width.
  final double width;

  /// Height.
  final double height;

  /// Right edge.
  double get right => left + width;

  /// Bottom edge.
  double get bottom => top + height;

  /// Whether [p] is inside (inclusive edges).
  bool contains(SieSpatialPoint2D p) =>
      p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;
}
