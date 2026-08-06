import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_join_request_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/student_batch_provider.dart';

class StudentMyBatchesScreen extends ConsumerWidget {
  const StudentMyBatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batchesAsync = ref.watch(studentRosterBatchesProvider);
    final requestsAsync = ref.watch(studentJoinRequestsProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'My Classes',
      subtitle: 'Class batches you belong to, plus your join requests.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load classes: $error',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
        data: (batches) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              _HubActionsCard(
                onJoin: () =>
                    context.pushNamed(RouteNames.studentJoinBatch),
                onAnnouncements: () => context.pushNamed(
                  RouteNames.studentClassAnnouncements,
                ),
              ),
              const SizedBox(height: 16),
              _JoinRequestsSection(
                requestsAsync: requestsAsync,
                rosterBatches: batches,
              ),
              const SizedBox(height: 18),
              Text(
                'My batches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (batches.isEmpty)
                DashboardEmptyState(
                  icon: Icons.groups_2_outlined,
                  title: 'No class batches yet',
                  message:
                      'Ask your teacher for an invite code, then request to join. '
                      'After approval you will see the batch here.',
                  actionLabel: 'Join a class batch',
                  onAction: () =>
                      context.pushNamed(RouteNames.studentJoinBatch),
                )
              else
                ResponsiveGrid(
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 2,
                  wideColumns: 3,
                  minChildWidth: 320,
                  children: [
                    for (final batch in batches)
                      _StudentBatchCard(
                        batch: batch,
                        onOpen: () => context.pushNamed(
                          RouteNames.studentBatchDetail,
                          pathParameters: {'batchId': batch.batchId},
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HubActionsCard extends StatelessWidget {
  const _HubActionsCard({
    required this.onJoin,
    required this.onAnnouncements,
  });

  final VoidCallback onJoin;
  final VoidCallback onAnnouncements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class batches',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join with an invite code or open announcements from batches on your roster.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAnnouncements,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Class announcements'),
              ),
              FilledButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.vpn_key_rounded),
                label: const Text('Join batch'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JoinRequestsSection extends StatelessWidget {
  const _JoinRequestsSection({
    required this.requestsAsync,
    required this.rosterBatches,
  });

  final AsyncValue<List<StudentJoinRequestItem>> requestsAsync;
  final List<TeacherBatchModel> rosterBatches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleById = {
      for (final batch in rosterBatches) batch.batchId: batch.title,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join requests',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pending, approved, and denied requests you submitted.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          requestsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Unable to load join requests. If this persists, an index may still be building.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No join requests yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _JoinRequestTile(
                      item: items[i],
                      batchTitle: titleById[items[i].batchId],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  const _JoinRequestTile({
    required this.item,
    required this.batchTitle,
  });

  final StudentJoinRequestItem item;
  final String? batchTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = TeacherBatchJoinRequestStatus.normalize(item.request.status);
    final label = TeacherBatchJoinRequestStatus.label(status);
    final title = (batchTitle != null && batchTitle!.trim().isNotEmpty)
        ? batchTitle!.trim()
        : (item.batchId.isEmpty
              ? 'Class batch'
              : 'Class batch · ${item.batchId.length > 8 ? item.batchId.substring(0, 8) : item.batchId}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd().add_jm().format(item.request.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusChip(
            label: label,
            color: switch (status) {
              TeacherBatchJoinRequestStatus.approved => AppColors.success,
              TeacherBatchJoinRequestStatus.denied => AppColors.error,
              _ => theme.colorScheme.tertiary,
            },
          ),
        ],
      ),
    );
  }
}

class _StudentBatchCard extends StatelessWidget {
  const _StudentBatchCard({
    required this.batch,
    required this.onOpen,
  });

  final TeacherBatchModel batch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snippet = batch.description.trim().isEmpty
        ? 'No description.'
        : batch.description.trim();
    final dateLabel = _formatDateRange(batch.startDate, batch.endDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      batch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: batch.isArchived ? 'Archived' : 'Active',
                    color: batch.isArchived
                        ? theme.colorScheme.outline
                        : AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _MetaChip(
                    icon: Icons.calendar_month_outlined,
                    label: dateLabel,
                  ),
                  _MetaChip(
                    icon: Icons.menu_book_outlined,
                    label: '${batch.courseIds.length} course'
                        '${batch.courseIds.length == 1 ? '' : 's'}',
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDateRange(DateTime? start, DateTime? end) {
  final fmt = DateFormat.yMMMd();
  if (start == null && end == null) return 'Dates TBD';
  if (start != null && end != null) {
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }
  if (start != null) return 'From ${fmt.format(start)}';
  return 'Until ${fmt.format(end!)}';
}
