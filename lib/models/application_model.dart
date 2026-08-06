import 'package:cloud_firestore/cloud_firestore.dart';

import 'hiring_lifecycle_models.dart';

String _stringValue(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}

List<OnboardingChecklistItem> _onboardingList(Object? value) {
  if (value is! Iterable) return const <OnboardingChecklistItem>[];
  return value
      .whereType<Map>()
      .map(
        (item) => OnboardingChecklistItem.fromMap(
          Map<String, dynamic>.from(item),
        ),
      )
      .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
      .toList();
}

List<EmploymentDocument> _documentsList(Object? value) {
  if (value is! Iterable) return const <EmploymentDocument>[];
  return value
      .whereType<Map>()
      .map(
        (item) => EmploymentDocument.fromMap(Map<String, dynamic>.from(item)),
      )
      .where((item) => item.id.isNotEmpty && item.url.isNotEmpty)
      .toList();
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

class ApplicationModel {
  const ApplicationModel({
    required this.id,
    required this.jobId,
    required this.applicantId,
    required this.companyId,
    required this.coverLetter,
    required this.status, // e.g. Pending, Reviewed, Accepted, Rejected
    required this.appliedAt,
    this.role = 'student',
    this.interviewId,
    this.lastUpdatedAt,
    this.pipelineStage = '',
    this.evaluationScore = 0,
    this.evaluationSummary = '',
    this.rankingScore = 0,
    this.rankingReason = '',
    this.matchedSkills = const <String>[],
    this.missingSkills = const <String>[],
    this.recommendedNextStep = '',
    this.companyNotes = '',
    this.offerStatus = '',
    this.offerDetails = '',
    this.candidateVisibleStatus = '',
    this.evaluationRequestStatus = 'none',
    this.evaluationQuestions = const <String>[],
    this.evaluationAnswers = const <String>[],
    this.offerSalary = '',
    this.offerCurrency = '',
    this.offerJoiningDate = '',
    this.offerMessage = '',
    this.offerSentAt,
    this.offerRespondedAt,
    this.candidateResponseMessage = '',
    this.talentPoolSaved = false,
    this.evaluatedAt,
    this.lifecycleStage = '',
    this.employmentStatus = 'none',
    this.joinedAt,
    this.offerRole = '',
    this.offerDepartment = '',
    this.offerEmploymentType = '',
    this.offerBenefits = '',
    this.offerContractDuration = '',
    this.offerWorkingHours = '',
    this.offerLocation = '',
    this.offerExpiresAt = '',
    this.hrInterviewFeedback = '',
    this.hrHiringComments = '',
    this.onboardingChecklist = const <OnboardingChecklistItem>[],
    this.offerDocumentGeneratedAt,
    this.welcomePack = const WelcomePack(),
    this.employmentProfile = const EmploymentProfile(),
    this.probation = const ProbationInfo(),
    this.offboarding = const OffboardingInfo(),
    this.documents = const <EmploymentDocument>[],
    this.hrThreadId = '',
    this.lastJoinReminderAt,
    this.lastDocsReminderAt,
  });

  final String id;
  final String jobId;
  final String applicantId;
  final String companyId;
  final String coverLetter;
  final String status;
  final DateTime appliedAt;
  final String role;
  final String? interviewId;
  final DateTime? lastUpdatedAt;
  final String pipelineStage;
  final double evaluationScore;
  final String evaluationSummary;
  final double rankingScore;
  final String rankingReason;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String recommendedNextStep;
  final String companyNotes;
  final String offerStatus;
  final String offerDetails;
  final String candidateVisibleStatus;
  final String evaluationRequestStatus;
  final List<String> evaluationQuestions;
  final List<String> evaluationAnswers;
  final String offerSalary;
  final String offerCurrency;
  final String offerJoiningDate;
  final String offerMessage;
  final DateTime? offerSentAt;
  final DateTime? offerRespondedAt;
  final String candidateResponseMessage;
  final bool talentPoolSaved;
  final DateTime? evaluatedAt;

  /// Phase 5 enterprise hiring timeline stage.
  final String lifecycleStage;
  final String employmentStatus;
  final DateTime? joinedAt;
  final String offerRole;
  final String offerDepartment;
  final String offerEmploymentType;
  final String offerBenefits;
  final String offerContractDuration;
  final String offerWorkingHours;
  final String offerLocation;
  final String offerExpiresAt;
  final String hrInterviewFeedback;
  final String hrHiringComments;
  final List<OnboardingChecklistItem> onboardingChecklist;
  final DateTime? offerDocumentGeneratedAt;
  final WelcomePack welcomePack;
  final EmploymentProfile employmentProfile;
  final ProbationInfo probation;
  final OffboardingInfo offboarding;
  final List<EmploymentDocument> documents;
  final String hrThreadId;
  final DateTime? lastJoinReminderAt;
  final DateTime? lastDocsReminderAt;

  String get normalizedStatus => normalizeApplicationStatus(status);
  String get normalizedPipelineStage =>
      normalizePipelineStage(pipelineStage.isEmpty ? status : pipelineStage);
  String get normalizedOfferStatus => normalizeOfferStatus(offerStatus);
  String get normalizedLifecycleStage => normalizeLifecycleStage(
        lifecycleStage.isEmpty
            ? lifecycleStageFromHiringChange(
                pipelineStage: normalizedPipelineStage,
                offerStatus: normalizedOfferStatus,
                applicationStatus: status,
              )
            : lifecycleStage,
      );
  String get normalizedEmploymentStatus =>
      normalizeEmploymentStatus(employmentStatus);
  double get advisoryScore =>
      evaluationScore > 0 ? evaluationScore : rankingScore;

  bool get isJoiningSoon => normalizedEmploymentStatus == 'joining_soon';
  bool get isActiveEmployee => normalizedEmploymentStatus == 'active';
  bool get isLeftEmployee => normalizedEmploymentStatus == 'left';
  bool get hasStructuredOffer =>
      offerSalary.isNotEmpty ||
      offerRole.isNotEmpty ||
      offerMessage.isNotEmpty ||
      offerDetails.isNotEmpty;
  String get displayJobTitle =>
      employmentProfile.title.isNotEmpty ? employmentProfile.title : offerRole;
  String get displayDepartment => employmentProfile.department.isNotEmpty
      ? employmentProfile.department
      : offerDepartment;

  factory ApplicationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ApplicationModel(
      id: doc.id,
      jobId: _stringValue(data['jobId']),
      applicantId: _stringValue(data['applicantId']),
      companyId: _stringValue(data['companyId']),
      coverLetter: _stringValue(data['coverLetter']),
      status: _stringValue(data['status'], 'Pending'),
      appliedAt: _dateValue(data['appliedAt']),
      role: _stringValue(data['role'], 'student'),
      interviewId: _stringValue(data['interviewId']).isEmpty
          ? null
          : _stringValue(data['interviewId']),
      lastUpdatedAt: data['lastUpdatedAt'] == null
          ? null
          : _dateValue(data['lastUpdatedAt']),
      pipelineStage: _stringValue(data['pipelineStage']),
      evaluationScore: _doubleValue(
        data['evaluationScore'],
      ).clamp(0, 100).toDouble(),
      evaluationSummary: _stringValue(data['evaluationSummary']),
      rankingScore: _doubleValue(data['rankingScore']).clamp(0, 100).toDouble(),
      rankingReason: _stringValue(data['rankingReason']),
      matchedSkills: _stringList(data['matchedSkills']),
      missingSkills: _stringList(data['missingSkills']),
      recommendedNextStep: _stringValue(data['recommendedNextStep']),
      companyNotes: _stringValue(data['companyNotes']),
      offerStatus: _stringValue(data['offerStatus']),
      offerDetails: _stringValue(data['offerDetails']),
      candidateVisibleStatus: _stringValue(data['candidateVisibleStatus']),
      evaluationRequestStatus: _stringValue(
        data['evaluationRequestStatus'],
        'none',
      ),
      evaluationQuestions: _stringList(data['evaluationQuestions']),
      evaluationAnswers: _stringList(data['evaluationAnswers']),
      offerSalary: _stringValue(data['offerSalary']),
      offerCurrency: _stringValue(data['offerCurrency']),
      offerJoiningDate: _stringValue(data['offerJoiningDate']),
      offerMessage: _stringValue(data['offerMessage']),
      offerSentAt: data['offerSentAt'] == null
          ? null
          : _dateValue(data['offerSentAt']),
      offerRespondedAt: data['offerRespondedAt'] == null
          ? null
          : _dateValue(data['offerRespondedAt']),
      candidateResponseMessage: _stringValue(data['candidateResponseMessage']),
      talentPoolSaved: data['talentPoolSaved'] == true,
      evaluatedAt: data['evaluatedAt'] == null
          ? null
          : _dateValue(data['evaluatedAt']),
      lifecycleStage: _stringValue(data['lifecycleStage']),
      employmentStatus: _stringValue(data['employmentStatus'], 'none'),
      joinedAt: data['joinedAt'] == null ? null : _dateValue(data['joinedAt']),
      offerRole: _stringValue(data['offerRole']),
      offerDepartment: _stringValue(data['offerDepartment']),
      offerEmploymentType: _stringValue(data['offerEmploymentType']),
      offerBenefits: _stringValue(data['offerBenefits']),
      offerContractDuration: _stringValue(data['offerContractDuration']),
      offerWorkingHours: _stringValue(data['offerWorkingHours']),
      offerLocation: _stringValue(data['offerLocation']),
      offerExpiresAt: _stringValue(data['offerExpiresAt']),
      hrInterviewFeedback: _stringValue(data['hrInterviewFeedback']),
      hrHiringComments: _stringValue(data['hrHiringComments']),
      onboardingChecklist: _onboardingList(data['onboardingChecklist']),
      offerDocumentGeneratedAt: data['offerDocumentGeneratedAt'] == null
          ? null
          : _dateValue(data['offerDocumentGeneratedAt']),
      welcomePack: WelcomePack.fromMap(_mapOrNull(data['welcomePack'])),
      employmentProfile: EmploymentProfile.fromMap(
        _mapOrNull(data['employmentProfile']),
      ),
      probation: ProbationInfo.fromMap(_mapOrNull(data['probation'])),
      offboarding: OffboardingInfo.fromMap(_mapOrNull(data['offboarding'])),
      documents: _documentsList(data['documents']),
      hrThreadId: _stringValue(data['hrThreadId']),
      lastJoinReminderAt: data['lastJoinReminderAt'] == null
          ? null
          : _dateValue(data['lastJoinReminderAt']),
      lastDocsReminderAt: data['lastDocsReminderAt'] == null
          ? null
          : _dateValue(data['lastDocsReminderAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'applicantId': applicantId,
      'companyId': companyId,
      'coverLetter': coverLetter,
      'status': status,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'role': role,
      if (interviewId != null) 'interviewId': interviewId,
      if (lastUpdatedAt != null)
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt!),
      'pipelineStage': normalizedPipelineStage,
      'evaluationScore': evaluationScore.clamp(0, 100),
      'evaluationSummary': evaluationSummary,
      'rankingScore': rankingScore.clamp(0, 100),
      'rankingReason': rankingReason,
      'matchedSkills': matchedSkills,
      'missingSkills': missingSkills,
      'recommendedNextStep': recommendedNextStep,
      'companyNotes': companyNotes,
      'offerStatus': normalizedOfferStatus,
      'offerDetails': offerDetails,
      'candidateVisibleStatus': candidateVisibleStatus,
      'evaluationRequestStatus': evaluationRequestStatus,
      'evaluationQuestions': evaluationQuestions,
      'evaluationAnswers': evaluationAnswers,
      'offerSalary': offerSalary,
      'offerCurrency': offerCurrency,
      'offerJoiningDate': offerJoiningDate,
      'offerMessage': offerMessage,
      if (offerSentAt != null) 'offerSentAt': Timestamp.fromDate(offerSentAt!),
      if (offerRespondedAt != null)
        'offerRespondedAt': Timestamp.fromDate(offerRespondedAt!),
      'candidateResponseMessage': candidateResponseMessage,
      'talentPoolSaved': talentPoolSaved,
      if (evaluatedAt != null) 'evaluatedAt': Timestamp.fromDate(evaluatedAt!),
      'lifecycleStage': normalizedLifecycleStage,
      'employmentStatus': normalizedEmploymentStatus,
      if (joinedAt != null) 'joinedAt': Timestamp.fromDate(joinedAt!),
      'offerRole': offerRole,
      'offerDepartment': offerDepartment,
      'offerEmploymentType': offerEmploymentType,
      'offerBenefits': offerBenefits,
      'offerContractDuration': offerContractDuration,
      'offerWorkingHours': offerWorkingHours,
      'offerLocation': offerLocation,
      'offerExpiresAt': offerExpiresAt,
      'hrInterviewFeedback': hrInterviewFeedback,
      'hrHiringComments': hrHiringComments,
      'onboardingChecklist':
          onboardingChecklist.map((item) => item.toMap()).toList(),
      if (offerDocumentGeneratedAt != null)
        'offerDocumentGeneratedAt':
            Timestamp.fromDate(offerDocumentGeneratedAt!),
      'welcomePack': welcomePack.toMap(),
      'employmentProfile': employmentProfile.toMap(),
      'probation': probation.toMap(),
      'offboarding': offboarding.toMap(),
      'documents': documents.map((doc) => doc.toMap()).toList(),
      'hrThreadId': hrThreadId,
      if (lastJoinReminderAt != null)
        'lastJoinReminderAt': Timestamp.fromDate(lastJoinReminderAt!),
      if (lastDocsReminderAt != null)
        'lastDocsReminderAt': Timestamp.fromDate(lastDocsReminderAt!),
    };
  }

  ApplicationModel copyWith({
    String? id,
    String? jobId,
    String? applicantId,
    String? companyId,
    String? coverLetter,
    String? status,
    DateTime? appliedAt,
    String? role,
    String? interviewId,
    DateTime? lastUpdatedAt,
    String? pipelineStage,
    double? evaluationScore,
    String? evaluationSummary,
    double? rankingScore,
    String? rankingReason,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    String? recommendedNextStep,
    String? companyNotes,
    String? offerStatus,
    String? offerDetails,
    String? candidateVisibleStatus,
    String? evaluationRequestStatus,
    List<String>? evaluationQuestions,
    List<String>? evaluationAnswers,
    String? offerSalary,
    String? offerCurrency,
    String? offerJoiningDate,
    String? offerMessage,
    DateTime? offerSentAt,
    DateTime? offerRespondedAt,
    String? candidateResponseMessage,
    bool? talentPoolSaved,
    DateTime? evaluatedAt,
    String? lifecycleStage,
    String? employmentStatus,
    DateTime? joinedAt,
    String? offerRole,
    String? offerDepartment,
    String? offerEmploymentType,
    String? offerBenefits,
    String? offerContractDuration,
    String? offerWorkingHours,
    String? offerLocation,
    String? offerExpiresAt,
    String? hrInterviewFeedback,
    String? hrHiringComments,
    List<OnboardingChecklistItem>? onboardingChecklist,
    DateTime? offerDocumentGeneratedAt,
    WelcomePack? welcomePack,
    EmploymentProfile? employmentProfile,
    ProbationInfo? probation,
    OffboardingInfo? offboarding,
    List<EmploymentDocument>? documents,
    String? hrThreadId,
    DateTime? lastJoinReminderAt,
    DateTime? lastDocsReminderAt,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      applicantId: applicantId ?? this.applicantId,
      companyId: companyId ?? this.companyId,
      coverLetter: coverLetter ?? this.coverLetter,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      role: role ?? this.role,
      interviewId: interviewId ?? this.interviewId,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      pipelineStage: pipelineStage ?? this.pipelineStage,
      evaluationScore: evaluationScore ?? this.evaluationScore,
      evaluationSummary: evaluationSummary ?? this.evaluationSummary,
      rankingScore: rankingScore ?? this.rankingScore,
      rankingReason: rankingReason ?? this.rankingReason,
      matchedSkills: matchedSkills ?? this.matchedSkills,
      missingSkills: missingSkills ?? this.missingSkills,
      recommendedNextStep: recommendedNextStep ?? this.recommendedNextStep,
      companyNotes: companyNotes ?? this.companyNotes,
      offerStatus: offerStatus ?? this.offerStatus,
      offerDetails: offerDetails ?? this.offerDetails,
      candidateVisibleStatus:
          candidateVisibleStatus ?? this.candidateVisibleStatus,
      evaluationRequestStatus:
          evaluationRequestStatus ?? this.evaluationRequestStatus,
      evaluationQuestions: evaluationQuestions ?? this.evaluationQuestions,
      evaluationAnswers: evaluationAnswers ?? this.evaluationAnswers,
      offerSalary: offerSalary ?? this.offerSalary,
      offerCurrency: offerCurrency ?? this.offerCurrency,
      offerJoiningDate: offerJoiningDate ?? this.offerJoiningDate,
      offerMessage: offerMessage ?? this.offerMessage,
      offerSentAt: offerSentAt ?? this.offerSentAt,
      offerRespondedAt: offerRespondedAt ?? this.offerRespondedAt,
      candidateResponseMessage:
          candidateResponseMessage ?? this.candidateResponseMessage,
      talentPoolSaved: talentPoolSaved ?? this.talentPoolSaved,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      lifecycleStage: lifecycleStage ?? this.lifecycleStage,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      joinedAt: joinedAt ?? this.joinedAt,
      offerRole: offerRole ?? this.offerRole,
      offerDepartment: offerDepartment ?? this.offerDepartment,
      offerEmploymentType: offerEmploymentType ?? this.offerEmploymentType,
      offerBenefits: offerBenefits ?? this.offerBenefits,
      offerContractDuration: offerContractDuration ?? this.offerContractDuration,
      offerWorkingHours: offerWorkingHours ?? this.offerWorkingHours,
      offerLocation: offerLocation ?? this.offerLocation,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      hrInterviewFeedback: hrInterviewFeedback ?? this.hrInterviewFeedback,
      hrHiringComments: hrHiringComments ?? this.hrHiringComments,
      onboardingChecklist: onboardingChecklist ?? this.onboardingChecklist,
      offerDocumentGeneratedAt:
          offerDocumentGeneratedAt ?? this.offerDocumentGeneratedAt,
      welcomePack: welcomePack ?? this.welcomePack,
      employmentProfile: employmentProfile ?? this.employmentProfile,
      probation: probation ?? this.probation,
      offboarding: offboarding ?? this.offboarding,
      documents: documents ?? this.documents,
      hrThreadId: hrThreadId ?? this.hrThreadId,
      lastJoinReminderAt: lastJoinReminderAt ?? this.lastJoinReminderAt,
      lastDocsReminderAt: lastDocsReminderAt ?? this.lastDocsReminderAt,
    );
  }
}

const applicationPipelineStages = <String>[
  'applied',
  'screening',
  'evaluationRequested',
  'evaluationSubmitted',
  'shortlisted',
  'interview',
  'offer',
  'hired',
  'rejected',
  'talentPool',
];

const applicationOfferStatuses = <String>[
  'none',
  'draft',
  'sent',
  'accepted',
  'declined',
  'clarification',
  'withdrawn',
];

String normalizePipelineStage(String stage) {
  final normalized = stage.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'pending' || 'applied' => 'applied',
    'reviewed' || 'screening' || 'on_hold' || 'on hold' => 'screening',
    'evaluationrequested' ||
    'evaluation_requested' ||
    'evaluation requested' => 'evaluationRequested',
    'evaluationsubmitted' ||
    'evaluation_submitted' ||
    'evaluation submitted' => 'evaluationSubmitted',
    'shortlisted' => 'shortlisted',
    'interview_scheduled' ||
    'interview_completed' ||
    'interviewed' ||
    'interview' => 'interview',
    'selected' || 'offer' => 'offer',
    'hired' || 'accepted' => 'hired',
    'rejected' => 'rejected',
    'talentpool' || 'talent_pool' => 'talentPool',
    _ => normalized.isEmpty ? 'applied' : normalized,
  };
}

