import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';
import '../services/invoice_service.dart';

class TeacherPurchaseHistoryScreen extends ConsumerWidget {
  const TeacherPurchaseHistoryScreen({this.teacherId, super.key});

  final String? teacherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authUid = ref.watch(authStateProvider).value?.uid ?? '';
    final resolvedId =
        (teacherId != null && teacherId!.trim().isNotEmpty)
            ? teacherId!.trim()
            : authUid;

    if (resolvedId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Purchase History')),
        body: const Center(
          child: DashboardEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Sign in required',
            message: 'Please sign in to view your purchase history.',
          ),
        ),
      );
    }

    final paymentsAsync = ref.watch(
      paymentTeacherPurchaseHistoryProvider(resolvedId),
    );
    final subscriptionAsync = ref.watch(
      teacherActiveSubscriptionProvider(resolvedId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
        elevation: 0,
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? Colors.transparent,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(paymentTeacherPurchaseHistoryProvider(resolvedId));
              ref.invalidate(teacherActiveSubscriptionProvider(resolvedId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, st) => Center(
          child: DashboardEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load purchase history',
            message: error.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(
              paymentTeacherPurchaseHistoryProvider(resolvedId),
            ),
          ),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return Center(
              child: DashboardEmptyState(
                icon: Icons.receipt_outlined,
                title: 'No purchases yet',
                message:
                    'You haven\'t made any purchases. Upgrade your teaching plan to unlock premium features.',
                actionLabel: 'Explore Plans',
                onAction: () => Navigator.of(context).pop(),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              subscriptionAsync.when(
                data: (sub) {
                  if (sub == null || !sub.isCancelScheduled) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CancelScheduleBanner(subscription: sub),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              ...List.generate(payments.length, (idx) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: idx == payments.length - 1 ? 0 : 8,
                  ),
                  child: _PurchaseHistoryCard(payment: payments[idx]),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _CancelScheduleBanner extends StatelessWidget {
  const _CancelScheduleBanner({required this.subscription});

  final PaymentSubscriptionModel subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = subscription.currentPeriodEnd;
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.event_busy_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan cancellation scheduled',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You keep all benefits until ${_formatDate(end)}. '
                    'After that the plan ends and your card will not be charged again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (subscription.cancelledAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Requested on ${_formatDate(subscription.cancelledAt!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseHistoryCard extends StatelessWidget {
  const _PurchaseHistoryCard({required this.payment});

  final PaymentRecordModel payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCancel = payment.type == PaymentType.subscriptionCancel;
    final isSuccess = PaymentStatus.isSuccess(payment.status);
    final isPending = PaymentStatus.isPending(payment.status);
    final isCancelled = PaymentStatus.isCancelled(payment.status) || isCancel;

    final statusLabel = isCancel
        ? 'CANCELLED'
        : payment.status.toUpperCase();
    final statusColor = isCancel || isCancelled
        ? AppColors.warning
        : isSuccess
            ? AppColors.success
            : isPending
                ? AppColors.warning
                : AppColors.error;

    final accessUntil = payment.metadata['accessUntil']?.toString();
    final planName = payment.metadata['planName']?.toString();
    final cancelledAt = payment.metadata['cancelledAt']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payment.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (isCancel) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cancel anytime details',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (planName != null && planName.isNotEmpty)
                      _DetailLine(label: 'Plan', value: planName),
                    if (accessUntil != null && accessUntil.isNotEmpty)
                      _DetailLine(
                        label: 'Access until',
                        value: _formatIsoOrRaw(accessUntil),
                      ),
                    if (cancelledAt != null && cancelledAt.isNotEmpty)
                      _DetailLine(
                        label: 'Cancel requested',
                        value: _formatIsoOrRaw(cancelledAt),
                      ),
                    const _DetailLine(
                      label: 'Billing',
                      value: 'Auto-renew stopped — no further card charges',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCancel
                          ? 'No charge'
                          : '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _typeLabel(payment.type),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gateway',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCancel ? 'N/A' : payment.gateway,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCancel ? 'Event ID' : 'Transaction ID',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.transactionId.isEmpty
                            ? payment.paymentId.substring(
                                0,
                                min(payment.paymentId.length, 12),
                              )
                            : payment.transactionId.substring(
                                0,
                                min(payment.transactionId.length, 12),
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(payment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (payment.cardLast4.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Card ending in ${payment.cardLast4}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (PaymentStatus.isSuccess(payment.status) && !isCancel) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadInvoice(context, payment),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Invoice'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case PaymentType.plan:
        return 'Plan';
      case PaymentType.course:
        return 'Course';
      case PaymentType.subscriptionCancel:
        return 'Plan cancel';
      case PaymentType.creditPack:
        return 'Credit Pack';
      default:
        return type;
    }
  }

  Future<void> _downloadInvoice(
    BuildContext context,
    PaymentRecordModel payment,
  ) async {
    try {
      final invoiceService = InvoiceService();
      await invoiceService.generateAndDisplayInvoice(
        payment: payment,
        businessName: 'SkillForge AI',
        businessEmail: 'billing@skillforgeai.com',
        companyRegistration: 'PKR123456789',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String _formatIsoOrRaw(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return _formatDate(parsed);
}
