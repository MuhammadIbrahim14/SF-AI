import '../data/interview_lab_repository.dart';
import '../models/interview_lab_models.dart';
import 'interview_lab_question_engine.dart';

/// Orchestrates per-answer evaluation, adaptive follow-ups, badges & progress.
class InterviewLabEvaluationEngine {
  InterviewLabEvaluationEngine({
    required InterviewLabRepository repository,
    required InterviewLabQuestionEngine questionEngine,
  })  : _repo = repository,
        _questions = questionEngine;

  final InterviewLabRepository _repo;
  final InterviewLabQuestionEngine _questions;

  /// Critiques an answer via AI and returns updated question + critique.
  Future<({InterviewLabQuestionModel question, InterviewLabAnswerCritique critique})>
      evaluateAnswer({
    required InterviewLabSessionModel session,
    required InterviewLabQuestionModel question,
    required String answer,
    required String candidateRole,
    required InterviewLabConfigModel config,
    required List<InterviewLabQuestionModel> allQuestions,
    bool isSkip = false,
  }) async {
    if (question.critiqueLocked &&
        question.critiqueAttempts > config.answerRegenerateLimit) {
      throw const InterviewLabException(
        code: 'critique-locked',
        message: 'Answer evaluation is locked for this question.',
      );
    }

    if (isSkip || answer.trim().isEmpty) {
      final penalty = config.skipConfidencePenalty;
      final now = DateTime.now();
      final skipped = question.copyWith(
        candidateAnswer: '',
        answeredAt: now,
        isAnswered: true,
        isSkipped: true,
        aiCritique:
            'Skipped — confidence penalty applied (−${penalty.toStringAsFixed(0)}).',
        scoreTechnical: 0,
        scoreCommunication: 20,
        scoreConfidence: (40 - penalty).clamp(0, 100),
        scoreProblemSolving: 0,
        scoreArchitecture: 0,
        scoreCodeQuality: 0,
        scoreOverall: (15 - penalty / 2).clamp(0, 100),
        strengths: const [],
        weaknesses: const ['Did not attempt the question'],
        improvement: 'Answer every question even briefly — silence costs confidence.',
        evaluationBreakdown: {
          'accuracy': 0,
          'completeness': 0,
          'confidence': (40 - penalty).clamp(0, 100),
          'overallQuality': 10,
        },
        critiqueLocked: true,
        critiqueAttempts: question.critiqueAttempts + 1,
        evaluatedAt: now,
      );
      final critique = InterviewLabAnswerCritique(
        feedback: skipped.aiCritique!,
        technical: 0,
        communication: 20,
        confidence: skipped.scoreConfidence!,
        problemSolving: 0,
        architecture: 0,
        codeQuality: 0,
        overall: skipped.scoreOverall!,
        breakdown: skipped.evaluationBreakdown,
        strengths: const [],
        weaknesses: skipped.weaknesses,
        improvement: skipped.improvement ?? '',
        shouldFollowUp: false,
        suggestedDifficulty: InterviewLabDifficulty.bumpDown(question.difficulty),
        provider: null,
      );
      return (question: skipped, critique: critique);
    }

    final prior = allQuestions.where((q) => q.isAnswered).toList();
    final critique = await _questions.critiqueAnswer(
      session: session,
      question: question,
      answer: answer,
      candidateRole: candidateRole,
      config: config,
      priorAnswered: prior,
    );

    final now = DateTime.now();
    final evaluated = question.copyWith(
      candidateAnswer: answer.trim(),
      answeredAt: now,
      isAnswered: true,
      isSkipped: false,
      aiCritique: critique.feedback,
      scoreTechnical: critique.technical,
      scoreCommunication: critique.communication,
      scoreConfidence: critique.confidence,
      scoreProblemSolving: critique.problemSolving,
      scoreArchitecture: critique.architecture,
      scoreCodeQuality: critique.codeQuality,
      scoreOverall: critique.overall,
      strengths: critique.strengths,
      weaknesses: critique.weaknesses,
      improvement: critique.improvement,
      evaluationBreakdown: critique.breakdown,
      critiqueLocked: true,
      critiqueAttempts: question.critiqueAttempts + 1,
      evaluatedAt: now,
      metadata: {
        ...question.metadata,
        'aiProvider': critique.provider,
        'taskType': InterviewLabAiTaskType.answerCritique,
        'suggestedDifficulty': critique.suggestedDifficulty,
        'shouldFollowUp': critique.shouldFollowUp,
      },
    );
    return (question: evaluated, critique: critique);
  }

