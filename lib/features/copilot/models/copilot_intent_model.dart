class CopilotIntentType {
  const CopilotIntentType._();

  static const openDashboard = 'openDashboard';
  static const openDestination = 'openDestination';
  static const openWallet = 'openWallet';
  static const openOrders = 'openOrders';
  static const openCustomerOrders = 'openCustomerOrders';
  static const openFreelancerOrders = 'openFreelancerOrders';
  static const openServiceRequests = 'openServiceRequests';
  static const openResolutionCenter = 'openResolutionCenter';
  static const openAdminResolutionDesk = 'openAdminResolutionDesk';
  static const openPayouts = 'openPayouts';
  static const openSupport = 'openSupport';
  static const openPrivacyPolicy = 'openPrivacyPolicy';
  static const openTerms = 'openTerms';
  static const openProfile = 'openProfile';
  static const openSettings = 'openSettings';

  static const getWalletBalance = 'getWalletBalance';
  static const getCustomerOrderSummary = 'getCustomerOrderSummary';
  static const getCustomerResolutionSummary = 'getCustomerResolutionSummary';
  static const getFreelancerOrderSummary = 'getFreelancerOrderSummary';
  static const getFreelancerServiceRequestSummary =
      'getFreelancerServiceRequestSummary';
  static const getFreelancerPayoutSummary = 'getFreelancerPayoutSummary';
  static const getFreelancerResolutionSummary =
      'getFreelancerResolutionSummary';
  static const getAdminResolutionSummary = 'getAdminResolutionSummary';
  static const getAdminPayoutSummary = 'getAdminPayoutSummary';
  static const getSettlementBackendStatus = 'getSettlementBackendStatus';
  static const getTeacherCourseSummary = 'getTeacherCourseSummary';
  static const getTeacherCertificateSummary = 'getTeacherCertificateSummary';
  static const getTeacherStudentProgressSummary =
      'getTeacherStudentProgressSummary';
  static const getCompanyJobSummary = 'getCompanyJobSummary';
  static const getCompanyApplicationsSummary = 'getCompanyApplicationsSummary';
  static const getCompanyHiringSummary = 'getCompanyHiringSummary';
  static const getMyRole = 'getMyRole';
  static const getDashboardSummary = 'getDashboardSummary';
  static const getProfileSummary = 'getProfileSummary';

  static const explainEscrow = 'explainEscrow';
  static const explainRefund = 'explainRefund';
  static const explainDispute = 'explainDispute';
  static const explainPayout = 'explainPayout';
  static const explainDeliveryFlow = 'explainDeliveryFlow';
  static const explainSettlementPaused = 'explainSettlementPaused';
  static const explainSkillForgeLaw = 'explainSkillForgeLaw';

  static const guideRefundRequest = 'guideRefundRequest';
  static const guideOpenDispute = 'guideOpenDispute';
  static const guideRequestRevision = 'guideRequestRevision';
  static const guideSubmitDelivery = 'guideSubmitDelivery';
  static const guideAddEvidence = 'guideAddEvidence';
  static const guidePayoutRequest = 'guidePayoutRequest';
  static const guideOpenWalletTopUp = 'guideOpenWalletTopUp';
  static const guidePayOrder = 'guidePayOrder';
  static const guideCreateServiceRequest = 'guideCreateServiceRequest';
  static const guideContactSupport = 'guideContactSupport';
  static const guideManageServiceRequests = 'guideManageServiceRequests';
  static const guideUpdateServicePackages = 'guideUpdateServicePackages';
  static const guideCreateCourse = 'guideCreateCourse';
  static const guideManageCourse = 'guideManageCourse';
  static const guideCreateCertificate = 'guideCreateCertificate';
  static const guidePostJob = 'guidePostJob';
  static const guideReviewApplications = 'guideReviewApplications';
  static const guideReviewResolutionCase = 'guideReviewResolutionCase';
  static const guideRequestEvidence = 'guideRequestEvidence';
  static const guideReviewPayout = 'guideReviewPayout';
  static const guideManageLaw = 'guideManageLaw';

  static const teacherCourseOutline = 'teacherCourseOutline';
  static const teacherCourseBlueprint = 'teacherCourseBlueprint';
  static const teacherLessonBuilder = 'teacherLessonBuilder';
  static const teacherAssignmentBuilder = 'teacherAssignmentBuilder';
  static const teacherQuizBuilder = 'teacherQuizBuilder';
  static const teacherGrandTestBuilder = 'teacherGrandTestBuilder';
  static const teacherImproveContent = 'teacherImproveContent';
  static const teacherBatchAnnouncementDraft = 'teacherBatchAnnouncementDraft';
  static const teacherLessonPlan = 'teacherLessonPlan';
  static const teacherQuizGenerator = 'teacherQuizGenerator';
  static const teacherAssignmentGenerator = 'teacherAssignmentGenerator';
  static const teacherRubricGenerator = 'teacherRubricGenerator';
  static const teacherImproveCourseText = 'teacherImproveCourseText';

  static const studentTutorExplain = 'studentTutorExplain';
  static const studentPracticeQuestions = 'studentPracticeQuestions';
  static const studentLessonSummary = 'studentLessonSummary';
  static const studentHint = 'studentHint';
  static const studentCodeExplanation = 'studentCodeExplanation';

  static const companyJobPostGenerator = 'companyJobPostGenerator';
  static const companyInterviewQuestions = 'companyInterviewQuestions';
  static const companyCandidateRubric = 'companyCandidateRubric';
  static const companyApplicationSummary = 'companyApplicationSummary';
  static const companySkillMatchExplanation = 'companySkillMatchExplanation';

  static const adminResolutionSummary = 'adminResolutionSummary';
  static const adminEvidenceSummary = 'adminEvidenceSummary';
  static const adminTimelineSummary = 'adminTimelineSummary';
  static const adminRiskFlags = 'adminRiskFlags';
  static const adminLawRecommendation = 'adminLawRecommendation';

  static const freelancerProposalDraft = 'freelancerProposalDraft';
  static const freelancerDeliveryNoteBuilder = 'freelancerDeliveryNoteBuilder';
  /// Legacy alias — remapped to [freelancerDeliveryNoteBuilder] for gateway.
  static const freelancerDeliveryMessageDraft = freelancerDeliveryNoteBuilder;
  static const freelancerProfileImprover = 'freelancerProfileImprover';
  /// Legacy alias — remapped to [freelancerProfileImprover] for gateway.
  static const freelancerProfileImprove = freelancerProfileImprover;
  static const freelancerServiceListingImprover =
      'freelancerServiceListingImprover';
  /// Legacy alias — remapped to [freelancerServiceListingImprover] for gateway.
  static const freelancerServicePackageImprove =
      freelancerServiceListingImprover;

  static const customerServiceRequestDraft = 'customerServiceRequestDraft';
  static const customerRefundRequestDraft = 'customerRefundRequestDraft';
  /// Legacy alias — remapped to [customerRefundRequestDraft] for gateway.
  static const customerRefundReasonDraft = customerRefundRequestDraft;
  static const customerDisputeExplanationDraft =
      'customerDisputeExplanationDraft';
  /// Legacy alias — remapped to [customerDisputeExplanationDraft] for gateway.
  static const customerDisputeSummaryDraft = customerDisputeExplanationDraft;
  static const customerMessageDraft = 'customerMessageDraft';
  /// Legacy alias — remapped to [customerMessageDraft] for gateway.
  static const customerSupportMessageDraft = customerMessageDraft;

  static const generalAppHelp = 'generalAppHelp';
  static const explainFeature = 'explainFeature';
  static const rewriteText = 'rewriteText';
  static const summarizeText = 'summarizeText';

  static const payWithWallet = 'payWithWallet';
  static const releaseEscrow = 'releaseEscrow';
  static const splitSettlement = 'splitSettlement';
  static const refundClient = 'refundClient';
  static const withdrawPayout = 'withdrawPayout';
  static const markPayoutPaid = 'markPayoutPaid';
  static const resolveCase = 'resolveCase';
  static const deleteData = 'deleteData';
  static const banUser = 'banUser';

  static const unknown = 'unknown';
}

