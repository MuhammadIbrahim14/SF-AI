import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/customer_wallet_model.dart';
import '../../../providers/customer_wallet_provider.dart';
import '../../../shared/widgets/customer_workspace_shell.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/presentation/checkout/payfast_checkout_sheet.dart';

class CustomerWalletScreen extends ConsumerStatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  ConsumerState<CustomerWalletScreen> createState() =>
      _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends ConsumerState<CustomerWalletScreen> {
  final _amountController = TextEditingController(text: '100');
  bool _requestedWallet = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(myCustomerWalletProvider);
    final transactionsAsync = ref.watch(myCustomerWalletTransactionsProvider);
    final actionState = ref.watch(customerWalletActionProvider);

    if (!_requestedWallet) {
      _requestedWallet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(customerWalletActionProvider.notifier).getOrCreateMyWallet();
      });
    }

    return CustomerWorkspaceShell(
      child: walletAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => _WalletPage(
          child: DashboardEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet unavailable',
            message: error.toString(),
          ),
        ),
        data: (wallet) => _WalletPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WalletHero(wallet: wallet),
              const SizedBox(height: 20),
              ResponsiveGrid(
                minChildWidth: 190,
                children: [
                  MetricCard(
                    title: 'Available',
                    value: _money(wallet?.availableBalance ?? 0),
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                  ),
                  MetricCard(
                    title: 'Total Added',
                    value: _money(wallet?.totalAdded ?? 0),
                    icon: Icons.add_card_rounded,
                    color: AppColors.primary,
                  ),
                  MetricCard(
                    title: 'Spent',
                    value: _money(wallet?.totalSpent ?? 0),
                    icon: Icons.shopping_bag_rounded,
                    color: AppColors.warning,
                  ),
                  MetricCard(
                    title: 'Escrowed',
                    value: _money(wallet?.totalEscrowed ?? 0),
                    icon: Icons.lock_rounded,
                    color: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _TopUpPanel(
                controller: _amountController,
                busy: actionState.isLoading,
                error: actionState.error?.toString(),
                onTopUp: _addBalance,
              ),
              const SizedBox(height: 20),
              transactionsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => DashboardEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ledger unavailable',
                  message: error.toString(),
                ),
                data: (transactions) =>
                    _TransactionHistory(transactions: transactions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addBalance() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }
    final result = await showPayFastCheckoutSheet(
      context: context,
      ref: ref,
      type: 'wallet_topup',
      amount: amount,
      currency: 'PKR',
      description: 'Wallet top-up',
      role: 'customer',
      metadata: {'walletRole': 'customer'},
      title: 'Top up wallet',
    );
    if (!mounted) return;
    if (result != null && PaymentStatus.isSuccess(result.status)) {
      ref.invalidate(myCustomerWalletProvider);
      ref.invalidate(myCustomerWalletTransactionsProvider);
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } else if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }
}

class _WalletPage extends StatelessWidget {
  const _WalletPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.wallet});

  final CustomerWalletModel? wallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.success.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 34),
              Text(
                'Customer Demo Wallet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                label: Text(wallet?.status ?? CustomerWalletStatus.active),
                avatar: const Icon(Icons.verified_user_rounded, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Demo funds only — no real money is processed.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _money(wallet?.availableBalance ?? 0),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            wallet?.currency ?? 'USD',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpPanel extends StatelessWidget {
  const _TopUpPanel({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onTopUp,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add demo balance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use this balance for future sandbox checkout phases. It is not connected to order payment yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final amount in const [100, 500, 1000])
                  ActionChip(
                    label: Text('\$$amount'),
                    onPressed: busy
                        ? null
                        : () => controller.text = amount.toString(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final input = TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                );
                final button = FilledButton.icon(
                  onPressed: busy ? null : onTopUp,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_card_rounded),
                  label: const Text('Add Demo Balance'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [input, const SizedBox(height: 12), button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: input),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
            ),
            if ((error ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransactionHistory extends StatelessWidget {
  const _TransactionHistory({required this.transactions});

  final List<WalletTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (transactions.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No wallet transactions yet',
        message: 'Top up demo balance to start your customer wallet ledger.',
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet Ledger',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in transactions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: item.direction == WalletTransactionDirection.debit
                      ? Theme.of(context).colorScheme.error.withValues(alpha: 0.14)
                      : AppColors.success.withValues(alpha: 0.14),
                  child: Icon(
                    item.direction == WalletTransactionDirection.debit
                        ? Icons.remove_rounded
                        : Icons.add_rounded,
                    color: item.direction == WalletTransactionDirection.debit
                        ? Theme.of(context).colorScheme.error
                        : AppColors.success,
                  ),
                ),
                title: Text(item.description),
                subtitle: Text(
                  '${item.type} • ${DateFormat.yMMMd().add_jm().format(item.createdAt)}',
                ),
                trailing: Text(
                  '${item.direction == WalletTransactionDirection.debit ? '-' : '+'}${_money(item.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: item.direction == WalletTransactionDirection.debit
                        ? Theme.of(context).colorScheme.error
                        : AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) {
  return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);
}
