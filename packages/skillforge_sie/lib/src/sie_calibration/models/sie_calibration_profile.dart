import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_camera_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_display_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_handedness_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_interaction_zone_calibration.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_sensitivity_parameters.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_user_calibration.dart';

/// Current calibration document schema version.
const int kSieCalibrationSchemaVersion = 1;

/// Immutable versioned calibration profile (single source of truth).
final class SieCalibrationProfile {
  /// Creates a profile.
  const SieCalibrationProfile({
    required this.profileId,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.sensitivity,
    required this.user,
    required this.camera,
    required this.display,
    required this.handedness,
    required this.interactionZone,
    this.validated = false,
    this.isIdentity = false,
  });

  /// Platform-independent identity defaults (optional calibration).
  factory SieCalibrationProfile.identity({
    DateTime? now,
    String profileId = 'identity',
  }) {
    final t = now ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return SieCalibrationProfile(
      profileId: profileId,
      schemaVersion: kSieCalibrationSchemaVersion,
      createdAt: t,
      updatedAt: t,
      sensitivity: SieSensitivityProfileId.standard,
      user: SieUserCalibration.identity,
      camera: SieCameraCalibration.identity,
      display: SieDisplayCalibration.identity,
      handedness: SieHandednessCalibration.identity,
      interactionZone: SieInteractionZoneCalibration.identity,
      validated: true,
      isIdentity: true,
    );
  }

  /// Stable profile id.
  final String profileId;

  /// Schema version for migration.
  final int schemaVersion;

  /// Creation time (UTC recommended).
  final DateTime createdAt;

  /// Last update time.
  final DateTime updatedAt;

  /// Active sensitivity profile.
  final SieSensitivityProfileId sensitivity;

  /// User / reach calibration.
  final SieUserCalibration user;

  /// Camera placement calibration.
  final SieCameraCalibration camera;

  /// Display calibration.
  final SieDisplayCalibration display;

  /// Handedness calibration.
  final SieHandednessCalibration handedness;

  /// Interaction zone.
  final SieInteractionZoneCalibration interactionZone;

  /// Whether a guided session validated this profile.
  final bool validated;

  /// Whether this is the identity / defaults profile.
  final bool isIdentity;

  /// Resolved sensitivity parameters.
  SieSensitivityParameters get sensitivityParameters =>
      SieSensitivityParameters.forProfile(sensitivity);

  /// Structural validity.
  bool get isValid =>
      profileId.isNotEmpty &&
      schemaVersion > 0 &&
      user.isValid &&
      camera.isValid &&
      display.isValid &&
      handedness.isValid &&
      interactionZone.isValid;

  /// Age since [updatedAt].
  Duration age([DateTime? now]) =>
      (now ?? DateTime.now().toUtc()).difference(updatedAt.toUtc());

  /// Copy with overrides.
  SieCalibrationProfile copyWith({
    String? profileId,
    int? schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    SieSensitivityProfileId? sensitivity,
    SieUserCalibration? user,
    SieCameraCalibration? camera,
    SieDisplayCalibration? display,
    SieHandednessCalibration? handedness,
    SieInteractionZoneCalibration? interactionZone,
    bool? validated,
    bool? isIdentity,
  }) {
    return SieCalibrationProfile(
      profileId: profileId ?? this.profileId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sensitivity: sensitivity ?? this.sensitivity,
      user: user ?? this.user,
      camera: camera ?? this.camera,
      display: display ?? this.display,
      handedness: handedness ?? this.handedness,
      interactionZone: interactionZone ?? this.interactionZone,
      validated: validated ?? this.validated,
      isIdentity: isIdentity ?? this.isIdentity,
    );
  }

  /// JSON document (platform-independent).
  Map<String, Object?> toJson() => {
        'profileId': profileId,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'sensitivity': sensitivity.name,
        'user': user.toJson(),
        'camera': camera.toJson(),
        'display': display.toJson(),
        'handedness': handedness.toJson(),
        'interactionZone': interactionZone.toJson(),
        'validated': validated,
        'isIdentity': isIdentity,
      };

  /// Parse JSON (throws [FormatException] on corruption).
  static SieCalibrationProfile fromJson(Map<String, Object?> json) {
    final id = json['profileId'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing profileId');
    }
    final schema = json['schemaVersion'];
    if (schema is! num || schema < 1) {
      throw const FormatException('Invalid schemaVersion');
    }
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (created == null || updated == null) {
      throw const FormatException('Invalid timestamps');
    }
    final userRaw = json['user'];
    final cameraRaw = json['camera'];
    final displayRaw = json['display'];
    final handedRaw = json['handedness'];
    final zoneRaw = json['interactionZone'];
    if (userRaw is! Map ||
        cameraRaw is! Map ||
        displayRaw is! Map ||
        handedRaw is! Map ||
        zoneRaw is! Map) {
      throw const FormatException('Missing calibration sections');
    }
    return SieCalibrationProfile(
      profileId: id,
      schemaVersion: schema.toInt(),
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
      sensitivity: _sensitivity(json['sensitivity'] as String?),
      user: SieUserCalibration.fromJson(Map<String, Object?>.from(userRaw)),
      camera:
          SieCameraCalibration.fromJson(Map<String, Object?>.from(cameraRaw)),
      display:
          SieDisplayCalibration.fromJson(Map<String, Object?>.from(displayRaw)),
      handedness: SieHandednessCalibration.fromJson(
        Map<String, Object?>.from(handedRaw),
      ),
      interactionZone: SieInteractionZoneCalibration.fromJson(
        Map<String, Object?>.from(zoneRaw),
      ),
      validated: json['validated'] as bool? ?? false,
      isIdentity: json['isIdentity'] as bool? ?? false,
    );
  }

  static SieSensitivityProfileId _sensitivity(String? name) {
    return switch (name) {
      'precision' => SieSensitivityProfileId.precision,
      'fast' => SieSensitivityProfileId.fast,
      'accessibility' => SieSensitivityProfileId.accessibility,
      'tremorTolerant' => SieSensitivityProfileId.tremorTolerant,
      _ => SieSensitivityProfileId.standard,
    };
  }
}
