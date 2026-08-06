import '../models/ai_course_blueprint_model.dart';
import '../models/ai_course_requirement_model.dart';

class AiCourseBlueprintRepairResult {
  const AiCourseBlueprintRepairResult({
    required this.blueprint,
    required this.warnings,
  });

  final AiCourseBlueprintModel blueprint;
  final List<String> warnings;
}

class AiCourseBlueprintRepairService {
  const AiCourseBlueprintRepairService();

  AiCourseBlueprintRepairResult repair({
    required AiCourseBlueprintModel blueprint,
    required AiCourseRequirementModel requirements,
    required String source,
    String? fallbackReason,
  }) {
    final sourceProvider = source.toLowerCase();
    if (sourceProvider.contains('template') ||
        sourceProvider.contains('mock') ||
        _containsGatewayText(blueprint.description)) {
      throw StateError(
        'AI output was unavailable or invalid. Please retry with a real AI provider.',
      );
    }
    final warnings = <String>[
      'Some AI output was repaired to match your selected structure.',
    ];
    final topic = requirements.topic.trim().isEmpty
        ? blueprint.title
        : requirements.topic.trim();
    final lessonDistribution = requirements.effectiveLessonDistribution;
    final modules = <AiCourseModuleBlueprintModel>[];
    var globalLessonIndex = 0;
    var assignmentIndex = 0;
    var quizIndex = 0;
    final repairStats = _repairStats(blueprint, requirements);

    for (
      var moduleIndex = 0;
      moduleIndex < requirements.moduleCount;
      moduleIndex++
    ) {
      final sourceModule = moduleIndex < blueprint.modules.length
          ? blueprint.modules[moduleIndex]
          : null;
      final moduleTitle = sourceModule?.title.trim().isNotEmpty == true
          ? sourceModule!.title
          : 'Module ${moduleIndex + 1}: ${_theme(topic, moduleIndex + 1)}';
      final lessonCount = lessonDistribution[moduleIndex];
      final lessons = <AiLessonBlueprintModel>[];
      for (var i = 0; i < lessonCount; i++) {
        globalLessonIndex++;
        final sourceLesson =
            sourceModule != null && i < sourceModule.lessons.length
            ? sourceModule.lessons[i]
            : null;
        lessons.add(
          _lesson(
            topic: topic,
            moduleTitle: moduleTitle,
            order: i + 1,
            globalIndex: globalLessonIndex,
            source: sourceLesson,
            requirements: requirements,
          ),
        );
      }

      final assignments = <AiAssignmentBlueprintModel>[];
      final moduleAssignmentSlots = _slotsForModule(
        total: requirements.effectiveAssignmentCount,
        modules: requirements.moduleCount,
        moduleIndex: moduleIndex,
      );
      for (var i = 0; i < moduleAssignmentSlots; i++) {
        assignmentIndex++;
        final sourceAssignment =
            sourceModule != null && i < sourceModule.assignments.length
            ? sourceModule.assignments[i]
            : null;
        final questionCount =
            requirements.effectiveAssignmentQuestionCounts[assignmentIndex - 1];
        assignments.add(
          _assignment(
            topic: topic,
            moduleTitle: moduleTitle,
            order: assignmentIndex,
            questionCount: questionCount,
            source: sourceAssignment,
            requirements: requirements,
          ),
        );
      }

      final moduleGetsQuiz =
          quizIndex < requirements.effectiveQuizCount &&
          _slotsForModule(
                total: requirements.effectiveQuizCount,
                modules: requirements.moduleCount,
                moduleIndex: moduleIndex,
              ) >
              0;
      AiQuizBlueprintModel quiz;
      if (moduleGetsQuiz) {
        quizIndex++;
        quiz = _quiz(
          topic: topic,
          moduleTitle: moduleTitle,
          order: quizIndex,
          questionCount:
              requirements.effectiveQuizQuestionCounts[quizIndex - 1],
          source: sourceModule?.quiz,
          requirements: requirements,
        );
      } else {
        quiz = const AiQuizBlueprintModel(
          title: 'No quiz requested',
          questions: [],
          passingScore: 0,
          points: 0,
        );
      }

      modules.add(
        AiCourseModuleBlueprintModel(
          title: moduleTitle,
          description: sourceModule?.description.trim().isNotEmpty == true
              ? sourceModule!.description
              : 'Structured ${requirements.difficultyLevel} practice for $topic.',
          order: moduleIndex + 1,
          lessons: lessons,
          assignments: assignments,
          quiz: quiz,
        ),
      );
    }

    final grandTests = <AiGrandTestBlueprintModel>[];
    final sourceGrandTests = blueprint.effectiveGrandTests;
    for (var i = 0; i < requirements.effectiveGrandTestCount; i++) {
      final questionCount = requirements.effectiveGrandTestQuestionCounts[i];
      final sourceTest = i < sourceGrandTests.length
          ? sourceGrandTests[i]
          : null;
      grandTests.add(
        _grandTest(
          topic: topic,
          order: i + 1,
          questionCount: questionCount,
          source: sourceTest,
          requirements: requirements,
        ),
      );
    }

    final repaired = AiCourseBlueprintModel(
      title: blueprint.title.trim().isEmpty ? topic : blueprint.title,
      subtitle: blueprint.subtitle,
      description:
          blueprint.description.trim().isEmpty ||
              _containsGatewayText(blueprint.description)
          ? 'Teacher-reviewed AI course blueprint for $topic.'
          : blueprint.description,
      targetAudience: blueprint.targetAudience,
      level: requirements.difficultyLevel,
      durationWeeks: requirements.durationWeeks,
      estimatedHours: (requirements.totalLessonCount * 1.5).ceil(),
      prerequisites: blueprint.prerequisites.isEmpty
          ? ['Basic computer literacy', 'Willingness to practice']
          : blueprint.prerequisites,
      learningOutcomes: blueprint.learningOutcomes.isEmpty
          ? [
              'Understand $topic fundamentals',
              'Apply $topic skills in practical tasks',
              'Complete assessments with confidence',
            ]
          : blueprint.learningOutcomes,
      modules: modules,
      grandTest: grandTests.isNotEmpty
          ? grandTests.first
          : const AiGrandTestBlueprintModel(
              title: 'No grand test requested',
              description: '',
              questions: [],
              passingScore: 0,
              totalPoints: 0,
            ),
      grandTests: grandTests,
      certificateCriteria: blueprint.certificateCriteria.isEmpty
          ? ['Complete lessons', 'Submit assignments', 'Pass final assessment']
          : blueprint.certificateCriteria,
      gradingRubric: blueprint.gradingRubric.isEmpty
          ? ['Assignments 40%', 'Quizzes 20%', 'Grand Test 40%']
          : blueprint.gradingRubric,
      languageStyle: requirements.languageStyle,
      generatedBy: _isRealAiSource(source)
          ? 'SkillForge AI + Safety Repair'
          : 'SkillForge AI Unavailable',
      generatedAt: DateTime.now(),
      source: source,
      contentSource: _contentSourceFor(
        source: source,
        repairedItemCount: repairStats.repairedItemCount,
        fallbackItemCount: repairStats.fallbackItemCount,
      ),
      isFallback: !_isRealAiSource(source),
      fallbackReason: fallbackReason,
      gatewayStatusMessage: fallbackReason,
      qualityWarnings: [
        if (repairStats.repairedItemCount > 0)
          'Some missing or invalid items were repaired locally.',
        ...warnings,
      ],
      repairedItemCount: repairStats.repairedItemCount,
      fallbackItemCount: repairStats.fallbackItemCount,
      aiModel: blueprint.aiModel,
      totalTokens: blueprint.totalTokens,
    );
    return AiCourseBlueprintRepairResult(
      blueprint: repaired,
      warnings: warnings,
    );
  }

