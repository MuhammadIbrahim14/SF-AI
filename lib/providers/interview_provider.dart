import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mailer/email_templates.dart';
import '../core/mailer/emailjs_provider.dart';
import '../core/notifications/notification_events.dart';
import '../core/utils/app_logger.dart';
import '../features/company/hiring_lifecycle/services/hiring_lifecycle_service.dart';
import '../models/interview_model.dart';
import 'auth_provider.dart';
import 'company_permission_provider.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';

final myInterviewsProvider = StreamProvider<List<InterviewModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const <InterviewModel>[]);
      return ref
          .watch(interviewRepositoryProvider)
          .streamInterviewsForCandidate(user.uid);
    },
    loading: () => Stream.value(const <InterviewModel>[]),
    error: (_, _) => Stream.value(const <InterviewModel>[]),
  );
});

final companyInterviewsProvider = StreamProvider<List<InterviewModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const <InterviewModel>[]);
      return ref
          .watch(interviewRepositoryProvider)
          .streamInterviewsForCompany(user.uid);
    },
    loading: () => Stream.value(const <InterviewModel>[]),
    error: (_, _) => Stream.value(const <InterviewModel>[]),
  );
});

final interviewDetailProvider = FutureProvider.family<InterviewModel?, String>((
  ref,
  interviewId,
) {
  return ref.watch(interviewRepositoryProvider).getInterview(interviewId);
});

final interviewDetailStreamProvider =
    StreamProvider.family<InterviewModel?, String>((ref, interviewId) {
  return ref.watch(interviewRepositoryProvider).streamInterview(interviewId);
});

final applicationInterviewProvider =
    FutureProvider.family<InterviewModel?, String>((ref, applicationId) {
      return ref
          .watch(interviewRepositoryProvider)
          .getInterviewForApplication(applicationId);
    });

final interviewActionProvider =
    AsyncNotifierProvider<InterviewActionNotifier, void>(
      InterviewActionNotifier.new,
    );

class InterviewActionNotifier extends AsyncNotifier<void> {
  HiringLifecycleService get _lifecycle => HiringLifecycleService(
        ref.read(applicationRepositoryProvider),
        ref.read(notificationServiceProvider),
      );

  @override
  Future<void> build() async {}

  Future<bool> scheduleInterview(InterviewModel interview) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      final isUpdate =
          interview.interviewId.isNotEmpty || interview.status == 'rescheduled';
      await ref.read(interviewRepositoryProvider).scheduleInterview(interview);
      await _sendInterviewEmail(
        interview: interview,
        status: isUpdate ? 'interview_updated' : 'interview_scheduled',
      );
      await _lifecycle.notifyHiringEvent(
        userId: interview.candidateId,
        title: isUpdate ? 'Interview updated' : 'Interview scheduled',
        body:
            'Your interview is set for ${interview.scheduledAt.toLocal()}.',
        applicationId: interview.applicationId,
        event: isUpdate
            ? NotificationEvents.hiringInterviewUpdated
            : NotificationEvents.hiringInterviewScheduled,
      );
    });
    return !state.hasError;
  }

  Future<bool> updateInterview(
    InterviewModel interview, {
    String? applicationStatus,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(interviewRepositoryProvider)
          .updateInterview(interview, applicationStatus: applicationStatus);
      final status = interview.isCancelled
          ? 'interview_cancelled'
          : interview.isCompleted
              ? 'interview_completed'
              : 'interview_updated';
      await _sendInterviewEmail(interview: interview, status: status);
      await _lifecycle.notifyHiringEvent(
        userId: interview.candidateId,
        title: status.replaceAll('_', ' '),
        body: 'Interview status: ${interview.status}.',
        applicationId: interview.applicationId,
        event: switch (status) {
          'interview_completed' =>
            NotificationEvents.hiringInterviewCompleted,
          'interview_cancelled' || 'interview_updated' =>
            NotificationEvents.hiringInterviewUpdated,
          _ => NotificationEvents.hiringStatusChanged,
        },
      );
    });
    return !state.hasError;
  }

  Future<bool> updateInterviewStatus({
    required String interviewId,
    required String status,
    String? result,
    String? applicationStatus,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(interviewRepositoryProvider)
          .updateInterviewStatus(
            interviewId: interviewId,
            status: status,
            result: result,
            applicationStatus: applicationStatus,
          );
      final interview =
          await ref.read(interviewRepositoryProvider).getInterview(interviewId);
      if (interview != null) {
        final emailStatus = status == 'cancelled'
            ? 'interview_cancelled'
            : status == 'completed'
                ? 'interview_completed'
                : 'interview_updated';
        await _sendInterviewEmail(interview: interview, status: emailStatus);
        await _lifecycle.notifyHiringEvent(
          userId: interview.candidateId,
          title: emailStatus.replaceAll('_', ' '),
          body: 'Interview status: $status.',
          applicationId: interview.applicationId,
          event: switch (emailStatus) {
            'interview_completed' =>
              NotificationEvents.hiringInterviewCompleted,
            'interview_cancelled' || 'interview_updated' =>
              NotificationEvents.hiringInterviewUpdated,
            _ => NotificationEvents.hiringStatusChanged,
          },
        );
      }
    });
    return !state.hasError;
  }

  Future<void> _sendInterviewEmail({
    required InterviewModel interview,
    required String status,
  }) async {
    try {
      final config = await ref.read(emailJsMailerServiceProvider).loadConfig();
      if (!config.sendHiringEmails) return;
      final candidate =
          await ref.read(userRepositoryProvider).getUser(interview.candidateId);
      final company =
          await ref.read(userRepositoryProvider).getUser(interview.companyId);
      final job = await ref.read(jobRepositoryProvider).getJob(interview.jobId);
      await ref.read(emailJsMailerServiceProvider).send(
            SkillForgeEmailTemplates.hiringStatus(
              applicationId: interview.applicationId,
              toEmail: candidate?.email ?? '',
              toName: candidate?.fullName ?? 'Candidate',
              companyName: company?.fullName ?? 'SkillForge company',
              jobTitle: job?.title ?? 'your applied role',
              status: status,
              nextSteps: status == 'interview_cancelled'
                  ? 'Your interview was cancelled. Watch for updates.'
                  : 'Please review interview details in My Interviews.',
              actionUrl: '',
            ),
            triggeredBy: interview.companyId,
            config: config,
          );
    } catch (_) {
      AppLogger.warn('Interview status email could not be sent.');
    }
  }
}
