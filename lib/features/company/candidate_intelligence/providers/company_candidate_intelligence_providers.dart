import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/firebase_providers.dart';
import '../../../../providers/repository_providers.dart';
import '../../../courses/providers/certificate_provider.dart';
import '../../../interview_lab/providers/interview_lab_providers.dart';
import '../models/company_candidate_intelligence_models.dart';
import '../services/company_candidate_intelligence_service.dart';

final companyCandidateIntelligenceServiceProvider =
    Provider<CompanyCandidateIntelligenceService>((ref) {
  return CompanyCandidateIntelligenceService(
    firestore: ref.watch(firestoreProvider),
    userRepository: ref.watch(userRepositoryProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
    jobRepository: ref.watch(jobRepositoryProvider),
    interviewLabRepository: ref.watch(interviewLabRepositoryProvider),
    certificateRepository: ref.watch(certificateRepositoryProvider),
  );
});

final companyCandidateIntelligenceProvider = FutureProvider.autoDispose
    .family<CompanyCandidateIntelligenceProfile, String>((ref, applicationId) {
  return ref
      .watch(companyCandidateIntelligenceServiceProvider)
      .loadProfile(applicationId: applicationId);
});

final companyCandidateIntelligenceActionProvider = AsyncNotifierProvider<
    CompanyCandidateIntelligenceActionNotifier, void>(
  CompanyCandidateIntelligenceActionNotifier.new,
);

class CompanyCandidateIntelligenceActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  CompanyCandidateIntelligenceService get _service =>
      ref.read(companyCandidateIntelligenceServiceProvider);

  Future<CompanyCandidateIntelligenceProfile?> enrich(String applicationId) async {
    CompanyCandidateIntelligenceProfile? result;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final base = await _service.loadProfile(applicationId: applicationId);
      result = await _service.enrichWithAi(base);
      ref.invalidate(companyCandidateIntelligenceProvider(applicationId));
    });
    return state.hasError ? null : result;
  }

  Future<List<CompanyCandidateComparisonRow>?> compare({
    required String jobId,
    required List<String> applicationIds,
  }) async {
    List<CompanyCandidateComparisonRow>? rows;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      rows = await _service.compareCandidates(
        jobId: jobId,
        applicationIds: applicationIds,
      );
    });
    return state.hasError ? null : rows;
  }

  String? get lastErrorMessage {
    final err = state.error;
    return err?.toString();
  }
}
