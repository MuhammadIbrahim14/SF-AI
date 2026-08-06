import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/project_submission_model.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class ProjectSubmissionsScreen extends ConsumerWidget {
  const ProjectSubmissionsScreen({
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
    final submissionsAsync = ref.watch(
      projectSubmissionsProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Submissions Overview',
      subtitle: 'Review submitted project work and open grading workflows.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherProjectAssignments,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: assignmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (assignment) {
            if (assignment == null) {
              return const CoursePremiumMessage(
                icon: Icons.search_off_rounded,
                title: 'Project not found',
                message: 'This project assignment may have been removed.',
              );
            }
            return submissionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (submissions) {
                return CoursePremiumListView.builder(
                  maxWidth: 900,
                  bottomPadding: 96,
                  itemCount: 4 + (submissions.isEmpty ? 1 : submissions.length),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CourseHeroHeader(
                        icon: Icons.fact_check_rounded,
                        title: 'Project Submissions',
                        subtitle: 'Review student work for ${assignment.title}',
                      );
                    }
                    if (index == 1) return const SizedBox(height: 32);
                    if (index == 2) {
                      return Row(
                        children: [
                          const Icon(
                            Icons.inbox_rounded,
                            color: AppColors.secondary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Submitted Work',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${submissions.length}',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    if (index == 3) return const SizedBox(height: 16);

                    if (submissions.isEmpty) {
                      return const CoursePremiumMessage(
                        icon: Icons.hourglass_empty_rounded,
                        title: 'Inbox zero',
                        message:
                            'No students have submitted their projects yet.',
                      );
                    }

                    final submission = submissions[index - 4];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SubmissionCard(
                        courseId: courseId,
                        assignmentId: assignmentId,
                        submission: submission,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.courseId,
    required this.assignmentId,
    required this.submission,
  });

  final String courseId;
  final String assignmentId;
  final ProjectSubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPending = submission.status == ProjectSubmissionStatus.submitted;
    final isApproved = submission.status == ProjectSubmissionStatus.graded;

    final accentColor = isPending
        ? AppColors.primary
        : isApproved
        ? Colors.green
        : Colors.orange;

    final dateStr = DateFormat('MMM d • h:mm a').format(submission.submittedAt);

    return InkWell(
      onTap: () => context.pushNamed(
        RouteNames.teacherProjectReview,
        pathParameters: {
          'courseId': courseId,
          'assignmentId': assignmentId,
          'studentId': submission.studentId,
        },
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? accentColor.withValues(alpha: 0.5)
                : (isDark ? AppColors.divider : AppColors.lightDivider),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_rounded, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student ${submission.studentId}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!isPending) ...[
                        Icon(
                          Icons.military_tech_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${submission.marks} marks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPending ? 'NEEDS REVIEW' : submission.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
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
