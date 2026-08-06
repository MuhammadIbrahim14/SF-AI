import '../data/interview_lab_repository.dart';
import '../models/interview_lab_models.dart';
import 'interview_lab_evaluation_engine.dart';
import 'interview_lab_history_manager.dart';
import 'interview_lab_question_engine.dart';

/// Lifecycle orchestration for Interview Lab sessions.
class InterviewLabSessionManager {
  InterviewLabSessionManager({
    required InterviewLabRepository repository,
    required InterviewLabQuestionEngine questionEngine,
    required InterviewLabHistoryManager historyManager,
    required InterviewLabEvaluationEngine evaluationEngine,
  })  : _repo = repository,
        _questions = questionEngine,
        _history = historyManager,
        _evaluation = evaluationEngine;

  final InterviewLabRepository _repo;
  final InterviewLabQuestionEngine _questions;
  final InterviewLabHistoryManager _history;
  final InterviewLabEvaluationEngine _evaluation;

  Future<InterviewLabSessionModel> startSession({
    required String candidateId,
    required String candidateRole,
    required String roleTrack,
    String? difficulty,
    String? targetJobId,
    String? targetJobTitle,
    String? templateId,
    String? companyId,
    int? questionCountOverride,
  }) async {
    final config = await _repo.getConfig();
    if (!config.enabled) {
      throw const InterviewLabException(
        code: 'lab-disabled',
        message: 'AI Interview Lab is currently disabled by admin.',
      );
    }

    final existing = await _repo.findResumableSession(candidateId);
    if (existing != null) {
      throw InterviewLabException(
        code: 'active-session-exists',
        message:
            'You already have an interview in progress. Resume or finish it first.',
        sessionId: existing.sessionId,
      );
    }

    final track = InterviewLabRoleTrack.isUsable(roleTrack)
        ? InterviewLabRoleTrack.slugify(roleTrack)
        : InterviewLabRoleTrack.general;
    final diff = InterviewLabDifficulty.isValid(difficulty ?? '')
        ? difficulty!
        : config.defaultDifficulty;
    final count =
        (questionCountOverride ?? config.maxQuestions).clamp(1, config.maxQuestions);

    InterviewLabTemplateModel? template;
    final resolvedTemplateId = (templateId ?? '').trim();
    if (resolvedTemplateId.isNotEmpty) {
      final all = await _repo.listAllTemplates();
      for (final t in all) {
        if (t.templateId == resolvedTemplateId) {
          template = t;
          break;
        }
      }
    }
    template ??= await _findActiveTemplateForTrack(track);

    final now = DateTime.now();
    final uniquenessSeed =
        '${candidateId}_${now.microsecondsSinceEpoch}_$track';
    final draft = InterviewLabSessionModel(
      sessionId: '',
      candidateId: candidateId,
      candidateRole: candidateRole,
      roleTrack: track,
      difficulty: diff,
      status: InterviewLabSessionStatus.draft,
      targetJobId: targetJobId,
      targetJobTitle: targetJobTitle ?? template?.title,
      templateId: template?.templateId ?? templateId,
      companyId: companyId,
      questionCount: count,
      answeredCount: 0,
      timeConsumedSeconds: 0,
      createdAt: now,
      updatedAt: now,
      aiProviderUsed: config.aiProvider,
      metadata: {
        'uniquenessSeed': uniquenessSeed,
        'sessionLocked': config.sessionLockEnabled,
        'adaptiveQuestioning': config.adaptiveQuestioning,
        'adaptiveDifficulty': diff,
        'followUpCount': 0,
        'timerMinutes': config.interviewTimeMinutes,
        'timerEnforced': config.timerEnforced,
        if (template != null) ...{
          'templateTitle': template.title,
          'templateDescription': template.description,
          'focusTopics': template.focusTopics,
          'promptHint': template.promptHint,
          'suggestedCategories': template.suggestedCategories,
        },
      },
    );

    final sessionId = await _repo.createSession(draft);
    var session = (await _repo.getSession(sessionId))!;

    final generated = await _questions.generateQuestions(
      session: session,
      count: count,
      candidateRole: candidateRole,
      uniquenessSeed: uniquenessSeed,
    );

    final withIds = <InterviewLabQuestionModel>[];
    for (var i = 0; i < generated.length; i++) {
      withIds.add(
        generated[i].copyWith(orderIndex: i),
      );
    }
    await _repo.upsertQuestions(withIds);
    final savedQuestions = await _repo.listQuestionsForSession(sessionId);

    session = session.copyWith(
      status: InterviewLabSessionStatus.ready,
      questionCount: savedQuestions.length,
      currentQuestionId:
          savedQuestions.isEmpty ? null : savedQuestions.first.questionId,
      currentQuestionIndex: 0,
      aiProviderUsed: config.aiProvider,
      metadata: {
        ...session.metadata,
        'questionFingerprint': savedQuestions
            .map((q) => q.prompt.hashCode.toRadixString(16))
            .join(':'),
      },
    );
    await _repo.updateSession(session);

    await _history.record(
      candidateId: candidateId,
      sessionId: sessionId,
      eventType: 'session_ready',
      message:
          'Interview Lab session ready with ${savedQuestions.length} unique AI questions.',
      roleTrack: track,
      difficulty: diff,
    );

    return (await _repo.getSession(sessionId))!;
  }

