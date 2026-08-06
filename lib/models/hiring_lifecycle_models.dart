import 'package:cloud_firestore/cloud_firestore.dart';

export 'user_notification_model.dart';

/// Enterprise hiring lifecycle stages (Phase 5).
/// Stored on [ApplicationModel.lifecycleStage] and timeline events.
const hiringLifecycleStages = <String>[
  'applied',
  'resume_reviewed',
  'portfolio_reviewed',
  'ai_interview_completed',
  'shortlisted',
  'interview_scheduled',
  'interview_completed',
  'evaluated',
  'offer_sent',
  'offer_accepted',
  'offer_declined',
  'joined',
  'rejected',
];

const employmentStatuses = <String>[
  'none',
  'joining_soon',
  'active',
  'left',
];

const meetingPlatforms = <String>[
  'google_meet',
  'zoom',
  'microsoft_teams',
  'custom',
  'none',
];

String normalizeLifecycleStage(String stage) {
  final normalized = stage.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'applied' || 'pending' => 'applied',
    'resume_reviewed' || 'resume reviewed' || 'reviewed' => 'resume_reviewed',
    'portfolio_reviewed' || 'portfolio reviewed' => 'portfolio_reviewed',
    'ai_interview_completed' ||
    'ai interview completed' ||
    'ai_interview' => 'ai_interview_completed',
    'shortlisted' => 'shortlisted',
    'interview_scheduled' || 'interview scheduled' => 'interview_scheduled',
    'interview_completed' || 'interview completed' => 'interview_completed',
    'evaluated' ||
    'evaluation_complete' ||
    'evaluation completed' ||
    'ready_for_decision' => 'evaluated',
    'offer_sent' || 'offer sent' || 'offer' => 'offer_sent',
    'offer_accepted' || 'offer accepted' || 'accepted' => 'offer_accepted',
    'offer_declined' || 'offer declined' || 'declined' => 'offer_declined',
    'joined' || 'joined_company' || 'hired' => 'joined',
    'rejected' => 'rejected',
    _ => normalized.isEmpty ? 'applied' : normalized,
  };
}

String lifecycleStageLabel(String stage) {
  return switch (normalizeLifecycleStage(stage)) {
    'applied' => 'Applied',
    'resume_reviewed' => 'Resume Reviewed',
    'portfolio_reviewed' => 'Portfolio Reviewed',
    'ai_interview_completed' => 'AI Interview Completed',
    'shortlisted' => 'Shortlisted',
    'interview_scheduled' => 'Interview Scheduled',
    'interview_completed' => 'Interview Completed',
    'evaluated' => 'Evaluated',
    'offer_sent' => 'Offer Sent',
    'offer_accepted' => 'Offer Accepted',
    'offer_declined' => 'Offer Declined',
    'joined' => 'Joined Company',
    'rejected' => 'Rejected',
    _ => stage,
  };
}

String normalizeEmploymentStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'joining_soon' || 'joining soon' || 'pending_join' => 'joining_soon',
    'active' || 'employee_active' || 'hired' => 'active',
    'left' || 'inactive' => 'left',
    _ => 'none',
  };
}

String employmentStatusLabel(String status) {
  return switch (normalizeEmploymentStatus(status)) {
    'joining_soon' => 'Joining Soon',
    'active' => 'Employee Active',
    'left' => 'Left',
    _ => 'Not employed',
  };
}

String meetingPlatformLabel(String platform) {
  return switch (platform.trim().toLowerCase()) {
    'google_meet' => 'Google Meet',
    'zoom' => 'Zoom',
    'microsoft_teams' => 'Microsoft Teams',
    'custom' => 'Custom URL',
    _ => 'None',
  };
}

