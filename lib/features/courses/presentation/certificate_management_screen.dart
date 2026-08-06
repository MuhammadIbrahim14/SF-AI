import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../providers/certificate_provider.dart';
import '../providers/course_provider.dart';
import 'course_premium_widgets.dart';

class CertificateManagementScreen extends ConsumerWidget {
  const CertificateManagementScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final certificatesAsync = ref.watch(courseCertificatesProvider(courseId));
    final actionState = ref.watch(certificateActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Certificate Studio',
      subtitle: 'Issue, review, and revoke course certificates.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherCourseLessons,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: certificatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Certificates unavailable',
            message: error.toString(),
          ),
          data: (certificates) {
            final courseTitle = courseAsync.value?.title ?? 'Course';
            final activeCount = certificates.where((c) => c.isActive).length;
            final revokedCount = certificates.length - activeCount;

            return CoursePremiumListView(
              maxWidth: 1000,
              bottomPadding: 96,
              children: [
                CourseHeroHeader(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Certification Studio',
                  subtitle:
                      'Issue performance-backed, highly secure digital certificates for $courseTitle.',
                  trailing: FilledButton.icon(
                    onPressed: () => context.pushNamed(
                      RouteNames.teacherCertificateEligible,
                      pathParameters: {'courseId': courseId},
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text(
                      'Issue New Certificates',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (certificates.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Issued',
                          value: '${certificates.length}',
                          icon: Icons.file_copy_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Active credentials',
                          value: '$activeCount',
                          icon: Icons.verified_rounded,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Revoked',
                          value: '$revokedCount',
                          icon: Icons.block_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.history_edu_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Issued Certificates Registry',
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
                if (certificates.isEmpty)
                  const CoursePremiumMessage(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No certificates issued yet',
                    message:
                        'Eligible students will appear in the issue workflow.',
                  )
                else
                  ...certificates.map(
                    (certificate) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CertificateTile(
                        certificate: certificate,
                        busy: actionState.isLoading,
                        onRevoke: certificate.isActive
                            ? () => _revoke(context, ref, certificate)
                            : null,
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

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    CertificateModel certificate,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _RevokeReasonDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    if (!context.mounted) return;

    final success = await ref
        .read(certificateActionProvider.notifier)
        .revokeCertificate(
          certificateId: certificate.certificateId,
          reason: reason,
        );
    if (!context.mounted) return;
    if (success) {
      _refreshCertificateSignals(ref);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Certificate revoked.'
              : ref.read(certificateActionProvider.notifier).errorMessage ??
                    'Failed to revoke certificate.',
        ),
      ),
    );
  }

  void _refreshCertificateSignals(WidgetRef ref) {
    ref.invalidate(courseCertificatesProvider(courseId));
    ref.invalidate(teacherDashboardStatsProvider);
    ref.invalidate(teacherGrandCertificateAnalyticsProvider);
    ref.invalidate(teacherAiIntelligenceProvider);
    ref.invalidate(teacherProductivityHubProvider);
    ref.invalidate(teacherStudentProgressProvider);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({
    required this.certificate,
    required this.busy,
    required this.onRevoke,
  });

  final CertificateModel certificate;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = certificate.isActive;

    // Emerald green for active, subtle red for revoked
    final statusColor = isActive ? Colors.teal : Colors.red;

    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              isActive ? Icons.workspace_premium_rounded : Icons.block_rounded,
              color: statusColor,
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
                        certificate.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusBadge(
                      label: isActive ? 'ACTIVE' : 'REVOKED',
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Issued to ${certificate.studentName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Course: ${certificate.courseTitle}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CertPill(
                      icon: Icons.category_rounded,
                      label: certificate.typeLabel,
                      color: Colors.amber.shade700,
                    ),
                    _CertPill(
                      icon: Icons.vpn_key_rounded,
                      label: certificate.verificationCode,
                      color: Colors.blue,
                    ),
                    _CertPill(
                      icon: Icons.score_rounded,
                      label:
                          '${certificate.finalScore.toStringAsFixed(0)}% Score',
                      color: Colors.purple,
                    ),
                    _CertPill(
                      icon: Icons.event_available_rounded,
                      label: DateFormat(
                        'MMM d, yyyy',
                      ).format(certificate.issuedAt),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onRevoke != null) ...[
            const SizedBox(width: 16),
            IconButton(
              tooltip: 'Revoke Certificate',
              onPressed: busy ? null : onRevoke,
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
              ),
              icon: const Icon(Icons.gpp_bad_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'ACTIVE'
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CertPill extends StatelessWidget {
  const _CertPill({
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

class _RevokeReasonDialog extends StatefulWidget {
  const _RevokeReasonDialog();

  @override
  State<_RevokeReasonDialog> createState() => _RevokeReasonDialogState();
}

class _RevokeReasonDialogState extends State<_RevokeReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Revoke Certificate',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reason for Revocation',
          hintText: 'e.g. Discovered plagiarism in final project',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.block_rounded),
          label: const Text('Revoke Permanently'),
        ),
      ],
    );
  }
}
