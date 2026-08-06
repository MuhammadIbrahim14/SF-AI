import '../models/copilot_intent_model.dart';
import 'copilot_route_catalog.dart';

class CopilotPermissionResult {
  const CopilotPermissionResult({required this.allowed, this.reason});

  final bool allowed;
  final String? reason;
}

class CopilotPermissionService {
  const CopilotPermissionService();

  CopilotPermissionResult check({
    required CopilotIntentModel intent,
    required String? userId,
    required String? role,
    required String? accountType,
  }) {
    final normalizedRole = _normalizeRole(role);
    final normalizedAccountType = _normalize(accountType);

    if (intent.actionLevel == CopilotActionLevel.explanation) {
      return const CopilotPermissionResult(allowed: true);
    }

    if (intent.actionLevel == CopilotActionLevel.dataRead) {
      if ((userId ?? '').trim().isEmpty) {
        return const CopilotPermissionResult(
          allowed: false,
          reason: 'Please sign in first to read private workspace summaries.',
        );
      }
      return _checkDataRead(
        intent,
        role: normalizedRole,
        accountType: normalizedAccountType,
      );
    }

    if (_isAiAction(intent.actionLevel)) {
      return _checkAi(
        intent,
        userId: userId,
        role: normalizedRole,
        accountType: normalizedAccountType,
      );
    }

    if (intent.actionLevel == CopilotActionLevel.sensitive) {
      if (intent.type == CopilotIntentType.releaseEscrow ||
          intent.type == CopilotIntentType.splitSettlement) {
        return const CopilotPermissionResult(
          allowed: false,
          reason:
              'This is a sensitive action. I can guide you to the Resolution Desk, but you must confirm it manually. Release/Split settlement backend is currently paused until Blaze and Cloud Functions are available.',
        );
      }
      return const CopilotPermissionResult(
        allowed: false,
        reason:
            'I can explain this action, but I cannot execute money, admin, or destructive actions.',
      );
    }

    final destination = CopilotRouteCatalog.byId(intent.destinationId);
    if (destination != null) {
      final isPublic =
          destination.category == CopilotRouteCategory.legal ||
          destination.category == CopilotRouteCategory.support ||
          destination.category == CopilotRouteCategory.marketplace;
      if ((userId ?? '').trim().isEmpty && !isPublic) {
        return const CopilotPermissionResult(
          allowed: false,
          reason: 'Please sign in first to open private workspace pages.',
        );
      }
      final allowed = CopilotRouteCatalog.isAllowed(
        destination,
        role: normalizedRole,
        accountType: normalizedAccountType,
      );
      return _allowIf(
        allowed,
        'You do not have access to ${destination.title} with your current role.',
      );
    }

    if (intent.type == CopilotIntentType.openPrivacyPolicy ||
        intent.type == CopilotIntentType.openTerms ||
        intent.type == CopilotIntentType.openSupport) {
      return const CopilotPermissionResult(allowed: true);
    }

    if ((userId ?? '').trim().isEmpty) {
      return const CopilotPermissionResult(
        allowed: false,
        reason: 'Please sign in first to open private workspace pages.',
      );
    }

    if (intent.requiredRole != null &&
        !_roleMatches(normalizedRole, intent.requiredRole!)) {
      return CopilotPermissionResult(
        allowed: false,
        reason:
            'This action is available only for ${intent.requiredRole} users.',
      );
    }

    if (_isAdmin(normalizedRole)) {
      return const CopilotPermissionResult(allowed: true);
    }

    if (intent.actionLevel == CopilotActionLevel.guidedAction) {
      return _checkGuided(
        intent,
        role: normalizedRole,
        accountType: normalizedAccountType,
      );
    }

    if (normalizedAccountType == 'customer') {
      return _checkCustomer(intent);
    }

    if (normalizedRole == 'freelancer') {
      return _checkFreelancer(intent);
    }

    if (normalizedRole == 'student' ||
        normalizedRole == 'teacher' ||
        normalizedRole == 'company') {
      return _checkProfessional(intent, normalizedRole);
    }

    return const CopilotPermissionResult(
      allowed: false,
      reason: 'I could not verify access for this workspace.',
    );
  }

  CopilotPermissionResult _checkCustomer(CopilotIntentModel intent) {
    const allowed = {
      CopilotIntentType.openDashboard,
      CopilotIntentType.openWallet,
      CopilotIntentType.openOrders,
      CopilotIntentType.openCustomerOrders,
      CopilotIntentType.openServiceRequests,
      CopilotIntentType.openResolutionCenter,
      CopilotIntentType.openProfile,
      CopilotIntentType.openSettings,
    };
    return _allowIf(
      allowed.contains(intent.type),
      'This page is not part of the customer workspace.',
    );
  }

  CopilotPermissionResult _checkFreelancer(CopilotIntentModel intent) {
    const allowed = {
      CopilotIntentType.openDashboard,
      CopilotIntentType.openWallet,
      CopilotIntentType.openOrders,
      CopilotIntentType.openFreelancerOrders,
      CopilotIntentType.openServiceRequests,
      CopilotIntentType.openResolutionCenter,
      CopilotIntentType.openPayouts,
      CopilotIntentType.openProfile,
      CopilotIntentType.openSettings,
    };
    return _allowIf(
      allowed.contains(intent.type),
      'This page is not available in the freelancer workspace.',
    );
  }

