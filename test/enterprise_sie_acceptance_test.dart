import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Stage 10 Prompt 31 — enterprise-wide cross-role acceptance (host).
void main() {
  group('Enterprise SIE acceptance — platform catalog', () {
    test('every SkillForge default route has explicit allowsSie decision', () {
      for (final p in SieSkillForgeRouteCatalog.defaults) {
        final allowed = p.allowsSie;
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(allowed, isFalse, reason: p.routeId);
        }
        expect(PrfRouteCatalog.allowsSie(p.routeId), allowed, reason: p.routeId);
      }
    });

    test('cross-module L3/L4 sensitive routes deny SIE platform-wide', () {
      const denied = [
        'student.payments',
        'student.courses.grand_test.attempt',
        'student.account_deletion',
        'teacher.plans',
        'teacher.payment_methods',
        'teacher.account_security',
        'freelancer.payouts',
        'freelancer.contracts.accept',
        'freelancer.account_deletion',
        'company.billing',
        'company.ownership',
        'company.account_deletion',
        'admin.billing',
        'admin.secrets',
        'admin.emergency',
        'admin.account_deletion',
        'admin.critical',
      ];
      for (final id in denied) {
        expect(PrfRouteCatalog.allowsSie(id), isFalse, reason: id);
      }
    });
  });

  group('Enterprise SIE acceptance — cross-role switching', () {
    test('five-role cycle stress on shared SRDCR', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final host = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.internalDevelopers,
        startPipeline: false,
      );
      await host.ensureStarted(
        platform: SiePlatformKind.web,
        userKey: 'enterprise-cycle',
      );

      final sw = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        await host.activateRoute('student.dashboard');
        await host.activateRoute('teacher.dashboard');
        await host.activateRoute('company.dashboard');
        await host.activateRoute('admin.dashboard');
        await host.activateRoute('freelancer.dashboard');
        await host.activateRoute('student.courses');
        await host.activateRoute('teacher.courses');
        await host.activateRoute('company.pipeline');
        await host.activateRoute('admin.audit_logs');
        await host.activateRoute('freelancer.orders');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(15000));
      expect(host.activeRouteId, 'freelancer.orders');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });

    test('role switch preserves deny on sensitive routes', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final host = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.internalDevelopers,
        startPipeline: false,
      );
      await host.ensureStarted(
        platform: SiePlatformKind.web,
        userKey: 'enterprise-deny',
      );

      const sequence = [
        ('student.dashboard', true),
        ('student.payments', false),
        ('teacher.dashboard', true),
        ('teacher.plans', false),
        ('freelancer.dashboard', true),
        ('freelancer.payouts', false),
        ('company.dashboard', true),
        ('company.billing', false),
        ('admin.dashboard', true),
        ('admin.secrets', false),
      ];

      for (final (routeId, expectEnabled) in sequence) {
        await host.activateRoute(routeId);
        expect(host.activeRouteId, routeId);
        expect(
          host.root.rollout.latestSnapshot.sieEnabled,
          expectEnabled,
          reason: routeId,
        );
      }

      await host.stop();
      await root.dispose();
    });

    test('user key switch does not leak prior route state', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final hostA = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.internalDevelopers,
        startPipeline: false,
      );
      await hostA.ensureStarted(
        platform: SiePlatformKind.web,
        userKey: 'user-a',
      );
      await hostA.activateRoute('admin.billing');
      expect(hostA.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await hostA.stop();

      final hostB = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.betaTesters,
        startPipeline: false,
      );
      await hostB.ensureStarted(
        platform: SiePlatformKind.web,
        userKey: 'user-b',
      );
      await hostB.activateRoute('student.dashboard');
      expect(hostB.activeRouteId, 'student.dashboard');
      expect(hostB.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await hostB.stop();
      await root.dispose();
    });
  });

  group('Enterprise SIE acceptance — rollout & fault tolerance', () {
    test('kill switch disables SIE globally', () async {
      final prf = SieProgressiveRolloutFramework(
        localDefaults: const PrfConfig(),
        deviceProbe: StaticPrfDeviceCapabilityProbe(
          PrfDeviceCapability.capable(SiePlatformKind.web),
        ),
        logger: const NopPrfLogger(),
      );
      await prf.initialize(
        platform: SiePlatformKind.web,
        segment: PrfUserSegment.publicUsers,
        userKey: 'rollout-test',
      );
      expect(prf.sieEnabled, isTrue);
      await prf.activateKillSwitch();
      expect(prf.sieEnabled, isFalse);
      expect(prf.currentStatus.killSwitchActive, isTrue);
      await prf.dispose();
    });

    test('rollback disables SIE after enablement', () async {
      final prf = SieProgressiveRolloutFramework(
        localDefaults: const PrfConfig(),
        deviceProbe: StaticPrfDeviceCapabilityProbe(
          PrfDeviceCapability.capable(SiePlatformKind.web),
        ),
        logger: const NopPrfLogger(),
      );
      await prf.initialize(
        platform: SiePlatformKind.web,
        segment: PrfUserSegment.publicUsers,
        userKey: 'rollback-test',
      );
      final snap = await prf.rollback(reason: 'enterprise_acceptance');
      expect(snap.rolledBack, isTrue);
      expect(snap.sieEnabled, isFalse);
      await prf.dispose();
    });
  });
}
