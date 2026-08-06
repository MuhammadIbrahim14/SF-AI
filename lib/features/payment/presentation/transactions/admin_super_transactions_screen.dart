import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/user_role.dart';
import '../../../../shared/widgets/dashboard_empty_state.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../providers/payment_providers.dart';

/// Admin / super-admin console for every SkillForge Demo Gateway payment intent.
class AdminSuperTransactionsScreen extends ConsumerStatefulWidget {
  const AdminSuperTransactionsScreen({super.key});

  @override
  ConsumerState<AdminSuperTransactionsScreen> createState() =>
      _AdminSuperTransactionsScreenState();
}

class _AdminSuperTransactionsScreenState
    extends ConsumerState<AdminSuperTransactionsScreen> {
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final intentsAsync = ref.watch(adminAllPaymentIntentsProvider);
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.admin,
      title: 'Super Transactions',
      subtitle: 'Full Demo Gateway ledger — fees, methods, roles, and statuses.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(RouteNames.adminDashboard);
      },
      scrollable: false,
      child: intentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: DashboardEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load ledger',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(adminAllPaymentIntentsProvider),
          ),
        ),
        data: (intents) {
          final filtered = intents.where((i) {
            if (_statusFilter != 'all' && i.status != _statusFilter) {
              return false;
            }
            if (_typeFilter != 'all' && i.type != _typeFilter) return false;
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final hay =
                  '${i.description} ${i.userId} ${i.intentId} ${i.type}'
                      .toLowerCase();
              if (!hay.contains(q)) return false;
            }
            return true;
          }).toList();

          final paid = intents.where((i) => i.isPaid);
          final platformFees = paid.fold<double>(
            0,
            (sum, i) => sum + i.platformFee,
          );
          final volume = paid.fold<double>(0, (sum, i) => sum + i.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Kpi(
                      label: 'Paid volume',
                      value: 'PKR ${volume.toStringAsFixed(2)}',
                      color: AppColors.primary,
                    ),
                    _Kpi(
                      label: 'Platform fees',
                      value: 'PKR ${platformFees.toStringAsFixed(2)}',
                      color: AppColors.success,
                    ),
                    _Kpi(
                      label: 'Intents',
                      value: '${intents.length}',
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search user, intent, description…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('Paid'),
                              ),
                              DropdownMenuItem(
                                value: 'failed',
                                child: Text('Failed'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _statusFilter = v ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _typeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All types'),
                              ),
                              DropdownMenuItem(
                                value: 'plan',
                                child: Text('Plan'),
                              ),
                              DropdownMenuItem(
                                value: 'credit_pack',
                                child: Text('Credit pack'),
                              ),
                              DropdownMenuItem(
                                value: 'course',
                                child: Text('Course'),
                              ),
                              DropdownMenuItem(
                                value: 'commerce_order',
                                child: Text('Commerce'),
                              ),
                              DropdownMenuItem(
                                value: 'wallet_topup',
                                child: Text('Wallet'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _typeFilter = v ?? 'all'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching transactions',
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final intent = filtered[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                intent.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${intent.userId}\n'
                                '${intent.type} · ${intent.paymentMethod} · '
                                'fee ${intent.currency} ${intent.platformFee.toStringAsFixed(2)}\n'
                                '${intent.intentId}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${intent.currency} ${intent.amount.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    intent.status.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: intent.isPaid
                                          ? AppColors.success
                                          : intent.isFailed
                                              ? AppColors.error
                                              : AppColors.warning,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
