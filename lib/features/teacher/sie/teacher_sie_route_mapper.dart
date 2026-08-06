import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Maps SkillForge Teacher GoRouter locations → SIE route policy ids.
///
/// Mirrors [StudentSieRouteMapper] — pure / deterministic.
abstract final class TeacherSieRouteMapper {
  /// Resolve SIE route id from location + optional GoRouter name.
  static String resolve({
    required String location,
    String? routeName,
  }) {
    final path = _normalize(location);
    final byName = routeName == null ? null : _byRouteName[routeName];
    if (byName != null) return byName;

    // Detail has same prefix as list — prefer detail when an id segment exists.
    if (path.startsWith('/teacher/analytics/students/') &&
        path.length > '/teacher/analytics/students/'.length) {
      return SieTeacherRouteCatalog.studentProgressDetail.routeId;
    }

    final entries = _byPathPrefix.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      if (path == e.key || path.startsWith('${e.key}/')) {
        return e.value;
      }
    }

    if (path.startsWith('/dashboard/teacher')) {
      return SieSkillForgeRouteCatalog.teacherDashboard.routeId;
    }
    if (path.startsWith('/teacher/')) {
      if (path.contains('payment') ||
          path.contains('plans') ||
          path.contains('earnings') ||
          path.contains('purchase') ||
          path.contains('paid-courses')) {
        return SieTeacherRouteCatalog.plans.routeId;
      }
      return SieSkillForgeRouteCatalog.teacherDashboard.routeId;
    }
    if (path.startsWith('/profile/teacher')) {
      return SieTeacherRouteCatalog.profile.routeId;
    }
    if (path.contains('account-deletion')) {
      return SieTeacherRouteCatalog.accountDeletion.routeId;
    }
    if (path.contains('/settings/security') || path.contains('app-lock')) {
      return SieTeacherRouteCatalog.accountSecurity.routeId;
    }

