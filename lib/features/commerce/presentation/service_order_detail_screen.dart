import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/services/cloudinary_delivery_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/invoice_model.dart';
import '../../../models/resolution_case_model.dart';
import '../../../models/service_order_delivery_model.dart';
import '../../../models/service_order_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/commerce_order_provider.dart';
import '../../../providers/customer_wallet_provider.dart';
import '../../../providers/invoice_provider.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../providers/resolution_v2_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../../marketplace_ai/widgets/marketplace_ai_notes_draft_dialog.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/presentation/checkout/payfast_checkout_sheet.dart';

class ServiceOrderDetailScreen extends ConsumerWidget {
  const ServiceOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = UserRole.fromString(user?.primaryRole) ?? UserRole.student;
    final orderAsync = ref.watch(serviceOrderProvider(orderId));
    final deliveriesAsync = ref.watch(orderDeliveriesProvider(orderId));
    final invoicesAsync = ref.watch(orderInvoicesProvider(orderId));
    final customerWalletAsync = ref.watch(myCustomerWalletProvider);
    final actionState = ref.watch(commerceOrderActionProvider);
    final walletActionState = ref.watch(customerWalletActionProvider);
    final invoiceActionState = ref.watch(invoiceActionProvider);
    final pdfActionState = ref.watch(pdfExportActionProvider);

