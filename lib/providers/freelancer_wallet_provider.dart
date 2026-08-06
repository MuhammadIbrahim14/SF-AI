import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commerce_transaction_model.dart';
import '../models/freelancer_wallet_model.dart';
import '../repositories/freelancer_wallet_repository.dart';
import '../repositories/freelancer_wallet_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'repository_providers.dart';

final freelancerWalletRepositoryProvider = Provider<FreelancerWalletRepository>(
  (ref) {
    return FreelancerWalletRepositoryImpl(ref.watch(firestoreProvider));
  },
);

final myFreelancerWalletProvider = StreamProvider<FreelancerWalletModel?>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(freelancerWalletRepositoryProvider).watchWallet(user.uid);
});

final adminFreelancerWalletsProvider =
    StreamProvider<List<FreelancerWalletModel>>((ref) {
      return ref.watch(freelancerWalletRepositoryProvider).watchAdminWallets();
    });

final myWalletTransactionsProvider =
    StreamProvider<List<CommerceTransactionModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <CommerceTransactionModel>[]);
      return ref
          .watch(freelancerWalletRepositoryProvider)
          .watchWalletTransactions(user.uid);
    });

final freelancerWalletActionProvider =
    AsyncNotifierProvider<FreelancerWalletActionNotifier, void>(
      FreelancerWalletActionNotifier.new,
    );

class FreelancerWalletActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> ensureWallet() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      await ref.read(freelancerWalletRepositoryProvider).ensureWallet(user.uid);
    });
    return !state.hasError;
  }

  Future<bool> releaseEscrowForCompletedRequest(String requestId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      await ref
          .read(freelancerWalletRepositoryProvider)
          .releaseEscrowForCompletedRequest(
            requestId: requestId,
            clientId: user.uid,
          );
    });
    return !state.hasError;
  }

  Future<bool> clearSandboxFunds() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      await ref
          .read(freelancerWalletRepositoryProvider)
          .clearSandboxFunds(user.uid);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}
