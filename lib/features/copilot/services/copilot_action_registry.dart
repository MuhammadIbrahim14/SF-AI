import '../../../app/router/route_names.dart';
import '../models/copilot_action_model.dart';
import '../models/copilot_intent_model.dart';
import 'copilot_route_catalog.dart';

class CopilotActionRegistry {
  const CopilotActionRegistry();

  CopilotActionModel actionFor({
    required CopilotIntentModel intent,
    required String? role,
    required String? accountType,
  }) {
    final normalizedRole = _normalizeRole(role);
    final normalizedAccountType = _normalize(accountType);

    if (intent.actionLevel == CopilotActionLevel.sensitive) {
      return CopilotActionModel(
        actionId: intent.type,
        label: _labelFor(intent.type),
        actionLevel: intent.actionLevel,
        requiresConfirmation: true,
        isAvailable: false,
        unavailableReason: _sensitiveReason(intent.type),
      );
    }

    final destination = CopilotRouteCatalog.byId(intent.destinationId);
    if (destination != null) {
      return CopilotActionModel(
        actionId: destination.id,
        label: destination.title,
        actionLevel: destination.actionLevel,
        targetRoute: destination.isAvailable ? destination.path : null,
        requiredRole: destination.allowedRoles.isNotEmpty
            ? destination.allowedRoles.first
            : null,
        requiresConfirmation: intent.needsConfirmation,
        isAvailable: destination.isAvailable,
        unavailableReason: destination.unavailableReason,
        message: _messageFor(intent.type),
      );
    }

    final route =
        intent.targetRoute ??
        _routeFor(
          intent.type,
          role: normalizedRole,
          accountType: normalizedAccountType,
        );

    return CopilotActionModel(
      actionId: intent.type,
      label: _labelFor(intent.type),
      actionLevel: intent.actionLevel,
      targetRoute: route,
      requiredRole: intent.requiredRole,
      requiresConfirmation: intent.needsConfirmation,
      isAvailable:
          route != null ||
          intent.actionLevel == CopilotActionLevel.explanation ||
          intent.actionLevel == CopilotActionLevel.guidedAction,
      unavailableReason:
          route == null &&
              intent.actionLevel == CopilotActionLevel.safeNavigation
          ? 'No safe route is available for this workspace.'
          : null,
      message: _messageFor(intent.type),
    );
  }

  List<CopilotActionModel> quickActionsFor({
    required String? role,
    required String? accountType,
  }) {
    final normalizedRole = _normalizeRole(role);
    final normalizedAccountType = _normalize(accountType);

    final destinationIds = normalizedAccountType == 'customer'
        ? const [
            'customerDashboard',
            'customerWallet',
            'customerOrders',
            'customerResolution',
            'servicesMarketplace',
            'support',
            'profileCustomer',
          ]
        : normalizedRole == 'freelancer'
        ? const [
            'freelancerDashboard',
            'freelancerServiceRequests',
            'freelancerOrders',
            'freelancerServices',
            'freelancerPayouts',
            'freelancerResolution',
            'profileFreelancer',
          ]
        : normalizedRole == 'teacher'
        ? const [
            'teacherDashboard',
            'teacherCourses',
            'teacherCourseCreate',
            'teacherStudentProgress',
            'support',
            'profileTeacher',
          ]
        : normalizedRole == 'company'
        ? const [
            'companyDashboard',
            'companyJobs',
            'createJob',
            'hiringPipeline',
            'myInterviews',
            'support',
            'profileCompany',
          ]
        : _isAdmin(normalizedRole)
        ? const [
            'adminDashboard',
            'adminResolutionDesk',
            'adminUsers',
            'adminPayouts',
            'adminFinance',
            'adminLogs',
            'adminLegal',
            'support',
          ]
        : const [
            'studentDashboard',
            'studentCourses',
            'studentEnrolledCourses',
            'studentCertificates',
            'studentResume',
            'jobs',
            'support',
            'profileStudent',
          ];

    final actions = <CopilotActionModel>[
      ..._guidedQuickActions(
        role: normalizedRole,
        accountType: normalizedAccountType,
      ),
    ];
    for (final id in destinationIds) {
      final destination = CopilotRouteCatalog.byId(id);
      if (destination == null || !destination.isAvailable) continue;
      if (!CopilotRouteCatalog.isAllowed(
        destination,
        role: normalizedRole,
        accountType: normalizedAccountType,
      )) {
        continue;
      }
      actions.add(
        CopilotActionModel(
          actionId: destination.id,
          label: destination.title,
          actionLevel: destination.actionLevel,
          targetRoute: destination.path,
          requiredRole: destination.allowedRoles.isNotEmpty
              ? destination.allowedRoles.first
              : null,
          isAvailable: true,
        ),
      );
    }
    return actions;
  }