    return RoleFixedHeaderPage(
      role: role,
      title: 'Sandbox Order',
      subtitle: 'Checkout, escrow hold, and payment timeline.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(
          role == UserRole.freelancer
              ? RouteNames.freelancerServiceOrders
              : RouteNames.serviceOrders,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Order unavailable',
            message: error.toString(),
          ),
          data: (order) {
            final canView =
                user != null &&
                (order?.clientId == user.uid ||
                    order?.freelancerId == user.uid ||
                    (user.isAdmin || user.isSystemOwner));
            if (order == null || !canView) {
              return const DashboardEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Order not found',
                message:
                    'This order does not exist or belongs to another account.',
              );
            }
            return _OrderDetail(
              order: order,
              deliveries:
                  deliveriesAsync.value ?? const <ServiceOrderDeliveryModel>[],
              invoices: invoicesAsync.value ?? const <InvoiceModel>[],
              role: role,
              isBusy:
                  actionState.isLoading ||
                  walletActionState.isLoading ||
                  invoiceActionState.isLoading ||
                  pdfActionState.isLoading,
              canPay: order.canCancel && order.clientId == user.uid,
              canCancel: order.canCancel && order.clientId == user.uid,
              walletBalance: customerWalletAsync.value?.availableBalance ?? 0,
              walletLoading: customerWalletAsync.isLoading,
              walletError: customerWalletAsync.error?.toString(),
              onWalletPay: () => _payWithWallet(context, ref, order),
              onAddWalletBalance: () => context.go(RoutePaths.customerWallet),
              onPay: () => _showCheckout(context, ref, order),
              onCompleteAndRelease: () =>
                  _completeOrderAndRelease(context, ref, order),
              onStartWork: () => _startWork(context, ref, order),
              onSubmitDelivery: () => _submitDelivery(context, ref, order),
              onCancel: () => _cancelOrder(context, ref, order),
              onGenerateInvoices: () => _generateInvoices(context, ref, order),
              onViewInvoice: (invoice) => _viewInvoice(context, role, invoice),
              onDownloadInvoice: (invoice) =>
                  _downloadInvoice(context, ref, invoice),
            );
          },
        ),
      ),
    );
  }

  Future<void> _generateInvoices(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    final notifier = ref.read(invoiceActionProvider.notifier);
    final ok = await notifier.generateForOrder(order.orderId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Invoices are ready for this order.'
              : notifier.errorMessage ?? 'Invoice generation failed.',
        ),
      ),
    );
  }

  Future<void> _startWork(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
        order.escrowStatus != ServiceOrderEscrowStatus.held) {
      await _blockingDialog(
        context,
        title: 'Escrow not funded yet',
        message:
            'You can start work only after the client completes sandbox payment and escrow is held.',
      );
      return;
    }
    final notifier = ref.read(commerceOrderActionProvider.notifier);
    final ok = await notifier.startWork(order.orderId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Work started. You can submit delivery when ready.'
              : notifier.errorMessage ?? 'Unable to start work.',
        ),
      ),
    );
    if (ok) {
      ref.invalidate(serviceOrderProvider(order.orderId));
    }
  }

  Future<void> _submitDelivery(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
        order.escrowStatus != ServiceOrderEscrowStatus.held) {
      await _blockingDialog(
        context,
        title: 'Escrow not funded',
        message: 'Delivery can be submitted only while escrow is held.',
      );
      return;
    }
    if (order.orderStatus != ServiceOrderStatus.inProgress) {
      await _blockingDialog(
        context,
        title: 'Start work first',
        message: 'Start the order before submitting your final delivery.',
      );
      return;
    }

    final messageController = TextEditingController(
      text: MarketplaceAiPendingApply.takeNoteBodyFor('delivery') ?? '',
    );
    final linksController = TextEditingController();
    final uploadService = CloudinaryDeliveryUploadService();
    final submitted = await showDialog<_DeliveryDraft>(
      context: context,
      builder: (context) {
        var uploading = false;
        final uploadedAttachments = <Map<String, dynamic>>[];
        String? uploadError;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Submit Delivery'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Upload delivery files or paste public review links. Files use Cloudinary unsigned upload; no API secret is stored in the app.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: messageController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Delivery message',
                        hintText:
                            'Explain what you delivered and how to review it.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              await MarketplaceAiNotesDraftDialog.show(
                                context: context,
                                taskType: MarketplaceAiTaskType
                                    .freelancerDeliveryNoteBuilder,
                                title: 'Draft delivery note with AI',
                                applyLabel: 'Apply to Delivery Message',
                                initialPrompt:
                                    'Draft a delivery handoff note for order '
                                    '${order.orderId} / ${order.serviceTitle}.',
                                safeAppContext: {
                                  'orderId': order.orderId,
                                  'serviceTitle': order.serviceTitle,
                                },
                                onApplyBody: (body) {
                                  messageController.text = body;
                                  setDialogState(() {});
                                },
                              );
                            },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Draft message with AI'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              setDialogState(() {
                                uploading = true;
                                uploadError = null;
                              });
                              try {
                                final files = await uploadService
                                    .pickDeliveryFiles();
                                if (files.isEmpty) {
                                  setDialogState(() => uploading = false);
                                  return;
                                }
                                final attachments = await uploadService
                                    .uploadDeliveryFiles(files);
                                setDialogState(() {
                                  uploadedAttachments
                                    ..clear()
                                    ..addAll(attachments);
                                  uploading = false;
                                });
                              } on CloudinaryDeliveryUploadException catch (e) {
                                if (context.mounted &&
                                    e.message ==
                                        'Upload service is not configured yet.') {
                                  await _blockingDialog(
                                    context,
                                    title: 'Upload service not configured',
                                    message: e.message,
                                  );
                                }
                                setDialogState(() {
                                  uploadError = e.message;
                                  uploading = false;
                                });
                              } catch (e) {
                                setDialogState(() {
                                  uploadError =
                                      'Delivery upload failed. Try links instead.';
                                  uploading = false;
                                });
                              }
                            },
                      icon: uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        uploading
                            ? 'Uploading...'
                            : uploadedAttachments.isEmpty
                            ? 'Upload Delivery Files'
                            : 'Replace Uploaded Files',
                      ),
                    ),
                    if (uploadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        uploadError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (uploadedAttachments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...uploadedAttachments.map(_AttachmentLine.new),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: linksController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Attachment URLs',
                        hintText: 'One URL per line',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: uploading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: uploading
                    ? null
                    : () {
                        final links = linksController.text
                            .split(RegExp(r'[\n,]'))
                            .map((item) => item.trim())
                            .where((item) => item.isNotEmpty)
                            .toList();
                        Navigator.of(context).pop(
                          _DeliveryDraft(
                            messageController.text.trim(),
                            links,
                            List<Map<String, dynamic>>.from(
                              uploadedAttachments,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Submit Delivery'),
              ),
            ],
          ),
        );
      },
    );
    messageController.dispose();
    linksController.dispose();
    uploadService.dispose();
    if (submitted == null || !context.mounted) return;
    if (submitted.message.isEmpty &&
        submitted.attachmentUrls.isEmpty &&
        submitted.attachmentMetadata.isEmpty) {
      await _blockingDialog(
        context,
        title: 'Delivery needs content',
        message: 'Add a delivery message or at least one attachment.',
      );
      return;
    }

    final notifier = ref.read(commerceOrderActionProvider.notifier);
    final ok = await notifier.submitDelivery(
      orderId: order.orderId,
      message: submitted.message,
      attachmentUrls: submitted.attachmentUrls,
      attachmentMetadata: submitted.attachmentMetadata,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Delivery submitted. Client review is now unlocked.'
              : notifier.errorMessage ?? 'Unable to submit delivery.',
        ),
      ),
    );
    if (ok) {
      ref.invalidate(serviceOrderProvider(order.orderId));
      ref.invalidate(orderDeliveriesProvider(order.orderId));
    }
  }

  Future<void> _completeOrderAndRelease(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    final deliveryReady =
        order.orderStatus == ServiceOrderStatus.delivered &&
        order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
        (order.lastDeliveryId ?? '').trim().isNotEmpty;
    if (!deliveryReady) {
      await _blockingDialog(
        context,
        title: 'Delivery required before release',
        message:
            'The freelancer must submit delivery before you can complete the order and release escrow.',
      );
      return;
    }
    final earnings = order.freelancerEarnings > 0
        ? order.freelancerEarnings
        : order.totalAmount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete order and release escrow?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will release ${_money(earnings, order.currency)} demo funds to ${order.freelancerName}.',
            ),
            const SizedBox(height: 12),
            Text('Escrow held: ${_money(order.totalAmount, order.currency)}'),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be repeated. Use the Resolution Center instead if there is a dispute or refund request.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Release Escrow'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(customerWalletActionProvider.notifier);
    final ok = await notifier.completeOrderAndReleaseEscrow(order.orderId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Order completed. Escrow released to freelancer.'
              : notifier.errorMessage ?? 'Unable to complete order.',
        ),
      ),
    );
    if (ok) {
      ref.invalidate(serviceOrderProvider(order.orderId));
      ref.invalidate(myCustomerWalletProvider);
      ref.invalidate(myCustomerWalletTransactionsProvider);
      ref.invalidate(orderResolutionCasesProvider(order.orderId));
    }
  }

  Future<void> _downloadInvoice(
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

  void _viewInvoice(BuildContext context, UserRole role, InvoiceModel invoice) {
    final route = switch (role) {
      UserRole.freelancer => RouteNames.freelancerInvoiceDetail,
      UserRole.admin || UserRole.superAdmin => RouteNames.adminInvoiceDetail,
      _ => RouteNames.invoiceDetail,
    };
    context.pushNamed(route, pathParameters: {'invoiceId': invoice.invoiceId});
  }

  Future<void> _cancelOrder(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel sandbox order?'),
        content: const Text(
          'Only unpaid pending sandbox orders can be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final notifier = ref.read(commerceOrderActionProvider.notifier);
    final ok = await notifier.cancelOrder(order.orderId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sandbox order cancelled.'
              : notifier.errorMessage ?? 'Cancel failed.',
        ),
      ),
    );
  }

  Future<void> _payWithWallet(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay with SkillForge Wallet?'),
        content: Text(
          'This will move ${_money(order.totalAmount, order.currency)} demo funds into escrow. No real money is processed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pay from Wallet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(customerWalletActionProvider.notifier);
    final ok = await notifier.payOrderFromWallet(order.orderId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Payment successful. Funds are now held in escrow.'
              : notifier.errorMessage ?? 'Wallet payment failed.',
        ),
      ),
    );
    if (ok) {
      ref.invalidate(serviceOrderProvider(order.orderId));
      ref.invalidate(myCustomerWalletProvider);
      ref.invalidate(myCustomerWalletTransactionsProvider);
      await _showPaymentSuccess(context);
    }
  }

  Future<void> _showCheckout(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderModel order,
  ) async {
    final result = await showPayFastCheckoutSheet(
      context: context,
      ref: ref,
      type: 'commerce_order',
      amount: order.totalAmount,
      currency: order.currency.isNotEmpty ? order.currency : 'PKR',
      description: 'Service order: ${order.serviceTitle}',
      role: 'customer',
      orderId: order.orderId,
      metadata: {
        'serviceRequestId': order.serviceRequestId,
        'freelancerId': order.freelancerId,
        'serviceTitle': order.serviceTitle,
      },
      title: 'Pay for service',
    );
    if (result == null || !context.mounted) return;
    if (PaymentStatus.isSuccess(result.status)) {
      ref.invalidate(serviceOrderProvider(order.orderId));
      await _showPaymentSuccess(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _showPaymentSuccess(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.success.withValues(alpha: 0.12),
          child: const Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 34,
          ),
        ),
        title: const Text('Payment complete'),
        content: const Text(
          'Escrow is now held for this order. The freelancer can see the paid status and expected release window.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('View Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockingDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.warning.withValues(alpha: 0.12),
          child: const Icon(Icons.lock_clock_rounded, color: AppColors.warning),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryDraft {
  const _DeliveryDraft(
    this.message,
    this.attachmentUrls,
    this.attachmentMetadata,
  );

  final String message;
  final List<String> attachmentUrls;
  final List<Map<String, dynamic>> attachmentMetadata;
}

class _PaymentMethod {
  const _PaymentMethod({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _PaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? AppColors.freelancerPrimary
        : theme.colorScheme.outline;
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Material(
        color: selected
            ? AppColors.freelancerPrimary.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Row(
              children: [
                Icon(method.icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.order,
    required this.deliveries,
    required this.invoices,
    required this.role,
    required this.isBusy,
    required this.canPay,
    required this.canCancel,
    required this.walletBalance,
    required this.walletLoading,
    required this.walletError,
    required this.onWalletPay,
    required this.onAddWalletBalance,
    required this.onPay,
    required this.onCompleteAndRelease,
    required this.onStartWork,
    required this.onSubmitDelivery,
    required this.onCancel,
    required this.onGenerateInvoices,
    required this.onViewInvoice,
    required this.onDownloadInvoice,
  });

  final ServiceOrderModel order;
  final List<ServiceOrderDeliveryModel> deliveries;
  final List<InvoiceModel> invoices;
  final UserRole role;
  final bool isBusy;
  final bool canPay;
  final bool canCancel;
  final double walletBalance;
  final bool walletLoading;
  final String? walletError;
  final VoidCallback onWalletPay;
  final VoidCallback onAddWalletBalance;
  final VoidCallback onPay;
  final VoidCallback onCompleteAndRelease;
  final VoidCallback onStartWork;
  final VoidCallback onSubmitDelivery;
  final VoidCallback onCancel;
  final VoidCallback onGenerateInvoices;
  final ValueChanged<InvoiceModel> onViewInvoice;
  final ValueChanged<InvoiceModel> onDownloadInvoice;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy - h:mm a');
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;
        final summary = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SandboxNotice(),
              const SizedBox(height: 18),
              _Header(order: order),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.payment_rounded,
                    label: 'Payment ${_label(order.paymentStatus)}',
                    color:
                        order.paymentStatus == ServiceOrderPaymentStatus.unpaid
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  _InfoChip(
                    icon: Icons.lock_clock_rounded,
                    label: 'Escrow ${_label(order.escrowStatus)}',
                    color: AppColors.freelancerSecondary,
                  ),
                  _InfoChip(
                    icon: Icons.task_alt_rounded,
                    label: 'Order ${_orderLegalStatusLabel(order)}',
                    color: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _PaymentSummary(order: order, formatter: formatter),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  role == UserRole.freelancer
                      ? RouteNames.freelancerAiAssistant
                      : RouteNames.customerAiAssistant,
                  queryParameters: {
                    'task': role == UserRole.freelancer
                        ? 'deliveryNote'
                        : 'deliveryChecklist',
                    'orderId': order.orderId,
                  },
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  role == UserRole.freelancer
                      ? 'Draft Delivery Note with AI'
                      : 'Review Delivery with AI',
                ),
              ),
              const SizedBox(height: 18),
              _DeliveryPanel(
                order: order,
                deliveries: deliveries,
                role: role,
                busy: isBusy,
                formatter: formatter,
                onStartWork: onStartWork,
                onSubmitDelivery: onSubmitDelivery,
              ),
              const SizedBox(height: 18),
              _Timeline(order: order, formatter: formatter),
              const SizedBox(height: 18),
              _ResolutionPanel(order: order),
            ],
          ),
        );
        final money = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Amount Breakdown',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _MoneyRow('Subtotal', order.subtotal, order.currency),
              _MoneyRow(
                'Platform fee (10%)',
                order.platformFee,
                order.currency,
              ),
              _MoneyRow('Tax total', order.taxTotal, order.currency),
              const Divider(height: 28),
              _MoneyRow(
                'Total amount',
                order.totalAmount,
                order.currency,
                emphasized: true,
              ),
              _MoneyRow(
                'Freelancer earnings',
                order.freelancerEarnings,
                order.currency,
                emphasized: true,
              ),
              const SizedBox(height: 18),
              _FinanceFacts(order: order, formatter: formatter),
              const SizedBox(height: 18),
              _InvoicePanel(
                invoices: invoices,
                role: role,
                order: order,
                isBusy: isBusy,
                onGenerate: onGenerateInvoices,
                onView: onViewInvoice,
                onDownload: onDownloadInvoice,
              ),
              const SizedBox(height: 18),
              _CompletionReleasePanel(
                order: order,
                role: role,
                busy: isBusy,
                onCompleteAndRelease: onCompleteAndRelease,
              ),
              const SizedBox(height: 18),
              if (canPay)
                _WalletPaymentPanel(
                  order: order,
                  balance: walletBalance,
                  loading: walletLoading,
                  error: walletError,
                  busy: isBusy,
                  onPay: onWalletPay,
                  onAddBalance: onAddWalletBalance,
                  onLegacyCheckout: onPay,
                )
              else
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.verified_user_rounded, size: 18),
                  label: const Text('Payment Locked in Escrow'),
                ),
              if (canCancel) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Sandbox Order'),
                ),
              ],
            ],
          ),
        );
        if (!isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 18), money],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: summary),
            const SizedBox(width: 18),
            Expanded(child: money),
          ],
        );
      },
    );
  }
}

