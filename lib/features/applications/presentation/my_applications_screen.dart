import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../features/company/hiring_lifecycle/presentation/widgets/hiring_timeline_panel.dart';
import '../../../features/company/hiring_lifecycle/providers/hiring_lifecycle_providers.dart';
import '../../../models/application_model.dart';
import '../../../models/hiring_lifecycle_models.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final currentRole =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.freelancer;
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: currentRole,
      title: 'Application Tracking',
      subtitle: 'Track job applications, status changes, and next steps.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(_dashboardRouteFor(currentRole)),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: applicationsAsync.when(
          data: (applications) {
            if (applications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.outbox_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Active Applications',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your application pipeline is currently empty. Head over to the Opportunities Center to find your next role.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Sort applications by most recent first
            final sortedApps = List<ApplicationModel>.from(applications)
              ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(myApplicationsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                itemCount: sortedApps.length,
                itemBuilder: (context, index) {
                  final application = sortedApps[index];
                  final jobAsync = ref.watch(
                    jobDetailProvider(application.jobId),
                  );

                  return jobAsync.when(
                    data: (job) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _PremiumApplicationCard(
                          application: application,
                          jobTitle: job?.title ?? 'Unknown Role',
                          companyName:
                              'Company ID: ${job?.companyId.substring(0, 8) ?? "Unknown"}',
                          onTap: () => context.pushNamed(
                            RouteNames.jobDetail,
                            pathParameters: {'id': application.jobId},
                          ),
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const SizedBox(),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

String _dashboardRouteFor(UserRole role) {
  return switch (role) {
    UserRole.student => RouteNames.studentDashboard,
    UserRole.freelancer => RouteNames.freelancerDashboard,
    UserRole.company => RouteNames.companyDashboard,
    UserRole.teacher => RouteNames.teacherDashboard,
    UserRole.admin => RouteNames.adminDashboard,
    UserRole.superAdmin => RouteNames.superAdminDashboard,
  };
}

class _PremiumApplicationCard extends ConsumerWidget {
  const _PremiumApplicationCard({
    required this.application,
    required this.jobTitle,
    required this.companyName,
    required this.onTap,
  });

  final ApplicationModel application;
  final String jobTitle;
  final String companyName;
  final VoidCallback onTap;

  // Pipeline Status Flow
  static const List<String> _pipeline = [
    'applied',
    'shortlisted',
    'interview',
    'offer',
    'hired',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentStatus = application.normalizedStatus;
    final isRejected = currentStatus == 'rejected';
    final isOnHold = currentStatus == 'on_hold';
    final isHired = application.candidateVisibleStatus == 'hired';

    // Determine color coding
    Color statusColor;
    IconData statusIcon;

    if (isHired) {
      statusColor = AppColors.success;
      statusIcon = Icons.verified_user_rounded;
    } else if (isRejected) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (isOnHold) {
      statusColor = AppColors.warning;
      statusIcon = Icons.pause_circle_filled_rounded;
    } else if (currentStatus == 'selected') {
      statusColor = AppColors.success;
      statusIcon = Icons.verified_rounded;
    } else if (currentStatus == 'interview_scheduled' ||
        currentStatus == 'interview_completed') {
      statusColor = Colors.deepPurpleAccent;
      statusIcon = Icons.event_available_rounded;
    } else {
      statusColor = AppColors.primary;
      statusIcon = Icons.pending_actions_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.05 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jobTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            companyName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isHired
                            ? 'HIRED ✓'
                            : isRejected
                            ? 'REJECTED'
                            : (isOnHold
                                  ? 'ON HOLD'
                                  : applicationStatusLabel(
                                      currentStatus,
                                    ).toUpperCase()),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (isHired) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.celebration_rounded,
                              color: AppColors.success,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Congratulations!',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You have been successfully hired.',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Divider(),
                const SizedBox(height: 24),

                // Pipeline Visualizer
                if (!isRejected && !isOnHold)
                  _buildTimeline(currentStatus, theme)
                else
                  Text(
                    isRejected
                        ? 'This application has been closed by the company.'
                        : 'This application is currently on hold.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                const SizedBox(height: 24),
                Text(
                  'Status: ${lifecycleStageLabel(application.normalizedLifecycleStage)}'
                  '${application.normalizedEmploymentStatus != 'none' ? ' · ${employmentStatusLabel(application.employmentStatus)}' : ''}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (application.offerJoiningDate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Joining date: ${application.offerJoiningDate}'),
                ],
                const SizedBox(height: 16),
                HiringTimelinePanel(
                  applicationId: application.id,
                  candidateView: true,
                ),
                const SizedBox(height: 24),
                if (application.evaluationRequestStatus == 'requested' ||
                    application.evaluationRequestStatus == 'submitted') ...[
                  _EvaluationRequestPanel(application: application, ref: ref),
                  const SizedBox(height: 24),
                ],
                if (application.normalizedOfferStatus == 'sent' ||
                    application.normalizedOfferStatus == 'accepted' ||
                    application.normalizedOfferStatus == 'declined' ||
                    application.normalizedOfferStatus == 'clarification') ...[
                  _OfferResponsePanel(application: application, ref: ref),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Applied on ${DateFormat.yMMMd().format(application.appliedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(String currentStatus, ThemeData theme) {
    String visualStatus = switch (normalizePipelineStage(currentStatus)) {
      'screening' || 'evaluationRequested' || 'evaluationSubmitted' => 'applied',
      'shortlisted' => 'shortlisted',
      'interview' => 'interview',
      'offer' => 'offer',
      'hired' => 'hired',
      'rejected' => 'applied',
      _ => normalizePipelineStage(currentStatus),
    };
    if (currentStatus.contains('interview') ||
        application.normalizedLifecycleStage == 'evaluated' ||
        application.normalizedLifecycleStage == 'interview_completed') {
      visualStatus = 'interview';
    }
    if (application.normalizedOfferStatus == 'sent' ||
        application.normalizedOfferStatus == 'accepted' ||
        application.normalizedOfferStatus == 'clarification') {
      visualStatus = application.normalizedOfferStatus == 'accepted'
          ? 'hired'
          : 'offer';
    }
    if (application.normalizedPipelineStage == 'hired' ||
        application.candidateVisibleStatus == 'hired') {
      visualStatus = 'hired';
    }

    int currentIndex = _pipeline.indexOf(visualStatus);
    if (currentIndex == -1) currentIndex = 0;

    return Row(
      children: List.generate(_pipeline.length * 2 - 1, (index) {
        if (index % 2 == 1) {
          final stepIndex = index ~/ 2;
          final isPast = stepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: isPast
                  ? AppColors.success
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          );
        } else {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentIndex;
          final isCurrent = stepIndex == currentIndex;

          Color nodeColor;
          if (isCompleted) {
            nodeColor = AppColors.success;
          } else if (isCurrent) {
            nodeColor = AppColors.primary;
          } else {
            nodeColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
          }

          return Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 4,
                        )
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                _shortLabel(_pipeline[stepIndex]),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                  color: (isCurrent || isCompleted)
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  String _shortLabel(String status) {
    return switch (status) {
      'applied' => 'Applied',
      'shortlisted' => 'Shortlist',
      'interview' => 'Interview',
      'offer' => 'Offer',
      'hired' => 'Hired',
      _ => status,
    };
  }
}

class _EvaluationRequestPanel extends StatelessWidget {
  const _EvaluationRequestPanel({required this.application, required this.ref});

  final ApplicationModel application;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitted = application.evaluationRequestStatus == 'submitted';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            submitted ? 'Evaluation submitted' : 'Evaluation requested',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submitted
                ? 'Your answers were sent to the company.'
                : 'The company requested a few answers before the next hiring step.',
          ),
          if (application.evaluationQuestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final question in application.evaluationQuestions.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('- $question'),
              ),
          ],
          if (!submitted) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _submit(context),
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: const Text('Submit Answers'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final controllers = [
      for (final _ in application.evaluationQuestions) TextEditingController(),
    ];
    final answers = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit evaluation answers'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < controllers.length; i++) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      application.evaluationQuestions[i],
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controllers[i],
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write your answer',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(controllers.map((controller) => controller.text).toList()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (answers == null || !context.mounted) return;
    final ok = await ref
        .read(applicationActionProvider.notifier)
        .submitEvaluationAnswers(
          applicationId: application.id,
          answers: answers,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Evaluation answers submitted.' : 'Unable to submit answers.',
        ),
      ),
    );
  }
}

class _OfferResponsePanel extends ConsumerWidget {
  const _OfferResponsePanel({required this.application, required this.ref});

  final ApplicationModel application;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final theme = Theme.of(context);
    final status = application.normalizedOfferStatus;
    final hasOfferDetails = application.offerSalary.isNotEmpty ||
        application.offerJoiningDate.isNotEmpty ||
        application.offerRole.isNotEmpty ||
        application.hasStructuredOffer;
    final apps = ref.watch(myApplicationsProvider).asData?.value ?? const [];
    final blockedByActiveHire = apps.any(
      (app) =>
          app.id != application.id &&
          (app.isJoiningSoon || app.isActiveEmployee),
    );
    final jobAsync = ref.watch(jobDetailProvider(application.jobId));
    final companyUserAsync =
        ref.watch(hiringUserProvider(application.companyId));
    final currentUser = ref.watch(currentUserProvider).asData?.value;
    final pdfBusy = ref.watch(pdfExportActionProvider).isLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status == 'accepted'
            ? AppColors.success.withValues(alpha: 0.08)
            : status == 'declined'
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'accepted'
              ? AppColors.success.withValues(alpha: 0.22)
              : status == 'declined'
              ? AppColors.error.withValues(alpha: 0.22)
              : AppColors.info.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'accepted'
                    ? Icons.verified_rounded
                    : status == 'declined'
                    ? Icons.cancel_rounded
                    : Icons.mail_outline_rounded,
                color: status == 'accepted'
                    ? AppColors.success
                    : status == 'declined'
                    ? AppColors.error
                    : AppColors.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status == 'sent'
                      ? 'Job Offer Received'
                      : status == 'accepted'
                      ? 'Offer Accepted - Welcome aboard!'
                      : status == 'clarification'
                      ? 'Clarification Requested'
                      : 'Offer Declined',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (hasOfferDetails) ...[
            const SizedBox(height: 16),
            if (application.offerRole.isNotEmpty)
              _offerRow(theme, 'Role', application.offerRole),
            if (application.offerDepartment.isNotEmpty)
              _offerRow(theme, 'Department', application.offerDepartment),
            if (application.offerSalary.isNotEmpty)
              _offerRow(
                theme,
                'Salary',
                '${application.offerSalary} ${application.offerCurrency}',
              ),
            if (application.offerEmploymentType.isNotEmpty)
              _offerRow(theme, 'Type', application.offerEmploymentType),
            if (application.offerJoiningDate.isNotEmpty)
              _offerRow(theme, 'Joining Date', application.offerJoiningDate),
            if (application.offerLocation.isNotEmpty)
              _offerRow(theme, 'Location', application.offerLocation),
            if (application.offerWorkingHours.isNotEmpty)
              _offerRow(theme, 'Hours', application.offerWorkingHours),
            if (application.offerContractDuration.isNotEmpty)
              _offerRow(
                theme,
                'Contract',
                application.offerContractDuration,
              ),
            if (application.offerBenefits.isNotEmpty)
              _offerRow(theme, 'Benefits', application.offerBenefits),
            if (application.offerExpiresAt.isNotEmpty)
              _offerRow(theme, 'Expires', application.offerExpiresAt),
          ],
          if (application.offerMessage.trim().isNotEmpty ||
              application.offerDetails.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                application.offerMessage.trim().isNotEmpty
                    ? application.offerMessage
                    : application.offerDetails,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: pdfBusy
                    ? null
                    : () => _exportOffer(
                          context,
                          print: true,
                          candidateName:
                              currentUser?.fullName.trim().isNotEmpty == true
                              ? currentUser!.fullName
                              : currentUser?.email ?? 'Candidate',
                          companyName:
                              companyUserAsync.asData?.value?.fullName ??
                              'Company',
                          jobTitle: jobAsync.asData?.value?.title,
                        ),
                icon: const Icon(Icons.print_rounded),
                label: const Text('Preview / Print'),
              ),
              FilledButton.tonalIcon(
                onPressed: pdfBusy
                    ? null
                    : () => _exportOffer(
                          context,
                          print: false,
                          candidateName:
                              currentUser?.fullName.trim().isNotEmpty == true
                              ? currentUser!.fullName
                              : currentUser?.email ?? 'Candidate',
                          companyName:
                              companyUserAsync.asData?.value?.fullName ??
                              'Company',
                          jobTitle: jobAsync.asData?.value?.title,
                        ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share PDF'),
              ),
            ],
          ),
          if (status == 'sent') ...[
            if (blockedByActiveHire) ...[
              const SizedBox(height: 12),
              Text(
                'You already have an active hire / joining role. Decline that first (or leave) before accepting another offer.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: blockedByActiveHire
                        ? null
                        : () => _respond(context, 'accepted'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respond(context, 'declined'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Decline'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _respond(
                context,
                'clarification',
                message: 'Please clarify offer details.',
              ),
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Request Clarification'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportOffer(
    BuildContext context, {
    required bool print,
    required String candidateName,
    required String companyName,
    String? jobTitle,
  }) async {
    var resolvedCompany = companyName;
    try {
      final company = await ref
          .read(companyRepositoryProvider)
          .getCompany(application.companyId);
      if (company != null && company.companyName.trim().isNotEmpty) {
        resolvedCompany = company.companyName;
      }
    } catch (_) {
      AppLogger.debug('Offer export used the supplied company name.');
    }
    final ok = await ref.read(pdfExportActionProvider.notifier).exportOfferLetter(
          application: application,
          companyName: resolvedCompany,
          candidateName: candidateName,
          jobTitle: jobTitle,
          print: print,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (print
                  ? 'Offer letter opened for print.'
                  : 'Offer letter ready to share.')
              : (ref.read(pdfExportActionProvider.notifier).errorMessage ??
                  'Unable to export offer letter.'),
        ),
      ),
    );
  }

  Widget _offerRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    String status, {
    String? message,
  }) async {
    final ok = await ref
        .read(applicationActionProvider.notifier)
        .respondToOffer(
          applicationId: application.id,
          offerStatus: status,
          candidateResponseMessage: message,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Offer response saved.'
              : (ref.read(applicationActionProvider.notifier).lastErrorMessage ??
                    'Unable to respond. Please try again.'),
        ),
      ),
    );
    if (ok) {
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(applicationDetailStreamProvider(application.id));
    }
  }
}
