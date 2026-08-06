class StudentAiTutorTaskType {
  const StudentAiTutorTaskType._();

  static const tutorChat = 'studentTutorChat';
  static const lessonExplain = 'studentLessonExplain';
  static const lessonSummary = 'studentLessonSummary';
  static const practiceQuestions = 'studentPracticeQuestions';
  static const quizReview = 'studentQuizReview';
  static const revisionPlan = 'studentRevisionPlan';
  static const conceptSimplifier = 'studentConceptSimplifier';
}

class StudentAiTutorContextModel {
  const StudentAiTutorContextModel({
    required this.studentId,
    this.courseId,
    this.courseTitle,
    this.lessonId,
    this.lessonTitle,
    this.lessonContentSummary,
    this.currentTopic,
    this.assignmentId,
    this.quizId,
    this.grandTestId,
    this.attemptId,
    this.recentScore,
    this.weakTopics = const <String>[],
    this.completedLessons = const <String>[],
    this.pendingAssignments = const <String>[],
    this.upcomingTests = const <String>[],
    this.languagePreference = 'mixed',
    this.difficultyLevel = 'beginner',
    this.mode = 'learning',
  });

  final String studentId;
  final String? courseId;
  final String? courseTitle;
  final String? lessonId;
  final String? lessonTitle;
  final String? lessonContentSummary;
  final String? currentTopic;
  final String? assignmentId;
  final String? quizId;
  final String? grandTestId;
  final String? attemptId;
  final num? recentScore;
  final List<String> weakTopics;
  final List<String> completedLessons;
  final List<String> pendingAssignments;
  final List<String> upcomingTests;
  final String languagePreference;
  final String difficultyLevel;
  final String mode;

  Map<String, dynamic> toSafeMap() {
    return {
      'studentId': studentId,
      if ((courseId ?? '').trim().isNotEmpty) 'courseId': courseId,
      if ((courseTitle ?? '').trim().isNotEmpty) 'courseTitle': courseTitle,
      if ((lessonId ?? '').trim().isNotEmpty) 'lessonId': lessonId,
      if ((lessonTitle ?? '').trim().isNotEmpty) 'lessonTitle': lessonTitle,
      if ((lessonContentSummary ?? '').trim().isNotEmpty)
        'lessonContentSummary': lessonContentSummary,
      if ((currentTopic ?? '').trim().isNotEmpty) 'currentTopic': currentTopic,
      if ((assignmentId ?? '').trim().isNotEmpty) 'assignmentId': assignmentId,
      if ((quizId ?? '').trim().isNotEmpty) 'quizId': quizId,
      if ((grandTestId ?? '').trim().isNotEmpty) 'grandTestId': grandTestId,
      if ((attemptId ?? '').trim().isNotEmpty) 'attemptId': attemptId,
      if (recentScore != null) 'recentScore': recentScore,
      'weakTopics': weakTopics.take(12).toList(),
      'completedLessons': completedLessons.take(12).toList(),
      'pendingAssignments': pendingAssignments.take(12).toList(),
      'upcomingTests': upcomingTests.take(8).toList(),
      'languagePreference': languagePreference,
      'difficultyLevel': difficultyLevel,
      'mode': mode,
    };
  }
}

class StudentPracticeQuestionModel {
  const StudentPracticeQuestionModel({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    required this.topicTag,
  });

  factory StudentPracticeQuestionModel.fromMap(Map<String, dynamic> map) {
    final options = map['options'] is Iterable
        ? (map['options'] as Iterable)
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];
    return StudentPracticeQuestionModel(
      question: map['question']?.toString().trim() ?? 'Practice question',
      options: options.take(4).toList(),
      correctAnswer: map['correctAnswer']?.toString().trim() ?? '',
      explanation: map['explanation']?.toString().trim() ?? '',
      difficulty: map['difficulty']?.toString().trim() ?? 'beginner',
      topicTag: map['topicTag']?.toString().trim() ?? '',
    );
  }

  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String difficulty;
  final String topicTag;
}

