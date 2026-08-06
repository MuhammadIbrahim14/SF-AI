import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/invoice_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/invoice_provider.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../shared/widgets/customer_workspace_shell.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';
import 'invoice_list_screen.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    required this.scope,
  });

  final String invoiceId;
  final InvoiceListScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceProvider(invoiceId));
    final exportState = ref.watch(pdfExportActionProvider);
    final content = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: invoiceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Invoice unavailable',
            message: error.toString(),
          ),
          data: (invoice) {
            if (invoice == null) {
              return const DashboardEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Invoice not found',
                message: 'This invoice does not exist or is not accessible.',
              );
            }
            return _InvoiceDetail(
              invoice: invoice,
              isBusy: exportState.isLoading,
              onDownload: () => _exportInvoice(context, ref, invoice),
              onPrint: () => _printInvoice(context, ref, invoice),
              onOrder: () => context.pushNamed(
                RouteNames.serviceOrderDetail,
                pathParameters: {'orderId': invoice.orderId},
              ),
            );
          },
        ),
      ),
    );

    final title = 'Invoice Detail';
    final subtitle = 'Immutable sandbox billing record.';
    return switch (scope) {
      InvoiceListScope.client => CustomerWorkspaceShell(child: content),
      InvoiceListScope.freelancer => RoleFixedHeaderPage(
        role: UserRole.freelancer,
        title: title,
        subtitle: subtitle,
        showBackButton: true,
        child: content,
      ),
      InvoiceListScope.admin => AdminControlScaffold(
        title: title,
        subtitle: subtitle,
        currentPath: RoutePaths.adminInvoices,
        body: content,
      ),
    };
  }

  Future<void> _exportInvoice(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel invoice,
  ) async {
    final notifier = ref.read(pdfExportActionProvider.notifier);
    final ok = await notifier.exportInvoice(invoice);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Invoice PDF ready.' : notifier.errorMessage ?? 'Export failed.',
        ),
      ),
    );
  }

  Future<void> _printInvoice(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel invoice,
  ) async {
    final notifier = ref.read(pdfExportActionProvider.notifier);
    final ok = await notifier.printInvoice(invoice);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Print dialog opened.'
              : notifier.errorMessage ?? 'Print failed.',
        ),
      ),
    );
  }
}

class _InvoiceDetail extends StatelessWidget {
  const _InvoiceDetail({
    required this.invoice,
    required this.isBusy,
    required this.onDownload,
    required this.onPrint,
    required this.onOrder,
  });

  final InvoiceModel invoice;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onPrint;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy - h:mm a');
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final summary = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(invoice: invoice),
              const SizedBox(height: 18),
              _SandboxNotice(),
              const SizedBox(height: 18),
              _DetailRow('Invoice ID', invoice.invoiceId),
              _DetailRow('Invoice number', invoice.invoiceNumber),
              _DetailRow('Order ID', invoice.orderId),
              _DetailRow('Type', InvoiceType.label(invoice.type)),
              _DetailRow('Status', invoice.status.toUpperCase()),
              _DetailRow('Issued', formatter.format(invoice.issuedAt)),
              _DetailRow(
                'Paid',
                invoice.paidAt == null
                    ? 'Pending'
                    : formatter.format(invoice.paidAt!),
              ),
              _DetailRow('Verification code', invoice.verificationCode),
            ],
          ),
        );
        final billing = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Billing Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              _DetailRow('Client', invoice.clientName),
              _DetailRow('Freelancer', invoice.freelancerName),
              _DetailRow('Service', invoice.serviceTitle),
              const Divider(height: 28),
              _MoneyRow('Subtotal', invoice.subtotal, invoice.currency),
              _MoneyRow('Platform fee', invoice.platformFee, invoice.currency),
              _MoneyRow('Tax', invoice.taxAmount, invoice.currency),
              const Divider(height: 28),
              _MoneyRow(
                'Total',
                invoice.totalAmount,
                invoice.currency,
                emphasized: true,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: isBusy ? null : onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download / Share PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onPrint,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOrder,
                    icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                    label: const Text('View Order'),
                  ),
                ],
              ),
            ],
          ),
        );
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 18), billing],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: summary),
            const SizedBox(width: 18),
            Expanded(child: billing),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice});

  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(invoice.type);
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(Icons.receipt_long_rounded, color: color, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                InvoiceType.label(invoice.type),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${invoice.invoiceNumber} - ${invoice.platformName}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _SandboxNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.warning.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.science_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sandbox billing record. It does not represent a real payment, payout, or tax invoice.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value.trim().isEmpty ? 'Not available' : value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(
    this.label,
    this.value,
    this.currency, {
    this.emphasized = false,
  });

  final String label;
  final double value;
  final String currency;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_money(value, currency), style: style),
        ],
      ),
    );
  }
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
