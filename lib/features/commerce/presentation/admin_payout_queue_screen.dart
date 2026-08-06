import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/payout_model.dart';
import '../../../providers/payout_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';

class AdminPayoutQueueScreen extends ConsumerStatefulWidget {
  const AdminPayoutQueueScreen({super.key});

  @override
  ConsumerState<AdminPayoutQueueScreen> createState() =>
      _AdminPayoutQueueScreenState();
}

class _AdminPayoutQueueScreenState
    extends ConsumerState<AdminPayoutQueueScreen> {
  String _status = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final payoutsAsync = ref.watch(adminPayoutsProvider);
    final actionState = ref.watch(payoutActionProvider);

    return AdminControlScaffold(
      title: 'Payout Queue',
      subtitle: 'Review and simulate freelancer sandbox withdrawals.',
      currentPath: RoutePaths.adminPayouts,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: payoutsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DashboardEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Payouts unavailable',
              message: error.toString(),
            ),
            data: (payouts) {
              final filtered = payouts.where(_matches).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PayoutMetrics(payouts: payouts),
                  const SizedBox(height: 18),
                  _Filters(
                    selected: _status,
                    payouts: payouts,
                    onStatusChanged: (value) => setState(() => _status = value),
                    onQueryChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 18),
                  if (payouts.isEmpty)
                    const DashboardEmptyState(
                      icon: Icons.outbound_rounded,
                      title: 'No payout requests yet',
                      message:
                          'Freelancer withdrawal requests will appear here.',
                    )
                  else if (filtered.isEmpty)
                    DashboardEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No payouts match',
                      message: 'Try another status or search term.',
                      actionLabel: 'Clear Filters',
                      onAction: () => setState(() {
                        _status = 'all';
                        _query = '';
                      }),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _PayoutAdminTile(
                        payout: filtered[index],
                        isBusy: actionState.isLoading,
                        onApprove: () =>
                            _runAction(filtered[index].payoutId, 'approve'),
                        onReject: () => _reject(filtered[index].payoutId),
                        onProcess: () =>
                            _runAction(filtered[index].payoutId, 'process'),
                        onPaid: () =>
                            _runAction(filtered[index].payoutId, 'paid'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matches(PayoutModel payout) {
    final statusMatches = _status == 'all' || payout.status == _status;
    final q = _query.trim().toLowerCase();
    final queryMatches =
        q.isEmpty ||
        payout.payoutId.toLowerCase().contains(q) ||
        payout.freelancerId.toLowerCase().contains(q) ||
        payout.destinationName.toLowerCase().contains(q) ||
        payout.destinationMasked.toLowerCase().contains(q);
    return statusMatches && queryMatches;
  }

  Future<void> _reject(String payoutId) async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject sandbox payout?'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain why this payout was rejected',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null || !mounted) return;
    final notifier = ref.read(payoutActionProvider.notifier);
    final ok = await notifier.rejectPayout(payoutId, notes);
    if (!mounted) return;
    _showResult(
      ok,
      notifier.errorMessage,
      'Payout rejected and funds returned.',
    );
  }

  Future<void> _runAction(String payoutId, String action) async {
    final notifier = ref.read(payoutActionProvider.notifier);
    final ok = switch (action) {
      'approve' => await notifier.approvePayout(payoutId),
      'process' => await notifier.processPayout(payoutId),
      'paid' => await notifier.markPayoutPaid(payoutId),
      _ => false,
    };
    if (!mounted) return;
    final message = switch (action) {
      'approve' => 'Payout approved.',
      'process' => 'Payout moved to processing.',
      'paid' => 'Sandbox payout marked paid.',
      _ => 'Payout updated.',
    };
    _showResult(ok, notifier.errorMessage, message);
  }

  void _showResult(bool ok, String? error, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? success : error ?? 'Payout action failed.')),
    );
  }
}

class _PayoutMetrics extends StatelessWidget {
  const _PayoutMetrics({required this.payouts});

  final List<PayoutModel> payouts;

  @override
  Widget build(BuildContext context) {
    final currency = payouts.isEmpty ? 'USD' : payouts.first.currency;
    final pending = payouts
        .where((payout) => payout.status == PayoutStatus.pendingApproval)
        .length;
    final activeAmount = payouts
        .where((payout) => PayoutStatus.isActive(payout.status))
        .fold<double>(0, (sum, payout) => sum + payout.amount);
    final paidAmount = payouts
        .where((payout) => payout.status == PayoutStatus.paid)
        .fold<double>(0, (sum, payout) => sum + payout.amount);
    return ResponsiveGrid(
      minChildWidth: 210,
      children: [
        MetricCard(
          title: 'Payout Requests',
          value: '${payouts.length}',
          icon: Icons.outbound_rounded,
          color: AppColors.adminPrimary,
        ),
        MetricCard(
          title: 'Pending Review',
          value: '$pending',
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Active Amount',
          value: _money(activeAmount, currency),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Sandbox Paid',
          value: _money(paidAmount, currency),
          icon: Icons.verified_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selected,
    required this.payouts,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  final String selected;
  final List<PayoutModel> payouts;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'all',
      PayoutStatus.pendingApproval,
      PayoutStatus.approved,
      PayoutStatus.processing,
      PayoutStatus.paid,
      PayoutStatus.rejected,
      PayoutStatus.cancelled,
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search payout, freelancer, destination',
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((status) {
              final count = status == 'all'
                  ? payouts.length
                  : payouts.where((payout) => payout.status == status).length;
              return ChoiceChip(
                selected: selected == status,
                label: Text('${_statusLabel(status)} ($count)'),
                onSelected: (_) => onStatusChanged(status),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PayoutAdminTile extends StatelessWidget {
  const _PayoutAdminTile({
    required this.payout,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
    required this.onProcess,
    required this.onPaid,
  });

  final PayoutModel payout;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onProcess;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy - h:mm a');
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(
                    payout.status,
                  ).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.outbound_rounded,
                    color: _statusColor(payout.status),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _money(payout.amount, payout.currency),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${payout.freelancerId} - ${payout.destinationType} - ${payout.destinationMasked}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: payout.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Requested ${formatter.format(payout.requestedAt)}',
                  ),
                ),
                Chip(label: Text(payout.destinationName)),
                if (payout.notes.trim().isNotEmpty)
                  Chip(label: Text(payout.notes)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (payout.status == PayoutStatus.pendingApproval)
                  FilledButton.icon(
                    onPressed: isBusy ? null : onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                if (PayoutStatus.isActive(payout.status))
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                if (payout.status == PayoutStatus.approved)
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onProcess,
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Process'),
                  ),
                if (payout.status == PayoutStatus.processing ||
                    payout.status == PayoutStatus.approved)
                  FilledButton.icon(
                    onPressed: isBusy ? null : onPaid,
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Mark Paid'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
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
    PayoutStatus.approved => AppColors.adminPrimary,
    _ => AppColors.warning,
  };
}

String _statusLabel(String value) {
  if (value == 'all') return 'All';
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
