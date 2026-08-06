import 'package:cloud_firestore/cloud_firestore.dart';

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

List<String> _strings(Object? value) {
  if (value is Iterable) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
  );
}

/// Reusable Interview Lab report (AI composed — no template fallback).
class InterviewLabReportModel {
  const InterviewLabReportModel({
    required this.reportId,
    required this.sessionId,
    required this.candidateId,
    required this.createdAt,
    required this.updatedAt,
    this.technicalScore = 0,
    this.communicationScore = 0,
    this.confidenceScore = 0,
    this.professionalismScore = 0,
    this.problemSolvingScore = 0,
    this.architectureScore = 0,
    this.codeQualityScore = 0,
    this.professionalReadinessScore = 0,
    this.overallRating = 0,
    this.overallLabel = 'pending',
    this.interviewLevel = 'Beginner',
    this.industryReadiness = '',
    this.scoreExplanations = const {},
    this.strengths = const [],
    this.weakSkills = const [],
    this.skillsDemonstrated = const [],
    this.skillsMissing = const [],
    this.mistakes = const [],
    this.recommendations = const [],
    this.learningPath = const [],
    this.recommendedCourses = const [],
    this.recommendedProjects = const [],
    this.recommendedCertifications = const [],
    this.badgesAwarded = const [],
    this.summary = '',
    this.aiProviderUsed,
    this.rawAiPayload = const {},
  });

