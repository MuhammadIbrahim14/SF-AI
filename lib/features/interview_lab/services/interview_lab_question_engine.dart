import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/app_logger.dart';
import '../../copilot/models/copilot_ai_request_model.dart';
import '../../copilot/models/copilot_ai_response_model.dart';
import '../../copilot/services/ai_gateway_client.dart';
import '../models/interview_lab_models.dart';

/// Per-answer AI critique result (persisted onto question docs).
class InterviewLabAnswerCritique {
  const InterviewLabAnswerCritique({
    required this.feedback,
    required this.technical,
    required this.communication,
    required this.confidence,
    required this.problemSolving,
    required this.architecture,
    required this.codeQuality,
    required this.overall,
    required this.breakdown,
    required this.strengths,
    required this.weaknesses,
    required this.improvement,
    required this.shouldFollowUp,
    required this.suggestedDifficulty,
    required this.provider,
  });

  final String feedback;
  final double technical;
  final double communication;
  final double confidence;
  final double problemSolving;
  final double architecture;
  final double codeQuality;
  final double overall;
  final Map<String, dynamic> breakdown;
  final List<String> strengths;
  final List<String> weaknesses;
  final String improvement;
  final bool shouldFollowUp;
  final String suggestedDifficulty;
  final String? provider;
}

/// Generates / adapts interview questions via AI Gateway — no hardcoded banks.
class InterviewLabQuestionEngine {
  InterviewLabQuestionEngine({
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
  })  : _gateway = gatewayClient ?? AiGatewayClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final AiGatewayClient _gateway;
  final FirebaseAuth _auth;
  final _rng = Random();

  Future<List<InterviewLabQuestionModel>> generateQuestions({
    required InterviewLabSessionModel session,
    required int count,
    required String candidateRole,
    String? uniquenessSeed,
  }) async {
    final seed = uniquenessSeed ??
        '${session.sessionId}_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(1 << 30)}';

    final request = CopilotAiRequestModel(
      requestId: 'interview_lab_qb_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? session.candidateId,
      role: candidateRole,
      accountType: 'professional',
      taskType: InterviewLabAiTaskType.questionBank,
      userMessage: _buildPrompt(
        session: session,
        count: count,
        uniquenessSeed: seed,
      ),
      pageContext: {
        'module': 'interview_lab',
        'roleTrack': session.roleTrack,
        'difficulty': session.difficulty,
        'questionCount': count,
        'uniquenessSeed': seed,
        if (session.targetJobId != null) 'targetJobId': session.targetJobId,
        if (session.targetJobTitle != null)
          'targetJobTitle': session.targetJobTitle,
      },
      safeAppContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'roleTrack': session.roleTrack,
        'difficulty': session.difficulty,
        'uniquenessSeed': seed,
      },
      languageHint: 'en',
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'Do not include answer keys that reveal full solutions.',
        'Questions must match roleTrack and difficulty.',
        'Randomize topics; avoid repeating generic interview clichés.',
        'No protected-attribute questions.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gateway.send(request);
    if (!response.isSuccess) {
      AppLogger.warn('Interview question generation request failed.');
      throw InterviewLabException(
        code: 'ai-unavailable',
        message: response.message.isNotEmpty
            ? response.message
            : 'AI Gateway could not generate interview questions.',
      );
    }

    final parsed = _parseQuestions(
      response: response,
      session: session,
      count: count,
      uniquenessSeed: seed,
    );
    if (parsed.isEmpty) {
      throw const InterviewLabException(
        code: 'invalid-ai-payload',
        message: 'AI returned no usable interview questions.',
      );
    }

    // Randomize order for uniqueness / anti-pattern predictability.
    final shuffled = List<InterviewLabQuestionModel>.from(parsed)..shuffle(_rng);
    return [
      for (var i = 0; i < shuffled.length; i++)
        shuffled[i].copyWith(orderIndex: i),
    ];
  }

