import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../copilot/models/copilot_ai_request_model.dart';
import '../../copilot/models/copilot_ai_response_model.dart';
import '../../copilot/services/ai_gateway_client.dart';
import '../data/interview_lab_repository.dart';
import '../models/interview_lab_models.dart';

/// Builds Interview Lab reports via AI debrief.
/// Falls back to evidence-based scoring when AI is unavailable.
class InterviewLabReportEngine {
  InterviewLabReportEngine(
    this._repo, {
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
  })  : _gateway = gatewayClient ?? AiGatewayClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final InterviewLabRepository _repo;
  final AiGatewayClient _gateway;
  final FirebaseAuth _auth;

  Future<({InterviewLabReportModel report, InterviewLabResultModel result})>
      buildAndSave({
    required InterviewLabSessionModel session,
    required List<InterviewLabQuestionModel> questions,
    InterviewLabConfigModel? config,
    required String candidateRole,
  }) async {
    final rules = (config ?? InterviewLabConfigModel.defaults).scoringRules;
    final answered = questions.where((q) => q.isAnswered).toList();

    double avg(double? Function(InterviewLabQuestionModel q) pick) {
      if (answered.isEmpty) return 0;
      final values = answered.map(pick).whereType<double>().toList();
      if (values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final technical = avg((q) => q.scoreTechnical);
    final communication = avg((q) => q.scoreCommunication);
    final confidence = avg((q) => q.scoreConfidence);
    final problemSolving = avg((q) => q.scoreProblemSolving);
    final architecture = avg((q) => q.scoreArchitecture);
    final codeQuality = avg((q) => q.scoreCodeQuality);
    final professionalism = avg((q) => q.scoreCommunication) * 0.6 +
        avg((q) => q.scoreConfidence) * 0.4;

    final transcript = answered.map((q) {
      return '''
Q${q.orderIndex + 1}${q.isFollowUp ? ' (follow-up)' : ''} [${q.category}/${q.difficulty}]
${q.prompt}
Answer: ${q.isSkipped ? '(skipped)' : (q.candidateAnswer ?? '')}
AI feedback: ${q.aiCritique ?? 'n/a'}
Scores T/C/Conf/PS/Arch: ${q.scoreTechnical}/${q.scoreCommunication}/${q.scoreConfidence}/${q.scoreProblemSolving}/${q.scoreArchitecture}
Strengths: ${q.strengths.join('; ')}
Weaknesses: ${q.weaknesses.join('; ')}
Improvement: ${q.improvement ?? ''}
''';
    }).join('\n---\n');

    final request = CopilotAiRequestModel(
      requestId: 'interview_lab_debrief_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? session.candidateId,
      role: candidateRole,
      accountType: 'professional',
      taskType: InterviewLabAiTaskType.debrief,
      userMessage: '''
Produce a professional Senior Interviewer debrief for SkillForge AI Interview Lab.
roleTrack=${session.roleTrack}
difficulty=${session.difficulty}
targetJob=${session.targetJobTitle ?? 'n/a'}
strictness=${(config ?? InterviewLabConfigModel.defaults).evaluationStrictness}
seedScores: technical=$technical communication=$communication confidence=$confidence problemSolving=$problemSolving architecture=$architecture codeQuality=$codeQuality professionalism=$professionalism

TRANSCRIPT:
$transcript

Return structuredData.report with:
summary, overallRating (0-100),
technicalScore, communicationScore, confidenceScore, problemSolvingScore,
architectureScore, codeQualityScore, professionalismScore, professionalReadinessScore,
scoreExplanations: map of dimension -> short explanation,
strengths[], weakSkills[], skillsDemonstrated[], skillsMissing[], mistakes[],
recommendations[], learningPath[], recommendedCourses[], recommendedProjects[],
recommendedCertifications[], industryReadiness (string),
interviewLevel (Beginner|Junior|Intermediate|Advanced|Senior Ready).
Do NOT invent template fluff — ground claims in the transcript.
''',
      pageContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'roleTrack': session.roleTrack,
      },
      safeAppContext: {
        'module': 'interview_lab',
        'sessionId': session.sessionId,
        'task': 'debrief',
      },
      languageHint: 'en',
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'No protected-attribute judgments.',
        'No hiring decisions — practice feedback only.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gateway.send(request).timeout(
      const Duration(seconds: 90),
      onTimeout: () => CopilotAiResponseModel(
        requestId: request.requestId,
        status: CopilotAiResponseStatus.unavailable,
        taskType: request.taskType,
        role: request.role,
        title: 'Timeout',
        message: 'AI debrief timed out.',
        requiresManualReview: true,
        provider: 'timeout',
      ),
    );
    if (!response.isSuccess) {
      // Timer-forced / gateway-down finish must still produce a report from
      // scored answers — never leave the candidate on an infinite loader.
      return _buildAndSaveEvidenceReport(
        session: session,
        questions: questions,
        config: config ?? InterviewLabConfigModel.defaults,
        technical: technical,
        communication: communication,
        confidence: confidence,
        problemSolving: problemSolving,
        architecture: architecture,
        codeQuality: codeQuality,
        professionalism: professionalism,
        reason: response.message.isNotEmpty
            ? response.message
            : 'AI debrief unavailable',
      );
    }

    final rawReport = response.structuredData['report'];
    if (rawReport is! Map) {
      return _buildAndSaveEvidenceReport(
        session: session,
        questions: questions,
        config: config ?? InterviewLabConfigModel.defaults,
        technical: technical,
        communication: communication,
        confidence: confidence,
        problemSolving: problemSolving,
        architecture: architecture,
        codeQuality: codeQuality,
        professionalism: professionalism,
        reason: 'AI returned an unusable interview debrief',
      );
    }
    final map = Map<String, dynamic>.from(rawReport);

    double pick(String key, double fallback) {
      final v = map[key];
      if (v is num) return v.toDouble().clamp(0, 100);
      return fallback;
    }

    List<String> list(String key) {
      final v = map[key];
      if (v is Iterable) {
        return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    final scoreExplanations = <String, String>{};
    final expl = map['scoreExplanations'];
    if (expl is Map) {
      for (final e in expl.entries) {
        scoreExplanations[e.key.toString()] = e.value?.toString() ?? '';
      }
    }

    final tech = pick('technicalScore', technical);
    final comm = pick('communicationScore', communication);
    final conf = pick('confidenceScore', confidence);
    final ps = pick('problemSolvingScore', problemSolving);
    final arch = pick('architectureScore', architecture);
    final code = pick('codeQualityScore', codeQuality);
    final prof = pick('professionalismScore', professionalism);
    final readiness = pick('professionalReadinessScore', (tech + comm + ps) / 3);
    var overall = pick('overallRating', 0);
    if (overall <= 0) {
      overall = rules.computeOverall(
        technical: tech,
        communication: comm,
        confidence: conf,
        problemSolving: ps,
        professionalism: prof,
        architecture: arch,
        codeQuality: code,
      );
    }

    final label = overall >= rules.passThreshold
        ? 'strong'
        : overall >= rules.holdThreshold
            ? 'developing'
            : 'needs_work';

    final levelRaw = map['interviewLevel']?.toString() ?? '';
    final level = [
      InterviewLabInterviewLevel.beginner,
      InterviewLabInterviewLevel.junior,
      InterviewLabInterviewLevel.intermediate,
      InterviewLabInterviewLevel.advanced,
      InterviewLabInterviewLevel.seniorReady,
    ].contains(levelRaw)
        ? levelRaw
        : InterviewLabInterviewLevel.fromScore(overall);

    final summary = map['summary']?.toString().trim() ?? '';
    if (summary.isEmpty && list('strengths').isEmpty) {
      return _buildAndSaveEvidenceReport(
        session: session,
        questions: questions,
        config: config ?? InterviewLabConfigModel.defaults,
        technical: technical,
        communication: communication,
        confidence: confidence,
        problemSolving: problemSolving,
        architecture: architecture,
        codeQuality: codeQuality,
        professionalism: professionalism,
        reason: 'AI debrief was empty',
      );
    }

    final now = DateTime.now();
    final report = InterviewLabReportModel(
      reportId: '',
      sessionId: session.sessionId,
      candidateId: session.candidateId,
      technicalScore: tech,
      communicationScore: comm,
      confidenceScore: conf,
      professionalismScore: prof,
      problemSolvingScore: ps,
      architectureScore: arch,
      codeQualityScore: code,
      professionalReadinessScore: readiness,
      overallRating: overall,
      overallLabel: label,
      interviewLevel: level,
      industryReadiness: map['industryReadiness']?.toString() ?? level,
      scoreExplanations: scoreExplanations,
      strengths: list('strengths'),
      weakSkills: list('weakSkills'),
      skillsDemonstrated: list('skillsDemonstrated'),
      skillsMissing: list('skillsMissing'),
      mistakes: list('mistakes'),
      recommendations: list('recommendations'),
      learningPath: list('learningPath'),
      recommendedCourses: list('recommendedCourses'),
      recommendedProjects: list('recommendedProjects'),
      recommendedCertifications: list('recommendedCertifications'),
      summary: summary.isEmpty
          ? 'Interview completed for ${InterviewLabRoleTrack.displayLabel(session.roleTrack)}.'
          : summary,
      aiProviderUsed: response.provider,
      rawAiPayload: {
        'interviewLevel': level,
        'provider': response.provider,
        'taskType': InterviewLabAiTaskType.debrief,
      },
      createdAt: now,
      updatedAt: now,
    );

    final reportId = await _repo.saveReport(report);
    final result = InterviewLabResultModel(
      resultId: '',
      sessionId: session.sessionId,
      candidateId: session.candidateId,
      reportId: reportId,
      roleTrack: session.roleTrack,
      difficulty: session.difficulty,
      overallScore: overall,
      outcome: label,
      technicalScore: tech,
      communicationScore: comm,
      confidenceScore: conf,
      problemSolvingScore: ps,
      interviewLevel: level,
      createdAt: now,
    );
    final resultId = await _repo.saveResult(result);

    return (
      report: InterviewLabReportModel.fromMap({
        ...report.toMap(useServerTimestamps: false),
        'reportId': reportId,
        'createdAt': now,
        'updatedAt': now,
      }, docId: reportId),
      result: InterviewLabResultModel(
        resultId: resultId,
        sessionId: session.sessionId,
        candidateId: session.candidateId,
        reportId: reportId,
        roleTrack: session.roleTrack,
        difficulty: session.difficulty,
        overallScore: overall,
        outcome: label,
        technicalScore: tech,
        communicationScore: comm,
        confidenceScore: conf,
        problemSolvingScore: ps,
        interviewLevel: level,
        createdAt: now,
      ),
    );
  }

  /// Offline / AI-failure debrief grounded only in scored session answers.
  Future<({InterviewLabReportModel report, InterviewLabResultModel result})>
      _buildAndSaveEvidenceReport({
    required InterviewLabSessionModel session,
    required List<InterviewLabQuestionModel> questions,
    required InterviewLabConfigModel config,
    required double technical,
    required double communication,
    required double confidence,
    required double problemSolving,
    required double architecture,
    required double codeQuality,
    required double professionalism,
    required String reason,
  }) async {
    final rules = config.scoringRules;
    final answered = questions.where((q) => q.isAnswered).toList();
    final attempted = answered.where((q) => !q.isSkipped).toList();
    final skipped = answered.where((q) => q.isSkipped).toList();

    final overall = answered.isEmpty
        ? 0.0
        : rules.computeOverall(
            technical: technical,
            communication: communication,
            confidence: confidence,
            problemSolving: problemSolving,
            professionalism: professionalism,
            architecture: architecture,
            codeQuality: codeQuality,
          );

    final label = overall >= rules.passThreshold
        ? 'strong'
        : overall >= rules.holdThreshold
            ? 'developing'
            : 'needs_work';
    final level = InterviewLabInterviewLevel.fromScore(overall);

    final strengths = <String>{
      for (final q in attempted) ...q.strengths,
    }.take(6).toList();
    final weaknesses = <String>{
      for (final q in answered) ...q.weaknesses,
      if (skipped.isNotEmpty) 'Skipped ${skipped.length} question(s)',
      if (attempted.isEmpty) 'No answers were submitted before the session ended',
    }.take(8).toList();
    final recommendations = <String>[
      if (skipped.isNotEmpty)
        'Attempt every question — skips reduce confidence and completeness.',
      if (technical < 60)
        'Review core ${InterviewLabRoleTrack.displayLabel(session.roleTrack)} concepts and practice aloud.',
      if (communication < 60)
        'Structure answers: situation → approach → trade-offs → result.',
      if (problemSolving < 60)
        'Narrate problem-solving steps before jumping to a final answer.',
      'Re-run a short Interview Lab session focusing on weak categories.',
    ];

    final summary = answered.isEmpty
        ? 'Session ended before scored answers were available ($reason). Practice again to generate a richer debrief.'
        : 'Evidence-based debrief from ${attempted.length} answered and ${skipped.length} skipped question(s) '
            'for ${InterviewLabRoleTrack.displayLabel(session.roleTrack)} ($reason).';

    final now = DateTime.now();
    final report = InterviewLabReportModel(
      reportId: '',
      sessionId: session.sessionId,
      candidateId: session.candidateId,
      technicalScore: technical,
      communicationScore: communication,
      confidenceScore: confidence,
      professionalismScore: professionalism,
      problemSolvingScore: problemSolving,
      architectureScore: architecture,
      codeQualityScore: codeQuality,
      professionalReadinessScore: (technical + communication + problemSolving) / 3,
      overallRating: overall,
      overallLabel: label,
      interviewLevel: level,
      industryReadiness: level,
      scoreExplanations: {
        'technical': 'Average of scored technical critiques in this session.',
        'communication': 'Average of scored communication critiques.',
        'confidence': 'Average confidence including skip penalties.',
        'problemSolving': 'Average problem-solving critiques.',
        'source': 'local_evidence',
        'fallbackReason': reason,
      },
      strengths: strengths,
      weakSkills: weaknesses,
      skillsDemonstrated: strengths,
      skillsMissing: weaknesses,
      mistakes: [
        for (final q in skipped) 'Skipped: ${q.prompt}',
      ].take(5).toList(),
      recommendations: recommendations,
      learningPath: recommendations,
      recommendedCourses: const [],
      recommendedProjects: const [],
      recommendedCertifications: const [],
      summary: summary,
      aiProviderUsed: 'local_evidence',
      rawAiPayload: {
        'fallback': true,
        'reason': reason,
        'answeredCount': answered.length,
        'skippedCount': skipped.length,
        'taskType': InterviewLabAiTaskType.debrief,
      },
      createdAt: now,
      updatedAt: now,
    );

    final reportId = await _repo.saveReport(report);
    final result = InterviewLabResultModel(
      resultId: '',
      sessionId: session.sessionId,
      candidateId: session.candidateId,
      reportId: reportId,
      roleTrack: session.roleTrack,
      difficulty: session.difficulty,
      overallScore: overall,
      outcome: label,
      technicalScore: technical,
      communicationScore: communication,
      confidenceScore: confidence,
      problemSolvingScore: problemSolving,
      interviewLevel: level,
      createdAt: now,
    );
    final resultId = await _repo.saveResult(result);

    return (
      report: InterviewLabReportModel.fromMap({
        ...report.toMap(useServerTimestamps: false),
        'reportId': reportId,
        'createdAt': now,
        'updatedAt': now,
      }, docId: reportId),
      result: InterviewLabResultModel(
        resultId: resultId,
        sessionId: session.sessionId,
        candidateId: session.candidateId,
        reportId: reportId,
        roleTrack: session.roleTrack,
        difficulty: session.difficulty,
        overallScore: overall,
        outcome: label,
        technicalScore: technical,
        communicationScore: communication,
        confidenceScore: confidence,
        problemSolvingScore: problemSolving,
        interviewLevel: level,
        createdAt: now,
      ),
    );
  }
}
