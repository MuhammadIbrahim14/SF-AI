import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';

/// Persistence port for versioned calibration profiles.
///
/// Host supplies secure storage; package stays platform-independent.
abstract interface class CalibrationStorePort {
  /// Load active profile, or null if missing.
  Future<SieCalibrationProfile?> loadActive();

  /// Persist [profile] as active.
  Future<void> saveActive(SieCalibrationProfile profile);

  /// Clear active profile.
  Future<void> clearActive();

  /// Load raw JSON for migration tests / diagnostics.
  Future<Map<String, Object?>?> loadActiveRaw();

  /// Save raw JSON (used during migration writes).
  Future<void> saveActiveRaw(Map<String, Object?> json);
}

/// In-memory store for tests and hosts without persistence yet.
final class InMemoryCalibrationStore implements CalibrationStorePort {
  /// Creates an empty store.
  InMemoryCalibrationStore({SieCalibrationProfile? seed}) {
    if (seed != null) {
      _raw = seed.toJson();
    }
  }

  Map<String, Object?>? _raw;

  @override
  Future<SieCalibrationProfile?> loadActive() async {
    final raw = _raw;
    if (raw == null) return null;
    return SieCalibrationProfile.fromJson(raw);
  }

  @override
  Future<void> saveActive(SieCalibrationProfile profile) async {
    _raw = profile.toJson();
  }

  @override
  Future<void> clearActive() async {
    _raw = null;
  }

  @override
  Future<Map<String, Object?>?> loadActiveRaw() async =>
      _raw == null ? null : Map<String, Object?>.from(_raw!);

  @override
  Future<void> saveActiveRaw(Map<String, Object?> json) async {
    _raw = Map<String, Object?>.from(json);
  }
}
