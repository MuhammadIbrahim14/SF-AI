import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_finance_model.dart';
import '../../../models/escrow_hold_model.dart';
import '../../../models/invoice_model.dart';
import '../../../models/service_order_model.dart';
import '../../../providers/admin_finance_provider.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';

class AdminFinanceCenterScreen extends ConsumerStatefulWidget {
  const AdminFinanceCenterScreen({super.key});

  @override
  ConsumerState<AdminFinanceCenterScreen> createState() =>
      _AdminFinanceCenterScreenState();
}

class _AdminFinanceCenterScreenState
    extends ConsumerState<AdminFinanceCenterScreen> {
  AdminFinanceFilter _filter = const AdminFinanceFilter();
  String _range = 'all';

  @override
  Widget build(BuildContext context) {
    final financeAsync = ref.watch(adminFinanceSnapshotProvider);
    final exportState = ref.watch(pdfExportActionProvider);

    return AdminControlScaffold(
      title: 'Finance Center',
      subtitle:
          'Enterprise sandbox revenue, escrow, wallet, and marketplace analytics.',
      currentPath: RoutePaths.adminFinanceCenter,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.adminCommerceOrders),
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('Orders'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.adminResolutionDesk),
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('Resolution Desk'),
        ),
        IconButton(
          tooltip: 'Refresh finance snapshot',
          onPressed: () => ref.invalidate(adminFinanceSnapshotProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: financeAsync.when(
            loading: () => const _FinanceLoadingState(),
            error: (error, _) => DashboardEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Finance center unavailable',
              message: error.toString(),
            ),
            data: (snapshot) {
              final filtered = snapshot.filtered(_filter);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SandboxBanner(generatedAt: snapshot.generatedAt),
                  const SizedBox(height: 18),
                  _FinanceFilters(
                    snapshot: snapshot,
                    range: _range,
                    filter: _filter,
                    onRangeChanged: (value) =>
                        setState(() => _applyRange(value)),
                    onFilterChanged: (filter) =>
                        setState(() => _filter = filter),
                  ),
                  const SizedBox(height: 18),
                  _ExportBar(
                    busy: exportState.isLoading,
                    onExportSummary: () =>
                        _exportReport(filtered, 'SkillForge Finance Summary'),
                    onExportRevenue: () =>
                        _exportReport(filtered, 'SkillForge Revenue Report'),
                    onExportCommission: () =>
                        _exportReport(filtered, 'SkillForge Commission Report'),
                    onExportRefunds: () =>
                        _exportReport(filtered, 'SkillForge Refund Summary'),
                    onExportTransactions: () => _exportReport(
                      filtered,
                      'SkillForge Transaction Summary',
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (filtered.orders.isEmpty &&
                      filtered.transactions.isEmpty &&
                      filtered.invoices.isEmpty)
                    DashboardEmptyState(
                      icon: Icons.analytics_outlined,
                      title: 'No finance data in this view',
                      message:
                          'Adjust filters or wait for marketplace orders, payments, invoices, and payouts.',
                      actionLabel: 'Reset Filters',
                      onAction: () => setState(() {
                        _range = 'all';
                        _filter = const AdminFinanceFilter();
                      }),
                    )
                  else ...[
                    _KpiGrid(snapshot: filtered),
                    const SizedBox(height: 18),
                    _AnalyticsRow(snapshot: filtered),
                    const SizedBox(height: 18),
                    _BreakdownRow(snapshot: filtered),
                    const SizedBox(height: 18),
                    _FinanceTables(snapshot: filtered),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportReport(
    AdminFinanceSnapshot snapshot,
    String title,
  ) async {
    final ok = await ref
        .read(pdfExportActionProvider.notifier)
        .exportFinanceReport(snapshot, title: title);
    if (!mounted) return;
    final notifier = ref.read(pdfExportActionProvider.notifier);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '$title exported.' : notifier.errorMessage ?? 'Export failed.',
        ),
      ),
    );
  }

  void _applyRange(String value) {
    _range = value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _filter = switch (value) {
      'today' => _filter.copyWith(startDate: today, clearEnd: true),
      'week' => _filter.copyWith(
        startDate: today.subtract(Duration(days: now.weekday - 1)),
        clearEnd: true,
      ),
      'month' => _filter.copyWith(
        startDate: DateTime(now.year, now.month),
        clearEnd: true,
      ),
      'year' => _filter.copyWith(startDate: DateTime(now.year), clearEnd: true),
      _ => _filter.copyWith(clearStart: true, clearEnd: true),
    };
  }
}

class _FinanceLoadingState extends StatelessWidget {
  const _FinanceLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        LinearProgressIndicator(),
        SizedBox(height: 24),
        DashboardEmptyState(
          icon: Icons.analytics_rounded,
          title: 'Building finance snapshot',
          message:
              'Reading sandbox orders, wallets, invoices, payouts, refunds, and disputes.',
        ),
      ],
    );
  }
}

