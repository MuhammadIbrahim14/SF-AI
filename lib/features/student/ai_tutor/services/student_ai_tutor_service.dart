import 'package:firebase_auth/firebase_auth.dart';

import '../../../ai_usage/models/ai_usage_models.dart';
import '../../../copilot/models/copilot_ai_request_model.dart';
import '../../../copilot/services/ai_gateway_client.dart';
import '../models/student_ai_message_model.dart';
import '../models/student_ai_tutor_models.dart';
import 'student_ai_safety_service.dart';

class StudentAiTutorService {
  StudentAiTutorService({
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
    StudentAiSafetyService? safetyService,
  }) : _gatewayClient = gatewayClient ?? AiGatewayClient(),
       _auth = auth ?? FirebaseAuth.instance,
       _safetyService = safetyService ?? const StudentAiSafetyService();

  final AiGatewayClient _gatewayClient;
  final FirebaseAuth _auth;
  final StudentAiSafetyService _safetyService;

  Future<StudentAiTutorResponseModel> ask({
    required String taskType,
    required String prompt,
    required StudentAiTutorContextModel context,
    String? threadId,
    List<StudentAiMessageModel> recentMessages =
        const <StudentAiMessageModel>[],
  }) async {
    final safeContext = {
      ...context.toSafeMap(),
      if ((threadId ?? '').trim().isNotEmpty) 'threadId': threadId!.trim(),
      'recentChatMessages': _safeHistory(recentMessages),
      'safeLearningInstruction': _safetyService.safeInstructionForMode(
        context.mode,
      ),
      'hideAnswerKey': _safetyService.shouldHideAnswerKey(context.mode),
      'autoSubmitAllowed': false,
      'progressWritesAllowed': false,
      'scoreWritesAllowed': false,
    };
    final request = CopilotAiRequestModel(
      requestId: 'student_tutor_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? context.studentId,
      role: 'student',
      accountType: 'professional',
      taskType: taskType,
      userMessage: prompt,
      pageContext: safeContext,
      safeAppContext: safeContext,
      languageHint: context.languagePreference,
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'Do not submit assignments, quizzes, or tests.',
        'Give hints for active graded work, not direct answer keys.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gatewayClient.send(request);
    if (!response.isSuccess || response.structuredData.isEmpty) {
      return StudentAiTutorResponseModel(
        title: response.title.isEmpty
            ? 'SkillForge AI is temporarily unavailable'
            : response.title,
        answer: response.message.isEmpty
            ? 'SkillForge AI could not generate a response right now. Please retry in a moment.'
            : response.message,
        sourceProvider: response.source ?? 'aiUnavailable',
        isFallback: false,
        isRepaired: false,
        model: response.model,
        creditCost: 0,
        safetyNotes: const ['No progress, score, or submission was changed.'],
        suggestedNextActions: response.suggestions,
        qualityWarnings: [
          response.safeErrorCode ?? response.blockedReason ?? 'aiUnavailable',
        ],
      );
    }

    final data = _normalize(response.structuredData);
    final parsed = StudentAiTutorResponseModel(
      title: _text(data['title'], response.title),
      answer: _text(data['answer'] ?? data['message'], response.message),
      sourceProvider: response.source ?? response.provider,
      isFallback: false,
      isRepaired: false,
      model: response.usage?['model']?.toString(),
      totalTokens: _int(response.usage?['totalTokens']),
      creditCost: AiUsageDefaults.featureCosts[taskType] ?? 1,
      explanationSteps: _stringList(data['explanationSteps']),
      examples: _stringList(data['examples']),
      practiceQuestions: _questions(data['practiceQuestions']),
      hints: _stringList(data['hints']),
      revisionPlan: _stringList(data['revisionPlan']),
      safetyNotes: [
        ..._stringList(data['safetyNotes']),
        'No progress, score, or submission was changed.',
      ],
      suggestedNextActions: _stringList(data['suggestedNextActions']),
      qualityWarnings: const <String>[],
    );

    if (_safetyService.shouldHideAnswerKey(context.mode)) {
      return StudentAiTutorResponseModel(
        title: parsed.title,
        answer: parsed.answer,
        sourceProvider: parsed.sourceProvider,
        isFallback: parsed.isFallback,
        isRepaired: true,
        model: parsed.model,
        totalTokens: parsed.totalTokens,
        creditCost: parsed.creditCost,
        explanationSteps: parsed.explanationSteps,
        examples: parsed.examples,
        practiceQuestions: parsed.practiceQuestions
            .map(
              (question) => StudentPracticeQuestionModel(
                question: question.question,
                options: question.options,
                correctAnswer: '',
                explanation: 'Answer key hidden during active assessment mode.',
                difficulty: question.difficulty,
                topicTag: question.topicTag,
              ),
            )
            .toList(),
        hints: parsed.hints,
        revisionPlan: parsed.revisionPlan,
        safetyNotes: parsed.safetyNotes,
        suggestedNextActions: parsed.suggestedNextActions,
        qualityWarnings: [
          ...parsed.qualityWarnings,
          'Answer keys were hidden for safe learning mode.',
        ],
      );
    }

    return parsed;
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final nested = data['structuredData'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    final tutor = data['tutor'];
    if (tutor is Map) return Map<String, dynamic>.from(tutor);
    final item = data['data'];
    if (item is Map && item['item'] is Map) {
      return Map<String, dynamic>.from(item['item'] as Map);
    }
    return Map<String, dynamic>.from(data);
  }

  String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const <String>[];
  }

  List<StudentPracticeQuestionModel> _questions(Object? value) {
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

  int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<Map<String, String>> _safeHistory(List<StudentAiMessageModel> messages) {
    return messages
        .where((message) => message.content.trim().isNotEmpty)
        .where((message) => !message.isFailed)
        .toList()
        .reversed
        .take(18)
        .toList()
        .reversed
        .map(
          (message) => {
            'role': message.isUser ? 'student' : 'assistant',
            'content': _trimHistory(message.content),
          },
        )
        .toList();
  }

  String _trimHistory(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 900) return text;
    return '${text.substring(0, 900)}...';
  }
}
