import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_ai/features/freelancer/sie/freelancer_sie_route_mapper.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';
import 'package:skillforge_ai/features/teacher/sie/teacher_sie_route_mapper.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('FreelancerSieRouteMapper', () {
    test('maps primary Freelancer RouteNames', () {
      const cases = <String, String>{
        RouteNames.freelancerDashboard: 'freelancer.dashboard',
        RouteNames.freelancerServices: 'freelancer.services',
        RouteNames.freelancerServiceCreate: 'freelancer.services.create',
        RouteNames.freelancerServiceRequests: 'freelancer.service_requests',
        RouteNames.freelancerServiceOrders: 'freelancer.orders',
        RouteNames.freelancerWallet: 'freelancer.wallet',
        RouteNames.freelancerInvoices: 'freelancer.invoices',
        RouteNames.freelancerPayouts: 'freelancer.payouts',
        RouteNames.freelancerAiAssistant: 'freelancer.ai_assistant',
        RouteNames.freelancerResolutions: 'freelancer.resolutions',
        RouteNames.freelancerProfile: 'freelancer.profile',
        RouteNames.freelancerEditProfile: 'freelancer.profile.edit',
      };
      for (final e in cases.entries) {
        expect(
          FreelancerSieRouteMapper.resolve(location: '/x', routeName: e.key),
          e.value,
          reason: e.key,
        );
      }
    });

    test('path prefixes resolve parameterized locations', () {
      expect(
        FreelancerSieRouteMapper.resolve(
          location: '/freelancer/services/svc1/edit',
        ),
        'freelancer.services.edit',
      );
      expect(
        FreelancerSieRouteMapper.resolve(
          location: '/freelancer/invoices/inv-9',
        ),
        'freelancer.invoices.detail',
      );
      expect(
        FreelancerSieRouteMapper.resolve(location: '/freelancer/wallet'),
        'freelancer.wallet',
      );
    });

    test('freelancer vs student/teacher location isolation', () {
      expect(
        FreelancerSieRouteMapper.isFreelancerLocation('/dashboard/freelancer'),
        isTrue,
      );
      expect(
        FreelancerSieRouteMapper.isFreelancerLocation('/dashboard/student'),
        isFalse,
      );
      expect(
        FreelancerSieRouteMapper.isFreelancerLocation('/dashboard/teacher'),
        isFalse,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/freelancer'),
        isFalse,
      );
      expect(
        TeacherSieRouteMapper.isTeacherLocation('/dashboard/freelancer'),
        isFalse,
      );
    });
  });

  group('SieFreelancerRouteCatalog — IDS policies', () {
    test('every freelancer policy is in SkillForge defaults', () {
      final ids =
          SieSkillForgeRouteCatalog.defaults.map((p) => p.routeId).toSet();
      expect(ids.contains('freelancer.dashboard'), isTrue);
      for (final p in SieFreelancerRouteCatalog.all) {
        expect(ids.contains(p.routeId), isTrue, reason: p.routeId);
      }
    });

    test('financial and L4 deny or limit SIE correctly', () {
      expect(SieFreelancerRouteCatalog.payouts.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.paymentApproval.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.contractAccept.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.banking.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.accountSecurity.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.accountDeletion.allowsSie, isFalse);
      expect(
        SieFreelancerRouteCatalog.accountDeletion.securityLevel,
        SieSecurityLevel.l4Irreversible,
      );
      expect(SieFreelancerRouteCatalog.wallet.mode, SieRouteSieMode.limited);
      expect(SieFreelancerRouteCatalog.wallet.allowsSie, isTrue);
      expect(PrfRouteCatalog.allowsSie('freelancer.payouts'), isFalse);
      expect(PrfRouteCatalog.allowsSie('freelancer.dashboard'), isTrue);
      expect(PrfRouteCatalog.allowsSie('freelancer.services'), isTrue);
    });

    test('proposal publish and project archive are restricted', () {
      expect(
        SieFreelancerRouteCatalog.proposalPublish.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieFreelancerRouteCatalog.projectArchive.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieFreelancerRouteCatalog.resolutions.mode,
        SieRouteSieMode.limited,
      );
    });
  });

  group('Freelancer SIE host — shared SRDCR', () {
    test('bootstraps once and activates freelancer routes', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final host = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.internalDevelopers,
        startPipeline: false,
      );

      expect(
        await host.ensureStarted(
          platform: SiePlatformKind.web,
          userKey: 'freelancer-test',
        ),
        isTrue,
      );

      await host.activateRoute('freelancer.dashboard');
      expect(host.activeRouteId, 'freelancer.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.activateRoute('freelancer.payouts');
      expect(host.activeRouteId, 'freelancer.payouts');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.activateRoute('freelancer.wallet');
      expect(host.activeRouteId, 'freelancer.wallet');

      await host.stop();
      await root.dispose();
    });

    test('rapid freelancer route stress under Integration Framework', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'freelancer.dashboard',
        'freelancer.services',
        'freelancer.orders',
        'freelancer.wallet',
        'freelancer.payouts',
        'freelancer.ai_assistant',
        'freelancer.account_deletion',
      ];
      final sw = Stopwatch()..start();
      for (var i = 0; i < 15; i++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final pay = await sif.activateRoute('freelancer.payouts');
      expect(pay.allowsSie, isFalse);
      await sif.dispose();
    });
  });

  group('Freelancer workflow validation matrix', () {
    const workflows = <String, String>{
      'Dashboard': 'freelancer.dashboard',
      'My Projects (orders)': 'freelancer.orders',
      'Client Workspace': 'freelancer.orders.detail',
      'Proposal Manager': 'freelancer.proposals',
      'Project Timeline': 'freelancer.timeline',
      'Tasks': 'freelancer.tasks',
      'Time Tracking': 'freelancer.time_tracking',
      'Deliverables': 'freelancer.deliverables',
      'File Manager': 'freelancer.files',
      'Messages': 'freelancer.messages',
      'AI Freelancer Assistant': 'freelancer.ai_assistant',
      'Earnings (wallet browse)': 'freelancer.wallet',
      'Invoices': 'freelancer.invoices',
      'Wallet withdraw': 'freelancer.payouts',
      'Reviews': 'freelancer.reviews',
      'Analytics': 'freelancer.analytics',
      'Notifications': 'freelancer.notifications',
      'Profile': 'freelancer.profile',
      'Settings (security)': 'freelancer.account_security',
    };

    test('every Prompt 25 workflow maps to a known catalog policy', () {
      final ids = {
        'freelancer.dashboard',
        ...SieFreelancerRouteCatalog.all.map((p) => p.routeId),
      };
      for (final e in workflows.entries) {
        expect(ids.contains(e.value), isTrue, reason: e.key);
      }
    });

    test('shared SRDCR activates every workflow route without throw', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final host = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.internalDevelopers,
        startPipeline: false,
      );
      expect(
        await host.ensureStarted(
          platform: SiePlatformKind.web,
          userKey: 'freelancer-workflow',
        ),
        isTrue,
      );

      for (final routeId in workflows.values) {
        await host.activateRoute(routeId);
        expect(host.activeRouteId, routeId, reason: routeId);
      }

      await host.activateRoute('freelancer.payouts');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('freelancer.contracts.accept');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.stop();
      await root.dispose();
    });

    test('student↔teacher↔freelancer isolation on shared composition root',
        () async {
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
        userKey: 'cross-module-f',
      );

      await host.activateRoute('student.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('teacher.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('freelancer.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('freelancer.payouts');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('freelancer.services');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });
  });

  group('Freelancer Prompt 26 — financial & stress validation', () {
    test('protected financial / contract actions deny SIE', () {
      const denied = [
        'freelancer.payouts',
        'freelancer.payments.approve',
        'freelancer.banking',
        'freelancer.tax',
        'freelancer.contracts.accept',
        'freelancer.identity',
        'freelancer.account_security',
        'freelancer.account_deletion',
      ];
      for (final id in denied) {
        expect(PrfRouteCatalog.allowsSie(id), isFalse, reason: id);
      }
      expect(SieFreelancerRouteCatalog.wallet.allowsSie, isTrue);
      expect(SieFreelancerRouteCatalog.wallet.mode, SieRouteSieMode.limited);
      expect(SieFreelancerRouteCatalog.invoices.allowsSie, isTrue);
      expect(
        SieFreelancerRouteCatalog.invoiceCreate.mode,
        SieRouteSieMode.restricted,
      );
    });

    test('project / file / AI route dwell stress stays under budget', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        await sif.activateRoute('freelancer.orders');
        if (i % 5 == 0) {
          await sif.activateRoute('freelancer.files');
        }
        if (i % 7 == 0) {
          await sif.activateRoute('freelancer.ai_assistant');
        }
        if (i % 11 == 0) {
          await sif.activateRoute('freelancer.timeline');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4000));

      final payout = await sif.activateRoute('freelancer.payouts');
      expect(payout.allowsSie, isFalse);
      await sif.dispose();
    });

    test('triple-module rapid route switching under shared SRDCR', () async {
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
        userKey: 'triple-module-stress',
      );

      final sw = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        await host.activateRoute('student.dashboard');
        await host.activateRoute('teacher.courses');
        await host.activateRoute('freelancer.dashboard');
        await host.activateRoute('freelancer.orders');
        await host.activateRoute('freelancer.payouts');
        await host.activateRoute('freelancer.services');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(8000));
      expect(host.activeRouteId, 'freelancer.services');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });
  });
}
