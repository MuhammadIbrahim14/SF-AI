import 'package:skillforge_sie/src/sie_config/sie_feature_flags.dart';
import 'package:skillforge_sie/src/sie_config/sie_feature_id.dart';

/// Mutable façade for feature flags with immutable snapshots.
///
/// Purpose: configure module availability without editing engine logic.
/// Inputs: overrides per [SieFeatureId].
/// Outputs: [SieFeatureFlags] snapshots.
/// Failure behavior: none — unknown features cannot be set.
final class SieFeatureFlagService {
  /// Creates the service with [initial] flags (defaults when null).
  SieFeatureFlagService({SieFeatureFlags? initial})
      : _flags = initial ?? SieFeatureFlags.defaults();

  SieFeatureFlags _flags;

  /// Current immutable snapshot.
  SieFeatureFlags get flags => _flags;

  /// Returns whether [id] is enabled.
  bool isEnabled(SieFeatureId id) => _flags.isEnabled(id);

  /// Enables or disables a single feature.
  void setEnabled(SieFeatureId id, {required bool enabled}) {
    _flags = _flags.copyWithOverrides({id: enabled});
  }

  /// Applies many overrides at once.
  void applyOverrides(Map<SieFeatureId, bool> overrides) {
    _flags = _flags.copyWithOverrides(overrides);
  }

  /// Resets to package defaults.
  void resetToDefaults() {
    _flags = SieFeatureFlags.defaults();
  }

  /// Disables all features (unsupported / kill switch helper).
  void disableAll() {
    _flags = SieFeatureFlags.allDisabled();
  }
}
