class AiCourseRequirementModel {
  const AiCourseRequirementModel({
    required this.topic,
    required this.targetAudience,
    required this.level,
    required this.durationWeeks,
    required this.languageStyle,
    required this.learningGoals,
    required this.includeAssignments,
    required this.includeQuizzes,
    required this.includeGrandTest,
    required this.extraInstructions,
    this.moduleCount = 4,
    this.totalLessonCount = 8,
    this.useCustomLessonDistribution = false,
    this.lessonCountPerModule = const <int>[],
    this.assignmentCount = 4,
    this.defaultQuestionsPerAssignment = 5,
    this.useCustomAssignmentQuestionCounts = false,
    this.assignmentQuestionCounts = const <int>[],
    this.assignmentType = 'mixed',
    this.quizCount = 4,
    this.defaultQuestionsPerQuiz = 5,
    this.useCustomQuizQuestionCounts = false,
    this.quizQuestionCounts = const <int>[],
    this.grandTestCount = 1,
    this.defaultQuestionsPerGrandTest = 20,
    this.useCustomGrandTestQuestionCounts = false,
    this.grandTestQuestionCounts = const <int>[],
    this.difficultyLevel = 'beginner',
    this.contentDepth = 'normal',
    this.avoidDuplicateQuestions = true,
    this.requireUniqueLessons = true,
  });

  final String topic;
  final String targetAudience;
  final String level;
  final int durationWeeks;
  final String languageStyle;
  final String learningGoals;
  final bool includeAssignments;
  final bool includeQuizzes;
  final bool includeGrandTest;
  final String extraInstructions;
  final int moduleCount;
  final int totalLessonCount;
  final bool useCustomLessonDistribution;
  final List<int> lessonCountPerModule;
  final int assignmentCount;
  final int defaultQuestionsPerAssignment;
  final bool useCustomAssignmentQuestionCounts;
  final List<int> assignmentQuestionCounts;
  final String assignmentType;
  final int quizCount;
  final int defaultQuestionsPerQuiz;
  final bool useCustomQuizQuestionCounts;
  final List<int> quizQuestionCounts;
  final int grandTestCount;
  final int defaultQuestionsPerGrandTest;
  final bool useCustomGrandTestQuestionCounts;
  final List<int> grandTestQuestionCounts;
  final String difficultyLevel;
  final String contentDepth;
  final bool avoidDuplicateQuestions;
  final bool requireUniqueLessons;

  int get effectiveAssignmentCount =>
      includeAssignments ? assignmentCount.clamp(0, 40).toInt() : 0;

  int get effectiveQuizCount =>
      includeQuizzes ? quizCount.clamp(0, 40).toInt() : 0;

  int get effectiveGrandTestCount =>
      includeGrandTest ? grandTestCount.clamp(0, 5).toInt() : 0;

  List<int> get effectiveLessonDistribution {
    final modules = moduleCount.clamp(1, 12).toInt();
    if (useCustomLessonDistribution &&
        lessonCountPerModule.length == modules &&
        lessonCountPerModule.fold<int>(0, (sum, value) => sum + value) ==
            totalLessonCount) {
      return lessonCountPerModule;
    }
    final base = totalLessonCount ~/ modules;
    var remainder = totalLessonCount % modules;
    return List<int>.generate(modules, (_) {
      final value = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      return value;
    });
  }

  List<int> get effectiveAssignmentQuestionCounts {
    return _counts(
      enabled: includeAssignments,
      count: effectiveAssignmentCount,
      custom: useCustomAssignmentQuestionCounts,
      customCounts: assignmentQuestionCounts,
      fallback: defaultQuestionsPerAssignment,
      min: 1,
      max: 50,
    );
  }

  List<int> get effectiveQuizQuestionCounts {
    return _counts(
      enabled: includeQuizzes,
      count: effectiveQuizCount,
      custom: useCustomQuizQuestionCounts,
      customCounts: quizQuestionCounts,
      fallback: defaultQuestionsPerQuiz,
      min: 1,
      max: 50,
    );
  }

  List<int> get effectiveGrandTestQuestionCounts {
    return _counts(
      enabled: includeGrandTest,
      count: effectiveGrandTestCount,
      custom: useCustomGrandTestQuestionCounts,
      customCounts: grandTestQuestionCounts,
      fallback: defaultQuestionsPerGrandTest,
      min: 5,
      max: 100,
    );
  }

  int get expectedAssignmentQuestionTotal =>
      effectiveAssignmentQuestionCounts.fold(0, (sum, value) => sum + value);

  int get expectedQuizQuestionTotal =>
      effectiveQuizQuestionCounts.fold(0, (sum, value) => sum + value);

  int get expectedGrandTestQuestionTotal =>
      effectiveGrandTestQuestionCounts.fold(0, (sum, value) => sum + value);

  String get estimateSummary {
    return 'This will generate $moduleCount modules, $totalLessonCount lessons, '
        '$effectiveAssignmentCount assignments, $expectedAssignmentQuestionTotal assignment questions, '
        '$effectiveQuizCount quizzes, $expectedQuizQuestionTotal quiz questions, '
        '$effectiveGrandTestCount grand test${effectiveGrandTestCount == 1 ? '' : 's'} '
        'with $expectedGrandTestQuestionTotal questions.';
  }

