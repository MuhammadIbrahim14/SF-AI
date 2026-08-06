import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_policy.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_admin_route_catalog.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_company_route_catalog.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_freelancer_route_catalog.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_student_route_catalog.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_teacher_route_catalog.dart';

/// Immutable route policy entry (explicit SIE capability declaration).
final class SieRoutePolicy {
  /// Creates policy.
  const SieRoutePolicy({
    required this.routeId,
    required this.displayName,
    required this.mode,
    required this.capabilityKind,
    required this.securityLevel,
    this.module = SieAppModuleId.custom,
    this.sieEnabled = true,
    this.configurable = false,
  });

  /// Stable route id (e.g. `student.dashboard`).
  final String routeId;

  /// Human label.
  final String displayName;

  /// Integration mode.
  final SieRouteSieMode mode;

  /// Maps to IDS route capability kind.
  final SieRouteCapabilityKind capabilityKind;

  /// IDS security level.
  final SieSecurityLevel securityLevel;

  /// Owning module.
  final SieAppModuleId module;

  /// Effective SIE enablement after mode resolution.
  final bool sieEnabled;

  /// Whether host may toggle (settings).
  final bool configurable;

  /// Resolved [SieRouteCapability] preset.
  SieRouteCapability get capability =>
      SieRouteCapability.forKind(capabilityKind);

  /// Whether SIE interactions may run under this policy.
  bool get allowsSie {
    if (securityLevel == SieSecurityLevel.l4Irreversible) return false;
    if (mode == SieRouteSieMode.disabled) return false;
    return sieEnabled;
  }

  /// Copy.
  SieRoutePolicy copyWith({
    String? routeId,
    String? displayName,
    SieRouteSieMode? mode,
    SieRouteCapabilityKind? capabilityKind,
    SieSecurityLevel? securityLevel,
    SieAppModuleId? module,
    bool? sieEnabled,
    bool? configurable,
  }) {
    return SieRoutePolicy(
      routeId: routeId ?? this.routeId,
      displayName: displayName ?? this.displayName,
      mode: mode ?? this.mode,
      capabilityKind: capabilityKind ?? this.capabilityKind,
      securityLevel: securityLevel ?? this.securityLevel,
      module: module ?? this.module,
      sieEnabled: sieEnabled ?? this.sieEnabled,
      configurable: configurable ?? this.configurable,
    );
  }
}

/// Built-in SkillForge AI route policies (Version 1).
abstract final class SieSkillForgeRouteCatalog {
  /// Landing / marketing.
  static const SieRoutePolicy landing = SieRoutePolicy(
    routeId: 'landing',
    displayName: 'Landing',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.marketing,
    securityLevel: SieSecurityLevel.l0Public,
    module: SieAppModuleId.custom,
  );

  /// Authentication — limited (no gesture confirm secrets).
  static const SieRoutePolicy authentication = SieRoutePolicy(
    routeId: 'authentication',
    displayName: 'Authentication',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.custom,
    sieEnabled: true,
  );

  /// Student dashboard.
  static const SieRoutePolicy studentDashboard = SieRoutePolicy(
    routeId: 'student.dashboard',
    displayName: 'Student Dashboard',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.student,
  );

  /// Teacher dashboard.
  static const SieRoutePolicy teacherDashboard = SieRoutePolicy(
    routeId: 'teacher.dashboard',
    displayName: 'Teacher Dashboard',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.teacher,
  );

  /// Freelancer dashboard.
  static const SieRoutePolicy freelancerDashboard = SieRoutePolicy(
    routeId: 'freelancer.dashboard',
    displayName: 'Freelancer Dashboard',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Company dashboard.
  static const SieRoutePolicy companyDashboard = SieRoutePolicy(
    routeId: 'company.dashboard',
    displayName: 'Company Dashboard',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Admin — restricted.
  static const SieRoutePolicy adminDashboard = SieRoutePolicy(
    routeId: 'admin.dashboard',
    displayName: 'Admin Dashboard',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Payments — SIE disabled.
  static const SieRoutePolicy payments = SieRoutePolicy(
    routeId: 'payments',
    displayName: 'Payments',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Settings — configurable.
  static const SieRoutePolicy settings = SieRoutePolicy(
    routeId: 'settings',
    displayName: 'Settings',
    mode: SieRouteSieMode.configurable,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.custom,
    configurable: true,
  );

  /// Courses.
  static const SieRoutePolicy courses = SieRoutePolicy(
    routeId: 'courses',
    displayName: 'Courses',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.courses,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.courses,
  );

  /// Default SkillForge catalog (O(1) map built by registry).
  ///
  /// Includes Phase 1–5 Student → Admin Module policies.
  static List<SieRoutePolicy> get defaults => [
        landing,
        authentication,
        studentDashboard,
        teacherDashboard,
        freelancerDashboard,
        companyDashboard,
        adminDashboard,
        payments,
        settings,
        courses,
        ...SieStudentRouteCatalog.all,
        ...SieTeacherRouteCatalog.all,
        ...SieFreelancerRouteCatalog.all,
        ...SieCompanyRouteCatalog.all,
        ...SieAdminRouteCatalog.all,
      ];
}
