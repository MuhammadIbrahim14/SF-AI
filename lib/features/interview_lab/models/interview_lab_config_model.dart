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

/// Optional gates — soft unless enforced later.
class InterviewLabValidationRequirements {
  const InterviewLabValidationRequirements({
    this.resumeRequired = false,
    this.portfolioRequired = false,
    this.jobRequired = false,
  });

  final bool resumeRequired;
  final bool portfolioRequired;
  final bool jobRequired;

  factory InterviewLabValidationRequirements.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return InterviewLabValidationRequirements(
      resumeRequired: map['resumeRequired'] == true,
      portfolioRequired: map['portfolioRequired'] == true,
      jobRequired: map['jobRequired'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'resumeRequired': resumeRequired,
        'portfolioRequired': portfolioRequired,
        'jobRequired': jobRequired,
      };

  InterviewLabValidationRequirements copyWith({
    bool? resumeRequired,
    bool? portfolioRequired,
    bool? jobRequired,
  }) {
    return InterviewLabValidationRequirements(
      resumeRequired: resumeRequired ?? this.resumeRequired,
      portfolioRequired: portfolioRequired ?? this.portfolioRequired,
      jobRequired: jobRequired ?? this.jobRequired,
    );
  }
}

/// Admin-configurable Interview Lab settings (`settings/interviewLab`).
class InterviewLabConfigModel {
  const InterviewLabConfigModel({
    this.maxQuestions = 8,
    this.interviewTimeMinutes = 30,
    this.defaultDifficulty = InterviewLabDifficulty.medium,
    this.aiProvider = 'openai',
    this.retryLimits = 2,
    this.scoringRules = const InterviewLabScoringRules(),
    this.validation = const InterviewLabValidationRequirements(),
    this.enabled = true,
    this.adaptiveQuestioning = true,
    this.maxFollowUpQuestions = 3,
    this.evaluationStrictness = InterviewLabEvaluationStrictness.balanced,
    this.difficultyScaling = true,
    this.skipConfidencePenalty = 12,
    this.sessionLockEnabled = true,
    this.timerEnforced = true,
    this.answerRegenerateLimit = 0,
    this.updatedAt,
  });

  final int maxQuestions;
  final int interviewTimeMinutes;
  final String defaultDifficulty;
  final String aiProvider;
  final int retryLimits;
  final InterviewLabScoringRules scoringRules;
  final InterviewLabValidationRequirements validation;
  final bool enabled;

  /// Dynamically insert follow-ups / adjust difficulty mid-session.
  final bool adaptiveQuestioning;
  final int maxFollowUpQuestions;
  final String evaluationStrictness;
  final bool difficultyScaling;
  final double skipConfidencePenalty;
  final bool sessionLockEnabled;
  final bool timerEnforced;

  /// Max times a locked critique may be re-requested (0 = never).
  final int answerRegenerateLimit;
  final DateTime? updatedAt;

  static const InterviewLabConfigModel defaults = InterviewLabConfigModel();

  /// Alias for admin "passing score".
  double get passingScore => scoringRules.passThreshold;

  factory InterviewLabConfigModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabConfigModel.fromMap(data);
  }

