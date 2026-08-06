import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_service_review_model.dart';
import '../../../models/service_order_model.dart';
import '../../../models/service_request_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/commerce_order_provider.dart';
import '../../../providers/freelancer_service_review_provider.dart';
import '../../../providers/service_request_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../../marketplace_ai/widgets/marketplace_ai_notes_draft_dialog.dart';
import 'service_review_dialog.dart';

class ServiceRequestDetailScreen extends ConsumerWidget {
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = UserRole.fromString(user?.primaryRole) ?? UserRole.student;
    final requestAsync = ref.watch(serviceRequestDetailProvider(requestId));
    final actionState = ref.watch(serviceRequestActionProvider);
    final orderActionState = ref.watch(commerceOrderActionProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view this request.')),
      );
    }

    return RoleFixedHeaderPage(
      role: role,
      title: 'Service Request',
      subtitle: 'Lifecycle, notes, and next actions.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        final isFreelancer = role == UserRole.freelancer;
        context.goNamed(
          isFreelancer
              ? RouteNames.freelancerServiceRequests
              : RouteNames.serviceRequests,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: requestAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Request unavailable',
            message: error.toString(),
          ),
          data: (request) {
            final isClient = request?.clientId == user.uid;
            final isFreelancer = request?.freelancerId == user.uid;
            if (request == null || (!isClient && !isFreelancer)) {
              return const DashboardEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Request not found',
                message:
                    'This request does not exist or belongs to another account.',
              );
            }
            final existingOrder = ref
                .watch(orderByServiceRequestProvider(request.requestId))
                .value;
            final existingOrderId = existingOrder?.orderId;
            return _RequestDetail(
              request: request,
              isClient: isClient,
              isFreelancer: isFreelancer,
              isBusy: actionState.isLoading || orderActionState.isLoading,
              existingOrder: existingOrder,
              existingReview: ref
                  .watch(requestReviewProvider(request.requestId))
                  .value,
              onCancel: () => _cancelRequest(context, ref, request),
              onCreateOrder: () => _createOrder(context, ref, request),
              onViewOrder: existingOrderId == null
                  ? null
                  : () => context.pushNamed(
                      RouteNames.serviceOrderDetail,
                      pathParameters: {'orderId': existingOrderId},
                    ),
              onReview: () => showServiceReviewDialog(
                context: context,
                ref: ref,
                request: request,
                user: user,
              ),
              onFreelancerAction: (status) =>
                  _updateFreelancerStatus(context, ref, request, status),
            );
          },
        ),
      ),
    );
  }

  Future<void> _cancelRequest(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
  ) async {
    final noteController = TextEditingController();
    final confirmed = await _noteDialog(
      context: context,
      title: 'Cancel request?',
      label: 'Optional cancellation note',
      confirmLabel: 'Cancel Request',
      confirmColor: AppColors.error,
      controller: noteController,
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !context.mounted) return;
    final notifier = ref.read(serviceRequestActionProvider.notifier);
    final ok = await notifier.cancelClientRequest(
      requestId: request.requestId,
      clientNote: note.isEmpty ? null : note,
    );
    if (!context.mounted) return;
    _showResult(context, ok, 'Request cancelled.', notifier.errorMessage);
  }

  Future<void> _updateFreelancerStatus(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
    String status,
  ) async {
    final pending = MarketplaceAiPendingApply.takeNoteBodyFor('proposal');
    final noteController = TextEditingController(
      text: (pending ?? request.freelancerNote ?? '').trim(),
    );
    final confirmed = await _noteDialog(
      context: context,
      title: '${_statusLabel(status)} request',
      label: 'Freelancer note',
      helper: 'Visible to the client. This does not create a chat thread.',
      confirmLabel: 'Update',
      confirmColor: _statusColor(status),
      controller: noteController,
      onDraftWithAi: () async {
        await MarketplaceAiNotesDraftDialog.show(
          context: context,
          taskType: MarketplaceAiTaskType.freelancerProposalDraft,
          title: 'Draft proposal note with AI',
          applyLabel: 'Apply to Freelancer Note',
          initialPrompt:
              'Draft a professional freelancer note for request '
              '"${request.projectTitle}". Requirements: ${request.requirements}',
          safeAppContext: {
            'requestId': request.requestId,
            'serviceRequest': {
              'projectTitle': request.projectTitle,
              'requirements': request.requirements,
              'budget': request.budget,
              'selectedPackageTitle': request.selectedPackageTitle,
            },
          },
          onApplyBody: (body) {
            noteController.text = body;
          },
        );
      },
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(serviceRequestActionProvider.notifier);
    final ok = await notifier.updateFreelancerStatus(
      requestId: request.requestId,
      status: status,
      freelancerNote: note.isEmpty ? null : note,
    );
    if (!context.mounted) return;
    _showResult(context, ok, 'Request updated.', notifier.errorMessage);
  }

  Future<void> _createOrder(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
  ) async {
    final notifier = ref.read(commerceOrderActionProvider.notifier);
    final orderId = await notifier.createOrderFromServiceRequest(
      request.requestId,
    );
    if (!context.mounted) return;
    if (orderId == null) {
      _showResult(
        context,
        false,
        'Order created.',
        notifier.errorMessage ?? 'Unable to create sandbox order.',
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sandbox order created.')));
    context.pushNamed(
      RouteNames.serviceOrderDetail,
      pathParameters: {'orderId': orderId},
    );
  }
}

class _RequestDetail extends StatelessWidget {
  const _RequestDetail({
    required this.request,
    required this.isClient,
    required this.isFreelancer,
    required this.isBusy,
    required this.existingOrder,
    required this.existingReview,
    required this.onCancel,
    required this.onCreateOrder,
    required this.onViewOrder,
    required this.onReview,
    required this.onFreelancerAction,
  });

  final ServiceRequestModel request;
  final bool isClient;
  final bool isFreelancer;
  final bool isBusy;
  final ServiceOrderModel? existingOrder;
  final FreelancerServiceReviewModel? existingReview;
  final VoidCallback onCancel;
  final VoidCallback onCreateOrder;
  final VoidCallback? onViewOrder;
  final VoidCallback onReview;
  final ValueChanged<String> onFreelancerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy • h:mm a');
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;
        final summary = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.projectTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(status: request.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${request.serviceTitle} • ${request.freelancerName}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isFreelancer) ...[
                const SizedBox(height: 8),
                Text(
                  '${request.clientName} • ${request.clientEmail}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(request.requirements, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.payments_rounded,
                    label:
                        '${request.currency} ${request.budget.toStringAsFixed(0)}',
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: 'Submitted ${formatter.format(request.createdAt)}',
                  ),
                  _InfoChip(
                    icon: Icons.update_rounded,
                    label: 'Updated ${formatter.format(request.updatedAt)}',
                  ),
                  if (request.deadline != null)
                    _InfoChip(
                      icon: Icons.flag_rounded,
                      label:
                          'Deadline ${DateFormat('MMM d, yyyy').format(request.deadline!)}',
                    ),
                  _InfoChip(
                    icon: Icons.priority_high_rounded,
                    label: _priorityLabel(request.priority),
                  ),
                ],
              ),
              if (request.attachments.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Attachment URLs',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ...request.attachments.map(
                  (link) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(
                      link,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.freelancerPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

        final operations = _Panel(
          child: _OperationsPanel(
            request: request,
            isClient: isClient,
            isFreelancer: isFreelancer,
            isBusy: isBusy,
            existingOrder: existingOrder,
            hasReview: existingReview != null,
            onCancel: onCancel,
            onCreateOrder: onCreateOrder,
            onViewOrder: onViewOrder,
            onReview: onReview,
            onFreelancerAction: onFreelancerAction,
          ),
        );

        final timeline = _Panel(
          child: _Timeline(request: request, formatter: formatter),
        );

        final notes = _notesPanel(request);

        if (!isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 18),
              operations,
              const SizedBox(height: 18),
              timeline,
              if (notes != null) ...[const SizedBox(height: 18), notes],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  summary,
                  const SizedBox(height: 18),
                  timeline,
                  if (notes != null) ...[const SizedBox(height: 18), notes],
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(child: operations),
          ],
        );
      },
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({
    required this.request,
    required this.isClient,
    required this.isFreelancer,
    required this.isBusy,
    required this.existingOrder,
    required this.hasReview,
    required this.onCancel,
    required this.onCreateOrder,
    required this.onViewOrder,
    required this.onReview,
    required this.onFreelancerAction,
  });

  final ServiceRequestModel request;
  final bool isClient;
  final bool isFreelancer;
  final bool isBusy;
  final ServiceOrderModel? existingOrder;
  final bool hasReview;
  final VoidCallback onCancel;
  final VoidCallback onCreateOrder;
  final VoidCallback? onViewOrder;
  final VoidCallback onReview;
  final ValueChanged<String> onFreelancerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final freelancerActions = _freelancerActionsFor(request.status);
    final canCreateOrViewOrder = isClient && _canCreateOrViewOrder(request);
    final hasAction =
        (isClient &&
            (request.canClientCancel ||
                canCreateOrViewOrder ||
                (request.status == ServiceRequestStatus.completed &&
                    !hasReview))) ||
        (isFreelancer && freelancerActions.isNotEmpty);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        Widget wrapButton(Widget button) {
          return isNarrow ? SizedBox(width: double.infinity, child: button) : button;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Next Action',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isClient
                  ? _nextClientAction(request)
                  : _nextFreelancerAction(request),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            wrapButton(
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  isFreelancer
                      ? RouteNames.freelancerAiAssistant
                      : RouteNames.customerAiAssistant,
                  queryParameters: {
                    'task': isFreelancer ? 'proposal' : 'serviceRequest',
                    'requestId': request.requestId,
                  },
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  isFreelancer ? 'Draft Proposal with AI' : 'Improve Request with AI',
                ),
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 18),
              if (isClient && request.canClientCancel)
                wrapButton(
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Request'),
                  ),
                ),
              if (canCreateOrViewOrder)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: wrapButton(
                    existingOrder == null
                        ? FilledButton.icon(
                            onPressed: isBusy ? null : onCreateOrder,
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text('Create Sandbox Order'),
                          )
                        : OutlinedButton.icon(
                            onPressed: onViewOrder,
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text('View Sandbox Order'),
                          ),
                  ),
                ),
              if (isClient &&
                  request.status == ServiceRequestStatus.completed &&
                  !hasReview)
                wrapButton(
                  FilledButton.icon(
                    onPressed: isBusy ? null : onReview,
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Leave Review'),
                  ),
                ),
              if (isClient &&
                  request.status == ServiceRequestStatus.completed &&
                  hasReview)
                const _ReviewedBadge(),
              if (isFreelancer)
                ...freelancerActions.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: wrapButton(
                      status == ServiceRequestStatus.rejected
                          ? OutlinedButton.icon(
                              onPressed: isBusy
                                  ? null
                                  : () => onFreelancerAction(status),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: Text(_statusLabel(status)),
                            )
                          : FilledButton.icon(
                              onPressed: isBusy
                                  ? null
                                  : () => onFreelancerAction(status),
                              icon: Icon(_actionIcon(status), size: 18),
                              label: Text(_statusLabel(status)),
                            ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.request, required this.formatter});

  final ServiceRequestModel request;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final isRejected = request.status == ServiceRequestStatus.rejected;
    final isCancelled = request.status == ServiceRequestStatus.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Timeline',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        _TimelineItem(
          title: 'Submitted',
          subtitle: formatter.format(request.createdAt),
          active: true,
          icon: Icons.send_rounded,
        ),
        _TimelineItem(
          title: 'Accepted',
          subtitle: request.acceptedAt == null
              ? 'Waiting for freelancer'
              : formatter.format(request.acceptedAt!),
          active: request.acceptedAt != null,
          icon: Icons.handshake_rounded,
        ),
        _TimelineItem(
          title: 'In progress',
          subtitle:
              request.status == ServiceRequestStatus.inProgress ||
                  request.deliveredAt != null ||
                  request.completedAt != null
              ? 'Work started'
              : 'Not started yet',
          active:
              request.status == ServiceRequestStatus.inProgress ||
              request.deliveredAt != null ||
              request.completedAt != null,
          icon: Icons.sync_rounded,
        ),
        _TimelineItem(
          title: 'Delivered',
          subtitle: request.deliveredAt == null
              ? 'Pending delivery'
              : formatter.format(request.deliveredAt!),
          active: request.deliveredAt != null,
          icon: Icons.inventory_2_rounded,
        ),
        _TimelineItem(
          title: _endingTitle(request),
          subtitle: request.completedAt != null
              ? formatter.format(request.completedAt!)
              : request.cancelledAt != null
              ? formatter.format(request.cancelledAt!)
              : isRejected
              ? 'Rejected by freelancer'
              : isCancelled
              ? 'Cancelled by client'
              : 'Pending completion',
          active: request.isTerminal,
          icon: _endingIcon(request),
          isLast: true,
        ),
      ],
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
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.circle, size: 0, color: Colors.transparent),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.freelancerPrimary),
          const SizedBox(width: 6),
          Flexible(child: Text(label)),
        ],
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ReviewedBadge extends StatelessWidget {
  const _ReviewedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Review submitted',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Widget? _notesPanel(ServiceRequestModel request) {
  final hasFreelancerNote = (request.freelancerNote ?? '').trim().isNotEmpty;
  final hasClientNote = (request.clientNote ?? '').trim().isNotEmpty;
  if (!hasFreelancerNote && !hasClientNote) return null;
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (hasFreelancerNote) ...[
              const SizedBox(height: 12),
              Text(
                'Freelancer',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.freelancerPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(request.freelancerNote!),
            ],
            if (hasClientNote) ...[
              const SizedBox(height: 12),
              Text(
                'Client',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(request.clientNote!),
            ],
          ],
        ),
      );
    },
  );
}