class _DeliveryPanel extends StatelessWidget {
  const _DeliveryPanel({
    required this.order,
    required this.deliveries,
    required this.role,
    required this.busy,
    required this.formatter,
    required this.onStartWork,
    required this.onSubmitDelivery,
  });

  final ServiceOrderModel order;
  final List<ServiceOrderDeliveryModel> deliveries;
  final UserRole role;
  final bool busy;
  final DateFormat formatter;
  final VoidCallback onStartWork;
  final VoidCallback onSubmitDelivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final funded =
        order.paymentStatus == ServiceOrderPaymentStatus.demoPaid &&
        order.escrowStatus == ServiceOrderEscrowStatus.held;
    final started =
        order.orderStatus == ServiceOrderStatus.inProgress ||
        order.orderStatus == ServiceOrderStatus.delivered ||
        order.orderStatus == ServiceOrderStatus.completed;
    final delivered =
        order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
        (order.lastDeliveryId ?? '').trim().isNotEmpty;
    final latestDelivery = deliveries.isEmpty ? null : deliveries.first;
    final isFreelancer = role == UserRole.freelancer;

    final statusColor = delivered
        ? AppColors.success
        : started
        ? AppColors.info
        : funded
        ? AppColors.freelancerPrimary
        : AppColors.warning;
    final statusText = delivered
        ? 'Delivery Submitted'
        : started
        ? 'Work In Progress'
        : funded
        ? 'Escrow Funded'
        : 'Waiting for Escrow';

    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delivery & Review',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusPill(label: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            delivered
                ? 'The client can review the submitted delivery and release escrow, request a revision, open a dispute, or request a refund.'
                : funded
                ? 'Escrow is held. The freelancer can start work and submit delivery from this order.'
                : 'The freelancer cannot start or submit work until the client funds escrow.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _DetailRow('Delivery status', _label(order.deliveryStatus)),
          _DetailRow(
            'Due date',
            order.dueDate == null
                ? 'Not scheduled'
                : formatter.format(order.dueDate!),
          ),
          _DetailRow(
            'Work started',
            order.workStartedAt == null
                ? 'Not started'
                : formatter.format(order.workStartedAt!),
          ),
          _DetailRow(
            'Review window',
            order.reviewDueAt == null
                ? 'Opens after delivery'
                : 'Until ${formatter.format(order.reviewDueAt!)}',
          ),
          if (latestDelivery != null) ...[
            const Divider(height: 24),
            Text(
              'Latest Delivery',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              latestDelivery.message.trim().isEmpty
                  ? 'No message added.'
                  : latestDelivery.message,
            ),
            if (latestDelivery.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...latestDelivery.attachments.take(4).map(_AttachmentLine.new),
              if (latestDelivery.attachments.length > 4)
                Text(
                  '+${latestDelivery.attachments.length - 4} more attachment links',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ],
          if (isFreelancer) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      !busy &&
                          funded &&
                          order.orderStatus == ServiceOrderStatus.active
                      ? onStartWork
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start Work'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      !busy &&
                          order.orderStatus == ServiceOrderStatus.inProgress
                      ? onSubmitDelivery
                      : null,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Submit Delivery'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentLine extends StatelessWidget {
  const _AttachmentLine(this.attachment);

  final Map<String, dynamic> attachment;

  @override
  Widget build(BuildContext context) {
    final fileName = attachment['fileName']?.toString().trim();
    final url = attachment['url']?.toString().trim() ?? '';
    final label = fileName == null || fileName.isEmpty ? url : fileName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionReleasePanel extends ConsumerWidget {
  const _CompletionReleasePanel({
    required this.order,
    required this.role,
    required this.busy,
    required this.onCompleteAndRelease,
  });

  final ServiceOrderModel order;
  final UserRole role;
  final bool busy;
  final VoidCallback onCompleteAndRelease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final cases =
        ref.watch(orderResolutionCasesProvider(order.orderId)).value ??
        const <ResolutionCaseModel>[];
    final isCustomer = user?.uid == order.clientId;
    if (!isCustomer || role == UserRole.freelancer) {
      return const SizedBox.shrink();
    }

    final pendingChecklist = MarketplaceAiPendingApply.acceptanceChecklist;
    MarketplaceAcceptanceChecklistDraft? checklist;
    if (pendingChecklist != null) {
      checklist = MarketplaceAcceptanceChecklistDraft.fromMap(pendingChecklist);
    }

    final walletFunded = order.sandboxPaymentMethod == 'SkillForge Wallet';
    final escrowHeld =
        order.paymentStatus == ServiceOrderPaymentStatus.demoPaid &&
        order.escrowStatus == ServiceOrderEscrowStatus.held;
    final released =
        order.orderStatus == ServiceOrderStatus.completed ||
        order.escrowStatus == ServiceOrderEscrowStatus.released ||
        order.paymentStatus == ServiceOrderPaymentStatus.released;
    final refunded =
        order.paymentStatus == ServiceOrderPaymentStatus.refunded ||
        order.escrowStatus == ServiceOrderEscrowStatus.refunded ||
        order.orderStatus == ServiceOrderStatus.cancelled;
    final splitSettled =
        order.paymentStatus == ServiceOrderPaymentStatus.partiallyRefunded ||
        order.escrowStatus == ServiceOrderEscrowStatus.split ||
        order.orderStatus == ServiceOrderStatus.splitSettled;
    final activeCase = cases.any((item) {
      final isFinancialCase =
          item.type == ResolutionCaseType.dispute ||
          item.type == ResolutionCaseType.refund;
      return isFinancialCase && item.isOpen;
    });
    final deliveryReady =
        order.orderStatus == ServiceOrderStatus.delivered &&
        order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
        (order.lastDeliveryId ?? '').trim().isNotEmpty;
    final canRelease =
        walletFunded && escrowHeld && deliveryReady && !released && !activeCase;

    if (!walletFunded && !released && !refunded && !splitSettled) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final statusColor = refunded
        ? AppColors.error
        : splitSettled
        ? AppColors.warning
        : released
        ? AppColors.success
        : activeCase
        ? AppColors.warning
        : !deliveryReady
        ? AppColors.info
        : AppColors.freelancerPrimary;
    final title = refunded
        ? 'Order refunded'
        : splitSettled
        ? 'Split settlement completed'
        : released
        ? 'Order completed'
        : activeCase
        ? 'Resolution case active'
        : !deliveryReady
        ? 'Waiting for delivery'
        : 'Complete order';
    final message = refunded
        ? 'Escrow has been refunded to the client. This order should not wait for delivery anymore.'
        : splitSettled
        ? 'Escrow was split between client refund and freelancer release.'
        : released
        ? 'Escrow has already been released for this order.'
        : activeCase
        ? 'Resolve the active dispute/refund case before releasing escrow.'
        : !deliveryReady
        ? 'The freelancer must submit delivery before escrow can be released.'
        : 'Release demo escrow to the freelancer when you are satisfied with the work.';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor.withValues(alpha: 0.34)),
      ),
      color: statusColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  released ? Icons.verified_rounded : Icons.lock_open_rounded,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              'Freelancer earnings',
              _money(
                order.freelancerEarnings > 0
                    ? order.freelancerEarnings
                    : order.totalAmount,
                order.currency,
              ),
            ),
            _DetailRow(
              'Escrow held',
              _money(order.totalAmount, order.currency),
            ),
            _DetailRow(
              'Delivery gate',
              deliveryReady ? 'Delivery submitted' : 'Delivery required',
            ),
            if (checklist != null && checklist.items.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                checklist.title.isEmpty
                    ? 'Acceptance checklist (advisory)'
                    : checklist.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Advisory only — does not complete the order or release escrow.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _AcceptanceChecklistBox(draft: checklist),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: canRelease && !busy ? onCompleteAndRelease : null,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.task_alt_rounded, size: 18),
              label: Text(
                released
                    ? 'Escrow Released'
                    : 'Complete Order & Release Escrow',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptanceChecklistBox extends StatefulWidget {
  const _AcceptanceChecklistBox({required this.draft});

  final MarketplaceAcceptanceChecklistDraft draft;

  @override
  State<_AcceptanceChecklistBox> createState() =>
      _AcceptanceChecklistBoxState();
}

class _AcceptanceChecklistBoxState extends State<_AcceptanceChecklistBox> {
  late final List<MarketplaceChecklistItem> _items = List.of(widget.draft.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _items[i].checked,
            title: Text(_items[i].label),
            subtitle: _items[i].hint.trim().isEmpty
                ? null
                : Text(_items[i].hint),
            onChanged: (value) {
              setState(() {
                _items[i] = _items[i].copyWith(checked: value == true);
              });
            },
          ),
      ],
    );
  }
}