  List<CopilotActionModel> _guidedQuickActions({
    required String role,
    required String accountType,
  }) {
    final items = accountType == 'customer'
        ? const [
            (CopilotIntentType.guideRefundRequest, 'Request Refund'),
            (CopilotIntentType.guideOpenDispute, 'Open Dispute'),
            (CopilotIntentType.guideAddEvidence, 'Add Evidence'),
            (CopilotIntentType.guideOpenWalletTopUp, 'Wallet Top-up Help'),
            (CopilotIntentType.guideContactSupport, 'Contact Support'),
          ]
        : role == 'freelancer'
        ? const [
            (CopilotIntentType.guideSubmitDelivery, 'Submit Delivery'),
            (CopilotIntentType.guideAddEvidence, 'Add Evidence'),
            (CopilotIntentType.guidePayoutRequest, 'Create Payout Request'),
            (
              CopilotIntentType.guideManageServiceRequests,
              'Manage Service Requests',
            ),
            (CopilotIntentType.guideContactSupport, 'Contact Support'),
          ]
        : role == 'teacher'
        ? const [
            (CopilotIntentType.guideCreateCourse, 'Create Course'),
            (CopilotIntentType.guideManageCourse, 'Manage Course'),
            (CopilotIntentType.guideCreateCertificate, 'Manage Certificates'),
            (CopilotIntentType.guideContactSupport, 'Contact Support'),
          ]
        : role == 'company'
        ? const [
            (CopilotIntentType.guidePostJob, 'Post Job'),
            (CopilotIntentType.guideReviewApplications, 'Review Applications'),
            (CopilotIntentType.guideContactSupport, 'Contact Support'),
          ]
        : _isAdmin(role)
        ? const [
            (
              CopilotIntentType.guideReviewResolutionCase,
              'Review Resolution Case',
            ),
            (CopilotIntentType.guideRequestEvidence, 'Request Evidence'),
            (CopilotIntentType.guideReviewPayout, 'Review Payout'),
            (
              CopilotIntentType.getSettlementBackendStatus,
              'Settlement Backend Status',
            ),
            (CopilotIntentType.explainSkillForgeLaw, 'Explain SkillForge Law'),
          ]
        : const <(String, String)>[];

    return items
        .map(
          (item) => CopilotActionModel(
            actionId: item.$1,
            label: item.$2,
            actionLevel: item.$1 == CopilotIntentType.getSettlementBackendStatus
                ? CopilotActionLevel.dataRead
                : item.$1 == CopilotIntentType.explainSkillForgeLaw
                ? CopilotActionLevel.explanation
                : CopilotActionLevel.guidedAction,
            isAvailable: true,
          ),
        )
        .toList(growable: false);
  }

