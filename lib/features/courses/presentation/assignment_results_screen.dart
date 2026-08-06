import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class AssignmentResultsScreen extends ConsumerWidget {
  const AssignmentResultsScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  final String courseId;
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(
      assignmentDetailProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );
    final attemptsAsync = ref.watch(
      assignmentAttemptsProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Assessment Results',
      subtitle: 'Review submissions, marks, warnings, and pass status.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherAssignments,
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
                title: 'Assignment not found',
                message: 'This assignment may have been removed.',
              );
            }
            return attemptsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (attempts) {
                return CoursePremiumListView(
                  maxWidth: 900,
                  bottomPadding: 96,
                  children: [
                    CourseHeroHeader(
                      icon: Icons.analytics_rounded,
                      title: 'Result Analytics',
                      subtitle:
                          'Overview of student performance for ${assignment.title}',
                    ),
                    const SizedBox(height: 24),
                    CourseGlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatColumn(
                            label: 'SUBMISSIONS',
                            value: attempts.length.toString(),
                            icon: Icons.people_alt_rounded,
                            color: AppColors.primary,
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Theme.of(context).dividerColor,
                          ),
                          _StatColumn(
                            label: 'TOTAL MARKS',
                            value: assignment.totalMarks.toString(),
                            icon: Icons.military_tech_rounded,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rtl_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Student Attempts',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (attempts.isEmpty)
                      const CoursePremiumMessage(
                        icon: Icons.hourglass_empty_rounded,
                        title: 'No submissions yet',
                        message:
                            'Students have not completed this assignment yet.',
                      )
                    else
                      ...attempts.map((attempt) {
                        final submittedAt = attempt.submittedAt == null
                            ? 'Submitted'
                            : DateFormat(
                                'MMM d, yyyy • h:mm a',
                              ).format(attempt.submittedAt!);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StudentResultCard(
                            studentId: attempt.studentId,
                            score: attempt.score,
                            percentage: attempt.percentage,
                            totalMarks: assignment.totalMarks,
                            warnings: attempt.warningsCount,
                            passed: attempt.passed,
                            submittedAt: submittedAt,
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}

class _StudentResultCard extends StatelessWidget {
  const _StudentResultCard({
    required this.studentId,
    required this.score,
    required this.percentage,
    required this.totalMarks,
    required this.warnings,
    required this.passed,
    required this.submittedAt,
  });

  final String studentId;
  final int score;
  final double percentage;
  final int totalMarks;
  final int warnings;
  final bool passed;
  final String submittedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statusColor = passed ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.1),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student $studentId',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  submittedAt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (warnings > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$warnings Warnings',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  passed ? 'PASSED' : 'FAILED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