/// Maps pipeline / offer / interview status changes → lifecycle stage.
String lifecycleStageFromHiringChange({
  required String pipelineStage,
  required String offerStatus,
  String? applicationStatus,
  String? interviewStatus,
}) {
  final offer = offerStatus.trim().toLowerCase();
  if (offer == 'declined' || offer == 'rejected') return 'offer_declined';
  if (offer == 'accepted') {
    if (pipelineStage == 'hired') return 'joined';
    return 'offer_accepted';
  }
  if (offer == 'sent' || offer == 'pending' || offer == 'viewed') {
    return 'offer_sent';
  }

  final interview = (interviewStatus ?? '').trim().toLowerCase();
  if (interview == 'completed') return 'interview_completed';
  if (interview == 'cancelled') {
    // Keep shortlisted/interview context; do not invent a cancelled lifecycle.
  }
  if (interview == 'scheduled' || interview == 'rescheduled') {
    return 'interview_scheduled';
  }

  final status = (applicationStatus ?? '').trim().toLowerCase();
  if (status == 'evaluated' ||
      status == 'evaluation_complete' ||
      status == 'ready_for_decision') {
    return 'evaluated';
  }
  if (status == 'interview_completed') return 'interview_completed';
  if (status == 'interview_scheduled') return 'interview_scheduled';

  return switch (pipelineStage) {
    'hired' => 'joined',
    'rejected' => 'rejected',
    'offer' => 'offer_sent',
    'interview' => status.contains('completed') || status == 'evaluated'
        ? (status == 'evaluated' ? 'evaluated' : 'interview_completed')
        : 'interview_scheduled',
    'shortlisted' => 'shortlisted',
    'screening' => 'resume_reviewed',
    'evaluationSubmitted' || 'evaluationRequested' => 'portfolio_reviewed',
    _ => 'applied',
  };
}

const probationStatuses = <String>[
  'none',
  'active',
  'completed',
  'extended',
];

String normalizeProbationStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'active' => 'active',
    'completed' || 'complete' => 'completed',
    'extended' || 'extend' => 'extended',
    _ => 'none',
  };
}

/// Welcome pack published by company for a hired / joining employee.
class WelcomePack {
  const WelcomePack({
    this.message = '',
    this.teamContacts = const <String>[],
    this.links = const <String>[],
    this.policiesSummary = '',
    this.publishedAt,
    this.publishedBy = '',
  });

  final String message;
  final List<String> teamContacts;
  final List<String> links;
  final String policiesSummary;
  final DateTime? publishedAt;
  final String publishedBy;

  bool get isPublished =>
      publishedAt != null ||
      message.trim().isNotEmpty ||
      policiesSummary.trim().isNotEmpty;

  factory WelcomePack.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const WelcomePack();
    return WelcomePack(
      message: (data['message'] as String?)?.trim() ?? '',
      teamContacts: _stringList(data['teamContacts']),
      links: _stringList(data['links']),
      policiesSummary: (data['policiesSummary'] as String?)?.trim() ?? '',
      publishedAt: _nullableDate(data['publishedAt']),
      publishedBy: (data['publishedBy'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'teamContacts': teamContacts,
      'links': links,
      'policiesSummary': policiesSummary,
      if (publishedAt != null)
        'publishedAt': Timestamp.fromDate(publishedAt!),
      'publishedBy': publishedBy,
    };
  }

  WelcomePack copyWith({
    String? message,
    List<String>? teamContacts,
    List<String>? links,
    String? policiesSummary,
    DateTime? publishedAt,
    String? publishedBy,
  }) {
    return WelcomePack(
      message: message ?? this.message,
      teamContacts: teamContacts ?? this.teamContacts,
      links: links ?? this.links,
      policiesSummary: policiesSummary ?? this.policiesSummary,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
    );
  }

  /// Seeded on [markJoined] when company has not published a pack yet.
  factory WelcomePack.defaultForJoin({
    required String publishedBy,
    required DateTime publishedAt,
  }) {
    return WelcomePack(
      message:
          'Welcome aboard! We are excited to have you on the team. '
          'Complete your onboarding checklist and message HR if you need help.',
      policiesSummary:
          'Please review company policies, accept terms, and submit '
          'required employment documents.',
      publishedAt: publishedAt,
      publishedBy: publishedBy,
    );
  }
}

/// Role / org profile for an employee, seeded from offer fields.
class EmploymentProfile {
  const EmploymentProfile({
    this.title = '',
    this.department = '',
    this.managerName = '',
    this.workLocation = '',
    this.workEmail = '',
    this.workPhone = '',
  });

