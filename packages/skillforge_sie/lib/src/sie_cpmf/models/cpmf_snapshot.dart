import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';

/// Immutable resolved configuration snapshot (authoritative at runtime).
final class CpmfConfigurationSnapshot {
  /// Creates snapshot.
  const CpmfConfigurationSnapshot({
    required this.timestamp,
    required this.environment,
    required this.platform,
    required this.profiles,
    required this.bundle,
    required this.source,
    required this.healthy,
    this.validationIssues = const [],
    this.metadata = const {},
  });

  /// Timestamp.
  final DateTime timestamp;

  /// Active environment.
  final CpmfEnvironment environment;

  /// Active platform.
  final SiePlatformKind platform;

  /// Active profile stack.
  final List<CpmfProfileId> profiles;

  /// Resolved bundle.
  final CpmfConfigurationBundle bundle;

  /// Winning source label.
  final CpmfConfigSource source;

  /// Whether validation passed (errors force fallback).
  final bool healthy;

  /// Validation issues.
  final List<CpmfValidationIssue> validationIssues;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Config version.
  String get version => bundle.version;

  /// Schema version.
  int get schemaVersion => bundle.schemaVersion;

  /// Diagnostics map.
  Map<String, Object?> toDiagnostics() => {
        'timestamp': timestamp.toIso8601String(),
        'environment': environment.name,
        'platform': platform.name,
        'profiles': profiles.map((p) => p.name).toList(growable: false),
        'version': version,
        'schemaVersion': schemaVersion,
        'source': source.name,
        'healthy': healthy,
        'issues': [
          for (final i in validationIssues) i.toMap(),
        ],
        'thresholds': bundle.toDiagnosticsMap(),
      };
}

/// Validation issue.
final class CpmfValidationIssue {
  /// Creates issue.
  const CpmfValidationIssue({
    required this.severity,
    required this.message,
    this.domain,
  });

  /// Severity.
  final CpmfValidationSeverity severity;

  /// Message.
  final String message;

  /// Domain.
  final CpmfDomainId? domain;

  /// Map.
  Map<String, Object?> toMap() => {
        'severity': severity.name,
        'message': message,
        if (domain != null) 'domain': domain!.name,
      };
}

/// Low-frequency Riverpod status.
final class CpmfFrameworkStatus {
  /// Creates status.
  const CpmfFrameworkStatus({
    required this.health,
    required this.environment,
    required this.profileIds,
    required this.version,
    this.lastEvent,
  });

  /// Idle.
  factory CpmfFrameworkStatus.idle() => const CpmfFrameworkStatus(
        health: CpmfHealth.idle,
        environment: CpmfEnvironment.production,
        profileIds: [CpmfProfileId.standard],
        version: '0.0.0',
      );

  /// Health.
  final CpmfHealth health;

  /// Environment.
  final CpmfEnvironment environment;

  /// Profiles.
  final List<CpmfProfileId> profileIds;

  /// Version.
  final String version;

  /// Last event.
  final String? lastEvent;
}
