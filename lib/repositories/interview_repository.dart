import '../models/interview_model.dart';

abstract class InterviewRepository {
  Future<String> scheduleInterview(InterviewModel interview);
  Future<void> updateInterview(
    InterviewModel interview, {
    String? applicationStatus,
  });
  Future<void> updateInterviewStatus({
    required String interviewId,
    required String status,
    String? result,
    String? applicationStatus,
  });
  Future<InterviewModel?> getInterview(String interviewId);
  Future<InterviewModel?> getInterviewForApplication(String applicationId);
  Stream<InterviewModel?> streamInterview(String interviewId);
  Stream<List<InterviewModel>> streamInterviewsForCandidate(String candidateId);
  Stream<List<InterviewModel>> streamInterviewsForCompany(String companyId);
}
