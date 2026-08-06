import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';

/// Explicit Admin Module SIE route policies (Phase 5 — highest security).
///
/// `admin.dashboard` lives in [SieSkillForgeRouteCatalog] (restricted L2).
/// All other Admin surfaces are declared here for Integration + PRF.
///
/// Security before convenience: destructive / secrets / billing / auth
/// surfaces are Traditional Input Only (disabled L3/L4).
abstract final class SieAdminRouteCatalog {
  /// Super-admin global control dashboard.
  static const SieRoutePolicy superDashboard = SieRoutePolicy(
    routeId: 'admin.super_dashboard',
    displayName: 'Super Admin Dashboard',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Analytics / telemetry browse.
  static const SieRoutePolicy analytics = SieRoutePolicy(
    routeId: 'admin.analytics',
    displayName: 'Admin Analytics',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.admin,
  );

  /// Reports.
  static const SieRoutePolicy reports = SieRoutePolicy(
    routeId: 'admin.reports',
    displayName: 'Admin Reports',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.admin,
  );

  /// Platform monitoring / health (read).
  static const SieRoutePolicy monitoring = SieRoutePolicy(
    routeId: 'admin.monitoring',
    displayName: 'Platform Monitoring',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Audit logs — browse.
  static const SieRoutePolicy auditLogs = SieRoutePolicy(
    routeId: 'admin.audit_logs',
    displayName: 'Audit Logs',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// System logs.
  static const SieRoutePolicy systemLogs = SieRoutePolicy(
    routeId: 'admin.system_logs',
    displayName: 'System Logs',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Notification / inbox center.
  static const SieRoutePolicy notifications = SieRoutePolicy(
    routeId: 'admin.notifications',
    displayName: 'Admin Inbox',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.admin,
  );

  /// AI admin assistant.
  static const SieRoutePolicy aiAssistant = SieRoutePolicy(
    routeId: 'admin.ai_assistant',
    displayName: 'AI Admin Assistant',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.aiAssistant,
  );

  /// Feature flags — browse + confirmation for changes.
  static const SieRoutePolicy featureFlags = SieRoutePolicy(
    routeId: 'admin.feature_flags',
    displayName: 'Feature Flags',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Progressive rollout console — restricted confirmation.
  static const SieRoutePolicy progressiveRollout = SieRoutePolicy(
    routeId: 'admin.progressive_rollout',
    displayName: 'Progressive Rollout',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// User management — browse + selection.
  static const SieRoutePolicy users = SieRoutePolicy(
    routeId: 'admin.users',
    displayName: 'User Management',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// User details — browse.
  static const SieRoutePolicy userDetails = SieRoutePolicy(
    routeId: 'admin.users.detail',
    displayName: 'User Details',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Role management — browse only.
  static const SieRoutePolicy roles = SieRoutePolicy(
    routeId: 'admin.roles',
    displayName: 'Role Management',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Permission management — browse only (writes traditional).
  static const SieRoutePolicy permissions = SieRoutePolicy(
    routeId: 'admin.permissions',
    displayName: 'Permission Management',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Organization management — restricted.
  static const SieRoutePolicy organizations = SieRoutePolicy(
    routeId: 'admin.organizations',
    displayName: 'Organization Management',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Course / marketplace / identity verification queues.
  static const SieRoutePolicy verification = SieRoutePolicy(
    routeId: 'admin.verification',
    displayName: 'Verification Queues',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Course moderation.
  static const SieRoutePolicy courseModeration = SieRoutePolicy(
    routeId: 'admin.moderation.courses',
    displayName: 'Course Moderation',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Marketplace moderation.
  static const SieRoutePolicy marketplaceModeration = SieRoutePolicy(
    routeId: 'admin.moderation.marketplace',
    displayName: 'Marketplace Moderation',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// CMS / legal editor — limited.
  static const SieRoutePolicy cms = SieRoutePolicy(
    routeId: 'admin.cms',
    displayName: 'CMS / Legal Editor',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Theme settings — limited.
  static const SieRoutePolicy theme = SieRoutePolicy(
    routeId: 'admin.theme',
    displayName: 'Theme Engine',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Motion settings — limited.
  static const SieRoutePolicy motion = SieRoutePolicy(
    routeId: 'admin.motion',
    displayName: 'Motion Engine',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Language settings — limited.
  static const SieRoutePolicy language = SieRoutePolicy(
    routeId: 'admin.language',
    displayName: 'Language System',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Platform org settings — restricted.
  static const SieRoutePolicy orgSettings = SieRoutePolicy(
    routeId: 'admin.org_settings',
    displayName: 'Platform Settings',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  /// Resolution desk — restricted moderation.
  static const SieRoutePolicy resolutions = SieRoutePolicy(
    routeId: 'admin.resolutions',
    displayName: 'Resolution Desk',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.admin,
  );

  // —— Traditional Input Only (L3) ——

  /// API key management.
  static const SieRoutePolicy apiKeys = SieRoutePolicy(
    routeId: 'admin.api_keys',
    displayName: 'API Keys',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Security center.
  static const SieRoutePolicy securityCenter = SieRoutePolicy(
    routeId: 'admin.security_center',
    displayName: 'Security Center',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Database operations.
  static const SieRoutePolicy databaseOps = SieRoutePolicy(
    routeId: 'admin.database',
    displayName: 'Database Operations',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Environment configuration.
  static const SieRoutePolicy environment = SieRoutePolicy(
    routeId: 'admin.environment',
    displayName: 'Environment Configuration',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Secrets management.
  static const SieRoutePolicy secrets = SieRoutePolicy(
    routeId: 'admin.secrets',
    displayName: 'Secrets',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Billing / finance / monetization / payouts / invoices.
  static const SieRoutePolicy billing = SieRoutePolicy(
    routeId: 'admin.billing',
    displayName: 'Billing / Finance',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Authentication / email settings.
  static const SieRoutePolicy authSettings = SieRoutePolicy(
    routeId: 'admin.auth_settings',
    displayName: 'Authentication Settings',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Backup restore.
  static const SieRoutePolicy backupRestore = SieRoutePolicy(
    routeId: 'admin.backup_restore',
    displayName: 'Backup Restore',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Delete / ban operations.
  static const SieRoutePolicy deleteOps = SieRoutePolicy(
    routeId: 'admin.delete_ops',
    displayName: 'Delete Operations',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Platform shutdown / maintenance.
  static const SieRoutePolicy shutdown = SieRoutePolicy(
    routeId: 'admin.shutdown',
    displayName: 'Platform Shutdown',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Emergency controls / recovery writes.
  static const SieRoutePolicy emergency = SieRoutePolicy(
    routeId: 'admin.emergency',
    displayName: 'Emergency Controls',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// AI usage control / credit grants (financial-adjacent).
  static const SieRoutePolicy aiUsageControl = SieRoutePolicy(
    routeId: 'admin.ai_usage_control',
    displayName: 'AI Usage Control',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Role / permission assignment writes.
  static const SieRoutePolicy roleAssignment = SieRoutePolicy(
    routeId: 'admin.role_assignment',
    displayName: 'Role Assignment',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Incident management writes (browse via monitoring).
  static const SieRoutePolicy incidentWrite = SieRoutePolicy(
    routeId: 'admin.incidents.write',
    displayName: 'Incident Write Ops',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  // —— L4 irreversible ——

  /// Account / user deletion — L4.
  static const SieRoutePolicy accountDeletion = SieRoutePolicy(
    routeId: 'admin.account_deletion',
    displayName: 'Account Deletion',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l4Irreversible,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// Critical / emergency irreversible ops.
  static const SieRoutePolicy critical = SieRoutePolicy(
    routeId: 'admin.critical',
    displayName: 'Critical Admin Ops',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l4Irreversible,
    module: SieAppModuleId.admin,
    sieEnabled: false,
  );

  /// All Admin Module policies (excludes shared `admin.dashboard`).
  static const List<SieRoutePolicy> all = [
    superDashboard,
    analytics,
    reports,
    monitoring,
    auditLogs,
    systemLogs,
    notifications,
    aiAssistant,
    featureFlags,
    progressiveRollout,
    users,
    userDetails,
    roles,
    permissions,
    organizations,
    verification,
    courseModeration,
    marketplaceModeration,
    cms,
    theme,
    motion,
    language,
    orgSettings,
    resolutions,
    apiKeys,
    securityCenter,
    databaseOps,
    environment,
    secrets,
    billing,
    authSettings,
    backupRestore,
    deleteOps,
    shutdown,
    emergency,
    aiUsageControl,
    roleAssignment,
    incidentWrite,
    accountDeletion,
    critical,
  ];
}
