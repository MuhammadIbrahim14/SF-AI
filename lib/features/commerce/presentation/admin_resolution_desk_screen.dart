import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/config/demo_resolution_config.dart';
import '../../../core/config/settlement_executor_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/resolution_case_model.dart';
import '../../../models/resolution_settlement_request_model.dart';
import '../../../providers/resolution_v2_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';

class AdminResolutionDeskScreen extends ConsumerStatefulWidget {
  const AdminResolutionDeskScreen({super.key});

  @override
  ConsumerState<AdminResolutionDeskScreen> createState() =>
      _AdminResolutionDeskScreenState();
}

class _AdminResolutionDeskScreenState
    extends ConsumerState<AdminResolutionDeskScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(adminResolutionCasesProvider);
    final actionState = ref.watch(resolutionV2ActionProvider);
    return AdminControlScaffold(
      title: 'Resolution Desk V2',
      subtitle:
          'Admin workload for disputes, refunds, and financial settlement records.',
      currentPath: RoutePaths.adminResolutionDesk,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.adminCommerceOrders),
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('Orders'),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: casesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => DashboardEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Resolution desk unavailable',
              message: error.toString(),
            ),
            data: (cases) => _AdminCases(
              cases: cases,
              filter: _filter,
              busy: actionState.isLoading,
              onFilter: (value) => setState(() => _filter = value),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminCases extends ConsumerWidget {
  const _AdminCases({
    required this.cases,
    required this.filter,
    required this.busy,
    required this.onFilter,
  });

  final List<ResolutionCaseModel> cases;
  final String filter;
  final bool busy;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = cases.where((item) => item.isOpen).length;
    final underReview = cases
        .where((item) => item.status == ResolutionCaseStatus.underReview)
        .length;
    final settlement = cases
        .where(
          (item) => item.settlementStatus != ResolutionSettlementStatus.none,
        )
        .length;
    final filtered = cases.where((item) {
      return switch (filter) {
        'open' => item.isOpen,
        'underReview' => item.status == ResolutionCaseStatus.underReview,
        'dispute' => item.type == ResolutionCaseType.dispute,
        'refund' => item.type == ResolutionCaseType.refund,
        'resolved' => item.status == ResolutionCaseStatus.resolved,
        _ => true,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) const LinearProgressIndicator(),
        if (!SettlementExecutorConfig.settlementBackendAvailable) ...[
          const _BackendPendingBanner(),
          const SizedBox(height: 18),
        ],
        ResponsiveGrid(
          minChildWidth: 210,
          children: [
            MetricCard(
              title: 'Open Cases',
              value: '$open',
              icon: Icons.folder_open_rounded,
              color: AppColors.adminPrimary,
            ),
            MetricCard(
              title: 'Under Review',
              value: '$underReview',
              icon: Icons.manage_search_rounded,
              color: AppColors.warning,
            ),
            MetricCard(
              title: 'Settlements',
              value: '$settlement',
              icon: Icons.balance_rounded,
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                'all',
                'open',
                'underReview',
                'dispute',
                'refund',
                'resolved',
              ].map((item) {
                return ChoiceChip(
                  selected: filter == item,
                  label: Text(_label(item)),
                  onSelected: (_) => onFilter(item),
                );
              }).toList(),
        ),
        const SizedBox(height: 18),
        if (cases.isEmpty)
          const DashboardEmptyState(
            icon: Icons.verified_user_rounded,
            title: 'No resolution cases yet',
            message:
                'New V2 dispute and refund cases will appear here. Revision cases stay with customer and freelancer.',
          )
        else if (filtered.isEmpty)
          const DashboardEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No cases match this filter',
            message: 'Try another queue filter.',
          )
        else
          _Section(
            title: 'Case Queue',
            icon: Icons.support_agent_rounded,
            children: filtered.map((item) {
              return _AdminCaseTile(
                item: item,
                color: _caseColor(item),
                actions: _actions(context, ref, item, busy),
              );
            }).toList(),
          ),
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    ResolutionCaseModel item,
    bool busy,
  ) {
    if (item.type == ResolutionCaseType.revision) {
      return const [
        Chip(
          avatar: Icon(Icons.sync_alt_rounded, size: 16),
          label: Text('Revision flow'),
        ),
      ];
    }
    if (!item.isOpen) {
      return [
        OutlinedButton(
          onPressed: busy
              ? null
              : () => ref
                    .read(resolutionV2ActionProvider.notifier)
                    .closeCase(item.caseId),
          child: const Text('Close'),
        ),
      ];
    }
    return [
      OutlinedButton(
        onPressed: busy
            ? null
            : () => ref
                  .read(resolutionV2ActionProvider.notifier)
                  .markUnderReview(item.caseId),
        child: const Text('Under Review'),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => _requestEvidenceAction(context, ref, item: item),
        child: const Text('Request Evidence'),
      ),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () => ref
                  .read(resolutionV2ActionProvider.notifier)
                  .generateLawRecommendation(item.caseId),
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: const Text('Law AI'),
      ),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () => context.goNamed(
                RouteNames.adminResolutionAiAnalyst,
                queryParameters: {
                  'task': 'analyze',
                  'caseId': item.caseId,
                  'orderId': item.orderId,
                },
              ),
        icon: const Icon(Icons.psychology_alt_rounded, size: 18),
        label: const Text('AI Analyst'),
      ),
      FilledButton.tonal(
        onPressed: busy
            ? null
            : () => _resolveAction(context, ref, item, _Decision.release),
        child: const Text('Demo Release'),
      ),
      FilledButton.tonal(
        onPressed: busy
            ? null
            : () => _resolveAction(context, ref, item, _Decision.refund),
        child: const Text('Refund'),
      ),
      FilledButton.tonal(
        onPressed: busy
            ? null
            : () => _resolveAction(context, ref, item, _Decision.split),
        child: const Text('Demo Split'),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => _noteAction(
                context,
                ref,
                title: 'Reject case',
                actionLabel: 'Reject',
                onSubmit: (notes) => ref
                    .read(resolutionV2ActionProvider.notifier)
                    .rejectCase(item.caseId, notes),
              ),
        child: const Text('Reject'),
      ),
    ];
  }
}