String pipelineStageLabel(String stage) {
  return switch (normalizePipelineStage(stage)) {
    'applied' => 'Applied',
    'screening' => 'Screening',
    'evaluationRequested' => 'Evaluation Requested',
    'evaluationSubmitted' => 'Evaluation Submitted',
    'shortlisted' => 'Shortlisted',
    'interview' => 'Interview',
    'offer' => 'Offer',
    'hired' => 'Hired',
    'rejected' => 'Rejected',
    'talentPool' => 'Talent Pool',
    _ => stage,
  };
}

String normalizeOfferStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'draft' => 'draft',
    'sent' || 'pending' || 'viewed' => 'sent',
    'accepted' => 'accepted',
    'declined' || 'rejected' => 'declined',
    'clarification' ||
    'clarification_requested' ||
    'request_clarification' => 'clarification',
    'withdrawn' => 'withdrawn',
    _ => 'none',
  };
}

String normalizeApplicationStatus(String status) {
  return switch (status.trim().toLowerCase()) {
    'pending' => 'applied',
    'reviewed' => 'shortlisted',
    'accepted' => 'selected',
    'screening' => 'screening',
    'offer' => 'offer',
    'hired' => 'hired',
    'talentpool' || 'talent_pool' => 'talentPool',
    'applied' => 'applied',
    'shortlisted' => 'shortlisted',
    'interview_scheduled' => 'interview_scheduled',
    'interview completed' || 'interview_completed' => 'interview_completed',
    'selected' => 'selected',
    'rejected' => 'rejected',
    'on hold' || 'on_hold' => 'on_hold',
    'withdrawn' => 'withdrawn',
    'joining_soon' => 'joining_soon',
    _ => status.trim().isEmpty ? 'applied' : status.trim().toLowerCase(),
  };
}

String applicationStatusLabel(String status) {
  return switch (normalizeApplicationStatus(status)) {
    'applied' => 'Applied',
    'shortlisted' => 'Shortlisted',
    'interview_scheduled' => 'Interview Scheduled',
    'interview_completed' => 'Interview Completed',
    'selected' => 'Selected',
    'offer' => 'Offer',
    'hired' => 'Hired',
    'rejected' => 'Rejected',
    'talentPool' => 'Talent Pool',
    'screening' => 'Screening',
    'on_hold' => 'On Hold',
    'withdrawn' => 'Withdrawn',
    'joining_soon' => 'Joining Soon',
    _ => status,
  };
}