  String? _routeFor(
    String type, {
    required String role,
    required String accountType,
  }) {
    switch (type) {
      case CopilotIntentType.openDashboard:
        return _dashboardRoute(role: role, accountType: accountType);
      case CopilotIntentType.openWallet:
        return role == 'freelancer'
            ? RoutePaths.freelancerWallet
            : RoutePaths.customerWallet;
      case CopilotIntentType.openOrders:
        return role == 'freelancer'
            ? RoutePaths.freelancerServiceOrders
            : RoutePaths.serviceOrders;
      case CopilotIntentType.openCustomerOrders:
        return RoutePaths.serviceOrders;
      case CopilotIntentType.openFreelancerOrders:
        return RoutePaths.freelancerServiceOrders;
      case CopilotIntentType.openServiceRequests:
        return role == 'freelancer'
            ? RoutePaths.freelancerServiceRequests
            : RoutePaths.serviceRequests;
      case CopilotIntentType.openResolutionCenter:
        if (_isAdmin(role)) return RoutePaths.adminResolutionDesk;
        return role == 'freelancer'
            ? RoutePaths.freelancerResolutions
            : RoutePaths.customerResolutions;
      case CopilotIntentType.openAdminResolutionDesk:
        return RoutePaths.adminResolutionDesk;
      case CopilotIntentType.openPayouts:
        return _isAdmin(role)
            ? RoutePaths.adminPayouts
            : RoutePaths.freelancerPayouts;
      case CopilotIntentType.openSupport:
        return RoutePaths.contactUs;
      case CopilotIntentType.openPrivacyPolicy:
        return RoutePaths.privacyPolicy;
      case CopilotIntentType.openTerms:
        return RoutePaths.termsOfService;
      case CopilotIntentType.openProfile:
        return _profileRoute(role: role, accountType: accountType);
      case CopilotIntentType.openSettings:
        return RoutePaths.securitySettings;
      case CopilotIntentType.guideRefundRequest:
      case CopilotIntentType.guideOpenDispute:
      case CopilotIntentType.guideAddEvidence:
        if (_isAdmin(role)) return RoutePaths.adminResolutionDesk;
        return role == 'freelancer'
            ? RoutePaths.freelancerResolutions
            : RoutePaths.customerResolutions;
      case CopilotIntentType.guideRequestRevision:
        return RoutePaths.customerResolutions;
      case CopilotIntentType.guideSubmitDelivery:
        return role == 'freelancer' ? RoutePaths.freelancerServiceOrders : null;
      case CopilotIntentType.guidePayoutRequest:
        return role == 'freelancer' ? RoutePaths.freelancerPayouts : null;
      case CopilotIntentType.guideOpenWalletTopUp:
        return RoutePaths.customerWallet;
      case CopilotIntentType.guideCreateServiceRequest:
        return RoutePaths.servicesMarketplace;
      case CopilotIntentType.guideContactSupport:
        return RoutePaths.contactUs;
      case CopilotIntentType.guideManageServiceRequests:
        return RoutePaths.freelancerServiceRequests;
      case CopilotIntentType.guideUpdateServicePackages:
        return RoutePaths.freelancerServices;
      case CopilotIntentType.guideCreateCourse:
        return RoutePaths.teacherCourseCreate;
      case CopilotIntentType.guideManageCourse:
      case CopilotIntentType.guideCreateCertificate:
        return RoutePaths.teacherCourses;
      case CopilotIntentType.guidePostJob:
        return RoutePaths.createJob;
      case CopilotIntentType.guideReviewApplications:
        return RoutePaths.hiringPipeline;
      case CopilotIntentType.guideReviewResolutionCase:
      case CopilotIntentType.guideRequestEvidence:
        return RoutePaths.adminResolutionDesk;
      case CopilotIntentType.guideReviewPayout:
        return RoutePaths.adminPayouts;
      case CopilotIntentType.guideManageLaw:
        return RoutePaths.adminLegalEditor;
      default:
        return null;
    }
  }

  String? _dashboardRoute({required String role, required String accountType}) {
    if (accountType == 'customer') return RoutePaths.customerDashboard;
    switch (role) {
      case 'student':
        return RoutePaths.studentDashboard;
      case 'teacher':
        return RoutePaths.teacherDashboard;
      case 'freelancer':
        return RoutePaths.freelancerDashboard;
      case 'company':
        return RoutePaths.companyDashboard;
      case 'admin':
        return RoutePaths.adminDashboard;
      case 'superadmin':
        return RoutePaths.superAdminDashboard;
      default:
        return RoutePaths.dashboard;
    }
  }

  String? _profileRoute({required String role, required String accountType}) {
    if (accountType == 'customer') return RoutePaths.profilePersonal;
    switch (role) {
      case 'student':
        return RoutePaths.studentProfile;
      case 'teacher':
        return RoutePaths.teacherProfile;
      case 'freelancer':
        return RoutePaths.freelancerProfile;
      case 'company':
        return RoutePaths.companyProfile;
      default:
        return RoutePaths.profilePersonal;
    }
  }
}

