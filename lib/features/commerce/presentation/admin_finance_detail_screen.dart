import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../providers/admin_finance_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';

class AdminFinanceDetailScreen extends ConsumerWidget {
  const AdminFinanceDetailScreen({
    super.key,
    required this.type,
    required this.id,
  });

  final String type;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(adminFinanceSnapshotProvider);
    return AdminControlScaffold(
      title: '${_label(type)} Detail',
      subtitle: 'Read-only sandbox finance record.',
      currentPath: RoutePaths.adminFinanceCenter,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.adminFinanceCenter),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Finance Center'),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: snapshotAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DashboardEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Detail unavailable',
              message: error.toString(),
            ),
            data: (snapshot) {
              final rows = _rowsFor(snapshot, type, id);
              if (rows.isEmpty) {
                return DashboardEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Record not found',
                  message: 'No $type record exists for $id.',
                );
              }
              return Card(
                elevation: 0,
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows
                        .map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    row.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Expanded(child: SelectableText(row.$2)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

List<(String, String)> _rowsFor(dynamic snapshot, String type, String id) {
  final date = DateFormat('MMM d, yyyy h:mm a');
  switch (type) {
    case 'transaction':
      final item = snapshot.transactions
          .where((record) => record.transactionId == id)
          .firstOrNull;
      if (item == null) return const [];
      return [
        ('Transaction ID', item.transactionId),
        ('Type', _label(item.type)),
        ('Status', _label(item.status)),
        ('Amount', '${item.currency} ${item.amount.toStringAsFixed(2)}'),
        ('Order ID', item.orderId),
        ('User ID', item.userId),
        ('Description', item.description),
        ('Created', date.format(item.createdAt)),
      ];
    case 'wallet':
      final item = snapshot.wallets
          .where((record) => record.walletId == id)
          .firstOrNull;
      if (item == null) return const [];
      return [
        ('Wallet ID', item.walletId),
        ('Freelancer ID', item.freelancerId),
        (
          'Available',
          '${item.currency} ${item.availableBalance.toStringAsFixed(2)}',
        ),
        (
          'Pending',
          '${item.currency} ${item.pendingBalance.toStringAsFixed(2)}',
        ),
        ('Escrow', '${item.currency} ${item.escrowBalance.toStringAsFixed(2)}'),
        (
          'Pending Payout',
          '${item.currency} ${item.pendingPayoutBalance.toStringAsFixed(2)}',
        ),
        ('Updated', date.format(item.updatedAt)),
      ];
    case 'refund':
      final item = snapshot.refunds
          .where((record) => record.refundId == id)
          .firstOrNull;
      if (item == null) return const [];
      return [
        ('Refund ID', item.refundId),
        ('Order ID', item.orderId),
        ('Service', item.serviceTitle),
        ('Status', _label(item.status)),
        ('Amount', '${item.currency} ${item.amount.toStringAsFixed(2)}'),
        ('Reason', item.reason),
        ('Created', date.format(item.createdAt)),
      ];
    case 'dispute':
      final item = snapshot.disputes
          .where((record) => record.disputeId == id)
          .firstOrNull;
      if (item == null) return const [];
      return [
        ('Dispute ID', item.disputeId),
        ('Order ID', item.orderId),
        ('Service', item.serviceTitle),
        ('Status', _label(item.status)),
        (
          'Decision',
          item.decision == null ? 'Pending' : _label(item.decision!),
        ),
        ('Reason', item.reason),
        ('Evidence Count', '${item.evidence.length}'),
        ('Created', date.format(item.createdAt)),
      ];
    case 'escrow':
      final item = snapshot.escrows
          .where((record) => record.escrowId == id)
          .firstOrNull;
      if (item == null) return const [];
      return [
        ('Escrow ID', item.escrowId),
        ('Order ID', item.orderId),
        ('Status', _label(item.status)),
        ('Amount', '${item.currency} ${item.amount.toStringAsFixed(2)}'),
        ('Client ID', item.clientId),
        ('Freelancer ID', item.freelancerId),
        ('Reason', item.holdReason),
        ('Started', date.format(item.holdStartedAt)),
        ('Expected Release', date.format(item.expectedReleaseAt)),
      ];
    default:
      return const [];
  }
}

String _label(String value) {
  if (value.isEmpty) return 'Unknown';
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}
