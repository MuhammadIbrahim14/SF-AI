import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_profile.dart';

/// Migrates calibration documents across schema versions.
final class SieCalibrationMigrator {
  /// Creates migrator.
  const SieCalibrationMigrator();

  /// Migrate [json] to [kSieCalibrationSchemaVersion].
  ///
  /// Throws [FormatException] when unsupported or corrupt.
  SieCalibrationProfile migrate(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version is! num) {
      throw const FormatException('Missing schemaVersion');
    }
    final v = version.toInt();
    if (v < 1) {
      throw FormatException('Unsupported schema version: $v');
    }
    if (v > kSieCalibrationSchemaVersion) {
      throw FormatException(
        'Unsupported future schema version: $v '
        '(max $kSieCalibrationSchemaVersion)',
      );
    }
    // v1 is current; future versions append transforms here.
    var doc = Map<String, Object?>.from(json);
    if (v < kSieCalibrationSchemaVersion) {
      // Placeholder for v1 → v2… migrations.
      doc['schemaVersion'] = kSieCalibrationSchemaVersion;
    }
    final profile = SieCalibrationProfile.fromJson(doc);
    if (!profile.isValid) {
      throw const FormatException('Migrated profile failed validation');
    }
    return profile;
  }
}
