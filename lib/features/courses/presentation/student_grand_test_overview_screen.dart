import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/grand_test_attempt_model.dart';
import '../data/models/grand_test_eligibility_model.dart';
import '../data/models/grand_test_model.dart';
import '../providers/grand_test_provider.dart';
import 'course_premium_widgets.dart';

class StudentGrandTestOverviewScreen extends ConsumerWidget {
  const StudentGrandTestOverviewScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(publishedGrandTestsProvider(courseId));
    final publishedTests =
        testsAsync.whenOrNull(data: (tests) => tests) ??
        const <GrandTestModel>[];

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Certification Center',
      subtitle: 'Check grand test readiness and certification status.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentCourseLearn,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      actions: [
        if (publishedTests.isNotEmpty)
          FilledButton.icon(
            onPressed: () => _showReadinessSheet(context, publishedTests.first),
            icon: const Icon(Icons.shield_rounded),
            label: const Text('Readiness Check'),
          ),
      ],
      child: CoursePremiumBackground(
        child: testsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Error loading certification',
            message: error.toString(),
          ),
          data: (tests) {
            if (tests.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.lock_outline_rounded,
                title: 'Certification Locked',
                message:
                    'The final certification exam is not currently available.',
              );
            }

            return CoursePremiumListView(
              maxWidth: 1000,
              children: [
                const CourseHeroHeader(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Final Certification',
                  subtitle:
                      'Pass the Grand Test to earn your official certificate of completion.',
                ),
                const SizedBox(height: 32),
                ...tests.map(
                  (test) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _GrandTestOverviewCard(test: test),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showReadinessSheet(BuildContext context, GrandTestModel test) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final eligibilityAsync = ref.watch(
                    grandTestEligibilityProvider((
                      courseId: test.courseId,
                      grandTestId: test.grandTestId,
                    )),
                  );
                  final latestAttemptAsync = ref.watch(
                    latestStudentGrandTestAttemptProvider((
                      courseId: test.courseId,
                      grandTestId: test.grandTestId,
                    )),
                  );

                  return eligibilityAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text(error.toString())),
                    data: (eligibility) {
                      return latestAttemptAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            Center(child: Text(error.toString())),
                        data: (attempt) {
                          final summary = _ReadinessSummary.from(
                            eligibility,
                            attempt,
                          );
                          return _ReadinessReportSheet(
                            controller: scrollController,
                            title: test.title,
                            eligibility: eligibility,
                            summary: summary,
                            onPrimaryAction: summary.canStart
                                ? () {
                                    Navigator.of(context).pop();
                                    context.pushNamed(
                                      RouteNames.studentGrandTestAttempt,
                                      pathParameters: {
                                        'courseId': test.courseId,
                                        'grandTestId': test.grandTestId,
                                      },
                                    );
                                  }
                                : summary.hasSubmittedAttempt
                                ? () {
                                    Navigator.of(context).pop();
                                    context.pushNamed(
                                      RouteNames.studentGrandTestResult,
                                      pathParameters: {
                                        'courseId': test.courseId,
                                        'grandTestId': test.grandTestId,
                                      },
                                    );
                                  }
                                : () => Navigator.of(context).pop(),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _GrandTestOverviewCard extends ConsumerWidget {
  const _GrandTestOverviewCard({required this.test});

  final GrandTestModel test;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibilityAsync = ref.watch(
      grandTestEligibilityProvider((
        courseId: test.courseId,
        grandTestId: test.grandTestId,
      )),
    );
    final latestAttemptAsync = ref.watch(
      latestStudentGrandTestAttemptProvider((
        courseId: test.courseId,
        grandTestId: test.grandTestId,
      )),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 24),
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
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'CERTIFICATION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        test.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        test.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildStatItem(
                            context,
                            Icons.timer_rounded,
                            '${test.durationMinutes} min',
                            'Duration',
                          ),
                          _buildStatItem(
                            context,
                            Icons.stars_rounded,
                            '${test.totalMarks} pts',
                            'Total Marks',
                          ),
                          _buildStatItem(
                            context,
                            Icons.flag_rounded,
                            '${test.passingMarks} pts',
                            'Passing Score',
                          ),
                          _buildStatItem(
                            context,
                            Icons.trending_up_rounded,
                            test.difficulty,
                            'Difficulty',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: eligibilityAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
              data: (eligibility) {
                return latestAttemptAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text(error.toString()),
                  data: (attempt) {
                    final summary = _ReadinessSummary.from(
                      eligibility,
                      attempt,
                    );

                    return _EligibilityPanel(
                      eligibility: eligibility,
                      summary: summary,
                      onStart: summary.canStart
                          ? () => context.pushNamed(
                              RouteNames.studentGrandTestAttempt,
                              pathParameters: {
                                'courseId': test.courseId,
                                'grandTestId': test.grandTestId,
                              },
                            )
                          : null,
                      onViewResult: summary.hasSubmittedAttempt
                          ? () => context.pushNamed(
                              RouteNames.studentGrandTestResult,
                              pathParameters: {
                                'courseId': test.courseId,
                                'grandTestId': test.grandTestId,
                              },
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EligibilityPanel extends StatelessWidget {
  const _EligibilityPanel({
    required this.eligibility,
    required this.summary,
    required this.onStart,
    required this.onViewResult,
  });

  final GrandTestEligibilityModel eligibility;
  final _ReadinessSummary summary;
  final VoidCallback? onStart;
  final VoidCallback? onViewResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final submittedAttempt = summary.latestAttempt?.isSubmitted == true
        ? summary.latestAttempt
        : null;

    final bool canTake = summary.canStart;
    //     final bool isLocked = !eligibility.isEligible || summary.attemptLimitReached;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              submittedAttempt != null
                  ? Icons.verified_rounded
                  : (canTake ? Icons.lock_open_rounded : Icons.lock_rounded),
              color: submittedAttempt != null
                  ? AppColors.success
                  : (canTake ? AppColors.primary : AppColors.error),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submittedAttempt != null
                        ? 'Certification Exam Completed'
                        : canTake
                        ? 'Ready for Certification'
                        : 'Certification Locked',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    submittedAttempt != null
                        ? 'You have finalized your attempt. Check your detailed score report.'
                        : canTake
                        ? 'You meet all requirements and may begin the exam.'
                        : 'Complete all readiness checks to unlock the exam.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (submittedAttempt == null) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: eligibility.readinessPercent / 100,
                      strokeWidth: 6,
                      color: canTake
                          ? AppColors.primary
                          : (isDark ? Colors.white24 : Colors.black12),
                      backgroundColor: Colors.transparent,
                    ),
                    Text(
                      '${eligibility.readinessPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onStart ?? onViewResult,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: submittedAttempt != null
                      ? theme.colorScheme.surfaceContainerHighest
                      : (canTake
                            ? AppColors.primary
                            : theme.colorScheme.surfaceContainerHighest),
                  foregroundColor: submittedAttempt != null
                      ? theme.colorScheme.onSurface
                      : (canTake
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  submittedAttempt != null
                      ? Icons.analytics_rounded
                      : (canTake
                            ? Icons.play_arrow_rounded
                            : Icons.lock_rounded),
                ),
                label: Text(
                  submittedAttempt != null
                      ? 'View Score Report'
                      : canTake
                      ? 'Start Exam Now'
                      : 'Locked',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadinessSummary {
  const _ReadinessSummary({
    required this.latestAttempt,
    required this.hasSubmittedAttempt,
    required this.hasInProgressAttempt,
    required this.attemptsUsed,
    required this.attemptsRemaining,
    required this.attemptLimitReached,
    required this.canStart,
  });

  final GrandTestAttemptModel? latestAttempt;
  final bool hasSubmittedAttempt;
  final bool hasInProgressAttempt;
  final int attemptsUsed;
  final int attemptsRemaining;
  final bool attemptLimitReached;
  final bool canStart;

  factory _ReadinessSummary.from(
    GrandTestEligibilityModel eligibility,
    GrandTestAttemptModel? attempt,
  ) {
    final hasSubmittedAttempt = attempt?.isSubmitted == true;
    final hasInProgressAttempt = attempt?.isInProgress == true;
    final attemptsUsedFromLatest = attempt?.attemptNumber ?? 0;
    final attemptsUsed = eligibility.attemptsUsed > attemptsUsedFromLatest
        ? eligibility.attemptsUsed
        : attemptsUsedFromLatest;
    final attemptsRemaining = (eligibility.maxAttempts - attemptsUsed).clamp(
      0,
      eligibility.maxAttempts,
    );
    final attemptLimitReached =
        hasSubmittedAttempt && attemptsUsed >= eligibility.maxAttempts;
    final canStart =
        hasInProgressAttempt ||
        (eligibility.isEligible && !attemptLimitReached);

    return _ReadinessSummary(
      latestAttempt: attempt,
      hasSubmittedAttempt: hasSubmittedAttempt,
      hasInProgressAttempt: hasInProgressAttempt,
      attemptsUsed: attemptsUsed,
      attemptsRemaining: attemptsRemaining,
      attemptLimitReached: attemptLimitReached,
      canStart: canStart,
    );
  }
}

class _ReadinessReportSheet extends StatelessWidget {
  const _ReadinessReportSheet({
    required this.controller,
    required this.title,
    required this.eligibility,
    required this.summary,
    required this.onPrimaryAction,
  });

  final ScrollController controller;
  final String title;
  final GrandTestEligibilityModel eligibility;
  final _ReadinessSummary summary;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final submittedAttempt = summary.latestAttempt?.isSubmitted == true
        ? summary.latestAttempt
        : null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Readiness Report',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Requirements Checklist',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              _ChecklistRow(
                label:
                    'Lesson Progress (${eligibility.lessonProgress.toStringAsFixed(0)}% / ${eligibility.requiredLessonProgressPercent.toStringAsFixed(0)}%)',
                passed:
                    eligibility.lessonProgress >=
                    eligibility.requiredLessonProgressPercent,
              ),
              const SizedBox(height: 16),
              _ChecklistRow(
                label:
                    'Assignment Completion (${eligibility.assignmentCompletion.toStringAsFixed(0)}% / ${eligibility.requiredAssignmentCompletionPercent.toStringAsFixed(0)}%)',
                passed:
                    eligibility.assignmentCompletion >=
                    eligibility.requiredAssignmentCompletionPercent,
              ),
              const SizedBox(height: 16),
              _ChecklistRow(
                label:
                    'Average Score (${eligibility.averageScore.toStringAsFixed(0)}% / ${eligibility.requiredAverageScorePercent.toStringAsFixed(0)}%)',
                passed:
                    eligibility.averageScore >=
                    eligibility.requiredAverageScorePercent,
              ),
              const SizedBox(height: 16),
              _ChecklistRow(
                label: eligibility.projectSubmitted
                    ? 'Project Submitted'
                    : 'Project Submission Pending',
                passed: eligibility.projectSubmitted,
              ),
              const SizedBox(height: 16),
              _ChecklistRow(
                label:
                    'Attempts Remaining: ${summary.attemptsRemaining} of ${eligibility.maxAttempts}',
                passed:
                    submittedAttempt != null || summary.attemptsRemaining > 0,
              ),
            ],
          ),
        ),

        if (eligibility.missingRequirements.isNotEmpty &&
            submittedAttempt == null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Missing Requirements',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final item in eligibility.missingRequirements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              color: AppColors.error,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        if (eligibility.recommendations.isNotEmpty &&
            submittedAttempt == null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recommendations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final item in eligibility.recommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 40),
        FilledButton.icon(
          onPressed: onPrimaryAction,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: submittedAttempt != null
                ? theme.colorScheme.surfaceContainerHighest
                : (summary.canStart
                      ? AppColors.primary
                      : theme.colorScheme.surfaceContainerHighest),
            foregroundColor: submittedAttempt != null
                ? theme.colorScheme.onSurface
                : (summary.canStart
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: Icon(
            submittedAttempt != null
                ? Icons.analytics_rounded
                : (summary.canStart
                      ? Icons.play_arrow_rounded
                      : Icons.lock_rounded),
            size: 24,
          ),
          label: Text(
            submittedAttempt != null
                ? 'View Score Report'
                : (summary.canStart ? 'Start Exam Now' : 'Locked'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: passed
                ? AppColors.success.withValues(alpha: 0.1)
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            passed ? Icons.check_rounded : Icons.close_rounded,
            size: 16,
            color: passed
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: passed ? FontWeight.w700 : FontWeight.w500,
              color: passed
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
