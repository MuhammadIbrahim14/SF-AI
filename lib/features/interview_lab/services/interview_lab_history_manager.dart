import '../data/interview_lab_repository.dart';
import '../models/interview_lab_models.dart';

/// Append-only history for Interview Lab candidate timelines.
class InterviewLabHistoryManager {
  InterviewLabHistoryManager(this._repo);

  final InterviewLabRepository _repo;

  Future<String> record({
    required String candidateId,
    required String sessionId,
    required String eventType,
    required String message,
    String? roleTrack,
    String? difficulty,
    double? overallScore,
    Map<String, dynamic>? metadata,
  }) {
    return _repo.appendHistory(
      InterviewLabHistoryEntryModel(
        historyId: '',
        candidateId: candidateId,
        sessionId: sessionId,
        eventType: eventType,
        message: message,
        roleTrack: roleTrack,
        difficulty: difficulty,
        overallScore: overallScore,
        metadata: metadata ?? const {},
        createdAt: DateTime.now(),
      ),
    );
  }

  Stream<List<InterviewLabHistoryEntryModel>> watchForCandidate(
    String candidateId, {
    int limit = 100,
  }) {
    return _repo.watchHistoryForCandidate(candidateId, limit: limit);
  }

  Future<List<InterviewLabSessionModel>> listSessions(
    String candidateId, {
    int limit = 50,
  }) {
    return _repo.listSessionsForCandidate(candidateId, limit: limit);
  }
}
