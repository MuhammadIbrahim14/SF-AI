// ignore_for_file: use_null_aware_elements

import 'package:cloud_firestore/cloud_firestore.dart';

class AiUsageDefaults {
  const AiUsageDefaults._();

  static const roleMonthlyCredits = {
    'student': 100,
    'teacher': 200,
    'company': 200,
    'freelancer': 100,
    'customer': 80,
    'admin': 1000,
    'super_admin': 5000,
    'superadmin': 5000,
  };

  static const featureCosts = {
    'teacherCourseBlueprint': 20,
    'teacherLessonBuilder': 5,
    'teacherAssignmentBuilder': 5,
    'teacherProjectAssignmentBuilder': 8,
    'teacherQuizBuilder': 5,
    'teacherGrandTestBuilder': 15,
    'teacherImproveContent': 3,
    'teacherBatchAnnouncementDraft': 2,
    'studentTutorChat': 1,
    'studentTutorMessage': 1,
    'studentTutorExplain': 1,
    'studentLessonExplain': 2,
    'studentLessonSummary': 2,
    'studentPracticeQuestions': 3,
    'studentQuizReview': 3,
    'studentRevisionPlan': 3,
    'studentConceptSimplifier': 1,
    'companyJobPostBuilder': 5,
    'companyJobPostGenerator': 5,
    'companyJobPostImprover': 3,
    'companyCandidateSummary': 5,
    'companyCandidateComparison': 8,
    'companyShortlistAssistant': 8,
    'companyInterviewQuestionBuilder': 4,
    'companyInterviewScorecardBuilder': 4,
    'companyInterviewKitBuilder': 6,
    'companyHiringPipelineInsights': 6,
    'companyCandidateMessageDraft': 2,
    'companySkillGapAnalysis': 5,
    'companyCandidateRubric': 5,
    'companyJobMatchScore': 4,
    'companyHiringRecommendation': 3,
    'interviewLabQuestionBank': 6,
    'interviewLabAnswerCritique': 3,
    'interviewLabFollowUp': 3,
    'interviewLabDebrief': 5,
    'studentCareerAdvisor': 6,
    'freelancerCareerAdvisor': 6,
    'teacherCareerAdvisor': 6,
    'companyCareerAdvisor': 6,
    'careerSkillGapAnalysis': 4,
    'careerLearningRoadmap': 4,
    'careerResumeReview': 4,
    'careerPortfolioReview': 4,
    'careerMarketInsights': 3,
    'freelancerProposalDraft': 3,
    'freelancerServiceListingBuilder': 5,
    'freelancerServiceListingImprover': 3,
    'freelancerScopeClarifier': 3,
    'freelancerDeliveryNoteBuilder': 3,
    'freelancerClientUpdateDraft': 2,
    'freelancerRevisionResponseDraft': 3,
    'freelancerDisputeEvidenceSummary': 5,
    'freelancerProfileImprover': 3,
    'freelancerTimelineBuilder': 3,
    'customerServiceRequestDraft': 3,
    'customerProjectBriefBuilder': 5,
    'customerRequirementClarifier': 2,
    'customerFreelancerComparison': 5,
    'customerMessageDraft': 2,
    'customerRevisionRequestDraft': 3,
    'customerRefundRequestDraft': 4,
    'customerDisputeExplanationDraft': 5,
    'customerDeliveryAcceptanceChecklist': 3,
    'customerOrderScopeReview': 3,
    'adminResolutionAnalysis': 10,
    'adminResolutionSummary': 10,
    'adminResolutionCaseSummary': 5,
    'adminResolutionEvidenceAnalysis': 8,
    'adminResolutionTimelineBuilder': 5,
    'adminResolutionPolicyCheck': 8,
    'adminResolutionRiskAnalysis': 8,
    'adminResolutionDraftDecision': 10,
    'adminSettlementRecommendation': 10,
    'adminRefundRiskReview': 8,
    'adminPayoutRiskReview': 8,
  };

