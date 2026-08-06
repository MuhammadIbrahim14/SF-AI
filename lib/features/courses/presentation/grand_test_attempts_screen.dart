import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/grand_test_provider.dart';
import 'course_premium_widgets.dart';

class GrandTestAttemptsScreen extends ConsumerWidget {
  const GrandTestAttemptsScreen({
    super.key,
    required this.courseId,
    required this.grandTestId,
  });

  final String courseId;
  final String grandTestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(
      grandTestAttemptsProvider((courseId: courseId, grandTestId: grandTestId)),
    );

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Exam Attempts',
      subtitle: 'Review submitted grand test attempts and warning flags.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherGrandTests,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: attemptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (attempts) {
            if (attempts.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.analytics_outlined,
                title: 'No attempts yet',
                message: 'Submitted exam attempts will appear here.',
              );
            }
            return CoursePremiumListView(
              maxWidth: 1000,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.analytics_rounded,
                  title: 'Exam Attempts Log',
                  subtitle:
                      'Review secure exam submissions, pass/fail status, and potential warning flags.',
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Submission Log',
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
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${attempts.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...attempts.map((attempt) {
                  final submittedAt = attempt.submittedAt;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CourseGlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: attempt.passed
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              border: Border.all(
                                color: attempt.passed
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              attempt.passed
                                  ? Icons.verified_rounded
                                  : Icons.cancel_rounded,
                              color: attempt.passed ? Colors.green : Colors.red,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Student ${attempt.studentId}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                            ),
                                      ),
                                    ),
                                    if (attempt.warningsCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 14,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${attempt.warningsCount} WARNINGS',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.orange,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  submittedAt == null
                                      ? 'Attempt in progress...'
                                      : 'Submitted ${DateFormat('MMM d, yyyy • h:mm a').format(submittedAt)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetricPill(
                                      icon: Icons.repeat_rounded,
                                      label:
                                          'Attempt #${attempt.attemptNumber}',
                                      color: Colors.blue,
                                    ),
                                    _MetricPill(
                                      icon: Icons.score_rounded,
                                      label:
                                          '${attempt.score} / ${attempt.totalMarks} Marks',
                                      color: attempt.passed
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    _MetricPill(
                                      icon: Icons.percent_rounded,
                                      label:
                                          '${attempt.percentage.toStringAsFixed(1)}%',
                                      color: attempt.passed
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    _MetricPill(
                                      icon: Icons.timer_rounded,
                                      label:
                                          '${(attempt.timeTakenSeconds / 60).toStringAsFixed(1)} min taken',
                                      color: Colors.purple,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