enum _Decision { release, refund, split }

Future<void> _resolveAction(
  BuildContext context,
  WidgetRef ref,
  ResolutionCaseModel item,
  _Decision decision,
) async {
  final escrowAmount = _caseEscrowAmount(item);
  final defaultRefund = item.requestedRefundAmount > 0
      ? item.requestedRefundAmount
      : escrowAmount;
  final releaseController = TextEditingController(
    text: decision == _Decision.refund
        ? '0'
        : (item.releaseAmount > 0 ? item.releaseAmount : escrowAmount)
              .toStringAsFixed(2),
  );
  final refundController = TextEditingController(
    text: decision == _Decision.release
        ? '0'
        : (item.refundAmount > 0 ? item.refundAmount : defaultRefund)
              .toStringAsFixed(2),
  );
  final notesController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Resolve ${_label(item.type)}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.32),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${DemoResolutionConfig.bannerMessage} This action creates a final settlement/audit record and cannot be repeated for the same case.',
                    ),
                  ),
                ],
              ),
            ),
            if (escrowAmount > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Escrow available: ${escrowAmount.toStringAsFixed(2)} ${item.currency}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (decision != _Decision.refund)
              TextField(
                controller: releaseController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Release amount',
                  border: OutlineInputBorder(),
                ),
              ),
            if (decision == _Decision.split) const SizedBox(height: 12),
            if (decision != _Decision.release)
              TextField(
                controller: refundController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Refund amount',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Admin note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm Settlement'),
        ),
      ],
    ),
  );
  final release = double.tryParse(releaseController.text) ?? 0;
  final refund = double.tryParse(refundController.text) ?? 0;
  final notes = notesController.text;
  releaseController.dispose();
  refundController.dispose();
  notesController.dispose();
  if (confirmed != true || !context.mounted) return;
  final validationError = _settlementValidationMessage(
    decision: decision,
    release: release,
    refund: refund,
    escrowAmount: escrowAmount,
  );
  if (validationError != null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check settlement amount'),
        content: Text(validationError),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }
  final notifier = ref.read(resolutionV2ActionProvider.notifier);
  if (DemoResolutionConfig.isDemoResolutionExecutorEnabled) {
    final ok = await notifier.completeDemoSettlement(
      caseId: item.caseId,
      resolutionType: switch (decision) {
        _Decision.release => 'demoRelease',
        _Decision.refund => 'demoRefund',
        _Decision.split => 'demoSplit',
      },
      freelancerAmount: release,
      customerAmount: refund,
      decisionNote: notes,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demo settlement completed.'
              : notifier.errorMessage ?? 'Demo settlement failed.',
        ),
      ),
    );
    return;
  }
  final request = await notifier.createSettlementRequest(
    item: item,
    decision: _settlementDecisionValue(decision),
    releaseAmount: release,
    refundAmount: refund,
    adminNote: notes,
  );
  if (!context.mounted) return;
  if (request == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notifier.errorMessage ?? 'Action failed.')),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Settlement request submitted. Processing...'),
    ),
  );
  await _showSettlementRequestDialog(context, ref, request.requestId);
}