class _WalletPaymentPanel extends StatelessWidget {
  const _WalletPaymentPanel({
    required this.order,
    required this.balance,
    required this.loading,
    required this.error,
    required this.busy,
    required this.onPay,
    required this.onAddBalance,
    required this.onLegacyCheckout,
  });

  final ServiceOrderModel order;
  final double balance;
  final bool loading;
  final String? error;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onAddBalance;
  final VoidCallback onLegacyCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = (error ?? '').trim().isNotEmpty;
    final sufficient = balance >= order.totalAmount;
    final canPay = !busy && !loading && !hasError && sufficient;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pay with SkillForge Wallet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Demo funds only — no real money is processed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow('Wallet balance', _money(balance, order.currency)),
            _DetailRow(
              'Order total',
              _money(order.totalAmount, order.currency),
            ),
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (hasError) ...[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            ] else if (!loading && !sufficient) ...[
              const SizedBox(height: 10),
              Text(
                'Insufficient wallet balance. Add demo balance first.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: canPay ? onPay : null,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Pay with Wallet'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onAddBalance,
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Add Demo Balance'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: busy ? null : onLegacyCheckout,
              child: const Text('Use legacy sandbox checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionPanel extends ConsumerWidget {
  const _ResolutionPanel({required this.order});

  final ServiceOrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final cases =
        ref.watch(orderResolutionCasesProvider(order.orderId)).value ??
        const <ResolutionCaseModel>[];
    final busy = ref.watch(resolutionV2ActionProvider).isLoading;
    final isClient = user?.uid == order.clientId;
    final isFreelancer = user?.uid == order.freelancerId;
    final isAdmin = user?.isAdmin == true || user?.isSystemOwner == true;
    final hasFundedEscrow =
        order.paymentStatus == ServiceOrderPaymentStatus.demoPaid &&
        (order.escrowStatus == ServiceOrderEscrowStatus.held ||
            order.escrowStatus == ServiceOrderEscrowStatus.disputed);
    final deliveryReady =
        order.orderStatus == ServiceOrderStatus.delivered &&
        order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
        (order.lastDeliveryId ?? '').trim().isNotEmpty;
    final canUseResolution =
        (isClient || isFreelancer) &&
        hasFundedEscrow &&
        order.orderStatus != ServiceOrderStatus.completed &&
        order.orderStatus != ServiceOrderStatus.cancelled &&
        order.orderStatus != ServiceOrderStatus.splitSettled &&
        order.paymentStatus != ServiceOrderPaymentStatus.refunded;
    final activeDispute = cases.any(
      (item) => item.type == ResolutionCaseType.dispute && item.isOpen,
    );
    final pendingRefund = cases.any(
      (item) => item.type == ResolutionCaseType.refund && item.isOpen,
    );
    final activeRevision = cases.any(
      (item) => item.type == ResolutionCaseType.revision && item.isOpen,
    );

    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resolution Center',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusPill(
                label: activeDispute ? 'Dispute Open' : 'Clear',
                color: activeDispute ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasFundedEscrow
                ? deliveryReady
                      ? 'Delivery has been submitted. Revision, dispute, and refund protections are available before escrow release.'
                      : 'Delivery has not been submitted yet. Refund protection is available; revision and dispute unlock after delivery.'
                : 'Resolution actions unlock after sandbox payment funds escrow.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isClient && canUseResolution && deliveryReady)
                OutlinedButton.icon(
                  onPressed: busy || activeRevision || activeDispute
                      ? null
                      : () => _resolutionTextAction(
                          context,
                          ref,
                          title: 'Request revision',
                          label: 'Request',
                          hint: 'Explain exactly what needs to be revised.',
                          aiTaskType:
                              MarketplaceAiTaskType.customerRevisionRequestDraft,
                          pendingNoteKind: 'revision',
                          onSubmit: (text) => ref
                              .read(resolutionV2ActionProvider.notifier)
                              .createRevision(order.orderId, text),
                        ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Request Revision'),
                ),
              if ((isClient || isFreelancer) &&
                  canUseResolution &&
                  deliveryReady)
                OutlinedButton.icon(
                  onPressed: busy || activeDispute
                      ? null
                      : () => _resolutionTextAction(
                          context,
                          ref,
                          title: 'Open dispute',
                          label: 'Open Dispute',
                          hint:
                              'Describe the issue and what outcome you expect.',
                          aiTaskType: MarketplaceAiTaskType
                              .customerDisputeExplanationDraft,
                          pendingNoteKind: 'dispute',
                          onSubmit: (text) => ref
                              .read(resolutionV2ActionProvider.notifier)
                              .createDispute(order.orderId, text),
                        ),
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('Open Dispute'),
                ),
              if (isClient &&
                  canUseResolution &&
                  order.paymentStatus == ServiceOrderPaymentStatus.demoPaid)
                OutlinedButton.icon(
                  onPressed: busy || pendingRefund
                      ? null
                      : () => _resolutionTextAction(
                          context,
                          ref,
                          title: 'Request refund',
                          label: 'Request Refund',
                          hint:
                              'Explain why you are requesting a sandbox refund.',
                          aiTaskType:
                              MarketplaceAiTaskType.customerRefundRequestDraft,
                          pendingNoteKind: 'refund',
                          onSubmit: (text) => ref
                              .read(resolutionV2ActionProvider.notifier)
                              .createRefund(order.orderId, text),
                        ),
                  icon: const Icon(
                    Icons.replay_circle_filled_rounded,
                    size: 18,
                  ),
                  label: const Text('Request Refund'),
                ),
              if (isClient)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.goNamed(RouteNames.customerResolutions),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('My Cases'),
                ),
              if (isFreelancer)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.goNamed(RouteNames.freelancerResolutions),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Resolution Queue'),
                ),
              if (isAdmin)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.goNamed(RouteNames.adminResolutionDesk),
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 18,
                  ),
                  label: const Text('Admin Desk'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (cases.isEmpty)
            Text(
              'No V2 resolution cases for this order.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            ...cases.take(5).map((item) {
              return _ResolutionTimelineTile(
                icon: _caseIcon(item),
                title: '${_label(item.type)}: ${_label(item.status)}',
                subtitle: item.description.isEmpty
                    ? item.reason
                    : item.description,
                date: item.updatedAt,
                color: _caseColor(item),
                trailing: _caseTrailing(context, ref, item, busy, isClient),
              );
            }),
          ],
        ],
      ),
    );
  }
}

