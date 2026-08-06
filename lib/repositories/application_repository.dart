import '../models/application_model.dart';
import '../models/hiring_lifecycle_models.dart';

abstract class ApplicationRepository {
  Future<String> createApplication(ApplicationModel application);
  Future<ApplicationModel?> findApplicationForJob({
    required String applicantId,
    required String jobId,
  });
  Future<void> updateApplicationStatus(String applicationId, String status);
  Future<void> updateApplicationPipeline({
    required String applicationId,
    required String status,
    String? interviewId,
  });
  Future<void> updateApplicationHiringData({
    required String applicationId,
    String? pipelineStage,
    String? applicationStatus,
    double? evaluationScore,
    String? evaluationSummary,
    double? rankingScore,
    String? rankingReason,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    String? recommendedNextStep,
    String? companyNotes,
    String? offerStatus,
    String? offerDetails,
    String? candidateVisibleStatus,
    String? evaluationRequestStatus,
    List<String>? evaluationQuestions,
    String? offerSalary,
    String? offerCurrency,
    String? offerJoiningDate,
    String? offerMessage,
    DateTime? offerSentAt,
    bool? talentPoolSaved,
    DateTime? evaluatedAt,
    String? lifecycleStage,
    String? employmentStatus,
    DateTime? joinedAt,
    String? offerRole,
    String? offerDepartment,
    String? offerEmploymentType,
    String? offerBenefits,
    String? offerContractDuration,
    String? offerWorkingHours,
    String? offerLocation,
    String? offerExpiresAt,
    String? hrInterviewFeedback,
    String? hrHiringComments,
    List<OnboardingChecklistItem>? onboardingChecklist,
    DateTime? offerDocumentGeneratedAt,
    WelcomePack? welcomePack,
    EmploymentProfile? employmentProfile,
    ProbationInfo? probation,
    OffboardingInfo? offboarding,
    List<EmploymentDocument>? documents,
    String? hrThreadId,
    DateTime? lastJoinReminderAt,
    DateTime? lastDocsReminderAt,
  });
  Future<void> updateCandidateResponse({
    required String applicationId,
    required String offerStatus,
    String? candidateResponseMessage,
  });
  Future<void> submitEvaluationAnswers({
    required String applicationId,
    required List<String> answers,
  });
  Future<void> appendTimelineEvent(HiringTimelineEvent event);
  Stream<List<HiringTimelineEvent>> streamTimeline(String applicationId);
  /// Deprecated: use [NotificationRepository.createNotification].
  @Deprecated('Use NotificationRepository / NotificationService')
  Future<void> createUserNotification(UserNotificationModel notification);

  /// Deprecated: use [NotificationRepository.streamUserNotifications].
  @Deprecated('Use NotificationRepository')
  Stream<List<UserNotificationModel>> streamUserNotifications(String userId);

  /// Deprecated: use [NotificationRepository.markNotificationRead].
  @Deprecated('Use NotificationRepository')
  Future<void> markNotificationRead(String notificationId);
  Future<ApplicationModel?> getApplication(String applicationId);
  Stream<ApplicationModel?> streamApplication(String applicationId);
  Stream<List<ApplicationModel>> streamApplicationsByUser(String applicantId);
  Stream<List<ApplicationModel>> streamApplicationsForJob(String jobId);
  Stream<List<ApplicationModel>> streamApplicationsForCompany(String companyId);
}
