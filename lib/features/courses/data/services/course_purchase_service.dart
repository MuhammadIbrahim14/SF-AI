import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../payment/models/payment_models.dart';
import '../../../payment/services/payment_service.dart';
import '../../../payment/services/teacher_subscription_service.dart';
import '../models/marketplace_models.dart';
import '../repositories/course_purchase_repository.dart';
import '../models/enrollment_model.dart';
import '../repositories/enrollment_repository.dart';

class CoursePurchaseService {
  const CoursePurchaseService(
    this._purchaseRepository,
    this._enrollmentRepository, {
    PaymentService? paymentService,
    TeacherSubscriptionService? teacherSubscriptionService,
  }) : _paymentService = paymentService,
       _teacherSubscriptionService = teacherSubscriptionService;

  final CoursePurchaseRepository _purchaseRepository;
  final EnrollmentRepository _enrollmentRepository;
  final PaymentService? _paymentService;
  final TeacherSubscriptionService? _teacherSubscriptionService;

  Future<PurchaseValidationResult> validatePurchase({
    required String studentId,
    required String courseId,
    required String teacherId,
  }) async {
    final config = await _purchaseRepository.getMarketplaceConfig();
    if (!config.paidCoursesEnabled) {
      return PurchaseValidationResult.error(
        'Paid courses are currently disabled',
        'marketplace_disabled',
      );
    }

    final paidConfig = await _purchaseRepository.getPaidCourseConfig(courseId);
    if (!paidConfig.isPaid) {
      return PurchaseValidationResult.error(
        'This course is not available for purchase',
        'course_not_paid',
      );
    }

    final alreadyPurchased = await _purchaseRepository.hasPurchased(
      studentId,
      courseId,
    );
    if (alreadyPurchased) {
      return PurchaseValidationResult.error(
        'You have already purchased this course',
        'already_purchased',
      );
    }

    try {
      final enrollment = await _enrollmentRepository
          .getEnrollmentByStudentAndCourse(
            studentId: studentId,
            courseId: courseId,
          );
      if (enrollment != null) {
        return PurchaseValidationResult.error(
          'You are already enrolled in this course',
          'already_enrolled',
        );
      }
    } catch (error) {
      AppLogger.warn(
        'Course enrollment validation could not be completed: $error',
      );
    }

    return PurchaseValidationResult.success('Purchase validation successful');
  }

  Future<PurchaseValidationResult> validatePricingSetup({
    required double price,
    required String currency,
    required double discount,
    String? teacherId,
  }) async {
    final config = await _purchaseRepository.getMarketplaceConfig();

    if (teacherId != null) {
      final subscriptionService = _teacherSubscriptionService;
      if (subscriptionService != null) {
        final access = await subscriptionService.getAccessForTeacher(teacherId);
        if (!access.allowPaidCourses) {
          return PurchaseValidationResult.error(
            'Paid courses require a Pro teaching plan. Upgrade to enable pricing.',
            'pro_plan_required',
          );
        }
      }
    }

    if (!config.isValidPrice(price)) {
      return PurchaseValidationResult.error(
        'Price must be between \$${config.minPrice} and \$${config.maxPrice}',
        'invalid_price_range',
      );
    }

    if (!config.supportedCurrencies.contains(currency)) {
      return PurchaseValidationResult.error(
        'Currency $currency is not supported',
        'unsupported_currency',
      );
    }

    if (discount < 0 || discount > 100) {
      return PurchaseValidationResult.error(
        'Discount must be between 0 and 100%',
        'invalid_discount',
      );
    }

    return PurchaseValidationResult.success('Pricing setup is valid');
  }

