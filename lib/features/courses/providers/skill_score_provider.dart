import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/repository_providers.dart';
import '../data/models/skill_score_model.dart';
import '../data/services/skill_score_service.dart';

final skillScoreServiceProvider = Provider<SkillScoreService>((ref) {
  return SkillScoreService(ref.watch(firestoreProvider));
});

final studentSkillScoresProvider = StreamProvider<List<SkillScoreModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <SkillScoreModel>[]);
  return ref.watch(skillScoreServiceProvider).watchStudentSkillScores(user.uid);
});

final studentSkillScoreDetailProvider =
    StreamProvider.family<SkillScoreModel?, String>((ref, skillName) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(null);
      return ref
          .watch(skillScoreServiceProvider)
          .watchSkillScore(studentId: user.uid, skillName: skillName);
    });

final skillScoreActionProvider =
    AsyncNotifierProvider<SkillScoreActionNotifier, void>(
      SkillScoreActionNotifier.new,
    );

class SkillScoreActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> recalculateMySkillScores() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in student is required.');
      await ref
          .read(skillScoreServiceProvider)
          .recalculateStudentSkillScores(user.uid);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}
