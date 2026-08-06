import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/grand_test_attempt_model.dart';
import '../data/models/grand_test_eligibility_model.dart';
import '../providers/enrollment_provider.dart';
import '../providers/grand_test_provider.dart';
import 'course_premium_widgets.dart';

class GrandTestEligibilityScreen extends ConsumerWidget {
  const GrandTestEligibilityScreen({
    super.key,
    required this.courseId,
    required this.grandTestId,
  });

  final String courseId;
  final String grandTestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(courseEnrollmentsProvider(courseId));

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Exam Eligibility',
      subtitle:
          'See which students are ready and which requirements are blocking them.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherGrandTests,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: enrollmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (enrollments) {
            if (enrollments.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.groups_outlined,
                title: 'No enrolled students yet',
                message:
                    'Eligibility will appear here when students enroll in this course.',
              );
            }

            return CoursePremiumListView(
              maxWidth: 1000,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.verified_user_rounded,
                  title: 'Live Eligibility Check',
                  subtitle:
                      'Monitor student readiness and view requirements blocking their access to the grand test.',
                ),
                const SizedBox(height: 32),
                ...enrollments.map(
                  (enrollment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _EligibilityTile(
                      courseId: courseId,
                      grandTestId: grandTestId,
                      studentId: enrollment.studentId,
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
}

class _EligibilityTile extends ConsumerWidget {
  const _EligibilityTile({
    required this.courseId,
    required this.grandTestId,
    required this.studentId,
  });

  final String courseId;
  final String grandTestId;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibilityAsync = ref.watch(
      grandTestStudentEligibilityProvider((
        courseId: courseId,
        grandTestId: grandTestId,
        studentId: studentId,
      )),
    );
    final attemptsAsync = ref.watch(
      grandTestAttemptsProvider((courseId: courseId, grandTestId: grandTestId)),
    );

    return eligibilityAsync.when(
      loading: () => const CourseGlassCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => CourseGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error loading $studentId: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (eligibility) {
        final attempts = attemptsAsync.value ?? const <GrandTestAttemptModel>[];
        final studentAttempts =
            attempts.where((attempt) => attempt.studentId == studentId).toList()
              ..sort(
                (a, b) => (b.submittedAt ?? b.startedAt).compareTo(
                  a.submittedAt ?? a.startedAt,
                ),
              );
        final latestAttempt = studentAttempts.isEmpty
            ? null
            : studentAttempts.first;
        return _EligibilityCard(
          studentId: studentId,
          eligibility: eligibility,
          latestAttempt: latestAttempt,
        );
      },
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({
    required this.studentId,
    required this.eligibility,
    required this.latestAttempt,
  });

  final String studentId;
  final GrandTestEligibilityModel eligibility;
  final GrandTestAttemptModel? latestAttempt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final submittedAttempt = latestAttempt?.isSubmitted == true;
    final inProgressAttempt = latestAttempt?.isInProgress == true;
    final nearlyEligible =
        !submittedAttempt &&
        !eligibility.isEligible &&
        eligibility.readinessPercent >= 70;

    final statusColor = submittedAttempt
        ? (latestAttempt?.passed == true ? Colors.green : Colors.red)
        : inProgressAttempt
        ? colorScheme.primary
        : eligibility.isEligible
        ? Colors.green
        : nearlyEligible
        ? Colors.orange
        : Colors.red;

    final statusLabel = submittedAttempt
        ? (latestAttempt?.passed == true ? 'PASSED' : 'FAILED')
        : inProgressAttempt
        ? 'IN PROGRESS'
        : eligibility.isEligible
        ? 'ELIGIBLE'
        : nearlyEligible
        ? 'NEARLY ELIGIBLE'
        : 'NOT ELIGIBLE';

    final subtitle = submittedAttempt
        ? 'Grand test completed'
        : inProgressAttempt
        ? 'Student is currently attempting the test'
        : eligibility.isEligible
        ? 'Requirements met. Ready for exam.'
        : nearlyEligible
        ? 'Close to unlocking the exam.'
        : 'Significant requirements pending.';

    final progressLabel = submittedAttempt
        ? '${latestAttempt!.percentage.toStringAsFixed(0)}% Result'
        : '${eligibility.readinessPercent.toStringAsFixed(0)}% Ready';

    final progressValue = submittedAttempt
        ? (latestAttempt!.percentage / 100).clamp(0, 1).toDouble()
        : (eligibility.readinessPercent / 100).clamp(0, 1).toDouble();

    return CourseGlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Icon(
                  submittedAttempt
                      ? Icons.emoji_events_rounded
                      : inProgressAttempt
                      ? Icons.play_circle_rounded
                      : eligibility.isEligible
                      ? Icons.verified_rounded
                      : Icons.lock_rounded,
                  color: statusColor,
                  size: 28,
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
                            'Student $studentId',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 12,
                    backgroundColor: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                progressLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricPill(
                label:
                    'Lessons ${eligibility.lessonProgress.toStringAsFixed(0)}%',
                icon: Icons.video_library_rounded,
                color: Colors.blue,
              ),
              _MetricPill(
                label:
                    'Assignments ${eligibility.assignmentCompletion.toStringAsFixed(0)}%',
                icon: Icons.assignment_turned_in_rounded,
                color: Colors.purple,
              ),
              _MetricPill(
                label:
                    'Avg Score ${eligibility.averageScore.toStringAsFixed(0)}%',
                icon: Icons.analytics_rounded,
                color: Colors.orange,
              ),
              _MetricPill(
                label:
                    'Attempts ${eligibility.attemptsUsed}/${eligibility.maxAttempts}',
                icon: Icons.repeat_rounded,
                color: Colors.teal,
              ),
              if (submittedAttempt)
                _MetricPill(
                  label:
                      'Exam Score ${latestAttempt!.score}/${latestAttempt!.totalMarks}',
                  icon: Icons.score_rounded,
                  color: statusColor,
                ),
              _MetricPill(
                label: eligibility.projectSubmitted
                    ? 'Project Submitted'
                    : 'Project Pending',
                icon: Icons.code_rounded,
                color: eligibility.projectSubmitted
                    ? Colors.green
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (!submittedAttempt &&
              eligibility.missingRequirements.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.block_rounded, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'MISSING REQUIREMENTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...eligibility.missingRequirements.map(
                    (reason) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!submittedAttempt && eligibility.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        color: Colors.blue,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'RECOMMENDATIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...eligibility.recommendations.map(
                    (recommendation) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              recommendation,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
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