class CopilotActionLevel {
  const CopilotActionLevel._();

  static const safeNavigation = 'safeNavigation';
  static const explanation = 'explanation';
  static const dataRead = 'dataRead';
  static const guidedAction = 'guidedAction';
  static const aiDraft = 'aiDraft';
  static const aiExplain = 'aiExplain';
  static const aiSummarize = 'aiSummarize';
  static const aiRecommend = 'aiRecommend';
  static const sensitive = 'sensitive';
  static const unsupported = 'unsupported';
}

class CopilotIntentModel {
  const CopilotIntentModel({
    required this.type,
    required this.rawText,
    this.confidence = 0,
    this.targetRoute,
    this.requiredRole,
    this.actionLevel = CopilotActionLevel.unsupported,
    this.needsConfirmation = false,
    this.destinationId,
    this.destinationTitle,
    this.matchedKeyword,
    this.category,
    this.suggestions = const <String>[],
  });

  final String type;
  final String rawText;
  final double confidence;
  final String? targetRoute;
  final String? requiredRole;
  final String actionLevel;
  final bool needsConfirmation;
  final String? destinationId;
  final String? destinationTitle;
  final String? matchedKeyword;
  final String? category;
  final List<String> suggestions;

  bool get isNavigation => actionLevel == CopilotActionLevel.safeNavigation;
  bool get isDataRead => actionLevel == CopilotActionLevel.dataRead;
  bool get isAi =>
      actionLevel == CopilotActionLevel.aiDraft ||
      actionLevel == CopilotActionLevel.aiExplain ||
      actionLevel == CopilotActionLevel.aiSummarize ||
      actionLevel == CopilotActionLevel.aiRecommend;
  bool get isSensitive => actionLevel == CopilotActionLevel.sensitive;

  CopilotIntentModel copyWith({
    String? type,
    String? rawText,
    double? confidence,
    String? targetRoute,
    String? requiredRole,
    String? actionLevel,
    bool? needsConfirmation,
    String? destinationId,
    String? destinationTitle,
    String? matchedKeyword,
    String? category,
    List<String>? suggestions,
  }) {
    return CopilotIntentModel(
      type: type ?? this.type,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
      targetRoute: targetRoute ?? this.targetRoute,
      requiredRole: requiredRole ?? this.requiredRole,
      actionLevel: actionLevel ?? this.actionLevel,
      needsConfirmation: needsConfirmation ?? this.needsConfirmation,
      destinationId: destinationId ?? this.destinationId,
      destinationTitle: destinationTitle ?? this.destinationTitle,
      matchedKeyword: matchedKeyword ?? this.matchedKeyword,
      category: category ?? this.category,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}