Future<bool?> _noteDialog({
  required BuildContext context,
  required String title,
  required String label,
  required String confirmLabel,
  required Color confirmColor,
  required TextEditingController controller,
  String? helper,
  Future<void> Function()? onDraftWithAi,
}) {
  return showDialog<bool>(
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
              labelText: label,
              helperText: helper,
              border: const OutlineInputBorder(),
            ),
          ),
          if (onDraftWithAi != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => onDraftWithAi(),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Draft with AI'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

void _showResult(BuildContext context, bool ok, String success, String? error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? success : error ?? 'Action failed.')),
  );
}

List<String> _freelancerActionsFor(String status) {
  return switch (status) {
    ServiceRequestStatus.pending => [
      ServiceRequestStatus.accepted,
      ServiceRequestStatus.rejected,
    ],
    _ => const <String>[],
  };
}

bool _canCreateOrViewOrder(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.accepted ||
    ServiceRequestStatus.inProgress ||
    ServiceRequestStatus.delivered ||
    ServiceRequestStatus.completed => true,
    _ => false,
  };
}

String _nextClientAction(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.pending =>
      'You can cancel while pending, or wait for the freelancer response.',
    ServiceRequestStatus.accepted =>
      'The freelancer accepted. Create a sandbox order, then fund escrow from the order page.',
    ServiceRequestStatus.inProgress =>
      'This older request is marked in progress. Use the linked sandbox order for delivery and release.',
    ServiceRequestStatus.delivered =>
      'This older request is marked delivered. Use the linked sandbox order for review and escrow release.',
    ServiceRequestStatus.completed => 'This request is completed.',
    ServiceRequestStatus.rejected => 'This request was rejected.',
    ServiceRequestStatus.cancelled => 'This request was cancelled.',
    _ => 'Review the request details.',
  };
}

