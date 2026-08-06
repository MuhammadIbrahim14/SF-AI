import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../ai_usage/models/ai_usage_models.dart';
import '../../../copilot/models/copilot_ai_request_model.dart';
import '../../../copilot/services/ai_gateway_client.dart';
import '../models/teacher_ai_generation_request_model.dart';
import '../models/teacher_ai_generation_result_model.dart';
import 'teacher_ai_validation_service.dart';

class TeacherAiGenerationService {
  TeacherAiGenerationService({
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
    TeacherAiValidationService? validationService,
  }) : _gatewayClient = gatewayClient ?? AiGatewayClient(),
       _auth = auth ?? FirebaseAuth.instance,
       _validationService =
           validationService ?? const TeacherAiValidationService();

  final AiGatewayClient _gatewayClient;
  final FirebaseAuth _auth;
  final TeacherAiValidationService _validationService;

  Future<TeacherAiGenerationResultModel> generate(
    TeacherAiGenerationRequestModel request,
  ) async {
    final aiRequest = CopilotAiRequestModel(
      requestId: 'teacher_ai_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? 'teacher',
      role: 'teacher',
      accountType: 'professional',
      taskType: request.taskType,
      userMessage: _buildUserMessage(request),
      pageContext: request.toSafeContext(),
      safeAppContext: {
        ...request.toSafeContext(),
        'firestoreWritesAllowed': false,
        'autoSaveAllowed': false,
        'manualApplyRequired': true,
      },
      languageHint: 'professional English with simple classroom wording',
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'Do not publish content.',
        'Teacher must manually review and save.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gatewayClient.send(aiRequest);
    AppLogger.debug('Teacher AI response received.');
    if (!response.isSuccess || response.structuredData.isEmpty) {
      return TeacherAiGenerationResultModel(
        taskType: request.taskType,
        title: response.title.isEmpty
            ? 'SkillForge AI is temporarily unavailable'
            : response.title,
        message: response.message.isEmpty
            ? 'SkillForge AI could not generate this content right now. Please retry.'
            : response.message,
        data: const <String, dynamic>{},
        sourceProvider: response.source ?? 'aiUnavailable',
        contentSource: response.source ?? 'aiUnavailable',
        qualityStatus: 'AI Unavailable',
        isValid: false,
        model: response.model,
        creditCost: 0,
        warnings: response.suggestions,
        errors: [
          response.safeErrorCode ?? response.blockedReason ?? 'aiUnavailable',
        ],
      );
    }

    final normalized = _normalizeStructuredData(
      response.structuredData,
      request.taskType,
    );
    final result = TeacherAiGenerationResultModel(
      taskType: request.taskType,
      title: response.title,
      message: response.message,
      data: normalized,
      sourceProvider: response.source ?? response.provider,
      contentSource: response.source ?? 'Generated with ${response.provider}',
      qualityStatus: 'Ready for Review',
      isValid: true,
      model: response.usage?['model']?.toString(),
      totalTokens: _intOrNull(response.usage?['totalTokens']),
      creditCost: AiUsageDefaults.featureCosts[request.taskType] ?? 1,
      warnings: const <String>[],
    );
    return _validationService.validateAndRepair(result, request);
  }

  String _buildUserMessage(TeacherAiGenerationRequestModel request) {
    return '''
Build teacher LMS content for taskType=${request.taskType}.
Teacher prompt: ${request.prompt}
Safe context: ${request.toSafeContext()}
Return only JSON in structuredData. No markdown. No Firestore writes.
''';
  }

  Map<String, dynamic> _normalizeStructuredData(
    Map<String, dynamic> data,
    String taskType,
  ) {
    Map<String, dynamic> unwrap(Object? value, String source) {
      if (value is! Map) return const <String, dynamic>{};
      final map = Map<String, dynamic>.from(value);
      AppLogger.debug('Teacher AI response shape detected.');
      return map;
    }

    final nested = data['structuredData'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      final dataItem = nestedMap['data'];
      if (dataItem is Map && dataItem['item'] is Map) {
        return unwrap(dataItem['item'], 'structuredData.data.item');
      }
      for (final key in _shapeKeys(taskType)) {
        if (nestedMap[key] is Map) {
          return unwrap(nestedMap[key], 'structuredData.$key');
        }
      }
      return unwrap(nestedMap, 'structuredData');
    }

    final dataItem = data['data'];
    if (dataItem is Map && dataItem['item'] is Map) {
      return unwrap(dataItem['item'], 'data.item');
    }

    for (final key in _shapeKeys(taskType)) {
      final value = data[key];
      if (value is Map) {
        return unwrap(value, key);
      }
    }
    return unwrap(data, 'direct');
  }

  List<String> _shapeKeys(String taskType) {
    return switch (taskType) {
      TeacherAiTaskType.lessonBuilder => const ['lesson', 'content'],
      TeacherAiTaskType.assignmentBuilder => const ['assignment', 'quiz'],
      TeacherAiTaskType.projectAssignmentBuilder => const [
        'projectAssignment',
        'assignment',
      ],
      TeacherAiTaskType.quizBuilder => const ['quiz', 'assignment'],
      TeacherAiTaskType.grandTestBuilder => const ['grandTest', 'test'],
      TeacherAiTaskType.batchAnnouncementDraft => const [
        'announcement',
        'content',
      ],
      TeacherAiTaskType.improveContent => const ['content', 'item'],
      _ => const ['content', 'item'],
    };
  }

  int? _intOrNull(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
