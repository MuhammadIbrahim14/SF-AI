import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/commerce_transaction_model.dart';
import '../../../models/freelancer_wallet_model.dart';
import '../../../models/service_order_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/commerce_order_provider.dart';
import '../../../providers/freelancer_wallet_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../payment/presentation/widgets/stripe_connect_card.dart';

class FreelancerWalletScreen extends ConsumerStatefulWidget {
  const FreelancerWalletScreen({super.key});

  @override
  ConsumerState<FreelancerWalletScreen> createState() =>
      _FreelancerWalletScreenState();
}

class _FreelancerWalletScreenState
    extends ConsumerState<FreelancerWalletScreen> {
  bool _requestedEnsure = false;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(myFreelancerWalletProvider);
    final transactionsAsync = ref.watch(myWalletTransactionsProvider);
    final ordersAsync = ref.watch(freelancerServiceOrdersProvider);
    final actionState = ref.watch(freelancerWalletActionProvider);

    if (!_requestedEnsure) {
      _requestedEnsure = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(freelancerWalletActionProvider.notifier).ensureWallet();
      });
    }

    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Wallet & Earnings',
      subtitle:
          'Sandbox balances, escrow history, and future payout readiness.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              context.pushNamed(RouteNames.freelancerServiceOrders),
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('View Orders'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.freelancerInvoices),
          icon: const Icon(Icons.description_rounded, size: 18),
          label: const Text('Invoices'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.freelancerPayouts),
          icon: const Icon(Icons.outbound_rounded, size: 18),
          label: const Text('Payouts'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: walletAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet unavailable',
            message: error.toString(),
          ),
          data: (wallet) {
            final safeWallet =
                wallet ??
                FreelancerWalletModel.empty(freelancerId: 'freelancer');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SandboxNotice(),
                const SizedBox(height: 18),
                _WalletMetrics(wallet: safeWallet),
                const SizedBox(height: 18),
                _WalletActions(
                  wallet: safeWallet,
                  isBusy: actionState.isLoading,
                  onClear: () => _clearFunds(context),
                ),
                const SizedBox(height: 18),
                const StripeConnectCard(
                  role: 'freelancer',
                  accent: AppColors.freelancerPrimary,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 980;
                    final transactions = transactionsAsync.value ?? [];
                    final orders = ordersAsync.value ?? [];
                    if (!isDesktop) {
                      return Column(
                        children: [
                          _TransactionsPanel(transactions: transactions),
                          const SizedBox(height: 18),
                          _EscrowHistoryPanel(orders: orders),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TransactionsPanel(transactions: transactions),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: _EscrowHistoryPanel(orders: orders)),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _clearFunds(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear sandbox funds?'),
        content: const Text(
          'This moves pending sandbox funds into available balance. No real payout is processed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear Funds'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final notifier = ref.read(freelancerWalletActionProvider.notifier);
    final ok = await notifier.clearSandboxFunds();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sandbox funds moved to available balance.'
              : notifier.errorMessage ?? 'Unable to clear sandbox funds.',
        ),
      ),
    );
  }
}

class _WalletMetrics extends StatelessWidget {
  const _WalletMetrics({required this.wallet});

  final FreelancerWalletModel wallet;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minChildWidth: 210,
      children: [
        MetricCard(
          title: 'Available Balance',
          value: _money(wallet.availableBalance, wallet.currency),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Pending Balance',
          value: _money(wallet.pendingBalance, wallet.currency),
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Escrow Balance',
          value: _money(wallet.escrowBalance, wallet.currency),
          icon: Icons.lock_clock_rounded,
          color: AppColors.freelancerSecondary,
        ),
        MetricCard(
          title: 'Pending Payout',
          value: _money(wallet.pendingPayoutBalance, wallet.currency),
          icon: Icons.outbound_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Lifetime Earnings',
          value: _money(wallet.lifetimeEarnings, wallet.currency),
          icon: Icons.trending_up_rounded,
          color: AppColors.freelancerPrimary,
        ),
        MetricCard(
          title: 'Lifetime Withdrawn',
          value: _money(wallet.lifetimeWithdrawn, wallet.currency),
          icon: Icons.outbound_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Monthly Earnings',
          value: _money(wallet.monthlyEarnings, wallet.currency),
          icon: Icons.calendar_month_rounded,
          color: AppColors.freelancerPrimary,
        ),
        MetricCard(
          title: 'Weekly Earnings',
          value: _money(wallet.weeklyEarnings, wallet.currency),
          icon: Icons.date_range_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Orders This Month',
          value: '${wallet.ordersThisMonth}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions({
    required this.wallet,
    required this.isBusy,
    required this.onClear,
  });

  final FreelancerWalletModel wallet;
  final bool isBusy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: wallet.pendingBalance > 0 && !isBusy ? onClear : null,
            icon: const Icon(Icons.cleaning_services_rounded, size: 18),
            label: const Text('Clear Sandbox Funds'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(RouteNames.freelancerPayouts),
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: const Text('Request Payout'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(RouteNames.freelancerInvoices),
            icon: const Icon(Icons.description_rounded, size: 18),
            label: const Text('View Invoices'),
          ),
          Text(
            'Sandbox clearance only. Real payouts are intentionally disabled.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel({required this.transactions});

  final List<CommerceTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent Transactions',
      child: transactions.isEmpty
          ? const DashboardEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No wallet transactions yet',
              message:
                  'Escrow releases and sandbox clearances will appear here.',
            )
          : Column(
              children: transactions
                  .take(8)
                  .map((item) => _TransactionTile(transaction: item))
                  .toList(),
            ),
    );
  }
}