  CopilotPermissionResult _checkProfessional(
    CopilotIntentModel intent,
    String role,
  ) {
    const common = {
      CopilotIntentType.openDashboard,
      CopilotIntentType.openProfile,
      CopilotIntentType.openSettings,
    };
    if (common.contains(intent.type)) {
      return const CopilotPermissionResult(allowed: true);
    }
    return CopilotPermissionResult(
      allowed: false,
      reason: 'This route is not available for the $role workspace.',
    );
  }

  CopilotPermissionResult _checkGuided(
    CopilotIntentModel intent, {
    required String role,
    required String accountType,
  }) {
    const freelancer = {
      CopilotIntentType.guideSubmitDelivery,
      CopilotIntentType.guidePayoutRequest,
      CopilotIntentType.guideManageServiceRequests,
      CopilotIntentType.guideUpdateServicePackages,
    };
    if (freelancer.contains(intent.type)) {
      return _allowIf(
        role == 'freelancer',
        'This guided action is available only in the freelancer workspace.',
      );
    }

    const customer = {
      CopilotIntentType.guideRefundRequest,
      CopilotIntentType.guideRequestRevision,
      CopilotIntentType.guideOpenWalletTopUp,
      CopilotIntentType.guidePayOrder,
      CopilotIntentType.guideCreateServiceRequest,
    };
    if (customer.contains(intent.type)) {
      return _allowIf(
        accountType == 'customer',
        'This guided action is available only in the customer workspace.',
      );
    }

    const customerOrFreelancer = {
      CopilotIntentType.guideOpenDispute,
      CopilotIntentType.guideAddEvidence,
    };
    if (customerOrFreelancer.contains(intent.type)) {
      return _allowIf(
        accountType == 'customer' || role == 'freelancer',
        'This guided action needs a customer or freelancer workspace.',
      );
    }

    const teacher = {
      CopilotIntentType.guideCreateCourse,
      CopilotIntentType.guideManageCourse,
      CopilotIntentType.guideCreateCertificate,
    };
    if (teacher.contains(intent.type)) {
      return _allowIf(
        role == 'teacher',
        'This guided action is available only in the teacher workspace.',
      );
    }

    const company = {
      CopilotIntentType.guidePostJob,
      CopilotIntentType.guideReviewApplications,
    };
    if (company.contains(intent.type)) {
      return _allowIf(
        role == 'company',
        'This guided action is available only in the company workspace.',
      );
    }

    const admin = {
      CopilotIntentType.guideReviewResolutionCase,
      CopilotIntentType.guideRequestEvidence,
      CopilotIntentType.guideReviewPayout,
      CopilotIntentType.guideManageLaw,
    };
    if (admin.contains(intent.type)) {
      return _allowIf(
        _isAdmin(role),
        'This guided action is available only in the admin workspace.',
      );
    }

    if (intent.type == CopilotIntentType.guideContactSupport) {
      return const CopilotPermissionResult(allowed: true);
    }

    return const CopilotPermissionResult(allowed: true);
  }

  CopilotPermissionResult _checkDataRead(
    CopilotIntentModel intent, {
    required String role,
    required String accountType,
  }) {
    const common = {
      CopilotIntentType.getMyRole,
      CopilotIntentType.getDashboardSummary,
      CopilotIntentType.getProfileSummary,
    };
    if (common.contains(intent.type)) {
      return const CopilotPermissionResult(allowed: true);
    }

    if (intent.type == CopilotIntentType.getWalletBalance) {
      return _allowIf(
        accountType == 'customer' || role == 'freelancer',
        'Wallet summaries are available only for customer or freelancer workspaces.',
      );
    }

    const customer = {
      CopilotIntentType.getCustomerOrderSummary,
      CopilotIntentType.getCustomerResolutionSummary,
    };
    if (customer.contains(intent.type)) {
      return _allowIf(
        accountType == 'customer',
        'This summary is available only inside the customer workspace.',
      );
    }

    const freelancer = {
      CopilotIntentType.getFreelancerOrderSummary,
      CopilotIntentType.getFreelancerServiceRequestSummary,
      CopilotIntentType.getFreelancerPayoutSummary,
      CopilotIntentType.getFreelancerResolutionSummary,
    };
    if (freelancer.contains(intent.type)) {
      return _allowIf(
        role == 'freelancer',
        'This summary is available only inside the freelancer workspace.',
      );
    }

    const teacher = {
      CopilotIntentType.getTeacherCourseSummary,
      CopilotIntentType.getTeacherCertificateSummary,
      CopilotIntentType.getTeacherStudentProgressSummary,
    };
    if (teacher.contains(intent.type)) {
      return _allowIf(
        role == 'teacher',
        'This summary is available only inside the teacher workspace.',
      );
    }

    const company = {
      CopilotIntentType.getCompanyJobSummary,
      CopilotIntentType.getCompanyApplicationsSummary,
      CopilotIntentType.getCompanyHiringSummary,
    };
    if (company.contains(intent.type)) {
      return _allowIf(
        role == 'company',
        'This summary is available only inside the company workspace.',
      );
    }

    const admin = {
      CopilotIntentType.getAdminResolutionSummary,
      CopilotIntentType.getAdminPayoutSummary,
      CopilotIntentType.getSettlementBackendStatus,
    };
    if (admin.contains(intent.type)) {
      return _allowIf(
        _isAdmin(role),
        'This summary is available only inside the admin workspace.',
      );
    }

    return const CopilotPermissionResult(
      allowed: false,
      reason: 'I cannot safely read that data from this workspace.',
    );
  }