  factory InterviewLabConfigModel.fromMap(Map<String, dynamic> data) {
    final strictness = data['evaluationStrictness']?.toString() ??
        InterviewLabEvaluationStrictness.balanced;
    return InterviewLabConfigModel(
      maxQuestions: _int(data['maxQuestions'], 8).clamp(1, 50),
      interviewTimeMinutes: _int(data['interviewTimeMinutes'], 30).clamp(5, 180),
      defaultDifficulty: InterviewLabDifficulty.isValid(
            data['defaultDifficulty']?.toString() ?? '',
          )
          ? data['defaultDifficulty'].toString()
          : InterviewLabDifficulty.medium,
      aiProvider: data['aiProvider']?.toString() ?? 'openai',
      retryLimits: _int(data['retryLimits'], 2).clamp(0, 10),
      scoringRules: InterviewLabScoringRules.fromMap(
        data['scoringRules'] as Map<String, dynamic>?,
      ),
      validation: InterviewLabValidationRequirements.fromMap(
        data['validation'] as Map<String, dynamic>?,
      ),
      enabled: data['enabled'] != false,
      adaptiveQuestioning: data['adaptiveQuestioning'] != false,
      maxFollowUpQuestions: _int(data['maxFollowUpQuestions'], 3).clamp(0, 8),
      evaluationStrictness:
          InterviewLabEvaluationStrictness.isValid(strictness)
              ? strictness
              : InterviewLabEvaluationStrictness.balanced,
      difficultyScaling: data['difficultyScaling'] != false,
      skipConfidencePenalty:
          _double(data['skipConfidencePenalty'], 12).clamp(0, 40),
      sessionLockEnabled: data['sessionLockEnabled'] != false,
      timerEnforced: data['timerEnforced'] != false,
      answerRegenerateLimit:
          _int(data['answerRegenerateLimit'], 0).clamp(0, 3),
      updatedAt: data['updatedAt'] != null ? _date(data['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'maxQuestions': maxQuestions,
        'interviewTimeMinutes': interviewTimeMinutes,
        'defaultDifficulty': defaultDifficulty,
        'aiProvider': aiProvider,
        'retryLimits': retryLimits,
        'scoringRules': scoringRules.toMap(),
        'validation': validation.toMap(),
        'enabled': enabled,
        'adaptiveQuestioning': adaptiveQuestioning,
        'maxFollowUpQuestions': maxFollowUpQuestions,
        'evaluationStrictness': evaluationStrictness,
        'difficultyScaling': difficultyScaling,
        'skipConfidencePenalty': skipConfidencePenalty,
        'sessionLockEnabled': sessionLockEnabled,
        'timerEnforced': timerEnforced,
        'answerRegenerateLimit': answerRegenerateLimit,
        'passingScore': scoringRules.passThreshold,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  InterviewLabConfigModel copyWith({
    int? maxQuestions,
    int? interviewTimeMinutes,
    String? defaultDifficulty,
    String? aiProvider,
    int? retryLimits,
    InterviewLabScoringRules? scoringRules,
    InterviewLabValidationRequirements? validation,
    bool? enabled,
    bool? adaptiveQuestioning,
    int? maxFollowUpQuestions,
    String? evaluationStrictness,
    bool? difficultyScaling,
    double? skipConfidencePenalty,
    bool? sessionLockEnabled,
    bool? timerEnforced,
    int? answerRegenerateLimit,
    DateTime? updatedAt,
  }) {
    return InterviewLabConfigModel(
      maxQuestions: maxQuestions ?? this.maxQuestions,
      interviewTimeMinutes: interviewTimeMinutes ?? this.interviewTimeMinutes,
      defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
      aiProvider: aiProvider ?? this.aiProvider,
      retryLimits: retryLimits ?? this.retryLimits,
      scoringRules: scoringRules ?? this.scoringRules,
      validation: validation ?? this.validation,
      enabled: enabled ?? this.enabled,
      adaptiveQuestioning: adaptiveQuestioning ?? this.adaptiveQuestioning,
      maxFollowUpQuestions: maxFollowUpQuestions ?? this.maxFollowUpQuestions,
      evaluationStrictness: evaluationStrictness ?? this.evaluationStrictness,
      difficultyScaling: difficultyScaling ?? this.difficultyScaling,
      skipConfidencePenalty:
          skipConfidencePenalty ?? this.skipConfidencePenalty,
      sessionLockEnabled: sessionLockEnabled ?? this.sessionLockEnabled,
      timerEnforced: timerEnforced ?? this.timerEnforced,
      answerRegenerateLimit:
          answerRegenerateLimit ?? this.answerRegenerateLimit,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class InterviewLabScoringRules {
  const InterviewLabScoringRules({
    this.technicalWeight = 0.28,
    this.communicationWeight = 0.14,
    this.confidenceWeight = 0.10,
    this.problemSolvingWeight = 0.16,
    this.professionalismWeight = 0.08,
    this.architectureWeight = 0.12,
    this.codeQualityWeight = 0.12,
    this.passThreshold = 75,
    this.holdThreshold = 50,
  });

  final double technicalWeight;
  final double communicationWeight;
  final double confidenceWeight;
  final double problemSolvingWeight;
  final double professionalismWeight;
  final double architectureWeight;
  final double codeQualityWeight;
  final double passThreshold;
  final double holdThreshold;

  factory InterviewLabScoringRules.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return InterviewLabScoringRules(
      technicalWeight: _double(map['technicalWeight'], 0.28),
      communicationWeight: _double(map['communicationWeight'], 0.14),
      confidenceWeight: _double(map['confidenceWeight'], 0.10),
      problemSolvingWeight: _double(map['problemSolvingWeight'], 0.16),
      professionalismWeight: _double(map['professionalismWeight'], 0.08),
      architectureWeight: _double(map['architectureWeight'], 0.12),
      codeQualityWeight: _double(map['codeQualityWeight'], 0.12),
      passThreshold: _double(map['passThreshold'], 75),
      holdThreshold: _double(map['holdThreshold'], 50),
    );
  }

  Map<String, dynamic> toMap() => {
        'technicalWeight': technicalWeight,
        'communicationWeight': communicationWeight,
        'confidenceWeight': confidenceWeight,
        'problemSolvingWeight': problemSolvingWeight,
        'professionalismWeight': professionalismWeight,
        'architectureWeight': architectureWeight,
        'codeQualityWeight': codeQualityWeight,
        'passThreshold': passThreshold,
        'holdThreshold': holdThreshold,
      };

  InterviewLabScoringRules copyWith({
    double? technicalWeight,
    double? communicationWeight,
    double? confidenceWeight,
    double? problemSolvingWeight,
    double? professionalismWeight,
    double? architectureWeight,
    double? codeQualityWeight,
    double? passThreshold,
    double? holdThreshold,
  }) {
    return InterviewLabScoringRules(
      technicalWeight: technicalWeight ?? this.technicalWeight,
      communicationWeight: communicationWeight ?? this.communicationWeight,
      confidenceWeight: confidenceWeight ?? this.confidenceWeight,
      problemSolvingWeight: problemSolvingWeight ?? this.problemSolvingWeight,
      professionalismWeight:
          professionalismWeight ?? this.professionalismWeight,
      architectureWeight: architectureWeight ?? this.architectureWeight,
      codeQualityWeight: codeQualityWeight ?? this.codeQualityWeight,
      passThreshold: passThreshold ?? this.passThreshold,
      holdThreshold: holdThreshold ?? this.holdThreshold,
    );
  }

  double computeOverall({
    required double technical,
    required double communication,
    required double confidence,
    required double problemSolving,
    required double professionalism,
    double architecture = 0,
    double codeQuality = 0,
  }) {
    final arch = architecture > 0 ? architecture : technical;
    final code = codeQuality > 0 ? codeQuality : technical;
    final raw = technical * technicalWeight +
        communication * communicationWeight +
        confidence * confidenceWeight +
        problemSolving * problemSolvingWeight +
        professionalism * professionalismWeight +
        arch * architectureWeight +
        code * codeQualityWeight;
    return (raw * 100).round() / 100;
  }
}
