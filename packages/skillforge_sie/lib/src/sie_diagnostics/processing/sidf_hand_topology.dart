/// MediaPipe Hands topology helpers for SIDF visualization.
abstract final class SidfHandTopology {
  /// Bone connections (landmark index pairs).
  static const List<(int, int)> bones = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (0, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (0, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (0, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (5, 9),
    (9, 13),
    (13, 17),
  ];

  /// Fingertip landmark indices.
  static const List<int> fingertips = [4, 8, 12, 16, 20];

  /// Palm / wrist index.
  static const int wrist = 0;
}