  CopilotPermissionResult _checkAi(
    CopilotIntentModel intent, {
    required String? userId,
    required String role,
    required String accountType,
  }) {
    const publicAi = {
      CopilotIntentType.generalAppHelp,
      CopilotIntentType.explainFeature,
      CopilotIntentType.rewriteText,
      CopilotIntentType.summarizeText,
    };
    if ((userId ?? '').trim().isEmpty) {
      return _allowIf(
        publicAi.contains(intent.type),
        'Please sign in to use role AI features.',
      );
    }

    const teacher = {
      CopilotIntentType.teacherCourseOutline,
      CopilotIntentType.teacherCourseBlueprint,
      CopilotIntentType.teacherLessonBuilder,
      CopilotIntentType.teacherAssignmentBuilder,
      CopilotIntentType.teacherQuizBuilder,
      CopilotIntentType.teacherGrandTestBuilder,
      CopilotIntentType.teacherImproveContent,
      CopilotIntentType.teacherBatchAnnouncementDraft,
      CopilotIntentType.teacherLessonPlan,
      CopilotIntentType.teacherQuizGenerator,
      CopilotIntentType.teacherAssignmentGenerator,
      CopilotIntentType.teacherRubricGenerator,
      CopilotIntentType.teacherImproveCourseText,
    };
    if (teacher.contains(intent.type)) {
      return _allowIf(
        role == 'teacher',
        'You do not have access to this AI feature with your current role.',
      );
    }

    const student = {
      CopilotIntentType.studentTutorExplain,
      CopilotIntentType.studentPracticeQuestions,
      CopilotIntentType.studentLessonSummary,
      CopilotIntentType.studentHint,
      CopilotIntentType.studentCodeExplanation,
    };
    if (student.contains(intent.type)) {
      return _allowIf(
        role == 'student' || accountType == 'customer',
        'You do not have access to this AI feature with your current role.',
      );
    }

    const company = {
      CopilotIntentType.companyJobPostGenerator,
      CopilotIntentType.companyInterviewQuestions,
      CopilotIntentType.companyCandidateRubric,
      CopilotIntentType.companyApplicationSummary,
      CopilotIntentType.companySkillMatchExplanation,
    };
    if (company.contains(intent.type)) {
      return _allowIf(
        role == 'company',
        'You do not have access to this AI feature with your current role.',
      );
    }

    const admin = {
      CopilotIntentType.adminResolutionSummary,
      CopilotIntentType.adminEvidenceSummary,
      CopilotIntentType.adminTimelineSummary,
      CopilotIntentType.adminRiskFlags,
      CopilotIntentType.adminLawRecommendation,
    };
    if (admin.contains(intent.type)) {
      return _allowIf(
        _isAdmin(role),
        'You do not have access to this AI feature with your current role.',
      );
    }

    const freelancer = {
      CopilotIntentType.freelancerProposalDraft,
      CopilotIntentType.freelancerDeliveryNoteBuilder,
      CopilotIntentType.freelancerProfileImprover,
      CopilotIntentType.freelancerServiceListingImprover,
    };
    if (freelancer.contains(intent.type)) {
      return _allowIf(
        role == 'freelancer',
        'You do not have access to this AI feature with your current role.',
      );
    }

    const customer = {
      CopilotIntentType.customerServiceRequestDraft,
      CopilotIntentType.customerRefundRequestDraft,
      CopilotIntentType.customerDisputeExplanationDraft,
      CopilotIntentType.customerMessageDraft,
    };
    if (customer.contains(intent.type)) {
      return _allowIf(
        accountType == 'customer',
        'You do not have access to this AI feature with your current role.',
      );
    }

    return _allowIf(
      publicAi.contains(intent.type),
      'You do not have access to this AI feature with your current role.',
    );
  }
}

CopilotPermissionResult _allowIf(bool condition, String reason) {
  return condition
      ? const CopilotPermissionResult(allowed: true)
      : CopilotPermissionResult(allowed: false, reason: reason);
}

bool _roleMatches(String role, String requiredRole) {
  final required = _normalizeRole(requiredRole);
  if (required == 'admin') return _isAdmin(role);
  return role == required;
}

bool _isAdmin(String role) => role == 'admin' || role == 'superadmin';

bool _isAiAction(String level) {
  return level == CopilotActionLevel.aiDraft ||
      level == CopilotActionLevel.aiExplain ||
      level == CopilotActionLevel.aiSummarize ||
      level == CopilotActionLevel.aiRecommend;
}

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
