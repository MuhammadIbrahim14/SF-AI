import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/teacher_batch_provider.dart';
import '../providers/teacher_student_progress_provider.dart';

class TeacherBatchesCompareScreen extends ConsumerWidget {
  const TeacherBatchesCompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(teacherBatchesProvider);
    final progressLoading = ref.watch(teacherStudentProgressProvider).isLoading;

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Compare Batches',
      subtitle: 'Side-by-side progress and risk for active batches.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.teacherBatches),
      scrollable: false,
      child: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load batches: $error')),
        data: (batches) {
          final active = batches.where((b) => !b.isArchived).toList()
            ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          if (active.isEmpty) {
            return DashboardEmptyState(
              icon: Icons.compare_arrows_rounded,
              title: 'No active batches',
              message: 'Create or unarchive batches to compare progress and risk.',
              actionLabel: 'Back to Batches',
              onAction: () => context.goNamed(RouteNames.teacherBatches),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(context),
                child: Text(
                  progressLoading
                      ? 'Progress is still loading — counts may update shortly.'
                      : 'Comparing ${active.length} active batch'
                          '${active.length == 1 ? '' : 'es'}. '
                          'Tap a row to open batch detail.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CompareTable(batches: active),
            ],
          );
        },
      ),
    );
  }
}

class _CompareTable extends ConsumerWidget {
  const _CompareTable({required this.batches});

  final List<TeacherBatchModel> batches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 40,
          ),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStatePropertyAll(
              AppColors.teacherPrimary.withValues(alpha: 0.08),
            ),
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('Batch')),
              DataColumn(label: Text('Students'), numeric: true),
              DataColumn(label: Text('Courses'), numeric: true),
              DataColumn(label: Text('Avg %'), numeric: true),
              DataColumn(label: Text('At Risk'), numeric: true),
              DataColumn(label: Text('Pending'), numeric: true),
              DataColumn(label: Text('GT Pass'), numeric: true),
              DataColumn(label: Text('GT Fail'), numeric: true),
            ],
            rows: [
              for (final batch in batches)
                _row(context, ref, theme, batch),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    TeacherBatchModel batch,
  ) {
    final summary = ref.watch(teacherBatchProgressProvider(batch));
    final students = batch.studentIds.isNotEmpty
        ? batch.studentIds.length
        : summary.totalStudents;
    final courses = batch.courseIds.isNotEmpty
        ? batch.courseIds.length
        : summary.assignedCourses;

    return DataRow(
      onSelectChanged: (_) => context.pushNamed(
        RouteNames.teacherBatchDetail,
        pathParameters: {'batchId': batch.batchId},
      ),
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              batch.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        DataCell(Text('$students')),
        DataCell(Text('$courses')),
        DataCell(Text('${summary.averageProgress.round()}')),
        DataCell(
          Text(
            '${summary.atRiskStudents}',
            style: TextStyle(
              fontWeight: summary.atRiskStudents > 0
                  ? FontWeight.w900
                  : FontWeight.w500,
              color: summary.atRiskStudents > 0 ? AppColors.error : null,
            ),
          ),
        ),
        DataCell(Text('${summary.pendingAssignments}')),
        DataCell(Text('${summary.grandTestsPassed}')),
        DataCell(
          Text(
            '${summary.grandTestsFailed}',
            style: TextStyle(
              fontWeight: summary.grandTestsFailed > 0
                  ? FontWeight.w900
                  : FontWeight.w500,
              color: summary.grandTestsFailed > 0 ? AppColors.error : null,
            ),
          ),
        ),
      ],
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
