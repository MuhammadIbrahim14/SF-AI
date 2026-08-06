import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../models/application_model.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/user_model.dart';
import '../../../../providers/application_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/company_permission_provider.dart';
import '../../../../providers/firebase_providers.dart';
import '../../../../providers/interview_provider.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../providers/repository_providers.dart';
import '../services/employment_hr_thread_repository.dart';
import '../services/hiring_lifecycle_service.dart';

final employmentHrThreadRepositoryProvider =
    Provider<EmploymentHrThreadRepository>((ref) {
      return EmploymentHrThreadRepository(ref.watch(firestoreProvider));
    });

final hiringLifecycleServiceProvider = Provider<HiringLifecycleService>((ref) {
  return HiringLifecycleService(
    ref.watch(applicationRepositoryProvider),
    ref.watch(notificationServiceProvider),
    hrThreads: ref.watch(employmentHrThreadRepositoryProvider),
  );
});

final hiringUserProvider = FutureProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepositoryProvider).getUser(uid);
});

final applicationTimelineProvider =
    StreamProvider.family<List<HiringTimelineEvent>, String>((
      ref,
      applicationId,
    ) {
      return ref
          .watch(applicationRepositoryProvider)
          .streamTimeline(applicationId);
    });

/// Prefer [myNotificationsProvider]; alias kept for hiring screens.
final myHiringNotificationsProvider = myNotificationsProvider;

final companyHiringAnalyticsProvider = Provider<HiringAnalyticsSnapshot>((ref) {
  final applications =
      ref.watch(companyApplicationsProvider).asData?.value ??
      const <ApplicationModel>[];
  final interviews =
      ref.watch(companyInterviewsProvider).asData?.value ?? const [];
  return ref
      .watch(hiringLifecycleServiceProvider)
      .buildAnalytics(applications: applications, interviews: interviews);
});

final companyEmployeesProvider = Provider<List<ApplicationModel>>((ref) {
  final applications =
      ref.watch(companyApplicationsProvider).asData?.value ??
      const <ApplicationModel>[];
  return applications
      .where(
        (a) =>
            a.isActiveEmployee ||
            a.isJoiningSoon ||
            a.isLeftEmployee ||
            a.normalizedPipelineStage == 'hired',
      )
      .toList()
    ..sort((a, b) {
      final aJoined = a.joinedAt ?? a.offerRespondedAt ?? a.appliedAt;
      final bJoined = b.joinedAt ?? b.offerRespondedAt ?? b.appliedAt;
      return bJoined.compareTo(aJoined);
    });
});

/// Candidate employment portal list (joining / active / left).
final myEmploymentProvider = Provider<List<ApplicationModel>>((ref) {
  final applications =
      ref.watch(myApplicationsProvider).asData?.value ??
      const <ApplicationModel>[];
  return applications
      .where((a) => a.isJoiningSoon || a.isActiveEmployee || a.isLeftEmployee)
      .toList()
    ..sort((a, b) {
      final aKey = a.joinedAt ?? a.offerRespondedAt ?? a.appliedAt;
      final bKey = b.joinedAt ?? b.offerRespondedAt ?? b.appliedAt;
      return bKey.compareTo(aKey);
    });
});

final employmentHrMessagesProvider =
    StreamProvider.family<List<EmploymentHrMessage>, String>((ref, threadId) {
      if (threadId.trim().isEmpty) {
        return Stream.value(const <EmploymentHrMessage>[]);
      }
      return ref
          .watch(hiringLifecycleServiceProvider)
          .streamHrMessages(threadId);
    });

final hiringLifecycleActionProvider =
    AsyncNotifierProvider<HiringLifecycleActionNotifier, void>(
      HiringLifecycleActionNotifier.new,
    );

class HiringLifecycleActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String? get lastErrorMessage {
    final err = state.error;
    if (err == null) return null;
    if (err is AppException) return err.message;
    return err.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<bool> markJoined(String applicationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .markJoined(applicationId: applicationId);
    });
    return !state.hasError;
  }

  Future<bool> toggleOnboardingItem({
    required String applicationId,
    required String itemId,
    required bool completed,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .updateOnboardingItem(
            applicationId: applicationId,
            itemId: itemId,
            completed: completed,
          );
    });
    return !state.hasError;
  }

  Future<bool> candidateToggleOnboardingItem({
    required String applicationId,
    required String itemId,
    required bool completed,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not signed in.');
      final app = await ref
          .read(applicationRepositoryProvider)
          .getApplication(applicationId);
      if (app == null || app.applicantId != uid) {
        throw Exception('Not allowed to update this checklist.');
      }
      final ok = await ref
          .read(hiringLifecycleServiceProvider)
          .updateOnboardingItem(
            applicationId: applicationId,
            itemId: itemId,
            completed: completed,
            candidateOnly: true,
          );
      if (!ok) {
        throw Exception('This checklist item cannot be completed by you.');
      }
    });
    return !state.hasError;
  }

  Future<bool> publishWelcomePack({
    required String applicationId,
    required WelcomePack pack,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      final uid = ref.read(authStateProvider).asData?.value?.uid ?? '';
      await ref
          .read(hiringLifecycleServiceProvider)
          .publishWelcomePack(
            applicationId: applicationId,
            pack: pack,
            publishedBy: uid,
          );
    });
    return !state.hasError;
  }

  Future<bool> updateEmploymentProfile({
    required String applicationId,
    required EmploymentProfile profile,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .updateEmploymentProfile(
            applicationId: applicationId,
            profile: profile,
          );
    });
    return !state.hasError;
  }

  Future<bool> addEmploymentDocument({
    required String applicationId,
    required EmploymentDocument document,
    required bool asCandidate,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not signed in.');
      if (asCandidate) {
        final app = await ref
            .read(applicationRepositoryProvider)
            .getApplication(applicationId);
        if (app == null || app.applicantId != uid) {
          throw Exception('Not allowed to upload documents.');
        }
      } else {
        final permission = await ref.read(companyPermissionProvider.future);
        permission.ensureCanManageHiring();
      }
      await ref
          .read(hiringLifecycleServiceProvider)
          .addEmploymentDocument(
            applicationId: applicationId,
            document: document,
            actorId: uid,
            asCandidate: asCandidate,
          );
    });
    return !state.hasError;
  }

  Future<String?> ensureHrThread(String applicationId) async {
    // Silent ensure — do not flip global action loading (keeps HR panel from
    // hanging behind a shared spinner while the thread is prepared).
    try {
      return await ref
          .read(hiringLifecycleServiceProvider)
          .ensureHrThread(applicationId: applicationId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> sendHrMessage({
    required String applicationId,
    required String body,
    required String senderRole,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not signed in.');
      if (senderRole == 'company') {
        final permission = await ref.read(companyPermissionProvider.future);
        permission.ensureCanManageHiring();
      }
      await ref
          .read(hiringLifecycleServiceProvider)
          .sendHrMessage(
            applicationId: applicationId,
            senderId: uid,
            senderRole: senderRole,
            body: body,
          );
    });
    return !state.hasError;
  }

  Future<bool> startProbation({
    required String applicationId,
    int days = 90,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .startProbation(applicationId: applicationId, days: days);
    });
    return !state.hasError;
  }

  Future<bool> completeProbation(
    String applicationId, {
    String notes = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .completeProbation(applicationId: applicationId, notes: notes);
    });
    return !state.hasError;
  }

  Future<bool> updateProbationDuration({
    required String applicationId,
    required int totalDays,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      final updated = await ref
          .read(hiringLifecycleServiceProvider)
          .updateProbationDuration(
            applicationId: applicationId,
            totalDays: totalDays,
          );
      if (!updated) {
        throw Exception('This probation period can no longer be edited.');
      }
    });
    return !state.hasError;
  }

  Future<bool> restartProbation({
    required String applicationId,
    int days = 90,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      final restarted = await ref
          .read(hiringLifecycleServiceProvider)
          .restartProbation(applicationId: applicationId, days: days);
      if (!restarted) {
        throw Exception('This probation period can no longer be restarted.');
      }
    });
    return !state.hasError;
  }

  Future<bool> extendProbation({
    required String applicationId,
    int extraDays = 30,
    String notes = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .extendProbation(
            applicationId: applicationId,
            extraDays: extraDays,
            notes: notes,
          );
    });
    return !state.hasError;
  }

  Future<bool> markLeft({
    required String applicationId,
    required String reason,
    String notes = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .markLeft(applicationId: applicationId, reason: reason, notes: notes);
    });
    return !state.hasError;
  }

  Future<bool> toggleOffboardingItem({
    required String applicationId,
    required String itemId,
    required bool completed,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(hiringLifecycleServiceProvider)
          .toggleOffboardingItem(
            applicationId: applicationId,
            itemId: itemId,
            completed: completed,
          );
    });
    return !state.hasError;
  }

  Future<void> runEmploymentReminders({
    required List<ApplicationModel> applications,
    required bool asCandidate,
  }) async {
    final service = ref.read(hiringLifecycleServiceProvider);
    await service.maybeSendJoinReminders(
      applications: applications,
      notifyCandidate: asCandidate,
    );
    await service.maybeSendDocsReminders(
      applications: applications,
      notifyCandidate: asCandidate,
    );
  }

  Future<bool> markAiInterviewCompleted(String applicationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            lifecycleStage: 'ai_interview_completed',
            recommendedNextStep:
                'AI interview evidence reviewed. Continue shortlist or schedule.',
          );
    });
    return !state.hasError;
  }

  Future<bool> markResumeReviewed(String applicationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: 'screening',
            lifecycleStage: 'resume_reviewed',
            candidateVisibleStatus: 'resume_reviewed',
          );
    });
    return !state.hasError;
  }

  Future<bool> markPortfolioReviewed(String applicationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref
          .read(applicationRepositoryProvider)
          .updateApplicationHiringData(
            applicationId: applicationId,
            pipelineStage: 'screening',
            lifecycleStage: 'portfolio_reviewed',
            candidateVisibleStatus: 'portfolio_reviewed',
          );
    });
    return !state.hasError;
  }
}
