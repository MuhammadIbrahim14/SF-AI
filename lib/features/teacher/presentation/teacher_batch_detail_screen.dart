import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../courses/providers/course_provider.dart';
import '../providers/teacher_batch_provider.dart';
import '../utils/teacher_batch_csv_export.dart';
import 'teacher_batch_announcements_section.dart';
import 'teacher_batch_attendance_section.dart';
import 'teacher_batch_editor_dialog.dart';
import 'teacher_batch_invite_section.dart';
import 'teacher_batch_join_requests_section.dart';
import 'teacher_batch_risk_digest_section.dart';
import 'teacher_batch_sessions_section.dart';

class TeacherBatchDetailScreen extends ConsumerStatefulWidget {
  const TeacherBatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<TeacherBatchDetailScreen> createState() =>
      _TeacherBatchDetailScreenState();
}

class _TeacherBatchDetailScreenState
    extends ConsumerState<TeacherBatchDetailScreen> {
  bool _syncing = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(teacherBatchesProvider);
    final batch = ref.watch(teacherBatchByIdProvider(widget.batchId));
    final courses = ref.watch(teacherCoursesProvider).value ?? const [];
    final courseTitles = {
      for (final course in courses) course.id: course.title,
    };

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: batch?.title ?? 'Batch Detail',
      subtitle: 'Roster, progress, and course filters for this workspace.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.teacherBatches),
      scrollable: false,
      child: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load batch: $error')),
        data: (_) {
          if (batch == null) {
            return DashboardEmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Batch not found',
              message:
                  'This batch may have been removed or belongs to another teacher.',
              actionLabel: 'Back to Batches',
              onAction: () => context.goNamed(RouteNames.teacherBatches),
            );
          }
          final summary = ref.watch(teacherBatchProgressProvider(batch));
          final roster = ref.watch(teacherBatchRosterProvider(batch));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              _HeaderSection(
                batch: batch,
                onEdit: () => _edit(batch),
                onArchive: batch.isArchived
                    ? null
                    : () => _archive(batch),
                onUnarchive: batch.isArchived
                    ? () => _unarchive(batch)
                    : null,
                onSync: () => _sync(batch),
                onExportCsv: () => _exportCsv(batch, roster),
                syncing: _syncing,
                exporting: _exporting,
              ),
              const SizedBox(height: 16),
              _MetricStrip(batch: batch, summary: summary),
              const SizedBox(height: 16),
              TeacherBatchRiskDigestSection(summary: summary),
              const SizedBox(height: 16),
              _CoursesSection(
                courseIds: batch.courseIds,
                courseTitles: courseTitles,
              ),
              const SizedBox(height: 16),
              _RosterSection(roster: roster),
              const SizedBox(height: 16),
              TeacherBatchInviteSection(batch: batch),
              const SizedBox(height: 16),
              TeacherBatchJoinRequestsSection(batch: batch),
              const SizedBox(height: 16),
              TeacherBatchSessionsSection(batch: batch),
              const SizedBox(height: 16),
              TeacherBatchAttendanceSection(batch: batch),
              const SizedBox(height: 16),
              TeacherBatchAnnouncementsSection(
                batch: batch,
                courseTitles: [
                  for (final id in batch.courseIds)
                    courseTitles[id] ?? id,
                ],
              ),
              if (summary.commonWeakAreas.isNotEmpty) ...[
                const SizedBox(height: 16),
                _WeakAreasSection(areas: summary.commonWeakAreas),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(TeacherBatchModel batch) async {
    final saved = await showTeacherBatchEditorDialog(context, batch: batch);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Batch saved.')));
    }
  }

  Future<void> _archive(TeacherBatchModel batch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive batch?'),
        content: Text('Archive "${batch.title}"? Progress remains readable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .archiveBatch(batch);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Batch archived.' : 'Unable to archive batch.'),
      ),
    );
  }

  Future<void> _unarchive(TeacherBatchModel batch) async {
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .unarchiveBatch(batch);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Batch restored to Active.' : 'Unable to unarchive batch.',
        ),
      ),
    );
  }

  Future<void> _sync(TeacherBatchModel batch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync roster from enrollments?'),
        content: const Text(
          'Replaces student list with currently enrolled students '
          'across this batch’s selected courses. Manual roster edits '
          'will be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sync roster'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _syncing = true);
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .syncRosterFromEnrollments(batch);
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Roster replaced with currently enrolled students.'
              : 'Unable to sync roster.',
        ),
      ),
    );
  }

  Future<void> _exportCsv(
    TeacherBatchModel batch,
    List<TeacherBatchRosterEntry> roster,
  ) async {
    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Roster is empty — nothing to export.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final result = await exportTeacherBatchRosterCsv(
        batchTitle: batch.title,
        roster: roster,
      );
      if (!mounted) return;
      final message = result.downloaded
          ? 'CSV downloaded and copied to clipboard.'
          : 'CSV copied to clipboard.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export CSV: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.batch,
    required this.onEdit,
    required this.onArchive,
    required this.onUnarchive,
    required this.onSync,
    required this.onExportCsv,
    required this.syncing,
    required this.exporting,
  });

  final TeacherBatchModel batch;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback onSync;
  final VoidCallback onExportCsv;
  final bool syncing;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDateRange(batch.startDate, batch.endDate);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  batch.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(status: batch.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            batch.description.isEmpty
                ? 'No description added yet.'
                : batch.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              FilledButton.tonalIcon(
                onPressed: syncing || batch.courseIds.isEmpty ? null : onSync,
                icon: syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: const Text('Sync roster'),
              ),
              OutlinedButton.icon(
                onPressed: exporting ? null : onExportCsv,
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: const Text('Export CSV'),
              ),
              if (onArchive != null)
                TextButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Archive'),
                ),
              if (onUnarchive != null)
                TextButton.icon(
                  onPressed: onUnarchive,
                  icon: const Icon(Icons.unarchive_rounded),
                  label: const Text('Unarchive'),
                ),
            ],
          ),
          if (batch.courseIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Sync replaces the student list with currently enrolled students.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.batch, required this.summary});

  final TeacherBatchModel batch;
  final TeacherBatchProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final studentCount = batch.studentIds.isNotEmpty
        ? batch.studentIds.length
        : summary.totalStudents;
    final courseCount = batch.courseIds.isNotEmpty
        ? batch.courseIds.length
        : summary.assignedCourses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Metric('Students', studentCount.toString()),
          _Metric('Courses', courseCount.toString()),
          _Metric('Avg Progress', '${summary.averageProgress.round()}%'),
          _Metric('At Risk', summary.atRiskStudents.toString()),
          _Metric('Needs Attention', summary.needsAttentionStudents.toString()),
          _Metric('Pending Work', summary.pendingAssignments.toString()),
        ],
      ),
    );
  }
}

