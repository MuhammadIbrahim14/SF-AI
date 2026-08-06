import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../courses/data/models/marketplace_models.dart';
import '../../courses/data/repositories/course_purchase_repository.dart';
import '../config/stripe_config.dart';
import '../data/payment_repository.dart';
import '../models/payment_intent_model.dart';
import '../models/payment_models.dart';
import '../models/stripe_models.dart';
import '../services/demo_payment_notification_helper.dart';
import '../services/payfast_checkout_service.dart';
import '../services/payment_service.dart';
import '../services/stripe_checkout_service.dart';
import '../services/teacher_subscription_service.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(firestoreProvider));
});

final payFastCheckoutServiceProvider = Provider<PayFastCheckoutService>((ref) {
  return PayFastCheckoutService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Stripe Test (sandbox) client. Demo checkout stays the default path.
final stripeCheckoutServiceProvider = Provider<StripeCheckoutService>((ref) {
  return StripeCheckoutService(auth: ref.watch(firebaseAuthProvider));
});

/// Gateway capability probe (`GET /api/stripe/config`). Never throws.
final stripeGatewayConfigProvider = FutureProvider<StripeGatewayConfig>((
  ref,
) async {
  if (!StripeConfig.enabled) return const StripeGatewayConfig.unavailable();
  return ref.read(stripeCheckoutServiceProvider).fetchConfig();
});

/// Whether the Demo | Stripe chooser is offered.
///
/// Three gates, all of which must pass: the `STRIPE_ENABLED` dart-define, an
/// admin kill switch at `settings/payments.stripeEnabled`, and the gateway
/// reporting usable **test** Stripe keys.
final stripePaymentsEnabledProvider = FutureProvider<bool>((ref) async {
  if (!StripeConfig.enabled) return false;

  try {
    final doc = await ref
        .watch(firestoreProvider)
        .collection('settings')
        .doc('payments')
        .get();
    if (doc.data()?['stripeEnabled'] == false) return false;
  } catch (error) {
    AppLogger.warn('Stripe kill switch unreadable, deferring to gateway: $error');
  }

  final config = await ref.watch(stripeGatewayConfigProvider.future);
  return config.isUsable;
});

/// Phase 4 — Connect Express (test mode) status for the signed-in seller.
final stripeConnectStatusProvider =
    FutureProvider.family<StripeConnectStatus, String>((ref, role) async {
  final enabled = await ref.watch(stripePaymentsEnabledProvider.future);
  if (!enabled) {
    return const StripeConnectStatus.unavailable(
      'Stripe Test payouts are turned off for this build.',
    );
  }
  return ref.read(stripeCheckoutServiceProvider).connectStatus(role: role);
});

final demoPaymentNotificationHelperProvider =
    Provider<DemoPaymentNotificationHelper>((ref) {
  return DemoPaymentNotificationHelper(
    ref.watch(notificationServiceProvider),
  );
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(
    ref.watch(paymentRepositoryProvider),
    checkoutService: ref.watch(payFastCheckoutServiceProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});

final teacherSubscriptionServiceProvider = Provider<TeacherSubscriptionService>(
  (ref) {
    return TeacherSubscriptionService(
      ref.watch(paymentRepositoryProvider),
      ref.watch(paymentServiceProvider),
    );
  },
);

// Auto-initialize payment data on first access
final paymentDataInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(paymentRepositoryProvider).seedDefaultConfiguration();
});

final teacherSubscriptionAccessProvider =
    FutureProvider.family<TeacherSubscriptionAccess, String>((ref, teacherId) async {
      if (teacherId.trim().isEmpty) {
        return TeacherSubscriptionAccess.free();
      }
      ref.watch(paymentDataInitProvider);

      final access = await ref
          .read(teacherSubscriptionServiceProvider)
          .getAccessForTeacher(teacherId);

      // Keep AI builder credits in sync with the active teaching plan.
      if (access.isPremium && access.maxAiCreditsPerMonth > 0) {
        try {
          await ref.read(paymentRepositoryProvider).syncAiUserCredits(
            userId: teacherId,
            role: 'teacher',
            monthlyFreeCredits: access.maxAiCreditsPerMonth,
          );
        } catch (_) {
          AppLogger.warn('Teacher AI credit sync could not be completed.');
        }
      }

      return access;
    });

final paymentPlansProvider = FutureProvider<List<PaymentPlanModel>>((
  ref,
) async {
  return ref.watch(paymentRepositoryProvider).getPlans();
});

final paymentCreditPacksProvider = FutureProvider<List<CreditPackModel>>((
  ref,
) async {
  return ref.watch(paymentRepositoryProvider).getCreditPacks();
});

final paymentTeacherPurchaseHistoryProvider =
    FutureProvider.family<List<PaymentRecordModel>, String>((ref, teacherId) {
  if (teacherId.trim().isEmpty) {
    return Future.value(<PaymentRecordModel>[]);
  }
  return ref.read(paymentRepositoryProvider).getPayments(userId: teacherId);
});

final teacherActiveSubscriptionProvider =
    FutureProvider.family<PaymentSubscriptionModel?, String>((ref, userId) async {
  if (userId.trim().isEmpty) return null;
  await ref
      .read(teacherSubscriptionServiceProvider)
      .finalizeExpiredCancellationIfNeeded(userId);
  return ref.read(paymentRepositoryProvider).getSubscriptionForUser(userId);
});

/// Aggregated teacher monetization snapshot for the billing / earnings hub.
final teacherEarningsSummaryProvider =
    FutureProvider.family<TeacherEarningsSummary, String>((ref, teacherId) async {
  if (teacherId.trim().isEmpty) {
    return TeacherEarningsSummary.empty();
  }

  final purchaseRepo = CoursePurchaseRepository(ref.watch(firestoreProvider));
  final paymentRepo = ref.watch(paymentRepositoryProvider);

  final sales = await purchaseRepo.getTeacherSalesHistory(teacherId);
  final payments = await paymentRepo.getPayments(userId: teacherId);
  final subscription = await paymentRepo.getSubscriptionForUser(teacherId);
  final access = await ref
      .read(teacherSubscriptionServiceProvider)
      .getAccessForTeacher(teacherId);

  final courseRevenue = sales.fold<double>(
    0,
    (sum, sale) => sum + sale.finalAmount,
  );

  final byCourse = <String, CourseEarningsRow>{};
  for (final sale in sales) {
    final existing = byCourse[sale.courseId];
    if (existing == null) {
      byCourse[sale.courseId] = CourseEarningsRow(
        courseId: sale.courseId,
        salesCount: 1,
        revenue: sale.finalAmount,
        currency: sale.currency,
      );
    } else {
      byCourse[sale.courseId] = CourseEarningsRow(
        courseId: sale.courseId,
        salesCount: existing.salesCount + 1,
        revenue: existing.revenue + sale.finalAmount,
        currency: sale.currency,
      );
    }
  }

  final courseRows = byCourse.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  final planSpend = payments
      .where(
        (p) =>
            p.type == PaymentType.plan && PaymentStatus.isSuccess(p.status),
      )
      .fold<double>(0, (sum, p) => sum + p.amount);

  final creditSpend = payments
      .where(
        (p) =>
            p.type == PaymentType.creditPack &&
            PaymentStatus.isSuccess(p.status),
      )
      .fold<double>(0, (sum, p) => sum + p.amount);

  final cancelEvents = payments
      .where((p) => p.type == PaymentType.subscriptionCancel)
      .toList();

  final recentSales = sales.take(8).toList();
  final now = DateTime.now();
  final monthSales = sales.where(
    (s) =>
        s.purchasedAt.year == now.year && s.purchasedAt.month == now.month,
  );
  final monthRevenue = monthSales.fold<double>(
    0,
    (sum, s) => sum + s.finalAmount,
  );

  return TeacherEarningsSummary(
    totalCourseRevenue: courseRevenue,
    monthCourseRevenue: monthRevenue,
    totalSalesCount: sales.length,
    monthSalesCount: monthSales.length,
    planSpend: planSpend,
    creditSpend: creditSpend,
    currency: sales.isNotEmpty
        ? sales.first.currency
        : (payments.isNotEmpty ? payments.first.currency : 'USD'),
    courseRows: courseRows,
    recentSales: recentSales,
    cancelEvents: cancelEvents,
    subscription: subscription,
    access: access,
    ownPayments: payments.take(12).toList(),
  );
});

class CourseEarningsRow {
  const CourseEarningsRow({
    required this.courseId,
    required this.salesCount,
    required this.revenue,
    required this.currency,
  });

  final String courseId;
  final int salesCount;
  final double revenue;
  final String currency;
}

class TeacherEarningsSummary {
  const TeacherEarningsSummary({
    required this.totalCourseRevenue,
    required this.monthCourseRevenue,
    required this.totalSalesCount,
    required this.monthSalesCount,
    required this.planSpend,
    required this.creditSpend,
    required this.currency,
    required this.courseRows,
    required this.recentSales,
    required this.cancelEvents,
    required this.subscription,
    required this.access,
    required this.ownPayments,
  });

  factory TeacherEarningsSummary.empty() {
    return TeacherEarningsSummary(
      totalCourseRevenue: 0,
      monthCourseRevenue: 0,
      totalSalesCount: 0,
      monthSalesCount: 0,
      planSpend: 0,
      creditSpend: 0,
      currency: 'USD',
      courseRows: const [],
      recentSales: const [],
      cancelEvents: const [],
      subscription: null,
      access: TeacherSubscriptionAccess.free(),
      ownPayments: const [],
    );
  }

  final double totalCourseRevenue;
  final double monthCourseRevenue;
  final int totalSalesCount;
  final int monthSalesCount;
  final double planSpend;
  final double creditSpend;
  final String currency;
  final List<CourseEarningsRow> courseRows;
  final List<CoursePurchase> recentSales;
  final List<PaymentRecordModel> cancelEvents;
  final PaymentSubscriptionModel? subscription;
  final TeacherSubscriptionAccess access;
  final List<PaymentRecordModel> ownPayments;
}

final paymentTeacherAiCreditsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, teacherId) async {
  if (teacherId.trim().isEmpty) {
    return {'monthly': 100, 'remaining': 100, 'used': 0};
  }

  final access = await ref
      .read(teacherSubscriptionServiceProvider)
      .getAccessForTeacher(teacherId);
  final monthly = access.maxAiCreditsPerMonth;
  return {
    'monthly': monthly,
    'remaining': monthly,
    'used': 0,
  };
});