  Future<InterviewLabQuestionModel?> maybeInsertFollowUp({
    required InterviewLabSessionModel session,
    required InterviewLabQuestionModel parent,
    required InterviewLabAnswerCritique critique,
    required String candidateAnswer,
    required String candidateRole,
    required InterviewLabConfigModel config,
    required List<InterviewLabQuestionModel> allQuestions,
    required int followUpsAlready,
  }) async {
    if (!config.adaptiveQuestioning) return null;
    if (!critique.shouldFollowUp) return null;
    if (followUpsAlready >= config.maxFollowUpQuestions) return null;
    if (candidateAnswer.trim().isEmpty) return null;

    final followUp = await _questions.generateFollowUp(
      session: session,
      parent: parent,
      candidateAnswer: candidateAnswer,
      candidateRole: candidateRole,
      difficulty: critique.suggestedDifficulty,
      critique: critique,
    );

    final insertAt = parent.orderIndex + 1;
    for (final q in allQuestions) {
      if (q.orderIndex >= insertAt) {
        await _repo.updateQuestion(
          q.copyWith(orderIndex: q.orderIndex + 1),
        );
      }
    }
    await _repo.upsertQuestions([followUp.copyWith(orderIndex: insertAt)]);
    final refreshed = await _repo.listQuestionsForSession(session.sessionId);
    return refreshed.firstWhere(
      (q) => q.isFollowUp && q.parentQuestionId == parent.questionId,
      orElse: () => refreshed.firstWhere((q) => q.orderIndex == insertAt),
    );
  }

  String resolveAdaptiveDifficulty({
    required InterviewLabConfigModel config,
    required String current,
    required InterviewLabAnswerCritique critique,
  }) {
    if (!config.difficultyScaling) return current;
    if (critique.overall >= 78) {
      return InterviewLabDifficulty.bumpUp(current);
    }
    if (critique.overall < 45 || critique.shouldFollowUp) {
      return InterviewLabDifficulty.bumpDown(current);
    }
    return critique.suggestedDifficulty;
  }

  Future<List<InterviewLabBadgeModel>> awardBadges({
    required InterviewLabSessionModel session,
    required InterviewLabReportModel report,
  }) async {
    final existing = await _repo.listBadgesForCandidate(session.candidateId);
    final owned = existing.map((b) => b.badgeKey).toSet();
    final now = DateTime.now();
    final awards = <InterviewLabBadgeModel>[];

    void consider(String key, String title, String description, bool ok) {
      if (!ok || owned.contains(key)) return;
      awards.add(
        InterviewLabBadgeModel(
          badgeId: '',
          candidateId: session.candidateId,
          badgeKey: key,
          title: title,
          description: description,
          sessionId: session.sessionId,
          roleTrack: session.roleTrack,
          awardedAt: now,
        ),
      );
    }

    consider(
      InterviewLabBadgeIds.flutterExpert,
      'Flutter Expert',
      'Strong Flutter-track interview performance.',
      session.roleTrack == InterviewLabRoleTrack.flutter &&
          report.technicalScore >= 80,
    );
    consider(
      InterviewLabBadgeIds.backendReady,
      'Backend Ready',
      'Demonstrated backend interview readiness.',
      session.roleTrack == InterviewLabRoleTrack.backend &&
          report.overallRating >= 75,
    );
    consider(
      InterviewLabBadgeIds.frontendReady,
      'Frontend Ready',
      'Demonstrated frontend interview readiness.',
      session.roleTrack == InterviewLabRoleTrack.frontend &&
          report.overallRating >= 75,
    );
    consider(
      InterviewLabBadgeIds.problemSolver,
      'Problem Solver',
      'High problem-solving scores in practice interviews.',
      report.problemSolvingScore >= 80,
    );
    consider(
      InterviewLabBadgeIds.communicationStar,
      'Communication Star',
      'Clear, professional technical communication.',
      report.communicationScore >= 82,
    );
    consider(
      InterviewLabBadgeIds.architectureThinker,
      'Architecture Thinker',
      'Strong architecture reasoning under interview pressure.',
      report.architectureScore >= 80,
    );
    consider(
      InterviewLabBadgeIds.jobReady,
      'Job Ready',
      'Reached Job Ready / Senior Ready interview level.',
      report.overallRating >= 85 ||
          report.interviewLevel == InterviewLabInterviewLevel.seniorReady,
    );
    consider(
      InterviewLabBadgeIds.adaptiveResilient,
      'Adaptive Resilient',
      'Handled follow-up pressure without collapsing scores.',
      report.confidenceScore >= 70 && report.overallRating >= 65,
    );

    for (final badge in awards) {
      await _repo.saveBadge(badge);
    }
    return awards;
  }