  AiLessonBlueprintModel _lesson({
    required String topic,
    required String moduleTitle,
    required int order,
    required int globalIndex,
    required AiLessonBlueprintModel? source,
    required AiCourseRequirementModel requirements,
  }) {
    final title = source?.title.trim().isNotEmpty == true
        ? source!.title
        : 'Lesson $globalIndex: ${_theme(topic, globalIndex)}';
    return AiLessonBlueprintModel(
      title: title,
      objective: source?.objective.trim().isNotEmpty == true
          ? source!.objective
          : 'Master a unique part of $topic through $moduleTitle.',
      summary: source?.summary.trim().isNotEmpty == true
          ? source!.summary
          : 'A ${requirements.contentDepth} lesson covering $title with examples and practice.',
      contentOutline: source?.contentOutline.isNotEmpty == true
          ? source!.contentOutline
          : [
              'Concept: $title',
              'Guided walkthrough',
              'Common mistakes',
              'Practice review',
            ],
      examples: source?.examples.isNotEmpty == true
          ? source!.examples
          : ['Example $globalIndex for $topic'],
      practiceTasks: source?.practiceTasks.isNotEmpty == true
          ? source!.practiceTasks
          : ['Complete practice task $globalIndex for $topic'],
      durationMinutes: source?.durationMinutes ?? 45,
      order: order,
    );
  }

