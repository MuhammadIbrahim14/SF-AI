import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_wallet_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/teacher_wallet_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../courses/data/models/marketplace_models.dart';
import '../../courses/presentation/course_premium_widgets.dart';
import '../../courses/providers/course_provider.dart';
import '../../courses/providers/purchase_provider.dart';
import '../providers/payment_providers.dart';
import 'widgets/stripe_connect_card.dart';

/// Teacher commerce wallet: course sales, balances, demo release & withdraw.
class TeacherWalletScreen extends ConsumerStatefulWidget {
  const TeacherWalletScreen({super.key});

  @override
  ConsumerState<TeacherWalletScreen> createState() =>
      _TeacherWalletScreenState();
}

class _TeacherWalletScreenState extends ConsumerState<TeacherWalletScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_initialized) return;
    _initialized = true;
    await ref.read(teacherWalletActionProvider.notifier).ensureAndSync();
  }

  Future<void> _refresh() async {
    await ref.read(teacherWalletActionProvider.notifier).ensureAndSync();
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = ref.watch(authStateProvider).value?.uid ?? '';
    final walletAsync = ref.watch(myTeacherWalletProvider);
    final transactionsAsync = ref.watch(myTeacherWalletTransactionsProvider);
    final salesAsync = ref.watch(teacherSalesHistoryProvider(teacherId));
    final summaryAsync = ref.watch(teacherEarningsSummaryProvider(teacherId));
    final coursesAsync = ref.watch(teacherCoursesProvider);
    final actionState = ref.watch(teacherWalletActionProvider);
    final isBusy = actionState.isLoading;

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Teacher Wallet',
      subtitle:
          'Course sales, student purchases, balances, and demo withdrawals.',
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
                message: 'Please sign in to view your teacher wallet.',
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: summaryAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => CoursePremiumMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load wallet',
                    message: e.toString(),
                  ),
                  data: (summary) {
                    final wallet = walletAsync.asData?.value;
                    final salesForFallback =
                        salesAsync.asData?.value ?? summary.recentSales;
                    final safeWallet = wallet ??
                        TeacherWalletModel(
                          walletId: teacherId,
                          teacherId: teacherId,
                          availableBalance: 0,
                          pendingBalance: summary.totalCourseRevenue,
                          lifetimeEarnings: summary.totalCourseRevenue,
                          lifetimeWithdrawn: 0,
                          currency: summary.currency,
                          totalSalesCount: summary.totalSalesCount,
                          uniqueStudentCount: salesForFallback
                              .map((s) => s.studentId)
                              .toSet()
                              .length,
                          monthSalesCount: summary.monthSalesCount,
                          monthRevenue: summary.monthCourseRevenue,
                          updatedAt: DateTime.now(),
                          createdAt: DateTime.now(),
                        );
                    final courseTitles = <String, String>{
                      for (final c in coursesAsync.value ?? const [])
                        c.id: c.title,
                    };

                    return CoursePremiumListView(
                      children: [
                        if (walletAsync.hasError) ...[
                          CoursePremiumMessage(
                            icon: Icons.sync_problem_rounded,
                            title: 'Wallet sync limited',
                            message:
                                'Showing sales totals. Balance actions may need a refresh after rules deploy.\n'
                                '${walletAsync.error}',
                          ),
                          const SizedBox(height: 16),
                        ],
                        const _DemoNoticeBanner(),
                        const SizedBox(height: 16),
                        _BalanceOverview(wallet: safeWallet),
                        const SizedBox(height: 16),
                        _CommerceStats(
                          wallet: safeWallet,
                          summary: summary,
                          courseTitles: courseTitles,
                        ),
                        const SizedBox(height: 16),
                        _WalletActions(
                          wallet: safeWallet,
                          isBusy: isBusy,
                          onRelease: () => _release(context),
                          onWithdraw: () => _withdraw(context, safeWallet),
                        ),
                        const SizedBox(height: 16),
                        const StripeConnectCard(
                          role: 'teacher',
                          accent: AppColors.teacherPrimary,
                        ),
                        const SizedBox(height: 16),
                        _QuickLinksRow(),
                        const SizedBox(height: 16),
                        salesAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (e, _) => CoursePremiumMessage(
                            icon: Icons.error_outline,
                            title: 'Sales unavailable',
                            message: e.toString(),
                          ),
                          data: (sales) => _StudentPurchasesPanel(
                            sales: sales,
                            courseTitles: courseTitles,
                          ),
                        ),
                        const SizedBox(height: 16),
                        transactionsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (txns) => _TransactionsPanel(transactions: txns),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _release(BuildContext context) async {
    final ok = await ref
        .read(teacherWalletActionProvider.notifier)
        .releasePending();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pending earnings released to available balance.'
              : ref.read(teacherWalletActionProvider.notifier).errorMessage ??
                  'Unable to release earnings.',
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, TeacherWalletModel wallet) async {
    if (wallet.availableBalance <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demo withdraw?'),
        content: Text(
          'Withdraw ${wallet.currency} ${wallet.availableBalance.toStringAsFixed(2)} '
          'to your demo wallet history. No real bank transfer is processed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(teacherWalletActionProvider.notifier)
        .demoWithdraw();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demo withdrawal recorded.'
              : ref.read(teacherWalletActionProvider.notifier).errorMessage ??
                  'Unable to withdraw.',
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }
}

class _DemoNoticeBanner extends StatelessWidget {
  const _DemoNoticeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sandbox wallet — balances sync from paid course sales. '
              'Release and withdraw are demo-only; no real payouts.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({required this.wallet});

  final TeacherWalletModel wallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet balances',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: 'Available',
                value: _money(wallet.availableBalance, wallet.currency),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.success,
              ),
              _MetricTile(
                label: 'Pending',
                value: _money(wallet.pendingBalance, wallet.currency),
                icon: Icons.hourglass_top_rounded,
                color: AppColors.warning,
              ),
              _MetricTile(
                label: 'Lifetime earnings',
                value: _money(wallet.lifetimeEarnings, wallet.currency),
                icon: Icons.trending_up_rounded,
                color: AppColors.primary,
              ),
              _MetricTile(
                label: 'Withdrawn (demo)',
                value: _money(wallet.lifetimeWithdrawn, wallet.currency),
                icon: Icons.outbound_rounded,
                color: AppColors.info,
              ),
            ],
          ),
          if (wallet.lastSyncAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last synced ${_fmt(wallet.lastSyncAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommerceStats extends StatelessWidget {
  const _CommerceStats({
    required this.wallet,
    required this.summary,
    required this.courseTitles,
  });

  final TeacherWalletModel wallet;
  final TeacherEarningsSummary? summary;
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
            'Commerce overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: 'Total sales',
                value: '${wallet.totalSalesCount}',
                icon: Icons.shopping_bag_outlined,
                color: AppColors.info,
              ),
              _MetricTile(
                label: 'Students purchased',
                value: '${wallet.uniqueStudentCount}',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
              ),
              _MetricTile(
                label: 'Sales this month',
                value: '${wallet.monthSalesCount}',
                icon: Icons.calendar_month_rounded,
                color: AppColors.warning,
              ),
              _MetricTile(
                label: 'Revenue this month',
                value: _money(wallet.monthRevenue, wallet.currency),
                icon: Icons.payments_rounded,
                color: AppColors.success,
              ),
            ],
          ),
          if (summary != null && summary!.courseRows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Per-course performance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...summary!.courseRows.map((row) {
              final title =
                  courseTitles[row.courseId] ?? 'Course ${row.courseId}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${row.salesCount} sale${row.salesCount == 1 ? '' : 's'}',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${row.currency} ${row.revenue.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions({
    required this.wallet,
    required this.isBusy,
    required this.onRelease,
    required this.onWithdraw,
  });

  final TeacherWalletModel wallet;
  final bool isBusy;
  final VoidCallback onRelease;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: wallet.pendingBalance > 0 && !isBusy ? onRelease : null,
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Release pending earnings'),
          ),
          OutlinedButton.icon(
            onPressed: wallet.availableBalance > 0 && !isBusy
                ? onWithdraw
                : null,
            icon: const Icon(Icons.account_balance_rounded, size: 18),
            label: const Text('Demo withdraw'),
          ),
          Text(
            'Demo only — no real bank transfer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinksRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('Paid courses'),
            onPressed: () => context.pushNamed(RouteNames.teacherPaidCourses),
          ),
          ActionChip(
            avatar: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Earnings hub'),
            onPressed: () => context.pushNamed(RouteNames.teacherEarnings),
          ),
          ActionChip(
            avatar: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: const Text('Plans'),
            onPressed: () => context.pushNamed(RouteNames.teacherPlans),
          ),
        ],
      ),
    );
  }
}

