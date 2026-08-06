import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../courses/presentation/course_premium_widgets.dart';
import '../../courses/providers/course_provider.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';
import 'widgets/stripe_connect_card.dart';

/// Teacher payment hub: earnings, paid-course analytics, plan & billing tools.
class TeacherEarningsScreen extends ConsumerWidget {
  const TeacherEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherId = ref.watch(authStateProvider).value?.uid ?? '';
    final summaryAsync = ref.watch(teacherEarningsSummaryProvider(teacherId));
    final coursesAsync = ref.watch(teacherCoursesProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Earnings & Billing',
      subtitle: 'Course sales, plan status, and payment tools in one place.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(RouteNames.teacherDashboard);
      },
      scrollable: false,
      child: CoursePremiumBackground(
        child: teacherId.isEmpty
            ? const CoursePremiumMessage(
                icon: Icons.person_off_outlined,
                title: 'Sign in required',
                message: 'Please sign in to view earnings and billing.',
              )
            : summaryAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => CoursePremiumMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Unable to load billing hub',
                  message: e.toString(),
                ),
                data: (summary) {
                  final courseTitles = <String, String>{};
                  for (final course in coursesAsync.value ?? const []) {
                    courseTitles[course.id] = course.title;
                  }

                  return CoursePremiumListView(
                    children: [
                      _EarningsOverview(summary: summary),
                      const SizedBox(height: 16),
                      _PlanBillingCard(
                        summary: summary,
                        teacherId: teacherId,
                      ),
                      const SizedBox(height: 16),
                      const StripeConnectCard(
                        role: 'teacher',
                        accent: AppColors.teacherPrimary,
                      ),
                      const SizedBox(height: 16),
                      _QuickLinksCard(),
                      const SizedBox(height: 16),
                      _PaidCourseAnalytics(
                        summary: summary,
                        courseTitles: courseTitles,
                      ),
                      const SizedBox(height: 16),
                      _RecentSalesCard(
                        summary: summary,
                        courseTitles: courseTitles,
                      ),
                      const SizedBox(height: 16),
                      _BillingActivityCard(summary: summary),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _EarningsOverview extends StatelessWidget {
  const _EarningsOverview({required this.summary});

  final TeacherEarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Revenue from students who purchased your paid courses.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(
                label: 'Total earnings',
                value:
                    '${summary.currency} ${summary.totalCourseRevenue.toStringAsFixed(2)}',
                icon: Icons.payments_rounded,
                color: AppColors.success,
              ),
              _StatTile(
                label: 'This month',
                value:
                    '${summary.currency} ${summary.monthCourseRevenue.toStringAsFixed(2)}',
                icon: Icons.calendar_month_rounded,
                color: AppColors.primary,
              ),
              _StatTile(
                label: 'Total sales',
                value: '${summary.totalSalesCount}',
                icon: Icons.shopping_bag_outlined,
                color: AppColors.info,
              ),
              _StatTile(
                label: 'Sales this month',
                value: '${summary.monthSalesCount}',
                icon: Icons.trending_up_rounded,
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanBillingCard extends ConsumerWidget {
  const _PlanBillingCard({
    required this.summary,
    required this.teacherId,
  });

  final TeacherEarningsSummary summary;
  final String teacherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final access = summary.access;
    final sub = summary.subscription;
    final cancelScheduled = sub?.isCancelScheduled == true;

    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teaching plan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            access.planName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            access.isPremium
                ? (cancelScheduled
                    ? 'Cancellation scheduled — full benefits until '
                        '${_fmt(sub!.currentPeriodEnd)}. No further charges.'
                    : 'Active subscription. Cancel anytime — keep benefits until month end.')
                : 'Free plan. Upgrade to unlock paid courses, analytics, and higher limits.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label:
                      'Period ends ${_fmt(sub.currentPeriodEnd)}',
                ),
                _Chip(
                  label: sub.autoRenew && !cancelScheduled
                      ? 'Auto-renew on'
                      : 'Auto-renew off',
                ),
                if (cancelScheduled) const _Chip(label: 'Cancel anytime used'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Your spend — plans: ${summary.currency} ${summary.planSpend.toStringAsFixed(2)} · '
            'AI credits: ${summary.currency} ${summary.creditSpend.toStringAsFixed(2)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    context.pushNamed(RouteNames.teacherPlans),
                icon: Icon(
                  access.isPremium
                      ? Icons.swap_horiz_rounded
                      : Icons.workspace_premium_rounded,
                ),
                label: Text(
                  access.isPremium ? 'Change / Upgrade plan' : 'Upgrade plan',
                ),
              ),
              if (access.isPremium && !cancelScheduled)
                OutlinedButton.icon(
                  onPressed: () => _cancelPlan(context, ref),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel anytime'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  RouteNames.teacherPurchaseHistory,
                  queryParameters: {'userId': teacherId},
                ),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Purchase history'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancelPlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel anytime?'),
        content: const Text(
          'Your plan stays active until the end of this billing month. '
          'You keep every premium benefit until then. After that the plan '
          'ends and your card will not be charged again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Schedule cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(teacherSubscriptionServiceProvider)
        .cancelSubscription(teacherId);

    ref.invalidate(teacherEarningsSummaryProvider(teacherId));
    ref.invalidate(teacherSubscriptionAccessProvider(teacherId));
    ref.invalidate(teacherActiveSubscriptionProvider(teacherId));
    ref.invalidate(paymentTeacherPurchaseHistoryProvider(teacherId));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? AppColors.success : AppColors.error,
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment tools',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LinkChip(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Teacher wallet',
                onTap: () => context.pushNamed(RouteNames.teacherWallet),
              ),
              _LinkChip(
                icon: Icons.storefront_rounded,
                label: 'Paid courses',
                onTap: () =>
                    context.pushNamed(RouteNames.teacherPaidCourses),
              ),
              _LinkChip(
                icon: Icons.credit_card_rounded,
                label: 'Payment methods',
                onTap: () =>
                    context.pushNamed(RouteNames.teacherPaymentMethods),
              ),
              _LinkChip(
                icon: Icons.auto_awesome_rounded,
                label: 'AI credit packs',
                onTap: () => context.pushNamed(RouteNames.creditPacks),
              ),
              _LinkChip(
                icon: Icons.workspace_premium_outlined,
                label: 'Compare plans',
                onTap: () => context.pushNamed(RouteNames.teacherPlans),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaidCourseAnalytics extends StatelessWidget {
  const _PaidCourseAnalytics({
    required this.summary,
    required this.courseTitles,
  });

  final TeacherEarningsSummary summary;
  final Map<String, String> courseTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paid course analytics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Per-course sales performance from the student marketplace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (summary.courseRows.isEmpty)
            Text(
              'No paid course sales yet. Set pricing on Paid courses, then share your courses with students.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...summary.courseRows.map((row) {
              final title =
                  courseTitles[row.courseId] ?? 'Course ${row.courseId}';
              final share = summary.totalCourseRevenue <= 0
                  ? 0.0
                  : (row.revenue / summary.totalCourseRevenue).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${row.currency} ${row.revenue.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.salesCount} sale${row.salesCount == 1 ? '' : 's'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({
    required this.summary,
    required this.courseTitles,
  });

  final TeacherEarningsSummary summary;
  final Map<String, String> courseTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent course sales',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (summary.recentSales.isEmpty)
            Text(
              'Sales will appear here when students buy your paid courses.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...summary.recentSales.map((sale) {
              final title =
                  courseTitles[sale.courseId] ?? 'Course ${sale.courseId}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_fmt(sale.purchasedAt)} · ${sale.paymentMethod}',
                ),
                trailing: Text(
                  '${sale.currency} ${sale.finalAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _BillingActivityCard extends StatelessWidget {
  const _BillingActivityCard({required this.summary});

  final TeacherEarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your billing activity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Plans, credit packs, and cancel events from your account.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (summary.ownPayments.isEmpty)
            Text(
              'No billing activity yet.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...summary.ownPayments.map((payment) {
              final isCancel =
                  payment.type == PaymentType.subscriptionCancel;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isCancel
                      ? Icons.event_busy_rounded
                      : payment.type == PaymentType.creditPack
                          ? Icons.auto_awesome_rounded
                          : Icons.receipt_long_rounded,
                  color: isCancel ? AppColors.warning : AppColors.primary,
                ),
                title: Text(
                  payment.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_typeLabel(payment.type)} · ${_fmt(payment.createdAt)}',
                ),
                trailing: Text(
                  isCancel
                      ? 'No charge'
                      : '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
          if (summary.cancelEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${summary.cancelEvents.length} cancel event'
              '${summary.cancelEvents.length == 1 ? '' : 's'} on record '
              '(shown in purchase history with access-until details).',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case PaymentType.plan:
        return 'Plan';
      case PaymentType.creditPack:
        return 'Credit pack';
      case PaymentType.subscriptionCancel:
        return 'Plan cancel';
      case PaymentType.course:
        return 'Course';
      default:
        return type;
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

String _fmt(DateTime date) => '${date.day}/${date.month}/${date.year}';
