import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../core/mailer/email_templates.dart';
import '../core/mailer/emailjs_provider.dart';
import '../core/notifications/notification_events.dart';
import '../core/utils/app_logger.dart';
import '../features/company/hiring_lifecycle/services/hiring_lifecycle_service.dart';
import '../models/application_model.dart';
import '../models/hiring_lifecycle_models.dart';
import 'auth_provider.dart';
import 'company_permission_provider.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';

/// Streams all applications submitted by the current user.
final myApplicationsProvider = StreamProvider<List<ApplicationModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref
          .watch(applicationRepositoryProvider)
          .streamApplicationsByUser(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

/// Streams all applications submitted for a specific job.
final jobApplicationsProvider =
    StreamProvider.family<List<ApplicationModel>, String>((ref, jobId) {
      return ref
          .watch(applicationRepositoryProvider)
          .streamApplicationsForJob(jobId);
    });

final applicationDetailProvider =
    FutureProvider.family<ApplicationModel?, String>((ref, applicationId) {
      return ref
          .watch(applicationRepositoryProvider)
          .getApplication(applicationId);
    });

final applicationDetailStreamProvider =
    StreamProvider.family<ApplicationModel?, String>((ref, applicationId) {
      return ref
          .watch(applicationRepositoryProvider)
          .streamApplication(applicationId);
    });

/// Streams all applications received by the current company across all jobs.
final companyApplicationsProvider = StreamProvider<List<ApplicationModel>>((
  ref,
) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref
          .watch(applicationRepositoryProvider)
          .streamApplicationsForCompany(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

/// Notifier to handle submitting and updating applications.
final applicationActionProvider =
    AsyncNotifierProvider<ApplicationActionNotifier, void>(
      ApplicationActionNotifier.new,
    );

class ApplicationActionNotifier extends AsyncNotifier<void> {
  HiringLifecycleService get _lifecycle => HiringLifecycleService(
        ref.read(applicationRepositoryProvider),
        ref.read(notificationServiceProvider),
      );

  @override
  Future<void> build() async {}

  Future<bool> submitApplication(ApplicationModel application) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final id = await ref
          .read(applicationRepositoryProvider)
          .createApplication(application);
      await _lifecycle.notifyHiringEvent(
        userId: application.companyId,
        title: 'New application',
        body: 'A candidate applied for one of your jobs.',
        applicationId: id,
        event: NotificationEvents.hiringApplicationReceived,
      );
    });
    return !state.hasError;
  }

  String? get lastErrorMessage {
    final err = state.error;
    if (err == null) return null;
    if (err is AppException) return err.message;
    return err.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<bool> updateStatus(String applicationId, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationStatus(applicationId, status);
      await _notifyCandidate(applicationId, status);
    });
    return !state.hasError;
  }

  Future<bool> updatePipelineStatus({
    required String applicationId,
    required String status,
    String? interviewId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationPipeline(
            applicationId: applicationId,
            status: status,
            interviewId: interviewId,
          );
      await _sendHiringEmail(applicationId: applicationId, status: status);
      await _notifyCandidate(applicationId, status);
    });
    return !state.hasError;
  }

  Future<bool> updateHiringData({
    required String applicationId,
    String? pipelineStage,
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
    String? applicationStatus,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: pipelineStage,
            evaluationScore: evaluationScore,
            evaluationSummary: evaluationSummary,
            rankingScore: rankingScore,
            rankingReason: rankingReason,
            matchedSkills: matchedSkills,
            missingSkills: missingSkills,
            recommendedNextStep: recommendedNextStep,
            companyNotes: companyNotes,
            offerStatus: offerStatus,
            offerDetails: offerDetails,
            candidateVisibleStatus: candidateVisibleStatus,
            evaluationRequestStatus: evaluationRequestStatus,
            evaluationQuestions: evaluationQuestions,
            offerSalary: offerSalary,
            offerCurrency: offerCurrency,
            offerJoiningDate: offerJoiningDate,
            offerMessage: offerMessage,
            offerSentAt: offerSentAt,
            talentPoolSaved: talentPoolSaved,
            evaluatedAt: evaluatedAt,
            lifecycleStage: lifecycleStage,
            employmentStatus: employmentStatus,
            joinedAt: joinedAt,
            offerRole: offerRole,
            offerDepartment: offerDepartment,
            offerEmploymentType: offerEmploymentType,
            offerBenefits: offerBenefits,
            offerContractDuration: offerContractDuration,
            offerWorkingHours: offerWorkingHours,
            offerLocation: offerLocation,
            offerExpiresAt: offerExpiresAt,
            hrInterviewFeedback: hrInterviewFeedback,
            hrHiringComments: hrHiringComments,
            onboardingChecklist: onboardingChecklist,
            applicationStatus: applicationStatus,
          );
      final emailStatus =
          candidateVisibleStatus ??
          offerStatus ??
          evaluationRequestStatus ??
          pipelineStage ??
          lifecycleStage ??
          'updated';
      await _sendHiringEmail(
        applicationId: applicationId,
        status: emailStatus,
      );
      await _notifyCandidate(applicationId, emailStatus);
    });
    return !state.hasError;
  }

  Future<bool> respondToOffer({
    required String applicationId,
    required String offerStatus,
    String? candidateResponseMessage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(applicationRepositoryProvider)
          .updateCandidateResponse(
            applicationId: applicationId,
            offerStatus: offerStatus,
            candidateResponseMessage: candidateResponseMessage,
          );
      await _sendCandidateResponseEmail(
        applicationId: applicationId,
        offerStatus: offerStatus,
      );
      final app = await ref
          .read(applicationRepositoryProvider)
          .getApplication(applicationId);
      if (app != null) {
        final offerKey = normalizeOfferStatus(offerStatus);
        final event = switch (offerKey) {
          'accepted' => NotificationEvents.hiringOfferAccepted,
          'declined' => NotificationEvents.hiringOfferDeclined,
          _ => NotificationEvents.hiringStatusChanged,
        };
        await _lifecycle.notifyHiringEvent(
          userId: app.companyId,
          title: 'Offer response',
          body:
              'Candidate ${normalizeOfferStatus(offerStatus)} the offer.',
          applicationId: applicationId,
          event: event,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> submitEvaluationAnswers({
    required String applicationId,
    required List<String> answers,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(applicationRepositoryProvider)
          .submitEvaluationAnswers(
            applicationId: applicationId,
            answers: answers,
          );
    });
    return !state.hasError;
  }

  Future<bool> markAsEvaluated({
    required String applicationId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: 'interview',
            applicationStatus: 'interview_completed',
            lifecycleStage: 'evaluated',
            candidateVisibleStatus: 'evaluation_complete',
            evaluatedAt: DateTime.now(),
            recommendedNextStep:
                'Evaluation complete. Ready for offer, hire, or reject.',
          );
    });
    return !state.hasError;
  }

  Future<bool> makeOffer({
    required String applicationId,
    required String salary,
    required String currency,
    required String joiningDate,
    String? message,
    String? role,
    String? department,
    String? employmentType,
    String? benefits,
    String? contractDuration,
    String? workingHours,
    String? location,
    String? expiresAt,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: 'offer',
            offerStatus: 'sent',
            offerSalary: salary,
            offerCurrency: currency,
            offerJoiningDate: joiningDate,
            offerMessage: message,
            offerSentAt: DateTime.now(),
            candidateVisibleStatus: 'offer_pending',
            lifecycleStage: 'offer_sent',
            offerRole: role,
            offerDepartment: department,
            offerEmploymentType: employmentType,
            offerBenefits: benefits,
            offerContractDuration: contractDuration,
            offerWorkingHours: workingHours,
            offerLocation: location,
            offerExpiresAt: expiresAt,
          );
      await _sendHiringEmail(
        applicationId: applicationId,
        status: 'offer_sent',
      );
      await _notifyCandidate(applicationId, 'offer_sent');
    });
    return !state.hasError;
  }

  Future<bool> hireCandidate({
    required String applicationId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      final existing = await ref
          .read(applicationRepositoryProvider)
          .getApplication(applicationId);
      final joinedAt = DateTime.now();
      final profile = existing == null || existing.employmentProfile.isEmpty
          ? EmploymentProfile.fromOffer(
              offerRole: existing?.offerRole ?? '',
              offerDepartment: existing?.offerDepartment ?? '',
              offerLocation: existing?.offerLocation ?? '',
            )
          : existing.employmentProfile;
      await ref.read(applicationRepositoryProvider).updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: 'hired',
            offerStatus: 'accepted',
            candidateVisibleStatus: 'hired',
            lifecycleStage: 'joined',
            employmentStatus: 'active',
            joinedAt: joinedAt,
            onboardingChecklist: OnboardingChecklistItem.defaultChecklist(),
            employmentProfile: profile,
          );
      await _sendHiringEmail(
        applicationId: applicationId,
        status: 'hired',
      );
      await _notifyCandidate(applicationId, 'hired');
    });
    return !state.hasError;
  }

  Future<bool> rejectCandidate({
    required String applicationId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: 'rejected',
            offerStatus: 'rejected',
            candidateVisibleStatus: 'rejected',
            lifecycleStage: 'rejected',
            employmentStatus: 'none',
          );
      await _sendHiringEmail(
        applicationId: applicationId,
        status: 'rejected',
      );
      await _notifyCandidate(applicationId, 'rejected');
    });
    return !state.hasError;
  }

  Future<void> _notifyCandidate(String applicationId, String status) async {
    try {
      final application = await ref
          .read(applicationRepositoryProvider)
          .getApplication(applicationId);
      if (application == null) return;
      final key = status.trim().toLowerCase();
      final title = switch (key) {
        'offer_sent' || 'offer' || 'offer_pending' || 'sent' =>
          'Job offer received',
        'evaluated' || 'evaluation_complete' || 'interview_completed' =>
          'Application update',
        'hired' || 'joined' => 'You were hired',
        'rejected' => 'Application update',
        _ => 'Application update',
      };
      final body = switch (key) {
        'offer_sent' || 'offer' || 'offer_pending' || 'sent' =>
          'Open My Applications to review and respond to your offer.',
        'evaluated' || 'evaluation_complete' =>
          'Your interview evaluation is complete. Awaiting company decision.',
        'interview_completed' =>
          'Your interview was marked completed.',
        'hired' || 'joined' =>
          'Congratulations — the company marked you as hired.',
        'rejected' => 'This application was not selected.',
        _ =>
          'Status: ${lifecycleStageLabel(application.normalizedLifecycleStage)}.',
      };
      final event = switch (key) {
        'offer_sent' || 'offer' || 'offer_pending' || 'sent' =>
          NotificationEvents.hiringOfferSent,
        'offer_accepted' || 'accepted' =>
          NotificationEvents.hiringOfferAccepted,
        'offer_declined' || 'declined' || 'offer_rejected' =>
          NotificationEvents.hiringOfferDeclined,
        'interview_scheduled' || 'interview' || 'interviewscheduled' =>
          NotificationEvents.hiringInterviewScheduled,
        'interview_updated' || 'interview_cancelled' =>
          NotificationEvents.hiringInterviewUpdated,
        'interview_completed' ||
        'evaluated' ||
        'evaluation_complete' =>
          NotificationEvents.hiringInterviewCompleted,
        'hired' => NotificationEvents.hiringHired,
        'joined' => NotificationEvents.hiringJoined,
        _ => NotificationEvents.hiringStatusChanged,
      };
      await _lifecycle.notifyHiringEvent(
        userId: application.applicantId,
        title: title,
        body: body,
        applicationId: applicationId,
        event: event,
      );
    } catch (_) {
      AppLogger.warn('Hiring status notification could not be sent.');
    }
  }

  Future<void> _sendHiringEmail({
    required String applicationId,
    required String status,
  }) async {
    try {
      final config = await ref.read(emailJsMailerServiceProvider).loadConfig();
      if (!config.sendHiringEmails) return;
      final application = await ref
          .read(applicationRepositoryProvider)
          .getApplication(applicationId);
      if (application == null) return;
      final candidate = await ref
          .read(userRepositoryProvider)
          .getUser(application.applicantId);
      final job = await ref
          .read(jobRepositoryProvider)
          .getJob(application.jobId);
      final company = await ref
          .read(userRepositoryProvider)
          .getUser(application.companyId);
      await ref
          .read(emailJsMailerServiceProvider)
          .send(
            SkillForgeEmailTemplates.hiringStatus(
              applicationId: application.id,
              toEmail: candidate?.email ?? '',
              toName: candidate?.fullName ?? 'Candidate',
              companyName: company?.fullName ?? 'SkillForge company',
              jobTitle: job?.title ?? 'your applied role',
              status: status,
              nextSteps: _nextStepsForStatus(status),
              actionUrl: '',
            ),
            triggeredBy: job?.companyId ?? application.companyId,
            config: config,
          );
    } catch (_) {
      // Email is non-blocking.
    }
  }

  Future<void> _sendCandidateResponseEmail({
    required String applicationId,
    required String offerStatus,
  }) async {
    try {
      final config = await ref.read(emailJsMailerServiceProvider).loadConfig();
      if (!config.sendHiringEmails) return;
      final application = await ref
          .read(applicationRepositoryProvider)
          .getApplication(applicationId);
      if (application == null) return;
      final company = await ref
          .read(userRepositoryProvider)
          .getUser(application.companyId);
      final job = await ref
          .read(jobRepositoryProvider)
          .getJob(application.jobId);
      final statusKey = switch (normalizeOfferStatus(offerStatus)) {
        'accepted' => 'offer_accepted',
        'declined' => 'offer_rejected',
        'clarification' => 'offer_clarification',
        _ => 'candidate_$offerStatus',
      };
      await ref
          .read(emailJsMailerServiceProvider)
          .send(
            SkillForgeEmailTemplates.hiringStatus(
              applicationId: application.id,
              toEmail: company?.email ?? '',
              toName: company?.fullName ?? 'Hiring team',
              companyName: company?.fullName ?? 'SkillForge company',
              jobTitle: job?.title ?? 'the role',
              status: statusKey,
              nextSteps:
                  'The candidate has ${normalizeOfferStatus(offerStatus)} the offer.',
              actionUrl: '',
            ),
            triggeredBy: application.applicantId,
            config: config,
          );
    } catch (_) {
      // Email is non-blocking.
    }
  }
}

String _nextStepsForStatus(String status) {
  return switch (status) {
    'shortlisted' => 'Please keep your profile ready for the next step.',
    'evaluation' || 'requested' || 'evaluationRequested' =>
      'Please open your application and submit the requested evaluation.',
    'interview' ||
    'interviewScheduled' ||
    'interview_scheduled' =>
      'Please review the interview details in your application center.',
    'interview_updated' => 'Interview details were updated. Please reconfirm.',
    'interview_cancelled' =>
      'Your interview was cancelled. Watch for a new schedule.',
    'offer' || 'sent' || 'offerSent' || 'offer_sent' =>
      'Please review the offer and respond from your application center.',
    'joining_reminder' =>
      'Your joining date is approaching. Complete onboarding items.',
    'selected' || 'hired' || 'joined' =>
      'The company will share the next joining steps.',
    'rejected' => 'Thank you for applying. Keep improving your portfolio.',
    _ => 'Open your application center for the latest status.',
  };
}