  final String reportId;
  final String sessionId;
  final String candidateId;
  final double technicalScore;
  final double communicationScore;
  final double confidenceScore;
  final double professionalismScore;
  final double problemSolvingScore;
  final double architectureScore;
  final double codeQualityScore;
  final double professionalReadinessScore;
  final double overallRating;
  final String overallLabel;
  final String interviewLevel;
  final String industryReadiness;
  final Map<String, String> scoreExplanations;
  final List<String> strengths;
  final List<String> weakSkills;
  final List<String> skillsDemonstrated;
  final List<String> skillsMissing;
  final List<String> mistakes;
  final List<String> recommendations;
  final List<String> learningPath;
  final List<String> recommendedCourses;
  final List<String> recommendedProjects;
  final List<String> recommendedCertifications;
  final List<String> badgesAwarded;
  final String summary;
  final String? aiProviderUsed;
  final Map<String, dynamic> rawAiPayload;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory InterviewLabReportModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabReportModel.fromMap(data, docId: doc.id);
  }

  factory InterviewLabReportModel.fromMap(
    Map<String, dynamic> data, {
    String? docId,
  }) {
    return InterviewLabReportModel(
      reportId: data['reportId']?.toString() ?? docId ?? '',
      sessionId: data['sessionId']?.toString() ?? '',
      candidateId: data['candidateId']?.toString() ?? '',
      technicalScore: _double(data['technicalScore']),
      communicationScore: _double(data['communicationScore']),
      confidenceScore: _double(data['confidenceScore']),
      professionalismScore: _double(data['professionalismScore']),
      problemSolvingScore: _double(data['problemSolvingScore']),
      architectureScore: _double(data['architectureScore']),
      codeQualityScore: _double(data['codeQualityScore']),
      professionalReadinessScore: _double(data['professionalReadinessScore']),
      overallRating: _double(data['overallRating']),
      overallLabel: data['overallLabel']?.toString() ?? 'pending',
      interviewLevel: () {
        final direct = data['interviewLevel']?.toString();
        if (direct != null && direct.isNotEmpty) return direct;
        final raw = data['rawAiPayload'];
        if (raw is Map) {
          final lvl = raw['interviewLevel']?.toString();
          if (lvl != null && lvl.isNotEmpty) return lvl;
        }
        return 'Beginner';
      }(),
      industryReadiness: data['industryReadiness']?.toString() ?? '',
      scoreExplanations: _stringMap(data['scoreExplanations']),
      strengths: _strings(data['strengths']),
      weakSkills: _strings(data['weakSkills']),
      skillsDemonstrated: _strings(data['skillsDemonstrated']),
      skillsMissing: _strings(data['skillsMissing']),
      mistakes: _strings(data['mistakes']),
      recommendations: _strings(data['recommendations']),
      learningPath: _strings(data['learningPath']),
      recommendedCourses: _strings(data['recommendedCourses']),
      recommendedProjects: _strings(data['recommendedProjects']),
      recommendedCertifications: _strings(data['recommendedCertifications']),
      badgesAwarded: _strings(data['badgesAwarded']),
      summary: data['summary']?.toString() ?? '',
      aiProviderUsed: data['aiProviderUsed']?.toString(),
      rawAiPayload: Map<String, dynamic>.from(
        (data['rawAiPayload'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'reportId': reportId,
        'sessionId': sessionId,
        'candidateId': candidateId,
        'technicalScore': technicalScore,
        'communicationScore': communicationScore,
        'confidenceScore': confidenceScore,
        'professionalismScore': professionalismScore,
        'problemSolvingScore': problemSolvingScore,
        'architectureScore': architectureScore,
        'codeQualityScore': codeQualityScore,
        'professionalReadinessScore': professionalReadinessScore,
        'overallRating': overallRating,
        'overallLabel': overallLabel,
        'interviewLevel': interviewLevel,
        'industryReadiness': industryReadiness,
        'scoreExplanations': scoreExplanations,
        'strengths': strengths,
        'weakSkills': weakSkills,
        'skillsDemonstrated': skillsDemonstrated,
        'skillsMissing': skillsMissing,
        'mistakes': mistakes,
        'recommendations': recommendations,
        'learningPath': learningPath,
        'recommendedCourses': recommendedCourses,
        'recommendedProjects': recommendedProjects,
        'recommendedCertifications': recommendedCertifications,
        'badgesAwarded': badgesAwarded,
        'summary': summary,
        'aiProviderUsed': aiProviderUsed,
        'rawAiPayload': rawAiPayload,
        'createdAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt),
        'updatedAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(updatedAt),
        'module': 'interview_lab',
      };
}

/// Compact result document for dashboards / history indexes.
class InterviewLabResultModel {
  const InterviewLabResultModel({
    required this.resultId,
    required this.sessionId,
    required this.candidateId,
    required this.overallScore,
    required this.outcome,
    required this.createdAt,
    this.reportId,
    this.roleTrack,
    this.difficulty,
    this.technicalScore = 0,
    this.communicationScore = 0,
    this.confidenceScore = 0,
    this.problemSolvingScore = 0,
    this.interviewLevel,
  });

  final String resultId;
  final String sessionId;
  final String candidateId;
  final String? reportId;
  final String? roleTrack;
  final String? difficulty;
  final double overallScore;
  final String outcome;
  final double technicalScore;
  final double communicationScore;
  final double confidenceScore;
  final double problemSolvingScore;
  final String? interviewLevel;
  final DateTime createdAt;

  factory InterviewLabResultModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabResultModel(
      resultId: data['resultId']?.toString() ?? doc.id,
      sessionId: data['sessionId']?.toString() ?? '',
      candidateId: data['candidateId']?.toString() ?? '',
      reportId: data['reportId']?.toString(),
      roleTrack: data['roleTrack']?.toString(),
      difficulty: data['difficulty']?.toString(),
      overallScore: _double(data['overallScore']),
      outcome: data['outcome']?.toString() ?? 'pending',
      technicalScore: _double(data['technicalScore']),
      communicationScore: _double(data['communicationScore']),
      confidenceScore: _double(data['confidenceScore']),
      problemSolvingScore: _double(data['problemSolvingScore']),
      interviewLevel: data['interviewLevel']?.toString(),
      createdAt: _date(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'resultId': resultId,
        'sessionId': sessionId,
        'candidateId': candidateId,
        'reportId': reportId,
        'roleTrack': roleTrack,
        'difficulty': difficulty,
        'overallScore': overallScore,
        'outcome': outcome,
        'technicalScore': technicalScore,
        'communicationScore': communicationScore,
        'confidenceScore': confidenceScore,
        'problemSolvingScore': problemSolvingScore,
        'interviewLevel': interviewLevel,
        'createdAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt),
        'module': 'interview_lab',
      };
}
