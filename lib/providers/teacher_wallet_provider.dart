import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/teacher_wallet_model.dart';
import '../repositories/teacher_wallet_repository.dart';
import '../repositories/teacher_wallet_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'repository_providers.dart';

final teacherWalletRepositoryProvider = Provider<TeacherWalletRepository>((ref) {
  return TeacherWalletRepositoryImpl(ref.watch(firestoreProvider));
});

final myTeacherWalletProvider = StreamProvider<TeacherWalletModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(teacherWalletRepositoryProvider).watchWallet(user.uid);
});

final myTeacherWalletTransactionsProvider =
    StreamProvider<List<TeacherWalletTransactionModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) {
        return Stream.value(const <TeacherWalletTransactionModel>[]);
      }
      return ref
          .watch(teacherWalletRepositoryProvider)
          .watchTransactions(user.uid);
    });

final teacherWalletActionProvider =
    AsyncNotifierProvider<TeacherWalletActionNotifier, void>(
      TeacherWalletActionNotifier.new,
    );

class TeacherWalletActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> ensureAndSync() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please sign in first.');
      final repo = ref.read(teacherWalletRepositoryProvider);
      await repo.ensureWallet(user.uid);
      await repo.syncFromCourseSales(user.uid);
    });
    return !state.hasError;
  }

  Future<bool> releasePending() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please sign in first.');
      await ref
          .read(teacherWalletRepositoryProvider)
          .releasePendingEarnings(user.uid);
    });
    return !state.hasError;
  }

  Future<bool> demoWithdraw({double? amount}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please sign in first.');
      await ref
          .read(teacherWalletRepositoryProvider)
          .demoWithdraw(user.uid, amount: amount);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}