final myPaymentIntentsProvider =
    FutureProvider.family<List<PaymentIntentModel>, String>((ref, userId) async {
  if (userId.trim().isEmpty) return const [];
  return ref.read(payFastCheckoutServiceProvider).listForUser(userId);
});

final adminAllPaymentIntentsProvider =
    FutureProvider<List<PaymentIntentModel>>((ref) async {
  return ref.read(payFastCheckoutServiceProvider).listAll();
});

final paymentActionProvider =
    AsyncNotifierProvider<PaymentActionNotifier, PaymentProcessResult?>(
      PaymentActionNotifier.new,
    );

class PaymentActionNotifier extends AsyncNotifier<PaymentProcessResult?> {
  @override
  Future<PaymentProcessResult?> build() async => null;

  Future<void> seedDefaultConfiguration() async {
    state = const AsyncLoading();
    try {
      await ref.read(paymentServiceProvider).initializeSeedData();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<PaymentProcessResult> processPayment({
    required String userId,
    required String type,
    required String description,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? planId,
    String? creditPackId,
    String? teacherId,
    String? role,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<PaymentProcessResult>(
      () => ref.read(paymentServiceProvider).processPayment(
            userId: userId,
            type: type,
            description: description,
            amount: amount,
            currency: currency,
            paymentMethod: paymentMethod,
            planId: planId,
            creditPackId: creditPackId,
            teacherId: teacherId,
            role: role,
            metadata: metadata,
          ),
    );
    state = result;
    return result.value ??
        const PaymentProcessResult(
          transactionId: '',
          paymentId: '',
          status: PaymentStatus.failed,
          message: 'Payment could not be completed.',
          amount: 0,
          currency: 'PKR',
        );
  }
}