Widget? _caseTrailing(
  BuildContext context,
  WidgetRef ref,
  ResolutionCaseModel item,
  bool busy,
  bool isClient,
) {
  if (isClient &&
      item.type == ResolutionCaseType.revision &&
      item.status == ResolutionCaseStatus.revisionSubmitted) {
    return TextButton(
      onPressed: busy
          ? null
          : () => _resolutionTextAction(
              context,
              ref,
              title: 'Complete revision',
              label: 'Complete',
              hint: 'Add an optional acceptance note.',
              onSubmit: (text) => ref
                  .read(resolutionV2ActionProvider.notifier)
                  .completeRevision(item.caseId, text),
            ),
      child: const Text('Complete'),
    );
  }
  if (item.isOpen) {
    return TextButton(
      onPressed: busy
          ? null
          : () => _resolutionTextAction(
              context,
              ref,
              title: 'Add evidence',
              label: 'Add',
              hint: 'Add evidence text or future attachment notes.',
              aiTaskType:
                  MarketplaceAiTaskType.freelancerDisputeEvidenceSummary,
              pendingNoteKind: 'evidence',
              onSubmit: (text) => ref
                  .read(resolutionV2ActionProvider.notifier)
                  .addEvidence(item.caseId, text),
            ),
      child: const Text('Add Evidence'),
    );
  }
  return null;
}