String _labelFor(String type) {
  switch (type) {
    case CopilotIntentType.openDashboard:
      return 'Open Dashboard';
    case CopilotIntentType.openWallet:
      return 'Open Wallet';
    case CopilotIntentType.openOrders:
    case CopilotIntentType.openCustomerOrders:
    case CopilotIntentType.openFreelancerOrders:
      return 'Open Orders';
    case CopilotIntentType.openServiceRequests:
      return 'Open Service Requests';
    case CopilotIntentType.openResolutionCenter:
    case CopilotIntentType.openAdminResolutionDesk:
      return 'Open Resolution Center';
    case CopilotIntentType.openPayouts:
      return 'Open Payouts';
    case CopilotIntentType.openSupport:
      return 'Contact Support';
    case CopilotIntentType.openPrivacyPolicy:
      return 'Privacy Policy';
    case CopilotIntentType.openTerms:
      return 'Terms of Service';
    case CopilotIntentType.openProfile:
      return 'Open Profile';
    case CopilotIntentType.openSettings:
      return 'Open Settings';
    case CopilotIntentType.guideSubmitDelivery:
      return 'Guide: Submit Delivery';
    case CopilotIntentType.guideRefundRequest:
      return 'Guide: Request Refund';
    case CopilotIntentType.guideOpenDispute:
      return 'Guide: Open Dispute';
    case CopilotIntentType.guideAddEvidence:
      return 'Guide: Add Evidence';
    case CopilotIntentType.guidePayoutRequest:
      return 'Guide: Request Payout';
    case CopilotIntentType.guideRequestRevision:
      return 'Guide: Request Revision';
    case CopilotIntentType.guideOpenWalletTopUp:
      return 'Guide: Wallet Top-up';
    case CopilotIntentType.guideCreateServiceRequest:
      return 'Guide: Create Service Request';
    case CopilotIntentType.guideContactSupport:
      return 'Guide: Contact Support';
    case CopilotIntentType.guideManageServiceRequests:
      return 'Guide: Manage Requests';
    case CopilotIntentType.guideUpdateServicePackages:
      return 'Guide: Update Services';
    case CopilotIntentType.guideCreateCourse:
      return 'Guide: Create Course';
    case CopilotIntentType.guideManageCourse:
      return 'Guide: Manage Course';
    case CopilotIntentType.guideCreateCertificate:
      return 'Guide: Certificates';
    case CopilotIntentType.guidePostJob:
      return 'Guide: Post Job';
    case CopilotIntentType.guideReviewApplications:
      return 'Guide: Review Applications';
    case CopilotIntentType.guideReviewResolutionCase:
      return 'Guide: Review Case';
    case CopilotIntentType.guideRequestEvidence:
      return 'Guide: Request Evidence';
    case CopilotIntentType.guideReviewPayout:
      return 'Guide: Review Payout';
    case CopilotIntentType.guideManageLaw:
      return 'Guide: Manage Policy';
    case CopilotIntentType.explainEscrow:
      return 'Explain Escrow';
    case CopilotIntentType.explainSettlementPaused:
      return 'Backend Status';
    case CopilotIntentType.explainSkillForgeLaw:
      return 'SkillForge Law';
    default:
      return 'Copilot Help';
  }
}

String? _messageFor(String type) {
  switch (type) {
    case CopilotIntentType.explainSettlementPaused:
      return 'Release and split settlement require the backend executor. They stay paused until Blaze and Cloud Functions are available.';
    case CopilotIntentType.explainSkillForgeLaw:
      return 'SkillForge Law is the platform rule layer that guides resolution decisions using order, delivery, evidence, and payment state.';
    default:
      return null;
  }
}

String _sensitiveReason(String type) {
  if (type == CopilotIntentType.releaseEscrow ||
      type == CopilotIntentType.splitSettlement) {
    return 'Backend executor required. Enable Blaze and deploy Cloud Functions to activate Release/Split.';
  }
  return 'This is a sensitive action. Copilot can guide you, but it will not execute payments, payouts, refunds, deletes, or admin enforcement.';
}

bool _isAdmin(String role) => role == 'admin' || role == 'superadmin';

String _normalizeRole(String? value) {
  final normalized = _normalize(value);
  if (normalized == 'superadmin' || normalized == 'super_admin') {
    return 'superadmin';
  }
  return normalized;
}

String _normalize(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '')
      .trim();
}
