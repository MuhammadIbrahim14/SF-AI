import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/firebase_providers.dart';
import '../../payment/providers/payment_providers.dart';
import '../data/models/marketplace_models.dart';
import '../data/repositories/course_purchase_repository.dart';
import '../data/services/course_purchase_service.dart';
import 'enrollment_provider.dart';

// ==================== REPOSITORY & SERVICE PROVIDERS ====================
final coursePurchaseRepositoryProvider =
    Provider<CoursePurchaseRepository>((ref) {
  return CoursePurchaseRepository(ref.watch(firestoreProvider));
});

final coursePurchaseServiceProvider = Provider<CoursePurchaseService>((ref) {
  return CoursePurchaseService(
    ref.watch(coursePurchaseRepositoryProvider),
    ref.watch(enrollmentRepositoryProvider),
    paymentService: ref.watch(paymentServiceProvider),
    teacherSubscriptionService: ref.watch(teacherSubscriptionServiceProvider),
  );
});

// ==================== MARKETPLACE CONFIG ====================
final marketplaceConfigProvider = FutureProvider<MarketplaceConfig>((ref) {
  return ref.watch(coursePurchaseRepositoryProvider).getMarketplaceConfig();
});

// ==================== PAID COURSE CONFIGURATION ====================
final paidCourseConfigProvider =
    FutureProvider.family<PaidCourseConfig, String>((ref, courseId) {
  return ref
      .watch(coursePurchaseRepositoryProvider)
      .getPaidCourseConfig(courseId);
});

final allPaidCoursesProvider = FutureProvider<List<PaidCourseConfig>>((ref) {
  return ref.watch(coursePurchaseRepositoryProvider).getPaidCourses();
});

// ==================== PURCHASE HISTORY ====================
final studentPurchaseHistoryProvider =
    FutureProvider.family<List<CoursePurchase>, String>((ref, studentId) {
  return ref
      .watch(coursePurchaseServiceProvider)
      .getStudentPurchaseHistory(studentId);
});

final teacherSalesHistoryProvider =
    FutureProvider.family<List<CoursePurchase>, String>((ref, teacherId) {
  return ref
      .watch(coursePurchaseServiceProvider)
      .getTeacherSalesHistory(teacherId);
});

// ==================== PURCHASE VALIDATION ====================
final purchaseValidationProvider = FutureProvider.family<
    PurchaseValidationResult,
    ({String studentId, String courseId, String teacherId})>((
  ref,
  params,
) {
  return ref.watch(coursePurchaseServiceProvider).validatePurchase(
    studentId: params.studentId,
    courseId: params.courseId,
    teacherId: params.teacherId,
  );
});

// ==================== PRICING SETUP VALIDATION ====================
final pricingValidationProvider = FutureProvider.family<
    PurchaseValidationResult,
    ({double price, String currency, double discount})>((ref, params) {
  return ref.watch(coursePurchaseServiceProvider).validatePricingSetup(
    price: params.price,
    currency: params.currency,
    discount: params.discount,
  );
});

// ==================== PURCHASE COMPLETION NOTIFIER ====================
class PurchaseCompletionNotifier
    extends AsyncNotifier<PaymentProcessingResult?> {
  @override
  Future<PaymentProcessingResult?> build() async {
    return null;
  }

  Future<PaymentProcessingResult?> completePurchase({
    required String studentId,
    required String courseId,
    required String teacherId,
    required PaidCourseConfig paidConfig,
    required String courseTitle,
    required String paymentMethod,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      // PayFast IPN finalizes enrollment + course_purchases server-side.
      // Demo Gateway confirm uses the same finalize pipeline.
      final paymentResult =
          await ref.read(coursePurchaseServiceProvider).processPurchase(
        studentId: studentId,
        courseId: courseId,
        teacherId: teacherId,
        courseTitle: courseTitle,
        amount: paidConfig.discountedPrice,
        currency: paidConfig.currency,
        paymentMethod: paymentMethod,
      );

      if (!paymentResult.success) {
        throw Exception(paymentResult.message);
      }

      ref.invalidate(studentPurchaseHistoryProvider);
      ref.invalidate(teacherSalesHistoryProvider);
      ref.invalidate(purchaseValidationProvider);
      ref.invalidate(hasPurchasedProvider);
      ref.invalidate(courseEnrollmentProvider(courseId));

      return PaymentProcessingResult.success(
        'Purchase completed successfully',
        paymentResult.transactionReference,
      );
    });

    return state.maybeWhen(
      data: (result) => result,
      orElse: () => null,
    );
  }
}

final purchaseCompletionProvider =
    AsyncNotifierProvider<PurchaseCompletionNotifier, PaymentProcessingResult?>(
  PurchaseCompletionNotifier.new,
);

// ==================== PRICING SETUP NOTIFIER ====================
class PricingSetupNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setupPaidCourse({
    required String courseId,
    required double price,
    required String currency,
    required double discount,
    String? thumbnailUrl,
    String? teacherId,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await ref.read(coursePurchaseServiceProvider).setupPaidCourse(
        courseId: courseId,
        price: price,
        currency: currency,
        discount: discount,
        thumbnailUrl: thumbnailUrl,
        teacherId: teacherId,
      );

      ref.invalidate(paidCourseConfigProvider);
      ref.invalidate(allPaidCoursesProvider);
    });
  }

  Future<void> updatePricing({
    required String courseId,
    double? price,
    String? currency,
    double? discount,
    String? thumbnailUrl,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await ref.read(coursePurchaseServiceProvider).updatePricingConfiguration(
        courseId: courseId,
        price: price,
        currency: currency,
        discount: discount,
        thumbnailUrl: thumbnailUrl,
      );

      // Invalidate caches
      ref.invalidate(paidCourseConfigProvider);
      ref.invalidate(allPaidCoursesProvider);
    });
  }

  Future<void> disablePaidCourse(String courseId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await ref.read(coursePurchaseServiceProvider).disablePaidCourse(courseId);

      // Invalidate caches
      ref.invalidate(paidCourseConfigProvider);
      ref.invalidate(allPaidCoursesProvider);
    });
  }
}

final pricingSetupProvider =
    AsyncNotifierProvider<PricingSetupNotifier, void>(
  PricingSetupNotifier.new,
);

// ==================== COURSE STATISTICS ====================
final coursePurchaseCountProvider =
    FutureProvider.family<int, String>((ref, courseId) {
  return ref
      .watch(coursePurchaseServiceProvider)
      .getCoursePurchaseCount(courseId);
});

final teacherRevenueProvider =
    FutureProvider.family<double, String>((ref, teacherId) {
  return ref
      .watch(coursePurchaseServiceProvider)
      .getTeacherRevenue(teacherId);
});

// ==================== PURCHASE CHECK ====================
final hasPurchasedProvider =
    FutureProvider.family<bool, ({String studentId, String courseId})>(
        (ref, params) {
  return ref.watch(coursePurchaseRepositoryProvider).hasPurchased(
    params.studentId,
    params.courseId,
  );
});
