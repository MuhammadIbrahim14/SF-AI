import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/repository_providers.dart';
import '../data/models/smart_resume_model.dart';
import '../data/services/resume_intelligence_service.dart';

final resumeIntelligenceServiceProvider = Provider<ResumeIntelligenceService>((
  ref,
) {
  return ResumeIntelligenceService(ref.watch(firestoreProvider));
});

final smartResumeProvider = StreamProvider<SmartResumeModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(resumeIntelligenceServiceProvider).watchResume(user.uid);
});

final resumeActionProvider = AsyncNotifierProvider<ResumeActionNotifier, void>(
  ResumeActionNotifier.new,
);

class ResumeActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> generateMyResume() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in student is required.');
      await ref
          .read(resumeIntelligenceServiceProvider)
          .generateResume(user.uid);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}
