import 'package:intl/intl.dart';

import '../models/payment_models.dart';

/// Handles subscription renewal reminders and notifications.
class SubscriptionRenewalService {
  static const int defaultReminderDays = 3;

  /// Returns true if subscription should trigger a renewal reminder.
  static bool shouldNotifyRenewal(
    DateTime subscriptionEndDate, {
    int daysBeforeExpiry = defaultReminderDays,
  }) {
    final now = DateTime.now();
    final daysUntilExpiry = subscriptionEndDate.difference(now).inDays;
    return daysUntilExpiry <= daysBeforeExpiry && daysUntilExpiry >= 0;
  }

  static int getDaysUntilExpiry(DateTime subscriptionEndDate) {
    return subscriptionEndDate.difference(DateTime.now()).inDays;
  }

  static String formatRenewalReminder(DateTime subscriptionEndDate) {
    final daysRemaining = getDaysUntilExpiry(subscriptionEndDate);
    final dateFormat = DateFormat('MMM dd, yyyy');

    if (daysRemaining == 0) {
      return 'Your subscription expires today!';
    } else if (daysRemaining == 1) {
      return 'Your subscription expires tomorrow.';
    } else {
      return 'Your subscription expires in $daysRemaining days (${dateFormat.format(subscriptionEndDate)}).';
    }
  }

  static SubscriptionStatus checkSubscriptionStatus(DateTime subscriptionEndDate) {
    final daysRemaining = subscriptionEndDate.difference(DateTime.now()).inDays;

    if (daysRemaining < 0) {
      return SubscriptionStatus.expired;
    } else if (daysRemaining == 0) {
      return SubscriptionStatus.expiringToday;
    } else if (daysRemaining <= 3) {
      return SubscriptionStatus.expiringSoon;
    } else {
      return SubscriptionStatus.active;
    }
  }

  static String getSuggestedAction(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.expired:
        return 'Your subscription has expired. Renew now to continue accessing premium features.';
      case SubscriptionStatus.expiringToday:
        return 'Your subscription expires today. Please renew to maintain uninterrupted access.';
      case SubscriptionStatus.expiringSoon:
        return 'Your subscription is expiring soon. Renew now to avoid service interruption.';
      case SubscriptionStatus.active:
        return 'Your subscription is active. You have full access to premium features.';
    }
  }

  /// Batch-check subscriptions. Pass [planNamesById] to resolve friendly plan names.
  static List<SubscriptionRenewalNotification> checkMultipleSubscriptions(
    List<PaymentSubscriptionModel> subscriptions, {
    int daysBeforeExpiry = defaultReminderDays,
    Map<String, String> planNamesById = const {},
  }) {
    return subscriptions
        .where((sub) => !PaymentStatus.isCancelled(sub.status))
        .where((sub) => shouldNotifyRenewal(
              sub.currentPeriodEnd,
              daysBeforeExpiry: daysBeforeExpiry,
            ))
        .map((sub) {
          final status = checkSubscriptionStatus(sub.currentPeriodEnd);
          return SubscriptionRenewalNotification(
            subscriptionId: sub.subscriptionId,
            planName: planNamesById[sub.planId] ?? sub.planId,
            renewalDate: sub.currentPeriodEnd,
            status: status,
            message: formatRenewalReminder(sub.currentPeriodEnd),
            suggestedAction: getSuggestedAction(status),
          );
        })
        .toList();
  }

  static SubscriptionRenewalNotification? forSubscription(
    PaymentSubscriptionModel subscription, {
    String? planName,
    int daysBeforeExpiry = defaultReminderDays,
  }) {
    if (PaymentStatus.isCancelled(subscription.status)) return null;

    final resolvedName = planName ?? subscription.planId;
    final dateFormat = DateFormat('MMM dd, yyyy');

    if (subscription.isCancelScheduled) {
      final days = getDaysUntilExpiry(subscription.currentPeriodEnd);
      return SubscriptionRenewalNotification(
        subscriptionId: subscription.subscriptionId,
        planName: resolvedName,
        renewalDate: subscription.currentPeriodEnd,
        status: days < 0
            ? SubscriptionStatus.expired
            : days == 0
                ? SubscriptionStatus.expiringToday
                : SubscriptionStatus.expiringSoon,
        message:
            'Cancellation scheduled. Full $resolvedName access until '
            '${dateFormat.format(subscription.currentPeriodEnd)}.',
        suggestedAction:
            'No further card charges. Plan ends automatically at period end.',
        cancelScheduled: true,
      );
    }

    if (!shouldNotifyRenewal(
      subscription.currentPeriodEnd,
      daysBeforeExpiry: daysBeforeExpiry,
    )) {
      return null;
    }
    final status = checkSubscriptionStatus(subscription.currentPeriodEnd);
    return SubscriptionRenewalNotification(
      subscriptionId: subscription.subscriptionId,
      planName: resolvedName,
      renewalDate: subscription.currentPeriodEnd,
      status: status,
      message: formatRenewalReminder(subscription.currentPeriodEnd),
      suggestedAction: getSuggestedAction(status),
    );
  }
}

enum SubscriptionStatus {
  active,
  expiringSoon,
  expiringToday,
  expired,
}

class SubscriptionRenewalNotification {
  SubscriptionRenewalNotification({
    required this.subscriptionId,
    required this.planName,
    required this.renewalDate,
    required this.status,
    required this.message,
    required this.suggestedAction,
    this.cancelScheduled = false,
  });

  final String subscriptionId;
  final String planName;
  final DateTime renewalDate;
  final SubscriptionStatus status;
  final String message;
  final String suggestedAction;
  final bool cancelScheduled;

  bool get isHighPriority => status != SubscriptionStatus.active;

  String get urgencyLevel {
    if (cancelScheduled) return 'warning';
    switch (status) {
      case SubscriptionStatus.active:
        return 'info';
      case SubscriptionStatus.expiringSoon:
        return 'warning';
      case SubscriptionStatus.expiringToday:
        return 'critical';
      case SubscriptionStatus.expired:
        return 'error';
    }
  }
}
