import 'package:cloud_firestore/cloud_firestore.dart';

import 'hiring_lifecycle_models.dart';

String _stringValue(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
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

class InterviewModel {
  const InterviewModel({
    required this.interviewId,
    required this.jobId,
    required this.applicationId,
    required this.companyId,
    required this.candidateId,
    required this.candidateRole,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.interviewMode,
    required this.meetingLink,
    required this.location,
    required this.agenda,
    required this.questions,
    required this.status,
    required this.result,
    required this.interviewerNotes,
    required this.candidateFeedback,
    required this.technicalScore,
    required this.communicationScore,
    required this.confidenceScore,
    required this.finalScore,
    required this.createdAt,
    required this.updatedAt,
    this.meetingPlatform = 'custom',
    this.timezone = 'UTC',
    this.companyInstructions = '',
    this.candidateInstructions = '',
  });

  final String interviewId;
  final String jobId;
  final String applicationId;
  final String companyId;
  final String candidateId;
  final String candidateRole;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String interviewMode;
  final String meetingLink;
  final String location;
  final String agenda;
  final List<String> questions;
  final String status;
  final String result;
  final String interviewerNotes;
  final String candidateFeedback;
  final double technicalScore;
  final double communicationScore;
  final double confidenceScore;
  final double finalScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String meetingPlatform;
  final String timezone;
  final String companyInstructions;
  final String candidateInstructions;

  bool get isScheduled => status == 'scheduled' || status == 'rescheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  String get platformLabel => meetingPlatformLabel(meetingPlatform);

  static double calculateFinalScore({
    required double technicalScore,
    required double communicationScore,
    required double confidenceScore,
  }) {
    final finalScore =
        technicalScore.clamp(0, 100) * 0.50 +
        communicationScore.clamp(0, 100) * 0.30 +
        confidenceScore.clamp(0, 100) * 0.20;
    return finalScore.clamp(0, 100).toDouble();
  }

  static String resultForScore(double finalScore) {
    if (finalScore >= 75) return 'passed';
    if (finalScore >= 50) return 'on_hold';
    return 'failed';
  }

  factory InterviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewModel(
      interviewId: _stringValue(data['interviewId'], doc.id),
      jobId: _stringValue(data['jobId']),
      applicationId: _stringValue(data['applicationId']),
      companyId: _stringValue(data['companyId']),
      candidateId: _stringValue(data['candidateId']),
      candidateRole: _stringValue(data['candidateRole'], 'student'),
      scheduledAt: _dateValue(data['scheduledAt']),
      durationMinutes: _intValue(data['durationMinutes'], 30),
      interviewMode: _stringValue(data['interviewMode'], 'online'),
      meetingLink: _stringValue(data['meetingLink']),
      location: _stringValue(data['location']),
      agenda: _stringValue(data['agenda']),
      questions: _stringList(data['questions']),
      status: _stringValue(data['status'], 'scheduled'),
      result: _stringValue(data['result'], 'pending'),
      interviewerNotes: _stringValue(data['interviewerNotes']),
      candidateFeedback: _stringValue(data['candidateFeedback']),
      technicalScore: _doubleValue(
        data['technicalScore'],
      ).clamp(0, 100).toDouble(),
      communicationScore: _doubleValue(
        data['communicationScore'],
      ).clamp(0, 100).toDouble(),
      confidenceScore: _doubleValue(
        data['confidenceScore'],
      ).clamp(0, 100).toDouble(),
      finalScore: _doubleValue(data['finalScore']).clamp(0, 100).toDouble(),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt'] ?? data['createdAt']),
      meetingPlatform: _stringValue(data['meetingPlatform'], 'custom'),
      timezone: _stringValue(data['timezone'], 'UTC'),
      companyInstructions: _stringValue(data['companyInstructions']),
      candidateInstructions: _stringValue(data['candidateInstructions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interviewId': interviewId,
      'jobId': jobId,
      'applicationId': applicationId,
      'companyId': companyId,
      'candidateId': candidateId,
      'candidateRole': candidateRole,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': durationMinutes,
      'interviewMode': interviewMode,
      'meetingLink': meetingLink,
      'location': location,
      'agenda': agenda,
      'questions': questions,
      'status': status,
      'result': result,
      'interviewerNotes': interviewerNotes,
      'candidateFeedback': candidateFeedback,
      'technicalScore': technicalScore,
      'communicationScore': communicationScore,
      'confidenceScore': confidenceScore,
      'finalScore': finalScore,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'meetingPlatform': meetingPlatform,
      'timezone': timezone,
      'companyInstructions': companyInstructions,
      'candidateInstructions': candidateInstructions,
    };
  }

  InterviewModel copyWith({
    String? interviewId,
    String? jobId,
    String? applicationId,
    String? companyId,
    String? candidateId,
    String? candidateRole,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? interviewMode,
    String? meetingLink,
    String? location,
    String? agenda,
    List<String>? questions,
    String? status,
    String? result,
    String? interviewerNotes,
    String? candidateFeedback,
    double? technicalScore,
    double? communicationScore,
    double? confidenceScore,
    double? finalScore,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? meetingPlatform,
    String? timezone,
    String? companyInstructions,
    String? candidateInstructions,
  }) {
    return InterviewModel(
      interviewId: interviewId ?? this.interviewId,
      jobId: jobId ?? this.jobId,
      applicationId: applicationId ?? this.applicationId,
      companyId: companyId ?? this.companyId,
      candidateId: candidateId ?? this.candidateId,
      candidateRole: candidateRole ?? this.candidateRole,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      interviewMode: interviewMode ?? this.interviewMode,
      meetingLink: meetingLink ?? this.meetingLink,
      location: location ?? this.location,
      agenda: agenda ?? this.agenda,
      questions: questions ?? this.questions,
      status: status ?? this.status,
      result: result ?? this.result,
      interviewerNotes: interviewerNotes ?? this.interviewerNotes,
      candidateFeedback: candidateFeedback ?? this.candidateFeedback,
      technicalScore: technicalScore ?? this.technicalScore,
      communicationScore: communicationScore ?? this.communicationScore,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      finalScore: finalScore ?? this.finalScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      meetingPlatform: meetingPlatform ?? this.meetingPlatform,
      timezone: timezone ?? this.timezone,
      companyInstructions: companyInstructions ?? this.companyInstructions,
      candidateInstructions:
          candidateInstructions ?? this.candidateInstructions,
    );
  }
}