class _StudentPurchasesPanel extends StatelessWidget {
  const _StudentPurchasesPanel({
    required this.sales,
    required this.courseTitles,
  });

  final List<CoursePurchase> sales;
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
            'Student purchases',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Every paid enrollment from your course marketplace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (sales.isEmpty)
            Text(
              'No paid course sales yet. Set pricing on Paid courses and share with students.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...sales.take(20).map((sale) {
              final title =
                  courseTitles[sale.courseId] ?? 'Course ${sale.courseId}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.person_rounded,
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
                  'Student ${sale.studentId.substring(0, 8)}… · '
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

class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel({required this.transactions});

  final List<TeacherWalletTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet activity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            Text(
              'Release and withdraw actions will appear here.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...transactions.take(10).map((txn) {
              final icon = switch (txn.type) {
                TeacherWalletTransactionType.withdraw => Icons.outbound_rounded,
                TeacherWalletTransactionType.release => Icons.lock_open_rounded,
                _ => Icons.sync_rounded,
              };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: AppColors.primary),
                title: Text(
                  txn.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_fmt(txn.createdAt)),
                trailing: Text(
                  '${txn.currency} ${txn.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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

String _money(double amount, String currency) =>
    '$currency ${amount.toStringAsFixed(2)}';

String _fmt(DateTime date) => DateFormat.yMMMd().add_jm().format(date);