class _CoursesSection extends StatelessWidget {
  const _CoursesSection({
    required this.courseIds,
    required this.courseTitles,
  });

  final List<String> courseIds;
  final Map<String, String> courseTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Courses',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (courseIds.isEmpty)
            Text(
              'No courses assigned yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final courseId in courseIds)
                  Chip(
                    label: Text(courseTitles[courseId] ?? courseId),
                    backgroundColor: AppColors.teacherPrimary.withValues(
                      alpha: 0.1,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RosterSection extends StatelessWidget {
  const _RosterSection({required this.roster});

  final List<TeacherBatchRosterEntry> roster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Roster',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a student to open progress detail.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (roster.isEmpty)
            Text(
              'No students in this batch yet. Use Edit or Sync roster.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: [
                for (final entry in roster) ...[
                  _RosterRow(entry: entry),
                  if (entry != roster.last) const Divider(height: 1),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.entry});

  final TeacherBatchRosterEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riskLabel = entry.isAtRisk
        ? 'At Risk'
        : entry.needsAttention
        ? 'Needs Attention'
        : 'Healthy';
    final riskColor = entry.isAtRisk
        ? AppColors.error
        : entry.needsAttention
        ? AppColors.warning
        : AppColors.success;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.pushNamed(
        RouteNames.teacherStudentProgressDetail,
        pathParameters: {'studentId': entry.studentId},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.teacherPrimary.withValues(alpha: 0.15),
              child: Text(
                entry.studentName.isNotEmpty
                    ? entry.studentName.characters.first.toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.studentName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.studentEmail.isNotEmpty)
                    Text(
                      entry.studentEmail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (entry.riskReasons.isNotEmpty)
                    Text(
                      entry.riskReasons.take(2).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.averageProgress.round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  riskLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: riskColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeakAreasSection extends StatelessWidget {
  const _WeakAreasSection({required this.areas});

  final List<String> areas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Common weak areas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final area in areas)
                Chip(
                  label: Text(area),
                  backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.teacherPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final archived = status == TeacherBatchStatus.archived;
    final color = archived ? AppColors.warning : AppColors.success;
    return Chip(
      label: Text(archived ? 'Archived' : 'Active'),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      visualDensity: VisualDensity.compact,
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}

String _formatDateRange(DateTime? start, DateTime? end) {
  final formatter = DateFormat.yMMMd();
  if (start == null && end == null) return 'No schedule dates set';
  if (start != null && end != null) {
    return '${formatter.format(start)} – ${formatter.format(end)}';
  }
  if (start != null) return 'Starts ${formatter.format(start)}';
  return 'Ends ${formatter.format(end!)}';
}
