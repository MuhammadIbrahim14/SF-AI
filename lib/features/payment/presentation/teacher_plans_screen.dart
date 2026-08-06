import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../ai_usage/providers/ai_usage_provider.dart';
import '../../courses/presentation/course_premium_widgets.dart';
import '../config/payfast_config.dart';
import '../models/payment_models.dart';
import '../presentation/checkout/payfast_checkout_sheet.dart';
import '../presentation/subscription_renewal_reminder_widget.dart';
import '../providers/payment_providers.dart';
import '../services/subscription_renewal_service.dart';
import '../services/teacher_subscription_service.dart';

/// Plan Management hub — current plan, compare, billing shortcuts, Demo Gateway checkout.
class TeacherPlansScreen extends ConsumerStatefulWidget {
  const TeacherPlansScreen({super.key});

  @override
  ConsumerState<TeacherPlansScreen> createState() => _TeacherPlansScreenState();
}

class _TeacherPlansScreenState extends ConsumerState<TeacherPlansScreen> {
  PaymentPlanModel? _selected;
  bool _checkingOut = false;
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(paymentPlansProvider);
    final teacherId = ref.watch(authStateProvider).value?.uid ?? '';
    final accessAsync = teacherId.isEmpty
        ? null
        : ref.watch(teacherSubscriptionAccessProvider(teacherId));
    final subAsync = teacherId.isEmpty
        ? null
        : ref.watch(teacherActiveSubscriptionProvider(teacherId));
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Plan Management',
      subtitle: 'Manage your teaching plan, compare tiers, and handle billing.',
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
        child: plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CoursePremiumMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load plans',
            message: e.toString(),
          ),
          data: (plans) {
            final access =
                accessAsync?.value ?? TeacherSubscriptionAccess.free();
            final subscription = subAsync?.value;
            final cancelScheduled = subscription?.isCancelScheduled == true;

            final paidPlans = plans
                .where((p) => p.planId != 'free_plan' && p.price > 0)
                .toList()
              ..sort((a, b) => a.price.compareTo(b.price));
            final freePlan =
                plans.where((p) => p.planId == 'free_plan').firstOrNull;

            final currentPaid = paidPlans
                .where((p) => p.planId == access.planId)
                .firstOrNull;
            final currentPrice = currentPaid?.price ?? 0;

            return CoursePremiumListView(
              children: [
                _DemoNotice(theme: theme),
                const SizedBox(height: 16),
                _CurrentPlanPanel(
                  access: access,
                  subscription: subscription,
                  cancelScheduled: cancelScheduled,
                  cancelling: _cancelling,
                  onUpgrade: () {
                    // Scroll focus: select first upgradeable paid plan if any.
                    final upgrade = paidPlans
                        .where((p) => p.price > currentPrice)
                        .firstOrNull;
                    if (upgrade != null) {
                      setState(() => _selected = upgrade);
                    }
                  },
                  onCancel: access.isPremium && !cancelScheduled
                      ? () => _cancelSubscription(teacherId)
                      : null,
                ),
                if (access.isPremium && subscription != null) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final notification =
                          SubscriptionRenewalService.forSubscription(
                        subscription,
                        planName: access.planName,
                      );
                      if (notification == null) {
                        return const SizedBox.shrink();
                      }
                      // Once-per-day inbox write (in-process gate) when reminder shows.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final uid = teacherId;
                        if (uid.isEmpty) return;
                        ref
                            .read(demoPaymentNotificationHelperProvider)
                            .maybeNotifySubscriptionExpiring(
                              userId: uid,
                              subscriptionId: notification.subscriptionId,
                              planName: notification.planName,
                              message: notification.message,
                              suggestedAction: notification.suggestedAction,
                            );
                      });
                      return SubscriptionRenewalReminder(
                        notification: notification,
                        onRenewPressed: () {
                          final reactivate = paidPlans
                              .where((p) => p.planId == access.planId)
                              .firstOrNull;
                          if (reactivate != null) {
                            setState(() => _selected = reactivate);
                          }
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Compare plans',
                  subtitle:
                      'Select a plan, then continue to secure demo checkout.',
                ),
                const SizedBox(height: 12),
                if (freePlan != null) ...[
                  _PlanCompareCard(
                    plan: freePlan,
                    isSelected: false,
                    badge: access.planId == freePlan.planId
                        ? 'Current plan'
                        : 'Free',
                    isCurrent: access.planId == freePlan.planId,
                    onSelect: null,
                  ),
                  const SizedBox(height: 12),
                ],
                ...paidPlans.map((plan) {
                  final isCurrent = plan.planId == access.planId &&
                      access.isPremium &&
                      !cancelScheduled;
                  final isReactivate =
                      plan.planId == access.planId && cancelScheduled;
                  final isUpgrade = plan.price > currentPrice;
                  final canSelect = !isCurrent;
                  final String badge;
                  if (isCurrent) {
                    badge = 'Current plan';
                  } else if (isReactivate) {
                    badge = 'Reactivate';
                  } else if (isUpgrade) {
                    badge = 'Upgrade';
                  } else {
                    badge = 'Switch';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCompareCard(
                      plan: plan,
                      isSelected: _selected?.planId == plan.planId,
                      badge: badge,
                      isCurrent: isCurrent,
                      onSelect: canSelect
                          ? () => setState(() => _selected = plan)
                          : null,
                    ),
                  );
                }),
                if (paidPlans.isEmpty)
                  const CoursePremiumMessage(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No paid plans yet',
                    message:
                        'Ask an admin to create plans in Monetization Center.',
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _checkingOut
                        ? null
                        : () => _startCheckout(
                              context,
                              _selected!,
                              access: access,
                              subscription: subscription,
                            ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _checkingOut
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _selected!.price > currentPrice
                                ? Icons.rocket_launch_rounded
                                : Icons.swap_horiz_rounded,
                          ),
                    label: Text(
                      _checkingOut
                          ? 'Opening checkout...'
                          : _checkoutLabel(
                              _selected!,
                              access: access,
                              cancelScheduled: cancelScheduled,
                              currentPrice: currentPrice,
                            ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _SectionHeader(
                  title: 'Billing & account',
                  subtitle: 'History, methods, credits, and earnings.',
                ),
                const SizedBox(height: 12),
                _BillingShortcuts(teacherId: teacherId),
                const SizedBox(height: 48),
              ],
            );
          },
        ),
      ),
    );
  }

  String _checkoutLabel(
    PaymentPlanModel plan, {
    required TeacherSubscriptionAccess access,
    required bool cancelScheduled,
    required double currentPrice,
  }) {
    final price = '${plan.currency} ${plan.price.toStringAsFixed(2)}';
    if (plan.planId == access.planId && cancelScheduled) {
      return 'Reactivate ${plan.name} · $price';
    }
    if (plan.price > currentPrice) {
      return 'Upgrade to ${plan.name} · $price';
    }
    return 'Switch to ${plan.name} · $price';
  }

  Future<void> _cancelSubscription(String teacherId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Your Premium Plan?'),
        content: const Text(
          'You can cancel anytime. Your plan stays fully active until the end of '
          'the current billing month, then it ends automatically with no further '
          'charges. You keep all premium benefits until that date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel at month end'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final cancellationResult = await ref
          .read(teacherSubscriptionServiceProvider)
          .cancelSubscription(teacherId);
      if (!mounted) return;
      ref.invalidate(teacherSubscriptionAccessProvider(teacherId));
      ref.invalidate(teacherActiveSubscriptionProvider(teacherId));
      ref.invalidate(paymentTeacherPurchaseHistoryProvider(teacherId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cancellationResult.message),
          backgroundColor: cancellationResult.success
              ? AppColors.success
              : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling subscription: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _startCheckout(
    BuildContext context,
    PaymentPlanModel plan, {
    required TeacherSubscriptionAccess access,
    required PaymentSubscriptionModel? subscription,
  }) async {
    final teacherId = ref.read(authStateProvider).value?.uid;
    if (teacherId == null) return;

    final service = ref.read(teacherSubscriptionServiceProvider);
    final evaluation = await service.evaluatePlanChange(
      teacherId: teacherId,
      target: plan,
    );
    if (!evaluation.canCheckout) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(evaluation.message)),
      );
      return;
    }

    setState(() => _checkingOut = true);
    final result = await showPayFastCheckoutSheet(
      context: context,
      ref: ref,
      type: PaymentType.plan,
      amount: plan.price,
      currency: plan.currency,
      description: evaluation.ctaLabel,
      role: 'teacher',
      planId: plan.planId,
      teacherId: teacherId,
      metadata: {
        'upgrade': evaluation.kind == PlanChangeKind.upgrade ||
            evaluation.kind == PlanChangeKind.reactivate,
        'changeType': evaluation.kind.name,
        'feature': 'teacher_subscription',
        'previousPlanId': evaluation.currentPlanId,
        if (evaluation.subscription != null)
          'previousSubscriptionId': evaluation.subscription!.subscriptionId,
      },
      title: evaluation.ctaLabel,
    );
    if (!mounted) return;
    setState(() => _checkingOut = false);

    if (result != null && PaymentStatus.isSuccess(result.status)) {
      ref.invalidate(teacherSubscriptionAccessProvider(teacherId));
      ref.invalidate(paymentTeacherPurchaseHistoryProvider(teacherId));
      ref.invalidate(currentAiUserCreditsProvider);
      ref.invalidate(teacherActiveSubscriptionProvider(teacherId));
      ref.invalidate(teacherEarningsSummaryProvider(teacherId));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            evaluation.kind == PlanChangeKind.reactivate
                ? 'Plan reactivated'
                : evaluation.kind == PlanChangeKind.switchPlan
                    ? 'Plan switched'
                    : 'Plan upgraded',
          ),
          content: Text(
            '${plan.name} is now active. Limits, paid courses, analytics, '
            'and ${plan.maxAiCreditsPerMonth} AI credits/month are unlocked. '
            'Any scheduled cancellation has been cleared.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      setState(() => _selected = null);
    } else if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D9A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFF8A6D1D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              PayFastConfig.demoBanner,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF8A6D1D),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CurrentPlanPanel extends StatelessWidget {
  const _CurrentPlanPanel({
    required this.access,
    required this.subscription,
    required this.cancelScheduled,
    required this.cancelling,
    required this.onUpgrade,
    required this.onCancel,
  });

  final TeacherSubscriptionAccess access;
  final PaymentSubscriptionModel? subscription;
  final bool cancelScheduled;
  final bool cancelling;
  final VoidCallback onUpgrade;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = access.isPremium;
    final dateFmt = DateFormat('MMM d, yyyy');
    final periodEnd = subscription?.currentPeriodEnd;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT PLAN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            access.planName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isPremium
                                ? (cancelScheduled
                                    ? 'Cancellation scheduled — benefits continue until period end.'
                                    : 'Active teaching workspace with full plan entitlements.')
                                : 'Starter workspace with limited publishing capacity.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusBadge(
                      label: cancelScheduled
                          ? 'Cancel scheduled'
                          : (isPremium ? 'Active' : 'Free'),
                      tone: cancelScheduled
                          ? _StatusTone.warning
                          : (isPremium
                              ? _StatusTone.success
                              : _StatusTone.neutral),
                    ),
                  ],
                ),
                if (periodEnd != null && isPremium) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cancelScheduled
                            ? 'Access until ${dateFmt.format(periodEnd)}'
                            : 'Current period ends ${dateFmt.format(periodEnd)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LimitChip(
                      label: 'Courses',
                      value: '${access.maxPublishedCourses}',
                    ),
                    _LimitChip(
                      label: 'Lessons',
                      value: '${access.maxLessonsPerCourse}',
                    ),
                    _LimitChip(
                      label: 'Assignments',
                      value: '${access.maxAssignmentsPerCourse}',
                    ),
                    _LimitChip(
                      label: 'Projects',
                      value: '${access.maxProjectsPerCourse}',
                    ),
                    _LimitChip(
                      label: 'Grand tests',
                      value: '${access.maxGrandTestsPerCourse}',
                    ),
                    _LimitChip(
                      label: 'AI credits',
                      value: '${access.maxAiCreditsPerMonth}/mo',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onUpgrade,
                  icon: Icon(
                    isPremium
                        ? Icons.swap_horiz_rounded
                        : Icons.workspace_premium_rounded,
                  ),
                  label: Text(
                    isPremium ? 'Change or upgrade' : 'Upgrade plan',
                  ),
                ),
                if (onCancel != null)
                  OutlinedButton.icon(
                    onPressed: cancelling ? null : onCancel,
                    icon: cancelling
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(cancelling ? 'Cancelling…' : 'Cancel anytime'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatusTone { success, warning, neutral }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    switch (tone) {
      case _StatusTone.success:
        color = AppColors.success;
      case _StatusTone.warning:
        color = AppColors.warning;
      case _StatusTone.neutral:
        color = theme.colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.labelMedium,
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingShortcuts extends StatelessWidget {
  const _BillingShortcuts({required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context) {
    final items = <_BillingLink>[
      _BillingLink(
        icon: Icons.history_rounded,
        label: 'Purchase history',
        onTap: () {
          if (teacherId.isEmpty) return;
          context.pushNamed(
            RouteNames.teacherPurchaseHistory,
            queryParameters: {'userId': teacherId},
          );
        },
      ),
      _BillingLink(
        icon: Icons.credit_card_rounded,
        label: 'Payment methods',
        onTap: () => context.pushNamed(RouteNames.teacherPaymentMethods),
      ),
      _BillingLink(
        icon: Icons.auto_awesome_rounded,
        label: 'AI credit packs',
        onTap: () => context.pushNamed(RouteNames.creditPacks),
      ),
      _BillingLink(
        icon: Icons.receipt_long_rounded,
        label: 'Transactions',
        onTap: () => context.pushNamed(
          RouteNames.myTransactions,
          queryParameters: {'role': 'teacher'},
        ),
      ),
      _BillingLink(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Earnings',
        onTap: () => context.pushNamed(RouteNames.teacherEarnings),
      ),
      _BillingLink(
        icon: Icons.storefront_rounded,
        label: 'Paid courses',
        onTap: () => context.pushNamed(RouteNames.teacherPaidCourses),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (item) => SizedBox(
                    width: (constraints.maxWidth - 20) / 3,
                    child: _BillingShortcutTile(item: item),
                  ),
                )
                .toList(),
          );
        }
        return Column(
          children: [
            for (final item in items) ...[
              _BillingShortcutTile(item: item),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _BillingLink {
  const _BillingLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _BillingShortcutTile extends StatelessWidget {
  const _BillingShortcutTile({required this.item});

  final _BillingLink item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCompareCard extends StatelessWidget {
  const _PlanCompareCard({
    required this.plan,
    required this.isSelected,
    required this.badge,
    required this.isCurrent,
    required this.onSelect,
  });

  final PaymentPlanModel plan;
  final bool isSelected;
  final String badge;
  final bool isCurrent;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFree = plan.price <= 0;
    final features = <String>[
      '${plan.maxPublishedCourses} published courses',
      '${plan.maxLessonsPerCourse} lessons / course',
      '${plan.maxAssignmentsPerCourse} assignments / course',
      '${plan.maxProjectsPerCourse} projects / course',
      '${plan.maxGrandTestsPerCourse} grand tests / course',
      '${plan.maxAiCreditsPerMonth} AI credits / month',
      if (plan.allowPaidCourses) 'Paid course marketplace',
      if (plan.allowAnalytics) 'Teaching analytics',
      if (!plan.allowPaidCourses) 'Paid courses locked',
      if (!plan.allowAnalytics) 'Analytics locked',
    ];

    final borderColor = isCurrent
        ? AppColors.success.withValues(alpha: 0.55)
        : (isSelected
            ? AppColors.primary.withValues(alpha: 0.65)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.9));

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFree
                              ? 'Free forever'
                              : '${plan.currency} ${plan.price.toStringAsFixed(2)} / ${plan.interval}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CoursePill(
                    icon: isCurrent
                        ? Icons.check_circle_rounded
                        : (badge == 'Upgrade'
                            ? Icons.rocket_launch_rounded
                            : Icons.workspace_premium_rounded),
                    label: badge,
                  ),
                ],
              ),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  plan.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        f.contains('locked')
                            ? Icons.lock_outline_rounded
                            : Icons.check_circle_rounded,
                        size: 18,
                        color: f.contains('locked')
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
              if (onSelect != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onSelect,
                    icon: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    label: Text(
                      isSelected
                          ? 'Selected'
                          : (badge == 'Upgrade'
                              ? 'Select to upgrade'
                              : badge == 'Reactivate'
                                  ? 'Select to reactivate'
                                  : 'Select to switch'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNullPlan<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
