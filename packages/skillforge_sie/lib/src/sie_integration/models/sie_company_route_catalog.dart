import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';

/// Explicit Company Module SIE route policies (Phase 4).
///
/// `company.dashboard` lives in [SieSkillForgeRouteCatalog]; all other
/// Company surfaces are declared here for Integration + PRF.
abstract final class SieCompanyRouteCatalog {
  /// Company onboarding.
  static const SieRoutePolicy onboarding = SieRoutePolicy(
    routeId: 'company.onboarding',
    displayName: 'Company Onboarding',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Organization overview.
  static const SieRoutePolicy organization = SieRoutePolicy(
    routeId: 'company.organization',
    displayName: 'Organization Overview',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Job listings / management.
  static const SieRoutePolicy jobs = SieRoutePolicy(
    routeId: 'company.jobs',
    displayName: 'Job Management',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Job creation / publishing — confirmation required.
  static const SieRoutePolicy jobCreate = SieRoutePolicy(
    routeId: 'company.jobs.create',
    displayName: 'Job Creation',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Job edit.
  static const SieRoutePolicy jobEdit = SieRoutePolicy(
    routeId: 'company.jobs.edit',
    displayName: 'Job Edit',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Job detail.
  static const SieRoutePolicy jobDetail = SieRoutePolicy(
    routeId: 'company.jobs.detail',
    displayName: 'Job Detail',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Candidate pipeline / ATS.
  static const SieRoutePolicy pipeline = SieRoutePolicy(
    routeId: 'company.pipeline',
    displayName: 'Candidate Pipeline',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Per-job hiring pipeline / applicants.
  static const SieRoutePolicy pipelineJob = SieRoutePolicy(
    routeId: 'company.pipeline.job',
    displayName: 'Job Hiring Pipeline',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Talent search.
  static const SieRoutePolicy talentSearch = SieRoutePolicy(
    routeId: 'company.talent_search',
    displayName: 'Talent Search',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Company projects / team workspace.
  static const SieRoutePolicy projects = SieRoutePolicy(
    routeId: 'company.projects',
    displayName: 'Company Projects',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Team workspace.
  static const SieRoutePolicy teamWorkspace = SieRoutePolicy(
    routeId: 'company.team',
    displayName: 'Team Workspace',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Departments.
  static const SieRoutePolicy departments = SieRoutePolicy(
    routeId: 'company.departments',
    displayName: 'Departments',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Employees directory — restricted operations for sensitive actions.
  static const SieRoutePolicy employees = SieRoutePolicy(
    routeId: 'company.employees',
    displayName: 'Employees',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Interview list.
  static const SieRoutePolicy interviews = SieRoutePolicy(
    routeId: 'company.interviews',
    displayName: 'Interviews',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Schedule interview — confirmation.
  static const SieRoutePolicy interviewSchedule = SieRoutePolicy(
    routeId: 'company.interviews.schedule',
    displayName: 'Schedule Interview',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Interview detail.
  static const SieRoutePolicy interviewDetail = SieRoutePolicy(
    routeId: 'company.interviews.detail',
    displayName: 'Interview Detail',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Evaluate interview / hiring decision adjacent.
  static const SieRoutePolicy interviewEvaluate = SieRoutePolicy(
    routeId: 'company.interviews.evaluate',
    displayName: 'Evaluate Interview',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Assessments.
  static const SieRoutePolicy assessments = SieRoutePolicy(
    routeId: 'company.assessments',
    displayName: 'Assessments',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// AI hiring assistant.
  static const SieRoutePolicy aiHiring = SieRoutePolicy(
    routeId: 'company.ai_hiring',
    displayName: 'AI Hiring Assistant',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.aiAssistant,
  );

  /// Analytics.
  static const SieRoutePolicy analytics = SieRoutePolicy(
    routeId: 'company.analytics',
    displayName: 'Analytics',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Reports.
  static const SieRoutePolicy reports = SieRoutePolicy(
    routeId: 'company.reports',
    displayName: 'Reports',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Financial reports — browse only.
  static const SieRoutePolicy financialReports = SieRoutePolicy(
    routeId: 'company.reports.financial',
    displayName: 'Financial Reports',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.marketplace,
  );

  /// Notifications.
  static const SieRoutePolicy notifications = SieRoutePolicy(
    routeId: 'company.notifications',
    displayName: 'Notifications',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Documents / resumes / contracts.
  static const SieRoutePolicy documents = SieRoutePolicy(
    routeId: 'company.documents',
    displayName: 'Documents',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Sensitive document actions — confirmation.
  static const SieRoutePolicy documentsSensitive = SieRoutePolicy(
    routeId: 'company.documents.sensitive',
    displayName: 'Sensitive Documents',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Company profile.
  static const SieRoutePolicy profile = SieRoutePolicy(
    routeId: 'company.profile',
    displayName: 'Company Profile',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.company,
  );

  /// Edit company profile — elevated.
  static const SieRoutePolicy profileEdit = SieRoutePolicy(
    routeId: 'company.profile.edit',
    displayName: 'Edit Company Profile',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Organization settings — confirmation required.
  static const SieRoutePolicy orgSettings = SieRoutePolicy(
    routeId: 'company.org_settings',
    displayName: 'Organization Settings',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.company,
  );

  /// Billing — traditional only.
  static const SieRoutePolicy billing = SieRoutePolicy(
    routeId: 'company.billing',
    displayName: 'Billing',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Subscription management — traditional only.
  static const SieRoutePolicy subscription = SieRoutePolicy(
    routeId: 'company.subscription',
    displayName: 'Subscription Management',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Organization ownership — traditional only.
  static const SieRoutePolicy ownership = SieRoutePolicy(
    routeId: 'company.ownership',
    displayName: 'Organization Ownership',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.company,
    sieEnabled: false,
  );

  /// Role assignment — traditional only.
  static const SieRoutePolicy roles = SieRoutePolicy(
    routeId: 'company.roles',
    displayName: 'Role Assignment',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.company,
    sieEnabled: false,
  );

  /// Permission management — traditional only.
  static const SieRoutePolicy permissions = SieRoutePolicy(
    routeId: 'company.permissions',
    displayName: 'Permission Management',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.company,
    sieEnabled: false,
  );

  /// Account security — traditional only.
  static const SieRoutePolicy accountSecurity = SieRoutePolicy(
    routeId: 'company.account_security',
    displayName: 'Account Security',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.company,
    sieEnabled: false,
  );

  /// Account deletion — L4.
  static const SieRoutePolicy accountDeletion = SieRoutePolicy(
    routeId: 'company.account_deletion',
    displayName: 'Account Deletion',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l4Irreversible,
    module: SieAppModuleId.company,
    sieEnabled: false,
  );

  /// All Company Module policies (excludes shared `company.dashboard`).
  static const List<SieRoutePolicy> all = [
    onboarding,
    organization,
    jobs,
    jobCreate,
    jobEdit,
    jobDetail,
    pipeline,
    pipelineJob,
    talentSearch,
    projects,
    teamWorkspace,
    departments,
    employees,
    interviews,
    interviewSchedule,
    interviewDetail,
    interviewEvaluate,
    assessments,
    aiHiring,
    analytics,
    reports,
    financialReports,
    notifications,
    documents,
    documentsSensitive,
    profile,
    profileEdit,
    orgSettings,
    billing,
    subscription,
    ownership,
    roles,
    permissions,
    accountSecurity,
    accountDeletion,
  ];
}