  Future<InterviewLabAnswerCritique> critiqueAnswer({
    required InterviewLabSessionModel session,
    required InterviewLabQuestionModel question,
    required String answer,
    required String candidateRole,
    required InterviewLabConfigModel config,
    required List<InterviewLabQuestionModel> priorAnswered,
  }) async {
    if (question.critiqueLocked &&
        question.critiqueAttempts > config.answerRegenerateLimit) {
      throw const InterviewLabException(
        code: 'critique-locked',
        message: 'This answer was already evaluated and cannot be regenerated.',
      );
    }

    final priorSnippets = priorAnswered
        .where((q) => q.questionId != question.questionId && q.isAnswered)
        .take(4)
        .map((q) {
          final a = q.candidateAnswer ?? '';
          final clipped = a.length <= 280 ? a : a.substring(0, 280);
          return 'Q: ${q.prompt}\nA: $clipped';
        })
        .join('\n---\n');

    final request = CopilotAiRequestModel(
      requestId: 'interview_lab_crit_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? session.candidateId,
      role: candidateRole,
      accountType: 'professional',
      taskType: InterviewLabAiTaskType.answerCritique,
      userMessage: '''
You are a Senior Technical Interviewer evaluating one practice answer.
roleTrack=${session.roleTrack}
targetJob=${session.targetJobTitle ?? 'n/a'}
sessionDifficulty=${session.difficulty}
questionDifficulty=${question.difficulty}
category=${question.category}
strictness=${config.evaluationStrictness}
expectedFocus=${question.expectedFocus.join(', ')}
QUESTION:
${question.prompt}
CANDIDATE ANSWER:
$answer
RECENT CONTEXT:
${priorSnippets.isEmpty ? 'none' : priorSnippets}

Return structuredData.critique with:
feedback (string),
scores: technical, communication, confidence, problemSolving, architecture, codeQuality, overall (0-100),
breakdown: accuracy, completeness, technicalDepth, logic, problemSolving, professionalCommunication, confidence, grammar, terminology, overallQuality (0-100 each),
strengths (string[]), weaknesses (string[]), improvement (string),
shouldFollowUp (bool), suggestedDifficulty (easy|medium|hard).
Be a realistic senior interviewer — not generic praise.
''',
      pageContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'questionId': question.questionId,
        'strictness': config.evaluationStrictness,
      },
      safeAppContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'task': 'answer_critique',
      },
      languageHint: 'en',
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'No protected-attribute judgments.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gateway.send(request);
    if (!response.isSuccess) {
      throw InterviewLabException(
        code: 'ai-unavailable',
        message: response.message.isNotEmpty
            ? response.message
            : 'AI evaluation is temporarily unavailable.',
      );
    }

