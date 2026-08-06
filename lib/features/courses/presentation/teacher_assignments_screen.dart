import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/mcq_assignment_model.dart';
import '../data/models/project_assignment_model.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class TeacherAssignmentsScreen extends ConsumerWidget {
  const TeacherAssignmentsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider(courseId));
    final projectAssignmentsAsync = ref.watch(
      teacherProjectAssignmentsProvider(courseId),
    );
    final actionState = ref.watch(assignmentActionProvider);
    //     final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Assessment Command Center',
      subtitle: 'Create, publish, archive, and review course assessments.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherCourseLessons,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      actions: [
        if (MediaQuery.of(context).size.width >= 700)
          FilledButton.icon(
            onPressed: () => _showCreateAssignmentSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Assignment'),
          ),
      ],
      child: CoursePremiumBackground(
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (assignments) {
            final projectAssignments =
                projectAssignmentsAsync.value ??
                const <ProjectAssignmentModel>[];

            if (assignments.isEmpty && projectAssignments.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.assignment_outlined,
                title: 'No assessments yet',
                message:
                    'Create an MCQ or Project assignment to evaluate your learners.',
              );
            }

            return CoursePremiumListView(
              maxWidth: 900,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.assignment_rounded,
                  title: 'Assignments & Projects',
                  subtitle:
                      'Manage quizzes, projects, and grading in one unified workspace.',
                ),
                const SizedBox(height: 24),
                _CreateOptionsCard(courseId: courseId),
                const SizedBox(height: 32),
                if (assignments.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'MCQ Assignments',
                    count: assignments.length,
                    icon: Icons.quiz_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  ...assignments.map(
                    (assignment) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AssignmentCard(
                        assignment: assignment,
                        busy: actionState.isLoading,
                        onEdit: () => context.pushNamed(
                          RouteNames.teacherAssignmentEdit,
                          pathParameters: {
                            'courseId': courseId,
                            'assignmentId': assignment.assignmentId,
                          },
                        ),
                        onPublish: assignment.isPublished
                            ? null
                            : () => _publish(
                                context,
                                ref,
                                assignment.assignmentId,
                              ),
                        onArchive: assignment.isArchived
                            ? null
                            : () => _archive(
                                context,
                                ref,
                                assignment.assignmentId,
                              ),
                        onResults: () => context.pushNamed(
                          RouteNames.teacherAssignmentResults,
                          pathParameters: {
                            'courseId': courseId,
                            'assignmentId': assignment.assignmentId,
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                if (projectAssignments.isNotEmpty) ...[
                  if (assignments.isNotEmpty) const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'Project Assignments',
                    count: projectAssignments.length,
                    icon: Icons.folder_special_rounded,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 16),
                  ...projectAssignments.map(
                    (assignment) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ProjectAssignmentCard(
                        assignment: assignment,
                        busy: actionState.isLoading,
                        onEdit: () => context.pushNamed(
                          RouteNames.teacherProjectAssignmentEdit,
                          pathParameters: {
                            'courseId': courseId,
                            'assignmentId': assignment.assignmentId,
                          },
                        ),
                        onPublish: assignment.isPublished
                            ? null
                            : () => _publishProject(
                                context,
                                ref,
                                assignment.assignmentId,
                              ),
                        onArchive: assignment.isArchived
                            ? null
                            : () => _archiveProject(
                                context,
                                ref,
                                assignment.assignmentId,
                              ),
                        onSubmissions: () => context.pushNamed(
                          RouteNames.teacherProjectSubmissions,
                          pathParameters: {
                            'courseId': courseId,
                            'assignmentId': assignment.assignmentId,
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCreateAssignmentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.quiz_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'MCQ Assignment',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Timed quiz with auto scoring'),
                  onTap: () {
                    context.pop();
                    context.pushNamed(
                      RouteNames.teacherAssignmentCreate,
                      pathParameters: {'courseId': courseId},
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.folder_special_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                  title: const Text(
                    'Project Assignment',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Submission links and teacher grading'),
                  onTap: () {
                    context.pop();
                    context.pushNamed(
                      RouteNames.teacherProjectAssignmentCreate,
                      pathParameters: {'courseId': courseId},
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _publish(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final success = await ref
        .read(assignmentActionProvider.notifier)
        .publishAssignment(courseId: courseId, assignmentId: assignmentId);
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success: success,
      successMessage: 'Assignment published.',
      fallbackError: 'Unable to publish assignment.',
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final success = await ref
        .read(assignmentActionProvider.notifier)
        .archiveAssignment(courseId: courseId, assignmentId: assignmentId);
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success: success,
      successMessage: 'Assignment archived.',
      fallbackError: 'Unable to archive assignment.',
    );
  }

  Future<void> _publishProject(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final success = await ref
        .read(assignmentActionProvider.notifier)
        .publishProjectAssignment(
          courseId: courseId,
          assignmentId: assignmentId,
        );
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success: success,
      successMessage: 'Project assignment published.',
      fallbackError: 'Unable to publish project assignment.',
    );
  }

  Future<void> _archiveProject(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final success = await ref
        .read(assignmentActionProvider.notifier)
        .archiveProjectAssignment(
          courseId: courseId,
          assignmentId: assignmentId,
        );
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success: success,
      successMessage: 'Project assignment archived.',
      fallbackError: 'Unable to archive project assignment.',
    );
  }

  void _showResult(
    BuildContext context,
    WidgetRef ref, {
    required bool success,
    required String successMessage,
    required String fallbackError,
  }) {
    final message = success
        ? successMessage
        : ref.read(assignmentActionProvider.notifier).errorMessage ??
              fallbackError;
    if (!success && message.toLowerCase().contains('upgrade')) {
      showTeacherUpgradeDialog(
        context: context,
        ref: ref,
        message: message,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CreateOptionsCard extends StatelessWidget {
  const _CreateOptionsCard({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => context.pushNamed(
                  RouteNames.teacherAssignmentCreate,
                  pathParameters: {'courseId': courseId},
                ),
                icon: const Icon(Icons.quiz_rounded),
                label: const Text('Create MCQ'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.pushNamed(
                  RouteNames.teacherProjectAssignmentCreate,
                  pathParameters: {'courseId': courseId},
                ),
                icon: const Icon(Icons.folder_special_rounded),
                label: const Text('Create Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.busy,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
    required this.onResults,
  });

  final McqAssignmentModel assignment;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onArchive;
  final VoidCallback onResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dueDate = assignment.dueDate == null
        ? 'No due date'
        : 'Due ${DateFormat('MMM d, yyyy').format(assignment.dueDate!)}';

    final isPublished = assignment.isPublished;

    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          assignment.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusBadge(status: assignment.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          icon: Icons.calendar_today_rounded,
                          text: dueDate,
                        ),
                        _MetaPill(
                          icon: Icons.timer_rounded,
                          text: '${assignment.timeLimitMinutes} min',
                        ),
                        _MetaPill(
                          icon: Icons.military_tech_rounded,
                          text: '${assignment.totalMarks} marks',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            assignment.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isPublished)
                FilledButton.icon(
                  onPressed: onResults,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text(
                    'View Results',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text(
                    'Publish MCQ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              if (!assignment.isArchived)
                TextButton.icon(
                  onPressed: busy ? null : onArchive,
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Archive'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectAssignmentCard extends StatelessWidget {
  const _ProjectAssignmentCard({
    required this.assignment,
    required this.busy,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
    required this.onSubmissions,
  });

  final ProjectAssignmentModel assignment;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onArchive;
  final VoidCallback onSubmissions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dueDate = assignment.dueDate == null
        ? 'No due date'
        : 'Due ${DateFormat('MMM d, yyyy').format(assignment.dueDate!)}';

    final isPublished = assignment.isPublished;

    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          assignment.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusBadge(status: assignment.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          icon: Icons.calendar_today_rounded,
                          text: dueDate,
                        ),
                        _MetaPill(
                          icon: Icons.military_tech_rounded,
                          text: 'Max ${assignment.maxMarks} marks',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            assignment.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (assignment.skillsCovered.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignment.skillsCovered
                  .take(3)
                  .map(
                    (skill) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isPublished)
                FilledButton.icon(
                  onPressed: onSubmissions,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text(
                    'Review Submissions',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text(
                    'Publish Project',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              if (!assignment.isArchived)
                TextButton.icon(
                  onPressed: busy ? null : onArchive,
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Archive'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPublished = status == AssignmentStatus.published;
    final isArchived = status == AssignmentStatus.archived;

    final color = isPublished
        ? Colors.green
        : isArchived
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }
}
