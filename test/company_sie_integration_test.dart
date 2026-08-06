import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_ai/features/company/sie/company_sie_route_mapper.dart';
import 'package:skillforge_ai/features/freelancer/sie/freelancer_sie_route_mapper.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';
import 'package:skillforge_ai/features/teacher/sie/teacher_sie_route_mapper.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('CompanySieRouteMapper', () {
    test('maps primary Company RouteNames', () {
      const cases = <String, String>{
        RouteNames.companyDashboard: 'company.dashboard',
        RouteNames.companyJobs: 'company.jobs',
        RouteNames.createJob: 'company.jobs.create',
        RouteNames.hiringPipeline: 'company.pipeline',
        RouteNames.companyAiHiringAssistant: 'company.ai_hiring',
        RouteNames.companyProfile: 'company.profile',
        RouteNames.companyEditProfile: 'company.profile.edit',
        RouteNames.scheduleInterview: 'company.interviews.schedule',
        RouteNames.evaluateInterview: 'company.interviews.evaluate',
      };
      for (final e in cases.entries) {
        expect(
          CompanySieRouteMapper.resolve(location: '/x', routeName: e.key),
          e.value,
          reason: e.key,
        );
      }
    });

    test('path prefixes resolve parameterized locations', () {
      expect(
        CompanySieRouteMapper.resolve(
          location: '/company/jobs/j1/pipeline',
        ),
        'company.pipeline.job',
      );
      expect(
        CompanySieRouteMapper.resolve(
          location: '/company/interviews/schedule/app1',
        ),
        'company.interviews.schedule',
      );
      expect(
        CompanySieRouteMapper.resolve(location: '/jobs/create'),
        'company.jobs.create',
      );
      expect(
        CompanySieRouteMapper.resolve(location: '/jobs/edit/42'),
        'company.jobs.edit',
      );
    });

    test('company vs other module location isolation', () {
      expect(
        CompanySieRouteMapper.isCompanyLocation('/dashboard/company'),
        isTrue,
      );
      expect(
        CompanySieRouteMapper.isCompanyLocation('/dashboard/freelancer'),
        isFalse,
      );
      expect(
        FreelancerSieRouteMapper.isFreelancerLocation('/dashboard/company'),
        isFalse,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/company'),
        isFalse,
      );
      expect(
        TeacherSieRouteMapper.isTeacherLocation('/dashboard/company'),
        isFalse,
      );
    });
  });

  group('SieCompanyRouteCatalog — IDS policies', () {
    test('every company policy is in SkillForge defaults', () {
      final ids =
          SieSkillForgeRouteCatalog.defaults.map((p) => p.routeId).toSet();
      expect(ids.contains('company.dashboard'), isTrue);
      for (final p in SieCompanyRouteCatalog.all) {
        expect(ids.contains(p.routeId), isTrue, reason: p.routeId);
      }
    });

    test('billing, roles, ownership and L4 deny SIE', () {
      expect(SieCompanyRouteCatalog.billing.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.subscription.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.ownership.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.roles.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.permissions.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.accountSecurity.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.accountDeletion.allowsSie, isFalse);
      expect(
        SieCompanyRouteCatalog.accountDeletion.securityLevel,
        SieSecurityLevel.l4Irreversible,
      );
      expect(SieCompanyRouteCatalog.financialReports.mode, SieRouteSieMode.limited);
      expect(SieCompanyRouteCatalog.jobCreate.mode, SieRouteSieMode.restricted);
      expect(PrfRouteCatalog.allowsSie('company.billing'), isFalse);
      expect(PrfRouteCatalog.allowsSie('company.dashboard'), isTrue);
      expect(PrfRouteCatalog.allowsSie('company.jobs'), isTrue);
    });

    test('org settings and interview evaluate are restricted', () {
      expect(
        SieCompanyRouteCatalog.orgSettings.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieCompanyRouteCatalog.interviewEvaluate.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieCompanyRouteCatalog.employees.mode,
        SieRouteSieMode.limited,
      );
    });
  });

  group('Company SIE host — shared SRDCR', () {
    test('bootstraps once and activates company routes', () async {
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
          userKey: 'company-test',
        ),
        isTrue,
      );

      await host.activateRoute('company.dashboard');
      expect(host.activeRouteId, 'company.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.activateRoute('company.billing');
      expect(host.activeRouteId, 'company.billing');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.activateRoute('company.pipeline');
      expect(host.activeRouteId, 'company.pipeline');

      await host.stop();
      await root.dispose();
    });

    test('rapid company route stress under Integration Framework', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'company.dashboard',
        'company.jobs',
        'company.jobs.create',
        'company.pipeline',
        'company.billing',
        'company.ai_hiring',
        'company.account_deletion',
      ];
      final sw = Stopwatch()..start();
      for (var i = 0; i < 15; i++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final bill = await sif.activateRoute('company.billing');
      expect(bill.allowsSie, isFalse);
      await sif.dispose();
    });
  });

  group('Company workflow validation matrix', () {
    const workflows = <String, String>{
      'Dashboard': 'company.dashboard',
      'Organization Overview': 'company.organization',
      'Job Management': 'company.jobs',
      'Job Creation': 'company.jobs.create',
      'Candidate Pipeline': 'company.pipeline',
      'Applicant Tracking': 'company.pipeline.job',
      'Talent Search': 'company.talent_search',
      'Company Projects': 'company.projects',
      'Team Workspace': 'company.team',
      'Departments': 'company.departments',
      'Employees': 'company.employees',
      'Interview Scheduling': 'company.interviews.schedule',
      'Assessments': 'company.assessments',
      'AI Hiring Assistant': 'company.ai_hiring',
      'Analytics': 'company.analytics',
      'Reports': 'company.reports',
      'Notifications': 'company.notifications',
      'Documents': 'company.documents',
      'Profile': 'company.profile',
      'Organization Settings': 'company.org_settings',
      'Billing': 'company.billing',
      'Settings (security)': 'company.account_security',
    };

    test('every Prompt 27 workflow maps to a known catalog policy', () {
      final ids = {
        'company.dashboard',
        ...SieCompanyRouteCatalog.all.map((p) => p.routeId),
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
          userKey: 'company-workflow',
        ),
        isTrue,
      );

      for (final routeId in workflows.values) {
        await host.activateRoute(routeId);
        expect(host.activeRouteId, routeId, reason: routeId);
      }

      await host.activateRoute('company.roles');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('company.ownership');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.stop();
      await root.dispose();
    });

    test('four-module isolation on shared composition root', () async {
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
        userKey: 'cross-module-c',
      );

      await host.activateRoute('student.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('teacher.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('freelancer.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('company.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('company.billing');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('company.jobs');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });
  });

  group('Company Prompt 28 — enterprise security & stress validation', () {
    test('protected billing / ownership / roles actions deny SIE', () {
      const denied = [
        'company.billing',
        'company.subscription',
        'company.ownership',
        'company.roles',
        'company.permissions',
        'company.account_security',
        'company.account_deletion',
      ];
      for (final id in denied) {
        expect(PrfRouteCatalog.allowsSie(id), isFalse, reason: id);
      }
      expect(SieCompanyRouteCatalog.financialReports.allowsSie, isTrue);
      expect(
        SieCompanyRouteCatalog.financialReports.mode,
        SieRouteSieMode.limited,
      );
      expect(SieCompanyRouteCatalog.jobCreate.mode, SieRouteSieMode.restricted);
      expect(
        SieCompanyRouteCatalog.orgSettings.mode,
        SieRouteSieMode.restricted,
      );
    });

    test('recruitment pipeline / analytics / AI dwell stress under budget',
        () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 250; i++) {
        await sif.activateRoute('company.pipeline');
        if (i % 5 == 0) {
          await sif.activateRoute('company.pipeline.job');
        }
        if (i % 7 == 0) {
          await sif.activateRoute('company.ai_hiring');
        }
        if (i % 11 == 0) {
          await sif.activateRoute('company.analytics');
        }
        if (i % 13 == 0) {
          await sif.activateRoute('company.jobs');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4000));

      final bill = await sif.activateRoute('company.billing');
      expect(bill.allowsSie, isFalse);
      await sif.dispose();
    });

    test('four-module rapid route switching under shared SRDCR', () async {
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
        userKey: 'four-module-stress',
      );

      final sw = Stopwatch()..start();
      for (var i = 0; i < 30; i++) {
        await host.activateRoute('student.dashboard');
        await host.activateRoute('teacher.courses');
        await host.activateRoute('freelancer.orders');
        await host.activateRoute('company.dashboard');
        await host.activateRoute('company.pipeline');
        await host.activateRoute('company.billing');
        await host.activateRoute('company.jobs');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(10000));
      expect(host.activeRouteId, 'company.jobs');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.stop();
      await root.dispose();
    });
  });
}
