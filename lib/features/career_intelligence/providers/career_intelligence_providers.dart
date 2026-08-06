import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/user_provider.dart';
import '../../interview_lab/providers/interview_lab_providers.dart';
import '../models/career_intelligence_models.dart';
import '../services/career_intelligence_service.dart';

final careerIntelligenceServiceProvider = Provider<CareerIntelligenceService>((
  ref,
) {
  return CareerIntelligenceService(
    firestore: ref.watch(firestoreProvider),
    labRepository: ref.watch(interviewLabRepositoryProvider),
  );
});

final careerIntelligenceReportProvider =
    FutureProvider.autoDispose<CareerIntelligenceReport?>((ref) async {
      final auth = await ref.watch(authStateProvider.future);
      if (auth == null) return null;
      final user = await ref.watch(currentUserProvider.future);
      if (user == null) return null;
      return ref.read(careerIntelligenceServiceProvider).loadReport(
            userId: auth.uid,
            role: (user.primaryRole ?? 'student').toLowerCase(),
          );
    });

final careerIntelligenceActionProvider =
    AsyncNotifierProvider<CareerIntelligenceActionNotifier, void>(
      CareerIntelligenceActionNotifier.new,
    );

class CareerIntelligenceActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<CareerIntelligenceReport?> refresh() async {
    state = const AsyncLoading();
    CareerIntelligenceReport? report;
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authStateProvider).value;
      final user = ref.read(currentUserProvider).asData?.value;
      if (auth == null || user == null) {
        throw StateError('Sign-in required.');
      }
      report = await ref.read(careerIntelligenceServiceProvider).loadReport(
            userId: auth.uid,
            role: (user.primaryRole ?? 'student').toLowerCase(),
            forceRefresh: true,
          );
      ref.invalidate(careerIntelligenceReportProvider);
    });
    return report;
  }

  Future<CareerIntelligenceReport?> runTask(String taskType) async {
    state = const AsyncLoading();
    CareerIntelligenceReport? report;
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authStateProvider).value;
      final user = ref.read(currentUserProvider).asData?.value;
      if (auth == null || user == null) {
        throw StateError('Sign-in required.');
      }
      report = await ref
          .read(careerIntelligenceServiceProvider)
          .runFocusedReview(
            userId: auth.uid,
            role: (user.primaryRole ?? 'student').toLowerCase(),
            taskType: taskType,
          );
      ref.invalidate(careerIntelligenceReportProvider);
    });
    return report;
  }
}