class _SandboxBanner extends StatelessWidget {
  const _SandboxBanner({required this.generatedAt});

  final DateTime generatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: AppColors.warning.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.science_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sandbox finance only. No real gateway, bank transfer, or external payout is connected. Snapshot generated ${DateFormat('MMM d, h:mm a').format(generatedAt)}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceFilters extends StatelessWidget {
  const _FinanceFilters({
    required this.snapshot,
    required this.range,
    required this.filter,
    required this.onRangeChanged,
    required this.onFilterChanged,
  });

  final AdminFinanceSnapshot snapshot;
  final String range;
  final AdminFinanceFilter filter;
  final ValueChanged<String> onRangeChanged;
  final ValueChanged<AdminFinanceFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final categories = {
      'all',
      ...snapshot.orders
          .map((order) => order.serviceCategory)
          .where((item) => item.trim().isNotEmpty),
    }.toList()..sort();
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: range,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Time')),
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'year', child: Text('This Year')),
              ],
              onChanged: (value) => onRangeChanged(value ?? 'all'),
            ),
            DropdownButton<String>(
              value: filter.status,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(
                  value: ServiceOrderStatus.pending,
                  child: Text('Pending'),
                ),
                DropdownMenuItem(
                  value: ServiceOrderStatus.active,
                  child: Text('Active'),
                ),
                DropdownMenuItem(
                  value: ServiceOrderStatus.completed,
                  child: Text('Completed'),
                ),
                DropdownMenuItem(
                  value: ServiceOrderStatus.cancelled,
                  child: Text('Cancelled'),
                ),
                DropdownMenuItem(
                  value: ServiceOrderStatus.disputed,
                  child: Text('Disputed'),
                ),
              ],
              onChanged: (value) =>
                  onFilterChanged(filter.copyWith(status: value ?? 'all')),
            ),
            DropdownButton<String>(
              value: categories.contains(filter.category)
                  ? filter.category
                  : 'all',
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(
                        category == 'all' ? 'All Categories' : category,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  onFilterChanged(filter.copyWith(category: value ?? 'all')),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Freelancer',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    onFilterChanged(filter.copyWith(freelancerQuery: value)),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    onFilterChanged(filter.copyWith(customerQuery: value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({
    required this.busy,
    required this.onExportSummary,
    required this.onExportRevenue,
    required this.onExportCommission,
    required this.onExportRefunds,
    required this.onExportTransactions,
  });

  final bool busy;
  final VoidCallback onExportSummary;
  final VoidCallback onExportRevenue;
  final VoidCallback onExportCommission;
  final VoidCallback onExportRefunds;
  final VoidCallback onExportTransactions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onExportSummary,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Finance Summary PDF'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onExportRevenue,
          icon: const Icon(Icons.trending_up_rounded, size: 18),
          label: const Text('Revenue Report'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onExportCommission,
          icon: const Icon(Icons.percent_rounded, size: 18),
          label: const Text('Commission Report'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onExportRefunds,
          icon: const Icon(Icons.replay_circle_filled_rounded, size: 18),
          label: const Text('Refund Summary'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onExportTransactions,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Transaction Summary'),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final AdminFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final k = snapshot.kpis;
    final c = snapshot.currency;
    return ResponsiveGrid(
      minChildWidth: 200,
      children: [
        _metric(
          'Today Revenue',
          _money(k.todayRevenue, c),
          Icons.today_rounded,
          AppColors.success,
        ),
        _metric(
          'Weekly Revenue',
          _money(k.weeklyRevenue, c),
          Icons.view_week_rounded,
          AppColors.info,
        ),
        _metric(
          'Monthly Revenue',
          _money(k.monthlyRevenue, c),
          Icons.calendar_month_rounded,
          AppColors.adminPrimary,
        ),
        _metric(
          'Yearly Revenue',
          _money(k.yearlyRevenue, c),
          Icons.insights_rounded,
          AppColors.superAdminPrimary,
        ),
        _metric(
          'Lifetime Revenue',
          _money(k.lifetimeRevenue, c),
          Icons.all_inclusive_rounded,
          AppColors.success,
        ),
        _metric(
          'Platform Commission',
          _money(k.platformCommission, c),
          Icons.percent_rounded,
          AppColors.warning,
        ),
        _metric(
          'Gross Revenue',
          _money(k.grossRevenue, c),
          Icons.payments_rounded,
          AppColors.info,
        ),
        _metric(
          'Net Revenue',
          _money(k.netRevenue, c),
          Icons.account_balance_rounded,
          AppColors.success,
        ),
        _metric(
          'Orders',
          '${k.orderCount}',
          Icons.receipt_long_rounded,
          AppColors.adminPrimary,
        ),
        _metric(
          'Completed Orders',
          '${k.completedOrders}',
          Icons.verified_rounded,
          AppColors.success,
        ),
        _metric(
          'Pending Orders',
          '${k.pendingOrders}',
          Icons.pending_actions_rounded,
          AppColors.warning,
        ),
        _metric(
          'Cancelled Orders',
          '${k.cancelledOrders}',
          Icons.cancel_outlined,
          AppColors.error,
        ),
        _metric(
          'Refund Count',
          '${k.refundCount}',
          Icons.replay_circle_filled_rounded,
          AppColors.error,
        ),
        _metric(
          'Refund Value',
          _money(k.refundValue, c),
          Icons.money_off_rounded,
          AppColors.error,
        ),
        _metric(
          'Escrow Held',
          _money(k.escrowHeld, c),
          Icons.lock_clock_rounded,
          AppColors.warning,
        ),
        _metric(
          'Escrow Released',
          _money(k.escrowReleased, c),
          Icons.lock_open_rounded,
          AppColors.success,
        ),
        _metric(
          'Pending Withdrawals',
          _money(k.pendingWithdrawals, c),
          Icons.outbound_rounded,
          AppColors.warning,
        ),
        _metric(
          'Completed Withdrawals',
          _money(k.completedWithdrawals, c),
          Icons.task_alt_rounded,
          AppColors.success,
        ),
        _metric(
          'Wallet Totals',
          _money(k.walletAvailable + k.walletPending + k.walletEscrow, c),
          Icons.account_balance_wallet_rounded,
          AppColors.info,
        ),
        _metric(
          'Average Order Value',
          _money(k.averageOrderValue, c),
          Icons.show_chart_rounded,
          AppColors.superAdminPrimary,
        ),
      ],
    );
  }

  MetricCard _metric(String title, String value, IconData icon, Color color) {
    return MetricCard(title: title, value: value, icon: icon, color: color);
  }
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.snapshot});

  final AdminFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final revenue = snapshot.trend(
      (order) => order.paidAt ?? order.createdAt,
      (order) => order.totalAmount,
    );
    final commission = snapshot.platformCommissionTrend();
    final refunds = snapshot.refunds
        .map(
          (refund) => FinanceTrendPoint(
            label: DateFormat('MM/dd').format(refund.createdAt),
            value: refund.amount,
          ),
        )
        .toList();
    return ResponsiveGrid(
      minChildWidth: 300,
      children: [
        _TrendCard(
          title: 'Revenue Trend',
          points: revenue,
          color: AppColors.success,
        ),
        _TrendCard(
          title: 'Commission Trend',
          points: commission,
          color: AppColors.warning,
        ),
        _TrendCard(
          title: 'Refund Trend',
          points: refunds,
          color: AppColors.error,
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.points,
    required this.color,
  });

  final String title;
  final List<FinanceTrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = points.fold<double>(
      0,
      (value, point) => point.value > value ? point.value : value,
    );
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'No trend data yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: points
                          .map(
                            (point) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Tooltip(
                                  message:
                                      '${point.label}: ${point.value.toStringAsFixed(2)}',
                                  child: FractionallySizedBox(
                                    heightFactor: max <= 0
                                        ? 0.04
                                        : (point.value / max).clamp(0.04, 1),
                                    alignment: Alignment.bottomCenter,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.78),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.snapshot});

  final AdminFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minChildWidth: 300,
      children: [
        _BreakdownCard(
          title: 'Top Services',
          items: snapshot.topServices(),
          currency: snapshot.currency,
        ),
        _BreakdownCard(
          title: 'Top Freelancers',
          items: snapshot.topFreelancers(),
          currency: snapshot.currency,
        ),
        _BreakdownCard(
          title: 'Top Categories',
          items: snapshot.topCategories(),
          currency: snapshot.currency,
        ),
        _BreakdownCard(
          title: 'Top Clients',
          items: snapshot.topClients(),
          currency: snapshot.currency,
        ),
        _BreakdownCard(
          title: 'Platform Fees by Provider',
          items: snapshot.platformFeesByProvider(),
          currency: snapshot.currency,
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.items,
    required this.currency,
  });

  final String title;
  final List<FinanceBreakdownItem> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('No data yet', style: theme.textTheme.bodyMedium)
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${item.count} · ${_money(item.amount, currency)}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinanceTables extends StatelessWidget {
  const _FinanceTables({required this.snapshot});

  final AdminFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TableSection(
          title: 'Recent Orders',
          icon: Icons.receipt_long_rounded,
          children: snapshot.orders
              .take(8)
              .map(
                (order) => _FinanceTile(
                  title: order.serviceTitle,
                  subtitle:
                      '${order.orderNumber} · ${order.clientName} → ${order.freelancerName}',
                  value: _money(order.totalAmount, order.currency),
                  status: _label(order.orderStatus),
                  onTap: () => context.pushNamed(
                    RouteNames.serviceOrderDetail,
                    pathParameters: {'orderId': order.orderId},
                  ),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Transactions',
          icon: Icons.swap_horiz_rounded,
          children: snapshot.transactions
              .take(8)
              .map(
                (item) => _FinanceTile(
                  title: _label(item.type),
                  subtitle: item.description,
                  value: _money(item.amount, item.currency),
                  status: _label(item.status),
                  onTap: () => context.pushNamed(
                    RouteNames.adminFinanceDetail,
                    pathParameters: {
                      'type': 'transaction',
                      'id': item.transactionId,
                    },
                  ),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Wallet Updates',
          icon: Icons.account_balance_wallet_rounded,
          children: snapshot.wallets
              .take(8)
              .map(
                (wallet) => _FinanceTile(
                  title: wallet.freelancerId,
                  subtitle:
                      'Available ${_money(wallet.availableBalance, wallet.currency)} · Pending ${_money(wallet.pendingBalance, wallet.currency)}',
                  value: _money(wallet.escrowBalance, wallet.currency),
                  status: 'Escrow',
                  onTap: () => context.pushNamed(
                    RouteNames.adminFinanceDetail,
                    pathParameters: {'type': 'wallet', 'id': wallet.walletId},
                  ),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Payouts',
          icon: Icons.outbound_rounded,
          children: snapshot.payouts
              .take(8)
              .map(
                (payout) => _FinanceTile(
                  title: payout.freelancerId,
                  subtitle:
                      '${payout.destinationType} · ${payout.destinationMasked}',
                  value: _money(payout.amount, payout.currency),
                  status: _label(payout.status),
                  onTap: () => context.goNamed(RouteNames.adminPayouts),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Refunds',
          icon: Icons.replay_circle_filled_rounded,
          children: snapshot.refunds
              .take(8)
              .map(
                (refund) => _FinanceTile(
                  title: refund.serviceTitle,
                  subtitle: refund.reason,
                  value: _money(refund.amount, refund.currency),
                  status: _label(refund.status),
                  onTap: () => context.pushNamed(
                    RouteNames.adminFinanceDetail,
                    pathParameters: {'type': 'refund', 'id': refund.refundId},
                  ),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Disputes',
          icon: Icons.gavel_rounded,
          children: snapshot.disputes
              .take(8)
              .map(
                (dispute) => _FinanceTile(
                  title: dispute.serviceTitle,
                  subtitle: dispute.reason,
                  value: dispute.decision == null
                      ? 'Review'
                      : _label(dispute.decision!),
                  status: _label(dispute.status),
                  onTap: () => context.pushNamed(
                    RouteNames.adminFinanceDetail,
                    pathParameters: {
                      'type': 'dispute',
                      'id': dispute.disputeId,
                    },
                  ),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Invoices',
          icon: Icons.description_rounded,
          children: snapshot.invoices
              .take(8)
              .map(
                (invoice) => _FinanceTile(
                  title: invoice.invoiceNumber,
                  subtitle:
                      '${InvoiceType.label(invoice.type)} · ${invoice.serviceTitle}',
                  value: _money(invoice.totalAmount, invoice.currency),
                  status: _label(invoice.status),
                  onTap: () => context.pushNamed(
                    RouteNames.adminInvoiceDetail,
                    pathParameters: {'invoiceId': invoice.invoiceId},
                  ),
                ),
              )
              .toList(),
        ),
        _TableSection(
          title: 'Recent Escrow Releases',
          icon: Icons.lock_open_rounded,
          children: snapshot.escrows
              .where((item) => item.status == EscrowHoldStatus.released)
              .take(8)
              .map(
                (escrow) => _FinanceTile(
                  title: escrow.orderId,
                  subtitle: escrow.holdReason,
                  value: _money(escrow.amount, escrow.currency),
                  status: _label(escrow.status),
                  onTap: () => context.pushNamed(
                    RouteNames.adminFinanceDetail,
                    pathParameters: {'type': 'escrow', 'id': escrow.escrowId},
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TableSection extends StatelessWidget {
  const _TableSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.36,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (children.isEmpty)
                Text(
                  'No records yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  const _FinanceTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tileColor: theme.colorScheme.surface.withValues(alpha: 0.46),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}

String _label(String value) {
  if (value.isEmpty) return 'Unknown';
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}
