import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../features/copilot/models/copilot_ai_request_model.dart';
import '../../../../features/copilot/models/copilot_ai_response_model.dart';
import '../../../../features/copilot/models/copilot_intent_model.dart';
import '../../../../features/copilot/services/ai_gateway_client.dart';
import '../models/ai_course_blueprint_model.dart';
import '../models/ai_course_requirement_model.dart';
import 'ai_course_blueprint_repair_service.dart';
import 'ai_course_blueprint_validator.dart';

class TeacherAiCourseBuilderService {
  const TeacherAiCourseBuilderService({
    required AiGatewayClient gatewayClient,
    required FirebaseAuth auth,
  }) : _gatewayClient = gatewayClient,
       _auth = auth;

  final AiGatewayClient _gatewayClient;
  final FirebaseAuth _auth;

  Future<AiCourseBlueprintModel> generateBlueprint(
    AiCourseRequirementModel requirements,
  ) async {
    final requirementErrors = requirements.validate();
    if (requirementErrors.isNotEmpty) {
      throw StateError(requirementErrors.join('\n'));
    }

    final request = CopilotAiRequestModel(
      requestId: 'course-builder-${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? 'anonymous',
      role: 'teacher',
      accountType: 'professional',
      taskType: CopilotIntentType.teacherCourseBlueprint,
      userMessage: _prompt(requirements),
      safeAppContext: {
        'manualReviewRequired': true,
        'noFirestoreWrites': true,
        'noAutoPublish': true,
        'exactCountsRequired': requirements.toJson(),
      },
      languageHint: requirements.languageStyle,
      constraints: const [
        'Return structured JSON only.',
        'Respect all exact counts.',
        'Do not repeat lessons or questions.',
        'Do not claim the course was saved or published.',
        'Teacher must review before saving or publishing.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gatewayClient.send(request);
    if (response.status == CopilotAiResponseStatus.success &&
        response.structuredData.isNotEmpty) {
      final data = _extractBlueprintData(response.structuredData);
      final shape = _structuredDataShape(response.structuredData);
      if (!_isBlueprintLike(data)) {
        _debugCourseBuilder(
          response: response,
          shape: shape,
          parsedSource: 'parseFailedTemplateFallback',
          originalData: data,
          finalBlueprint: null,
        );
        throw StateError(
          'AI generated a response, but it did not match the required course format. Please retry.',
        );
      }
      final blueprint = AiCourseBlueprintModel.fromGatewayStructuredData(
        response.structuredData,
        source: response.source ?? response.provider,
        isFallback: false,
        languageStyle: requirements.languageStyle,
        usage: response.usage,
      );
      final repaired = _repairAndValidate(
        blueprint: blueprint,
        requirements: requirements,
        source: response.source ?? response.provider,
      );
      _debugCourseBuilder(
        response: response,
        shape: shape,
        parsedSource: repaired.normalizedContentSource,
        originalData: data,
        finalBlueprint: repaired,
      );
      return repaired;
    }

    throw StateError(
      response.message.isEmpty
          ? 'SkillForge AI could not generate this course right now. Please retry.'
          : response.message,
    );
  }

  AiCourseBlueprintModel generateFallbackBlueprint(
    AiCourseRequirementModel requirements,
    String reason, {
    String contentSource = 'aiUnavailable',
  }) {
    throw StateError(
      'AI template generation is disabled. SkillForge AI requires a real AI provider response.',
    );
  }

  List<String> validateBlueprint(
    AiCourseBlueprintModel blueprint, {
    AiCourseRequirementModel? requirements,
  }) {
    if (requirements == null) {
      final errors = <String>[];
      if (blueprint.title.trim().isEmpty) {
        errors.add('Course title is required.');
      }
      if (blueprint.modules.isEmpty) {
        errors.add('At least one module is required.');
      }
      if (blueprint.modules.any((module) => module.lessons.isEmpty)) {
        errors.add('Every module needs at least one lesson.');
      }
      return errors;
    }
    return const AiCourseBlueprintValidator()
        .validate(blueprint: blueprint, requirements: requirements)
        .errors;
  }

  AiCourseBlueprintModel _repairAndValidate({
    required AiCourseBlueprintModel blueprint,
    required AiCourseRequirementModel requirements,
    required String source,
    String? fallbackReason,
  }) {
    final repaired = const AiCourseBlueprintRepairService().repair(
      blueprint: blueprint,
      requirements: requirements,
      source: source == 'template' ? 'validationFailed' : source,
      fallbackReason: fallbackReason,
    );
    final validation = const AiCourseBlueprintValidator().validate(
      blueprint: repaired.blueprint,
      requirements: requirements,
    );
    if (validation.isValid) return repaired.blueprint;
    throw StateError(validation.errors.join('\n'));
  }

  Map<String, dynamic> _extractBlueprintData(Map<String, dynamic> data) {
    final course = data['course'];
    if (course is Map) return Map<String, dynamic>.from(course);
    if (data['title'] != null ||
        data['modules'] != null ||
        data['grandTests'] != null ||
        data['grandTest'] != null) {
      return data;
    }
    final nested = data['blueprint'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return data;
  }

  bool _isBlueprintLike(Map<String, dynamic> data) {
    final modules = data['modules'];
    return data['title'] != null ||
        data['grandTests'] != null ||
        data['grandTest'] != null ||
        modules is Iterable;
  }

  String _structuredDataShape(Map<String, dynamic> data) {
    if (data['course'] is Map) return 'courseWrapper';
    if (_isBlueprintLike(data)) return 'direct';
    if (data['blueprint'] is Map) return 'blueprintWrapper';
    return 'unknown';
  }

  void _debugCourseBuilder({
    required CopilotAiResponseModel response,
    required String shape,
    required String parsedSource,
    required Map<String, dynamic> originalData,
    required AiCourseBlueprintModel? finalBlueprint,
  }) {
    if (!kDebugMode) return;
    final originalModules = originalData['modules'] is Iterable
        ? (originalData['modules'] as Iterable).length
        : 0;
    final originalLessons = originalData['modules'] is Iterable
        ? (originalData['modules'] as Iterable).whereType<Map>().fold<int>(
            0,
            (sum, module) =>
                sum +
                (module['lessons'] is Iterable
                    ? (module['lessons'] as Iterable).length
                    : 0),
          )
        : 0;
    debugPrint(
      '[TeacherAIBuilder] provider=${response.provider} '
      'status=${response.status} fallbackRecommended=${response.fallbackRecommended} '
      'structuredDataShape=$shape parsedBlueprintSource=$parsedSource '
      'originalOpenAiModuleCount=$originalModules '
      'originalOpenAiLessonCount=$originalLessons '
      'finalModuleCount=${finalBlueprint?.modules.length ?? 0} '
      'finalLessonCount=${finalBlueprint?.totalLessonCount ?? 0} '
      'repairedItemCount=${finalBlueprint?.repairedItemCount ?? 0} '
      'fallbackItemCount=${finalBlueprint?.fallbackItemCount ?? 0} '
      'contentSource=${finalBlueprint?.normalizedContentSource ?? parsedSource}',
    );
  }

  String _prompt(AiCourseRequirementModel requirements) {
    final contract = requirements.toJson();
    return '''
Generate a complete SkillForge LMS course blueprint as strict JSON only.
Generate professional LMS-ready content, not a generic outline.

Teacher requirement contract:
$contract

Strict count rules:
1. Create exactly moduleCount modules.
2. Create exactly totalLessonCount lessons distributed by lessonCountPerModule.
3. Create exactly assignmentCount assignments.
4. Each assignment must contain exactly its assignmentQuestionCounts value.
5. Create exactly quizCount quizzes.
6. Each quiz must contain exactly its quizQuestionCounts value.
7. Create exactly grandTestCount grand tests.
8. Each grand test must contain exactly its grandTestQuestionCounts value.
9. Every lesson title/objective/summary must be unique.
10. Every assignment, quiz, and grand test question must be unique.
11. MCQs need at least four options and correctAnswer must match one option.
12. Do not use markdown. Do not claim the course was saved or published.
13. Each lesson summary/content must be 120-200 words with 4-8 contentOutline bullets, 2 practical examples, and 2 practiceTasks.
14. Each assignment needs detailed instructions, at least 4 rubric criteria, exact question counts, and topic-specific questions.
15. Each MCQ needs 4 meaningful options, a correctAnswer that exactly matches one option, explanation, and points.
16. Avoid repeated generic beginner questions or reused options. Use course-specific practical, conceptual, and debugging contexts.

Required JSON shape:
{
  "title": "...",
  "subtitle": "...",
  "description": "...",
  "targetAudience": "...",
  "level": "...",
  "durationWeeks": 4,
  "estimatedHours": 24,
  "prerequisites": [],
  "learningOutcomes": [],
  "modules": [
    {
      "title": "...",
      "description": "...",
      "order": 1,
      "lessons": [{"title":"...","objective":"...","summary":"...","contentOutline":[],"examples":[],"practiceTasks":[],"durationMinutes":45,"order":1}],
      "assignments": [{"title":"...","submissionType":"mcq|project","instructions":"...","rubric":[],"questions":[{"type":"mcq","question":"...","options":[],"correctAnswer":"...","explanation":"...","points":5}],"dueOffsetDays":7,"points":100}],
      "quiz": {"title":"...","questions":[{"type":"mcq","question":"...","options":[],"correctAnswer":"...","explanation":"...","points":5}],"passingScore":70,"points":50}
    }
  ],
  "grandTests": [
    {"title":"...","description":"...","questions":[{"type":"mcq","question":"...","options":[],"correctAnswer":"...","explanation":"...","points":5}],"practicalTask":"...","passingScore":70,"totalPoints":100}
  ],
  "certificateCriteria": [],
  "gradingRubric": []
}
''';
  }
}
