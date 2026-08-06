import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../services/notification_service.dart';
import '../models/payment_models.dart';

/// Inbox alerts after SkillForge **demo** checkout success/fail.
///
/// Call from Flutter after confirm — never throw to callers.
class DemoPaymentNotificationHelper {
  const DemoPaymentNotificationHelper(this._notifications);

  final NotificationService _notifications;

  /// Once-per-process-day gate for subscription-expiring inbox writes.
  static final Set<String> _expiringKeys = <String>{};

  Future<void> notifyCheckoutOutcome({
    required String payerId,
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
    final uid = payerId.trim();
    if (uid.isEmpty) return;

    final amountLabel =
        '${currency.trim().isEmpty ? 'PKR' : currency} ${amount.toStringAsFixed(2)}';
    final meta = <String, dynamic>{
      if (intentId != null && intentId.isNotEmpty) 'intentId': intentId,
      'paymentType': type,
      'amount': amount,
      'currency': currency,
      'planId': ?planId,
      'creditPackId': ?creditPackId,
      'teacherId': ?teacherId,
      'orderId': ?orderId,
      ...?metadata,
    };

    if (!success) {
      await _notifications.notifyOne(
        recipientId: uid,
        title: 'Payment failed',
        body: (errorMessage != null && errorMessage.trim().isNotEmpty)
            ? 'Demo payment of $amountLabel failed: ${errorMessage.trim()}'
            : 'Demo payment of $amountLabel failed. You can try again.',
        category: NotificationCategories.system,
        event: NotificationEvents.systemPaymentFailed,
        actorId: 'system',
        relatedPath: intentId != null && intentId.isNotEmpty
            ? 'paymentIntents/$intentId'
            : '',
        priority: 'high',
        meta: meta,
      );
      return;
    }

    switch (type) {
      case PaymentType.plan:
      case PaymentType.subscription:
        await _notifications.notifyOne(
          recipientId: uid,
          title: 'Plan payment successful',
          body:
              'Your ${(planId ?? 'plan')} demo payment of $amountLabel was successful.',
          category: NotificationCategories.system,
          event: NotificationEvents.systemPaymentSucceeded,
          actorId: 'system',
          relatedPath: intentId != null && intentId.isNotEmpty
              ? 'paymentIntents/$intentId'
              : 'subscriptions',
          routeName: RouteNames.teacherPlans,
          meta: meta,
        );
        final tid = (teacherId ?? '').trim();
        if (tid.isNotEmpty && tid != uid) {
          await _notifications.notifyOne(
            recipientId: tid,
            title: 'Plan activated',
            body:
                'A demo plan payment of $amountLabel was completed for your teaching account.',
            category: NotificationCategories.system,
            event: NotificationEvents.systemPaymentSucceeded,
            actorId: 'system',
            routeName: RouteNames.teacherPlans,
            meta: meta,
          );
        }
        return;

      case PaymentType.creditPack:
        await _notifications.notifyOne(
          recipientId: uid,
          title: 'Credits purchased',
          body: 'Your AI credit pack demo payment of $amountLabel succeeded.',
          category: NotificationCategories.system,
          event: NotificationEvents.systemPaymentSucceeded,
          actorId: 'system',
          relatedPath: intentId != null && intentId.isNotEmpty
              ? 'paymentIntents/$intentId'
              : '',
          routeName: RouteNames.teacherPlans,
          meta: meta,
        );
        return;

      case PaymentType.course:
        await _notifyCoursePurchase(
          studentId: uid,
          amountLabel: amountLabel,
          teacherId: teacherId,
          intentId: intentId,
          meta: meta,
        );
        return;

      case 'commerce_order':
        await _notifyCommerceFunded(
          payerId: uid,
          amountLabel: amountLabel,
          orderId: orderId,
          intentId: intentId,
          meta: meta,
        );
        return;

      case 'wallet_topup':
        await _notifications.notifyOne(
          recipientId: uid,
          title: 'Wallet topped up',
          body: 'Demo wallet top-up of $amountLabel was successful.',
          category: NotificationCategories.system,
          event: NotificationEvents.systemPaymentSucceeded,
          actorId: 'system',
          relatedPath: intentId != null && intentId.isNotEmpty
              ? 'paymentIntents/$intentId'
              : '',
          routeName: RouteNames.customerWallet,
          meta: meta,
        );
        return;

      default:
        await _notifications.notifyOne(
          recipientId: uid,
          title: 'Payment successful',
          body:
              'Demo payment of $amountLabel for ${description.trim().isEmpty ? 'your purchase' : description} succeeded.',
          category: NotificationCategories.system,
          event: NotificationEvents.systemPaymentSucceeded,
          actorId: 'system',
          relatedPath: intentId != null && intentId.isNotEmpty
              ? 'paymentIntents/$intentId'
              : '',
          meta: meta,
        );
    }
  }

  /// Free-course enroll: notify teacher (student already knows from UI).
  Future<void> notifyFreeEnrollment({
    required String studentId,
    required String teacherId,
    required String courseId,
    required String courseTitle,
    String? studentName,
  }) async {
    final tid = teacherId.trim();
    final sid = studentId.trim();
    if (tid.isEmpty || sid.isEmpty || tid == sid) return;

    final title = courseTitle.trim().isEmpty ? 'your course' : courseTitle.trim();
    await _notifications.notifyOne(
      recipientId: tid,
      title: 'New enrollment',
      body: '${(studentName ?? 'A student').trim().isEmpty ? 'A student' : studentName!.trim()} enrolled in "$title".',
      category: NotificationCategories.learning,
      event: NotificationEvents.learningStudentEnrolled,
      actorId: sid,
      actorRole: 'student',
      relatedPath: 'enrollments/${sid}_$courseId',
      routeName: RouteNames.teacherCourseDetail,
      routeParams: {'courseId': courseId},
      meta: {
        'courseId': courseId,
        'studentId': sid,
        'courseTitle': title,
        'source': 'free_enroll',
      },
    );
  }

  /// Idempotent inbox write when a renewal reminder is first shown (once per day
  /// per subscription in this app process).
  Future<void> maybeNotifySubscriptionExpiring({
    required String userId,
    required String subscriptionId,
    required String planName,
    required String message,
    required String suggestedAction,
  }) async {
    final uid = userId.trim();
    final subId = subscriptionId.trim();
    if (uid.isEmpty || subId.isEmpty) return;

    final day = DateTime.now().toIso8601String().substring(0, 10);
    final key = '$uid:$subId:$day';
    if (_expiringKeys.contains(key)) return;
    _expiringKeys.add(key);

    await _notifications.notifyOne(
      recipientId: uid,
      title: 'Subscription expiring',
      body: '$message $suggestedAction'.trim(),
      category: NotificationCategories.system,
      event: NotificationEvents.systemSubscriptionExpiring,
      actorId: 'system',
      relatedPath: 'subscriptions/$subId',
      routeName: RouteNames.teacherPlans,
      priority: 'high',
      meta: {
        'subscriptionId': subId,
        'planName': planName,
        'notifyDay': day,
      },
    );
  }

  Future<void> _notifyCoursePurchase({
    required String studentId,
    required String amountLabel,
    String? teacherId,
    String? intentId,
    required Map<String, dynamic> meta,
  }) async {
    final courseId = (meta['courseId'] ?? '').toString();
    final courseTitle = (meta['courseTitle'] ?? meta['title'] ?? 'Course')
        .toString();
    final related = courseId.isNotEmpty
        ? 'enrollments/${studentId}_$courseId'
        : (intentId != null && intentId.isNotEmpty
              ? 'paymentIntents/$intentId'
              : '');

    await _notifications.notifyOne(
      recipientId: studentId,
      title: 'Course purchase confirmed',
      body:
          'You purchased "$courseTitle" for $amountLabel (demo). Enrollment is active.',
      category: NotificationCategories.learning,
      event: NotificationEvents.systemPaymentSucceeded,
      actorId: 'system',
      relatedPath: related,
      routeName: RouteNames.studentCourseDetail,
      routeParams: courseId.isNotEmpty ? {'courseId': courseId} : null,
      meta: meta,
    );

    final tid = (teacherId ?? meta['teacherId'] ?? '').toString().trim();
    if (tid.isNotEmpty && tid != studentId) {
      await _notifications.notifyOne(
        recipientId: tid,
        title: 'New course sale',
        body: 'A student purchased "$courseTitle" for $amountLabel (demo).',
        category: NotificationCategories.learning,
        event: NotificationEvents.systemPaymentSucceeded,
        actorId: studentId,
        actorRole: 'student',
        relatedPath: courseId.isNotEmpty ? 'courses/$courseId' : related,
        routeName: RouteNames.teacherCourseDetail,
        routeParams: courseId.isNotEmpty ? {'courseId': courseId} : null,
        meta: meta,
      );
    }
  }

  Future<void> _notifyCommerceFunded({
    required String payerId,
    required String amountLabel,
    String? orderId,
    String? intentId,
    required Map<String, dynamic> meta,
  }) async {
    final oid = (orderId ?? '').trim();
    final freelancerId = (meta['freelancerId'] ?? '').toString().trim();
    final serviceTitle = (meta['serviceTitle'] ?? meta['description'] ?? 'service')
        .toString()
        .trim();
    final relatedPath = oid.isNotEmpty
        ? 'serviceOrders/$oid'
        : (intentId != null && intentId.isNotEmpty
              ? 'paymentIntents/$intentId'
              : '');
    final routeParams = oid.isNotEmpty ? {'orderId': oid} : null;
    final sharedMeta = {
      ...meta,
      'orderStatus': 'active',
      'escrowStatus': 'held',
      if (serviceTitle.isNotEmpty) 'serviceTitle': serviceTitle,
    };

    await _notifications.notifyOne(
      recipientId: payerId,
      title: 'Order funded',
      body: oid.isEmpty
          ? 'Demo escrow payment of $amountLabel succeeded.'
          : 'Demo escrow funded for "$serviceTitle" ($amountLabel).',
      category: NotificationCategories.commerce,
      event: NotificationEvents.commerceOrderStatus,
      actorId: 'system',
      relatedPath: relatedPath,
      routeName: oid.isNotEmpty ? RouteNames.serviceOrderDetail : null,
      routeParams: routeParams,
      meta: sharedMeta,
    );

    if (freelancerId.isNotEmpty && freelancerId != payerId) {
      await _notifications.notifyOne(
        recipientId: freelancerId,
        title: 'Escrow funded',
        body:
            'Client funded escrow for "$serviceTitle" ($amountLabel). You can start work.',
        category: NotificationCategories.commerce,
        event: NotificationEvents.commerceOrderStatus,
        actorId: payerId,
        actorRole: 'client',
        relatedPath: relatedPath,
        routeName: oid.isNotEmpty ? RouteNames.serviceOrderDetail : null,
        routeParams: routeParams,
        meta: sharedMeta,
      );
    }
  }
}
