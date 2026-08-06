import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/jobs/services/job_matching_service.dart';
import '../models/job_match_model.dart';
import 'firebase_providers.dart';
import 'job_provider.dart';
import 'user_provider.dart';

final jobMatchingServiceProvider = Provider<JobMatchingService>((ref) {
  return JobMatchingService(ref.watch(firestoreProvider));
});

final matchedJobsProvider = FutureProvider<List<MatchedJobModel>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const <MatchedJobModel>[];
  final role = user.primaryRole ?? 'student';
  if (role != 'student' && role != 'freelancer') {
    return const <MatchedJobModel>[];
  }
  final jobs = await ref.watch(allJobsProvider.future);
  return ref
      .watch(jobMatchingServiceProvider)
      .matchJobsForCandidate(
        jobs: jobs,
        candidateId: user.uid,
        candidateRole: role,
      );
});

final rankedJobApplicantsProvider =
    FutureProvider.family<List<RankedCandidateModel>, String>((
      ref,
      jobId,
    ) async {
      final job = await ref.watch(jobDetailProvider(jobId).future);
      if (job == null) return const <RankedCandidateModel>[];
      return ref.watch(jobMatchingServiceProvider).rankCandidatesForJob(job);
    });
