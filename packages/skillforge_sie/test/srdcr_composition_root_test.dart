import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieServiceRegistryCompositionRoot _root() => SieServiceRegistryCompositionRoot(
      useTestDoubles: true,
      logger: const NopSrdcrLogger(),
    );

void main() {
  group('SRDCR — catalog & graph validation', () {
    test('default catalog validates cleanly', () {
      final issues = SrdcrGraphValidator.validate(SrdcrServiceCatalog.defaults);
      expect(issues, isEmpty);
    });

    test('sorted init order is deterministic and covers all services', () {
      final order =
          SrdcrGraphValidator.sortedInitOrder(SrdcrServiceCatalog.defaults);
      expect(order.first, SrdcrServiceId.diagnostics);
      expect(order.last, SrdcrServiceId.rollout);
      expect(order.length, SrdcrServiceCatalog.defaults.length);
      expect(order.toSet().length, order.length);
    });

    test('shutdown order is reverse of init order', () {
      final init =
          SrdcrGraphValidator.sortedInitOrder(SrdcrServiceCatalog.defaults);
      final shutdown = SrdcrServiceCatalog.shutdownOrder;
      expect(shutdown, init.reversed.toList());
    });

    test('detects missing dependency', () {
      final issues = SrdcrGraphValidator.validate([
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.camera,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 10,
          dependsOn: [SrdcrServiceId.platform],
        ),
      ]);
      expect(
        issues.any((i) => i.message.contains('Missing dependency')),
        isTrue,
      );
    });

    test('detects circular dependency', () {
      final issues = SrdcrGraphValidator.validate([
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.camera,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 10,
          dependsOn: [SrdcrServiceId.vision],
        ),
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.vision,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 20,
          dependsOn: [SrdcrServiceId.camera],
        ),
      ]);
      expect(
        issues.any((i) => i.message.contains('Circular dependency')),
        isTrue,
      );
    });

    test('detects invalid init order vs dependsOn', () {
      final issues = SrdcrGraphValidator.validate([
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.platform,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 20,
        ),
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.camera,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 10,
          dependsOn: [SrdcrServiceId.platform],
        ),
      ]);
      expect(
        issues.any((i) => i.message.contains('Invalid init order')),
        isTrue,
      );
    });

    test('rejects transient lifetime for engines', () {
      final issues = SrdcrGraphValidator.validate([
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.gestures,
          lifetime: SrdcrLifetime.transient,
          initOrder: 10,
        ),
      ]);
      expect(
        issues.any((i) => i.message.contains('Invalid lifetime transient')),
        isTrue,
      );
    });
  });

  group('SRDCR — registry lifetimes', () {
    test('singleton returns same instance', () {
      final registry = SrdcrServiceRegistry();
      registry.register(
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.platform,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 1,
        ),
        (_) => Object(),
      );
      registry.seal();
      final a = registry.resolve<Object>(SrdcrServiceId.platform);
      final b = registry.resolve<Object>(SrdcrServiceId.platform);
      expect(identical(a, b), isTrue);
    });

    test('transient returns new instances', () {
      final registry = SrdcrServiceRegistry();
      registry.register(
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.platform,
          lifetime: SrdcrLifetime.transient,
          initOrder: 1,
        ),
        (_) => Object(),
      );
      // seal skips transient lifetime validation for platform only via graph —
      // platform is exempt from "engine transient" rule.
      registry.seal();
      final a = registry.resolve<Object>(SrdcrServiceId.platform);
      final b = registry.resolve<Object>(SrdcrServiceId.platform);
      expect(identical(a, b), isFalse);
    });

    test('scoped requires active scope', () {
      final registry = SrdcrServiceRegistry();
      registry.register(
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.diagnostics,
          lifetime: SrdcrLifetime.scoped,
          initOrder: 1,
        ),
        (_) => Object(),
      );
      registry.seal();
      expect(
        () => registry.resolve<Object>(SrdcrServiceId.diagnostics),
        throwsA(isA<SieSrdcrFailure>()),
      );
      registry.beginScope();
      final a = registry.resolve<Object>(SrdcrServiceId.diagnostics);
      final b = registry.resolve<Object>(SrdcrServiceId.diagnostics);
      expect(identical(a, b), isTrue);
    });

    test('duplicate registration fails', () {
      final registry = SrdcrServiceRegistry();
      const desc = SrdcrServiceDescriptor(
        id: SrdcrServiceId.platform,
        lifetime: SrdcrLifetime.singleton,
        initOrder: 1,
      );
      registry.register(desc, (_) => Object());
      expect(
        () => registry.register(desc, (_) => Object()),
        throwsA(isA<SieSrdcrFailure>()),
      );
    });

    test('circular construct throws', () {
      final registry = SrdcrServiceRegistry();
      registry.register(
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.camera,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 10,
          dependsOn: [SrdcrServiceId.vision],
        ),
        (r) {
          r(SrdcrServiceId.vision);
          return Object();
        },
      );
      registry.register(
        const SrdcrServiceDescriptor(
          id: SrdcrServiceId.vision,
          lifetime: SrdcrLifetime.singleton,
          initOrder: 20,
          dependsOn: [SrdcrServiceId.camera],
        ),
        (r) {
          r(SrdcrServiceId.camera);
          return Object();
        },
      );
      expect(
        () => registry.seal(),
        throwsA(isA<SieSrdcrFailure>()),
      );
    });
  });

  group('SRDCR — bootstrap & shutdown', () {
    test('bootstrap registers all services and reaches ready', () async {
      final root = _root();
      await root.bootstrap(platform: SiePlatformKind.web);
      expect(root.isReady, isTrue);
      expect(root.currentStatus.phase, SrdcrPhase.ready);
      expect(root.latestSnapshot.initOrder.first, SrdcrServiceId.diagnostics);
      expect(root.latestSnapshot.initOrder.last, SrdcrServiceId.rollout);
      expect(
        root.registry.registeredIds.length,
        SrdcrServiceCatalog.defaults.length,
      );
      expect(root.camera, isA<CameraPort>());
      expect(root.vision, isA<VisionRuntimePort>());
      expect(root.integration, isA<SieIntegrationPort>());
      expect(root.rollout, isA<ProgressiveRolloutPort>());
      expect(root.cpmf, isA<CpmfPort>());
      expect(root.diagnostics, isA<SidfDiagnosticsPort>());
      expect(root.latestSnapshot.startupDurationMs, greaterThan(0));
      await root.shutdown();
      await root.dispose();
    });

    test('double bootstrap throws', () async {
      final root = _root();
      await root.bootstrap(platform: SiePlatformKind.android);
      await expectLater(
        root.bootstrap(platform: SiePlatformKind.android),
        throwsA(isA<SieSrdcrFailure>()),
      );
      await root.shutdown();
      await root.dispose();
    });

    test('shutdown then re-bootstrap succeeds', () async {
      final root = _root();
      await root.bootstrap(platform: SiePlatformKind.web);
      await root.shutdown();
      expect(root.isReady, isFalse);
      await root.bootstrap(platform: SiePlatformKind.windows);
      expect(root.isReady, isTrue);
      final platform =
          root.resolve<SrdcrPlatformContext>(SrdcrServiceId.platform);
      expect(platform.platform, SiePlatformKind.windows);
      await root.dispose();
    });

    test('mock override replaces registered factory', () async {
      final root = _root();
      final marker = SidfDiagnosticsFramework(logger: const NopSidfLogger());
      await root.bootstrap(
        platform: SiePlatformKind.web,
        overrides: {
          SrdcrServiceId.diagnostics: (_) => marker,
        },
      );
      expect(identical(root.diagnostics, marker), isTrue);
      await root.dispose();
    });

    test('startRuntimePipeline is idempotent', () async {
      final root = _root();
      await root.bootstrap(platform: SiePlatformKind.web);
      await root.startRuntimePipeline();
      await root.startRuntimePipeline();
      final report = root.diagnosticsReport();
      expect(report['pipelineStarted'], isTrue);
      expect(report['bootstrapped'], isTrue);
      expect(report['dependencyGraph'], isA<Map>());
      await root.dispose();
    });

    test('resolve before bootstrap throws', () {
      final root = _root();
      expect(
        () => root.resolve<Object>(SrdcrServiceId.camera),
        throwsA(isA<SieSrdcrFailure>()),
      );
    });

    test('platform context matches bootstrap platform', () async {
      final root = _root();
      await root.bootstrap(platform: SiePlatformKind.android);
      final ctx = root.resolve<SrdcrPlatformContext>(SrdcrServiceId.platform);
      expect(ctx.platform, SiePlatformKind.android);
      await root.dispose();
    });
  });

  group('SRDCR — performance', () {
    test('bootstrap with test doubles completes under budget', () async {
      final root = _root();
      final sw = Stopwatch()..start();
      await root.bootstrap(platform: SiePlatformKind.web);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));
      expect(root.latestSnapshot.startupDurationMs, lessThan(5000));
      await root.dispose();
    });
  });
}
