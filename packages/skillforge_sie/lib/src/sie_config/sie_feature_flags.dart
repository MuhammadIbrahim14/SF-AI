import 'package:skillforge_sie/src/sie_config/sie_feature_id.dart';

/// Immutable feature-flag map for SIE modules.
///
/// Purpose: gate modules independently of engine internals.
/// Inputs: per-feature booleans (package defaults → app overrides).
/// Outputs: [isEnabled] queries.
/// Failure behavior: unknown ids are not representable; missing keys use
/// [defaultsFor] construction.
final class SieFeatureFlags {
  /// Creates flags from an explicit map (copied).
  SieFeatureFlags(Map<SieFeatureId, bool> values)
      : _values = Map<SieFeatureId, bool>.unmodifiable(
          Map<SieFeatureId, bool>.from(values),
        );

  /// Production defaults: core interaction on; debug overlay off.
  factory SieFeatureFlags.defaults() {
    return SieFeatureFlags({
      for (final id in SieFeatureId.values)
        id: id != SieFeatureId.debugOverlay,
    });
  }

  /// All features disabled (safe for unsupported platforms).
  factory SieFeatureFlags.allDisabled() {
    return SieFeatureFlags({
      for (final id in SieFeatureId.values) id: false,
    });
  }

  final Map<SieFeatureId, bool> _values;

  /// Returns whether [id] is enabled (defaults to `false` if absent).
  bool isEnabled(SieFeatureId id) => _values[id] ?? false;

  /// Copy with selective overrides.
  SieFeatureFlags copyWithOverrides(Map<SieFeatureId, bool> overrides) {
    final next = Map<SieFeatureId, bool>.from(_values);
    next.addAll(overrides);
    return SieFeatureFlags(next);
  }

  /// Unmodifiable view of all flags.
  Map<SieFeatureId, bool> get asMap => _values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SieFeatureFlags &&
          _mapEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(
        SieFeatureId.values.map((id) => Object.hash(id, _values[id])),
      );

  static bool _mapEquals(Map<SieFeatureId, bool> a, Map<SieFeatureId, bool> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
