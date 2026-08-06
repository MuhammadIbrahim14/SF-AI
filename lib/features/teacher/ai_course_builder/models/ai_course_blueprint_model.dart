class AiCourseBlueprintModel {
  const AiCourseBlueprintModel({
    required this.title,
    required this.description,
    required this.targetAudience,
    required this.level,
    required this.durationWeeks,
    required this.estimatedHours,
    required this.prerequisites,
    required this.learningOutcomes,
    required this.modules,
    required this.grandTest,
    List<AiGrandTestBlueprintModel>? grandTests,
    required this.certificateCriteria,
    required this.gradingRubric,
    required this.languageStyle,
    required this.generatedBy,
    required this.generatedAt,
    required this.source,
    this.contentSource,
    required this.isFallback,
    this.fallbackReason,
    this.gatewayStatusMessage,
    this.qualityWarnings = const <String>[],
    this.repairedItemCount = 0,
    this.fallbackItemCount = 0,
    this.parseWarning,
    this.aiModel,
    this.totalTokens,
    this.subtitle,
  }) : grandTests = grandTests ?? const <AiGrandTestBlueprintModel>[];

  final String title;
  final String? subtitle;
  final String description;
  final String targetAudience;
  final String level;
  final int durationWeeks;
  final int estimatedHours;
  final List<String> prerequisites;
  final List<String> learningOutcomes;
  final List<AiCourseModuleBlueprintModel> modules;
  final AiGrandTestBlueprintModel grandTest;
  final List<AiGrandTestBlueprintModel> grandTests;
  final List<String> certificateCriteria;
  final List<String> gradingRubric;
  final String languageStyle;
  final String generatedBy;
  final DateTime generatedAt;
  final String source;
  final String? contentSource;
  final bool isFallback;
  final String? fallbackReason;
  final String? gatewayStatusMessage;
  final List<String> qualityWarnings;
  final int repairedItemCount;
  final int fallbackItemCount;
  final String? parseWarning;
  final String? aiModel;
  final int? totalTokens;

  String get sourceProvider {
    final normalized = source.trim().toLowerCase();
    if (normalized.contains('parsefailed') || normalized.contains('template')) {
      return 'aiUnavailable';
    }
    if (normalized.contains('openai')) return 'openai';
    if (normalized.contains('gemini')) return 'gemini';
    if (normalized.contains('mock')) return 'aiUnavailable';
    return isFallback ? 'aiUnavailable' : normalized;
  }

  bool get isRealAiGenerated =>
      (sourceProvider == 'openai' || sourceProvider == 'gemini') &&
      normalizedContentSource != 'aiUnavailable' &&
      normalizedContentSource != 'validationFailed';

  String get normalizedContentSource {
    final clean = (contentSource ?? '').trim();
    if (clean.isNotEmpty) return clean;
    if (sourceProvider == 'templateFallback') return 'aiUnavailable';
    if (repairedItemCount > 0 || fallbackItemCount > 0) {
      return '${sourceProvider}WithRepair';
    }
    return sourceProvider;
  }

  String get sourceLabel {
    return switch (normalizedContentSource) {
      'openai' => 'Generated with OpenAI',
      'gemini' => 'Generated with Gemini',
      'openaiWithRepair' => 'OpenAI + Repair',
      'geminiWithRepair' => 'Gemini + Repair',
      'parseFailedTemplateFallback' => 'Validation Failed',
      'templateFallback' => 'AI Unavailable',
      'aiUnavailable' => 'AI Unavailable',
      'gatewayUnreachable' => 'Gateway Unreachable',
      'providerError' => 'Provider Error',
      _ =>
        sourceProvider == 'openai'
            ? 'Generated with OpenAI'
            : sourceProvider == 'gemini'
            ? 'Generated with Gemini'
            : 'AI Unavailable',
    };
  }

  int get totalLessonCount =>
      modules.fold(0, (sum, module) => sum + module.lessons.length);
  int get totalDurationMinutes =>
      modules.fold(0, (sum, module) => sum + module.durationMinutes);
  int get totalAssignmentCount =>
      modules.fold(0, (sum, module) => sum + module.assignments.length);
  int get totalAssignmentQuestionCount => modules.fold(
    0,
    (sum, module) =>
        sum +
        module.assignments.fold(
          0,
          (assignmentSum, assignment) =>
              assignmentSum + assignment.questions.length,
        ),
  );
  int get totalQuizCount =>
      modules.where((module) => module.quiz.questions.isNotEmpty).length;
  int get totalQuizQuestionCount =>
      modules.fold(0, (sum, module) => sum + module.quiz.questions.length);
  List<AiGrandTestBlueprintModel> get effectiveGrandTests =>
      grandTests.isNotEmpty
      ? grandTests
      : grandTest.questions.isNotEmpty || grandTest.totalPoints > 0
      ? [grandTest]
      : const <AiGrandTestBlueprintModel>[];
  int get totalGrandTestQuestionCount =>
      effectiveGrandTests.fold(0, (sum, test) => sum + test.questions.length);

  AiCourseBlueprintModel copyWith({
    String? title,
    String? subtitle,
    String? description,
  }) {
    return AiCourseBlueprintModel(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      targetAudience: targetAudience,
      level: level,
      durationWeeks: durationWeeks,
      estimatedHours: estimatedHours,
      prerequisites: prerequisites,
      learningOutcomes: learningOutcomes,
      modules: modules,
      grandTest: grandTest,
      grandTests: grandTests,
      certificateCriteria: certificateCriteria,
      gradingRubric: gradingRubric,
      languageStyle: languageStyle,
      generatedBy: generatedBy,
      generatedAt: generatedAt,
      source: source,
      contentSource: contentSource,
      isFallback: isFallback,
      fallbackReason: fallbackReason,
      gatewayStatusMessage: gatewayStatusMessage,
      qualityWarnings: qualityWarnings,
      repairedItemCount: repairedItemCount,
      fallbackItemCount: fallbackItemCount,
      parseWarning: parseWarning,
      aiModel: aiModel,
      totalTokens: totalTokens,
    );
  }

  factory AiCourseBlueprintModel.fromGatewayStructuredData(
    Map<String, dynamic> data, {
    required String source,
    required bool isFallback,
    required String languageStyle,
    Map<String, dynamic>? usage,
  }) {
    final normalized = _normalizeGatewayBlueprint(data);
    return AiCourseBlueprintModel.fromJson(
      normalized,
      source: source,
      isFallback: isFallback,
      languageStyle: languageStyle,
      contentSource: _sourceContent(source, isFallback),
      aiModel: usage?['model']?.toString(),
      totalTokens: _intOrNull(usage?['totalTokens']),
    );
  }

  factory AiCourseBlueprintModel.fromJson(
    Map<String, dynamic> json, {
    required String source,
    required bool isFallback,
    required String languageStyle,
    String? contentSource,
    int repairedItemCount = 0,
    int fallbackItemCount = 0,
    String? parseWarning,
    String? aiModel,
    int? totalTokens,
  }) {
    final modules = _list(json['modules'])
        .whereType<Map>()
        .map(
          (item) => AiCourseModuleBlueprintModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((module) => module.lessons.isNotEmpty)
        .toList();
    final grandTest = AiGrandTestBlueprintModel.fromJson(
      _map(json['grandTest']),
    );
    final grandTests = _list(json['grandTests'])
        .whereType<Map>()
        .map(
          (item) => AiGrandTestBlueprintModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((test) => test.questions.isNotEmpty || test.totalPoints > 0)
        .toList();
    return AiCourseBlueprintModel(
      title: _text(json['title'], 'AI Generated Course'),
      subtitle: _text(json['subtitle'], ''),
      description: _text(json['description'], 'Review and refine this course.'),
      targetAudience: _text(json['targetAudience'], 'SkillForge learners'),
      level: _text(json['level'], 'Beginner'),
      durationWeeks: _int(json['durationWeeks'], 4),
      estimatedHours: _int(json['estimatedHours'], 24),
      prerequisites: _strings(json['prerequisites']),
      learningOutcomes: _strings(json['learningOutcomes']),
      modules: modules,
      grandTest: grandTests.isNotEmpty ? grandTests.first : grandTest,
      grandTests: grandTests.isNotEmpty ? grandTests : [grandTest],
      certificateCriteria: _strings(json['certificateCriteria']),
      gradingRubric: _strings(json['gradingRubric']),
      languageStyle: languageStyle,
      generatedBy: 'SkillForge AI',
      generatedAt: DateTime.now(),
      source: source,
      contentSource: contentSource,
      isFallback: isFallback,
      fallbackReason: isFallback ? _text(json['fallbackReason'], '') : null,
      gatewayStatusMessage: _text(json['gatewayStatusMessage'], ''),
      qualityWarnings: _strings(json['qualityWarnings']),
      repairedItemCount: repairedItemCount,
      fallbackItemCount: fallbackItemCount,
      parseWarning: parseWarning,
      aiModel: aiModel,
      totalTokens: totalTokens,
    );
  }
}

class AiCourseModuleBlueprintModel {
  const AiCourseModuleBlueprintModel({
    required this.title,
    required this.description,
    required this.order,
    required this.lessons,
    required this.assignments,
    required this.quiz,
  });

  final String title;
  final String description;
  final int order;
  final List<AiLessonBlueprintModel> lessons;
  final List<AiAssignmentBlueprintModel> assignments;
  final AiQuizBlueprintModel quiz;

  int get durationMinutes =>
      lessons.fold(0, (sum, lesson) => sum + lesson.durationMinutes);

  factory AiCourseModuleBlueprintModel.fromJson(Map<String, dynamic> json) {
    return AiCourseModuleBlueprintModel(
      title: _text(json['title'], 'Module'),
      description: _text(json['description'], ''),
      order: _int(json['order'], 1),
      lessons: _list(json['lessons'])
          .whereType<Map>()
          .map(
            (item) => AiLessonBlueprintModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      assignments: _list(json['assignments'])
          .whereType<Map>()
          .map(
            (item) => AiAssignmentBlueprintModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      quiz: AiQuizBlueprintModel.fromJson(_map(json['quiz'])),
    );
  }
}

class AiLessonBlueprintModel {
  const AiLessonBlueprintModel({
    required this.title,
    required this.objective,
    required this.summary,
    required this.contentOutline,
    required this.examples,
    required this.practiceTasks,
    required this.durationMinutes,
    required this.order,
  });

  final String title;
  final String objective;
  final String summary;
  final List<String> contentOutline;
  final List<String> examples;
  final List<String> practiceTasks;
  final int durationMinutes;
  final int order;

  factory AiLessonBlueprintModel.fromJson(Map<String, dynamic> json) {
    return AiLessonBlueprintModel(
      title: _text(json['title'], 'Lesson'),
      objective: _text(json['objective'], ''),
      summary: _text(json['summary'], ''),
      contentOutline: _strings(json['contentOutline']),
      examples: _strings(json['examples']),
      practiceTasks: _strings(json['practiceTasks']),
      durationMinutes: _int(json['durationMinutes'], 45),
      order: _int(json['order'], 1),
    );
  }
}

class AiAssignmentBlueprintModel {
  const AiAssignmentBlueprintModel({
    required this.title,
    required this.instructions,
    required this.submissionType,
    required this.rubric,
    this.questions = const <AiQuizQuestionBlueprintModel>[],
    required this.dueOffsetDays,
    required this.points,
  });

  final String title;
  final String instructions;
  final String submissionType;
  final List<String> rubric;
  final List<AiQuizQuestionBlueprintModel> questions;
  final int dueOffsetDays;
  final int points;

  factory AiAssignmentBlueprintModel.fromJson(Map<String, dynamic> json) {
    return AiAssignmentBlueprintModel(
      title: _text(json['title'], 'Assignment'),
      instructions: _text(json['instructions'], ''),
      submissionType: _text(json['submissionType'], 'project'),
      rubric: _strings(json['rubric']),
      questions: _list(json['questions'])
          .whereType<Map>()
          .map(
            (item) => AiQuizQuestionBlueprintModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      dueOffsetDays: _int(json['dueOffsetDays'], 7),
      points: _int(json['points'], 100),
    );
  }
}

class AiQuizBlueprintModel {
  const AiQuizBlueprintModel({
    required this.title,
    required this.questions,
    required this.passingScore,
    required this.points,
  });

  final String title;
  final List<AiQuizQuestionBlueprintModel> questions;
  final int passingScore;
  final int points;

  factory AiQuizBlueprintModel.fromJson(Map<String, dynamic> json) {
    return AiQuizBlueprintModel(
      title: _text(json['title'], 'Module Quiz'),
      questions: _list(json['questions'])
          .whereType<Map>()
          .map(
            (item) => AiQuizQuestionBlueprintModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      passingScore: _int(json['passingScore'], 70),
      points: _int(json['points'], 50),
    );
  }
}

class AiQuizQuestionBlueprintModel {
  const AiQuizQuestionBlueprintModel({
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.points,
  });

  final String type;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final int points;

  factory AiQuizQuestionBlueprintModel.fromJson(Map<String, dynamic> json) {
    return AiQuizQuestionBlueprintModel(
      type: _text(json['type'], 'mcq'),
      question: _text(json['question'], ''),
      options: _strings(json['options']),
      correctAnswer: _text(json['correctAnswer'], ''),
      explanation: _text(json['explanation'], ''),
      points: _int(json['points'], 5),
    );
  }
}

class AiGrandTestBlueprintModel {
  const AiGrandTestBlueprintModel({
    required this.title,
    required this.description,
    required this.questions,
    required this.passingScore,
    required this.totalPoints,
    this.practicalTask,
  });

  final String title;
  final String description;
  final List<AiQuizQuestionBlueprintModel> questions;
  final String? practicalTask;
  final int passingScore;
  final int totalPoints;

  factory AiGrandTestBlueprintModel.fromJson(Map<String, dynamic> json) {
    return AiGrandTestBlueprintModel(
      title: _text(json['title'], 'Final Grand Test'),
      description: _text(json['description'], ''),
      questions: _list(json['questions'])
          .whereType<Map>()
          .map(
            (item) => AiQuizQuestionBlueprintModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      practicalTask: _text(json['practicalTask'], ''),
      passingScore: _int(json['passingScore'], 70),
      totalPoints: _int(json['totalPoints'], 100),
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Object?> _list(Object? value) => value is Iterable ? value.toList() : [];

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(Object? value, int fallback) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _intOrNull(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _strings(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
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

Map<String, dynamic> _normalizeGatewayBlueprint(Map<String, dynamic> data) {
  final wrapped = data['course'];
  final source = wrapped is Map ? Map<String, dynamic>.from(wrapped) : data;
  final normalized = Map<String, dynamic>.from(source);
  final modules = _list(normalized['modules']).whereType<Map>().toList();
  final topAssignments = _list(
    normalized['assignments'],
  ).whereType<Map>().toList();
  final topQuizzes = _list(normalized['quizzes']).whereType<Map>().toList();
  if (modules.isNotEmpty &&
      (topAssignments.isNotEmpty || topQuizzes.isNotEmpty)) {
    final patchedModules = <Map<String, dynamic>>[];
    for (var i = 0; i < modules.length; i++) {
      final module = Map<String, dynamic>.from(modules[i]);
      if (_list(module['assignments']).isEmpty && i < topAssignments.length) {
        module['assignments'] = [topAssignments[i]];
      }
      if (_map(module['quiz']).isEmpty && i < topQuizzes.length) {
        module['quiz'] = topQuizzes[i];
      }
      patchedModules.add(module);
    }
    normalized['modules'] = patchedModules;
  }
  if (normalized['grandTest'] == null &&
      _list(normalized['grandTests']).whereType<Map>().isNotEmpty) {
    normalized['grandTest'] = Map<String, dynamic>.from(
      _list(normalized['grandTests']).whereType<Map>().first,
    );
  }
  return normalized;
}

String _sourceContent(String source, bool isFallback) {
  final normalized = source.toLowerCase();
  if (isFallback) return 'aiUnavailable';
  if (normalized.contains('openai')) return 'openai';
  if (normalized.contains('gemini')) return 'gemini';
  return normalized.contains('template') ? 'aiUnavailable' : normalized;
}
