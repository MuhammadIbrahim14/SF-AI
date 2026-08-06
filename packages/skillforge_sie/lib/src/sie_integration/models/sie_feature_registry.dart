import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';

/// Immutable feature registration entry.
final class SieIntegrationFeature {
  /// Creates feature.
  const SieIntegrationFeature({
    required this.id,
    required this.enabled,
    this.label,
  });

  /// Feature id.
  final SieIntegrationFeatureId id;

  /// Enabled.
  final bool enabled;

  /// Optional label.
  final String? label;

  /// Copy.
  SieIntegrationFeature copyWith({bool? enabled, String? label}) {
    return SieIntegrationFeature(
      id: id,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }
}

/// Feature registry — constant-time lookups.
final class SieFeatureRegistry {
  /// Creates empty registry.
  SieFeatureRegistry();

  final Map<SieIntegrationFeatureId, SieIntegrationFeature> _features = {};

  /// Register defaults.
  void registerDefaults() {
    for (final id in SieIntegrationFeatureId.values) {
      final enabled = id != SieIntegrationFeatureId.debugOverlay;
      _features[id] = SieIntegrationFeature(id: id, enabled: enabled);
    }
  }

  /// Register / replace.
  void register(SieIntegrationFeature feature) {
    _features[feature.id] = feature;
  }

  /// Enable feature.
  void setEnabled(SieIntegrationFeatureId id, {required bool enabled}) {
    final current = _features[id] ?? SieIntegrationFeature(id: id, enabled: false);
    _features[id] = current.copyWith(enabled: enabled);
  }

  /// Lookup.
  bool isEnabled(SieIntegrationFeatureId id) =>
      _features[id]?.enabled ?? false;

  /// Snapshot map.
  Map<SieIntegrationFeatureId, bool> asMap() => {
        for (final e in _features.entries) e.key: e.value.enabled,
      };

  /// All features.
  List<SieIntegrationFeature> get all =>
      List.unmodifiable(_features.values.toList(growable: false));
}
