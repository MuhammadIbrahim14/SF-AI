import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payment/models/payment_models.dart';
import '../../payment/providers/payment_providers.dart';
import '../../courses/providers/purchase_provider.dart';
import '../../courses/data/models/marketplace_models.dart';

final adminPlansProvider = FutureProvider<List<PaymentPlanModel>>((ref) async {
  return ref.watch(paymentRepositoryProvider).getPlans(includeInactive: true);
});

final adminAllCreditPacksProvider = FutureProvider<List<CreditPackModel>>((ref) async {
  return ref.watch(paymentRepositoryProvider).getCreditPacks(includeInactive: true);
});

final adminTransactionsProvider = FutureProvider.family<List<PaymentTransactionModel>, Map<String, dynamic>>(
  (ref, params) async {
    final status = params['status'] as String?;
    final since = params['since'] as DateTime?;
    return ref.watch(paymentRepositoryProvider).getTransactions(status: status, since: since);
  },
);

final adminPaymentsProvider = FutureProvider.family<List<PaymentRecordModel>, Map<String, String?>>(
  (ref, params) async {
    final status = params['status'];
    final type = params['type'];
    final teacherId = params['teacherId'];
    final userId = params['userId'];
    return ref.watch(paymentRepositoryProvider).getPayments(
      status: status,
      type: type,
      teacherId: teacherId,
      userId: userId,
    );
  },
);

final adminActiveSubscriptionsProvider = FutureProvider<List<PaymentSubscriptionModel>>((ref) async {
  return ref.watch(paymentRepositoryProvider).getActiveSubscriptions();
});

final adminExpiredSubscriptionsProvider = FutureProvider<List<PaymentSubscriptionModel>>((ref) async {
  return ref.watch(paymentRepositoryProvider).getExpiredSubscriptions();
});

final adminPendingPaymentsProvider = FutureProvider<List<PaymentRecordModel>>((ref) async {
  return ref.watch(paymentRepositoryProvider).getPayments(status: PaymentStatus.pending);
});

// Revenue summary for last N days
final revenueSummaryProvider = FutureProvider.family<double, int>((ref, days) async {
  final since = DateTime.now().subtract(Duration(days: days));
  final payments = await ref.watch(paymentRepositoryProvider).getPayments(status: PaymentStatus.success);
  final recent = payments.where((p) => p.createdAt.isAfter(since));
  final total = recent.fold<double>(0, (s, p) => s + p.amount);
  return total;
});

final teacherEarningsProvider = FutureProvider.family<List<Map<String, dynamic>>, DateTime?>((ref, since) async {
  final repo = ref.watch(coursePurchaseRepositoryProvider);
  final purchases = await repo.getAllPurchases(since: since);
  final Map<String, double> sums = {};
  for (final p in purchases) {
    sums[p.teacherId] = (sums[p.teacherId] ?? 0) + (p.finalAmount ?? 0);
  }
  final list = sums.entries.map((e) => {'teacherId': e.key, 'revenue': e.value}).toList();
  list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
  return list;
});

final paidCourseSalesProvider = FutureProvider.family<List<CoursePurchase>, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(coursePurchaseRepositoryProvider);
  final courseId = params['courseId'] as String?;
  final since = params['since'] as DateTime?;
  if (courseId != null && courseId.isNotEmpty) return repo.getCoursePurchases(courseId);
  return repo.getAllPurchases(since: since);
});

final studentPurchasesProvider = FutureProvider.family<List<CoursePurchase>, String?>((ref, studentId) async {
  final repo = ref.watch(coursePurchaseRepositoryProvider);
  if (studentId == null || studentId.isEmpty) return repo.getAllPurchases();
  return repo.getStudentPurchaseHistory(studentId);
});
