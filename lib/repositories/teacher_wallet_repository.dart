import '../models/teacher_wallet_model.dart';

abstract class TeacherWalletRepository {
  Stream<TeacherWalletModel?> watchWallet(String teacherId);

  Stream<List<TeacherWalletTransactionModel>> watchTransactions(String teacherId);

  Future<void> ensureWallet(String teacherId);

  /// Reconcile wallet totals from [course_purchases] (read-only source).
  Future<void> syncFromCourseSales(String teacherId);

  /// Demo: move pending course earnings into available balance.
  Future<void> releasePendingEarnings(String teacherId);

  /// Demo: withdraw available balance (no real payout).
  Future<void> demoWithdraw(String teacherId, {double? amount});
}
