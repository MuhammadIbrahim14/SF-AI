import '../models/interview_lab_models.dart';

/// Persistence contract for AI Interview Lab (separate from hiring interviews).
abstract class InterviewLabRepository {
  Future<InterviewLabConfigModel> getConfig();
  Stream<InterviewLabConfigModel> watchConfig();
  Future<void> upsertConfig(InterviewLabConfigModel config);

  Future<String> createSession(InterviewLabSessionModel session);
  Future<void> updateSession(InterviewLabSessionModel session);
  Future<InterviewLabSessionModel?> getSession(String sessionId);
  Stream<InterviewLabSessionModel?> watchSession(String sessionId);
  Stream<List<InterviewLabSessionModel>> watchSessionsForCandidate(
    String candidateId,
  );
  Future<List<InterviewLabSessionModel>> listSessionsForCandidate(
    String candidateId, {
    int limit = 50,
  });

  /// Active practice session that can be resumed (ready / in_progress / paused).
  Future<InterviewLabSessionModel?> findResumableSession(String candidateId);

  Future<void> deleteSessionCascade(String sessionId);

  Future<void> upsertQuestions(List<InterviewLabQuestionModel> questions);
  Future<void> updateQuestion(InterviewLabQuestionModel question);
  Future<List<InterviewLabQuestionModel>> listQuestionsForSession(
    String sessionId,
  );
  Stream<List<InterviewLabQuestionModel>> watchQuestionsForSession(
    String sessionId,
  );

  Future<String> saveReport(InterviewLabReportModel report);
  Future<InterviewLabReportModel?> getReport(String reportId);
  Future<InterviewLabReportModel?> getReportForSession(String sessionId);

  Future<String> saveResult(InterviewLabResultModel result);
  Future<InterviewLabResultModel?> getResultForSession(String sessionId);

  Future<String> appendHistory(InterviewLabHistoryEntryModel entry);
  Stream<List<InterviewLabHistoryEntryModel>> watchHistoryForCandidate(
    String candidateId, {
    int limit = 100,
  });

  Future<String> upsertTemplate(InterviewLabTemplateModel template);
  Stream<List<InterviewLabTemplateModel>> watchActiveTemplates();
  Future<List<InterviewLabTemplateModel>> listActiveTemplates();
  Stream<List<InterviewLabTemplateModel>> watchAllTemplates();
  Future<List<InterviewLabTemplateModel>> listAllTemplates();

  Future<String> saveBadge(InterviewLabBadgeModel badge);
  Stream<List<InterviewLabBadgeModel>> watchBadgesForCandidate(String candidateId);
  Future<List<InterviewLabBadgeModel>> listBadgesForCandidate(String candidateId);

  Future<InterviewLabProgressModel?> getProgress(String candidateId);
  Stream<InterviewLabProgressModel?> watchProgress(String candidateId);
  Future<void> upsertProgress(InterviewLabProgressModel progress);
}