  List<String> validate() {
    final errors = <String>[];
    if (moduleCount < 1 || moduleCount > 12) {
      errors.add('Module count must be between 1 and 12.');
    }
    if (totalLessonCount < moduleCount || totalLessonCount > 60) {
      errors.add('Total lessons must be between module count and 60.');
    }
    if (useCustomLessonDistribution) {
      if (lessonCountPerModule.length != moduleCount) {
        errors.add('Lesson distribution must include one value per module.');
      } else if (lessonCountPerModule.any((value) => value < 1)) {
        errors.add('Each module needs at least one lesson.');
      } else if (lessonCountPerModule.fold<int>(0, (sum, v) => sum + v) !=
          totalLessonCount) {
        errors.add('Custom lesson distribution must equal total lessons.');
      }
    }
    _validateCount(
      errors,
      name: 'Assignment count',
      value: assignmentCount,
      min: 0,
      max: 40,
    );
    _validateCount(
      errors,
      name: 'Questions per assignment',
      value: defaultQuestionsPerAssignment,
      min: 1,
      max: 50,
    );
    _validateCustom(
      errors,
      enabled: includeAssignments && useCustomAssignmentQuestionCounts,
      name: 'assignment question counts',
      expectedLength: assignmentCount,
      values: assignmentQuestionCounts,
      min: 1,
      max: 50,
    );
    _validateCount(
      errors,
      name: 'Quiz count',
      value: quizCount,
      min: 0,
      max: 40,
    );
    _validateCount(
      errors,
      name: 'Questions per quiz',
      value: defaultQuestionsPerQuiz,
      min: 1,
      max: 50,
    );
    _validateCustom(
      errors,
      enabled: includeQuizzes && useCustomQuizQuestionCounts,
      name: 'quiz question counts',
      expectedLength: quizCount,
      values: quizQuestionCounts,
      min: 1,
      max: 50,
    );
    _validateCount(
      errors,
      name: 'Grand test count',
      value: grandTestCount,
      min: 0,
      max: 5,
    );
    _validateCount(
      errors,
      name: 'Questions per grand test',
      value: defaultQuestionsPerGrandTest,
      min: 5,
      max: 100,
    );
    _validateCustom(
      errors,
      enabled: includeGrandTest && useCustomGrandTestQuestionCounts,
      name: 'grand test question counts',
      expectedLength: grandTestCount,
      values: grandTestQuestionCounts,
      min: 5,
      max: 100,
    );
    if (!const {
      'mcq',
      'written',
      'practical',
      'mixed',
    }.contains(assignmentType)) {
      errors.add('Assignment type must be mcq, written, practical, or mixed.');
    }
    if (!const {
      'beginner',
      'intermediate',
      'advanced',
    }.contains(difficultyLevel)) {
      errors.add('Difficulty must be beginner, intermediate, or advanced.');
    }
    if (!const {'english', 'romanUrdu', 'mixed'}.contains(languageStyle)) {
      errors.add('Language style must be english, romanUrdu, or mixed.');
    }
    if (!const {'short', 'normal', 'detailed'}.contains(contentDepth)) {
      errors.add('Content depth must be short, normal, or detailed.');
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'targetAudience': targetAudience,
    'level': level,
    'durationWeeks': durationWeeks,
    'languageStyle': languageStyle,
    'learningGoals': learningGoals,
    'includeAssignments': includeAssignments,
    'includeQuizzes': includeQuizzes,
    'includeGrandTest': includeGrandTest,
    'extraInstructions': extraInstructions,
    'moduleCount': moduleCount,
    'totalLessonCount': totalLessonCount,
    'lessonCountPerModule': effectiveLessonDistribution,
    'assignmentCount': effectiveAssignmentCount,
    'assignmentQuestionCounts': effectiveAssignmentQuestionCounts,
    'assignmentType': assignmentType,
    'quizCount': effectiveQuizCount,
    'quizQuestionCounts': effectiveQuizQuestionCounts,
    'grandTestCount': effectiveGrandTestCount,
    'grandTestQuestionCounts': effectiveGrandTestQuestionCounts,
    'difficultyLevel': difficultyLevel,
    'contentDepth': contentDepth,
    'avoidDuplicateQuestions': avoidDuplicateQuestions,
    'requireUniqueLessons': requireUniqueLessons,
  };
}

List<int> _counts({
  required bool enabled,
  required int count,
  required bool custom,
  required List<int> customCounts,
  required int fallback,
  required int min,
  required int max,
}) {
  if (!enabled || count <= 0) return const <int>[];
  if (custom && customCounts.length == count) {
    return customCounts.map((value) => value.clamp(min, max).toInt()).toList();
  }
  return List<int>.filled(count, fallback.clamp(min, max).toInt());
}

void _validateCount(
  List<String> errors, {
  required String name,
  required int value,
  required int min,
  required int max,
}) {
  if (value < min || value > max) {
    errors.add('$name must be between $min and $max.');
  }
}

void _validateCustom(
  List<String> errors, {
  required bool enabled,
  required String name,
  required int expectedLength,
  required List<int> values,
  required int min,
  required int max,
}) {
  if (!enabled) return;
  if (values.length != expectedLength) {
    errors.add('Custom $name must include $expectedLength values.');
    return;
  }
  if (values.any((value) => value < min || value > max)) {
    errors.add('Each custom $name value must be between $min and $max.');
  }
}
