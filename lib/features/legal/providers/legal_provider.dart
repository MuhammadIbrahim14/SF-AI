import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/repository_providers.dart';
import '../domain/models/legal_policy.dart';

final legalPoliciesProvider = StreamProvider<LegalPolicies?>((ref) {
  return FirebaseFirestore.instance
      .collection('platform_settings')
      .doc('legal')
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return LegalPolicies.fromJson(snapshot.data()!);
      });
});

final legalEditorProvider = AsyncNotifierProvider<LegalEditorNotifier, void>(
  LegalEditorNotifier.new,
);

class LegalEditorNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> savePolicies(LegalPolicies policies) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Not authenticated');

      final toSave = policies.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: user.uid,
      );

      await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('legal')
          .set(toSave.toJson());
    });
    return !state.hasError;
  }
}
