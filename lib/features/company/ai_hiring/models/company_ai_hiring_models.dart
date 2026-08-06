import '../../../../models/application_model.dart';
import '../../../../models/job_model.dart';
import '../../../copilot/models/copilot_ai_response_model.dart';

class CompanyAiTaskType {
  const CompanyAiTaskType._();

  static const companyJobPostBuilder = 'companyJobPostBuilder';
  static const companyJobPostImprover = 'companyJobPostImprover';
  static const companyCandidateSummary = 'companyCandidateSummary';
  static const companyCandidateComparison = 'companyCandidateComparison';
  static const companyShortlistAssistant = 'companyShortlistAssistant';
  static const companyInterviewQuestionBuilder =
      'companyInterviewQuestionBuilder';
  static const companyInterviewScorecardBuilder =
      'companyInterviewScorecardBuilder';
  static const companyInterviewKitBuilder = 'companyInterviewKitBuilder';
  static const companyHiringPipelineInsights = 'companyHiringPipelineInsights';
  static const companyCandidateMessageDraft = 'companyCandidateMessageDraft';
  static const companySkillGapAnalysis = 'companySkillGapAnalysis';

  static const all = <String>[
    companyJobPostBuilder,
    companyJobPostImprover,
    companyCandidateSummary,
    companyCandidateComparison,
    companyShortlistAssistant,
    companyInterviewQuestionBuilder,
    companyInterviewScorecardBuilder,
    companyInterviewKitBuilder,
    companyHiringPipelineInsights,
    companyCandidateMessageDraft,
    companySkillGapAnalysis,
  ];

  static String label(String taskType) {
    return switch (taskType) {
      companyJobPostBuilder => 'Job Post Builder',
      companyJobPostImprover => 'Job Post Improver',
      companyCandidateSummary => 'Candidate Summary',
      companyCandidateComparison => 'Candidate Comparison',
      companyShortlistAssistant => 'Shortlist Assistant',
      companyInterviewQuestionBuilder => 'Interview Questions',
      companyInterviewScorecardBuilder => 'Interview Scorecard',
      companyInterviewKitBuilder => 'Interview Kit',
      companyHiringPipelineInsights => 'Pipeline Insights',
      companyCandidateMessageDraft => 'Candidate Message Draft',
      companySkillGapAnalysis => 'Skill Gap Analysis',
      _ => taskType,
    };
  }

  static String description(String taskType) {
    return switch (taskType) {
      companyJobPostBuilder =>
        'Create a complete job post with category, skills, requirements, score threshold, and screening questions.',
      companyJobPostImprover =>
        'Improve the selected job post and show exactly what should be clearer or stronger.',
      companyCandidateSummary =>
        'Summarize applicant strengths, possible gaps, matched skills, and safe next-step notes.',
      companyCandidateComparison =>
        'Compare candidates fairly using role-relevant evidence only.',
      companyShortlistAssistant =>
        'Suggest interview-ready candidates without changing their status.',
      companyInterviewQuestionBuilder =>
        'Generate focused interview questions for the selected job and applicant pool.',
      companyInterviewScorecardBuilder =>
        'Build a professional scorecard/rubric for consistent evaluations.',
      companyInterviewKitBuilder =>
        'Create a complete interview kit with sections, questions, signals, and scorecard.',
      companyHiringPipelineInsights =>
        'Find pipeline bottlenecks and manual next actions.',
      companyCandidateMessageDraft =>
        'Draft a candidate message that the recruiter must review and send manually.',
      companySkillGapAnalysis =>
        'Identify missing skills, skills to verify, and job-post clarity gaps.',
      _ => 'Generate safe hiring assistance for this company workflow.',
    };
  }

  static String defaultPrompt(String taskType) {
    return switch (taskType) {
      companyJobPostBuilder =>
        'Build a professional job post. Detect category, required skills, preferred skills, responsibilities, requirements, employment type, experience level, location type, and a minimum skill score if I mention it.',
      companyJobPostImprover =>
        'Improve the selected job post. Make it clearer, more specific, fair, searchable, and easier for qualified candidates to understand. Keep the final decision manual.',
      companyCandidateSummary =>
        'Create a fair candidate summary using only application/job evidence. Include strengths, possible gaps, matched skills, and recommended manual next step.',
      companyCandidateComparison =>
        'Compare candidates fairly for this job. Use role-relevant evidence only and explain fit, gaps, and recommended manual next step.',
      companyShortlistAssistant =>
        'Suggest who should be reviewed for interview first. Do not hire, reject, or change statuses.',
      companyInterviewQuestionBuilder =>
        'Create role-specific interview questions with skill tested, difficulty, expected signals, and red flags.',
      companyInterviewScorecardBuilder =>
        'Create an interview scorecard with criteria, rating scale, evidence notes, and fair evaluation guidance.',
      companyInterviewKitBuilder =>
        'Build a complete interview kit with interview sections, questions, scorecard, expected signals, and manual review notes.',
      companyHiringPipelineInsights =>
        'Analyze the hiring pipeline and recommend manual next actions for bottlenecks, pending reviews, and interview follow-ups.',
      companyCandidateMessageDraft =>
        'Draft a professional candidate message. Do not claim it was sent. Keep tone respectful and recruiter-review friendly.',
      companySkillGapAnalysis =>
        'Analyze skill gaps between the job post and applicant pool. Include skills to verify in interview and job post clarity issues.',
      _ => 'Generate safe hiring assistance for this workflow.',
    };
  }
}

class CompanyAiContextModel {
  const CompanyAiContextModel({
    required this.companyId,
    required this.companyName,
    this.companyIndustry,
    this.job,
    this.applications = const <ApplicationModel>[],
    this.pipelineStageCounts = const <String, int>{},
    this.hiringGoal = '',
    this.languagePreference = 'professional English',
    this.extraInstructions = '',
  });

