import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../courses/providers/course_provider.dart';
import '../providers/teacher_batch_provider.dart';
import '../providers/teacher_student_progress_provider.dart';
import 'teacher_batch_editor_dialog.dart';

enum _BatchStatusFilter { active, archived, all }

enum _BatchSort { updatedAt, title, atRisk }

class TeacherBatchesScreen extends ConsumerStatefulWidget {
  const TeacherBatchesScreen({super.key});

  @override
  ConsumerState<TeacherBatchesScreen> createState() =>
      _TeacherBatchesScreenState();
}

class _TeacherBatchesScreenState extends ConsumerState<TeacherBatchesScreen> {
  _BatchStatusFilter _statusFilter = _BatchStatusFilter.active;
  _BatchSort _sort = _BatchSort.updatedAt;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(teacherBatchesProvider);
    final courses = ref.watch(teacherCoursesProvider).value ?? const [];
    final progressLoading = ref.watch(teacherStudentProgressProvider).isLoading;

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Batch Management',
      subtitle: 'Organize students, assign courses, and track class risk.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.teacherDashboard),
      scrollable: false,
      child: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load batches: $error')),
        data: (batches) {
          final filtered = _filterAndSort(batches);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              _HeaderCard(
                onCreate: () => _openEditor(),
                onCompare: () =>
                    context.pushNamed(RouteNames.teacherBatchesCompare),
              ),
              const SizedBox(height: 16),
              _FilterBar(
                statusFilter: _statusFilter,
                sort: _sort,
                searchController: _searchController,
                onStatusChanged: (value) =>
                    setState(() => _statusFilter = value),
                onSortChanged: (value) => setState(() => _sort = value),
                onSearchChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                DashboardEmptyState(
                  icon: Icons.groups_2_rounded,
                  title: batches.isEmpty
                      ? 'No batches yet'
                      : 'No batches match filters',
                  message: batches.isEmpty
                      ? 'Create a batch to group students, courses, and progress insights.'
                      : 'Try a different status, search, or sort option.',
                  actionLabel: batches.isEmpty ? 'Create Batch' : null,
                  onAction: batches.isEmpty ? () => _openEditor() : null,
                )
              else
                ResponsiveGrid(
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 2,
                  wideColumns: 3,
                  minChildWidth: 320,
                  children: [
                    for (final batch in filtered)
                      _BatchCard(
                        batch: batch,
                        courseTitles: {
                          for (final course in courses) course.id: course.title,
                        },
                        progressLoading: progressLoading,
                        onOpen: () => context.pushNamed(
                          RouteNames.teacherBatchDetail,
                          pathParameters: {'batchId': batch.batchId},
                        ),
                        onEdit: () => _openEditor(batch: batch),
                        onArchive: batch.isArchived
                            ? null
                            : () => _archiveBatch(batch),
                        onUnarchive: batch.isArchived
                            ? () => _unarchiveBatch(batch)
                            : null,
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  List<TeacherBatchModel> _filterAndSort(List<TeacherBatchModel> batches) {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = batches.where((batch) {
      switch (_statusFilter) {
        case _BatchStatusFilter.active:
          if (batch.isArchived) return false;
        case _BatchStatusFilter.archived:
          if (!batch.isArchived) return false;
        case _BatchStatusFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return batch.title.toLowerCase().contains(query) ||
          batch.description.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case _BatchSort.updatedAt:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _BatchSort.title:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _BatchSort.atRisk:
        filtered.sort((a, b) {
          final aRisk = ref
              .read(teacherBatchProgressProvider(a))
              .atRiskStudents;
          final bRisk = ref
              .read(teacherBatchProgressProvider(b))
              .atRiskStudents;
          final byRisk = bRisk.compareTo(aRisk);
          if (byRisk != 0) return byRisk;
          return b.updatedAt.compareTo(a.updatedAt);
        });
    }
    return filtered;
  }

  Future<void> _openEditor({TeacherBatchModel? batch}) async {
    final saved = await showTeacherBatchEditorDialog(context, batch: batch);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Batch saved.')));
    }
  }

  Future<void> _archiveBatch(TeacherBatchModel batch) async {
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

  Future<void> _unarchiveBatch(TeacherBatchModel batch) async {
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
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.onCreate, required this.onCompare});

  final VoidCallback onCreate;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher Batch Command Center',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Batches are private teacher workspaces. They use existing enrollments and progress data, so no student data is exposed to other students.',
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
                onPressed: onCompare,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text('Compare batches'),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Batch'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusFilter,
    required this.sort,
    required this.searchController,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onSearchChanged,
  });

  final _BatchStatusFilter statusFilter;
  final _BatchSort sort;
  final TextEditingController searchController;
  final ValueChanged<_BatchStatusFilter> onStatusChanged;
  final ValueChanged<_BatchSort> onSortChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_BatchStatusFilter>(
            segments: const [
              ButtonSegment(
                value: _BatchStatusFilter.active,
                label: Text('Active'),
                icon: Icon(Icons.check_circle_outline_rounded),
              ),
              ButtonSegment(
                value: _BatchStatusFilter.archived,
                label: Text('Archived'),
                icon: Icon(Icons.archive_outlined),
              ),
              ButtonSegment(
                value: _BatchStatusFilter.all,
                label: Text('All'),
                icon: Icon(Icons.layers_outlined),
              ),
            ],
            selected: {statusFilter},
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              onStatusChanged(value.first);
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final search = TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by title',
                  isDense: true,
                ),
                onChanged: onSearchChanged,
              );
              final sortField = DropdownButtonFormField<_BatchSort>(
                initialValue: sort,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: _BatchSort.updatedAt,
                    child: Text('Updated'),
                  ),
                  DropdownMenuItem(
                    value: _BatchSort.title,
                    child: Text('Title'),
                  ),
                  DropdownMenuItem(
                    value: _BatchSort.atRisk,
                    child: Text('At-risk count'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: search),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: sortField),
                  ],
                );
              }
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  sortField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BatchCard extends ConsumerWidget {
  const _BatchCard({
    required this.batch,
    required this.courseTitles,
    required this.progressLoading,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onUnarchive,
  });

  final TeacherBatchModel batch;
  final Map<String, String> courseTitles;
  final bool progressLoading;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(teacherBatchProgressProvider(batch));
    final theme = Theme.of(context);
    final titles = batch.courseIds
        .map((id) => courseTitles[id] ?? id)
        .take(3)
        .join(', ');
    final dateLabel = _formatDateRange(batch.startDate, batch.endDate);

    // Prefer roster / selected course counts while progress is still loading.
    final studentCount = progressLoading
        ? (batch.studentIds.isNotEmpty
              ? batch.studentIds.length
              : summary.totalStudents)
        : summary.totalStudents;
    final courseCount = progressLoading
        ? (batch.courseIds.isNotEmpty
              ? batch.courseIds.length
              : summary.assignedCourses)
        : summary.assignedCourses;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(context),
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
                  _StatusChip(status: batch.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                batch.description.isEmpty
                    ? 'No description added yet.'
                    : batch.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                titles.isEmpty ? 'No assigned courses yet.' : titles,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric('Students', studentCount.toString()),
                  _Metric('Courses', courseCount.toString()),
                  _Metric(
                    'Avg Progress',
                    '${summary.averageProgress.round()}%',
                  ),
                  _Metric('At Risk', summary.atRiskStudents.toString()),
                  _Metric(
                    'Pending Work',
                    summary.pendingAssignments.toString(),
                  ),
                ],
              ),
              if (summary.commonWeakAreas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Weak areas: ${summary.commonWeakAreas.take(2).join(' · ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
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
            ],
          ),
        ),
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
