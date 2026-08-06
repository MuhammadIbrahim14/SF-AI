import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';

/// Immutable service registration descriptor.
final class SrdcrServiceDescriptor {
  /// Creates descriptor.
  const SrdcrServiceDescriptor({
    required this.id,
    required this.lifetime,
    required this.initOrder,
    this.dependsOn = const [],
    this.label,
  });

  /// Service id.
  final SrdcrServiceId id;

  /// Lifetime.
  final SrdcrLifetime lifetime;

  /// Explicit initialization order (lower first).
  final int initOrder;

  /// Declared dependencies (must be registered).
  final List<SrdcrServiceId> dependsOn;

  /// Optional label.
  final String? label;
}

/// Canonical SIE service catalog (registration metadata only).
abstract final class SrdcrServiceCatalog {
  /// Default descriptors in startup order.
  static const List<SrdcrServiceDescriptor> defaults = [
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.diagnostics,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 10,
      label: 'SIDF Diagnostics',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.cpmf,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 20,
      dependsOn: [SrdcrServiceId.diagnostics],
      label: 'Configuration & Policy Management',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.platform,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 30,
      label: 'Platform Capability',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.camera,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 40,
      dependsOn: [SrdcrServiceId.platform],
      label: 'Camera Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.vision,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 50,
      dependsOn: [SrdcrServiceId.camera, SrdcrServiceId.platform],
      label: 'Vision Provider',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.landmarks,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 60,
      dependsOn: [SrdcrServiceId.vision],
      label: 'Landmark Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.spatial,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 70,
      dependsOn: [SrdcrServiceId.landmarks],
      label: 'Spatial Coordinate Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.calibration,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 80,
      dependsOn: [SrdcrServiceId.spatial],
      label: 'Calibration Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.confidence,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 90,
      dependsOn: [SrdcrServiceId.calibration],
      label: 'Confidence Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.gestures,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 100,
      dependsOn: [SrdcrServiceId.confidence],
      label: 'Gesture Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.intent,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 110,
      dependsOn: [SrdcrServiceId.gestures],
      label: 'Intent Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.cursor,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 120,
      dependsOn: [SrdcrServiceId.intent],
      label: 'Virtual Cursor Engine',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.pointer,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 130,
      dependsOn: [SrdcrServiceId.cursor, SrdcrServiceId.intent],
      label: 'Flutter Pointer Bridge',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.arbitration,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 140,
      dependsOn: [SrdcrServiceId.pointer],
      label: 'Input Arbitration',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.orchestrator,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 150,
      dependsOn: [SrdcrServiceId.arbitration, SrdcrServiceId.pointer],
      label: 'Interaction Orchestrator',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.integration,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 160,
      dependsOn: [
        SrdcrServiceId.orchestrator,
        SrdcrServiceId.arbitration,
        SrdcrServiceId.intent,
        SrdcrServiceId.diagnostics,
      ],
      label: 'Integration Framework',
    ),
    SrdcrServiceDescriptor(
      id: SrdcrServiceId.rollout,
      lifetime: SrdcrLifetime.singleton,
      initOrder: 170,
      dependsOn: [
        SrdcrServiceId.integration,
        SrdcrServiceId.diagnostics,
        SrdcrServiceId.cpmf,
      ],
      label: 'Progressive Rollout Framework',
    ),
  ];

  /// Shutdown order (reverse of init, with disposable stages first).
  static List<SrdcrServiceId> get shutdownOrder =>
      (List<SrdcrServiceDescriptor>.of(defaults)
            ..sort((a, b) => b.initOrder.compareTo(a.initOrder)))
          .map((d) => d.id)
          .toList(growable: false);
}
