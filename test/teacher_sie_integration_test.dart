import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';
import 'package:skillforge_ai/features/teacher/sie/teacher_sie_route_mapper.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('TeacherSieRouteMapper', () {
    test('maps primary Teacher RouteNames', () {
      const cases = <String, String>{
        RouteNames.teacherDashboard: 'teacher.dashboard',
        RouteNames.teacherCourses: 'teacher.courses',
        RouteNames.teacherCourseCreate: 'teacher.courses.create',
        RouteNames.teacherCourseEdit: 'teacher.courses.edit',
        RouteNames.teacherLessonEdit: 'teacher.courses.lesson.editor',
        RouteNames.teacherAssignmentResults:
            'teacher.courses.assignment.results',
        RouteNames.teacherProjectReview: 'teacher.courses.project.review',
        RouteNames.teacherAiCourseBuilder: 'teacher.ai_course_builder',
        RouteNames.teacherPlans: 'teacher.plans',
        RouteNames.teacherProfile: 'teacher.profile',
        RouteNames.teacherStudentProgress: 'teacher.analytics.students',
      };
      for (final e in cases.entries) {
        expect(
          TeacherSieRouteMapper.resolve(location: '/x', routeName: e.key),
          e.value,
          reason: e.key,
        );
      }
    });

    test('path prefixes resolve parameterized locations', () {
      expect(
        TeacherSieRouteMapper.resolve(
          location: '/teacher/courses/lessons/edit/c1/l2',
        ),
        'teacher.courses.lesson.editor',
      );
      expect(
        TeacherSieRouteMapper.resolve(
          location:
              '/teacher/courses/assignments/project/review/c1/a1/s1',
        ),
        'teacher.courses.project.review',
      );
      expect(
        TeacherSieRouteMapper.resolve(location: '/teacher/plans'),
        'teacher.plans',
      );
    });

    test('teacher vs student location isolation', () {
      expect(
        TeacherSieRouteMapper.isTeacherLocation('/dashboard/teacher'),
        isTrue,
      );
      expect(
        TeacherSieRouteMapper.isTeacherLocation('/dashboard/student'),
        isFalse,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/teacher'),
        isFalse,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/student'),
        isTrue,
      );
    });
  });

  group('SieTeacherRouteCatalog — IDS policies', () {
    test('every teacher policy is in SkillForge defaults', () {
      final ids =
          SieSkillForgeRouteCatalog.defaults.map((p) => p.routeId).toSet();
      expect(ids.contains('teacher.dashboard'), isTrue);
      for (final p in SieTeacherRouteCatalog.all) {
        expect(ids.contains(p.routeId), isTrue, reason: p.routeId);
      }
    });

    test('payments and L4 deny SIE', () {
      expect(SieTeacherRouteCatalog.plans.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.paymentMethods.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.earnings.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.accountDeletion.allowsSie, isFalse);
      expect(
        SieTeacherRouteCatalog.accountDeletion.securityLevel,
        SieSecurityLevel.l4Irreversible,
      );
      expect(PrfRouteCatalog.allowsSie('teacher.plans'), isFalse);
      expect(PrfRouteCatalog.allowsSie('teacher.dashboard'), isTrue);
      expect(PrfRouteCatalog.allowsSie('teacher.courses'), isTrue);
    });

    test('publish and project review are elevated / restricted', () {
      expect(
        SieTeacherRouteCatalog.coursePublish.securityLevel,
        SieSecurityLevel.l2Elevated,
      );
      expect(
        SieTeacherRouteCatalog.projectReview.mode,
        SieRouteSieMode.limited,
      );
      expect(
        SieTeacherRouteCatalog.liveClassroom.mode,
        SieRouteSieMode.restricted,
      );
    });
  });

  group('Teacher SIE host — shared SRDCR', () {
    test('bootstraps once and activates teacher routes', () async {
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
          userKey: 'teacher-test',
        ),
        isTrue,
      );

      await host.activateRoute('teacher.dashboard');
      expect(host.activeRouteId, 'teacher.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);

      await host.activateRoute('teacher.plans');
      expect(host.activeRouteId, 'teacher.plans');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.activateRoute('teacher.courses.project.review');
      expect(host.activeRouteId, 'teacher.courses.project.review');

      await host.stop();
      await root.dispose();
    });

    test('rapid teacher route stress under Integration Framework', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'teacher.dashboard',
        'teacher.courses',
        'teacher.courses.edit',
        'teacher.courses.assignment.results',
        'teacher.courses.project.review',
        'teacher.plans',
        'teacher.ai_course_builder',
        'teacher.account_deletion',
      ];
      final sw = Stopwatch()..start();
      for (var i = 0; i < 15; i++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final pay = await sif.activateRoute('teacher.plans');
      expect(pay.allowsSie, isFalse);
      await sif.dispose();
    });
  });

  group('Teacher workflow validation matrix', () {
    /// Maps Prompt 24 teaching workflows → catalog route IDs.
    const workflows = <String, String>{
      'Dashboard': 'teacher.dashboard',
      'Course Builder': 'teacher.courses.create',
      'Lesson Editor': 'teacher.courses.lesson.editor',
      'Assignment Manager': 'teacher.courses.assignments',
      'Quiz Builder': 'teacher.courses.assignment.editor',
      'Gradebook': 'teacher.courses.assignment.results',
      'Student Progress': 'teacher.analytics.students',
      'Attendance (batches)': 'teacher.batches',
      'Reports': 'teacher.reports',
      'Resource Library': 'teacher.resources',
      'AI Teaching Assistant': 'teacher.ai_course_builder',
      'Live Classroom Controls': 'teacher.live_classroom',
      'Profile': 'teacher.profile',
      'Settings (security)': 'teacher.account_security',
    };

    test('every Prompt 24 workflow maps to a known catalog policy', () {
      final ids = {
        'teacher.dashboard',
        ...SieTeacherRouteCatalog.all.map((p) => p.routeId),
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
          userKey: 'teacher-workflow',
        ),
        isTrue,
      );

      for (final routeId in workflows.values) {
        await host.activateRoute(routeId);
        expect(host.activeRouteId, routeId, reason: routeId);
      }

      // Payments / settings remain denied after authoring routes.
      await host.activateRoute('teacher.plans');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('teacher.account_security');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      // Live classroom stays restricted but activatable.
      await host.activateRoute('teacher.live_classroom');
      expect(host.activeRouteId, 'teacher.live_classroom');

      await host.stop();
      await root.dispose();
    });

    test('student↔teacher module isolation on shared composition root', () async {
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
        userKey: 'cross-module',
      );

      await host.activateRoute('student.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('teacher.dashboard');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('student.payments');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);
      await host.activateRoute('teacher.courses');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isTrue);
      await host.activateRoute('teacher.account_deletion');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.stop();
      await root.dispose();
    });
  });
}
