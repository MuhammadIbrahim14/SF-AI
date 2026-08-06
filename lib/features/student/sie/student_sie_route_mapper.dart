import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Maps SkillForge Student GoRouter locations → SIE route policy ids.
///
/// Pure / deterministic — no engine coupling.
abstract final class StudentSieRouteMapper {
  /// Resolve SIE route id from a GoRouter location path (and optional name).
  static String resolve({
    required String location,
    String? routeName,
  }) {
    final path = _normalize(location);
    final byName = routeName == null ? null : _byRouteName[routeName];
    if (byName != null) return byName;

    // Longest-prefix match for parameterized paths.
    final entries = _byPathPrefix.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      if (path == e.key || path.startsWith('${e.key}/')) {
        return e.value;
      }
    }

    if (path.startsWith('/dashboard/student')) {
      return SieSkillForgeRouteCatalog.studentDashboard.routeId;
    }
    if (path.startsWith('/student/')) {
      return SieSkillForgeRouteCatalog.studentDashboard.routeId;
    }
    if (path.startsWith('/profile/student')) {
      return SieStudentRouteCatalog.profile.routeId;
    }
    if (path.contains('payfast') ||
        path.contains('checkout') ||
        path.contains('wallet') ||
        path.contains('invoice')) {
      return SieStudentRouteCatalog.payments.routeId;
    }
    if (path.contains('account-deletion')) {
      return SieStudentRouteCatalog.accountDeletion.routeId;
    }
    if (path.contains('/settings/security') || path.contains('app-lock')) {
      return SieStudentRouteCatalog.accountSecurity.routeId;
    }

    return SieSkillForgeRouteCatalog.studentDashboard.routeId;
  }

  /// Whether this location is a Student Module surface (SIE host scope).
  static bool isStudentLocation(String location) {
    final path = _normalize(location);
    return path.startsWith('/dashboard/student') ||
        path.startsWith('/student/') ||
        path.startsWith('/onboarding/student') ||
        path.startsWith('/profile/student');
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
    RouteNames.studentOnboarding: 'student.onboarding',
    RouteNames.studentDashboard: 'student.dashboard',
    RouteNames.studentAiTutor: 'student.ai_tutor',
    RouteNames.studentCourses: 'student.courses',
    RouteNames.studentCourseDetail: 'student.courses.detail',
    RouteNames.studentEnrolledCourses: 'student.courses.enrolled',
    RouteNames.studentCourseLearn: 'student.courses.learn',
    RouteNames.studentLessonDetail: 'student.courses.lesson',
    RouteNames.studentAssignments: 'student.courses.assignments',
    RouteNames.studentAssignmentAttempt: 'student.courses.assignment.attempt',
    RouteNames.studentAssignmentResult: 'student.courses.assignment.result',
    RouteNames.studentProjectSubmission: 'student.courses.project.submit',
    RouteNames.studentProjectStatus: 'student.courses.project.status',
    RouteNames.studentGrandTestOverview: 'student.courses.grand_test.overview',
    RouteNames.studentGrandTestAttempt: 'student.courses.grand_test.attempt',
    RouteNames.studentGrandTestResult: 'student.courses.grand_test.result',
    RouteNames.studentCertificates: 'student.certificates',
    RouteNames.studentCertificateDetail: 'student.certificates.detail',
    RouteNames.studentSkillScores: 'student.skill_scores',
    RouteNames.studentSkillScoreDetail: 'student.skill_scores.detail',
    RouteNames.studentCareerRoadmap: 'student.career_roadmap',
    RouteNames.studentFreelancerBridge: 'student.freelancer_bridge',
    RouteNames.studentResume: 'student.resume',
    RouteNames.studentResumePreview: 'student.resume.preview',
    RouteNames.studentApplications: 'student.applications',
    RouteNames.studentJoinBatch: 'student.batches',
    RouteNames.studentClassAnnouncements: 'student.batches',
    RouteNames.studentMyBatches: 'student.batches',
    RouteNames.studentBatchDetail: 'student.batches.detail',
    RouteNames.studentProfile: 'student.profile',
    RouteNames.studentEditProfile: 'student.profile.edit',
    RouteNames.accountDeletionPolicy: 'student.account_deletion',
    RouteNames.securitySettings: 'student.account_security',
  };

  static const Map<String, String> _byPathPrefix = {
    '/onboarding/student': 'student.onboarding',
    '/dashboard/student': 'student.dashboard',
    '/student/ai-tutor': 'student.ai_tutor',
    '/student/class-batches/join': 'student.batches',
    '/student/class-batches/announcements': 'student.batches',
    '/student/class-batches': 'student.batches',
    '/student/courses/detail': 'student.courses.detail',
    '/student/courses/enrolled': 'student.courses.enrolled',
    '/student/courses/learn': 'student.courses.learn',
    '/student/courses/lesson': 'student.courses.lesson',
    '/student/courses/assignments/mcq': 'student.courses.assignment.attempt',
    '/student/courses/assignments/result': 'student.courses.assignment.result',
    '/student/courses/assignments': 'student.courses.assignments',
    '/student/courses/project/submit': 'student.courses.project.submit',
    '/student/courses/project/status': 'student.courses.project.status',
    '/student/courses/grand-test/attempt': 'student.courses.grand_test.attempt',
    '/student/courses/grand-test/result': 'student.courses.grand_test.result',
    '/student/courses/grand-test': 'student.courses.grand_test.overview',
    '/student/courses': 'student.courses',
    '/student/certificates/detail': 'student.certificates.detail',
    '/student/certificates': 'student.certificates',
    '/student/skill-scores/detail': 'student.skill_scores.detail',
    '/student/skill-scores': 'student.skill_scores',
    '/student/career-roadmap': 'student.career_roadmap',
    '/student/freelancer-bridge': 'student.freelancer_bridge',
    '/student/resume/preview': 'student.resume.preview',
    '/student/resume': 'student.resume',
    '/student/applications': 'student.applications',
    '/profile/student/edit': 'student.profile.edit',
    '/profile/student': 'student.profile',
  };
}