  final String title;
  final String department;
  final String managerName;
  final String workLocation;
  final String workEmail;
  final String workPhone;

  bool get isEmpty =>
      title.isEmpty &&
      department.isEmpty &&
      managerName.isEmpty &&
      workLocation.isEmpty &&
      workEmail.isEmpty &&
      workPhone.isEmpty;

  factory EmploymentProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const EmploymentProfile();
    return EmploymentProfile(
      title: (data['title'] as String?)?.trim() ?? '',
      department: (data['department'] as String?)?.trim() ?? '',
      managerName: (data['managerName'] as String?)?.trim() ?? '',
      workLocation: (data['workLocation'] as String?)?.trim() ?? '',
      workEmail: (data['workEmail'] as String?)?.trim() ?? '',
      workPhone: (data['workPhone'] as String?)?.trim() ?? '',
    );
  }

  factory EmploymentProfile.fromOffer({
    required String offerRole,
    required String offerDepartment,
    required String offerLocation,
  }) {
    return EmploymentProfile(
      title: offerRole.trim(),
      department: offerDepartment.trim(),
      workLocation: offerLocation.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'department': department,
      'managerName': managerName,
      'workLocation': workLocation,
      'workEmail': workEmail,
      'workPhone': workPhone,
    };
  }

  EmploymentProfile copyWith({
    String? title,
    String? department,
    String? managerName,
    String? workLocation,
    String? workEmail,
    String? workPhone,
  }) {
    return EmploymentProfile(
      title: title ?? this.title,
      department: department ?? this.department,
      managerName: managerName ?? this.managerName,
      workLocation: workLocation ?? this.workLocation,
      workEmail: workEmail ?? this.workEmail,
      workPhone: workPhone ?? this.workPhone,
    );
  }
}

/// Probation window for an active employee (P2 UI in later waves).
class ProbationInfo {
  const ProbationInfo({
    this.startsAt,
    this.endsAt,
    this.status = 'none',
    this.notes = '',
  });

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final String notes;

  String get normalizedStatus => normalizeProbationStatus(status);