    return _parseCritique(response, fallbackDifficulty: question.difficulty);
  }

  Future<InterviewLabQuestionModel> generateFollowUp({
    required InterviewLabSessionModel session,
    required InterviewLabQuestionModel parent,
    required String candidateAnswer,
    required String candidateRole,
    required String difficulty,
    required InterviewLabAnswerCritique critique,
  }) async {
    final request = CopilotAiRequestModel(
      requestId: 'interview_lab_fu_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? session.candidateId,
      role: candidateRole,
      accountType: 'professional',
      taskType: InterviewLabAiTaskType.followUp,
      userMessage: '''
Generate ONE natural follow-up interview question as a Senior Technical Interviewer.
roleTrack=${session.roleTrack}
targetJob=${session.targetJobTitle ?? 'n/a'}
difficulty=$difficulty
PARENT QUESTION:
${parent.prompt}
CANDIDATE SAID:
$candidateAnswer
EVALUATION NOTES:
${critique.feedback}
Weaknesses: ${critique.weaknesses.join('; ')}

Return structuredData.followUp with prompt, category, expectedFocus[].
Make it conversational (e.g. "Why X over Y?") — unique to this answer.
''',
      pageContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'parentQuestionId': parent.questionId,
      },
      safeAppContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'task': 'follow_up',
      },
      languageHint: 'en',
      constraints: const [
        'Return JSON only.',
        'One follow-up only.',
        'Do not write Firestore.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gateway.send(request);
    if (!response.isSuccess) {
      throw InterviewLabException(
        code: 'ai-unavailable',
        message: response.message.isNotEmpty
            ? response.message
            : 'AI could not generate a follow-up question.',
      );
    }

    final structured = response.structuredData;
    Map<String, dynamic>? map;
    final fu = structured['followUp'];
    if (fu is Map) {
      map = Map<String, dynamic>.from(fu);
    } else if (structured['question'] is Map) {
      map = Map<String, dynamic>.from(structured['question'] as Map);
    } else if (structured['questions'] is List &&
        (structured['questions'] as List).isNotEmpty &&
        (structured['questions'] as List).first is Map) {
      map = Map<String, dynamic>.from(
        (structured['questions'] as List).first as Map,
      );
    }
    final prompt = (map?['prompt'] ?? map?['question'] ?? map?['text'] ?? '')
        .toString()
        .trim();
    if (prompt.isEmpty) {
      throw const InterviewLabException(
        code: 'invalid-ai-payload',
        message: 'AI returned an empty follow-up question.',
      );
    }
    final focuses = (map?['expectedFocus'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return InterviewLabQuestionModel(
      questionId: '',
      sessionId: session.sessionId,
      orderIndex: 0,
      prompt: prompt,
      difficulty: difficulty,
      roleTrack: session.roleTrack,
      category: map?['category']?.toString() ??
          InterviewLabQuestionCategory.communication,
      expectedFocus: focuses,
      isFollowUp: true,
      parentQuestionId: parent.questionId,
      createdAt: DateTime.now(),
      metadata: {
        'aiProvider': response.provider,
        'taskType': InterviewLabAiTaskType.followUp,
      },
    );
  }

  String _buildPrompt({
    required InterviewLabSessionModel session,
    required int count,
    required String uniquenessSeed,
  }) {
    final meta = session.metadata;
    final focusTopics = (meta['focusTopics'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .join(', ') ??
        '';
    final promptHint = meta['promptHint']?.toString() ?? '';
    final templateTitle = meta['templateTitle']?.toString() ?? '';
    final templateDescription = meta['templateDescription']?.toString() ?? '';
    final categories = (meta['suggestedCategories'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .join(', ') ??
        '';

    return '''
Generate $count UNIQUE interview questions for SkillForge AI Interview Lab.
Act as a Senior Technical Interviewer.
roleTrack=${session.roleTrack}
displayRole=${InterviewLabRoleTrack.displayLabel(session.roleTrack)}
templateTitle=${templateTitle.isEmpty ? 'n/a' : templateTitle}
templateDescription=${templateDescription.isEmpty ? 'n/a' : templateDescription}
focusTopics=${focusTopics.isEmpty ? 'n/a' : focusTopics}
adminPromptHint=${promptHint.isEmpty ? 'n/a' : promptHint}
preferredCategories=${categories.isEmpty ? 'n/a' : categories}
difficulty=${session.difficulty}
targetJobTitle=${session.targetJobTitle ?? 'n/a'}
uniquenessSeed=$uniquenessSeed
Mix categories across: concept, scenario, debugging, architecture, best_practices, optimization, behavioral, communication, real_world, technical, problem_solving, short_answer.
If focusTopics or adminPromptHint are provided, prioritize those skills and stacks.
Return structuredData.questions as an array of objects with fields:
prompt (string), category (one of the categories above), expectedFocus (string[]), difficulty (easy|medium|hard).
Every interview must feel unique — vary scenarios using uniquenessSeed.
No hardcoded generic fluff.
''';
  }

  List<InterviewLabQuestionModel> _parseQuestions({
    required CopilotAiResponseModel response,
    required InterviewLabSessionModel session,
    required int count,
    required String uniquenessSeed,
  }) {
    final structured = response.structuredData;
    dynamic rawList = structured['questions'];
    if (rawList == null && structured['interviewKit'] is Map) {
      rawList = (structured['interviewKit'] as Map)['questions'];
    }
    if (rawList is String) {
      try {
        rawList = jsonDecode(rawList);
      } catch (_) {
        AppLogger.debug('Interview question response was not valid JSON.');
      }
    }
    if (rawList is! List) return const [];

    final now = DateTime.now();
    final seen = <String>{};
    final out = <InterviewLabQuestionModel>[];
    for (var i = 0; i < rawList.length && out.length < count; i++) {
      final item = rawList[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final prompt = (map['prompt'] ?? map['question'] ?? map['text'] ?? '')
          .toString()
          .trim();
      if (prompt.isEmpty) continue;
      final key = prompt.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      final focuses = (map['expectedFocus'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final diff = InterviewLabDifficulty.isValid(
            map['difficulty']?.toString() ?? '',
          )
          ? map['difficulty'].toString()
          : session.difficulty;
      out.add(
        InterviewLabQuestionModel(
          questionId: '',
          sessionId: session.sessionId,
          orderIndex: out.length,
          prompt: prompt,
          difficulty: diff,
          roleTrack: session.roleTrack,
          category: map['category']?.toString() ??
              InterviewLabQuestionCategory.technical,
          expectedFocus: focuses,
          createdAt: now,
          metadata: {
            'aiProvider': response.provider,
            'taskType': InterviewLabAiTaskType.questionBank,
            'uniquenessSeed': uniquenessSeed,
          },
        ),
      );
    }
    return out;
  }

  InterviewLabAnswerCritique _parseCritique(
    CopilotAiResponseModel response, {
    required String fallbackDifficulty,
  }) {
    final structured = response.structuredData;
    Map<String, dynamic> critique = {};
    final raw = structured['critique'];
    if (raw is Map) {
      critique = Map<String, dynamic>.from(raw);
    } else if (structured.isNotEmpty) {
      critique = Map<String, dynamic>.from(structured);
    }

    double score(String key, [String? alt]) {
      final scores = critique['scores'];
      if (scores is Map && scores[key] != null) {
        final v = scores[key];
        if (v is num) return v.toDouble().clamp(0, 100);
      }
      final direct = critique[key] ?? (alt == null ? null : critique[alt]);
      if (direct is num) return direct.toDouble().clamp(0, 100);
      return 0;
    }

    final breakdownRaw = critique['breakdown'];
    final breakdown = breakdownRaw is Map
        ? Map<String, dynamic>.from(breakdownRaw)
        : <String, dynamic>{};

    final strengths = (critique['strengths'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final weaknesses = (critique['weaknesses'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final suggested = critique['suggestedDifficulty']?.toString() ?? '';
    final feedback = (critique['feedback'] ?? critique['summary'] ?? '')
        .toString()
        .trim();
    if (feedback.isEmpty && score('overall') <= 0 && score('technical') <= 0) {
      throw const InterviewLabException(
        code: 'invalid-ai-payload',
        message: 'AI returned an unusable answer evaluation.',
      );
    }

    final technical = score('technical');
    final communication = score('communication');
    final confidence = score('confidence');
    final problemSolving = score('problemSolving', 'problem_solving');
    final architecture = score('architecture');
    final codeQuality = score('codeQuality', 'code_quality');
    var overall = score('overall');
    if (overall <= 0) {
      final parts = [
        technical,
        communication,
        confidence,
        problemSolving,
        if (architecture > 0) architecture,
        if (codeQuality > 0) codeQuality,
      ].where((e) => e > 0).toList();
      overall = parts.isEmpty
          ? 0
          : parts.reduce((a, b) => a + b) / parts.length;
    }

    return InterviewLabAnswerCritique(
      feedback: feedback.isEmpty ? 'Evaluation recorded.' : feedback,
      technical: technical,
      communication: communication,
      confidence: confidence,
      problemSolving: problemSolving,
      architecture: architecture > 0 ? architecture : technical,
      codeQuality: codeQuality > 0 ? codeQuality : technical,
      overall: overall,
      breakdown: breakdown,
      strengths: strengths,
      weaknesses: weaknesses,
      improvement: critique['improvement']?.toString() ?? '',
      shouldFollowUp: critique['shouldFollowUp'] == true,
      suggestedDifficulty: InterviewLabDifficulty.isValid(suggested)
          ? suggested
          : fallbackDifficulty,
      provider: response.provider,
    );
  }
}

class InterviewLabException implements Exception {
  const InterviewLabException({
    required this.code,
    required this.message,
    this.sessionId,
  });

  final String code;
  final String message;
  final String? sessionId;

  @override
  String toString() => message;
}