  static const featureLabels = {
    'teacherCourseBlueprint': 'AI Course Builder',
    'teacherLessonBuilder': 'AI Lesson Builder',
    'teacherAssignmentBuilder': 'AI Assignment Builder',
    'teacherProjectAssignmentBuilder': 'AI Project Assignment Builder',
    'teacherQuizBuilder': 'AI Quiz/MCQ Builder',
    'teacherGrandTestBuilder': 'AI Grand Test Builder',
    'teacherImproveContent': 'Improve Content with AI',
    'teacherBatchAnnouncementDraft': 'Batch Announcement Draft',
    'studentTutorChat': 'Student AI Tutor Chat',
    'studentTutorMessage': 'Student Tutor Message',
    'studentTutorExplain': 'Student Tutor Explain',
    'studentLessonExplain': 'Student Lesson Explain',
    'studentLessonSummary': 'Student Lesson Summary',
    'studentPracticeQuestions': 'Student Practice Questions',
    'studentQuizReview': 'Student Quiz Review',
    'studentRevisionPlan': 'Student Revision Plan',
    'studentConceptSimplifier': 'Student Concept Simplifier',
    'companyJobPostBuilder': 'Company Job Post Builder',
    'companyJobPostGenerator': 'Company Job Post Generator',
    'companyJobPostImprover': 'Company Job Post Improver',
    'companyCandidateSummary': 'Company Candidate Summary',
    'companyCandidateComparison': 'Company Candidate Comparison',
    'companyShortlistAssistant': 'Company Shortlist Assistant',
    'companyInterviewQuestionBuilder': 'Company Interview Questions',
    'companyInterviewScorecardBuilder': 'Company Interview Scorecard',
    'companyInterviewKitBuilder': 'Company Interview Kit',
    'companyHiringPipelineInsights': 'Company Hiring Pipeline Insights',
    'companyCandidateMessageDraft': 'Company Candidate Message Draft',
    'companySkillGapAnalysis': 'Company Skill Gap Analysis',
    'companyCandidateRubric': 'Company Candidate Rubric',
    'companyJobMatchScore': 'Company Job Match Score',
    'companyHiringRecommendation': 'Company Hiring Recommendation',
    'interviewLabQuestionBank': 'Interview Lab Question Bank',
    'interviewLabAnswerCritique': 'Interview Lab Answer Critique',
    'interviewLabFollowUp': 'Interview Lab Follow-Up',
    'interviewLabDebrief': 'Interview Lab Debrief',
    'studentCareerAdvisor': 'Student Career Advisor',
    'freelancerCareerAdvisor': 'Freelancer Career Advisor',
    'teacherCareerAdvisor': 'Teacher Career Advisor',
    'companyCareerAdvisor': 'Company Career Advisor',
    'careerSkillGapAnalysis': 'Career Skill Gap Analysis',
    'careerLearningRoadmap': 'Career Learning Roadmap',
    'careerResumeReview': 'Career Resume Review',
    'careerPortfolioReview': 'Career Portfolio Review',
    'careerMarketInsights': 'Career Market Insights',
    'freelancerProposalDraft': 'Freelancer Proposal Draft',
    'freelancerServiceListingBuilder': 'Freelancer Service Listing Builder',
    'freelancerServiceListingImprover': 'Freelancer Service Listing Improver',
    'freelancerScopeClarifier': 'Freelancer Scope Clarifier',
    'freelancerDeliveryNoteBuilder': 'Freelancer Delivery Note Builder',
    'freelancerClientUpdateDraft': 'Freelancer Client Update Draft',
    'freelancerRevisionResponseDraft': 'Freelancer Revision Response Draft',
    'freelancerDisputeEvidenceSummary': 'Freelancer Dispute Evidence Summary',
    'freelancerProfileImprover': 'Freelancer Profile Improver',
    'freelancerTimelineBuilder': 'Freelancer Timeline Builder',
    'customerServiceRequestDraft': 'Customer Service Request Draft',
    'customerProjectBriefBuilder': 'Customer Project Brief Builder',
    'customerRequirementClarifier': 'Customer Requirement Clarifier',
    'customerFreelancerComparison': 'Customer Freelancer Comparison',
    'customerMessageDraft': 'Customer Message Draft',
    'customerRevisionRequestDraft': 'Customer Revision Request Draft',
    'customerRefundRequestDraft': 'Customer Refund Request Draft',
    'customerDisputeExplanationDraft': 'Customer Dispute Explanation Draft',
    'customerDeliveryAcceptanceChecklist':
        'Customer Delivery Acceptance Checklist',
    'customerOrderScopeReview': 'Customer Order Scope Review',
    'adminResolutionAnalysis': 'Admin Resolution Analysis',
    'adminResolutionSummary': 'Admin Resolution Summary',
    'adminResolutionCaseSummary': 'Admin Resolution Case Summary',
    'adminResolutionEvidenceAnalysis': 'Admin Resolution Evidence Analysis',
    'adminResolutionTimelineBuilder': 'Admin Resolution Timeline Builder',
    'adminResolutionPolicyCheck': 'Admin Resolution Policy Check',
    'adminResolutionRiskAnalysis': 'Admin Resolution Risk Analysis',
    'adminResolutionDraftDecision': 'Admin Resolution Draft Decision',
    'adminSettlementRecommendation': 'Admin Settlement Recommendation',
    'adminRefundRiskReview': 'Admin Refund Risk Review',
    'adminPayoutRiskReview': 'Admin Payout Risk Review',
  };
}

