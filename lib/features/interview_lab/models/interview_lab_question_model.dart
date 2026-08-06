import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<String> _strings(Object? value) {
  if (value is Iterable) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

/// AI-generated question bound to a lab session (never hardcoded banks).
class InterviewLabQuestionModel {
  const InterviewLabQuestionModel({
    required this.questionId,
    required this.sessionId,
    required this.orderIndex,
    required this.prompt,
    required this.difficulty,
    required this.roleTrack,
    required this.createdAt,
    this.category = 'technical',
    this.expectedFocus = const [],
    this.candidateAnswer,
    this.answeredAt,
    this.timeSpentSeconds = 0,
    this.aiCritique,
    this.scoreTechnical,
    this.scoreCommunication,
    this.scoreConfidence,
    this.scoreProblemSolving,
    this.scoreArchitecture,
    this.scoreCodeQuality,
    this.scoreOverall,
    this.strengths = const [],
    this.weaknesses = const [],
    this.improvement,
    this.evaluationBreakdown = const {},
    this.isFollowUp = false,
    this.parentQuestionId,
    this.isSkipped = false,
    this.critiqueLocked = false,
    this.critiqueAttempts = 0,
    this.evaluatedAt,
    this.isAnswered = false,
    this.metadata = const {},
  });

  final String questionId;
  final String sessionId;
  final int orderIndex;
  final String prompt;
  final String difficulty;
  final String roleTrack;
  final String category;
  final List<String> expectedFocus;
  final String? candidateAnswer;
  final DateTime? answeredAt;
  final int timeSpentSeconds;
  final String? aiCritique;
  final double? scoreTechnical;
  final double? scoreCommunication;
  final double? scoreConfidence;
  final double? scoreProblemSolving;
  final double? scoreArchitecture;
  final double? scoreCodeQuality;
  final double? scoreOverall;
  final List<String> strengths;
  final List<String> weaknesses;
  final String? improvement;
  final Map<String, dynamic> evaluationBreakdown;
  final bool isFollowUp;
  final String? parentQuestionId;
  final bool isSkipped;
  final bool critiqueLocked;
  final int critiqueAttempts;
  final DateTime? evaluatedAt;
  final bool isAnswered;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory InterviewLabQuestionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabQuestionModel.fromMap(data, docId: doc.id);
  }

  factory InterviewLabQuestionModel.fromMap(
    Map<String, dynamic> data, {
    String? docId,
  }) {
    return InterviewLabQuestionModel(
      questionId: data['questionId']?.toString() ?? docId ?? '',
      sessionId: data['sessionId']?.toString() ?? '',
      orderIndex: _int(data['orderIndex']),
      prompt: data['prompt']?.toString() ?? '',
      difficulty: data['difficulty']?.toString() ?? 'medium',
      roleTrack: data['roleTrack']?.toString() ?? 'general',
      category: data['category']?.toString() ?? 'technical',
      expectedFocus: _strings(data['expectedFocus']),
      candidateAnswer: data['candidateAnswer']?.toString(),
      answeredAt:
          data['answeredAt'] != null ? _date(data['answeredAt']) : null,
      timeSpentSeconds: _int(data['timeSpentSeconds']),
      aiCritique: data['aiCritique']?.toString(),
      scoreTechnical: _nullableDouble(data['scoreTechnical']),
      scoreCommunication: _nullableDouble(data['scoreCommunication']),
      scoreConfidence: _nullableDouble(data['scoreConfidence']),
      scoreProblemSolving: _nullableDouble(data['scoreProblemSolving']),
      scoreArchitecture: _nullableDouble(data['scoreArchitecture']),
      scoreCodeQuality: _nullableDouble(data['scoreCodeQuality']),
      scoreOverall: _nullableDouble(data['scoreOverall']),
      strengths: _strings(data['strengths']),
      weaknesses: _strings(data['weaknesses']),
      improvement: data['improvement']?.toString(),
      evaluationBreakdown: Map<String, dynamic>.from(
        (data['evaluationBreakdown'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      isFollowUp: data['isFollowUp'] == true,
      parentQuestionId: data['parentQuestionId']?.toString(),
      isSkipped: data['isSkipped'] == true,
      critiqueLocked: data['critiqueLocked'] == true,
      critiqueAttempts: _int(data['critiqueAttempts']),
      evaluatedAt:
          data['evaluatedAt'] != null ? _date(data['evaluatedAt']) : null,
      isAnswered: data['isAnswered'] == true,
      createdAt: _date(data['createdAt']),
      metadata: Map<String, dynamic>.from(
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'questionId': questionId,
        'sessionId': sessionId,
        'orderIndex': orderIndex,
        'prompt': prompt,
        'difficulty': difficulty,
        'roleTrack': roleTrack,
        'category': category,
        'expectedFocus': expectedFocus,
        'candidateAnswer': candidateAnswer,
        'answeredAt': answeredAt == null ? null : Timestamp.fromDate(answeredAt!),
        'timeSpentSeconds': timeSpentSeconds,
        'aiCritique': aiCritique,
        'scoreTechnical': scoreTechnical,
        'scoreCommunication': scoreCommunication,
        'scoreConfidence': scoreConfidence,
        'scoreProblemSolving': scoreProblemSolving,
        'scoreArchitecture': scoreArchitecture,
        'scoreCodeQuality': scoreCodeQuality,
        'scoreOverall': scoreOverall,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'improvement': improvement,
        'evaluationBreakdown': evaluationBreakdown,
        'isFollowUp': isFollowUp,
        'parentQuestionId': parentQuestionId,
        'isSkipped': isSkipped,
        'critiqueLocked': critiqueLocked,
        'critiqueAttempts': critiqueAttempts,
        'evaluatedAt':
            evaluatedAt == null ? null : Timestamp.fromDate(evaluatedAt!),
        'isAnswered': isAnswered,
        'createdAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt),
        'updatedAt':
            useServerTimestamps ? FieldValue.serverTimestamp() : Timestamp.now(),
        'metadata': metadata,
        'module': 'interview_lab',
      };

  InterviewLabQuestionModel copyWith({
    String? prompt,
    String? difficulty,
    String? category,
    List<String>? expectedFocus,
    String? candidateAnswer,
    DateTime? answeredAt,
    int? timeSpentSeconds,
    String? aiCritique,
    double? scoreTechnical,
    double? scoreCommunication,
    double? scoreConfidence,
    double? scoreProblemSolving,
    double? scoreArchitecture,
    double? scoreCodeQuality,
    double? scoreOverall,
    List<String>? strengths,
    List<String>? weaknesses,
    String? improvement,
    Map<String, dynamic>? evaluationBreakdown,
    bool? isFollowUp,
    String? parentQuestionId,
    bool? isSkipped,
    bool? critiqueLocked,
    int? critiqueAttempts,
    DateTime? evaluatedAt,
    bool? isAnswered,
    Map<String, dynamic>? metadata,
    int? orderIndex,
  }) {
    return InterviewLabQuestionModel(
      questionId: questionId,
      sessionId: sessionId,
      orderIndex: orderIndex ?? this.orderIndex,
      prompt: prompt ?? this.prompt,
      difficulty: difficulty ?? this.difficulty,
      roleTrack: roleTrack,
      category: category ?? this.category,
      expectedFocus: expectedFocus ?? this.expectedFocus,
      candidateAnswer: candidateAnswer ?? this.candidateAnswer,
      answeredAt: answeredAt ?? this.answeredAt,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      aiCritique: aiCritique ?? this.aiCritique,
      scoreTechnical: scoreTechnical ?? this.scoreTechnical,
      scoreCommunication: scoreCommunication ?? this.scoreCommunication,
      scoreConfidence: scoreConfidence ?? this.scoreConfidence,
      scoreProblemSolving: scoreProblemSolving ?? this.scoreProblemSolving,
      scoreArchitecture: scoreArchitecture ?? this.scoreArchitecture,
      scoreCodeQuality: scoreCodeQuality ?? this.scoreCodeQuality,
      scoreOverall: scoreOverall ?? this.scoreOverall,
      strengths: strengths ?? this.strengths,
      weaknesses: weaknesses ?? this.weaknesses,
      improvement: improvement ?? this.improvement,
      evaluationBreakdown: evaluationBreakdown ?? this.evaluationBreakdown,
      isFollowUp: isFollowUp ?? this.isFollowUp,
      parentQuestionId: parentQuestionId ?? this.parentQuestionId,
      isSkipped: isSkipped ?? this.isSkipped,
      critiqueLocked: critiqueLocked ?? this.critiqueLocked,
      critiqueAttempts: critiqueAttempts ?? this.critiqueAttempts,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      isAnswered: isAnswered ?? this.isAnswered,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