class StudentAiTutorResponseModel {
  const StudentAiTutorResponseModel({
    required this.title,
    required this.answer,
    required this.sourceProvider,
    required this.isFallback,
    required this.isRepaired,
    this.model,
    this.totalTokens,
    this.creditCost = 0,
    this.explanationSteps = const <String>[],
    this.examples = const <String>[],
    this.practiceQuestions = const <StudentPracticeQuestionModel>[],
    this.hints = const <String>[],
    this.revisionPlan = const <String>[],
    this.safetyNotes = const <String>[],
    this.suggestedNextActions = const <String>[],
    this.qualityWarnings = const <String>[],
  });

  final String title;
  final String answer;
  final String sourceProvider;
  final bool isFallback;
  final bool isRepaired;
  final String? model;
  final int? totalTokens;
  final int creditCost;
  final List<String> explanationSteps;
  final List<String> examples;
  final List<StudentPracticeQuestionModel> practiceQuestions;
  final List<String> hints;
  final List<String> revisionPlan;
  final List<String> safetyNotes;
  final List<String> suggestedNextActions;
  final List<String> qualityWarnings;

  bool get isUnavailable {
    final source = sourceProvider.trim();
    return source == 'aiUnavailable' ||
        source == 'gatewayUnreachable' ||
        source == 'providerError' ||
        source == 'quotaBlocked' ||
        source == 'roleNotAllowed' ||
        qualityWarnings.any(
          (item) =>
              item == 'aiUnavailable' ||
              item == 'gatewayUnreachable' ||
              item == 'providerError' ||
              item == 'quotaBlocked' ||
              item == 'roleNotAllowed',
        );
  }

  Map<String, dynamic> toStructuredMap() {
    return {
      'title': title,
      'answer': answer,
      'sourceProvider': sourceProvider,
      'isFallback': false,
      'isRepaired': isRepaired,
      if ((model ?? '').trim().isNotEmpty) 'model': model,
      if (totalTokens != null) 'totalTokens': totalTokens,
      'creditCost': creditCost,
      'explanationSteps': explanationSteps,
      'examples': examples,
      'practiceQuestions': practiceQuestions
          .map(
            (question) => {
              'question': question.question,
              'options': question.options,
              'correctAnswer': question.correctAnswer,
              'explanation': question.explanation,
              'difficulty': question.difficulty,
              'topicTag': question.topicTag,
            },
          )
          .toList(),
      'hints': hints,
      'revisionPlan': revisionPlan,
      'safetyNotes': safetyNotes,
      'suggestedNextActions': suggestedNextActions,
      'qualityWarnings': qualityWarnings,
    };
  }

  factory StudentAiTutorResponseModel.fromStructuredMap(
    Map<String, dynamic> map, {
    String? fallbackContent,
  }) {
    final title = _text(map['title']);
    final answer = _text(map['answer']);
    final sourceProvider = _text(map['sourceProvider']) ?? _text(map['source']);
    return StudentAiTutorResponseModel(
      title: title ?? 'SkillForge AI Tutor',
      answer: answer ?? (fallbackContent ?? ''),
      sourceProvider: sourceProvider ?? 'openai',
      isFallback: false,
      isRepaired: map['isRepaired'] == true,
      model: map['model']?.toString(),
      totalTokens: _int(map['totalTokens']),
      creditCost: _int(map['creditCost']) ?? 0,
      explanationSteps: _stringList(map['explanationSteps']),
      examples: _stringList(map['examples']),
      practiceQuestions: _questions(map['practiceQuestions']),
      hints: _stringList(map['hints']),
      revisionPlan: _stringList(map['revisionPlan']),
      safetyNotes: _stringList(map['safetyNotes']),
      suggestedNextActions: _stringList(map['suggestedNextActions']),
      qualityWarnings: _stringList(map['qualityWarnings']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const <String>[];
  }

  static List<StudentPracticeQuestionModel> _questions(Object? value) {
    if (value is! Iterable) return const <StudentPracticeQuestionModel>[];
    return value
        .whereType<Map>()
        .map(
          (item) => StudentPracticeQuestionModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class StudentAiTutorMessageModel {
  const StudentAiTutorMessageModel({
    required this.text,
    required this.isStudent,
    this.response,
  });

  final String text;
  final bool isStudent;
  final StudentAiTutorResponseModel? response;
}
