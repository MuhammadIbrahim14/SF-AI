import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_ai/features/admin/sie/admin_sie_route_mapper.dart';
import 'package:skillforge_ai/features/company/sie/company_sie_route_mapper.dart';
import 'package:skillforge_ai/features/freelancer/sie/freelancer_sie_route_mapper.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';
import 'package:skillforge_ai/features/teacher/sie/teacher_sie_route_mapper.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('AdminSieRouteMapper', () {
    test('maps primary Admin RouteNames', () {
      const cases = <String, String>{
        RouteNames.adminDashboard: 'admin.dashboard',
        RouteNames.superAdminDashboard: 'admin.super_dashboard',
        RouteNames.adminUserManagement: 'admin.users',
        RouteNames.adminVerification: 'admin.verification',
        RouteNames.adminAuditLogs: 'admin.audit_logs',
        RouteNames.adminReleaseCenter: 'admin.progressive_rollout',
        RouteNames.adminFinanceCenter: 'admin.billing',
        RouteNames.adminEmailSettings: 'admin.auth_settings',
        RouteNames.adminRecovery: 'admin.emergency',
      };
      for (final e in cases.entries) {
        expect(
          AdminSieRouteMapper.resolve(location: '/x', routeName: e.key),
          e.value,
          reason: e.key,
        );
      }
    });

    test('path prefixes resolve admin locations', () {
      expect(
        AdminSieRouteMapper.resolve(location: '/admin/users'),
        'admin.users',
      );
      expect(
        AdminSieRouteMapper.resolve(location: '/admin/commerce/finance/x/1'),
        'admin.billing',
      );
      expect(
        AdminSieRouteMapper.resolve(location: '/dashboard/super-admin'),
        'admin.super_dashboard',
      );
    });

    test('admin vs other module location isolation', () {
      expect(AdminSieRouteMapper.isAdminLocation('/dashboard/admin'), isTrue);
      expect(AdminSieRouteMapper.isAdminLocation('/admin/users'), isTrue);
      expect(
        AdminSieRouteMapper.isAdminLocation('/dashboard/company'),
        isFalse,
      );
      expect(
        CompanySieRouteMapper.isCompanyLocation('/dashboard/admin'),
        isFalse,
      );
      expect(
        FreelancerSieRouteMapper.isFreelancerLocation('/admin/users'),
        isFalse,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/admin'),
        isFalse,
      );
      expect(
        TeacherSieRouteMapper.isTeacherLocation('/dashboard/admin'),
        isFalse,
      );
    });
  });

  group('SieAdminRouteCatalog — IDS policies', () {
    test('every admin policy is in SkillForge defaults', () {
      final ids =
          SieSkillForgeRouteCatalog.defaults.map((p) => p.routeId).toSet();
      expect(ids.contains('admin.dashboard'), isTrue);
      for (final p in SieAdminRouteCatalog.all) {
        expect(ids.contains(p.routeId), isTrue, reason: p.routeId);
      }
    });

    test('billing, secrets, emergency and L4 deny SIE', () {
      expect(SieAdminRouteCatalog.billing.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.apiKeys.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.secrets.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.environment.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.securityCenter.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.authSettings.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.emergency.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.shutdown.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.deleteOps.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.accountDeletion.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.critical.allowsSie, isFalse);
      expect(
        SieAdminRouteCatalog.accountDeletion.securityLevel,
        SieSecurityLevel.l4Irreversible,
      );
      expect(
        SieSkillForgeRouteCatalog.adminDashboard.mode,
        SieRouteSieMode.restricted,
      );
      expect(PrfRouteCatalog.allowsSie('admin.billing'), isFalse);
      expect(PrfRouteCatalog.allowsSie('admin.dashboard'), isTrue);
      expect(PrfRouteCatalog.allowsSie('admin.users'), isTrue);
    });

    test('users limited; verification and rollout restricted', () {
      expect(SieAdminRouteCatalog.users.mode, SieRouteSieMode.limited);
      expect(SieAdminRouteCatalog.roles.mode, SieRouteSieMode.limited);
      expect(
        SieAdminRouteCatalog.verification.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieAdminRouteCatalog.progressiveRollout.mode,
        SieRouteSieMode.restricted,
      );
    });
  });

  group('Admin SIE host — shared SRDCR', () {
    test('bootstraps once and activates admin routes', () async {
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
          userKey: 'admin-test',
        ),
        isTrue,
      );

      await host.activateRoute('admin.dashboard');
      expect(host.activeRouteId, 'admin.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.activateRoute('admin.billing');
      expect(host.activeRouteId, 'admin.billing');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.activateRoute('admin.audit_logs');
      expect(host.activeRouteId, 'admin.audit_logs');

      await host.stop();
      await root.dispose();
    });

    test('rapid admin route stress under Integration Framework', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'admin.dashboard',
        'admin.users',
        'admin.verification',
        'admin.billing',
        'admin.emergency',
        'admin.account_deletion',
        'admin.ai_assistant',
      ];
      final sw = Stopwatch()..start();
      for (var i = 0; i < 15; i++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final bill = await sif.activateRoute('admin.billing');
      expect(bill.allowsSie, isFalse);
      await sif.dispose();
    });
  });

  group('Admin workflow validation matrix', () {
    const workflows = <String, String>{
      'Admin Dashboard': 'admin.dashboard',
      'User Management': 'admin.users',
      'Role Management': 'admin.roles',
      'Permission Management': 'admin.permissions',
      'Organization Management': 'admin.organizations',
      'Verification Queues': 'admin.verification',
      'Course Moderation': 'admin.moderation.courses',
      'Marketplace Moderation': 'admin.moderation.marketplace',
      'Reports': 'admin.reports',
      'Analytics': 'admin.analytics',
      'AI Admin Assistant': 'admin.ai_assistant',
      'Audit Logs': 'admin.audit_logs',
      'Feature Flags': 'admin.feature_flags',
      'Progressive Rollout': 'admin.progressive_rollout',
      'Platform Monitoring': 'admin.monitoring',
      'Notifications': 'admin.notifications',
      'CMS': 'admin.cms',
      'Security Center': 'admin.security_center',
      'Billing': 'admin.billing',
      'API Keys': 'admin.api_keys',
      'Emergency Controls': 'admin.emergency',
      'Account Deletion': 'admin.account_deletion',
    };

    test('every Prompt 29 workflow maps to a known catalog policy', () {
      final ids = {
        'admin.dashboard',
        ...SieAdminRouteCatalog.all.map((p) => p.routeId),
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
          userKey: 'admin-workflow',
        ),
        isTrue,
      );

      for (final routeId in workflows.values) {
        await host.activateRoute(routeId);
        expect(host.activeRouteId, routeId, reason: routeId);
      }

      await host.activateRoute('admin.secrets');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('admin.critical');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.stop();
      await root.dispose();
    });

    test('five-module isolation on shared composition root', () async {
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
        userKey: 'cross-module-a',
      );

      await host.activateRoute('student.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('teacher.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('freelancer.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('company.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('admin.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('admin.billing');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('admin.users');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });
  });

  group('Admin Prompt 30 — security & compliance validation', () {
    test('protected administrative operations deny SIE (traditional-only)', () {
      const denied = [
        'admin.api_keys',
        'admin.secrets',
        'admin.environment',
        'admin.database',
        'admin.backup_restore',
        'admin.billing',
        'admin.auth_settings',
        'admin.security_center',
        'admin.role_assignment',
        'admin.delete_ops',
        'admin.shutdown',
        'admin.emergency',
        'admin.ai_usage_control',
        'admin.incidents.write',
        'admin.account_deletion',
        'admin.critical',
      ];
      for (final id in denied) {
        expect(PrfRouteCatalog.allowsSie(id), isFalse, reason: id);
      }
      expect(SieAdminRouteCatalog.users.allowsSie, isTrue);
      expect(SieAdminRouteCatalog.users.mode, SieRouteSieMode.limited);
      expect(SieAdminRouteCatalog.roles.mode, SieRouteSieMode.limited);
      expect(
        SieAdminRouteCatalog.progressiveRollout.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieAdminRouteCatalog.featureFlags.mode,
        SieRouteSieMode.limited,
      );
    });

    test('audit logs / user directory dwell stress under budget', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 280; i++) {
        await sif.activateRoute('admin.audit_logs');
        if (i % 5 == 0) {
          await sif.activateRoute('admin.system_logs');
        }
        if (i % 7 == 0) {
          await sif.activateRoute('admin.users');
        }
        if (i % 11 == 0) {
          await sif.activateRoute('admin.users.detail');
        }
        if (i % 13 == 0) {
          await sif.activateRoute('admin.verification');
        }
        if (i % 17 == 0) {
          await sif.activateRoute('admin.reports');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4500));

      final secrets = await sif.activateRoute('admin.secrets');
      expect(secrets.allowsSie, isFalse);
      await sif.dispose();
    });

    test('five-module rapid route switching with admin under shared SRDCR',
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
        userKey: 'five-module-admin-stress',
      );

      final sw = Stopwatch()..start();
      for (var i = 0; i < 30; i++) {
        await host.activateRoute('student.dashboard');
        await host.activateRoute('teacher.courses');
        await host.activateRoute('freelancer.orders');
        await host.activateRoute('company.dashboard');
        await host.activateRoute('admin.dashboard');
        await host.activateRoute('admin.audit_logs');
        await host.activateRoute('admin.billing');
        await host.activateRoute('admin.users');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(12000));
      expect(host.activeRouteId, 'admin.users');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });
  });
}
