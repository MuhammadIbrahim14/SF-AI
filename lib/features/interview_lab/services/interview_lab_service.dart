import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import '../data/interview_lab_repository.dart';
import '../models/interview_lab_models.dart';
import 'interview_lab_evaluation_engine.dart';
import 'interview_lab_history_manager.dart';
import 'interview_lab_question_engine.dart';
import 'interview_lab_report_engine.dart';
import 'interview_lab_session_manager.dart';

/// Facade service for AI Interview Lab intelligence engine.
class InterviewLabService {
  InterviewLabService({
    required InterviewLabRepository repository,
    InterviewLabQuestionEngine? questionEngine,
    InterviewLabHistoryManager? historyManager,
    InterviewLabReportEngine? reportEngine,
    InterviewLabEvaluationEngine? evaluationEngine,
    InterviewLabSessionManager? sessionManager,
  }) : _repo = repository {
    _questions = questionEngine ?? InterviewLabQuestionEngine();
    _history = historyManager ?? InterviewLabHistoryManager(repository);
    _report = reportEngine ?? InterviewLabReportEngine(repository);
    _evaluation = evaluationEngine ??
        InterviewLabEvaluationEngine(
          repository: repository,
          questionEngine: _questions,
        );
    _sessions = sessionManager ??
        InterviewLabSessionManager(
          repository: repository,
          questionEngine: _questions,
          historyManager: _history,
          evaluationEngine: _evaluation,
        );
  }

  final InterviewLabRepository _repo;
  late final InterviewLabSessionManager _sessions;
  late final InterviewLabReportEngine _report;
  late final InterviewLabHistoryManager _history;
  late final InterviewLabQuestionEngine _questions;
  late final InterviewLabEvaluationEngine _evaluation;

  InterviewLabRepository get repository => _repo;
  InterviewLabSessionManager get sessionManager => _sessions;
  InterviewLabReportEngine get reportEngine => _report;
  InterviewLabHistoryManager get historyManager => _history;
  InterviewLabQuestionEngine get questionEngine => _questions;
  InterviewLabEvaluationEngine get evaluationEngine => _evaluation;

  Future<InterviewLabConfigModel> getConfig() => _repo.getConfig();

  Future<void> upsertConfig(InterviewLabConfigModel config) =>
      _repo.upsertConfig(config);

  Future<InterviewLabSessionModel> createAndPrepareSession({
    required String candidateId,
    required String candidateRole,
    required String roleTrack,
    String? difficulty,
    String? targetJobId,
    String? targetJobTitle,
    String? templateId,
    String? companyId,
    int? questionCountOverride,
  }) {
    return _sessions.startSession(
      candidateId: candidateId,
      candidateRole: candidateRole,
      roleTrack: roleTrack,
      difficulty: difficulty,
      targetJobId: targetJobId,
      targetJobTitle: targetJobTitle,
      templateId: templateId,
      companyId: companyId,
      questionCountOverride: questionCountOverride,
    );
  }

  Future<InterviewLabSessionModel> beginAnswering(String sessionId) =>
      _sessions.beginAnswering(sessionId);

  Future<InterviewLabSessionModel> ensureInProgress(String sessionId) =>
      _sessions.ensureInProgress(sessionId);

  Future<InterviewLabSessionModel> pauseSession(String sessionId) =>
      _sessions.pauseSession(sessionId);

  Future<InterviewLabSessionModel?> findResumableSession(String candidateId) =>
      _repo.findResumableSession(candidateId);

  Future<void> autosaveDraft({
    required String sessionId,
    required String questionId,
    required String answer,
  }) {
    return _sessions.autosaveDraft(
      sessionId: sessionId,
      questionId: questionId,
      answer: answer,
    );
  }

  Future<InterviewLabSessionModel> goToQuestion({
    required String sessionId,
    required int questionIndex,
  }) {
    return _sessions.goToQuestion(
      sessionId: sessionId,
      questionIndex: questionIndex,
    );
  }

  Future<InterviewLabSessionModel> skipQuestion({
    required String sessionId,
    required String questionId,
    int timeSpentSeconds = 0,
  }) {
    return _sessions.skipQuestion(
      sessionId: sessionId,
      questionId: questionId,
      timeSpentSeconds: timeSpentSeconds,
    );
  }

  Future<void> deleteSession(String sessionId) =>
      _repo.deleteSessionCascade(sessionId);

