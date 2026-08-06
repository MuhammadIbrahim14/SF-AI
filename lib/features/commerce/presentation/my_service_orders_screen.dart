import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_order_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/commerce_order_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class MyServiceOrdersScreen extends ConsumerWidget {
  const MyServiceOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = UserRole.fromString(user?.primaryRole) ?? UserRole.student;
    final ordersAsync = ref.watch(myServiceOrdersProvider);

    return RoleFixedHeaderPage(
      role: role,
      title: 'My Orders',
      subtitle: 'Sandbox commerce orders. No real payment is processed.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.serviceRequests),
          icon: const Icon(Icons.handshake_rounded, size: 18),
          label: const Text('Service Requests'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.invoices),
          icon: const Icon(Icons.description_rounded, size: 18),
          label: const Text('Invoices'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Orders unavailable',
            message: error.toString(),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return DashboardEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No sandbox orders yet',
                message:
                    'Create an order from an accepted service request, then complete the sandbox checkout to hold escrow.',
                actionLabel: 'View Requests',
                onAction: () => context.goNamed(RouteNames.serviceRequests),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrderMetrics(orders: orders),
                const SizedBox(height: 18),
                _SandboxNotice(),
                const SizedBox(height: 18),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _OrderCard(
                    order: orders[index],
                    counterpart: orders[index].freelancerName,
                    earningsMode: false,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class FreelancerServiceOrdersScreen extends ConsumerWidget {
  const FreelancerServiceOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(freelancerServiceOrdersProvider);
    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Freelancer Orders',
      subtitle: 'Sandbox order pipeline for accepted service requests.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              context.goNamed(RouteNames.freelancerServiceRequests),
          icon: const Icon(Icons.handshake_rounded, size: 18),
          label: const Text('Requests'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.freelancerInvoices),
          icon: const Icon(Icons.description_rounded, size: 18),
          label: const Text('Invoices'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Orders unavailable',
            message: error.toString(),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return DashboardEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No sandbox orders yet',
                message:
                    'Orders appear after clients convert accepted service requests.',
                actionLabel: 'View Requests',
                onAction: () =>
                    context.goNamed(RouteNames.freelancerServiceRequests),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrderMetrics(orders: orders),
                const SizedBox(height: 18),
                _SandboxNotice(),
                const SizedBox(height: 18),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _OrderCard(
                    order: orders[index],
                    counterpart: orders[index].clientName,
                    earningsMode: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderMetrics extends StatelessWidget {
  const _OrderMetrics({required this.orders});

  final List<ServiceOrderModel> orders;

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
    final heldEscrow = orders
        .where((order) => order.escrowStatus == ServiceOrderEscrowStatus.held)
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
    return ResponsiveGrid(
      minChildWidth: 190,
      children: [
        MetricCard(
          title: 'Orders',
          value: '${orders.length}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.freelancerPrimary,
        ),
        MetricCard(
          title: 'Total Value',
          value: _money(totalValue, orders.first.currency),
          icon: Icons.payments_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Held Escrow',
          value: _money(heldEscrow, orders.first.currency),
          icon: Icons.lock_clock_rounded,
          color: AppColors.freelancerSecondary,
        ),
        MetricCard(
          title: 'Platform Fees',
          value: _money(platformFees, orders.first.currency),
          icon: Icons.percent_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.counterpart,
    required this.earningsMode,
  });

  final ServiceOrderModel order;
  final String counterpart;
  final bool earningsMode;

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
        borderRadius: BorderRadius.circular(24),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: _orderLegalStatusLabel(order),
                    color: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.orderNumber} - $counterpart',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.payments_rounded,
                    label: earningsMode
                        ? 'Earnings ${_money(order.freelancerEarnings, order.currency)}'
                        : 'Total ${_money(order.totalAmount, order.currency)}',
                    color: AppColors.success,
                  ),
                  _InfoChip(
                    icon: Icons.percent_rounded,
                    label: 'Fee ${_money(order.platformFee, order.currency)}',
                    color: AppColors.warning,
                  ),
                  _InfoChip(
                    icon: Icons.lock_clock_rounded,
                    label: _label(order.escrowStatus),
                    color: AppColors.freelancerSecondary,
                  ),
                  _InfoChip(
                    icon: Icons.verified_user_rounded,
                    label: _label(order.paymentStatus),
                    color:
                        order.paymentStatus == ServiceOrderPaymentStatus.unpaid
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: formatter.format(order.createdAt),
                    color: AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SandboxNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.warning.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.science_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sandbox commerce mode - no real payment has been processed yet.',
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.16)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}

String _label(String value) {
  if (value.isEmpty) return value;
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _orderLegalStatusLabel(ServiceOrderModel order) {
  if (order.paymentStatus == ServiceOrderPaymentStatus.refunded ||
      order.escrowStatus == ServiceOrderEscrowStatus.refunded) {
    return 'Refunded';
  }
  if (order.paymentStatus == ServiceOrderPaymentStatus.partiallyRefunded ||
      order.escrowStatus == ServiceOrderEscrowStatus.split ||
      order.orderStatus == ServiceOrderStatus.splitSettled) {
    return 'Split Settled';
  }
  if (order.paymentStatus == ServiceOrderPaymentStatus.released ||
      order.escrowStatus == ServiceOrderEscrowStatus.released ||
      order.orderStatus == ServiceOrderStatus.completed) {
    return 'Completed';
  }
  return _label(order.orderStatus);
}