  final String companyId;
  final String companyName;
  final String? companyIndustry;
  final JobModel? job;
  final List<ApplicationModel> applications;
  final Map<String, int> pipelineStageCounts;
  final String hiringGoal;
  final String languagePreference;
  final String extraInstructions;

  Map<String, dynamic> toSafeJson() {
    final currentJob = job;
    return {
      'companyId': companyId,
      'companyName': companyName,
      if ((companyIndustry ?? '').trim().isNotEmpty)
        'companyIndustry': companyIndustry,
      if (currentJob != null) ...{
        'jobId': currentJob.id,
        'jobTitle': currentJob.title,
        'jobDescription': currentJob.description,
        'requiredSkills': currentJob.requiredSkills,
        'preferredSkills': currentJob.preferredSkills,
        'requirements': currentJob.requirements,
        'experienceLevel': currentJob.experienceLevel,
        'employmentType': currentJob.type,
        'locationType': currentJob.remoteAllowed ? 'remote/hybrid' : 'onsite',
        'location': currentJob.location,
        'salaryRange': currentJob.salaryRange,
        'category': currentJob.category,
      },
      'applications': applications.take(12).map(_applicationJson).toList(),
      'pipelineStageCounts': pipelineStageCounts,
      'hiringGoal': hiringGoal,
      'languagePreference': languagePreference,
      'extraInstructions': extraInstructions,
      'fairHiringConstraints': const [
        'Use only role-relevant skills, experience, job requirements, cover letters, and application status.',
        'Ignore protected attributes if they appear in free text.',
        'Never auto-hire, auto-reject, auto-message, or update candidate status.',
      ],
    };
  }

  Map<String, dynamic> _applicationJson(ApplicationModel application) {
    return {
      'applicationId': application.id,
      'candidateId': application.applicantId,
      'candidateRole': application.role,
      'jobId': application.jobId,
      'status': application.normalizedStatus,
      'coverLetterSummary': _limit(application.coverLetter, 900),
      'appliedAt': application.appliedAt.toIso8601String(),
      if ((application.interviewId ?? '').trim().isNotEmpty)
        'interviewId': application.interviewId,
    };
  }

  String _limit(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}...';
  }
}

class CompanyAiHiringRequestModel {
  const CompanyAiHiringRequestModel({
    required this.taskType,
    required this.prompt,
    required this.context,
    this.selectedApplicationIds = const <String>[],
    this.extraInputs = const <String, dynamic>{},
  });

  final String taskType;
  final String prompt;
  final CompanyAiContextModel context;
  final List<String> selectedApplicationIds;
  final Map<String, dynamic> extraInputs;

  Map<String, dynamic> toSafeContext() {
    return {
      ...context.toSafeJson(),
      'selectedApplicationIds': selectedApplicationIds,
      'extraInputs': extraInputs,
      'manualApplyRequired': true,
      'firestoreWritesAllowed': false,
      'autoDecisionAllowed': false,
    };
  }
}

class CompanyAiHiringResponseModel {
  const CompanyAiHiringResponseModel({
    required this.taskType,
    required this.title,
    required this.summary,
    required this.structuredData,
    required this.recommendations,
    required this.safetyNotes,
    required this.sourceProvider,
    required this.requiresManualReview,
    this.isFallback = false,
    this.isRepaired = false,
    this.qualityWarnings = const <String>[],
  });

  final String taskType;
  final String title;
  final String summary;
  final Map<String, dynamic> structuredData;
  final List<String> recommendations;
  final List<String> safetyNotes;
  final String sourceProvider;
  final bool requiresManualReview;
  final bool isFallback;
  final bool isRepaired;
  final List<String> qualityWarnings;

  bool get hasJobPost => structuredData['jobPost'] is Map;
  bool get isUnavailable =>
      taskType.isNotEmpty &&
      (sourceProvider == 'aiUnavailable' ||
          sourceProvider == 'gatewayUnreachable' ||
          sourceProvider == 'providerError' ||
          structuredData.isEmpty &&
              title.toLowerCase().contains('unavailable'));

  Map<String, dynamic> get jobPost {
    final value = structuredData['jobPost'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  factory CompanyAiHiringResponseModel.fromCopilot(
    CopilotAiResponseModel response, {
    required String taskType,
  }) {
    return CompanyAiHiringResponseModel(
      taskType: taskType,
      title: response.title,
      summary: response.message,
      structuredData: response.structuredData,
      recommendations: response.suggestions,
      safetyNotes: response.safetyNotes,
      sourceProvider: response.source ?? response.provider,
      requiresManualReview: response.requiresManualReview,
      isFallback: false,
      qualityWarnings: [
        if ((response.blockedReason ?? '').trim().isNotEmpty)
          response.blockedReason!,
      ],
    );
  }

  CompanyAiHiringResponseModel copyWith({
    String? title,
    String? summary,
    Map<String, dynamic>? structuredData,
    List<String>? recommendations,
    List<String>? safetyNotes,
    String? sourceProvider,
    bool? requiresManualReview,
    bool? isFallback,
    bool? isRepaired,
    List<String>? qualityWarnings,
  }) {
    return CompanyAiHiringResponseModel(
      taskType: taskType,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      structuredData: structuredData ?? this.structuredData,
      recommendations: recommendations ?? this.recommendations,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      sourceProvider: sourceProvider ?? this.sourceProvider,
      requiresManualReview: requiresManualReview ?? this.requiresManualReview,
      isFallback: isFallback ?? this.isFallback,
      isRepaired: isRepaired ?? this.isRepaired,
      qualityWarnings: qualityWarnings ?? this.qualityWarnings,
    );
  }
}
