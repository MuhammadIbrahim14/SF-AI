import '../models/customer_wallet_model.dart';

abstract class CustomerWalletRepository {
  Stream<CustomerWalletModel?> watchMyWallet(String customerId);
  Stream<List<WalletTransactionModel>> watchMyWalletTransactions(
    String customerId,
  );

  Future<CustomerWalletModel> getOrCreateMyWallet(String customerId);
  Future<void> addDemoBalance({
    required String customerId,
    required double amount,
  });
  Future<void> payOrderFromWallet({
    required String customerId,
    required String orderId,
  });
  Future<void> completeOrderAndReleaseEscrow({
    required String customerId,
    required String orderId,
  });
}