  Future<InterviewLabSessionModel> beginAnswering(String sessionId) async {
    final session = await _requireSession(sessionId);
    if (session.status == InterviewLabSessionStatus.inProgress) {
      return session;
    }
    if (session.status != InterviewLabSessionStatus.ready &&
        session.status != InterviewLabSessionStatus.paused) {
      throw InterviewLabException(
        code: 'invalid-state',
        message: 'Session cannot start from status ${session.status}.',
      );
    }
    final config = await _repo.getConfig();
    final startedAt = session.startedAt ?? DateTime.now();
    final deadline = startedAt.add(
      Duration(minutes: config.interviewTimeMinutes),
    );
    final resuming = session.status == InterviewLabSessionStatus.paused;
    final updated = session.copyWith(
      status: InterviewLabSessionStatus.inProgress,
      startedAt: startedAt,
      metadata: {
        ...session.metadata,
        'sessionLocked': config.sessionLockEnabled,
        'timerDeadlineAt': deadline.toIso8601String(),
        'timerEnforced': config.timerEnforced,
      },
    );
    await _repo.updateSession(updated);
    await _history.record(
      candidateId: session.candidateId,
      sessionId: sessionId,
      eventType: resuming ? 'session_resumed' : 'session_started',
      message: resuming
          ? 'Candidate resumed the interview.'
          : 'Candidate began answering.',
      roleTrack: session.roleTrack,
      difficulty: session.difficulty,
    );
    return (await _repo.getSession(sessionId))!;
  }

  /// Resumes a paused/ready session so answers/skips can be submitted.
  Future<InterviewLabSessionModel> ensureInProgress(String sessionId) async {
    final session = await _requireSession(sessionId);
    if (session.status == InterviewLabSessionStatus.inProgress) {
      return session;
    }
    if (session.status == InterviewLabSessionStatus.ready ||
        session.status == InterviewLabSessionStatus.paused) {
      return beginAnswering(sessionId);
    }
    throw InterviewLabException(
      code: 'invalid-state',
      message:
          'Answers can only be submitted while session is in progress '
          '(current status: ${session.status}).',
    );
  }

  Future<InterviewLabSessionModel> pauseSession(String sessionId) async {
    final session = await _requireSession(sessionId);
    if (session.status != InterviewLabSessionStatus.inProgress) {
      throw const InterviewLabException(
        code: 'invalid-state',
        message: 'Only an in-progress session can be paused.',
      );
    }
    final updated = session.copyWith(status: InterviewLabSessionStatus.paused);
    await _repo.updateSession(updated);
    await _history.record(
      candidateId: session.candidateId,
      sessionId: sessionId,
      eventType: 'session_paused',
      message: 'Session paused — resume later.',
      roleTrack: session.roleTrack,
      difficulty: session.difficulty,
    );
    return (await _repo.getSession(sessionId))!;
  }

