import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/grand_test_provider.dart';
import 'course_premium_widgets.dart';

class GrandTestResultScreen extends ConsumerWidget {
  const GrandTestResultScreen({
    super.key,
    required this.courseId,
    required this.grandTestId,
  });

  final String courseId;
  final String grandTestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(
      grandTestDetailProvider((courseId: courseId, grandTestId: grandTestId)),
    );
    final attemptAsync = ref.watch(
      latestStudentGrandTestAttemptProvider((
        courseId: courseId,
        grandTestId: grandTestId,
      )),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Official Score Report',
      subtitle: 'Review your grand test performance and answer breakdown.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentGrandTestOverview,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,

      child: CoursePremiumBackground(
        child: testAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (test) {
            if (test == null) {
              return const Center(child: Text('Grand test not found.'));
            }
            return attemptAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (attempt) {
                if (attempt == null || !attempt.isSubmitted) {
                  return CoursePremiumMessage(
                    icon: Icons.pending_actions_rounded,
                    title: 'Result Unavailable',
                    message: 'No official score report found for this test.',
                    actionLabel: 'Return to Hub',
                    onAction: () => context.goNamed(
                      RouteNames.studentGrandTestOverview,
                      pathParameters: {'courseId': courseId},
                    ),
                  );
                }

                final passed = attempt.passed;

                return CoursePremiumListView(
                  maxWidth: 1000,
                  children: [
                    // Hero Result Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 48,
                      ),
                      decoration: BoxDecoration(
                        color: passed
                            ? AppColors.success.withValues(
                                alpha: isDark ? 0.05 : 0.02,
                              )
                            : AppColors.error.withValues(
                                alpha: isDark ? 0.05 : 0.02,
                              ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: passed
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.error.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (passed ? AppColors.success : AppColors.error)
                                    .withValues(alpha: isDark ? 0.1 : 0.05),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: passed
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              passed
                                  ? Icons.workspace_premium_rounded
                                  : Icons.info_outline_rounded,
                              size: 80,
                              color: passed
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            passed ? 'CERTIFICATION PASSED' : 'PRACTICE NEEDED',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: passed
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${attempt.percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 72,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You scored ${attempt.score} out of ${attempt.totalMarks} possible points.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              _StatPill(
                                icon: Icons.checklist_rounded,
                                label: 'Attempt #${attempt.attemptNumber}',
                              ),
                              _StatPill(
                                icon: Icons.warning_amber_rounded,
                                label: '${attempt.warningsCount} Warnings',
                                isWarning: attempt.warningsCount > 0,
                              ),
                              _StatPill(
                                icon: Icons.analytics_rounded,
                                label: attempt.status.replaceAll('_', ' '),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'Detailed Performance Review',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (test.questions.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.quiz_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Detailed review will appear here once the question data is available.',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'The score report is ready, but this assessment does not currently expose question-level review content.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...test.questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        final selected = attempt.answers[question.questionId];
                        final isCorrect =
                            selected?.trim().toLowerCase() ==
                            question.correctAnswer.trim().toLowerCase();
                        final questionText = question.question.trim().isNotEmpty
                            ? question.question.trim()
                            : 'Question ${index + 1}';
                        final userAnswer = selected?.trim().isNotEmpty == true
                            ? selected!.trim()
                            : 'Not answered';
                        final correctAnswer = question.correctAnswer.trim().isNotEmpty
                            ? question.correctAnswer.trim()
                            : 'Not provided';
                        final explanationText = question.explanation.trim().isNotEmpty
                            ? question.explanation.trim()
                            : 'No explanation provided for this question.';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1A1A)
                                : Colors.white,
                            border: Border(
                              left: BorderSide(
                                color: isCorrect
                                    ? AppColors.success
                                    : AppColors.error,
                                width: 4,
                              ),
                              top: BorderSide(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              right: BorderSide(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              bottom: BorderSide(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          (isCorrect
                                                  ? AppColors.success
                                                  : AppColors.error)
                                              .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCorrect
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      color: isCorrect
                                          ? AppColors.success
                                          : AppColors.error,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Question ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onSurfaceVariant,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          questionText,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                height: 1.4,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCorrect
                                          ? AppColors.success.withValues(
                                              alpha: 0.12,
                                            )
                                          : AppColors.error.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isCorrect ? 'Correct' : 'Needs Review',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: isCorrect
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.black.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAnswerRow(
                                      context,
                                      'Your Answer',
                                      userAnswer,
                                      !isCorrect,
                                    ),
                                    const Divider(height: 24),
                                    _buildAnswerRow(
                                      context,
                                      'Correct Answer',
                                      correctAnswer,
                                      false,
                                      isCorrectValue: true,
                                    ),
                                    const Divider(height: 24),
                                    Text(
                                      'Explanation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      explanationText,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 40),

                    FilledButton.icon(
                      onPressed: () => context.goNamed(
                        RouteNames.studentGrandTestOverview,
                        pathParameters: {'courseId': courseId},
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: theme.colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text(
                        'Return to Certification Center',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnswerRow(
    BuildContext context,
    String label,
    String value,
    bool isError, {
    bool isCorrectValue = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    Color valueColor = colorScheme.onSurface;
    if (isError) valueColor = AppColors.error;
    if (isCorrectValue) valueColor = AppColors.success;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isWarning ? AppColors.warning : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.warning.withValues(alpha: 0.1)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning
              ? AppColors.warning.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