IconData _caseIcon(ResolutionCaseModel item) {
  return switch (item.type) {
    ResolutionCaseType.revision => Icons.edit_note_rounded,
    ResolutionCaseType.refund => Icons.replay_circle_filled_rounded,
    _ => Icons.gavel_rounded,
  };
}

Color _caseColor(ResolutionCaseModel item) {
  return switch (item.type) {
    ResolutionCaseType.revision => AppColors.freelancerPrimary,
    ResolutionCaseType.refund => AppColors.error,
    _ => AppColors.warning,
  };
}

class _ResolutionTimelineTile extends StatelessWidget {
  const _ResolutionTimelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime date;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, h:mm a');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  formatter.format(date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Future<void> _resolutionTextAction(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String label,
  required String hint,
  required Future<bool> Function(String text) onSubmit,
  String? aiTaskType,
  String? pendingNoteKind,
}) async {
  final pendingKind = pendingNoteKind ?? '';
  final pending = pendingKind.isEmpty
      ? null
      : MarketplaceAiPendingApply.takeNoteBodyFor(pendingKind);
  final controller = TextEditingController(text: pending ?? '');
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          if (aiTaskType != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await MarketplaceAiNotesDraftDialog.show(
                  context: context,
                  taskType: aiTaskType,
                  title: 'Draft notes with AI',
                  applyLabel: 'Apply to Notes',
                  role: aiTaskType.startsWith('customer')
                      ? 'customer'
                      : 'freelancer',
                  accountType: aiTaskType.startsWith('customer')
                      ? 'customer'
                      : 'professional',
                  accent: aiTaskType.startsWith('customer')
                      ? AppColors.studentPrimary
                      : AppColors.freelancerPrimary,
                  initialPrompt: hint,
                  onApplyBody: (body) {
                    controller.text = body;
                  },
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Draft with AI'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(label),
        ),
      ],
    ),
  );
  controller.dispose();
  if (text == null || !context.mounted) return;
  final ok = await onSubmit(text);
  if (!context.mounted) return;
  final notifier = ref.read(resolutionV2ActionProvider.notifier);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? '$label saved.' : notifier.errorMessage ?? 'Action failed.',
      ),
    ),
  );
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.order});

  final ServiceOrderModel order;

  @override
  Widget build(BuildContext context) {
    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.serviceTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('Freelancer: ${order.freelancerName}'),
          Text('Client: ${order.clientName}'),
          Text('Order: ${order.orderNumber}'),
          const Divider(height: 24),
          _MoneyRow('Subtotal', order.subtotal, order.currency),
          _MoneyRow('Platform commission', order.platformFee, order.currency),
          _MoneyRow('Tax', order.taxTotal, order.currency),
          _MoneyRow(
            'Estimated freelancer earnings',
            order.freelancerEarnings,
            order.currency,
          ),
          const Divider(height: 24),
          _MoneyRow(
            'Total amount',
            order.totalAmount,
            order.currency,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.order, required this.formatter});

  final ServiceOrderModel order;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final expectedRelease = order.expectedReleaseAt;
    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment & Escrow',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _DetailRow('Payment status', _label(order.paymentStatus)),
          _DetailRow('Escrow status', _label(order.escrowStatus)),
          _DetailRow(
            'Payment method',
            order.sandboxPaymentMethod ?? 'Not selected',
          ),
          _DetailRow(
            'Transaction reference',
            order.transactionReference ?? 'Pending sandbox payment',
          ),
          _DetailRow(
            'Expected release',
            expectedRelease == null
                ? '${SandboxCommerceConfig.escrowHoldingDays} days after payment'
                : formatter.format(expectedRelease),
          ),
          _DetailRow(
            'Wallet state',
            order.escrowReleasedAt == null
                ? 'Escrow not released yet'
                : order.fundsClearedAt == null
                ? 'Escrow released - pending clearance'
                : 'Funds cleared to available balance',
          ),
        ],
      ),
    );
  }
}

