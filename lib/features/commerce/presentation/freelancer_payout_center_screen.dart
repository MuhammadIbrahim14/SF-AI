import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_wallet_model.dart';
import '../../../models/payout_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/freelancer_wallet_provider.dart';
import '../../../providers/payout_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class FreelancerPayoutCenterScreen extends ConsumerStatefulWidget {
  const FreelancerPayoutCenterScreen({super.key});

  @override
  ConsumerState<FreelancerPayoutCenterScreen> createState() =>
      _FreelancerPayoutCenterScreenState();
}

class _FreelancerPayoutCenterScreenState
    extends ConsumerState<FreelancerPayoutCenterScreen> {
  final _amountController = TextEditingController();
  final _destinationNameController = TextEditingController();
  final _destinationMaskedController = TextEditingController();
  final _notesController = TextEditingController();
  String _destinationType = PayoutDestinationType.sandboxBank;

  @override
  void dispose() {
    _amountController.dispose();
    _destinationNameController.dispose();
    _destinationMaskedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(myFreelancerWalletProvider);
    final payoutsAsync = ref.watch(myPayoutsProvider);
    final actionState = ref.watch(payoutActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Withdrawal Center',
      subtitle: 'Sandbox payout requests and withdrawal history.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.freelancerWallet),
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
          label: const Text('Wallet'),
        ),
      ],
      child: SingleChildScrollView(
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
              final payouts = payoutsAsync.value ?? const <PayoutModel>[];
              final active = payouts
                  .where((payout) => PayoutStatus.isActive(payout.status))
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SandboxNotice(),
                  const SizedBox(height: 18),
                  _PayoutMetrics(wallet: safeWallet, activePayouts: active),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 980;
                      final form = _WithdrawPanel(
                        wallet: safeWallet,
                        amountController: _amountController,
                        destinationNameController: _destinationNameController,
                        destinationMaskedController:
                            _destinationMaskedController,
                        notesController: _notesController,
                        destinationType: _destinationType,
                        isBusy: actionState.isLoading,
                        onDestinationChanged: (value) =>
                            setState(() => _destinationType = value),
                        onSubmit: () => _requestPayout(safeWallet),
                      );
                      final history = _PayoutHistoryPanel(
                        payouts: payouts,
                        isBusy: actionState.isLoading,
                        onCancel: _cancelPayout,
                      );
                      if (!isWide) {
                        return Column(
                          children: [
                            form,
                            const SizedBox(height: 18),
                            _UpcomingPayoutPanel(payouts: active),
                            const SizedBox(height: 18),
                            history,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: form),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              children: [
                                _UpcomingPayoutPanel(payouts: active),
                                const SizedBox(height: 18),
                                history,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _requestPayout(FreelancerWalletModel wallet) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request sandbox payout?'),
        content: Text(
          'This will reserve ${_money(amount, wallet.currency)} from your available balance. No real money will move.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Request Payout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(payoutActionProvider.notifier);
    final ok = await notifier.requestPayout(
      amount: amount,
      destinationType: _destinationType,
      destinationName: _destinationNameController.text,
      destinationMasked: _destinationMaskedController.text,
      notes: _notesController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sandbox payout request submitted for admin review.'
              : notifier.errorMessage ?? 'Unable to request payout.',
        ),
      ),
    );
    if (ok) {
      _amountController.clear();
      _destinationNameController.clear();
      _destinationMaskedController.clear();
      _notesController.clear();
    }
  }

  Future<void> _cancelPayout(String payoutId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel payout request?'),
        content: const Text(
          'Reserved sandbox funds will return to your available balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Payout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(payoutActionProvider.notifier);
    final ok = await notifier.cancelPayout(payoutId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Payout request cancelled and funds returned.'
              : notifier.errorMessage ?? 'Unable to cancel payout.',
        ),
      ),
    );
  }
}

class _PayoutMetrics extends StatelessWidget {
  const _PayoutMetrics({required this.wallet, required this.activePayouts});

  final FreelancerWalletModel wallet;
  final List<PayoutModel> activePayouts;

  @override
  Widget build(BuildContext context) {
    final activeAmount = activePayouts.fold<double>(
      0,
      (sum, payout) => sum + payout.amount,
    );
    return ResponsiveGrid(
      minChildWidth: 210,
      children: [
        MetricCard(
          title: 'Available',
          value: _money(wallet.availableBalance, wallet.currency),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Pending Earnings',
          value: _money(wallet.pendingBalance, wallet.currency),
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Escrow',
          value: _money(wallet.escrowBalance, wallet.currency),
          icon: Icons.lock_clock_rounded,
          color: AppColors.freelancerSecondary,
        ),
        MetricCard(
          title: 'Pending Payout',
          value: _money(activeAmount, wallet.currency),
          icon: Icons.outbound_rounded,
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _WithdrawPanel extends StatelessWidget {
  const _WithdrawPanel({
    required this.wallet,
    required this.amountController,
    required this.destinationNameController,
    required this.destinationMaskedController,
    required this.notesController,
    required this.destinationType,
    required this.isBusy,
    required this.onDestinationChanged,
    required this.onSubmit,
  });

  final FreelancerWalletModel wallet;
  final TextEditingController amountController;
  final TextEditingController destinationNameController;
  final TextEditingController destinationMaskedController;
  final TextEditingController notesController;
  final String destinationType;
  final bool isBusy;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canWithdraw =
        wallet.availableBalance >= 25 &&
        (wallet.activePayoutId ?? '').trim().isEmpty;
    return _Panel(
      title: 'Withdraw Funds',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Only available balance can be withdrawn. Pending and escrow balances stay locked until cleared.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${wallet.currency} ',
              helperText: 'Minimum 25, maximum 10,000 sandbox units.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: destinationType,
            decoration: const InputDecoration(labelText: 'Destination Type'),
            items: PayoutDestinationType.values
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: isBusy ? null : (value) => onDestinationChanged(value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: destinationNameController,
            decoration: const InputDecoration(
              labelText: 'Destination Name',
              hintText: 'e.g. Sandbox Bank Account',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: destinationMaskedController,
            decoration: const InputDecoration(
              labelText: 'Masked Destination',
              hintText: 'e.g. **** 4242 or demo@example.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Optional sandbox payout note',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: canWithdraw && !isBusy ? onSubmit : null,
            icon: const Icon(Icons.outbound_rounded, size: 18),
            label: Text(
              (wallet.activePayoutId ?? '').trim().isNotEmpty
                  ? 'Active payout already pending'
                  : 'Request Sandbox Payout',
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingPayoutPanel extends StatelessWidget {
  const _UpcomingPayoutPanel({required this.payouts});

  final List<PayoutModel> payouts;

  @override
  Widget build(BuildContext context) {
    if (payouts.isEmpty) {
      return const _Panel(
        title: 'Upcoming Payout',
        child: DashboardEmptyState(
          icon: Icons.outbound_rounded,
          title: 'No payout in progress',
          message: 'Your next sandbox payout request will appear here.',
        ),
      );
    }
    return _Panel(
      title: 'Upcoming Payout',
      child: _PayoutTile(payout: payouts.first),
    );
  }
}

class _PayoutHistoryPanel extends StatelessWidget {
  const _PayoutHistoryPanel({
    required this.payouts,
    required this.isBusy,
    required this.onCancel,
  });

  final List<PayoutModel> payouts;
  final bool isBusy;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Withdrawal History',
      child: payouts.isEmpty
          ? const DashboardEmptyState(
              icon: Icons.history_rounded,
              title: 'No payout history',
              message: 'Sandbox withdrawal requests will appear here.',
            )
          : Column(
              children: payouts
                  .take(10)
                  .map(
                    (payout) => _PayoutTile(
                      payout: payout,
                      isBusy: isBusy,
                      onCancel: onCancel,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout, this.isBusy = false, this.onCancel});

  final PayoutModel payout;
  final bool isBusy;
  final ValueChanged<String>? onCancel;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _statusColor(payout.status).withValues(alpha: 0.12),
        child: Icon(Icons.outbound_rounded, color: _statusColor(payout.status)),
      ),
      title: Text(_money(payout.amount, payout.currency)),
      subtitle: Text(
        '${payout.destinationType} - ${payout.destinationMasked}\n${formatter.format(payout.requestedAt)}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusPill(status: payout.status),
          if (payout.status == PayoutStatus.pendingApproval && onCancel != null)
            TextButton(
              onPressed: isBusy ? null : () => onCancel!(payout.payoutId),
              child: const Text('Cancel'),
            ),
        ],
      ),
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
              'Sandbox payout mode - no real gateway, bank transfer, or money movement is connected.',
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Chip(
      label: Text(_statusLabel(status)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.18)),
    );
  }
}

Color _statusColor(String status) {
  return switch (PayoutStatus.normalize(status)) {
    PayoutStatus.paid => AppColors.success,
    PayoutStatus.rejected => AppColors.error,
    PayoutStatus.cancelled => AppColors.textTertiary,
    PayoutStatus.processing => AppColors.info,
    PayoutStatus.approved => AppColors.freelancerPrimary,
    _ => AppColors.warning,
  };
}

String _statusLabel(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