  Future<InterviewLabSessionModel> goToQuestion({
    required String sessionId,
    required int questionIndex,
  }) async {
    final session = await _requireSession(sessionId);
    final questions = await _repo.listQuestionsForSession(sessionId);
    if (questionIndex < 0 || questionIndex >= questions.length) {
      throw const InterviewLabException(
        code: 'invalid-argument',
        message: 'Question index out of range.',
      );
    }
    final q = questions[questionIndex];
    final updated = session.copyWith(
      currentQuestionIndex: questionIndex,
      currentQuestionId: q.questionId,
    );
    await _repo.updateSession(updated);
    return (await _repo.getSession(sessionId))!;
  }

  Future<void> autosaveDraft({
    required String sessionId,
    required String questionId,
    required String answer,
  }) async {
    final session = await _requireSession(sessionId);
    if (session.status != InterviewLabSessionStatus.inProgress &&
        session.status != InterviewLabSessionStatus.paused) {
      return;
    }
    final questions = await _repo.listQuestionsForSession(sessionId);
    final index = questions.indexWhere((q) => q.questionId == questionId);
    if (index < 0) return;
    final existing = questions[index];
    if (existing.critiqueLocked) return;
    await _repo.updateQuestion(
      existing.copyWith(
        candidateAnswer: answer,
        isAnswered: answer.trim().isNotEmpty ? existing.isAnswered : false,
      ),
    );
  }

  Future<InterviewLabSessionModel> skipQuestion({
    required String sessionId,
    required String questionId,
    int timeSpentSeconds = 0,
  }) async {
    return submitAnswer(
      sessionId: sessionId,
      questionId: questionId,
      answer: '',
      timeSpentSeconds: timeSpentSeconds,
      allowEmpty: true,
    );
  }

