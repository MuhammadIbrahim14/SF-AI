import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

void main() {
  group('StudentSieRouteMapper', () {
    test('maps every primary Student RouteNames entry', () {
      const cases = <String, String>{
        RouteNames.studentDashboard: 'student.dashboard',
        RouteNames.studentCourses: 'student.courses',
        RouteNames.studentCourseDetail: 'student.courses.detail',
        RouteNames.studentEnrolledCourses: 'student.courses.enrolled',
        RouteNames.studentCourseLearn: 'student.courses.learn',
        RouteNames.studentLessonDetail: 'student.courses.lesson',
        RouteNames.studentAssignments: 'student.courses.assignments',
        RouteNames.studentAssignmentAttempt:
            'student.courses.assignment.attempt',
        RouteNames.studentGrandTestAttempt: 'student.courses.grand_test.attempt',
        RouteNames.studentAiTutor: 'student.ai_tutor',
        RouteNames.studentProfile: 'student.profile',
        RouteNames.studentEditProfile: 'student.profile.edit',
        RouteNames.studentCertificates: 'student.certificates',
      };
      for (final e in cases.entries) {
        expect(
          StudentSieRouteMapper.resolve(
            location: '/ignored',
            routeName: e.key,
          ),
          e.value,
          reason: e.key,
        );
      }
    });

    test('path prefixes resolve parameterized locations', () {
      expect(
        StudentSieRouteMapper.resolve(
          location: '/student/courses/lesson/c1/l2',
        ),
        'student.courses.lesson',
      );
      expect(
        StudentSieRouteMapper.resolve(
          location: '/student/courses/grand-test/attempt/c1/g1',
        ),
        'student.courses.grand_test.attempt',
      );
      expect(
        StudentSieRouteMapper.resolve(
          location: '/student/courses/assignments/mcq/c1/a1',
        ),
        'student.courses.assignment.attempt',
      );
    });

    test('detects student locations only', () {
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/student'),
        isTrue,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/student/courses'),
        isTrue,
      );
      expect(
        StudentSieRouteMapper.isStudentLocation('/dashboard/teacher'),
        isFalse,
      );
      expect(StudentSieRouteMapper.isStudentLocation('/admin'), isFalse);
    });
  });

  group('SieStudentRouteCatalog — IDS policies', () {
    test('every student policy is registered in SkillForge defaults', () {
      final ids = SieSkillForgeRouteCatalog.defaults
          .map((p) => p.routeId)
          .toSet();
      for (final p in SieStudentRouteCatalog.all) {
        expect(ids.contains(p.routeId), isTrue, reason: p.routeId);
      }
      expect(ids.contains('student.dashboard'), isTrue);
    });

    test('payments and account deletion disable SIE', () {
      expect(SieStudentRouteCatalog.payments.allowsSie, isFalse);
      expect(SieStudentRouteCatalog.accountDeletion.allowsSie, isFalse);
      expect(
        SieStudentRouteCatalog.accountDeletion.securityLevel,
        SieSecurityLevel.l4Irreversible,
      );
      expect(SieStudentRouteCatalog.grandTestAttempt.allowsSie, isFalse);
      expect(SieStudentRouteCatalog.accountSecurity.allowsSie, isFalse);
    });

    test('PRF catalog allows student dashboard and courses', () {
      expect(PrfRouteCatalog.allowsSie('student.dashboard'), isTrue);
      expect(PrfRouteCatalog.allowsSie('student.courses'), isTrue);
      expect(PrfRouteCatalog.allowsSie('student.payments'), isFalse);
      expect(
        PrfRouteCatalog.allowsSie('student.courses.grand_test.attempt'),
        isFalse,
      );
    });
  });

  group('StudentSieHostController', () {
    test('bootstraps with test doubles and activates routes', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final host = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.internalDevelopers,
        startPipeline: false,
        logger: const StudentSieHostLogger(),
      );

      final ok = await host.ensureStarted(
        platform: SiePlatformKind.web,
        userKey: 'test-student',
      );
      expect(ok, isTrue);
      expect(host.isAvailable, isTrue);

      await host.activateRoute('student.dashboard');
      expect(host.activeRouteId, 'student.dashboard');

      await host.activateRoute('student.courses.grand_test.attempt');
      expect(host.activeRouteId, 'student.courses.grand_test.attempt');
      expect(host.root.rollout.latestSnapshot.sieEnabled, isFalse);

      await host.activateRoute('student.courses');
      expect(host.root.integration.routes.contains('student.courses'), isTrue);

      final report = host.diagnosticsReport();
      expect(report['available'], isTrue);

      await host.stop();
      await root.dispose();
    });

    test('queues route activation before bootstrap completes', () async {
      final root = SieServiceRegistryCompositionRoot(
        useTestDoubles: true,
        logger: const NopSrdcrLogger(),
      );
      final host = StudentSieHostController(
        root: root,
        segment: PrfUserSegment.qaTeam,
      );

      // Fire activate before start — should pending then apply.
      final activateFuture = host.activateRoute('student.ai_tutor');
      final startFuture = host.ensureStarted(
        platform: SiePlatformKind.android,
        userKey: 'qa-user',
      );
      await Future.wait([activateFuture, startFuture]);
      expect(host.activeRouteId, 'student.ai_tutor');
      await host.stop();
      await root.dispose();
    });
  });
}
