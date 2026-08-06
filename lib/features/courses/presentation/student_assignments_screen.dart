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

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(publishedAssignmentsProvider(courseId));
    final projectAssignmentsAsync = ref.watch(
      publishedProjectAssignmentsProvider(courseId),
    );
    final theme = Theme.of(context);
    //     final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Student Work Hub',
      subtitle: 'Track assignments, deadlines, and project submissions.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentCourseLearn,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Failed to load assignments',
            message: error.toString(),
          ),
          data: (assignments) {
            final projectAssignments =
                projectAssignmentsAsync.value ?? const [];
            if (assignments.isEmpty && projectAssignments.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.assignment_outlined,
                title: 'No pending work',
                message:
                    'You have no assignments or projects to complete at this time.',
              );
            }

            return CoursePremiumListView(
              maxWidth: 900,
              children: [
                CourseHeroHeader(
                  icon: Icons.checklist_rtl_rounded,
                  title: 'Student Work Hub',
                  subtitle:
                      'Track your progress, manage deadlines, and submit your projects.',
                ),
                const SizedBox(height: 32),
                if (projectAssignments.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.folder_special_rounded,
                        color: AppColors.accent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Project Assignments',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...projectAssignments.map(
                    (assignment) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StudentProjectCard(
                        courseId: courseId,
                        assignment: assignment,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (assignments.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.quiz_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MCQ Assignments',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...assignments.map(
                    (assignment) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StudentAssignmentCard(
                        courseId: courseId,
                        assignment: assignment,
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
}

class _StudentProjectCard extends ConsumerStatefulWidget {
  const _StudentProjectCard({required this.courseId, required this.assignment});

  final String courseId;
  final ProjectAssignmentModel assignment;

  @override
  ConsumerState<_StudentProjectCard> createState() =>
      _StudentProjectCardState();
}

class _StudentProjectCardState extends ConsumerState<_StudentProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final submission = ref
        .watch(
          studentProjectSubmissionProvider((
            courseId: widget.courseId,
            assignmentId: widget.assignment.assignmentId,
          )),
        )
        .value;

    final isOverdue =
        widget.assignment.dueDate != null &&
        widget.assignment.dueDate!.isBefore(DateTime.now()) &&
        submission == null;

    final dueDateText = widget.assignment.dueDate == null
        ? 'No due date'
        : 'Due ${DateFormat('MMM d').format(widget.assignment.dueDate!)}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? AppColors.accent.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? (_isHovered ? 0.3 : 0.1)
                    : (_isHovered ? 0.1 : 0.02),
              ),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.pushNamed(
              submission == null
                  ? RouteNames.studentProjectSubmission
                  : RouteNames.studentProjectStatus,
              pathParameters: {
                'courseId': widget.courseId,
                'assignmentId': widget.assignment.assignmentId,
              },
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;

                  final content = [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PROJECT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.accent,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (submission != null)
                                _StatusBadge(status: submission.status)
                              else if (isOverdue)
                                _StatusBadge(status: 'Overdue', isError: true)
                              else
                                _StatusBadge(
                                  status: 'Pending',
                                  isWarning: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.assignment.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.assignment.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isOverdue
                                    ? AppColors.error
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dueDateText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue
                                      ? AppColors.error
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.stars_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.assignment.maxMarks} points',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: 24),
                    if (!isWide) const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.pushNamed(
                        submission == null
                            ? RouteNames.studentProjectSubmission
                            : RouteNames.studentProjectStatus,
                        pathParameters: {
                          'courseId': widget.courseId,
                          'assignmentId': widget.assignment.assignmentId,
                        },
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: submission == null
                            ? AppColors.accent
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: submission == null
                            ? Colors.white
                            : colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      icon: Icon(
                        submission == null
                            ? Icons.upload_rounded
                            : Icons.fact_check_rounded,
                        size: 20,
                      ),
                      label: Text(
                        submission == null ? 'Submit Project' : 'View Status',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: content,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentAssignmentCard extends ConsumerStatefulWidget {
  const _StudentAssignmentCard({
    required this.courseId,
    required this.assignment,
  });

  final String courseId;
  final McqAssignmentModel assignment;

  @override
  ConsumerState<_StudentAssignmentCard> createState() =>
      _StudentAssignmentCardState();
}

class _StudentAssignmentCardState
    extends ConsumerState<_StudentAssignmentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final attemptAsync = ref.watch(
      studentAssignmentAttemptProvider((
        courseId: widget.courseId,
        assignmentId: widget.assignment.assignmentId,
      )),
    );
    final actionState = ref.watch(assignmentActionProvider);
    final attempt = attemptAsync.value;

    final isSubmitted = attempt?.isSubmitted == true;
    final isOverdue =
        widget.assignment.dueDate != null &&
        widget.assignment.dueDate!.isBefore(DateTime.now()) &&
        !isSubmitted;

    final dueDateText = widget.assignment.dueDate == null
        ? 'No due date'
        : 'Due ${DateFormat('MMM d').format(widget.assignment.dueDate!)}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? (_isHovered ? 0.3 : 0.1)
                    : (_isHovered ? 0.1 : 0.02),
              ),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;

              final content = [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'MCQ EXAM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isSubmitted)
                            const _StatusBadge(
                              status: 'Completed',
                              isSuccess: true,
                            )
                          else if (isOverdue)
                            const _StatusBadge(status: 'Overdue', isError: true)
                          else
                            const _StatusBadge(
                              status: 'Pending',
                              isWarning: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.assignment.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.assignment.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: isOverdue
                                ? AppColors.error
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dueDateText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isOverdue
                                  ? AppColors.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.timer_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.assignment.timeLimitMinutes} min',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.assignment.totalMarks} points',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isWide) const SizedBox(width: 24),
                if (!isWide) const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: actionState.isLoading
                      ? null
                      : () => _openAssignment(context, isSubmitted),
                  style: FilledButton.styleFrom(
                    backgroundColor: isSubmitted
                        ? colorScheme.surfaceContainerHighest
                        : AppColors.primary,
                    foregroundColor: isSubmitted
                        ? colorScheme.onSurface
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  icon: actionState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isSubmitted
                              ? Icons.analytics_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                  label: Text(
                    isSubmitted ? 'View Result' : 'Start Exam',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: content,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openAssignment(BuildContext context, bool submitted) async {
    if (submitted) {
      context.pushNamed(
        RouteNames.studentAssignmentResult,
        pathParameters: {
          'courseId': widget.courseId,
          'assignmentId': widget.assignment.assignmentId,
        },
      );
      return;
    }

    final success = await ref
        .read(assignmentActionProvider.notifier)
        .startAttempt(
          courseId: widget.courseId,
          assignmentId: widget.assignment.assignmentId,
        );
    if (!context.mounted) return;
    if (!success) {
      final message =
          ref.read(assignmentActionProvider.notifier).errorMessage ??
          'Unable to start assignment.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    context.pushNamed(
      RouteNames.studentAssignmentAttempt,
      pathParameters: {
        'courseId': widget.courseId,
        'assignmentId': widget.assignment.assignmentId,
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    this.isSuccess = false,
    this.isWarning = false,
    this.isError = false,
  });
  final String status;
  final bool isSuccess;
  final bool isWarning;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    if (isSuccess || status.toLowerCase() == 'graded') {
      color = AppColors.success;
    } else if (isWarning || status.toLowerCase() == 'pending') {
      color = AppColors.warning;
    } else if (isError) {
      color = AppColors.error;
    } else if (status.toLowerCase() == 'submitted') {
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
