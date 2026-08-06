import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/resolution_case_model.dart';
import '../../../providers/resolution_v2_provider.dart';
import '../../../shared/widgets/customer_workspace_shell.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';

class CustomerResolutionCenterScreen extends ConsumerWidget {
  const CustomerResolutionCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(customerResolutionCasesProvider);
    return CustomerWorkspaceShell(
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = AppBreakpoints.pagePadding(constraints.maxWidth);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: padding.add(
                EdgeInsets.only(
                  bottom: 48 + MediaQuery.viewPaddingOf(context).bottom,
                ),
              ),
              child: casesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => DashboardEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Resolution cases unavailable',
                  message: error.toString(),
                ),
                data: (cases) => _CustomerCases(cases: cases),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CustomerCases extends StatelessWidget {
  const _CustomerCases({required this.cases});

  final List<ResolutionCaseModel> cases;

  @override
  Widget build(BuildContext context) {
    final open = cases.where((item) => item.isOpen).length;
    final revisions = cases
        .where((item) => item.type == ResolutionCaseType.revision)
        .length;
    final financial = cases
        .where((item) => item.isFinancialSettlementRequired)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Resolution Center',
          subtitle:
              'Track revision, refund, and dispute cases without touching escrow or wallet data.',
          icon: Icons.support_agent_rounded,
          color: AppColors.freelancerPrimary,
        ),
        const SizedBox(height: 18),
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
              title: 'Revisions',
              value: '$revisions',
              icon: Icons.edit_note_rounded,
              color: AppColors.warning,
            ),
            MetricCard(
              title: 'Settlement Review',
              value: '$financial',
              icon: Icons.balance_rounded,
              color: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (cases.isEmpty)
          DashboardEmptyState(
            icon: Icons.verified_user_rounded,
            title: 'No active resolution cases',
            message:
                'If an order needs changes, review, or a refund, open it from My Orders.',
            actionLabel: 'View Orders',
            onAction: () => context.goNamed(RouteNames.serviceOrders),
          )
        else
          _CaseSection(
            title: 'My Cases',
            icon: Icons.list_alt_rounded,
            cases: cases,
            color: AppColors.freelancerPrimary,
          ),
      ],
    );
  }
}

class _CaseSection extends StatelessWidget {
  const _CaseSection({
    required this.title,
    required this.icon,
    required this.cases,
    required this.color,
  });

  final String title;
  final IconData icon;
  final List<ResolutionCaseModel> cases;
  final Color color;

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
            ...cases.map(
              (item) => ResolutionCaseTile(item: item, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class ResolutionCaseTile extends StatelessWidget {
  const ResolutionCaseTile({
    super.key,
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
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
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
                    Chip(
                      label: Text(_label(item.type)),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('Opened by ${_label(item.openedByRole)}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (item.evidenceRequestStatus !=
                        ResolutionEvidenceRequestStatus.none)
                      Chip(
                        label: Text(_label(item.evidenceRequestStatus)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.description.isEmpty ? item.reason : item.description}\nClient evidence ${item.clientEvidenceCount} - Freelancer evidence ${item.freelancerEvidenceCount}\n${formatter.format(item.updatedAt)}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
