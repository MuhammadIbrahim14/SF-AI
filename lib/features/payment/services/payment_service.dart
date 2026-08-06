import '../../../services/notification_service.dart';
import '../data/payment_repository.dart';
import '../models/payment_models.dart';
import 'demo_payment_notification_helper.dart';
import 'payfast_checkout_service.dart';

/// LMS / billing payments via SkillForge Demo Gateway (no real money).
class PaymentService {
  PaymentService(
    this._repo, {
    PayFastCheckoutService? checkoutService,
    NotificationService? notifications,
  }) : _checkoutOverride = checkoutService,
       _notifications = notifications;

  final PaymentRepository _repo;
  final PayFastCheckoutService? _checkoutOverride;
  final NotificationService? _notifications;

  PayFastCheckoutService get _checkout =>
      _checkoutOverride ?? PayFastCheckoutService();

  PayFastCheckoutService get checkoutService => _checkout;

  Future<void> initializeSeedData() async {
    await _repo.seedDefaultConfiguration();
  }

  /// Starts SkillForge Demo Gateway checkout and waits for finalize confirmation.
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
    String? orderId,
    Map<String, dynamic>? metadata,
    bool openBrowser = true,
  }) async {
    try {
      final intent = await _checkout.checkoutAndWait(
        type: type,
        amount: amount,
        description: description,
        paymentMethod: paymentMethod,
        currency: currency,
        role: role,
        planId: planId,
        creditPackId: creditPackId,
        teacherId: teacherId,
        orderId: orderId,
        metadata: {
          ...?metadata,
          'isDemo': true,
          'environment': 'demo',
          'gateway': 'skillforge_demo',
        },
        openBrowser: openBrowser,
      );

      if (intent.isFailed) {
        final failed = PaymentProcessResult(
          transactionId: intent.transactionId ?? '',
          paymentId: intent.paymentId ?? '',
          status: PaymentStatus.failed,
          message: intent.errorMessage ?? 'Demo payment failed.',
          amount: amount,
          currency: currency,
          intentId: intent.intentId,
        );
        await _notifyOutcome(
          userId: userId,
          type: type,
          success: false,
          amount: amount,
          currency: currency,
          description: description,
          intentId: intent.intentId,
          planId: planId,
          creditPackId: creditPackId,
          teacherId: teacherId,
          orderId: orderId,
          errorMessage: failed.message,
          metadata: metadata,
        );
        return failed;
      }

      final ok = PaymentProcessResult(
        transactionId: intent.transactionId ?? '',
        paymentId: intent.paymentId ?? '',
        status: PaymentStatus.success,
        message:
            'DEMO payment confirmed via SkillForge Demo Gateway. No real money moved.',
        amount: intent.amount,
        currency: intent.currency,
        intentId: intent.intentId,
        platformFee: intent.platformFee,
        sellerNet: intent.sellerNet,
      );
      await _notifyOutcome(
        userId: userId,
        type: type,
        success: true,
        amount: intent.amount,
        currency: intent.currency,
        description: description,
        intentId: intent.intentId,
        planId: planId,
        creditPackId: creditPackId,
        teacherId: teacherId,
        orderId: orderId,
        metadata: metadata,
      );
      return ok;
    } on PayFastCheckoutException catch (e) {
      final failed = PaymentProcessResult(
        transactionId: '',
        paymentId: '',
        status: PaymentStatus.failed,
        message: e.message,
        amount: amount,
        currency: currency,
      );
      await _notifyOutcome(
        userId: userId,
        type: type,
        success: false,
        amount: amount,
        currency: currency,
        description: description,
        planId: planId,
        creditPackId: creditPackId,
        teacherId: teacherId,
        orderId: orderId,
        errorMessage: e.message,
        metadata: metadata,
      );
      return failed;
    }
  }

  Future<void> _notifyOutcome({
    required String userId,
    required String type,
    required bool success,
    required double amount,
    required String currency,
    required String description,
    String? intentId,
    String? planId,
    String? creditPackId,
    String? teacherId,
    String? orderId,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    final notifications = _notifications;
    if (notifications == null) return;
    try {
      await DemoPaymentNotificationHelper(notifications).notifyCheckoutOutcome(
        payerId: userId,
        type: type,
        success: success,
        amount: amount,
        currency: currency,
        description: description,
        intentId: intentId,
        planId: planId,
        creditPackId: creditPackId,
        teacherId: teacherId,
        orderId: orderId,
        errorMessage: errorMessage,
        metadata: metadata,
      );
    } catch (_) {
      // Never fail payment because of inbox write.
    }
  }

  Future<PaymentProcessResult> purchasePlan({
    required String userId,
    required String planId,
    required double amount,
    required String currency,
    required String paymentMethod,
    String? teacherId,
    Map<String, dynamic>? metadata,
  }) async {
    final plan = await _repo.getPlan(planId);
    final effectiveAmount = plan?.price ?? amount;
    return processPayment(
      userId: userId,
      type: PaymentType.plan,
      description: plan?.name ?? 'Plan purchase',
      amount: effectiveAmount,
      currency: currency,
      paymentMethod: paymentMethod,
      planId: planId,
      teacherId: teacherId,
      role: 'teacher',
      metadata: metadata,
    );
  }

  Future<PaymentProcessResult> purchaseCreditPack({
    required String userId,
    required String creditPackId,
    required String currency,
    required String paymentMethod,
    String? teacherId,
    Map<String, dynamic>? metadata,
  }) async {
    final packs = await _repo.getCreditPacks();
    final pack = packs.where((item) => item.packId == creditPackId).firstOrNull;
    return processPayment(
      userId: userId,
      type: PaymentType.creditPack,
      description: pack?.name ?? 'Credit pack purchase',
      amount: pack?.price ?? 0,
      currency: currency,
      paymentMethod: paymentMethod,
      creditPackId: creditPackId,
      teacherId: teacherId,
      role: 'teacher',
      metadata: metadata,
    );
  }

  Future<PaymentProcessResult> purchaseCourse({
    required String userId,
    required String courseId,
    required String teacherId,
    required String courseTitle,
    required double amount,
    required String currency,
    required String paymentMethod,
    Map<String, dynamic>? metadata,
  }) async {
    return processPayment(
      userId: userId,
      type: PaymentType.course,
      description: 'Course: $courseTitle',
      amount: amount,
      currency: currency,
      paymentMethod: paymentMethod,
      teacherId: teacherId,
      role: 'student',
      metadata: {
        'courseId': courseId,
        'courseTitle': courseTitle,
        ...?metadata,
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
