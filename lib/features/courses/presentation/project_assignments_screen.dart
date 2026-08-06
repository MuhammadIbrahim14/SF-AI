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

class ProjectAssignmentsScreen extends ConsumerWidget {
  const ProjectAssignmentsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(
      teacherProjectAssignmentsProvider(courseId),
    );
    final actionState = ref.watch(assignmentActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Project Assignments',
      subtitle: 'Create project briefs and review learner submissions.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherCourseLessons,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      actions: [
        FilledButton.icon(
          onPressed: () => context.pushNamed(
            RouteNames.teacherProjectAssignmentCreate,
            pathParameters: {'courseId': courseId},
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Project'),
        ),
      ],
      child: CoursePremiumBackground(
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (assignments) {
            if (assignments.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.folder_open_rounded,
                title: 'No project assignments yet',
                message:
                    'Create a project to challenge your learners with real-world tasks.',
              );
            }
            return CoursePremiumListView(
              maxWidth: 900,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.folder_special_rounded,
                  title: 'Projects Dashboard',
                  subtitle: 'Manage and review student project submissions.',
                ),
                const SizedBox(height: 24),
                ...assignments.map(
                  (assignment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ProjectCard(
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
                          : () =>
                                _publish(context, ref, assignment.assignmentId),
                      onArchive: assignment.isArchived
                          ? null
                          : () =>
                                _archive(context, ref, assignment.assignmentId),
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _publish(
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
    _showResult(context, ref, success, 'Project assignment published.');
  }

  Future<void> _archive(
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
    _showResult(context, ref, success, 'Project assignment archived.');
  }

  void _showResult(
    BuildContext context,
    WidgetRef ref,
    bool success,
    String successMessage,
  ) {
    final message = success
        ? successMessage
        : ref.read(assignmentActionProvider.notifier).errorMessage ??
              'Unable to update project assignment.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
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
                  .take(4)
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