  Future<InterviewLabProgressModel> updateProgress({
    required InterviewLabSessionModel session,
    required InterviewLabReportModel report,
  }) async {
    final prev =
        await _repo.getProgress(session.candidateId) ??
            InterviewLabProgressModel.empty(session.candidateId);

    final n = prev.completedInterviews + 1;
    final avgOverall =
        ((prev.averageOverall * prev.completedInterviews) + report.overallRating) /
            n;

    Map<String, double> skills = {
      'Technical': _rolling(prev.skillAverages['Technical'], report.technicalScore, prev.completedInterviews, n),
      'Communication': _rolling(prev.skillAverages['Communication'], report.communicationScore, prev.completedInterviews, n),
      'Confidence': _rolling(prev.skillAverages['Confidence'], report.confidenceScore, prev.completedInterviews, n),
      'Problem Solving': _rolling(prev.skillAverages['Problem Solving'], report.problemSolvingScore, prev.completedInterviews, n),
      'Architecture': _rolling(prev.skillAverages['Architecture'], report.architectureScore, prev.completedInterviews, n),
      'Code Quality': _rolling(prev.skillAverages['Code Quality'], report.codeQualityScore, prev.completedInterviews, n),
      'Professional Readiness': _rolling(
        prev.skillAverages['Professional Readiness'],
        report.professionalReadinessScore,
        prev.completedInterviews,
        n,
      ),
    };

    final trends = <String, List<double>>{};
    for (final e in skills.entries) {
      final hist = List<double>.from(prev.skillTrends[e.key] ?? const []);
      final latest = switch (e.key) {
        'Technical' => report.technicalScore,
        'Communication' => report.communicationScore,
        'Confidence' => report.confidenceScore,
        'Problem Solving' => report.problemSolvingScore,
        'Architecture' => report.architectureScore,
        'Code Quality' => report.codeQualityScore,
        'Professional Readiness' => report.professionalReadinessScore,
        _ => e.value,
      };
      hist.add(latest);
      while (hist.length > 12) {
        hist.removeAt(0);
      }
      trends[e.key] = hist;
    }

    final tracks = Map<String, double>.from(prev.trackAverages);
    tracks[session.roleTrack] = _rolling(
      tracks[session.roleTrack],
      report.overallRating,
      prev.completedInterviews,
      n,
    );

    final insights = _buildInsights(skills, trends, session.roleTrack);

    final next = InterviewLabProgressModel(
      candidateId: session.candidateId,
      completedInterviews: n,
      averageOverall: (avgOverall * 10).round() / 10,
      skillAverages: skills,
      skillTrends: trends,
      trackAverages: tracks,
      insights: insights,
      lastSessionId: session.sessionId,
      lastInterviewLevel: report.interviewLevel,
      updatedAt: DateTime.now(),
    );
    await _repo.upsertProgress(next);
    return next;
  }

  double _rolling(double? prevAvg, double score, int prevCount, int nextCount) {
    if (prevCount <= 0 || prevAvg == null) return score;
    return ((prevAvg * prevCount) + score) / nextCount;
  }

  List<String> _buildInsights(
    Map<String, double> skills,
    Map<String, List<double>> trends,
    String roleTrack,
  ) {
    final out = <String>[];
    for (final e in skills.entries) {
      final hist = trends[e.key] ?? const <double>[];
      if (hist.length >= 2) {
        final delta = hist.last - hist.first;
        if (delta >= 8) {
          out.add('${e.key} improving');
        } else if (delta <= -8) {
          out.add('${e.key} declining — prioritize practice');
        }
      }
      if (e.value >= 80) {
        out.add('${e.key} strong');
      } else if (e.value > 0 && e.value < 55) {
        out.add('${e.key} weak');
      } else if (e.value >= 55 && e.value < 70) {
        out.add('${e.key} average');
      }
    }
    out.add(
      '${InterviewLabRoleTrack.displayLabel(roleTrack)} track avg '
      '${(skills['Technical'] ?? 0).toStringAsFixed(0)} technical',
    );
    return out.take(8).toList();
  }
}