class AiSettingsModel {
  const AiSettingsModel({
    required this.enabled,
    required this.monthlyResetEnabled,
    required this.defaultProvider,
    required this.templateFallbackEnabled,
    this.updatedAt,
    this.updatedBy,
  });

  factory AiSettingsModel.defaults() {
    return const AiSettingsModel(
      enabled: true,
      monthlyResetEnabled: true,
      defaultProvider: 'openai',
      templateFallbackEnabled: false,
    );
  }

  factory AiSettingsModel.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return AiSettingsModel(
      enabled: data['enabled'] != false,
      monthlyResetEnabled: data['monthlyResetEnabled'] != false,
      defaultProvider: data['defaultProvider']?.toString() ?? 'openai',
      templateFallbackEnabled: data['templateFallbackEnabled'] == true,
      updatedAt: _date(data['updatedAt']),
      updatedBy: data['updatedBy']?.toString(),
    );
  }

  final bool enabled;
  final bool monthlyResetEnabled;
  final String defaultProvider;
  final bool templateFallbackEnabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  Map<String, dynamic> toMap({String? updatedBy}) {
    return {
      'enabled': enabled,
      'monthlyResetEnabled': monthlyResetEnabled,
      'defaultProvider': defaultProvider,
      'templateFallbackEnabled': templateFallbackEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  AiSettingsModel copyWith({
    bool? enabled,
    bool? monthlyResetEnabled,
    String? defaultProvider,
    bool? templateFallbackEnabled,
  }) {
    return AiSettingsModel(
      enabled: enabled ?? this.enabled,
      monthlyResetEnabled: monthlyResetEnabled ?? this.monthlyResetEnabled,
      defaultProvider: defaultProvider ?? this.defaultProvider,
      templateFallbackEnabled:
          templateFallbackEnabled ?? this.templateFallbackEnabled,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }
}

class AiRoleQuotaModel {
  const AiRoleQuotaModel({
    required this.role,
    required this.monthlyFreeCredits,
    required this.maxDailyRequests,
    required this.aiEnabled,
    required this.allowedFeatures,
    this.updatedAt,
    this.updatedBy,
  });

  factory AiRoleQuotaModel.defaults(String role) {
    return AiRoleQuotaModel(
      role: normalizeRole(role),
      monthlyFreeCredits:
          AiUsageDefaults.roleMonthlyCredits[normalizeRole(role)] ?? 100,
      maxDailyRequests: normalizeRole(role).contains('admin') ? 500 : 100,
      aiEnabled: true,
      allowedFeatures: const <String>[],
    );
  }

  factory AiRoleQuotaModel.fromMap(String role, Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    final fallback = AiRoleQuotaModel.defaults(role);
    return AiRoleQuotaModel(
      role: data['role']?.toString() ?? fallback.role,
      monthlyFreeCredits: _int(
        data['monthlyFreeCredits'],
        fallback.monthlyFreeCredits,
      ),
      maxDailyRequests: _int(
        data['maxDailyRequests'],
        fallback.maxDailyRequests,
      ),
      aiEnabled: data['aiEnabled'] != false,
      allowedFeatures: _stringList(data['allowedFeatures']),
      updatedAt: _date(data['updatedAt']),
      updatedBy: data['updatedBy']?.toString(),
    );
  }

  final String role;
  final int monthlyFreeCredits;
  final int maxDailyRequests;
  final bool aiEnabled;
  final List<String> allowedFeatures;
  final DateTime? updatedAt;
  final String? updatedBy;

  Map<String, dynamic> toMap({String? updatedBy}) {
    return {
      'role': role,
      'monthlyFreeCredits': monthlyFreeCredits,
      'maxDailyRequests': maxDailyRequests,
      'aiEnabled': aiEnabled,
      'allowedFeatures': allowedFeatures,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  bool allowsFeature(String taskType) {
    return allowedFeatures.isEmpty || allowedFeatures.contains(taskType);
  }
}

class AiFeatureCostModel {
  const AiFeatureCostModel({
    required this.taskType,
    required this.label,
    required this.creditCost,
    required this.isHeavy,
    required this.enabled,
    this.updatedAt,
    this.updatedBy,
  });

  factory AiFeatureCostModel.defaults(String taskType) {
    return AiFeatureCostModel(
      taskType: taskType,
      label: AiUsageDefaults.featureLabels[taskType] ?? taskType,
      creditCost: AiUsageDefaults.featureCosts[taskType] ?? 1,
      isHeavy:
          taskType == 'teacherCourseBlueprint' ||
          taskType == 'teacherGrandTestBuilder' ||
          taskType.startsWith('admin'),
      enabled: true,
    );
  }

  factory AiFeatureCostModel.fromMap(
    String taskType,
    Map<String, dynamic>? map,
  ) {
    final data = map ?? const <String, dynamic>{};
    final fallback = AiFeatureCostModel.defaults(taskType);
    return AiFeatureCostModel(
      taskType: data['taskType']?.toString() ?? fallback.taskType,
      label: data['label']?.toString() ?? fallback.label,
      creditCost: _int(data['creditCost'], fallback.creditCost),
      isHeavy: data['isHeavy'] == true || fallback.isHeavy,
      enabled: data['enabled'] != false,
      updatedAt: _date(data['updatedAt']),
      updatedBy: data['updatedBy']?.toString(),
    );
  }

  final String taskType;
  final String label;
  final int creditCost;
  final bool isHeavy;
  final bool enabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  Map<String, dynamic> toMap({String? updatedBy}) {
    return {
      'taskType': taskType,
      'label': label,
      'creditCost': creditCost,
      'isHeavy': isHeavy,
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }
}

class AiUserCreditsModel {
  const AiUserCreditsModel({
    required this.userId,
    required this.role,
    required this.monthlyFreeCredits,
    required this.bonusCredits,
    required this.usedCreditsThisMonth,
    required this.remainingCredits,
    required this.currentMonthKey,
    this.manuallyAdjustedBy,
    this.updatedAt,
  });

  factory AiUserCreditsModel.defaults({
    required String userId,
    required String role,
  }) {
    final normalized = normalizeRole(role);
    final monthly = AiUsageDefaults.roleMonthlyCredits[normalized] ?? 100;
    return AiUserCreditsModel(
      userId: userId,
      role: normalized,
      monthlyFreeCredits: monthly,
      bonusCredits: 0,
      usedCreditsThisMonth: 0,
      remainingCredits: monthly,
      currentMonthKey: monthKey(DateTime.now()),
    );
  }

  factory AiUserCreditsModel.fromMap({
    required String userId,
    required String role,
    required Map<String, dynamic>? map,
  }) {
    final data = map ?? const <String, dynamic>{};
    final fallback = AiUserCreditsModel.defaults(userId: userId, role: role);
    final currentMonth = monthKey(DateTime.now());
    final storedMonth = data['currentMonthKey']?.toString() ?? currentMonth;
    final monthly = _int(
      data['monthlyFreeCredits'],
      fallback.monthlyFreeCredits,
    );
    final bonus = _int(data['bonusCredits'], 0);
    final used = storedMonth == currentMonth
        ? _int(data['usedCreditsThisMonth'], 0)
        : 0;
    return AiUserCreditsModel(
      userId: data['userId']?.toString() ?? userId,
      role: normalizeRole(data['role']?.toString() ?? role),
      monthlyFreeCredits: monthly,
      bonusCredits: bonus,
      usedCreditsThisMonth: used,
      remainingCredits: (monthly + bonus - used).clamp(0, 1000000),
      currentMonthKey: currentMonth,
      manuallyAdjustedBy: data['manuallyAdjustedBy']?.toString(),
      updatedAt: _date(data['updatedAt']),
    );
  }

  final String userId;
  final String role;
  final int monthlyFreeCredits;
  final int bonusCredits;
  final int usedCreditsThisMonth;
  final int remainingCredits;
  final String currentMonthKey;
  final String? manuallyAdjustedBy;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap({String? adjustedBy}) {
    return {
      'userId': userId,
      'role': role,
      'monthlyFreeCredits': monthlyFreeCredits,
      'bonusCredits': bonusCredits,
      'usedCreditsThisMonth': usedCreditsThisMonth,
      'remainingCredits': remainingCredits,
      'currentMonthKey': currentMonthKey,
      if (adjustedBy != null) 'manuallyAdjustedBy': adjustedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AiUsageLogModel {
  const AiUsageLogModel({
    required this.logId,
    required this.userId,
    required this.role,
    required this.taskType,
    required this.feature,
    required this.provider,
    required this.model,
    required this.status,
    required this.creditsCharged,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.fallbackUsed,
    this.createdAt,
  });

  factory AiUsageLogModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AiUsageLogModel(
      logId: doc.id,
      userId: data['userId']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
      taskType: data['taskType']?.toString() ?? '',
      feature: data['feature']?.toString() ?? '',
      provider: data['provider']?.toString() ?? '',
      model: data['model']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      creditsCharged: _int(data['creditsCharged'], 0),
      promptTokens: _int(data['promptTokens'], 0),
      completionTokens: _int(data['completionTokens'], 0),
      totalTokens: _int(data['totalTokens'], 0),
      fallbackUsed: data['fallbackUsed'] == true,
      createdAt: _date(data['createdAt']),
    );
  }

  final String logId;
  final String userId;
  final String role;
  final String taskType;
  final String feature;
  final String provider;
  final String model;
  final String status;
  final int creditsCharged;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final bool fallbackUsed;
  final DateTime? createdAt;
}

class AiCreditRequestModel {
  const AiCreditRequestModel({
    required this.requestId,
    required this.userId,
    required this.role,
    required this.requestedCredits,
    required this.reason,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory AiCreditRequestModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AiCreditRequestModel(
      requestId: doc.id,
      userId: data['userId']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
      requestedCredits: _int(data['requestedCredits'], 0),
      reason: data['reason']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      adminNote: data['adminNote']?.toString(),
      createdAt: _date(data['createdAt']),
      reviewedAt: _date(data['reviewedAt']),
      reviewedBy: data['reviewedBy']?.toString(),
    );
  }

  final String requestId;
  final String userId;
  final String role;
  final int requestedCredits;
  final String reason;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
}

String normalizeRole(String role) {
  final normalized = role.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  if (normalized == 'superadmin') return 'super_admin';
  return normalized;
}

String monthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int _int(Object? value, int fallback) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
