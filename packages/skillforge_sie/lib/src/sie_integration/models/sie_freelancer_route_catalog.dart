import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';

/// Explicit Freelancer Module SIE route policies (Phase 3).
///
/// `freelancer.dashboard` lives in [SieSkillForgeRouteCatalog]; all other
/// Freelancer surfaces are declared here for Integration + PRF.
abstract final class SieFreelancerRouteCatalog {
  /// Freelancer onboarding.
  static const SieRoutePolicy onboarding = SieRoutePolicy(
    routeId: 'freelancer.onboarding',
    displayName: 'Freelancer Onboarding',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Public / directory browse.
  static const SieRoutePolicy directory = SieRoutePolicy(
    routeId: 'freelancer.directory',
    displayName: 'Freelancer Directory',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Portfolio studio.
  static const SieRoutePolicy portfolioStudio = SieRoutePolicy(
    routeId: 'freelancer.portfolio_studio',
    displayName: 'Portfolio Studio',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// My services list.
  static const SieRoutePolicy services = SieRoutePolicy(
    routeId: 'freelancer.services',
    displayName: 'My Services',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Create service listing.
  static const SieRoutePolicy serviceCreate = SieRoutePolicy(
    routeId: 'freelancer.services.create',
    displayName: 'Create Service',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Edit service listing.
  static const SieRoutePolicy serviceEdit = SieRoutePolicy(
    routeId: 'freelancer.services.edit',
    displayName: 'Edit Service',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Service requests / client intake (proposal workspace).
  static const SieRoutePolicy serviceRequests = SieRoutePolicy(
    routeId: 'freelancer.service_requests',
    displayName: 'Service Requests',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Active orders / projects list.
  static const SieRoutePolicy orders = SieRoutePolicy(
    routeId: 'freelancer.orders',
    displayName: 'Service Orders',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Order / client workspace detail — elevated (contract-adjacent).
  static const SieRoutePolicy orderDetail = SieRoutePolicy(
    routeId: 'freelancer.orders.detail',
    displayName: 'Order Detail / Client Workspace',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.freelancer,
  );

  /// Contract acceptance — traditional input only.
  static const SieRoutePolicy contractAccept = SieRoutePolicy(
    routeId: 'freelancer.contracts.accept',
    displayName: 'Contract Acceptance',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.freelancer,
    sieEnabled: false,
  );

  /// Proposal manager / drafts.
  static const SieRoutePolicy proposals = SieRoutePolicy(
    routeId: 'freelancer.proposals',
    displayName: 'Proposal Manager',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Publish / submit proposal — confirmation required.
  static const SieRoutePolicy proposalPublish = SieRoutePolicy(
    routeId: 'freelancer.proposals.publish',
    displayName: 'Publish Proposal',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.freelancer,
  );

  /// Project timeline / milestones (future-ready).
  static const SieRoutePolicy timeline = SieRoutePolicy(
    routeId: 'freelancer.timeline',
    displayName: 'Project Timeline',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Tasks / delivery helper.
  static const SieRoutePolicy tasks = SieRoutePolicy(
    routeId: 'freelancer.tasks',
    displayName: 'Tasks',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Time tracking — deliberate select for start/stop.
  static const SieRoutePolicy timeTracking = SieRoutePolicy(
    routeId: 'freelancer.time_tracking',
    displayName: 'Time Tracking',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Deliverables review.
  static const SieRoutePolicy deliverables = SieRoutePolicy(
    routeId: 'freelancer.deliverables',
    displayName: 'Deliverables',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// File manager.
  static const SieRoutePolicy files = SieRoutePolicy(
    routeId: 'freelancer.files',
    displayName: 'File Manager',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Messages / client conversations (future-ready).
  static const SieRoutePolicy messages = SieRoutePolicy(
    routeId: 'freelancer.messages',
    displayName: 'Messages',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// AI freelancer assistant.
  static const SieRoutePolicy aiAssistant = SieRoutePolicy(
    routeId: 'freelancer.ai_assistant',
    displayName: 'AI Freelancer Assistant',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.aiAssistant,
  );

  /// Job applications.
  static const SieRoutePolicy applications = SieRoutePolicy(
    routeId: 'freelancer.applications',
    displayName: 'My Applications',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Interviews.
  static const SieRoutePolicy interviews = SieRoutePolicy(
    routeId: 'freelancer.interviews',
    displayName: 'My Interviews',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Job browse (when entered from freelancer shell).
  static const SieRoutePolicy jobs = SieRoutePolicy(
    routeId: 'freelancer.jobs',
    displayName: 'Browse Jobs',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Wallet / earnings overview — browse only.
  static const SieRoutePolicy wallet = SieRoutePolicy(
    routeId: 'freelancer.wallet',
    displayName: 'Wallet / Earnings',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.marketplace,
  );

  /// Invoice list — browse.
  static const SieRoutePolicy invoices = SieRoutePolicy(
    routeId: 'freelancer.invoices',
    displayName: 'Invoices',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.marketplace,
  );

  /// Invoice create / irreversible payment confirm — restricted.
  static const SieRoutePolicy invoiceCreate = SieRoutePolicy(
    routeId: 'freelancer.invoices.create',
    displayName: 'Invoice Creation',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.marketplace,
  );

  /// Invoice detail.
  static const SieRoutePolicy invoiceDetail = SieRoutePolicy(
    routeId: 'freelancer.invoices.detail',
    displayName: 'Invoice Detail',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.marketplace,
  );

  /// Payouts / withdraw funds — traditional only.
  static const SieRoutePolicy payouts = SieRoutePolicy(
    routeId: 'freelancer.payouts',
    displayName: 'Payouts / Withdraw',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Payment approval — traditional only.
  static const SieRoutePolicy paymentApproval = SieRoutePolicy(
    routeId: 'freelancer.payments.approve',
    displayName: 'Payment Approval',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Banking details — traditional only.
  static const SieRoutePolicy banking = SieRoutePolicy(
    routeId: 'freelancer.banking',
    displayName: 'Banking Details',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Tax information — traditional only.
  static const SieRoutePolicy tax = SieRoutePolicy(
    routeId: 'freelancer.tax',
    displayName: 'Tax Information',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.payment,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.marketplace,
    sieEnabled: false,
  );

  /// Identity verification — traditional only.
  static const SieRoutePolicy identityVerification = SieRoutePolicy(
    routeId: 'freelancer.identity',
    displayName: 'Identity Verification',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.freelancer,
    sieEnabled: false,
  );

  /// Dispute / resolution center — elevated.
  static const SieRoutePolicy resolutions = SieRoutePolicy(
    routeId: 'freelancer.resolutions',
    displayName: 'Resolution Center',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.freelancer,
  );

  /// Reviews.
  static const SieRoutePolicy reviews = SieRoutePolicy(
    routeId: 'freelancer.reviews',
    displayName: 'Reviews',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Analytics.
  static const SieRoutePolicy analytics = SieRoutePolicy(
    routeId: 'freelancer.analytics',
    displayName: 'Analytics',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Notifications.
  static const SieRoutePolicy notifications = SieRoutePolicy(
    routeId: 'freelancer.notifications',
    displayName: 'Notifications',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Profile.
  static const SieRoutePolicy profile = SieRoutePolicy(
    routeId: 'freelancer.profile',
    displayName: 'Freelancer Profile',
    mode: SieRouteSieMode.enabled,
    capabilityKind: SieRouteCapabilityKind.dashboard,
    securityLevel: SieSecurityLevel.l1Standard,
    module: SieAppModuleId.freelancer,
  );

  /// Edit profile — elevated.
  static const SieRoutePolicy profileEdit = SieRoutePolicy(
    routeId: 'freelancer.profile.edit',
    displayName: 'Edit Freelancer Profile',
    mode: SieRouteSieMode.limited,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.freelancer,
  );

  /// Account security — traditional only.
  static const SieRoutePolicy accountSecurity = SieRoutePolicy(
    routeId: 'freelancer.account_security',
    displayName: 'Account Security',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.authentication,
    securityLevel: SieSecurityLevel.l3Sensitive,
    module: SieAppModuleId.freelancer,
    sieEnabled: false,
  );

  /// Account deletion — L4.
  static const SieRoutePolicy accountDeletion = SieRoutePolicy(
    routeId: 'freelancer.account_deletion',
    displayName: 'Account Deletion',
    mode: SieRouteSieMode.disabled,
    capabilityKind: SieRouteCapabilityKind.admin,
    securityLevel: SieSecurityLevel.l4Irreversible,
    module: SieAppModuleId.freelancer,
    sieEnabled: false,
  );

  /// Project archive — confirmation required.
  static const SieRoutePolicy projectArchive = SieRoutePolicy(
    routeId: 'freelancer.projects.archive',
    displayName: 'Archive Project',
    mode: SieRouteSieMode.restricted,
    capabilityKind: SieRouteCapabilityKind.custom,
    securityLevel: SieSecurityLevel.l2Elevated,
    module: SieAppModuleId.freelancer,
  );

  /// All Freelancer Module policies (excludes shared `freelancer.dashboard`).
  static const List<SieRoutePolicy> all = [
    onboarding,
    directory,
    portfolioStudio,
    services,
    serviceCreate,
    serviceEdit,
    serviceRequests,
    orders,
    orderDetail,
    contractAccept,
    proposals,
    proposalPublish,
    timeline,
    tasks,
    timeTracking,
    deliverables,
    files,
    messages,
    aiAssistant,
    applications,
    interviews,
    jobs,
    wallet,
    invoices,
    invoiceCreate,
    invoiceDetail,
    payouts,
    paymentApproval,
    banking,
    tax,
    identityVerification,
    resolutions,
    reviews,
    analytics,
    notifications,
    profile,
    profileEdit,
    accountSecurity,
    accountDeletion,
    projectArchive,
  ];
}