  Future<InterviewLabSessionModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
    int timeSpentSeconds = 0,
    bool allowEmpty = false,
  }) {
    return _sessions.submitAnswer(
      sessionId: sessionId,
      questionId: questionId,
      answer: answer,
      timeSpentSeconds: timeSpentSeconds,
      allowEmpty: allowEmpty,
    );
  }

  Future<InterviewLabSessionModel> abandonSession(String sessionId) =>
      _sessions.abandonSession(sessionId);

  /// Completes session: AI debrief, badges, progress, mark completed.
  Future<
      ({
        InterviewLabSessionModel session,
        InterviewLabReportModel report,
        InterviewLabResultModel result,
        List<InterviewLabBadgeModel> badges,
      })> completeSession(String sessionId) async {
    final session = await _repo.getSession(sessionId);
    if (session == null) {
      throw const InterviewLabException(
        code: 'not-found',
        message: 'Session not found.',
      );
    }
    final questions = await _repo.listQuestionsForSession(sessionId);
    final config = await _repo.getConfig();
    final built = await _report.buildAndSave(
      session: session,
      questions: questions,
      config: config,
      candidateRole: session.candidateRole,
    );

    var badges = <InterviewLabBadgeModel>[];
    try {
      badges = await _evaluation.awardBadges(
        session: session,
        report: built.report,
      );
      await _evaluation.updateProgress(
        session: session,
        report: built.report,
      );
    } catch (_) {
      // Badges/progress must not block report completion after timer expiry.
    }

    // Persist badge keys onto report for UI convenience.
    if (badges.isNotEmpty) {
      try {
        final withBadges = InterviewLabReportModel.fromMap({
          ...built.report.toMap(useServerTimestamps: false),
          'badgesAwarded': badges.map((b) => b.badgeKey).toList(),
          'reportId': built.report.reportId,
        }, docId: built.report.reportId);
        await _repo.saveReport(withBadges);
      } catch (_) {
        AppLogger.warn('Interview report badge persistence was skipped.');
      }
    }

    final completed = await _sessions.markCompleted(
      session,
      reportId: built.report.reportId,
      resultId: built.result.resultId,
      overallScore: built.report.overallRating,
      technicalScore: built.report.technicalScore,
      communicationScore: built.report.communicationScore,
      confidenceScore: built.report.confidenceScore,
      problemSolvingScore: built.report.problemSolvingScore,
      badgesAwarded: badges.map((b) => b.badgeKey).toList(),
    );
    return (
      session: completed,
      report: built.report,
      result: built.result,
      badges: badges,
    );
  }

  Future<List<InterviewLabQuestionModel>> listQuestions(String sessionId) =>
      _repo.listQuestionsForSession(sessionId);

  Future<List<InterviewLabTemplateModel>> listTemplates() =>
      _repo.listActiveTemplates();

  Future<List<InterviewLabTemplateModel>> listAllTemplates() =>
      _repo.listAllTemplates();

  Future<String> upsertTemplate(InterviewLabTemplateModel template) =>
      _repo.upsertTemplate(template);

  /// Soft seed for candidates: only when active templates are empty.
  Future<void> seedDefaultTemplatesIfEmpty() async {
    try {
      final existing = await _repo.listActiveTemplates();
      if (existing.isNotEmpty) return;
      await _upsertDefaultTemplates();
    } on FirebaseException catch (e) {
      // Templates are admin-owned metadata only. Students/freelancers must still
      // start practice when the collection is empty or write is denied.
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

  /// Admin force-seed: upserts built-in tracks (does not delete custom ones).
  Future<void> seedDefaultTemplates({bool force = false}) async {
    if (!force) {
      await seedDefaultTemplatesIfEmpty();
      return;
    }
    await _upsertDefaultTemplates();
  }

  Future<void> _upsertDefaultTemplates() async {
    final now = DateTime.now();
    const tracks = <(String, String, String, List<String>)>[
      (
        InterviewLabRoleTrack.flutter,
        'Flutter Developer',
        'Mobile Flutter interview prep',
        ['Flutter', 'Dart', 'State management', 'Widgets'],
      ),
      (
        InterviewLabRoleTrack.backend,
        'Backend Developer',
        'APIs, databases, system design',
        ['REST APIs', 'Databases', 'Auth', 'System design'],
      ),
      (
        InterviewLabRoleTrack.frontend,
        'Frontend Developer',
        'Web UI engineering',
        ['HTML/CSS', 'JavaScript', 'React', 'Performance'],
      ),
      (
        InterviewLabRoleTrack.uiUx,
        'UI / UX Designer',
        'Product design interviews',
        ['UX research', 'Wireframes', 'Design systems'],
      ),
      (
        InterviewLabRoleTrack.ai,
        'AI Engineer',
        'Applied AI engineering',
        ['ML basics', 'LLMs', 'Prompting', 'Evaluation'],
      ),
      (
        InterviewLabRoleTrack.cyberSecurity,
        'Cyber Security',
        'Security engineering',
        ['OWASP', 'Auth', 'Threat modeling'],
      ),
      (
        InterviewLabRoleTrack.dataScience,
        'Data Analyst',
        'Analytics & ML interviews',
        ['SQL', 'Statistics', 'Visualization'],
      ),
      (
        InterviewLabRoleTrack.mobile,
        'Mobile Developer',
        'Native / cross-platform mobile',
        ['Mobile architecture', 'Offline sync', 'App store'],
      ),
      (
        InterviewLabRoleTrack.devops,
        'DevOps Engineer',
        'CI/CD and cloud operations',
        ['CI/CD', 'Docker', 'Cloud', 'Monitoring'],
      ),
      (
        InterviewLabRoleTrack.qa,
        'QA Engineer',
        'Testing and quality engineering',
        ['Test strategy', 'Automation', 'Bug reporting'],
      ),
      (
        InterviewLabRoleTrack.general,
        'Generalist',
        'Cross-functional interview prep',
        ['Problem solving', 'Communication'],
      ),
    ];
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      await _repo.upsertTemplate(
        InterviewLabTemplateModel(
          templateId: 'tpl_${t.$1}',
          roleTrack: t.$1,
          title: t.$2,
          description: t.$3,
          focusTopics: t.$4,
          sortOrder: (i + 1) * 10,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}
