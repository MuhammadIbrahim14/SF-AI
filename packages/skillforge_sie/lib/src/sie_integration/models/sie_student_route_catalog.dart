import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';

/// Explicit Student Module SIE route policies (Phase 1 production catalog).
///
/// Every Student surface must appear here — Integration + PRF resolve from this list.
abstract final class SieStudentRouteCatalog {
  /// Student onboarding.
  static const SieRoutePolicy onboarding = SieRoutePolicy(
    routeId: 'student.onboarding',
    displayName: 'Student Onboarding',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Course discovery / catalog.
  static const SieRoutePolicy courses = SieRoutePolicy(
    routeId: 'student.courses',
    displayName: 'Find Courses',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Course detail (hover + select; purchase CTA is gated separately).
  static const SieRoutePolicy courseDetail = SieRoutePolicy(
    routeId: 'student.courses.detail',
    displayName: 'Course Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Enrolled courses list.
  static const SieRoutePolicy enrolled = SieRoutePolicy(
    routeId: 'student.courses.enrolled',
    displayName: 'My Courses',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Course learning hub.
  static const SieRoutePolicy learn = SieRoutePolicy(
    routeId: 'student.courses.learn',
    displayName: 'Course Learning',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Lesson / video materials (stable select required for controls).
  static const SieRoutePolicy lesson = SieRoutePolicy(
    routeId: 'student.courses.lesson',
    displayName: 'Lesson Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Assignments list.
  static const SieRoutePolicy assignments = SieRoutePolicy(
    routeId: 'student.courses.assignments',
    displayName: 'Assignments',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// MCQ attempt — restricted (accuracy / integrity).
  static const SieRoutePolicy assignmentAttempt = SieRoutePolicy(
    routeId: 'student.courses.assignment.attempt',
    displayName: 'Assignment Attempt',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.assessments,
  );

  /// Assignment result.
  static const SieRoutePolicy assignmentResult = SieRoutePolicy(
    routeId: 'student.courses.assignment.result',
    displayName: 'Assignment Result',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Project submission.
  static const SieRoutePolicy projectSubmit = SieRoutePolicy(
    routeId: 'student.courses.project.submit',
    displayName: 'Project Submission',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.assessments,
  );

  /// Project status.
  static const SieRoutePolicy projectStatus = SieRoutePolicy(
    routeId: 'student.courses.project.status',
    displayName: 'Project Status',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Grand test overview.
  static const SieRoutePolicy grandTestOverview = SieRoutePolicy(
    routeId: 'student.courses.grand_test.overview',
    displayName: 'Grand Test Overview',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Grand test attempt — traditional input preferred (IDS integrity).
  static const SieRoutePolicy grandTestAttempt = SieRoutePolicy(
    routeId: 'student.courses.grand_test.attempt',
    displayName: 'Grand Test Attempt',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.assessments,
    sieEnabled: false,
  );

  /// Grand test result.
  static const SieRoutePolicy grandTestResult = SieRoutePolicy(
    routeId: 'student.courses.grand_test.result',
    displayName: 'Grand Test Result',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Certificates list.
  static const SieRoutePolicy certificates = SieRoutePolicy(
    routeId: 'student.certificates',
    displayName: 'Certificates',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Certificate detail.
  static const SieRoutePolicy certificateDetail = SieRoutePolicy(
    routeId: 'student.certificates.detail',
    displayName: 'Certificate Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Skill scores / learning analytics.
  static const SieRoutePolicy skillScores = SieRoutePolicy(
    routeId: 'student.skill_scores',
    displayName: 'Skill Scores',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Skill score detail.
  static const SieRoutePolicy skillScoreDetail = SieRoutePolicy(
    routeId: 'student.skill_scores.detail',
    displayName: 'Skill Score Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Career roadmap.
  static const SieRoutePolicy careerRoadmap = SieRoutePolicy(
    routeId: 'student.career_roadmap',
    displayName: 'Career Roadmap',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Freelancer bridge.
  static const SieRoutePolicy freelancerBridge = SieRoutePolicy(
    routeId: 'student.freelancer_bridge',
    displayName: 'Freelancer Bridge',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Smart resume.
  static const SieRoutePolicy resume = SieRoutePolicy(
    routeId: 'student.resume',
    displayName: 'Smart Resume',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Resume preview.
  static const SieRoutePolicy resumePreview = SieRoutePolicy(
    routeId: 'student.resume.preview',
    displayName: 'Resume Preview',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Applications.
  static const SieRoutePolicy applications = SieRoutePolicy(
    routeId: 'student.applications',
    displayName: 'Applications',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Class batches hub (roster + join requests).
  static const SieRoutePolicy batches = SieRoutePolicy(
    routeId: 'student.batches',
    displayName: 'My Classes',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Student view of a single class batch.
  static const SieRoutePolicy batchesDetail = SieRoutePolicy(
    routeId: 'student.batches.detail',
    displayName: 'Class Batch Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// AI Tutor / assistant.
  static const SieRoutePolicy aiTutor = SieRoutePolicy(
    routeId: 'student.ai_tutor',
    displayName: 'AI Tutor',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.aiAssistant,
  );

  /// Student profile.
  static const SieRoutePolicy profile = SieRoutePolicy(
    routeId: 'student.profile',
    displayName: 'Student Profile',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Edit profile — elevated.
  static const SieRoutePolicy profileEdit = SieRoutePolicy(
    routeId: 'student.profile.edit',
    displayName: 'Edit Student Profile',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.student,
  );

  /// Course payment / PayFast — SIE disabled (IDS L3).
  static const SieRoutePolicy payments = SieRoutePolicy(
    routeId: 'student.payments',
    displayName: 'Student Payments',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Account security — traditional input only.
  static const SieRoutePolicy accountSecurity = SieRoutePolicy(
    routeId: 'student.account_security',
    displayName: 'Account Security',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.student,
    sieEnabled: false,
  );

  /// Account deletion — L4 irreversible.
  static const SieRoutePolicy accountDeletion = SieRoutePolicy(
    routeId: 'student.account_deletion',
    displayName: 'Account Deletion',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l4Irreversible,
    module: SieAppModuleId.student,
    sieEnabled: false,
  );

  /// Notifications (shared surface when opened from student).
  static const SieRoutePolicy notifications = SieRoutePolicy(
    routeId: 'student.notifications',
    displayName: 'Notifications',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Calendar / schedule widgets.
  static const SieRoutePolicy calendar = SieRoutePolicy(
    routeId: 'student.calendar',
    displayName: 'Calendar',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Resources / downloads.
  static const SieRoutePolicy resources = SieRoutePolicy(
    routeId: 'student.resources',
    displayName: 'Resources',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Discussion boards.
  static const SieRoutePolicy discussions = SieRoutePolicy(
    routeId: 'student.discussions',
    displayName: 'Discussions',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// All Student Module policies (excluding shared `student.dashboard` in base catalog).
  static const List<SieRoutePolicy> all = [
    onboarding,
    courses,
    courseDetail,
    enrolled,
    learn,
    lesson,
    assignments,
    assignmentAttempt,
    assignmentResult,
    projectSubmit,
    projectStatus,
    grandTestOverview,
    grandTestAttempt,
    grandTestResult,
    certificates,
    certificateDetail,
    skillScores,
    skillScoreDetail,
    careerRoadmap,
    freelancerBridge,
    resume,
    resumePreview,
    applications,
    batches,
    batchesDetail,
    aiTutor,
    profile,
    profileEdit,
    payments,
    accountSecurity,
    accountDeletion,
    notifications,
    calendar,
    resources,
    discussions,
  ];
}
