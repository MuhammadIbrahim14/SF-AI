/// Deterministic latency distribution (avg / median / p95 / p99 / min / max).
final class SieLatencyDistribution {
  /// Creates distribution.
  const SieLatencyDistribution({
    required this.count,
    required this.minMs,
    required this.maxMs,
    required this.averageMs,
    required this.medianMs,
    required this.p95Ms,
    required this.p99Ms,
  });

  /// Empty.
  static const SieLatencyDistribution empty = SieLatencyDistribution(
    count: 0,
    minMs: 0,
    maxMs: 0,
    averageMs: 0,
    medianMs: 0,
    p95Ms: 0,
    p99Ms: 0,
  );

  /// Sample count.
  final int count;

  /// Minimum ms.
  final double minMs;

  /// Maximum ms.
  final double maxMs;

  /// Arithmetic mean ms.
  final double averageMs;

  /// Median (p50) ms.
  final double medianMs;

  /// 95th percentile ms.
  final double p95Ms;

  /// 99th percentile ms.
  final double p99Ms;

  /// JSON.
  Map<String, Object?> toJson() => {
        'count': count,
        'minMs': minMs,
        'maxMs': maxMs,
        'averageMs': averageMs,
        'medianMs': medianMs,
        'p95Ms': p95Ms,
        'p99Ms': p99Ms,
      };
}

/// Pure latency statistics for validation / SIDF.
abstract final class SieLatencyStats {
  /// Compute distribution from millisecond samples (copies + sorts).
  static SieLatencyDistribution fromSamples(Iterable<double> samples) {
    final list = samples.where((s) => s.isFinite && s >= 0).toList()..sort();
    if (list.isEmpty) return SieLatencyDistribution.empty;

    final n = list.length;
    var sum = 0.0;
    for (final v in list) {
      sum += v;
    }
    return SieLatencyDistribution(
      count: n,
      minMs: list.first,
      maxMs: list.last,
      averageMs: sum / n,
      medianMs: _percentile(list, 0.50),
      p95Ms: _percentile(list, 0.95),
      p99Ms: _percentile(list, 0.99),
    );
  }

  /// Nearest-rank percentile on a sorted non-empty list.
  static double _percentile(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final rank = (p * (sorted.length - 1)).clamp(0.0, (sorted.length - 1).toDouble());
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    final t = rank - lo;
    return sorted[lo] * (1 - t) + sorted[hi] * t;
  }
}
