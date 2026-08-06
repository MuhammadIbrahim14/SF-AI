import 'package:flutter/material.dart';

import '../services/subscription_renewal_service.dart';

/// Widget to display subscription renewal reminders
class SubscriptionRenewalReminder extends StatelessWidget {
  final SubscriptionRenewalNotification notification;
  final VoidCallback onRenewPressed;
  final VoidCallback? onDismissed;

  const SubscriptionRenewalReminder({
    required this.notification,
    required this.onRenewPressed,
    this.onDismissed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!notification.isHighPriority) {
      return const SizedBox.shrink();
    }

    final bgColor = _getBackgroundColor();
    final borderColor = _getBorderColor();
    final iconColor = _getIconColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIcon(),
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.cancelScheduled
                            ? 'Cancellation scheduled'
                            : 'Subscription Renewal',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.planName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismissed != null)
                  InkWell(
                    onTap: onDismissed,
                    child: Icon(
                      Icons.close,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notification.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification.suggestedAction,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            if (!notification.cancelScheduled)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRenewPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Renew Subscription'),
                    ),
                  ),
                ],
              ),
            if (notification.cancelScheduled)
              Text(
                'You can keep using premium features until the date above.',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (notification.status) {
      case SubscriptionStatus.active:
        return Colors.blue[50]!;
      case SubscriptionStatus.expiringSoon:
        return Colors.amber[50]!;
      case SubscriptionStatus.expiringToday:
        return Colors.orange[50]!;
      case SubscriptionStatus.expired:
        return Colors.red[50]!;
    }
  }

  Color _getBorderColor() {
    switch (notification.status) {
      case SubscriptionStatus.active:
        return Colors.blue[200]!;
      case SubscriptionStatus.expiringSoon:
        return Colors.amber[300]!;
      case SubscriptionStatus.expiringToday:
        return Colors.orange[400]!;
      case SubscriptionStatus.expired:
        return Colors.red[400]!;
    }
  }

  Color _getIconColor() {
    switch (notification.status) {
      case SubscriptionStatus.active:
        return Colors.blue;
      case SubscriptionStatus.expiringSoon:
        return Colors.amber[700]!;
      case SubscriptionStatus.expiringToday:
        return Colors.orange[700]!;
      case SubscriptionStatus.expired:
        return Colors.red[700]!;
    }
  }

  IconData _getIcon() {
    switch (notification.status) {
      case SubscriptionStatus.active:
        return Icons.check_circle_outline;
      case SubscriptionStatus.expiringSoon:
        return Icons.warning_amber;
      case SubscriptionStatus.expiringToday:
        return Icons.priority_high;
      case SubscriptionStatus.expired:
        return Icons.error_outline;
    }
  }
}

/// Compact version for display in cards or limited space
class CompactSubscriptionRenewalReminder extends StatelessWidget {
  final SubscriptionRenewalNotification notification;
  final VoidCallback onTap;

  const CompactSubscriptionRenewalReminder({
    required this.notification,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!notification.isHighPriority) {
      return const SizedBox.shrink();
    }

    final iconColor = _getIconColor();
    final bgColor = iconColor.withAlpha(26);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: iconColor.withAlpha(77)),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), color: iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: iconColor),
          ],
        ),
      ),
    );
  }

  Color _getIconColor() {
    switch (notification.status) {
      case SubscriptionStatus.active:
        return Colors.blue;
      case SubscriptionStatus.expiringSoon:
        return Colors.amber[700]!;
      case SubscriptionStatus.expiringToday:
        return Colors.orange[700]!;
      case SubscriptionStatus.expired:
        return Colors.red[700]!;
    }
  }

  IconData _getIcon() {
    switch (notification.status) {
      case SubscriptionStatus.active:
        return Icons.check_circle;
      case SubscriptionStatus.expiringSoon:
        return Icons.warning_amber;
      case SubscriptionStatus.expiringToday:
        return Icons.priority_high;
      case SubscriptionStatus.expired:
        return Icons.error;
    }
  }
}