class _FinanceFacts extends StatelessWidget {
  const _FinanceFacts({required this.order, required this.formatter});

  final ServiceOrderModel order;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final paid = order.paidAt == null
        ? 'Pending'
        : formatter.format(order.paidAt!);
    final held = order.escrowHeldAt == null
        ? 'Not funded'
        : formatter.format(order.escrowHeldAt!);
    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Sandbox badge', 'Demo payment only'),
          _DetailRow('Paid at', paid),
          _DetailRow('Escrow held at', held),
          _DetailRow(
            'Holding period',
            '${SandboxCommerceConfig.escrowHoldingDays} days',
          ),
        ],
      ),
    );
  }
}

class _InvoicePanel extends StatelessWidget {
  const _InvoicePanel({
    required this.invoices,
    required this.role,
    required this.order,
    required this.isBusy,
    required this.onGenerate,
    required this.onView,
    required this.onDownload,
  });

  final List<InvoiceModel> invoices;
  final UserRole role;
  final ServiceOrderModel order;
  final bool isBusy;
  final VoidCallback onGenerate;
  final ValueChanged<InvoiceModel> onView;
  final ValueChanged<InvoiceModel> onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoice = _preferredInvoice();
    final hasInvoices = invoices.isNotEmpty;
    final paymentReady =
        order.paymentStatus != ServiceOrderPaymentStatus.unpaid;
    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasInvoices
                    ? Icons.verified_rounded
                    : Icons.receipt_long_outlined,
                color: hasInvoices ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasInvoices ? 'Invoice Generated' : 'Invoice Pending',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasInvoices
                ? '${invoices.length} immutable sandbox billing record${invoices.length == 1 ? '' : 's'} available for this order.'
                : paymentReady
                ? 'Generate professional invoice records for this paid sandbox order.'
                : 'Invoices become available after sandbox payment is completed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (invoice != null) ...[
                FilledButton.icon(
                  onPressed: isBusy ? null : () => onView(invoice),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View Invoice'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onDownload(invoice),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Invoice'),
                ),
              ],
              if (!hasInvoices &&
                  paymentReady &&
                  role != UserRole.admin &&
                  role != UserRole.superAdmin)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onGenerate,
                  icon: const Icon(Icons.post_add_rounded, size: 18),
                  label: const Text('Generate Invoice'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  InvoiceModel? _preferredInvoice() {
    if (invoices.isEmpty) return null;
    final preferredType = switch (role) {
      UserRole.freelancer => InvoiceType.freelancerInvoice,
      UserRole.admin || UserRole.superAdmin => InvoiceType.clientReceipt,
      _ => InvoiceType.clientReceipt,
    };
    for (final invoice in invoices) {
      if (invoice.type == preferredType) return invoice;
    }
    return invoices.first;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final ServiceOrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.serviceTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${order.orderNumber} - ${order.clientName} to ${order.freelancerName}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order, required this.formatter});

  final ServiceOrderModel order;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimelineItem(
          title: 'Order created',
          subtitle: formatter.format(order.createdAt),
          active: true,
          icon: Icons.receipt_long_rounded,
        ),
        _TimelineItem(
          title: 'Sandbox payment',
          subtitle: order.paidAt == null
              ? 'Pending demo checkout'
              : formatter.format(order.paidAt!),
          active: order.paidAt != null,
          icon: Icons.payments_rounded,
        ),
        _TimelineItem(
          title: 'Escrow held',
          subtitle: order.escrowHeldAt == null
              ? 'Escrow will be created after payment'
              : formatter.format(order.escrowHeldAt!),
          active: order.escrowStatus == ServiceOrderEscrowStatus.held,
          icon: Icons.lock_clock_rounded,
        ),
        _TimelineItem(
          title: 'Freelancer working',
          subtitle: order.workStartedAt == null
              ? 'Starts after escrow is held'
              : formatter.format(order.workStartedAt!),
          active:
              order.workStartedAt != null ||
              order.orderStatus == ServiceOrderStatus.inProgress ||
              order.deliveredAt != null ||
              order.completedAt != null,
          icon: Icons.engineering_rounded,
        ),
        _TimelineItem(
          title: 'Delivery',
          subtitle: order.deliveredAt == null
              ? 'Freelancer delivery pending'
              : formatter.format(order.deliveredAt!),
          active: order.deliveredAt != null,
          icon: Icons.inventory_2_rounded,
        ),
        _TimelineItem(
          title: 'Waiting client approval',
          subtitle: order.deliveredAt == null
              ? 'Pending delivery'
              : order.reviewDueAt == null
              ? 'Client can approve after delivery'
              : 'Review until ${formatter.format(order.reviewDueAt!)}',
          active: order.deliveredAt != null,
          icon: Icons.rate_review_rounded,
        ),
        if ((order.revisionStatus ?? '').trim().isNotEmpty)
          _TimelineItem(
            title: 'Revision workflow',
            subtitle:
                '${_label(order.revisionStatus!)} - ${order.revisionNotes ?? 'Revision history attached'}',
            active: true,
            icon: Icons.edit_note_rounded,
          ),
        if (order.orderStatus == ServiceOrderStatus.disputed ||
            order.escrowStatus == ServiceOrderEscrowStatus.disputed)
          const _TimelineItem(
            title: 'Dispute opened',
            subtitle: 'Admin resolution may release escrow or refund client',
            active: true,
            icon: Icons.gavel_rounded,
          ),
        if (order.paymentStatus == ServiceOrderPaymentStatus.refunded)
          const _TimelineItem(
            title: 'Sandbox refund processed',
            subtitle: 'Escrow was returned in sandbox mode',
            active: true,
            icon: Icons.replay_circle_filled_rounded,
          ),
        _TimelineItem(
          title: 'Ready for wallet release',
          subtitle: order.completedAt == null
              ? 'Prepared for FC4 wallet release'
              : formatter.format(order.completedAt!),
          active: order.completedAt != null,
          icon: Icons.verified_rounded,
          isLast: true,
        ),
      ],
    );
  }
}

class _SoftBox extends StatelessWidget {
  const _SoftBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
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
      padding: const EdgeInsets.only(bottom: 8),
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
              value,
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

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.icon,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool active;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.freelancerPrimary
        : Theme.of(context).colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.20),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle),
                ],
              ),
            ),
          ),
        ],
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _SandboxNotice extends StatelessWidget {
  const _SandboxNotice() : message = 'Sandbox commerce mode - no real payment has been processed yet.';

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.warning.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.science_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(
    this.label,
    this.amount,
    this.currency, {
    this.emphasized = false,
  });

  final String label;
  final double amount;
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
          Text(_money(amount, currency), style: style),
        ],
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
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.22)),
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
    return 'Completed / Released';
  }
  if (order.orderStatus == ServiceOrderStatus.disputed ||
      order.escrowStatus == ServiceOrderEscrowStatus.disputed) {
    return 'Disputed';
  }
  return _label(order.orderStatus);
}