double _caseEscrowAmount(ResolutionCaseModel item) {
  final amount = item.orderSnapshot['amount'];
  if (amount is num) return amount.toDouble();
  if (amount is String) return double.tryParse(amount) ?? 0;
  final knownAmount =
      item.releaseAmount + item.refundAmount + item.requestedRefundAmount;
  return knownAmount > 0 ? knownAmount : 0;
}

String? _settlementValidationMessage({
  required _Decision decision,
  required double release,
  required double refund,
  required double escrowAmount,
}) {
  if (decision == _Decision.release && release <= 0) {
    return 'Release amount must be greater than 0.';
  }
  if (decision == _Decision.refund && refund <= 0) {
    return 'Refund amount must be greater than 0.';
  }
  if (decision == _Decision.split) {
    if (release <= 0 || refund <= 0) {
      return 'Split settlement needs both release and refund amounts.';
    }
    if (escrowAmount > 0 && release + refund > escrowAmount) {
      return 'Split total cannot exceed the available escrow amount.';
    }
  }
  return null;
}

String _settlementDecisionValue(_Decision decision) {
  return switch (decision) {
    _Decision.release => ResolutionDecision.releaseToFreelancer,
    _Decision.refund => ResolutionDecision.refundToClient,
    _Decision.split => ResolutionDecision.splitRelease,
  };
}

Future<void> _showSettlementRequestDialog(
  BuildContext context,
  WidgetRef ref,
  String requestId,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final requestAsync = ref.watch(
          resolutionSettlementRequestProvider(requestId),
        );
        return AlertDialog(
          title: const Text('Settlement processing'),
          content: SizedBox(
            width: 420,
            child: requestAsync.when(
              loading: () => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Waiting for settlement request...'),
                ],
              ),
              error: (error, _) =>
                  Text('Settlement status unavailable: $error'),
              data: (request) {
                if (request == null) {
                  return const Text('Settlement request was not found.');
                }
                final failed =
                    request.status ==
                        ResolutionSettlementRequestStatus.failed ||
                    request.status ==
                        ResolutionSettlementRequestStatus.rejected;
                final completed =
                    request.status ==
                    ResolutionSettlementRequestStatus.completed;
                final backendPending =
                    !SettlementExecutorConfig.settlementBackendAvailable &&
                    !request.isTerminal;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!request.isTerminal && !backendPending)
                      const LinearProgressIndicator(),
                    if (!request.isTerminal && !backendPending)
                      const SizedBox(height: 12),
                    Text(
                      completed
                          ? 'Settlement completed successfully.'
                          : failed
                          ? 'Settlement failed: ${request.errorMessage ?? 'Unknown error'}'
                          : backendPending
                          ? 'Pending backend deployment. Enable Blaze and deploy Cloud Functions to process this request.'
                          : 'Current status: ${_label(request.status)}',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Decision: ${_label(request.decision)}\n'
                      'Release: ${request.releaseAmount.toStringAsFixed(2)} ${request.currency}\n'
                      'Refund: ${request.refundAmount.toStringAsFixed(2)} ${request.currency}',
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _noteAction(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String actionLabel,
  required Future<bool> Function(String notes) onSubmit,
}) async {
  final controller = TextEditingController();
  final notes = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Notes',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  if (notes == null || !context.mounted) return;
  final ok = await onSubmit(notes);
  if (!context.mounted) return;
  final notifier = ref.read(resolutionV2ActionProvider.notifier);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? '$actionLabel saved.' : notifier.errorMessage ?? 'Action failed.',
      ),
    ),
  );
}