  AiAssignmentBlueprintModel _assignment({
    required String topic,
    required String moduleTitle,
    required int order,
    required int questionCount,
    required AiAssignmentBlueprintModel? source,
    required AiCourseRequirementModel requirements,
  }) {
    final type = requirements.assignmentType == 'mixed'
        ? (order.isOdd ? 'mcq' : 'practical')
        : requirements.assignmentType;
    return AiAssignmentBlueprintModel(
      title: source?.title.trim().isNotEmpty == true
          ? source!.title
          : 'Assignment $order: $moduleTitle practice',
      instructions: source?.instructions.trim().isNotEmpty == true
          ? source!.instructions
          : 'Complete a $type assignment that proves your understanding of $moduleTitle.',
      submissionType: type == 'mcq' ? 'mcq' : 'project',
      rubric: source?.rubric.isNotEmpty == true
          ? source!.rubric
          : ['Accuracy', 'Completeness', 'Clarity', 'Practical application'],
      questions: _questions(
        source: source?.questions ?? const <AiQuizQuestionBlueprintModel>[],
        count: questionCount,
        topic: topic,
        context: 'Assignment $order $moduleTitle',
        seedBase: order * 100,
        type: type == 'written' ? 'written' : 'mcq',
        requirements: requirements,
      ),
      dueOffsetDays: source?.dueOffsetDays ?? 7,
      points: questionCount * 5,
    );
  }

  AiQuizBlueprintModel _quiz({
    required String topic,
    required String moduleTitle,
    required int order,
    required int questionCount,
    required AiQuizBlueprintModel? source,
    required AiCourseRequirementModel requirements,
  }) {
    return AiQuizBlueprintModel(
      title: source?.title.trim().isNotEmpty == true
          ? source!.title
          : 'Quiz $order: $moduleTitle check',
      questions: _questions(
        source: source?.questions ?? const <AiQuizQuestionBlueprintModel>[],
        count: questionCount,
        topic: topic,
        context: 'Quiz $order $moduleTitle',
        seedBase: order * 1000,
        type: 'mcq',
        requirements: requirements,
      ),
      passingScore: source?.passingScore ?? 70,
      points: questionCount * 5,
    );
  }

  AiGrandTestBlueprintModel _grandTest({
    required String topic,
    required int order,
    required int questionCount,
    required AiGrandTestBlueprintModel? source,
    required AiCourseRequirementModel requirements,
  }) {
    return AiGrandTestBlueprintModel(
      title: source?.title.trim().isNotEmpty == true
          ? source!.title
          : 'Grand Test $order: $topic mastery',
      description: source?.description.trim().isNotEmpty == true
          ? source!.description
          : 'Final unique assessment for $topic.',
      questions: _questions(
        source: source?.questions ?? const <AiQuizQuestionBlueprintModel>[],
        count: questionCount,
        topic: topic,
        context: 'Grand Test $order',
        seedBase: order * 10000,
        type: 'mcq',
        requirements: requirements,
      ),
      practicalTask: source?.practicalTask,
      passingScore: source?.passingScore ?? 70,
      totalPoints: questionCount * 5,
    );
  }

  AiQuizQuestionBlueprintModel _question({
    required String topic,
    required String context,
    required int globalIndex,
    required String type,
    required AiCourseRequirementModel requirements,
  }) {
    final concept = _theme(topic, globalIndex);
    if (type == 'written') {
      return AiQuizQuestionBlueprintModel(
        type: 'written',
        question:
            '$context Q$globalIndex: Explain how $concept applies in a real $topic workflow.',
        options: const [],
        correctAnswer: '',
        explanation:
            'A strong answer connects the concept to practical implementation.',
        points: 5,
      );
    }
    final correct = 'Apply $concept with a clear practical workflow';
    return AiQuizQuestionBlueprintModel(
      type: 'mcq',
      question:
          '$context Q$globalIndex: What is the best professional use of $concept in $topic?',
      options: [
        correct,
        'Skip practice and memorize terms only',
        'Use unrelated tools without planning',
        'Ignore feedback and testing',
      ],
      correctAnswer: correct,
      explanation:
          'This answer matches ${requirements.difficultyLevel} level practical understanding.',
      points: 5,
    );
  }

