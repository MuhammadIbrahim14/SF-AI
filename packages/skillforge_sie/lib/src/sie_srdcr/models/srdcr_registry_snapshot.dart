import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_service_descriptor.dart';

/// Immutable registry / bootstrap snapshot.
final class SrdcrRegistrySnapshot {
  /// Creates snapshot.
  const SrdcrRegistrySnapshot({
    required this.timestamp,
    required this.phase,
    required this.health,
    required this.registered,
    required this.initOrder,
    required this.startupDurationMs,
    this.failures = const [],
    this.metadata = const {},
  });

  /// Idle.
  factory SrdcrRegistrySnapshot.idle() => SrdcrRegistrySnapshot(
        timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        phase: SrdcrPhase.idle,
        health: SrdcrHealth.idle,
        registered: const [],
        initOrder: const [],
        startupDurationMs: 0,
      );

  /// Timestamp.
  final DateTime timestamp;

  /// Phase.
  final SrdcrPhase phase;

  /// Health.
  final SrdcrHealth health;

  /// Registered service ids.
  final List<SrdcrServiceId> registered;

  /// Initialization order used.
  final List<SrdcrServiceId> initOrder;

  /// Startup duration ms.
  final double startupDurationMs;

  /// Failure messages.
  final List<String> failures;

  /// Metadata.
  final Map<String, Object?> metadata;

  /// Diagnostics map.
  Map<String, Object?> toDiagnostics() => {
        'timestamp': timestamp.toIso8601String(),
        'phase': phase.name,
        'health': health.name,
        'registered': registered.map((e) => e.name).toList(growable: false),
        'initOrder': initOrder.map((e) => e.name).toList(growable: false),
        'startupDurationMs': startupDurationMs,
        'failures': failures,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// Low-frequency Riverpod-safe status.
final class SrdcrStatus {
  /// Creates status.
  const SrdcrStatus({
    required this.phase,
    required this.health,
    required this.ready,
    this.startupDurationMs = 0,
    this.lastEvent,
  });

  /// Idle.
  factory SrdcrStatus.idle() => const SrdcrStatus(
        phase: SrdcrPhase.idle,
        health: SrdcrHealth.idle,
        ready: false,
      );

  /// Phase.
  final SrdcrPhase phase;

  /// Health.
  final SrdcrHealth health;

  /// Ready.
  final bool ready;

  /// Startup ms.
  final double startupDurationMs;

  /// Last event.
  final String? lastEvent;
}

/// Graph validation issue.
final class SrdcrValidationIssue {
  /// Creates issue.
  const SrdcrValidationIssue({
    required this.message,
    this.service,
  });

  /// Message.
  final String message;

  /// Related service.
  final SrdcrServiceId? service;
}

/// Dependency graph validator (pure).
abstract final class SrdcrGraphValidator {
  /// Validate descriptors for duplicates, missing deps, cycles, order.
  static List<SrdcrValidationIssue> validate(
    List<SrdcrServiceDescriptor> descriptors,
  ) {
    final issues = <SrdcrValidationIssue>[];
    final byId = <SrdcrServiceId, SrdcrServiceDescriptor>{};

    for (final d in descriptors) {
      if (byId.containsKey(d.id)) {
        issues.add(
          SrdcrValidationIssue(
            message: 'Duplicate registration: ${d.id.name}',
            service: d.id,
          ),
        );
      } else {
        byId[d.id] = d;
      }
    }

    for (final d in descriptors) {
      for (final dep in d.dependsOn) {
        if (!byId.containsKey(dep)) {
          issues.add(
            SrdcrValidationIssue(
              message:
                  'Missing dependency ${dep.name} required by ${d.id.name}',
              service: d.id,
            ),
          );
        }
      }
      if (d.lifetime == SrdcrLifetime.transient &&
          d.id != SrdcrServiceId.platform) {
        // Engines should not be transient — warn as issue for validation fail.
        issues.add(
          SrdcrValidationIssue(
            message: 'Invalid lifetime transient for engine ${d.id.name}',
            service: d.id,
          ),
        );
      }
    }

    // Cycle detection (DFS).
    final visiting = <SrdcrServiceId>{};
    final visited = <SrdcrServiceId>{};

    bool dfs(SrdcrServiceId id) {
      if (visiting.contains(id)) return true;
      if (visited.contains(id)) return false;
      visiting.add(id);
      final deps = byId[id]?.dependsOn ?? const [];
      for (final dep in deps) {
        if (dfs(dep)) return true;
      }
      visiting.remove(id);
      visited.add(id);
      return false;
    }

    for (final id in byId.keys) {
      if (dfs(id)) {
        issues.add(
          SrdcrValidationIssue(
            message: 'Circular dependency detected involving ${id.name}',
            service: id,
          ),
        );
        break;
      }
    }

    // Init order must be unique and respect dependency directions.
    final orders = <int>{};
    for (final d in descriptors) {
      if (!orders.add(d.initOrder)) {
        issues.add(
          SrdcrValidationIssue(
            message: 'Duplicate initOrder ${d.initOrder} on ${d.id.name}',
            service: d.id,
          ),
        );
      }
    }
    for (final d in descriptors) {
      for (final dep in d.dependsOn) {
        final depDesc = byId[dep];
        if (depDesc != null && depDesc.initOrder >= d.initOrder) {
          issues.add(
            SrdcrValidationIssue(
              message:
                  'Invalid init order: ${d.id.name} (${d.initOrder}) depends on '
                  '${dep.name} (${depDesc.initOrder})',
              service: d.id,
            ),
          );
        }
      }
    }

    return issues;
  }

  /// Sorted init order.
  static List<SrdcrServiceId> sortedInitOrder(
    List<SrdcrServiceDescriptor> descriptors,
  ) {
    final sorted = List<SrdcrServiceDescriptor>.of(descriptors)
      ..sort((a, b) => a.initOrder.compareTo(b.initOrder));
    return sorted.map((d) => d.id).toList(growable: false);
  }
}
