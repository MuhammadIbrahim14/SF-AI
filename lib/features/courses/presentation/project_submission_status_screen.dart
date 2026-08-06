import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class ProjectSubmissionStatusScreen extends ConsumerWidget {
  const ProjectSubmissionStatusScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  final String courseId;
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(
      projectAssignmentDetailProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );
    final submissionAsync = ref.watch(
      studentProjectSubmissionProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Review Status',
      subtitle: 'Track project review, feedback, links, and score.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentCourseLearn,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: assignmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Error loading assignment',
            message: error.toString(),
          ),
          data: (assignment) {
            if (assignment == null) {
              return const CoursePremiumMessage(
                icon: Icons.find_in_page_rounded,
                title: 'Not Found',
                message: 'Project assignment not found.',
              );
            }
            return submissionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (submission) {
                if (submission == null) {
                  return CoursePremiumMessage(
                    icon: Icons.upload_file_rounded,
                    title: 'No submission found',
                    message: 'You have not submitted this project yet.',
                    actionLabel: 'Submit Project Now',
                    onAction: () => context.goNamed(
                      RouteNames.studentProjectSubmission,
                      pathParameters: {
                        'courseId': courseId,
                        'assignmentId': assignmentId,
                      },
                    ),
                  );
                }

                final isGraded = submission.status.toLowerCase() == 'graded';
                final isReviewing =
                    submission.status.toLowerCase() == 'under review';
                //                   final isRejected = submission.status.toLowerCase() == 'changes requested' || submission.status.toLowerCase() == 'rejected';

                return CoursePremiumListView(
                  maxWidth: 1000,
                  children: [
                    CourseHeroHeader(
                      icon: isGraded
                          ? Icons.workspace_premium_rounded
                          : (isReviewing
                                ? Icons.pending_actions_rounded
                                : Icons.fact_check_rounded),
                      title: 'Project Status',
                      subtitle: 'Track your deployment review and feedback.',
                    ),
                    const SizedBox(height: 32),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;

                        final mainContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeline(context, submission.status),
                            const SizedBox(height: 32),
                            if (submission.feedback.trim().isNotEmpty) ...[
                              _buildFeedbackCard(
                                context,
                                submission.feedback,
                                isDark,
                              ),
                              const SizedBox(height: 32),
                            ],
                            _buildLinksCard(
                              context,
                              submission.githubLink,
                              submission.liveDemoLink,
                              isDark,
                            ),
                          ],
                        );

                        final sidebarContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildScoreCard(
                              context,
                              submission.marks,
                              submission.maxMarks,
                              submission.percentage,
                              isDark,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: isGraded
                                  ? null
                                  : () => context.goNamed(
                                      RouteNames.studentProjectSubmission,
                                      pathParameters: {
                                        'courseId': courseId,
                                        'assignmentId': assignmentId,
                                      },
                                    ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                foregroundColor: colorScheme.onSurface,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              label: const Text(
                                'Update Submission',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: mainContent),
                              const SizedBox(width: 40),
                              Expanded(flex: 4, child: sidebarContent),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            sidebarContent,
                            const SizedBox(height: 40),
                            mainContent,
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, String currentStatus) {
    final statusLower = currentStatus.toLowerCase();

    int currentStep = 0;
    if (statusLower == 'graded') {
      currentStep = 3;
    } else if (statusLower == 'changes requested' ||
        statusLower == 'rejected') {
      currentStep = 2; // Treat as stuck at review phase
    } else if (statusLower == 'under review') {
      currentStep = 1;
    } else {
      currentStep = 0; // Submitted
    }

    final isRejected =
        statusLower == 'changes requested' || statusLower == 'rejected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deployment Pipeline',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        _TimelineStep(
          icon: Icons.cloud_upload_rounded,
          title: 'Submitted',
          subtitle: 'Your project has been deployed successfully.',
          isCompleted: currentStep >= 0,
          isActive: currentStep == 0,
        ),
        _TimelineDivider(isActive: currentStep >= 1),
        _TimelineStep(
          icon: Icons.remove_red_eye_rounded,
          title: 'Under Review',
          subtitle: 'The instructor is reviewing your code and demo.',
          isCompleted: currentStep >= 1,
          isActive: currentStep == 1,
        ),
        _TimelineDivider(
          isActive: currentStep >= 2,
          isError: isRejected && currentStep == 2,
        ),
        if (isRejected)
          _TimelineStep(
            icon: Icons.error_rounded,
            title: currentStatus.toUpperCase(),
            subtitle: 'The instructor has requested changes.',
            isCompleted: true,
            isActive: true,
            isError: true,
          )
        else
          _TimelineStep(
            icon: Icons.workspace_premium_rounded,
            title: 'Graded',
            subtitle: 'Feedback and marks have been finalized.',
            isCompleted: currentStep >= 3,
            isActive: currentStep == 3,
          ),
      ],
    );
  }

  Widget _buildFeedbackCard(
    BuildContext context,
    String feedback,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(
          left: const BorderSide(color: AppColors.accent, width: 4),
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: AppColors.accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Instructor Feedback',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            feedback,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksCard(
    BuildContext context,
    String githubLink,
    String liveDemoLink,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deployment Links',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          if (githubLink.trim().isNotEmpty) ...[
            _LinkRow(
              icon: Icons.code_rounded,
              label: 'Repository',
              url: githubLink,
            ),
            if (liveDemoLink.trim().isNotEmpty) const SizedBox(height: 16),
          ],
          if (liveDemoLink.trim().isNotEmpty)
            _LinkRow(
              icon: Icons.public_rounded,
              label: 'Live Demo',
              url: liveDemoLink,
            ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context,
    num marks,
    num maxMarks,
    double percentage,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGraded = marks > 0 || percentage > 0;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Evaluation',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: isGraded
                      ? (percentage / 100).clamp(0, 1).toDouble()
                      : 0,
                  strokeWidth: 12,
                  backgroundColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    isGraded
                        ? (percentage >= 50
                              ? AppColors.success
                              : AppColors.error)
                        : Colors.grey,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isGraded ? '${percentage.toStringAsFixed(0)}%' : 'N/A',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGraded ? 'Score' : 'Pending',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  isGraded
                      ? '${marks.toStringAsFixed(1)} / ${maxMarks.toStringAsFixed(1)} Marks'
                      : 'Not graded yet',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                url,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color primaryColor = AppColors.primary;
    if (isError) {
      primaryColor = AppColors.error;
    } else if (isCompleted) {
      primaryColor = AppColors.success;
    }

    if (!isCompleted && !isActive) {
      primaryColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? primaryColor
                : (isCompleted
                      ? primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? primaryColor
                  : (isCompleted
                        ? primaryColor
                        : primaryColor.withValues(alpha: 0.5)),
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted && !isError && !isActive ? Icons.check_rounded : icon,
            color: isActive ? Colors.white : primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isCompleted || isActive
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineDivider extends StatelessWidget {
  const _TimelineDivider({required this.isActive, this.isError = false});
  final bool isActive;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    Color color = isActive
        ? AppColors.success
        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);
    if (isError) color = AppColors.error;

    return Container(
      margin: const EdgeInsets.only(left: 23, top: 4, bottom: 4),
      width: 2,
      height: 32,
      decoration: BoxDecoration(color: color),
    );
  }
}