String _nextFreelancerAction(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.pending =>
      'Accept the request if you can take it, or reject it with a helpful note.',
    ServiceRequestStatus.accepted =>
      'Waiting for the client to create and fund the sandbox order.',
    ServiceRequestStatus.inProgress =>
      'This older request is in progress. Use the linked order for delivery actions.',
    ServiceRequestStatus.delivered =>
      'Waiting for the client to review the linked order.',
    ServiceRequestStatus.completed => 'This request is completed.',
    ServiceRequestStatus.rejected => 'This request was rejected.',
    ServiceRequestStatus.cancelled => 'This request was cancelled.',
    _ => 'Review the client request.',
  };
}

IconData _actionIcon(String status) {
  return switch (status) {
    ServiceRequestStatus.accepted => Icons.handshake_rounded,
    ServiceRequestStatus.inProgress => Icons.sync_rounded,
    ServiceRequestStatus.delivered => Icons.inventory_2_rounded,
    _ => Icons.check_rounded,
  };
}

IconData _endingIcon(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.completed => Icons.check_circle_rounded,
    ServiceRequestStatus.rejected => Icons.cancel_rounded,
    ServiceRequestStatus.cancelled => Icons.block_rounded,
    _ => Icons.flag_rounded,
  };
}

String _endingTitle(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.completed => 'Completed',
    ServiceRequestStatus.rejected => 'Rejected',
    ServiceRequestStatus.cancelled => 'Cancelled',
    _ => 'Completed / Closed',
  };
}

String _priorityLabel(String priority) {
  return priority[0].toUpperCase() + priority.substring(1);
}

String _statusLabel(String status) {
  return switch (status) {
    ServiceRequestStatus.inProgress => 'In Progress',
    _ => status[0].toUpperCase() + status.substring(1),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    ServiceRequestStatus.accepted ||
    ServiceRequestStatus.inProgress => AppColors.info,
    ServiceRequestStatus.delivered ||
    ServiceRequestStatus.completed => AppColors.success,
    ServiceRequestStatus.rejected ||
    ServiceRequestStatus.cancelled => AppColors.error,
    _ => AppColors.warning,
  };
}