  /// Processes course payment via PayFast Pakistan.
  Future<PaymentProcessingResult> processPurchase({
    required String studentId,
    required String courseId,
    required String teacherId,
    required String courseTitle,
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    try {
      final paymentService = _paymentService;
      if (paymentService == null) {
        return PaymentProcessingResult.failure(
          'Payment service unavailable.',
          'payment_unavailable',
        );
      }

      final result = await paymentService.purchaseCourse(
        userId: studentId,
        courseId: courseId,
        teacherId: teacherId,
        courseTitle: courseTitle,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
      );

      if (PaymentStatus.isSuccess(result.status)) {
        return PaymentProcessingResult.success(
          result.message,
          result.transactionId.isNotEmpty
              ? result.transactionId
              : (result.intentId ?? ''),
        );
      }
      return PaymentProcessingResult.failure(
        result.message,
        'payment_declined',
      );
    } catch (e) {
      return PaymentProcessingResult.failure(
        'Payment processing failed: ${e.toString()}',
        'payment_error',
      );
    }
  }

  Future<CoursePurchase?> completePurchase({
    required String studentId,
    required String courseId,
    required String teacherId,
    required PaidCourseConfig paidConfig,
    required String? transactionReference,
  }) async {
    final marketplace = await _purchaseRepository.getMarketplaceConfig();
    final grossAmount = paidConfig.discountedPrice;
    final platformFee = _roundMoney(
      grossAmount * marketplace.platformCommissionPercent / 100,
    );
    final teacherNet = _roundMoney(
      (grossAmount - platformFee).clamp(0, grossAmount).toDouble(),
    );
    final enrollmentId = '${studentId}_$courseId';
    final now = DateTime.now();

    final enrollment = EnrollmentModel(
      enrollmentId: enrollmentId,
      courseId: courseId,
      studentId: studentId,
      teacherId: teacherId,
      enrolledAt: now,
      progressPercent: 0,
      completedLessons: 0,
      totalLessons: 0,
      status: EnrollmentStatus.active,
    );

    await _enrollmentRepository.createEnrollment(enrollment);

    const uuid = Uuid();
    final purchaseId = 'purchase_${uuid.v4()}';

    final purchase = CoursePurchase(
      purchaseId: purchaseId,
      courseId: courseId,
      studentId: studentId,
      teacherId: teacherId,
      price: paidConfig.price,
      discountAmount: paidConfig.discountAmount,
      platformFee: platformFee,
      finalAmount: teacherNet,
      currency: paidConfig.currency,
      purchasedAt: now,
      enrollmentId: enrollmentId,
      transactionReference: transactionReference,
    );

    await _purchaseRepository.recordPurchase(purchase);
    return purchase;
  }

  Future<List<CoursePurchase>> getStudentPurchaseHistory(
    String studentId,
  ) async {
    return _purchaseRepository.getStudentPurchaseHistory(studentId);
  }

  Future<List<CoursePurchase>> getTeacherSalesHistory(String teacherId) async {
    return _purchaseRepository.getTeacherSalesHistory(teacherId);
  }

  Future<double> getTeacherRevenue(String teacherId) async {
    return _purchaseRepository.getTeacherRevenue(teacherId);
  }

  Future<int> getCoursePurchaseCount(String courseId) async {
    return _purchaseRepository.getCoursePurchaseCount(courseId);
  }

  Future<void> setupPaidCourse({
    required String courseId,
    required double price,
    required String currency,
    required double discount,
    required String? thumbnailUrl,
    String? teacherId,
  }) async {
    final validation = await validatePricingSetup(
      price: price,
      currency: currency,
      discount: discount,
      teacherId: teacherId,
    );

    if (!validation.isValid) {
      throw Exception(validation.message);
    }

    final now = DateTime.now();
    final config = PaidCourseConfig(
      courseId: courseId,
      isPaid: true,
      price: price,
      currency: currency,
      discount: discount,
      discountType: 'percentage',
      thumbnailUrl: thumbnailUrl,
      createdAt: now,
      updatedAt: now,
    );

    await _purchaseRepository.createOrUpdatePaidCourseConfig(config);
  }

  Future<void> updatePricingConfiguration({
    required String courseId,
    double? price,
    String? currency,
    double? discount,
    String? thumbnailUrl,
    String? teacherId,
  }) async {
    final existing = await _purchaseRepository.getPaidCourseConfig(courseId);

    if (price != null) {
      final validation = await validatePricingSetup(
        price: price,
        currency: currency ?? existing.currency,
        discount: discount ?? existing.discount,
        teacherId: teacherId,
      );
      if (!validation.isValid) {
        throw Exception(validation.message);
      }
    }

    final updated = existing.copyWith(
      price: price,
      currency: currency,
      discount: discount,
      thumbnailUrl: thumbnailUrl,
      updatedAt: DateTime.now(),
    );

    await _purchaseRepository.createOrUpdatePaidCourseConfig(updated);
  }

  Future<void> disablePaidCourse(String courseId) async {
    await _purchaseRepository.deletePaidCourseConfig(courseId);
  }

  Future<PaidCourseConfig> getPaidCourseConfig(String courseId) async {
    return _purchaseRepository.getPaidCourseConfig(courseId);
  }
}

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;