Future<void> _requestEvidenceAction(
  BuildContext context,
  WidgetRef ref, {
  required ResolutionCaseModel item,
}) async {
  final controller = TextEditingController();
  var targetRole = 'both';
  final submitted = await showDialog<({String notes, String targetRole})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Request evidence'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetRole,
                decoration: const InputDecoration(
                  labelText: 'Request from',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'client', child: Text('Client')),
                  DropdownMenuItem(
                    value: 'freelancer',
                    child: Text('Freelancer'),
                  ),
                  DropdownMenuItem(value: 'both', child: Text('Both sides')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => targetRole = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Evidence request message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop((notes: controller.text, targetRole: targetRole)),
            child: const Text('Request'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (submitted == null || !context.mounted) return;
  final notifier = ref.read(resolutionV2ActionProvider.notifier);
  final ok = await notifier.requestEvidence(
    item.caseId,
    submitted.notes,
    targetRole: submitted.targetRole,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Evidence requested.' : notifier.errorMessage ?? 'Action failed.',
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BackendPendingBanner extends StatelessWidget {
  const _BackendPendingBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DemoResolutionConfig.demoModeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(DemoResolutionConfig.bannerMessage),
                const SizedBox(height: 4),
                Text(
                  'Release, refund, and split are enabled for demo ledger records. Cloud Functions are still required later for production settlement execution.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({required this.item, required this.evidenceAsync});

  final ResolutionCaseModel item;
  final AsyncValue<List<ResolutionCaseEvidenceModel>> evidenceAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.adminPrimary.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.adminPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniFact(
                label: 'Requested from',
                value: _label(item.adminEvidenceRequestedFrom ?? 'not set'),
              ),
              _MiniFact(
                label: 'Evidence status',
                value: _label(item.evidenceRequestStatus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          evidenceAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (error, _) => Text(
              'Evidence unavailable: $error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            data: (evidence) {
              final clientEvidence = evidence
                  .where((entry) => entry.actorRole == 'client')
                  .toList();
              final freelancerEvidence = evidence
                  .where((entry) => entry.actorRole == 'freelancer')
                  .toList();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 760;
                  final panels = [
                    _EvidenceSide(
                      title: 'Client Evidence',
                      evidence: clientEvidence,
                      emptyMessage: 'No client evidence submitted yet.',
                    ),
                    _EvidenceSide(
                      title: 'Freelancer Evidence',
                      evidence: freelancerEvidence,
                      emptyMessage: 'No freelancer evidence submitted yet.',
                    ),
                  ];
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        panels.first,
                        const SizedBox(height: 10),
                        panels.last,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: panels.first),
                      const SizedBox(width: 10),
                      Expanded(child: panels.last),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EvidenceSide extends StatelessWidget {
  const _EvidenceSide({
    required this.title,
    required this.evidence,
    required this.emptyMessage,
  });

  final String title;
  final List<ResolutionCaseEvidenceModel> evidence;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surface.withValues(alpha: 0.52),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (evidence.isEmpty)
            Text(emptyMessage, style: theme.textTheme.bodySmall)
          else
            ...evidence.map((entry) => _EvidenceEntry(entry: entry)),
        ],
      ),
    );
  }
}

class _EvidenceEntry extends StatelessWidget {
  const _EvidenceEntry({required this.entry});

  final ResolutionCaseEvidenceModel entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, h:mm a');
    final attachments = entry.attachments
        .map((attachment) => attachment['url']?.toString() ?? '')
        .where((url) => url.trim().isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.34,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.title.isEmpty ? 'Evidence' : entry.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (entry.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.description),
              ],
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Attachments: ${attachments.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.adminPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                formatter.format(entry.createdAt),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminCaseTile extends ConsumerWidget {
  const _AdminCaseTile({
    required this.item,
    required this.color,
    this.actions = const [],
  });

  final ResolutionCaseModel item;
  final Color color;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy');
    final evidenceAsync = ref.watch(
      resolutionCaseEvidenceProvider(item.caseId),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface.withValues(alpha: 0.52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.serviceOrderDetail,
            pathParameters: {'orderId': item.orderId},
          ),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.serviceTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Chip(
                      label: Text(_label(item.status)),
                      backgroundColor: color.withValues(alpha: 0.12),
                      side: BorderSide(color: color.withValues(alpha: 0.24)),
                    ),
                    Chip(label: Text(_label(item.type))),
                    Chip(
                      avatar: Icon(
                        item.openedByRole == 'freelancer'
                            ? Icons.handyman_rounded
                            : Icons.person_rounded,
                        size: 16,
                      ),
                      label: Text('Opened by ${_label(item.openedByRole)}'),
                    ),
                    if ((item.againstRole ?? '').isNotEmpty)
                      Chip(label: Text('Against ${_label(item.againstRole!)}')),
                    if (item.evidenceRequired)
                      const Chip(
                        avatar: Icon(Icons.priority_high_rounded, size: 16),
                        label: Text('Needs Evidence'),
                      ),
                    if (item.evidenceRequestStatus !=
                        ResolutionEvidenceRequestStatus.none)
                      Chip(
                        avatar: const Icon(Icons.fact_check_rounded, size: 16),
                        label: Text(_label(item.evidenceRequestStatus)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniFact(
                      label: 'Client evidence',
                      value: '${item.clientEvidenceCount}',
                    ),
                    _MiniFact(
                      label: 'Freelancer evidence',
                      value: '${item.freelancerEvidenceCount}',
                    ),
                    _MiniFact(
                      label: 'Order',
                      value: _label(
                        item.orderSnapshot['orderStatus']?.toString() ?? '',
                      ),
                    ),
                    _MiniFact(
                      label: 'Payment',
                      value: _label(
                        item.orderSnapshot['paymentStatus']?.toString() ?? '',
                      ),
                    ),
                    _MiniFact(
                      label: 'Escrow',
                      value: _label(
                        item.orderSnapshot['escrowStatus']?.toString() ?? '',
                      ),
                    ),
                    if ((item.lawTitle ?? '').isNotEmpty)
                      _MiniFact(label: 'Law', value: item.lawTitle!),
                    if (item.aiRecommendedAction.isNotEmpty &&
                        item.aiRecommendedAction != ResolutionDecision.none)
                      _MiniFact(
                        label: 'AI recommends',
                        value: _label(item.aiRecommendedAction),
                      ),
                  ],
                ),
                if (item.aiSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.aiSummary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.adminPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (item.evidenceRequestStatus !=
                        ResolutionEvidenceRequestStatus.none ||
                    item.clientEvidenceCount > 0 ||
                    item.freelancerEvidenceCount > 0) ...[
                  const SizedBox(height: 10),
                  _EvidencePanel(item: item, evidenceAsync: evidenceAsync),
                ],
                const SizedBox(height: 6),
                Text(
                  '${item.description.isEmpty ? item.reason : item.description}\nClient ${item.clientName} - Freelancer ${item.freelancerName}\n${formatter.format(item.updatedAt)}',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _caseColor(ResolutionCaseModel item) {
  return switch (item.type) {
    ResolutionCaseType.revision => AppColors.adminPrimary,
    ResolutionCaseType.refund => AppColors.error,
    _ => AppColors.warning,
  };
}

String _label(String value) {
  if (value == 'all') return 'All';
  if (value.isEmpty) return 'Unknown';
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}
