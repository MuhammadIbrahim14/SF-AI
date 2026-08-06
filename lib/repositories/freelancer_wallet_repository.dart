import '../models/commerce_transaction_model.dart';
import '../models/freelancer_wallet_model.dart';

abstract class FreelancerWalletRepository {
  Stream<FreelancerWalletModel?> watchWallet(String freelancerId);
  Stream<List<FreelancerWalletModel>> watchAdminWallets();
  Stream<List<CommerceTransactionModel>> watchWalletTransactions(
    String freelancerId,
  );

  Future<void> ensureWallet(String freelancerId);
  Future<void> releaseEscrowForCompletedRequest({
    required String requestId,
    required String clientId,
  });
  Future<void> clearSandboxFunds(String freelancerId);
}