  factory ProbationInfo.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ProbationInfo();
    return ProbationInfo(
      startsAt: _nullableDate(data['startsAt']),
      endsAt: _nullableDate(data['endsAt']),
      status: normalizeProbationStatus(
        (data['status'] as String?) ?? 'none',
      ),
      notes: (data['notes'] as String?)?.trim() ?? '',
    );
  }

  factory ProbationInfo.defaultFromJoin(DateTime joinedAt, {int days = 90}) {
    return ProbationInfo(
      startsAt: joinedAt,
      endsAt: joinedAt.add(Duration(days: days)),
      status: 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (startsAt != null) 'startsAt': Timestamp.fromDate(startsAt!),
      if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
      'status': normalizeProbationStatus(status),
      'notes': notes,
    };
  }

  ProbationInfo copyWith({
    DateTime? startsAt,
    DateTime? endsAt,
    String? status,
    String? notes,
  }) {
    return ProbationInfo(
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  double get progressFraction {
    if (startsAt == null || endsAt == null) return 0;
    final total = endsAt!.difference(startsAt!).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(startsAt!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  int? get daysRemaining {
    if (endsAt == null) return null;
    return endsAt!.difference(DateTime.now()).inDays;
  }
}

/// Offboarding payload when employmentStatus → left.
class OffboardingInfo {
  const OffboardingInfo({
    this.leftAt,
    this.reason = '',
    this.notes = '',
    this.checklist = const <OnboardingChecklistItem>[],
  });

  final DateTime? leftAt;
  final String reason;
  final String notes;
  final List<OnboardingChecklistItem> checklist;

  bool get hasData =>
      leftAt != null ||
      reason.isNotEmpty ||
      notes.isNotEmpty ||
      checklist.isNotEmpty;

  factory OffboardingInfo.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const OffboardingInfo();
    final rawChecklist = data['checklist'];
    final checklist = rawChecklist is Iterable
        ? rawChecklist
            .whereType<Map>()
            .map(
              (item) => OnboardingChecklistItem.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList()
        : const <OnboardingChecklistItem>[];
    return OffboardingInfo(
      leftAt: _nullableDate(data['leftAt']),
      reason: (data['reason'] as String?)?.trim() ?? '',
      notes: (data['notes'] as String?)?.trim() ?? '',
      checklist: checklist,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (leftAt != null) 'leftAt': Timestamp.fromDate(leftAt!),
      'reason': reason,
      'notes': notes,
      'checklist': checklist.map((item) => item.toMap()).toList(),
    };
  }

  OffboardingInfo copyWith({
    DateTime? leftAt,
    String? reason,
    String? notes,
    List<OnboardingChecklistItem>? checklist,
  }) {
    return OffboardingInfo(
      leftAt: leftAt ?? this.leftAt,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      checklist: checklist ?? this.checklist,
    );
  }

  static List<OnboardingChecklistItem> defaultChecklist() {
    return const [
      OnboardingChecklistItem(
        id: 'revoke_access',
        title: 'Revoke system access',
      ),
      OnboardingChecklistItem(
        id: 'return_assets',
        title: 'Return company assets',
      ),
      OnboardingChecklistItem(
        id: 'exit_interview',
        title: 'Exit interview note',
      ),
    ];
  }
}

/// Employment document vault entry (Cloudinary URL).
class EmploymentDocument {
  const EmploymentDocument({
    required this.id,
    required this.title,
    this.category = 'other',
    required this.url,
    required this.uploadedBy,
    required this.uploadedAt,
    this.visibleToCandidate = true,
  });

  final String id;
  final String title;
  final String category;
  final String url;
  final String uploadedBy;
  final DateTime uploadedAt;
  final bool visibleToCandidate;

  factory EmploymentDocument.fromMap(Map<String, dynamic> data) {
    return EmploymentDocument(
      id: (data['id'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? (data['category'] as String).trim()
          : 'other',
      url: (data['url'] as String?)?.trim() ?? '',
      uploadedBy: (data['uploadedBy'] as String?)?.trim() ?? '',
      uploadedAt: _nullableDate(data['uploadedAt']) ?? DateTime.now(),
      visibleToCandidate: data['visibleToCandidate'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'url': url,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'visibleToCandidate': visibleToCandidate,
    };
  }
}

DateTime? _nullableDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
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

class OnboardingChecklistItem {
  const OnboardingChecklistItem({
    required this.id,
    required this.title,
    this.completed = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final bool completed;
  final DateTime? completedAt;

  factory OnboardingChecklistItem.fromMap(Map<String, dynamic> data) {
    return OnboardingChecklistItem(
      id: (data['id'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      completed: data['completed'] == true,
      completedAt: data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : data['completedAt'] is DateTime
              ? data['completedAt'] as DateTime
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      if (completedAt != null)
        'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  OnboardingChecklistItem copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? completedAt,
  }) {
    return OnboardingChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static const candidateCompletableIds = <String>{
    'complete_profile',
    'verify_email',
    'read_policies',
    'accept_terms',
    'submit_documents',
  };

  bool get isCandidateCompletable => candidateCompletableIds.contains(id);

  static List<OnboardingChecklistItem> defaultChecklist() {
    return const [
      OnboardingChecklistItem(id: 'complete_profile', title: 'Complete Profile'),
      OnboardingChecklistItem(id: 'verify_email', title: 'Verify Email'),
      OnboardingChecklistItem(
        id: 'read_policies',
        title: 'Read Company Policies',
      ),
      OnboardingChecklistItem(id: 'accept_terms', title: 'Accept Terms'),
      OnboardingChecklistItem(
        id: 'submit_documents',
        title: 'Submit Documents',
      ),
    ];
  }
}

/// Thin HR chat message under `employmentHrThreads/{id}/messages`.
class EmploymentHrMessage {
  const EmploymentHrMessage({
    required this.id,
    required this.threadId,
    required this.applicationId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String applicationId;
  final String senderId;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  factory EmploymentHrMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EmploymentHrMessage(
      id: doc.id,
      threadId: (data['threadId'] as String?)?.trim() ?? '',
      applicationId: (data['applicationId'] as String?)?.trim() ?? '',
      senderId: (data['senderId'] as String?)?.trim() ?? '',
      senderRole: (data['senderRole'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
      createdAt: _nullableDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'threadId': threadId,
      'applicationId': applicationId,
      'senderId': senderId,
      'senderRole': senderRole,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class HiringTimelineEvent {
  const HiringTimelineEvent({
    required this.id,
    required this.applicationId,
    required this.companyId,
    required this.candidateId,
    required this.stage,
    required this.title,
    required this.description,
    required this.actorId,
    required this.actorRole,
    required this.createdAt,
    this.visibleToCandidate = true,
  });

  final String id;
  final String applicationId;
  final String companyId;
  final String candidateId;
  final String stage;
  final String title;
  final String description;
  final String actorId;
  final String actorRole;
  final DateTime createdAt;
  final bool visibleToCandidate;

  factory HiringTimelineEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return HiringTimelineEvent(
      id: doc.id,
      applicationId: (data['applicationId'] as String?) ?? '',
      companyId: (data['companyId'] as String?) ?? '',
      candidateId: (data['candidateId'] as String?) ?? '',
      stage: normalizeLifecycleStage((data['stage'] as String?) ?? ''),
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      actorId: (data['actorId'] as String?) ?? '',
      actorRole: (data['actorRole'] as String?) ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      visibleToCandidate: data['visibleToCandidate'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applicationId': applicationId,
      'companyId': companyId,
      'candidateId': candidateId,
      'stage': normalizeLifecycleStage(stage),
      'title': title,
      'description': description,
      'actorId': actorId,
      'actorRole': actorRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'visibleToCandidate': visibleToCandidate,
    };
  }
}

class HiringAnalyticsSnapshot {
  const HiringAnalyticsSnapshot({
    required this.totalApplications,
    required this.funnelCounts,
    required this.offerAcceptanceRate,
    required this.interviewCompletionRate,
    required this.employeeConversionRate,
    required this.averageHiringDays,
    required this.topSkillsHired,
    required this.activeEmployees,
    required this.pendingJoining,
    required this.offersSent,
    required this.rejected,
    required this.interviewScheduled,
    required this.newApplications,
  });

  final int totalApplications;
  final Map<String, int> funnelCounts;
  final double offerAcceptanceRate;
  final double interviewCompletionRate;
  final double employeeConversionRate;
  final double averageHiringDays;
  final List<String> topSkillsHired;
  final int activeEmployees;
  final int pendingJoining;
  final int offersSent;
  final int rejected;
  final int interviewScheduled;
  final int newApplications;

  static const empty = HiringAnalyticsSnapshot(
    totalApplications: 0,
    funnelCounts: <String, int>{},
    offerAcceptanceRate: 0,
    interviewCompletionRate: 0,
    employeeConversionRate: 0,
    averageHiringDays: 0,
    topSkillsHired: <String>[],
    activeEmployees: 0,
    pendingJoining: 0,
    offersSent: 0,
    rejected: 0,
    interviewScheduled: 0,
    newApplications: 0,
  );
}