    return SieSkillForgeRouteCatalog.teacherDashboard.routeId;
  }

  /// Whether this location is a Teacher Module SIE surface.
  static bool isTeacherLocation(String location) {
    final path = _normalize(location);
    return path.startsWith('/dashboard/teacher') ||
        path.startsWith('/teacher/') ||
        path.startsWith('/onboarding/teacher') ||
        path.startsWith('/profile/teacher');
  }

  static String _normalize(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  static const Map<String, String> _byRouteName = {
    RouteNames.teacherOnboarding: 'teacher.onboarding',
    RouteNames.teacherDashboard: 'teacher.dashboard',
    RouteNames.teacherCourses: 'teacher.courses',
    RouteNames.teacherCourseCreate: 'teacher.courses.create',
    RouteNames.teacherCourseEdit: 'teacher.courses.edit',
    RouteNames.teacherCourseDetail: 'teacher.courses.edit',
    RouteNames.teacherCourseLessons: 'teacher.courses.lessons',
    RouteNames.teacherLessonCreate: 'teacher.courses.lesson.editor',
    RouteNames.teacherLessonEdit: 'teacher.courses.lesson.editor',
    RouteNames.teacherAssignments: 'teacher.courses.assignments',
    RouteNames.teacherAssignmentCreate: 'teacher.courses.assignment.editor',
    RouteNames.teacherAssignmentEdit: 'teacher.courses.assignment.editor',
    RouteNames.teacherAssignmentResults: 'teacher.courses.assignment.results',
    RouteNames.teacherProjectAssignments: 'teacher.courses.projects',
    RouteNames.teacherProjectAssignmentCreate: 'teacher.courses.project.editor',
    RouteNames.teacherProjectAssignmentEdit: 'teacher.courses.project.editor',
    RouteNames.teacherProjectSubmissions: 'teacher.courses.project.submissions',
    RouteNames.teacherProjectReview: 'teacher.courses.project.review',
    RouteNames.teacherGrandTests: 'teacher.courses.grand_tests',
    RouteNames.teacherGrandTestCreate: 'teacher.courses.grand_test.editor',
    RouteNames.teacherGrandTestEdit: 'teacher.courses.grand_test.editor',
    RouteNames.teacherGrandTestEligibility:
        'teacher.courses.grand_test.eligibility',
    RouteNames.teacherGrandTestAttempts: 'teacher.courses.grand_test.attempts',
    RouteNames.teacherCertificates: 'teacher.certificates',
    RouteNames.teacherCertificateEligible: 'teacher.certificates.eligible',
    RouteNames.teacherStudentProgress: 'teacher.analytics.students',
    RouteNames.teacherStudentProgressDetail:
        'teacher.analytics.students.detail',
    RouteNames.teacherBatches: 'teacher.batches',
    RouteNames.teacherBatchesCompare: 'teacher.batches',
    RouteNames.teacherBatchDetail: 'teacher.batches.detail',
    RouteNames.teacherAiCourseBuilder: 'teacher.ai_course_builder',
    RouteNames.teacherProfile: 'teacher.profile',
    RouteNames.teacherEditProfile: 'teacher.profile.edit',
    RouteNames.teacherPlans: 'teacher.plans',
    RouteNames.teacherPaymentMethods: 'teacher.payment_methods',
    RouteNames.teacherPurchaseHistory: 'teacher.purchase_history',
    RouteNames.teacherEarnings: 'teacher.earnings',
    RouteNames.teacherPaidCourses: 'teacher.paid_courses',
    RouteNames.accountDeletionPolicy: 'teacher.account_deletion',
    RouteNames.securitySettings: 'teacher.account_security',
  };

  static const Map<String, String> _byPathPrefix = {
    '/onboarding/teacher': 'teacher.onboarding',
    '/dashboard/teacher': 'teacher.dashboard',
    '/teacher/ai-course-builder': 'teacher.ai_course_builder',
    '/teacher/courses/create': 'teacher.courses.create',
    '/teacher/courses/edit': 'teacher.courses.edit',
    '/teacher/courses/detail': 'teacher.courses.edit',
    '/teacher/courses/lessons/create': 'teacher.courses.lesson.editor',
    '/teacher/courses/lessons/edit': 'teacher.courses.lesson.editor',
    '/teacher/courses/lessons': 'teacher.courses.lessons',
    '/teacher/courses/assignments/create': 'teacher.courses.assignment.editor',
    '/teacher/courses/assignments/edit': 'teacher.courses.assignment.editor',
    '/teacher/courses/assignments/results':
        'teacher.courses.assignment.results',
    '/teacher/courses/assignments': 'teacher.courses.assignments',
    '/teacher/courses/assignments/project/create':
        'teacher.courses.project.editor',
    '/teacher/courses/assignments/project/edit':
        'teacher.courses.project.editor',
    '/teacher/courses/assignments/project/submissions':
        'teacher.courses.project.submissions',
    '/teacher/courses/assignments/project/review':
        'teacher.courses.project.review',
    '/teacher/courses/assignments/project': 'teacher.courses.projects',
    '/teacher/courses/grand-tests/create': 'teacher.courses.grand_test.editor',
    '/teacher/courses/grand-tests/edit': 'teacher.courses.grand_test.editor',
    '/teacher/courses/grand-tests/eligibility':
        'teacher.courses.grand_test.eligibility',
    '/teacher/courses/grand-tests/attempts':
        'teacher.courses.grand_test.attempts',
    '/teacher/courses/grand-tests': 'teacher.courses.grand_tests',
    '/teacher/courses': 'teacher.courses',
    '/teacher/certificates/eligible': 'teacher.certificates.eligible',
    '/teacher/certificates': 'teacher.certificates',
    '/teacher/analytics/students': 'teacher.analytics.students',
    '/teacher/batches': 'teacher.batches',
    '/teacher/plans': 'teacher.plans',
    '/teacher/payment-methods': 'teacher.payment_methods',
    '/teacher/purchase-history': 'teacher.purchase_history',
    '/teacher/earnings': 'teacher.earnings',
    '/teacher/paid-courses': 'teacher.paid_courses',
    '/profile/teacher/edit': 'teacher.profile.edit',
    '/profile/teacher': 'teacher.profile',
  };
}
