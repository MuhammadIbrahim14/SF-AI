import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job_model.dart';
import 'auth_provider.dart';
import 'company_permission_provider.dart';
import 'repository_providers.dart';

/// Streams all active jobs in the platform.
final allJobsProvider = StreamProvider<List<JobModel>>((ref) {
  return ref.watch(jobRepositoryProvider).streamAllJobs();
});

/// Streams jobs created by the currently authenticated company.
final companyJobsProvider = StreamProvider<List<JobModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.watch(jobRepositoryProvider).streamJobsByCompany(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

/// Fetches a single job by its ID.
final jobDetailProvider = FutureProvider.family<JobModel?, String>((
  ref,
  jobId,
) {
  return ref.watch(jobRepositoryProvider).getJob(jobId);
});

/// Notifier to handle creating, updating, and deleting jobs.
final jobActionProvider = AsyncNotifierProvider<JobActionNotifier, void>(
  JobActionNotifier.new,
);

class JobActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createJob(JobModel job) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref.read(jobRepositoryProvider).createJob(job);
    });
    return !state.hasError;
  }

  Future<bool> updateJob(JobModel job) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref.read(jobRepositoryProvider).updateJob(job);
    });
    return !state.hasError;
  }

  Future<bool> deleteJob(String jobId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final permission = await ref.read(companyPermissionProvider.future);
      permission.ensureCanManageHiring();
      await ref.read(jobRepositoryProvider).deleteJob(jobId);
    });
    return !state.hasError;
  }
}
