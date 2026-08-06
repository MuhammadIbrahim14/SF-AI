import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/application_model.dart';
import '../../../models/job_match_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/company_permission_provider.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'widgets/applicant_card.dart';

class JobApplicantsScreen extends ConsumerStatefulWidget {
  const JobApplicantsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobApplicantsScreen> createState() =>
      _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends ConsumerState<JobApplicantsScreen> {
  String _status = 'all';
  _CandidateSort _sort = _CandidateSort.highestMatch;
  _CandidateSignalFilter _signalFilter = _CandidateSignalFilter.all;

  static const _filters = [
    'all',
    'applied',
    'shortlisted',
    'interview_scheduled',
    'interview_completed',
    'selected',
    'rejected',
    'on_hold',
  ];

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(jobApplicationsProvider(widget.jobId));
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final rankedAsync = ref.watch(rankedJobApplicantsProvider(widget.jobId));
    final permissionAsync = ref.watch(companyPermissionProvider);
    final permission = permissionAsync.value;
    final canManageHiring = permission?.canViewApplicants ?? false;
    final jobTitle = jobAsync.whenOrNull(data: (job) => job?.title);

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: jobTitle ?? 'Applicants',
      subtitle: 'Review ranked candidates and manage pipeline status.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyJobs),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: permissionAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : !canManageHiring
            ? _CompanyPermissionBlocked(
                message:
                    permission?.restrictionMessage ??
                    'Company verification is required before viewing applicants.',
              )
            : applicationsAsync.when(
                data: (applications) {
                  if (applications.isEmpty) {
                    return const Center(
                      child: Text('No applicants yet for this job.'),
                    );
                  }

                  return rankedAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Error: $error')),
                    data: (rankedCandidates) => RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          rankedJobApplicantsProvider(widget.jobId),
                        );
                        ref.invalidate(jobApplicationsProvider(widget.jobId));
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _CandidateIntelligenceHeader(
                            candidates: rankedCandidates,
                          ),
                          const SizedBox(height: 18),
                          _CandidateControls(
                            status: _status,
                            filters: _filters,
                            sort: _sort,
                            signalFilter: _signalFilter,
                            onStatusChanged: (value) =>
                                setState(() => _status = value),
                            onSortChanged: (value) =>
                                setState(() => _sort = value),
                            onSignalFilterChanged: (value) =>
                                setState(() => _signalFilter = value),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => context.pushNamed(
                                RouteNames.companyCandidateCompare,
                                queryParameters: {'jobId': widget.jobId},
                              ),
                              icon: const Icon(Icons.compare_arrows),
                              label: const Text('AI Compare candidates'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          ..._filteredCandidates(rankedCandidates).map((
                            candidate,
                          ) {
                            final application = candidate.application;
                            return ApplicantCard(
                              application: application,
                              applicant: candidate.applicant,
                              match: candidate.match,
                              onViewIntelligence: () => context.pushNamed(
                                RouteNames.companyCandidateIntelligence,
                                pathParameters: {
                                  'applicationId': application.id,
                                },
                              ),
                              onScheduleInterview: () => context.pushNamed(
                                RouteNames.scheduleInterview,
                                pathParameters: {
                                  'applicationId': application.id,
                                },
                              ),
                              onViewInterview: application.interviewId == null
                                  ? null
                                  : () => context.pushNamed(
                                      RouteNames.interviewDetail,
                                      pathParameters: {
                                        'interviewId': application.interviewId!,
                                      },
                                    ),
                              onEvaluateInterview:
                                  application.interviewId == null
                                  ? null
                                  : () => context.pushNamed(
                                      RouteNames.evaluateInterview,
                                      pathParameters: {
                                        'interviewId': application.interviewId!,
                                      },
                                    ),
                              onUpdateStatus: (newStatus) async {
                                final latestPermission = await ref.read(
                                  companyPermissionProvider.future,
                                );
                                if (!latestPermission.canReject) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          latestPermission.restrictionMessage,
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                final success = await ref
                                    .read(applicationActionProvider.notifier)
                                    .updatePipelineStatus(
                                      applicationId: application.id,
                                      status: newStatus,
                                      interviewId: application.interviewId,
                                    );
                                if (success && context.mounted) {
                                  ref.invalidate(
                                    jobApplicationsProvider(widget.jobId),
                                  );
                                  ref.invalidate(
                                    rankedJobApplicantsProvider(widget.jobId),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Status updated to ${applicationStatusLabel(newStatus)}',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          }),
                          if (_filteredCandidates(rankedCandidates).isEmpty)
                            const _CandidateEmptyState(),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
      ),
    );
  }

  List<RankedCandidateModel> _filteredCandidates(
    List<RankedCandidateModel> candidates,
  ) {
    final filtered = candidates.where((candidate) {
      final application = candidate.application;
      final match = candidate.match;
      final statusMatches =
          _status == 'all' || application.normalizedStatus == _status;
      if (!statusMatches) return false;

      return switch (_signalFilter) {
        _CandidateSignalFilter.all => true,
        _CandidateSignalFilter.interviewScheduled =>
          application.interviewId != null ||
              application.normalizedStatus == 'interview_scheduled',
        _CandidateSignalFilter.certified => match.certificateScore > 0,
        _CandidateSignalFilter.resumeAvailable => match.resumeScore > 0,
        _CandidateSignalFilter.portfolioAvailable => match.projectScore > 0,
      };
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        _CandidateSort.highestMatch => b.match.matchScore.compareTo(
          a.match.matchScore,
        ),
        _CandidateSort.highestSkill => b.match.skillScoreAverage.compareTo(
          a.match.skillScoreAverage,
        ),
        _CandidateSort.newest => b.application.appliedAt.compareTo(
          a.application.appliedAt,
        ),
      };
    });

    return filtered;
  }
}

class _CompanyPermissionBlocked extends StatelessWidget {
  const _CompanyPermissionBlocked({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.warning,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                'Applicant access locked',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CandidateSort { highestMatch, highestSkill, newest }

enum _CandidateSignalFilter {
  all,
  interviewScheduled,
  certified,
  resumeAvailable,
  portfolioAvailable,
}

class _CandidateIntelligenceHeader extends StatelessWidget {
  const _CandidateIntelligenceHeader({required this.candidates});

  final List<RankedCandidateModel> candidates;

  @override
  Widget build(BuildContext context) {
    final total = candidates.length;
    final highMatch = candidates
        .where((candidate) => candidate.match.matchScore >= 75)
        .length;
    final interviewReady = candidates
        .where(
          (candidate) =>
              candidate.application.interviewId != null ||
              candidate.application.normalizedStatus == 'interview_scheduled',
        )
        .length;
    final certified = candidates
        .where((candidate) => candidate.match.certificateScore > 0)
        .length;
    final resumeReady = candidates
        .where((candidate) => candidate.match.resumeScore > 0)
        .length;
    final averageMatch = total == 0
        ? 0.0
        : candidates
                  .map((candidate) => candidate.match.matchScore)
                  .reduce((a, b) => a + b) /
              total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.elevatedSurface.withValues(alpha: 0.46)
            : AppColors.lightElevatedSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.companyPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.companyPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidate Intelligence Center',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Read-only recruiter insights built from applications, resumes, skill scores, certificates, and project evidence.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mobileColumns: 2,
            tabletColumns: 3,
            desktopColumns: 5,
            wideColumns: 5,
            minChildWidth: 150,
            children: [
              _SignalMetric(label: 'Candidates', value: '$total'),
              _SignalMetric(
                label: 'Avg Match',
                value: '${averageMatch.toStringAsFixed(0)}%',
              ),
              _SignalMetric(label: 'High Match', value: '$highMatch'),
              _SignalMetric(label: 'Interviews', value: '$interviewReady'),
              _SignalMetric(label: 'Certified', value: '$certified'),
              _SignalMetric(label: 'Resume Ready', value: '$resumeReady'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateControls extends StatelessWidget {
  const _CandidateControls({
    required this.status,
    required this.filters,
    required this.sort,
    required this.signalFilter,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onSignalFilterChanged,
  });

  final String status;
  final List<String> filters;
  final _CandidateSort sort;
  final _CandidateSignalFilter signalFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<_CandidateSort> onSortChanged;
  final ValueChanged<_CandidateSignalFilter> onSignalFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in filters)
          ChoiceChip(
            selected: status == item,
            label: Text(item == 'all' ? 'All' : applicationStatusLabel(item)),
            onSelected: (_) => onStatusChanged(item),
          ),
        const SizedBox(width: 8),
        for (final item in _CandidateSort.values)
          ChoiceChip(
            selected: sort == item,
            label: Text(_sortLabel(item)),
            avatar: Icon(_sortIcon(item), size: 16),
            onSelected: (_) => onSortChanged(item),
          ),
        const SizedBox(width: 8),
        for (final item in _CandidateSignalFilter.values)
          ChoiceChip(
            selected: signalFilter == item,
            label: Text(_signalFilterLabel(item)),
            onSelected: (_) => onSignalFilterChanged(item),
          ),
      ],
    );
  }
}

class _SignalMetric extends StatelessWidget {
  const _SignalMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.companyPrimary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.companyPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateEmptyState extends StatelessWidget {
  const _CandidateEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'No candidates match these filters',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a broader status or signal filter to review more applicants.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _sortLabel(_CandidateSort sort) {
  return switch (sort) {
    _CandidateSort.highestMatch => 'Highest Match',
    _CandidateSort.highestSkill => 'Highest Skill',
    _CandidateSort.newest => 'Newest',
  };
}

IconData _sortIcon(_CandidateSort sort) {
  return switch (sort) {
    _CandidateSort.highestMatch => Icons.auto_graph_rounded,
    _CandidateSort.highestSkill => Icons.psychology_rounded,
    _CandidateSort.newest => Icons.schedule_rounded,
  };
}

String _signalFilterLabel(_CandidateSignalFilter filter) {
  return switch (filter) {
    _CandidateSignalFilter.all => 'All Signals',
    _CandidateSignalFilter.interviewScheduled => 'Interview Scheduled',
    _CandidateSignalFilter.certified => 'Certified',
    _CandidateSignalFilter.resumeAvailable => 'Resume Available',
    _CandidateSignalFilter.portfolioAvailable => 'Portfolio / Projects',
  };
}
