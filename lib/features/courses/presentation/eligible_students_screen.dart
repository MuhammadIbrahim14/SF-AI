import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../teacher/providers/teacher_ai_intelligence_provider.dart';
import '../../teacher/providers/teacher_dashboard_provider.dart';
import '../../teacher/providers/teacher_grand_certificate_analytics_provider.dart';
import '../../teacher/providers/teacher_productivity_hub_provider.dart';
import '../../teacher/providers/teacher_student_progress_provider.dart';
import '../data/models/certificate_model.dart';
import '../data/models/enrollment_model.dart';
import '../providers/certificate_provider.dart';
import '../providers/enrollment_provider.dart';
import 'course_premium_widgets.dart';

class EligibleStudentsScreen extends ConsumerWidget {
  const EligibleStudentsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(courseEnrollmentsProvider(courseId));

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Eligible Students',
      subtitle: 'Review certificate eligibility and issue credentials.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherCertificates,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: enrollmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Students unavailable',
            message: error.toString(),
          ),
          data: (enrollments) {
            if (enrollments.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.groups_outlined,
                title: 'No enrolled students yet',
                message:
                    'Students will appear here after enrolling in this course.',
              );
            }

            return CoursePremiumListView(
              maxWidth: 1000,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Issue Certificates',
                  subtitle:
                      'Review verified student eligibility across all requirements and securely issue official credentials.',
                ),
                const SizedBox(height: 32),
                ...enrollments.map(
                  (enrollment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _EligibilityCard(
                      courseId: courseId,
                      enrollment: enrollment,
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

class _EligibilityCard extends ConsumerWidget {
  const _EligibilityCard({required this.courseId, required this.enrollment});

  final String courseId;
  final EnrollmentModel enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibilityAsync = ref.watch(
      certificateEligibilityProvider((
        courseId: courseId,
        studentId: enrollment.studentId,
      )),
    );
    final actionState = ref.watch(certificateActionProvider);

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
                  'Error loading eligibility: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (eligibility) {
        final colorScheme = Theme.of(context).colorScheme;
        final availableTypes = eligibility.eligibleCertificateTypes;
        final issuedTypes = eligibility.issuedCertificateTypes;
        final isEligible = availableTypes.isNotEmpty;
        final allEligibleTypesIssued = eligibility.allEligibleTypesIssued;

        final statusColor = isEligible
            ? Colors.amber.shade700
            : allEligibleTypesIssued
            ? AppColors.success
            : Colors.grey.shade500;
        final statusLabel = isEligible
            ? 'READY'
            : allEligibleTypesIssued
            ? 'ISSUED'
            : 'PENDING';

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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
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
                                'Student ${enrollment.studentId}',
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isEligible || allEligibleTypesIssued
                                        ? Icons.verified_user_rounded
                                        : Icons.lock_clock_rounded,
                                    size: 14,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEligible
                              ? 'Ready to issue: ${availableTypes.map(CertificateType.label).join(', ')}'
                              : allEligibleTypesIssued
                              ? 'All currently qualified certificate types have already been issued once.'
                              : 'Complete missing requirements to unlock certification.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(
                    icon: Icons.menu_book_rounded,
                    label:
                        'Lessons ${eligibility.lessonProgress.toStringAsFixed(0)}%',
                    color: Colors.blue,
                  ),
                  _MetricPill(
                    icon: Icons.assignment_turned_in_rounded,
                    label:
                        'Assignments ${eligibility.assignmentCompletion.toStringAsFixed(0)}%',
                    color: Colors.purple,
                  ),
                  _MetricPill(
                    icon: Icons.score_rounded,
                    label:
                        'Average ${eligibility.assignmentAverage.toStringAsFixed(0)}%',
                    color: Colors.orange,
                  ),
                  _MetricPill(
                    icon: Icons.workspace_premium_rounded,
                    label:
                        'Grand Test ${eligibility.grandTestScore.toStringAsFixed(0)}%',
                    color: Colors.teal,
                  ),
                  if (issuedTypes.isNotEmpty)
                    _MetricPill(
                      icon: Icons.verified_rounded,
                      label:
                          'Issued ${issuedTypes.map(CertificateType.label).join(', ')}',
                      color: AppColors.success,
                    ),
                ],
              ),
              if (eligibility.missingRequirements.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.block_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'MISSING REQUIREMENTS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...eligibility.missingRequirements.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    color: Colors.orange,
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
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _IssueButton(
                    icon: Icons.verified_rounded,
                    label:
                        issuedTypes.contains(CertificateType.courseCompletion)
                        ? 'Completion Issued'
                        : 'Issue Completion Cert',
                    enabled:
                        !issuedTypes.contains(
                          CertificateType.courseCompletion,
                        ) &&
                        availableTypes.contains(
                          CertificateType.courseCompletion,
                        ),
                    busy: actionState.isLoading,
                    color: Colors.teal, // Emerald style
                    onPressed: () =>
                        _issue(context, ref, CertificateType.courseCompletion),
                  ),
                  _IssueButton(
                    icon: Icons.military_tech_rounded,
                    label: issuedTypes.contains(CertificateType.excellence)
                        ? 'Excellence Issued'
                        : 'Issue Excellence Cert',
                    enabled:
                        !issuedTypes.contains(CertificateType.excellence) &&
                        availableTypes.contains(CertificateType.excellence),
                    busy: actionState.isLoading,
                    color: Colors.amber.shade700, // Gold style
                    onPressed: () =>
                        _issue(context, ref, CertificateType.excellence),
                  ),
                  _IssueButton(
                    icon: Icons.star_rounded,
                    label:
                        issuedTypes.contains(CertificateType.projectExcellence)
                        ? 'Project Excellence Issued'
                        : 'Issue Project Excellence',
                    enabled:
                        !issuedTypes.contains(
                          CertificateType.projectExcellence,
                        ) &&
                        availableTypes.contains(
                          CertificateType.projectExcellence,
                        ),
                    busy: actionState.isLoading,
                    color: Colors.deepPurple.shade400, // Premium accent
                    onPressed: () =>
                        _issue(context, ref, CertificateType.projectExcellence),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _issue(
    BuildContext context,
    WidgetRef ref,
    String certificateType,
  ) async {
    final success = await ref
        .read(certificateActionProvider.notifier)
        .issueCertificate(
          courseId: courseId,
          studentId: enrollment.studentId,
          certificateType: certificateType,
        );
    if (!context.mounted) return;
    if (success) {
      _refreshCertificateSignals(ref);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${CertificateType.label(certificateType)} certificate issued securely.'
              : ref.read(certificateActionProvider.notifier).errorMessage ??
                    'Failed to issue certificate.',
        ),
      ),
    );
  }

  void _refreshCertificateSignals(WidgetRef ref) {
    ref.invalidate(courseCertificatesProvider(courseId));
    ref.invalidate(
      certificateEligibilityProvider((
        courseId: courseId,
        studentId: enrollment.studentId,
      )),
    );
    ref.invalidate(teacherDashboardStatsProvider);
    ref.invalidate(teacherGrandCertificateAnalyticsProvider);
    ref.invalidate(teacherAiIntelligenceProvider);
    ref.invalidate(teacherProductivityHubProvider);
    ref.invalidate(teacherStudentProgressProvider);
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

class _IssueButton extends StatelessWidget {
  const _IssueButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.busy,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool busy;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled && !busy ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: enabled ? color : color.withValues(alpha: 0.1),
        foregroundColor: enabled ? Colors.white : color.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}
