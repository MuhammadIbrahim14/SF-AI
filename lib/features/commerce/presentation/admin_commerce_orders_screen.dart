import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_wallet_model.dart';
import '../../../models/service_order_model.dart';
import '../../../providers/commerce_order_provider.dart';
import '../../../providers/freelancer_wallet_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';

class AdminCommerceOrdersScreen extends ConsumerStatefulWidget {
  const AdminCommerceOrdersScreen({super.key});

  @override
  ConsumerState<AdminCommerceOrdersScreen> createState() =>
      _AdminCommerceOrdersScreenState();
}

class _AdminCommerceOrdersScreenState
    extends ConsumerState<AdminCommerceOrdersScreen> {
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminServiceOrdersProvider);
    final wallets = ref.watch(adminFreelancerWalletsProvider).value ?? const [];
    return AdminControlScaffold(
      title: 'Commerce Orders',
      subtitle: 'Sandbox service orders and future escrow readiness.',
      currentPath: RoutePaths.adminCommerceOrders,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.adminInvoices),
          icon: const Icon(Icons.description_rounded, size: 18),
          label: const Text('Invoices'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.adminPayouts),
          icon: const Icon(Icons.outbound_rounded, size: 18),
          label: const Text('Payouts'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.adminFinanceCenter),
          icon: const Icon(Icons.analytics_rounded, size: 18),
          label: const Text('Finance Center'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(RouteNames.adminResolutionDesk),
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('Resolution Desk'),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DashboardEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Orders unavailable',
              message: error.toString(),
            ),
            data: (orders) {
              final filtered = _status == 'all'
                  ? orders
                  : orders
                        .where((order) => order.orderStatus == _status)
                        .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminMetrics(orders: orders, wallets: wallets),
                  const SizedBox(height: 18),
                  _AdminFilters(
                    selected: _status,
                    orders: orders,
                    onChanged: (value) => setState(() => _status = value),
                  ),
                  const SizedBox(height: 18),
                  if (orders.isEmpty)
                    const DashboardEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No sandbox orders yet',
                      message:
                          'Orders will appear here after clients create them from accepted service requests.',
                    )
                  else if (filtered.isEmpty)
                    DashboardEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No orders in this status',
                      message: 'Try another order status filter.',
                      actionLabel: 'Show All',
                      onAction: () => setState(() => _status = 'all'),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return _AdminOrderTile(order: order);
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
}

class _AdminMetrics extends StatelessWidget {
  const _AdminMetrics({required this.orders, required this.wallets});

  final List<ServiceOrderModel> orders;
  final List<FreelancerWalletModel> wallets;

  @override
  Widget build(BuildContext context) {
    final totalValue = orders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final platformFees = orders.fold<double>(
      0,
      (sum, order) => sum + order.platformFee,
    );
    final sandboxPayments = orders.where(
      (order) => order.paymentStatus == ServiceOrderPaymentStatus.demoPaid,
    );
    final heldEscrow = orders
        .where((order) => order.escrowStatus == ServiceOrderEscrowStatus.held)
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
    final currency = orders.isEmpty ? 'USD' : orders.first.currency;
    final pendingBalances = wallets.fold<double>(
      0,
      (sum, wallet) => sum + wallet.pendingBalance,
    );
    final availableBalances = wallets.fold<double>(
      0,
      (sum, wallet) => sum + wallet.availableBalance,
    );
    return ResponsiveGrid(
      minChildWidth: 210,
      children: [
        MetricCard(
          title: 'Sandbox Orders',
          value: '${orders.length}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.adminPrimary,
        ),
        MetricCard(
          title: 'Total Order Value',
          value: _money(totalValue, currency),
          icon: Icons.payments_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Sandbox Payments',
          value: '${sandboxPayments.length}',
          icon: Icons.verified_user_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Held Escrow',
          value: _money(heldEscrow, currency),
          icon: Icons.lock_clock_rounded,
          color: AppColors.freelancerSecondary,
        ),
        MetricCard(
          title: 'Platform Fee Total',
          value: _money(platformFees, currency),
          icon: Icons.percent_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Pending Wallets',
          value: _money(pendingBalances, currency),
          icon: Icons.pending_actions_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Available Wallets',
          value: _money(availableBalances, currency),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _AdminFilters extends StatelessWidget {
  const _AdminFilters({
    required this.selected,
    required this.orders,
    required this.onChanged,
  });

  final String selected;
  final List<ServiceOrderModel> orders;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'all',
      ServiceOrderStatus.pending,
      ServiceOrderStatus.active,
      ServiceOrderStatus.delivered,
      ServiceOrderStatus.completed,
      ServiceOrderStatus.cancelled,
      ServiceOrderStatus.disputed,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final count = status == 'all'
            ? orders.length
            : orders.where((order) => order.orderStatus == status).length;
        return ChoiceChip(
          selected: selected == status,
          label: Text('${_label(status)} ($count)'),
          onSelected: (_) => onChanged(status),
        );
      }).toList(),
    );
  }
}

class _AdminOrderTile extends StatelessWidget {
  const _AdminOrderTile({required this.order});

  final ServiceOrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy');
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.pushNamed(
          RouteNames.serviceOrderDetail,
          pathParameters: {'orderId': order.orderId},
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.adminPrimary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.adminPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.orderNumber} - ${order.clientName} to ${order.freelancerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            _money(order.totalAmount, order.currency),
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Fee ${_money(order.platformFee, order.currency)}',
                          ),
                        ),
                        Chip(label: Text(_label(order.paymentStatus))),
                        Chip(
                          label: Text('Escrow ${_label(order.escrowStatus)}'),
                        ),
                        Chip(label: Text(formatter.format(order.createdAt))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _label(String value) {
  if (value == 'all') return 'All';
  return value[0].toUpperCase() + value.substring(1);
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
