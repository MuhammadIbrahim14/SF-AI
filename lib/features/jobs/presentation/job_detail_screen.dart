import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/application_model.dart';
import '../../../models/hiring_lifecycle_models.dart';
import '../../../models/job_match_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _coverLetterController = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  void _applyForJob(String companyId, String role) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    if (role != 'student' && role != 'freelancer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only student and freelancer accounts can apply.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final existing = () {
      final apps = ref.read(myApplicationsProvider).value ?? const [];
      for (final a in apps) {
        if (a.jobId == widget.jobId) return a;
      }
      return null;
    }();
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have already applied to this job.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (_coverLetterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please write a cover letter.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() => _isApplying = true);

    final application = ApplicationModel(
      id: '',
      jobId: widget.jobId,
      applicantId: user.uid,
      companyId: companyId,
      coverLetter: _coverLetterController.text.trim(),
      status: 'Pending',
      appliedAt: DateTime.now(),
      role: role,
    );

    final success = await ref
        .read(applicationActionProvider.notifier)
        .submitApplication(application);

    if (mounted) {
      setState(() => _isApplying = false);
      if (success) {
        ref.invalidate(myApplicationsProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application submitted successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error = ref.read(applicationActionProvider.notifier).lastErrorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ?? 'Failed to submit application. Please try again.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showApplyBottomSheet(String companyId, String role) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 32,
            right: 32,
            top: 32,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit Application',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Why are you a perfect match for this role?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _coverLetterController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Draft your cover letter here...',
                  filled: true,
                  fillColor: isDark ? Colors.black12 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isApplying
                    ? null
                    : () => _applyForJob(companyId, role),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isApplying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send Application',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final currentUser = ref.watch(currentUserProvider).value;
    final matchedJobs = ref.watch(matchedJobsProvider).value;
    final headerRole =
        UserRole.fromString(currentUser?.primaryRole) ?? UserRole.freelancer;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: headerRole,
      title: 'Opportunity Overview',
      subtitle: 'Review job details, matching rules, and candidate access.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              headerRole == UserRole.company
                  ? RouteNames.companyJobs
                  : RouteNames.jobList,
            ),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: jobAsync.when(
          data: (job) {
            if (job == null) {
              return const Center(child: Text('Opportunity not found.'));
            }

            final isCompanyOwner = currentUser?.uid == job.companyId;
            final role = (currentUser?.primaryRole ?? '').toLowerCase();
            final targetRoles = job.targetRoles.map(
              (value) => value.toLowerCase(),
            );
            final currentMatch = matchedJobs == null
                ? null
                : _matchForJob(matchedJobs, job.id);
            final roleAllowed =
                (role == 'student' || role == 'freelancer') &&
                (targetRoles.contains(role) || targetRoles.contains('both'));
            final matchAllowsApply = isJobRelevantForCandidate(
              job: job,
              match: currentMatch,
            );
            final canApply = roleAllowed && matchAllowsApply;
            ApplicationModel? existingApplication;
            for (final a
                in ref.watch(myApplicationsProvider).value ?? const []) {
              if (a.jobId == job.id) {
                existingApplication = a;
                break;
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Massive Hero Section
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161616) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF222222)
                                      : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.business_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job.title,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                            height: 1.1,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Company ID: ${job.companyId.substring(0, 8)}',
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (currentMatch != null && !isCompanyOwner)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: (currentMatch.matchScore / 100)
                                            .clamp(0.0, 1.0),
                                        strokeWidth: 4,
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.2),
                                      ),
                                      Text(
                                        currentMatch.matchScore.toStringAsFixed(
                                          0,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _HeroPill(
                                icon: Icons.location_on_rounded,
                                text: job.location,
                              ),
                              _HeroPill(
                                icon: Icons.work_rounded,
                                text: job.type,
                              ),
                              _HeroPill(
                                icon: Icons.attach_money_rounded,
                                text: job.salaryRange,
                                color: AppColors.success,
                              ),
                              if (job.remoteAllowed)
                                const _HeroPill(
                                  icon: Icons.public_rounded,
                                  text: 'Remote Friendly',
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildMainContent(job, context),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildSidePanel(
                              job,
                              currentMatch,
                              isCompanyOwner,
                              canApply,
                              roleAllowed,
                              matchAllowsApply,
                              role,
                              context,
                              existingApplication,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildSidePanel(
                        job,
                        currentMatch,
                        isCompanyOwner,
                        canApply,
                        roleAllowed,
                        matchAllowsApply,
                        role,
                        context,
                        existingApplication,
                      ),
                      const SizedBox(height: 24),
                      _buildMainContent(job, context),
                    ],
                  ],
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: content,
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Widget _buildMainContent(dynamic job, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            job.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),

          if (job.requirements.isNotEmpty) ...[
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 40),
            Text(
              'Key Responsibilities & Requirements',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            ...job.requirements.map(
              (req) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        req,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidePanel(
    dynamic job,
    JobMatchModel? match,
    bool isCompanyOwner,
    bool canApply,
    bool roleAllowed,
    bool matchAllowsApply,
    String role,
    BuildContext context,
    ApplicationModel? existingApplication,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (match != null && !isCompanyOwner) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: match.isStrongMatch
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: match.isStrongMatch
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      match.isStrongMatch
                          ? Icons.auto_awesome_rounded
                          : Icons.info_outline_rounded,
                      color: match.isStrongMatch
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI Match Analysis',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: match.isStrongMatch
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  match.recommendationReason,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!job.isActive)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Application Closed',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else if (existingApplication != null && !isCompanyOwner)
                _ExistingApplicationStatus(
                  application: existingApplication,
                  onViewApplications: () =>
                      context.pushNamed(RouteNames.myApplications),
                )
              else if (canApply && !isCompanyOwner)
                FilledButton.icon(
                  onPressed: () => _showApplyBottomSheet(job.companyId, role),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'Apply Now',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                )
              else if (roleAllowed && !matchAllowsApply && !isCompanyOwner)
                _SkillGateNotice(job: job, match: match)
              else if (isCompanyOwner)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'This is your company\'s listing',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),

              Text(
                'Required Expertise',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: job.requiredSkills.map<Widget>((skill) {
                  final isMissing =
                      match != null && match.missingSkills.contains(skill);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMissing
                          ? AppColors.error.withValues(alpha: 0.05)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMissing
                            ? AppColors.error.withValues(alpha: 0.2)
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                    child: Text(
                      skill,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isMissing
                            ? AppColors.error
                            : theme.colorScheme.onSurfaceVariant,
                        decoration: isMissing
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

JobMatchModel? _matchForJob(
  Iterable<MatchedJobModel> matchedJobs,
  String jobId,
) {
  for (final item in matchedJobs) {
    if (item.job.id == jobId) return item.match;
  }
  return null;
}

class _SkillGateNotice extends StatelessWidget {
  const _SkillGateNotice({required this.job, required this.match});

  final dynamic job;
  final JobMatchModel? match;

  @override
  Widget build(BuildContext context) {
    final minimum = job.minimumSkillScore as double;
    final hasMinimum = minimum > 0;
    final score = match?.skillScoreAverage ?? 0;
    final missingSkills = match?.missingSkills ?? job.requiredSkills;
    final missingText = missingSkills.isEmpty
        ? 'required skills'
        : missingSkills.take(3).join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Application Locked',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasMinimum
                ? 'This role requires a ${minimum.toStringAsFixed(0)}% verified skill strength. Your average is ${score.toStringAsFixed(0)}%.\n\nLevel up in $missingText to unlock.'
                : 'Improve your verified skills in $missingText to unlock this role.',
            style: const TextStyle(height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ExistingApplicationStatus extends StatelessWidget {
  const _ExistingApplicationStatus({
    required this.application,
    required this.onViewApplications,
  });

  final ApplicationModel application;
  final VoidCallback onViewApplications;

  String get _title {
    if (application.candidateVisibleStatus == 'hired' ||
        application.normalizedPipelineStage == 'hired' ||
        application.normalizedLifecycleStage == 'joined') {
      return 'Already Hired';
    }
    return switch (application.normalizedOfferStatus) {
      'sent' => 'Offer Received',
      'accepted' => 'Offer Accepted',
      'declined' => 'Offer Declined',
      'clarification' => 'Offer Clarification',
      _ => 'Already Applied',
    };
  }

  String get _subtitle {
    if (application.candidateVisibleStatus == 'hired' ||
        application.normalizedLifecycleStage == 'joined') {
      return 'You are hired for this job. Re-apply is not available.';
    }
    if (application.normalizedOfferStatus == 'sent') {
      return 'An offer is waiting in My Applications.';
    }
    return 'Status: ${lifecycleStageLabel(application.normalizedLifecycleStage)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onViewApplications,
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('View My Applications'),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    //     final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: themeColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }
}
