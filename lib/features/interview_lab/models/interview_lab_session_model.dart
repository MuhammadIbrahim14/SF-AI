import 'package:cloud_firestore/cloud_firestore.dart';

import 'interview_lab_enums.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// One AI Interview Lab practice/assigned session.
class InterviewLabSessionModel {
  const InterviewLabSessionModel({
    required this.sessionId,
    required this.candidateId,
    required this.candidateRole,
    required this.roleTrack,
    required this.difficulty,
    required this.status,
    required this.questionCount,
    required this.answeredCount,
    required this.timeConsumedSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.targetJobId,
    this.targetJobTitle,
    this.templateId,
    this.companyId,
    this.hiringInterviewId,
    this.applicationId,
    this.currentQuestionId,
    this.currentQuestionIndex = 0,
    this.startedAt,
    this.completedAt,
    this.aiProviderUsed,
    this.overallScore = 0,
    this.technicalScore = 0,
    this.communicationScore = 0,
    this.confidenceScore = 0,
    this.problemSolvingScore = 0,
    this.reportId,
    this.resultId,
    this.metadata = const {},
  });

  final String sessionId;
  final String candidateId;

  /// App role: student | freelancer | etc.
  final String candidateRole;

  /// Interview track: flutter, backend, …
  final String roleTrack;
  final String difficulty;
  final String status;

  /// Optional target job (Phase 2+ hiring link).
  final String? targetJobId;
  final String? targetJobTitle;
  final String? templateId;
  final String? companyId;
  final String? hiringInterviewId;
  final String? applicationId;

  final int questionCount;
  final int answeredCount;
  final String? currentQuestionId;
  final int currentQuestionIndex;
  final int timeConsumedSeconds;

  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? aiProviderUsed;
  final double overallScore;
  final double technicalScore;
  final double communicationScore;
  final double confidenceScore;
  final double problemSolvingScore;

  final String? reportId;
  final String? resultId;
  final Map<String, dynamic> metadata;

  bool get isInProgress => status == InterviewLabSessionStatus.inProgress;
  bool get isCompleted => status == InterviewLabSessionStatus.completed;
  bool get hasTargetJob => (targetJobId ?? '').isNotEmpty;

  bool get timerEnforced => metadata['timerEnforced'] == true;

  DateTime? get timerDeadlineAt {
    final raw = metadata['timerDeadlineAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool get isTimerExpired {
    if (!timerEnforced) return false;
    final deadline = timerDeadlineAt;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  /// Remaining seconds until deadline; 0 when expired / unknown.
  int get timerRemainingSeconds {
    final deadline = timerDeadlineAt;
    if (deadline == null) return 0;
    final left = deadline.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  factory InterviewLabSessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabSessionModel.fromMap(data, docId: doc.id);
  }

  factory InterviewLabSessionModel.fromMap(
    Map<String, dynamic> data, {
    String? docId,
  }) {
    return InterviewLabSessionModel(
      sessionId: data['sessionId']?.toString() ?? docId ?? '',
      candidateId: data['candidateId']?.toString() ?? '',
      candidateRole: data['candidateRole']?.toString() ?? 'student',
      roleTrack: data['roleTrack']?.toString() ?? InterviewLabRoleTrack.general,
      difficulty:
          data['difficulty']?.toString() ?? InterviewLabDifficulty.medium,
      status: data['status']?.toString() ?? InterviewLabSessionStatus.draft,
      targetJobId: data['targetJobId']?.toString(),
      targetJobTitle: data['targetJobTitle']?.toString(),
      templateId: data['templateId']?.toString(),
      companyId: data['companyId']?.toString(),
      hiringInterviewId: data['hiringInterviewId']?.toString(),
      applicationId: data['applicationId']?.toString(),
      questionCount: _int(data['questionCount']),
      answeredCount: _int(data['answeredCount']),
      currentQuestionId: data['currentQuestionId']?.toString(),
      currentQuestionIndex: _int(data['currentQuestionIndex']),
      timeConsumedSeconds: _int(data['timeConsumedSeconds']),
      startedAt: data['startedAt'] != null ? _date(data['startedAt']) : null,
      completedAt:
          data['completedAt'] != null ? _date(data['completedAt']) : null,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      aiProviderUsed: data['aiProviderUsed']?.toString(),
      overallScore: _double(data['overallScore']),
      technicalScore: _double(data['technicalScore']),
      communicationScore: _double(data['communicationScore']),
      confidenceScore: _double(data['confidenceScore']),
      problemSolvingScore: _double(data['problemSolvingScore']),
      reportId: data['reportId']?.toString(),
      resultId: data['resultId']?.toString(),
      metadata: Map<String, dynamic>.from(
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) {
    return {
      'sessionId': sessionId,
      'candidateId': candidateId,
      'candidateRole': candidateRole,
      'roleTrack': roleTrack,
      'difficulty': difficulty,
      'status': status,
      'targetJobId': targetJobId,
      'targetJobTitle': targetJobTitle,
      'templateId': templateId,
      'companyId': companyId,
      'hiringInterviewId': hiringInterviewId,
      'applicationId': applicationId,
      'questionCount': questionCount,
      'answeredCount': answeredCount,
      'currentQuestionId': currentQuestionId,
      'currentQuestionIndex': currentQuestionIndex,
      'timeConsumedSeconds': timeConsumedSeconds,
      'startedAt': startedAt == null
          ? null
          : Timestamp.fromDate(startedAt!),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'createdAt': useServerTimestamps
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      'updatedAt': useServerTimestamps
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt),
      'aiProviderUsed': aiProviderUsed,
      'overallScore': overallScore,
      'technicalScore': technicalScore,
      'communicationScore': communicationScore,
      'confidenceScore': confidenceScore,
      'problemSolvingScore': problemSolvingScore,
      'reportId': reportId,
      'resultId': resultId,
      'metadata': metadata,
      'gateway': 'skillforge_interview_lab',
      'module': 'interview_lab',
    };
  }

  InterviewLabSessionModel copyWith({
    String? status,
    int? questionCount,
    int? answeredCount,
    String? currentQuestionId,
    int? currentQuestionIndex,
    int? timeConsumedSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    String? aiProviderUsed,
    double? overallScore,
    double? technicalScore,
    double? communicationScore,
    double? confidenceScore,
    double? problemSolvingScore,
    String? reportId,
    String? resultId,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
  }) {
    return InterviewLabSessionModel(
      sessionId: sessionId,
      candidateId: candidateId,
      candidateRole: candidateRole,
      roleTrack: roleTrack,
      difficulty: difficulty,
      status: status ?? this.status,
      targetJobId: targetJobId,
      targetJobTitle: targetJobTitle,
      templateId: templateId,
      companyId: companyId,
      hiringInterviewId: hiringInterviewId,
      applicationId: applicationId,
      questionCount: questionCount ?? this.questionCount,
      answeredCount: answeredCount ?? this.answeredCount,
      currentQuestionId: currentQuestionId ?? this.currentQuestionId,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      timeConsumedSeconds: timeConsumedSeconds ?? this.timeConsumedSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      aiProviderUsed: aiProviderUsed ?? this.aiProviderUsed,
      overallScore: overallScore ?? this.overallScore,
      technicalScore: technicalScore ?? this.technicalScore,
      communicationScore: communicationScore ?? this.communicationScore,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      problemSolvingScore: problemSolvingScore ?? this.problemSolvingScore,
      reportId: reportId ?? this.reportId,
      resultId: resultId ?? this.resultId,
      metadata: metadata ?? this.metadata,
    );
  }
}