class _EscrowHistoryPanel extends StatelessWidget {
  const _EscrowHistoryPanel({required this.orders});

  final List<ServiceOrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final escrowOrders = orders
        .where(
          (order) =>
              order.escrowStatus == ServiceOrderEscrowStatus.held ||
              order.escrowStatus == ServiceOrderEscrowStatus.released,
        )
        .toList();
    return _Panel(
      title: 'Escrow History',
      child: escrowOrders.isEmpty
          ? const DashboardEmptyState(
              icon: Icons.lock_clock_outlined,
              title: 'No escrow history yet',
              message:
                  'Paid sandbox orders appear here when escrow is held or released.',
            )
          : Column(
              children: escrowOrders
                  .take(8)
                  .map((order) => _EscrowTile(order: order))
                  .toList(),
            ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final CommerceTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, h:mm a');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _transactionColor(
          transaction.type,
        ).withValues(alpha: 0.12),
        child: Icon(
          _transactionIcon(transaction.type),
          color: _transactionColor(transaction.type),
        ),
      ),
      title: Text(_transactionLabel(transaction.type)),
      subtitle: Text(formatter.format(transaction.createdAt)),
      trailing: Text(
        _money(transaction.amount, transaction.currency),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EscrowTile extends StatelessWidget {
  const _EscrowTile({required this.order});

  final ServiceOrderModel order;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.freelancerSecondary.withValues(alpha: 0.12),
        child: const Icon(
          Icons.lock_clock_rounded,
          color: AppColors.freelancerSecondary,
        ),
      ),
      title: Text(
        order.serviceTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        order.escrowReleasedAt == null
            ? 'Held ${order.escrowHeldAt == null ? '' : formatter.format(order.escrowHeldAt!)}'
            : 'Released ${formatter.format(order.escrowReleasedAt!)}',
      ),
      trailing: Text(_money(order.freelancerEarnings, order.currency)),
    );
  }
}

class _SandboxNotice extends StatelessWidget {
  const _SandboxNotice();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sandbox wallet mode - balances simulate marketplace finance. No real payout or money movement is processed.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.46,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}

String _transactionLabel(String type) {
  return switch (type) {
    CommerceTransactionType.escrowRelease => 'Escrow Released',
    CommerceTransactionType.walletClearance => 'Sandbox Clearance',
    CommerceTransactionType.payoutRequest => 'Payout Requested',
    CommerceTransactionType.payoutPaid => 'Payout Paid',
    CommerceTransactionType.payoutRejected => 'Payout Rejected',
    CommerceTransactionType.payoutCancelled => 'Payout Cancelled',
    CommerceTransactionType.escrowHold => 'Escrow Hold',
    _ => type,
  };
}

IconData _transactionIcon(String type) {
  return switch (type) {
    CommerceTransactionType.escrowRelease => Icons.lock_open_rounded,
    CommerceTransactionType.walletClearance => Icons.account_balance_wallet,
    CommerceTransactionType.payoutRequest => Icons.outbound_rounded,
    CommerceTransactionType.payoutPaid => Icons.payments_rounded,
    CommerceTransactionType.payoutRejected => Icons.undo_rounded,
    CommerceTransactionType.payoutCancelled => Icons.cancel_schedule_send,
    CommerceTransactionType.escrowHold => Icons.lock_clock_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

Color _transactionColor(String type) {
  return switch (type) {
    CommerceTransactionType.escrowRelease => AppColors.warning,
    CommerceTransactionType.walletClearance => AppColors.success,
    CommerceTransactionType.payoutRequest => AppColors.info,
    CommerceTransactionType.payoutPaid => AppColors.success,
    CommerceTransactionType.payoutRejected => AppColors.error,
    CommerceTransactionType.payoutCancelled => AppColors.textTertiary,
    CommerceTransactionType.escrowHold => AppColors.freelancerSecondary,
    _ => AppColors.info,
  };
}
