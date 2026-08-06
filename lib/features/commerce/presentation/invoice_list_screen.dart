import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/invoice_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/invoice_provider.dart';
import '../../../shared/widgets/customer_workspace_shell.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';

enum InvoiceListScope { client, freelancer, admin }

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key, required this.scope});

  final InvoiceListScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = switch (scope) {
      InvoiceListScope.client => ref.watch(myClientInvoicesProvider),
      InvoiceListScope.freelancer => ref.watch(myFreelancerInvoicesProvider),
      InvoiceListScope.admin => ref.watch(adminInvoicesProvider),
    };
    final title = switch (scope) {
      InvoiceListScope.client => 'My Invoices',
      InvoiceListScope.freelancer => 'Freelancer Invoices',
      InvoiceListScope.admin => 'Invoice Center',
    };
    final subtitle = switch (scope) {
      InvoiceListScope.client => 'Receipts for your sandbox service orders.',
      InvoiceListScope.freelancer =>
        'Invoices and billing proof for completed sandbox work.',
      InvoiceListScope.admin => 'Read-only platform billing records.',
    };
    final content = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: invoicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Invoices unavailable',
            message: error.toString(),
          ),
          data: (invoices) =>
              _InvoiceListContent(invoices: invoices, scope: scope),
        ),
      ),
    );

    return switch (scope) {
      InvoiceListScope.client => CustomerWorkspaceShell(child: content),
      InvoiceListScope.freelancer => RoleFixedHeaderPage(
        role: UserRole.freelancer,
        title: title,
        subtitle: subtitle,
        showBackButton: true,
        actions: [
          OutlinedButton.icon(
            onPressed: () =>
                context.pushNamed(RouteNames.freelancerServiceOrders),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Orders'),
          ),
        ],
        child: content,
      ),
      InvoiceListScope.admin => AdminControlScaffold(
        title: title,
        subtitle: subtitle,
        currentPath: RoutePaths.adminInvoices,
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(RouteNames.adminCommerceOrders),
            icon: const Icon(Icons.shopping_bag_rounded, size: 18),
            label: const Text('Orders'),
          ),
        ],
        body: content,
      ),
    };
  }
}

class _InvoiceListContent extends StatelessWidget {
  const _InvoiceListContent({required this.invoices, required this.scope});

  final List<InvoiceModel> invoices;
  final InvoiceListScope scope;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return DashboardEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No invoices yet',
        message:
            'Invoices appear automatically after sandbox payment is completed.',
        actionLabel: scope == InvoiceListScope.freelancer
            ? 'View Orders'
            : scope == InvoiceListScope.admin
            ? 'View Commerce Orders'
            : 'View Orders',
        onAction: () => _goToOrders(context, scope),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InvoiceMetrics(invoices: invoices),
        const SizedBox(height: 18),
        _SandboxNotice(),
        const SizedBox(height: 18),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: invoices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _InvoiceTile(invoice: invoices[index], scope: scope),
        ),
      ],
    );
  }

  void _goToOrders(BuildContext context, InvoiceListScope scope) {
    switch (scope) {
      case InvoiceListScope.client:
        context.goNamed(RouteNames.serviceOrders);
      case InvoiceListScope.freelancer:
        context.goNamed(RouteNames.freelancerServiceOrders);
      case InvoiceListScope.admin:
        context.goNamed(RouteNames.adminCommerceOrders);
    }
  }
}

class _InvoiceMetrics extends StatelessWidget {
  const _InvoiceMetrics({required this.invoices});

  final List<InvoiceModel> invoices;

  @override
  Widget build(BuildContext context) {
    final currency = invoices.first.currency;
    final total = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final paid = invoices.where((invoice) => invoice.status == 'paid').length;
    final fees = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.platformFee,
    );
    return ResponsiveGrid(
      minChildWidth: 210,
      children: [
        MetricCard(
          title: 'Invoices',
          value: '${invoices.length}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Paid Records',
          value: '$paid',
          icon: Icons.verified_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Total Amount',
          value: _money(total, currency),
          icon: Icons.payments_rounded,
          color: AppColors.freelancerPrimary,
        ),
        MetricCard(
          title: 'Platform Fees',
          value: _money(fees, currency),
          icon: Icons.percent_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.scope});

  final InvoiceModel invoice;
  final InvoiceListScope scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy');
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        onTap: () => context.pushNamed(
          _detailRouteName(scope),
          pathParameters: {'invoiceId': invoice.invoiceId},
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _typeColor(
                  invoice.type,
                ).withValues(alpha: 0.12),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: _typeColor(invoice.type),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      InvoiceType.label(invoice.type),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${invoice.invoiceNumber} - ${invoice.serviceTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            _money(invoice.totalAmount, invoice.currency),
                          ),
                        ),
                        Chip(label: Text(invoice.status.toUpperCase())),
                        Chip(label: Text(formatter.format(invoice.issuedAt))),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
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
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.science_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sandbox billing mode - invoices are professional records for demo marketplace payments only.',
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

String _detailRouteName(InvoiceListScope scope) {
  return switch (scope) {
    InvoiceListScope.client => RouteNames.invoiceDetail,
    InvoiceListScope.freelancer => RouteNames.freelancerInvoiceDetail,
    InvoiceListScope.admin => RouteNames.adminInvoiceDetail,
  };
}

Color _typeColor(String type) {
  return switch (InvoiceType.normalize(type)) {
    InvoiceType.freelancerInvoice => AppColors.freelancerPrimary,
    InvoiceType.platformCommissionInvoice => AppColors.warning,
    _ => AppColors.info,
  };
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