  List<AiQuizQuestionBlueprintModel> _questions({
    required List<AiQuizQuestionBlueprintModel> source,
    required int count,
    required String topic,
    required String context,
    required int seedBase,
    required String type,
    required AiCourseRequirementModel requirements,
  }) {
    final questions = <AiQuizQuestionBlueprintModel>[];
    final seen = <String>{};
    for (final question in source) {
      if (questions.length >= count) break;
      final normalized = _normalize(question.question);
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      if (!_isValidQuestion(question)) continue;
      questions.add(question);
    }
    while (questions.length < count) {
      final index = questions.length;
      questions.add(
        _question(
          topic: topic,
          context: context,
          globalIndex: seedBase + index + 1,
          type: type,
          requirements: requirements,
        ),
      );
    }
    return questions;
  }
}

class _RepairStats {
  const _RepairStats({
    required this.repairedItemCount,
    required this.fallbackItemCount,
  });

  final int repairedItemCount;
  final int fallbackItemCount;
}

_RepairStats _repairStats(
  AiCourseBlueprintModel blueprint,
  AiCourseRequirementModel requirements,
) {
  var repaired = 0;
  repaired += (requirements.moduleCount - blueprint.modules.length).clamp(
    0,
    999,
  );
  repaired += (requirements.totalLessonCount - blueprint.totalLessonCount)
      .clamp(0, 999);
  repaired +=
      (requirements.effectiveAssignmentCount - blueprint.totalAssignmentCount)
          .clamp(0, 999);
  repaired +=
      (requirements.expectedAssignmentQuestionTotal -
              blueprint.totalAssignmentQuestionCount)
          .clamp(0, 999);
  repaired += (requirements.effectiveQuizCount - blueprint.totalQuizCount)
      .clamp(0, 999);
  repaired +=
      (requirements.expectedQuizQuestionTotal -
              blueprint.totalQuizQuestionCount)
          .clamp(0, 999);
  repaired +=
      (requirements.effectiveGrandTestCount -
              blueprint.effectiveGrandTests.length)
          .clamp(0, 999);
  repaired +=
      (requirements.expectedGrandTestQuestionTotal -
              blueprint.totalGrandTestQuestionCount)
          .clamp(0, 999);
  final fallback = blueprint.modules.isEmpty ? repaired : 0;
  return _RepairStats(
    repairedItemCount: repaired.toInt(),
    fallbackItemCount: fallback.toInt(),
  );
}

String _contentSourceFor({
  required String source,
  required int repairedItemCount,
  required int fallbackItemCount,
}) {
  if (!_isRealAiSource(source)) return 'aiUnavailable';
  final provider = source.toLowerCase().contains('gemini')
      ? 'gemini'
      : 'openai';
  if (repairedItemCount > 0 || fallbackItemCount > 0) {
    return '${provider}WithRepair';
  }
  return provider;
}

int _slotsForModule({
  required int total,
  required int modules,
  required int moduleIndex,
}) {
  final base = total ~/ modules;
  final remainder = total % modules;
  return base + (moduleIndex < remainder ? 1 : 0);
}

String _theme(String topic, int order) {
  final clean = topic.trim().isEmpty ? 'course skill' : topic.trim();
  final themes = [
    '$clean foundations',
    '$clean setup and workflow',
    '$clean practical implementation',
    '$clean problem solving',
    '$clean real-world scenarios',
    '$clean debugging and review',
    '$clean portfolio practice',
    '$clean final mastery',
  ];
  return themes[(order - 1).abs() % themes.length];
}

bool _containsGatewayText(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('gemini is temporarily unavailable') ||
      normalized.contains('gateway is not reachable') ||
      normalized.contains('failed to fetch') ||
      normalized.contains('rate-limited') ||
      normalized.contains('rate limited') ||
      normalized.contains('provider mock') ||
      normalized.contains('template fallback reason');
}

bool _isValidQuestion(AiQuizQuestionBlueprintModel question) {
  if (question.question.trim().isEmpty ||
      _containsGatewayText(question.question)) {
    return false;
  }
  if (question.type.toLowerCase() != 'mcq') return true;
  if (question.options.length < 4) return false;
  final correct = question.correctAnswer.trim().toLowerCase();
  if (correct.isEmpty) return false;
  return question.options.any(
    (option) => option.trim().toLowerCase() == correct,
  );
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isRealAiSource(String source) {
  final normalized = source.toLowerCase();
  return normalized.contains('gemini') || normalized.contains('openai');
}