  Future<InterviewLabSessionModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
    int timeSpentSeconds = 0,
    bool allowEmpty = false,
  }) async {
    // Leave → Pause sets status=paused. Resume must restore in_progress before
    // submit/skip, including when the UI race-clicks Next too early.
    final session = await ensureInProgress(sessionId);

    _assertTimer(session);

    final trimmed = answer.trim();
    if (!allowEmpty && trimmed.isEmpty) {
      throw const InterviewLabException(
        code: 'empty-answer',
        message: 'Please write an answer before continuing.',
      );
    }

    final questions = await _repo.listQuestionsForSession(sessionId);
    final index = questions.indexWhere((q) => q.questionId == questionId);
    if (index < 0) {
      throw const InterviewLabException(
        code: 'not-found',
        message: 'Question not found for this session.',
      );
    }

    final existing = questions[index];
    if (existing.critiqueLocked) {
      throw const InterviewLabException(
        code: 'critique-locked',
        message:
            'This answer was already evaluated. Continue to the next question.',
      );
    }

    final config = await _repo.getConfig();
    final evaluated = await _evaluation.evaluateAnswer(
      session: session,
      question: existing.copyWith(timeSpentSeconds: timeSpentSeconds),
      answer: trimmed,
      candidateRole: session.candidateRole,
      config: config,
      allQuestions: questions,
      isSkip: allowEmpty && trimmed.isEmpty,
    );
    await _repo.updateQuestion(evaluated.question);

    var followUpCount =
        (session.metadata['followUpCount'] as num?)?.toInt() ?? 0;
    InterviewLabQuestionModel? followUp;
    try {
      followUp = await _evaluation.maybeInsertFollowUp(
        session: session,
        parent: evaluated.question,
        critique: evaluated.critique,
        candidateAnswer: trimmed,
        candidateRole: session.candidateRole,
        config: config,
        allQuestions: await _repo.listQuestionsForSession(sessionId),
        followUpsAlready: followUpCount,
      );
      if (followUp != null) followUpCount += 1;
    } on InterviewLabException catch (e) {
      if (e.code != 'ai-unavailable') rethrow;
      // Follow-up is best-effort — primary critique already saved.
    }

    final refreshed = await _repo.listQuestionsForSession(sessionId);
    final answeredCount = refreshed.where((q) => q.isAnswered).length;
    final adaptiveDiff = _evaluation.resolveAdaptiveDifficulty(
      config: config,
      current: session.metadata['adaptiveDifficulty']?.toString() ??
          session.difficulty,
      critique: evaluated.critique,
    );

    // Prefer jumping to follow-up when inserted; else next unanswered/next index.
    int nextIndex;
    if (followUp != null) {
      nextIndex = refreshed.indexWhere((q) => q.questionId == followUp!.questionId);
      if (nextIndex < 0) nextIndex = index + 1;
    } else {
      nextIndex = index + 1;
    }
    if (nextIndex >= refreshed.length) nextIndex = refreshed.length - 1;

    final updated = session.copyWith(
      answeredCount: answeredCount,
      questionCount: refreshed.length,
      currentQuestionIndex: nextIndex,
      currentQuestionId: refreshed[nextIndex].questionId,
      timeConsumedSeconds: session.timeConsumedSeconds + timeSpentSeconds,
      metadata: {
        ...session.metadata,
        'followUpCount': followUpCount,
        'adaptiveDifficulty': adaptiveDiff,
        'lastCritiqueOverall': evaluated.critique.overall,
      },
    );
    await _repo.updateSession(updated);
    return (await _repo.getSession(sessionId))!;
  }

  Future<InterviewLabSessionModel> abandonSession(String sessionId) async {
    final session = await _requireSession(sessionId);
    final updated = session.copyWith(
      status: InterviewLabSessionStatus.abandoned,
      completedAt: DateTime.now(),
    );
    await _repo.updateSession(updated);
    await _history.record(
      candidateId: session.candidateId,
      sessionId: sessionId,
      eventType: 'session_abandoned',
      message: 'Session abandoned.',
      roleTrack: session.roleTrack,
      difficulty: session.difficulty,
    );
    return (await _repo.getSession(sessionId))!;
  }

  Future<InterviewLabSessionModel> markCompleted(
    InterviewLabSessionModel session, {
    required String reportId,
    required String resultId,
    required double overallScore,
    required double technicalScore,
    required double communicationScore,
    required double confidenceScore,
    required double problemSolvingScore,
    List<String> badgesAwarded = const [],
  }) async {
    final updated = session.copyWith(
      status: InterviewLabSessionStatus.completed,
      completedAt: DateTime.now(),
      reportId: reportId,
      resultId: resultId,
      overallScore: overallScore,
      technicalScore: technicalScore,
      communicationScore: communicationScore,
      confidenceScore: confidenceScore,
      problemSolvingScore: problemSolvingScore,
      metadata: {
        ...session.metadata,
        'badgesAwarded': badgesAwarded,
        'sessionLocked': true,
      },
    );
    await _repo.updateSession(updated);
    await _history.record(
      candidateId: session.candidateId,
      sessionId: session.sessionId,
      eventType: 'session_completed',
      message: 'Session completed. Overall score $overallScore.',
      roleTrack: session.roleTrack,
      difficulty: session.difficulty,
      overallScore: overallScore,
    );
    return (await _repo.getSession(session.sessionId))!;
  }

  void _assertTimer(InterviewLabSessionModel session) {
    final enforced = session.metadata['timerEnforced'] == true;
    if (!enforced) return;
    final raw = session.metadata['timerDeadlineAt']?.toString();
    if (raw == null || raw.isEmpty) return;
    final deadline = DateTime.tryParse(raw);
    if (deadline == null) return;
    if (DateTime.now().isAfter(deadline)) {
      throw const InterviewLabException(
        code: 'timer-expired',
        message: 'Interview timer has expired. Finish to generate your report.',
      );
    }
  }

  Future<InterviewLabSessionModel> _requireSession(String sessionId) async {
    final session = await _repo.getSession(sessionId);
    if (session == null) {
      throw const InterviewLabException(
        code: 'not-found',
        message: 'Interview Lab session not found.',
      );
    }
    return session;
  }

  Future<InterviewLabTemplateModel?> _findActiveTemplateForTrack(
    String roleTrack,
  ) async {
    final active = await _repo.listActiveTemplates();
    for (final t in active) {
      if (InterviewLabRoleTrack.slugify(t.roleTrack) == roleTrack) {
        return t;
      }
    }
    return null;
  }
}
