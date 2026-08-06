import '../models/ai_course_blueprint_model.dart';
import '../models/ai_course_requirement_model.dart';

class AiCourseBlueprintValidationResult {
  const AiCourseBlueprintValidationResult({
    required this.isValid,
    required this.repairable,
    required this.errors,
    required this.warnings,
    required this.duplicateItems,
    required this.missingCounts,
    required this.qualityScore,
    required this.qualityStatus,
  });

  final bool isValid;
  final bool repairable;
  final List<String> errors;
  final List<String> warnings;
  final List<String> duplicateItems;
  final List<String> missingCounts;
  final int qualityScore;
  final String qualityStatus;

  bool get hasWarnings => warnings.isNotEmpty || duplicateItems.isNotEmpty;

  String get statusLabel {
    if (isValid && hasWarnings) return 'Needs review';
    if (isValid) return 'Valid';
    return repairable ? 'Repairable' : 'Invalid';
  }
}

class AiCourseBlueprintValidator {
  const AiCourseBlueprintValidator();

  AiCourseBlueprintValidationResult validate({
    required AiCourseBlueprintModel blueprint,
    required AiCourseRequirementModel requirements,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final duplicateItems = <String>[];
    final missingCounts = <String>[];

    void count(String label, int expected, int actual) {
      if (expected != actual) {
        final message = '$label expected $expected but generated $actual.';
        missingCounts.add(message);
        errors.add(message);
      }
    }

    count('Modules', requirements.moduleCount, blueprint.modules.length);
    count('Lessons', requirements.totalLessonCount, blueprint.totalLessonCount);
    count(
      'Assignments',
      requirements.effectiveAssignmentCount,
      blueprint.totalAssignmentCount,
    );
    count(
      'Assignment questions',
      requirements.expectedAssignmentQuestionTotal,
      blueprint.totalAssignmentQuestionCount,
    );
    count('Quizzes', requirements.effectiveQuizCount, blueprint.totalQuizCount);
    count(
      'Quiz questions',
      requirements.expectedQuizQuestionTotal,
      blueprint.totalQuizQuestionCount,
    );
    count(
      'Grand tests',
      requirements.effectiveGrandTestCount,
      blueprint.effectiveGrandTests.length,
    );
    count(
      'Grand test questions',
      requirements.expectedGrandTestQuestionTotal,
      blueprint.totalGrandTestQuestionCount,
    );

    if (_containsGatewayText(blueprint.title) ||
        _containsGatewayText(blueprint.description)) {
      errors.add(
        'Gateway/provider status text cannot be used as course content.',
      );
    }

    for (final module in blueprint.modules) {
      if (_containsGatewayText(module.title) ||
          _containsGatewayText(module.description)) {
        errors.add('Gateway/provider status text found inside module content.');
      }
      for (final lesson in module.lessons) {
        if (lesson.title.trim().isEmpty || lesson.summary.trim().isEmpty) {
          errors.add('A lesson in ${module.title} has empty title or summary.');
        }
        if (_containsGatewayText(lesson.title) ||
            _containsGatewayText(lesson.objective) ||
            _containsGatewayText(lesson.summary)) {
          errors.add(
            'Gateway/provider status text found inside lesson content.',
          );
        }
      }
      for (final assignment in module.assignments) {
        if (assignment.title.trim().isEmpty ||
            assignment.instructions.trim().isEmpty) {
          errors.add('An assignment in ${module.title} has missing content.');
        }
        if (_containsGatewayText(assignment.title) ||
            _containsGatewayText(assignment.instructions)) {
          errors.add(
            'Gateway/provider status text found inside assignment content.',
          );
        }
        for (final question in assignment.questions) {
          _validateQuestion(errors, question);
        }
      }
      for (final question in module.quiz.questions) {
        _validateQuestion(errors, question);
      }
    }
    for (final test in blueprint.effectiveGrandTests) {
      for (final question in test.questions) {
        _validateQuestion(errors, question);
      }
    }

    _collectDuplicates(
      duplicateItems,
      label: 'lesson',
      values: blueprint.modules.expand(
        (module) => module.lessons.map(
          (lesson) => '${lesson.title} ${lesson.objective} ${lesson.summary}',
        ),
      ),
    );
    _collectDuplicates(
      duplicateItems,
      label: 'assignment',
      values: blueprint.modules.expand(
        (module) => module.assignments.map((assignment) => assignment.title),
      ),
    );
    _collectDuplicates(
      duplicateItems,
      label: 'question',
      values: [
        ...blueprint.modules.expand(
          (module) => module.assignments.expand(
            (assignment) => assignment.questions.map((q) => q.question),
          ),
        ),
        ...blueprint.modules.expand(
          (module) => module.quiz.questions.map((q) => q.question),
        ),
        ...blueprint.effectiveGrandTests.expand(
          (test) => test.questions.map((q) => q.question),
        ),
      ],
    );
    if (requirements.requireUniqueLessons &&
        duplicateItems.any((i) => i.contains('lesson'))) {
      errors.add('Duplicate lesson content detected.');
    }
    if (requirements.avoidDuplicateQuestions &&
        duplicateItems.any((i) => i.contains('question'))) {
      errors.add('Duplicate questions detected.');
    }
    if (duplicateItems.any((i) => i.contains('assignment'))) {
      errors.add('Duplicate assignment titles detected.');
    }

    final score = _qualityScore(
      blueprint: blueprint,
      errors: errors,
      duplicates: duplicateItems,
      requirements: requirements,
    );
    final isValid = errors.isEmpty;
    return AiCourseBlueprintValidationResult(
      isValid: isValid,
      repairable: true,
      errors: errors,
      warnings: warnings,
      duplicateItems: duplicateItems,
      missingCounts: missingCounts,
      qualityScore: score,
      qualityStatus: !isValid
          ? 'Invalid'
          : score >= 90
          ? 'Excellent'
          : score >= 75
          ? 'Good'
          : 'Needs Review',
    );
  }

  void _validateQuestion(
    List<String> errors,
    AiQuizQuestionBlueprintModel question,
  ) {
    if (question.question.trim().isEmpty) {
      errors.add('A question has empty text.');
    }
    if (_containsGatewayText(question.question) ||
        _containsGatewayText(question.explanation)) {
      errors.add('Gateway/provider status text found inside question content.');
    }
    if (question.type.toLowerCase() == 'mcq') {
      if (question.options.length < 4) {
        errors.add('MCQ "${question.question}" needs at least 4 options.');
      }
      final correct = question.correctAnswer.trim().toLowerCase();
      final hasCorrect = question.options.any(
        (option) => option.trim().toLowerCase() == correct,
      );
      if (correct.isEmpty || !hasCorrect) {
        errors.add('MCQ "${question.question}" has invalid correct answer.');
      }
    }
  }

  void _collectDuplicates(
    List<String> duplicates, {
    required String label,
    required Iterable<String> values,
  }) {
    final seen = <String>{};
    for (final value in values) {
      final normalized = _normalize(value);
      if (normalized.isEmpty) continue;
      final near = normalized.length > 80
          ? normalized.substring(0, 80)
          : normalized;
      if (!seen.add(near)) {
        duplicates.add('Duplicate $label: ${value.trim()}');
      }
    }
  }

  int _qualityScore({
    required AiCourseBlueprintModel blueprint,
    required List<String> errors,
    required List<String> duplicates,
    required AiCourseRequirementModel requirements,
  }) {
    var score = 100;
    score -= errors.length * 10;
    score -= duplicates.length * 6;
    if (blueprint.isFallback) score -= 8;
    if (blueprint.modules.any(
      (m) => m.lessons.any((l) => l.summary.length < 40),
    )) {
      score -= 6;
    }
    if (requirements.effectiveGrandTestCount > 0 &&
        blueprint.effectiveGrandTests.isEmpty) {
      score -= 10;
    }
    return score.clamp(0, 100).toInt();
  }
}

String normalizeAiCourseText(String value) => _normalize(value);

bool containsGatewayStatusText(String value) => _containsGatewayText(value);

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _containsGatewayText(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('gemini is temporarily unavailable') ||
      normalized.contains('gateway is not reachable') ||
      normalized.contains('failed to fetch') ||
      normalized.contains('rate-limited') ||
      normalized.contains('rate limited') ||
      normalized.contains('provider mock') ||
      normalized.contains('template fallback reason') ||
      normalized.contains('ai gateway is not reachable');
}
