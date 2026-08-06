import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';

/// Explicit Teacher Module SIE route policies (Phase 2 — mirrors Student catalog).
///
/// `teacher.dashboard` lives in [SieSkillForgeRouteCatalog]; all other Teacher
/// surfaces are declared here for Integration + PRF.
abstract final class SieTeacherRouteCatalog {
  /// Teacher onboarding.
  static const SieRoutePolicy onboarding = SieRoutePolicy(
    routeId: 'teacher.onboarding',
    displayName: 'Teacher Onboarding',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// My courses list.
  static const SieRoutePolicy courses = SieRoutePolicy(
    routeId: 'teacher.courses',
    displayName: 'Teacher Courses',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Course create / builder.
  static const SieRoutePolicy courseCreate = SieRoutePolicy(
    routeId: 'teacher.courses.create',
    displayName: 'Course Create',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Course editor (publish gated separately — elevated).
  static const SieRoutePolicy courseEdit = SieRoutePolicy(
    routeId: 'teacher.courses.edit',
    displayName: 'Course Editor',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Course publish / irreversible publish confirm — restricted.
  static const SieRoutePolicy coursePublish = SieRoutePolicy(
    routeId: 'teacher.courses.publish',
    displayName: 'Course Publish',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.teacher,
  );

  /// Lessons list.
  static const SieRoutePolicy lessons = SieRoutePolicy(
    routeId: 'teacher.courses.lessons',
    displayName: 'Course Lessons',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Lesson editor.
  static const SieRoutePolicy lessonEditor = SieRoutePolicy(
    routeId: 'teacher.courses.lesson.editor',
    displayName: 'Lesson Editor',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Assignments list.
  static const SieRoutePolicy assignments = SieRoutePolicy(
    routeId: 'teacher.courses.assignments',
    displayName: 'Assignments',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Quiz / MCQ assignment builder.
  static const SieRoutePolicy assignmentEditor = SieRoutePolicy(
    routeId: 'teacher.courses.assignment.editor',
    displayName: 'Assignment Editor',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Gradebook / assignment results — hover + click + scroll.
  static const SieRoutePolicy assignmentResults = SieRoutePolicy(
    routeId: 'teacher.courses.assignment.results',
    displayName: 'Assignment Results',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Project assignments.
  static const SieRoutePolicy projects = SieRoutePolicy(
    routeId: 'teacher.courses.projects',
    displayName: 'Project Assignments',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Project editor.
  static const SieRoutePolicy projectEditor = SieRoutePolicy(
    routeId: 'teacher.courses.project.editor',
    displayName: 'Project Assignment Editor',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Project submissions list.
  static const SieRoutePolicy projectSubmissions = SieRoutePolicy(
    routeId: 'teacher.courses.project.submissions',
    displayName: 'Project Submissions',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Project review / grading — elevated (student work).
  static const SieRoutePolicy projectReview = SieRoutePolicy(
    routeId: 'teacher.courses.project.review',
    displayName: 'Project Review',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.assessments,
  );

  /// Grand tests list.
  static const SieRoutePolicy grandTests = SieRoutePolicy(
    routeId: 'teacher.courses.grand_tests',
    displayName: 'Grand Tests',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Grand test editor.
  static const SieRoutePolicy grandTestEditor = SieRoutePolicy(
    routeId: 'teacher.courses.grand_test.editor',
    displayName: 'Grand Test Editor',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Grand test eligibility.
  static const SieRoutePolicy grandTestEligibility = SieRoutePolicy(
    routeId: 'teacher.courses.grand_test.eligibility',
    displayName: 'Grand Test Eligibility',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.assessments,
  );

  /// Grand test attempts / grading.
  static const SieRoutePolicy grandTestAttempts = SieRoutePolicy(
    routeId: 'teacher.courses.grand_test.attempts',
    displayName: 'Grand Test Attempts',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.assessments,
  );

  /// Certificate management.
  static const SieRoutePolicy certificates = SieRoutePolicy(
    routeId: 'teacher.certificates',
    displayName: 'Certificates',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Certificate eligible students — elevated issue action.
  static const SieRoutePolicy certificateEligible = SieRoutePolicy(
    routeId: 'teacher.certificates.eligible',
    displayName: 'Certificate Eligible Students',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.teacher,
  );

  /// Student progress analytics.
  static const SieRoutePolicy studentProgress = SieRoutePolicy(
    routeId: 'teacher.analytics.students',
    displayName: 'Student Progress',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Student progress detail.
  static const SieRoutePolicy studentProgressDetail = SieRoutePolicy(
    routeId: 'teacher.analytics.students.detail',
    displayName: 'Student Progress Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Batches / classrooms.
  static const SieRoutePolicy batches = SieRoutePolicy(
    routeId: 'teacher.batches',
    displayName: 'Batches',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// AI course builder / teaching assistant.
  static const SieRoutePolicy aiCourseBuilder = SieRoutePolicy(
    routeId: 'teacher.ai_course_builder',
    displayName: 'AI Course Builder',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.aiAssistant,
  );

  /// Teacher profile.
  static const SieRoutePolicy profile = SieRoutePolicy(
    routeId: 'teacher.profile',
    displayName: 'Teacher Profile',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Edit profile — elevated.
  static const SieRoutePolicy profileEdit = SieRoutePolicy(
    routeId: 'teacher.profile.edit',
    displayName: 'Edit Teacher Profile',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.teacher,
  );

  /// Plans / subscriptions — payments (IDS L3).
  static const SieRoutePolicy plans = SieRoutePolicy(
    routeId: 'teacher.plans',
    displayName: 'Teacher Plans',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Payment methods — disabled.
  static const SieRoutePolicy paymentMethods = SieRoutePolicy(
    routeId: 'teacher.payment_methods',
    displayName: 'Payment Methods',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Purchase history — disabled.
  static const SieRoutePolicy purchaseHistory = SieRoutePolicy(
    routeId: 'teacher.purchase_history',
    displayName: 'Purchase History',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Earnings — disabled.
  static const SieRoutePolicy earnings = SieRoutePolicy(
    routeId: 'teacher.earnings',
    displayName: 'Teacher Earnings',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Paid courses commerce — disabled.
  static const SieRoutePolicy paidCourses = SieRoutePolicy(
    routeId: 'teacher.paid_courses',
    displayName: 'Paid Courses',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Account security — traditional only.
  static const SieRoutePolicy accountSecurity = SieRoutePolicy(
    routeId: 'teacher.account_security',
    displayName: 'Account Security',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.teacher,
    sieEnabled: false,
  );

  /// Account deletion — L4.
  static const SieRoutePolicy accountDeletion = SieRoutePolicy(
    routeId: 'teacher.account_deletion',
    displayName: 'Account Deletion',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l4Irreversible,
    module: SieAppModuleId.teacher,
    sieEnabled: false,
  );

  /// Live classroom controls (future) — restricted moderation.
  static const SieRoutePolicy liveClassroom = SieRoutePolicy(
    routeId: 'teacher.live_classroom',
    displayName: 'Live Classroom',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.teacher,
  );

  /// Announcements.
  static const SieRoutePolicy announcements = SieRoutePolicy(
    routeId: 'teacher.announcements',
    displayName: 'Announcements',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Resource library.
  static const SieRoutePolicy resources = SieRoutePolicy(
    routeId: 'teacher.resources',
    displayName: 'Resource Library',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Reports.
  static const SieRoutePolicy reports = SieRoutePolicy(
    routeId: 'teacher.reports',
    displayName: 'Reports',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// All Teacher Module policies (excludes shared `teacher.dashboard`).
  static const List<SieRoutePolicy> all = [
    onboarding,
    courses,
    courseCreate,
    courseEdit,
    coursePublish,
    lessons,
    lessonEditor,
    assignments,
    assignmentEditor,
    assignmentResults,
    projects,
    projectEditor,
    projectSubmissions,
    projectReview,
    grandTests,
    grandTestEditor,
    grandTestEligibility,
    grandTestAttempts,
    certificates,
    certificateEligible,
    studentProgress,
    studentProgressDetail,
    batches,
    aiCourseBuilder,
    profile,
    profileEdit,
    plans,
    paymentMethods,
    purchaseHistory,
    earnings,
    paidCourses,
    accountSecurity,
    accountDeletion,
    liveClassroom,
    announcements,
    resources,
    reports,
  ];
}
