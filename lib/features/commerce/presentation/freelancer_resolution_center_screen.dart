import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/resolution_case_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/resolution_v2_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../../marketplace_ai/widgets/marketplace_ai_notes_draft_dialog.dart';

class FreelancerResolutionCenterScreen extends ConsumerWidget {
  const FreelancerResolutionCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(freelancerResolutionCasesProvider);
    final busy = ref.watch(resolutionV2ActionProvider).isLoading;
    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Resolution Center',
      subtitle: 'Revision queue, evidence requests, and settlement outcomes.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.freelancerServiceOrders),
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('Orders'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: casesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Resolution data unavailable',
            message: error.toString(),
          ),
          data: (cases) => _FreelancerCases(cases: cases, busy: busy),
        ),
      ),
    );
  }
}

class _FreelancerCases extends ConsumerWidget {
  const _FreelancerCases({required this.cases, required this.busy});

  final List<ResolutionCaseModel> cases;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revisions = cases
        .where((item) => item.type == ResolutionCaseType.revision)
        .toList();
    final open = cases.where((item) => item.isOpen).length;
    final settlements = cases
        .where(
          (item) => item.settlementStatus != ResolutionSettlementStatus.none,
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minChildWidth: 210,
          children: [
            MetricCard(
              title: 'Open Cases',
              value: '$open',
              icon: Icons.folder_open_rounded,
              color: AppColors.freelancerPrimary,
            ),
            MetricCard(
              title: 'Revision Queue',
              value: '${revisions.where((item) => item.isOpen).length}',
              icon: Icons.edit_note_rounded,
              color: AppColors.warning,
            ),
            MetricCard(
              title: 'Settlement Records',
              value: '$settlements',
              icon: Icons.balance_rounded,
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (cases.isEmpty)
          DashboardEmptyState(
            icon: Icons.verified_user_rounded,
            title: 'No resolution work yet',
            message:
                'Revision requests, evidence requests, and settlement decisions will appear here as clients raise them.',
            actionLabel: 'View Orders',
            onAction: () => context.goNamed(RouteNames.freelancerServiceOrders),
          )
        else
          _Section(
            title: 'Freelancer Cases',
            icon: Icons.support_agent_rounded,
            children: cases.map((item) {
              return _CaseTile(
                item: item,
                color: _caseColor(item),
                actions: [
                  if (item.type == ResolutionCaseType.revision &&
                      item.status == ResolutionCaseStatus.revisionRequested)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _notesAction(
                              context,
                              ref,
                              title: 'Accept revision',
                              actionLabel: 'Accept',
                              onSubmit: (notes) => ref
                                  .read(resolutionV2ActionProvider.notifier)
                                  .acceptRevision(item.caseId, notes),
                            ),
                      child: const Text('Accept'),
                    ),
                  if (item.type == ResolutionCaseType.revision &&
                      item.status == ResolutionCaseStatus.revisionAccepted)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _notesAction(
                              context,
                              ref,
                              title: 'Submit revision',
                              actionLabel: 'Submit',
                              aiTaskType: MarketplaceAiTaskType
                                  .freelancerRevisionResponseDraft,
                              pendingNoteKind: 'revisionResponse',
                              onSubmit: (notes) => ref
                                  .read(resolutionV2ActionProvider.notifier)
                                  .submitRevision(item.caseId, notes),
                            ),
                      child: const Text('Submit'),
                    ),
                  if (item.isOpen)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _notesAction(
                              context,
                              ref,
                              title: 'Add evidence',
                              actionLabel: 'Add Evidence',
                              aiTaskType: MarketplaceAiTaskType
                                  .freelancerDisputeEvidenceSummary,
                              pendingNoteKind: 'evidence',
                              onSubmit: (notes) => ref
                                  .read(resolutionV2ActionProvider.notifier)
                                  .addEvidence(item.caseId, notes),
                            ),
                      child: const Text('Add Evidence'),
                    ),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }
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

class _CaseTile extends StatelessWidget {
  const _CaseTile({
    required this.item,
    required this.color,
    this.actions = const [],
  });

  final ResolutionCaseModel item;
  final Color color;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy');
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
                    Chip(label: Text('Opened by ${_label(item.openedByRole)}')),
                    if (item.evidenceRequestStatus !=
                        ResolutionEvidenceRequestStatus.none)
                      Chip(label: Text(_label(item.evidenceRequestStatus))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.description.isEmpty ? item.reason : item.description}\nClient evidence ${item.clientEvidenceCount} - Freelancer evidence ${item.freelancerEvidenceCount}\n${formatter.format(item.updatedAt)}',
                  maxLines: 4,
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

Future<void> _notesAction(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String actionLabel,
  required Future<bool> Function(String notes) onSubmit,
  String? aiTaskType,
  String? pendingNoteKind,
}) async {
  final pending = (pendingNoteKind ?? '').isEmpty
      ? null
      : MarketplaceAiPendingApply.takeNoteBodyFor(pendingNoteKind!);
  final controller = TextEditingController(text: pending ?? '');
  final notes = await showDialog<String>(
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
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
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

Color _caseColor(ResolutionCaseModel item) {
  return switch (item.type) {
    ResolutionCaseType.revision => AppColors.freelancerPrimary,
    ResolutionCaseType.refund => AppColors.error,
    _ => AppColors.warning,
  };
}

String _label(String value) {
  if (value.isEmpty) return 'Unknown';
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}
