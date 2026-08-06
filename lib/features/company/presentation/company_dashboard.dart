import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_role.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/company_permission_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/user_provider.dart';
import '../providers/company_hiring_intelligence_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/dashboard_shell.dart';
import '../../../shared/widgets/dashboard_section.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/profile_completion_card.dart';
import '../../../shared/widgets/quick_action_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/role_theme.dart';

class CompanyDashboard extends ConsumerWidget {
  const CompanyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final companyAsync = ref.watch(companyProvider);
    final intelligenceAsync = ref.watch(companyHiringIntelligenceProvider);
    final permissionAsync = ref.watch(companyPermissionProvider);
    final profile = ref.watch(profileDataProvider).value;
    ref.watch(profileCompletionSyncProvider);

    final user = userAsync.value;
    final company = companyAsync.value;
    final intelligence = intelligenceAsync.value;
    final permission = permissionAsync.value;
    final canManageHiring = permission?.canCreateJob ?? false;
    final canAccessAnalytics = permission?.canAccessAnalytics ?? false;
    final completion = profile?.completion;
    final roleTheme = getRoleTheme(UserRole.company);

    return RoleDashboardFrame(
      role: UserRole.company,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(companyProvider);
          ref.invalidate(companyHiringIntelligenceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // 1. Hero Header
            _CompanyHeroHeader(
              companyName: company?.companyName.isNotEmpty == true
                  ? company!.companyName
                  : (user?.fullName ?? 'Company'),
              photoUrl: user?.photoUrl,
              activeJobsCount: intelligence?.jobSummary.activeJobs ?? 0,
              unreadCount: ref.watch(unreadNotificationCountProvider),
              onProfileTap: () => context.pushNamed(RouteNames.companyProfile),
              onNotificationsTap: () =>
                  context.pushNamed(RouteNames.notificationsInbox),
              onPostJob: canManageHiring
                  ? () => context.pushNamed(RouteNames.createJob)
                  : () => _showCompanyRestriction(context, permission),
              onViewPipeline: canAccessAnalytics
                  ? () => context.push(RoutePaths.hiringPipeline)
                  : () => _showCompanyRestriction(context, permission),
            ),

            if (completion != null && !completion.isComplete)
              ProfileCompletionCard(
                completionPercentage: completion.profileCompletionPercentage,
                isProfileImageMissing: completion.missingFields.contains(
                  'Profile image',
                ),
                missingFields: completion.missingFields,
                onCompleteProfileTap: () =>
                    context.pushNamed(RouteNames.companyEditProfile),
                roleTheme: roleTheme,
              ),

            // 2. Executive Metrics
            DashboardSection(
              title: 'Executive Metrics',
              child: !canAccessAnalytics
                  ? _CompanyPermissionSection(
                      message:
                          permission?.restrictionMessage ??
                          'Company verification is required before viewing hiring metrics.',
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: intelligenceAsync.when(
                        loading: () => const _DashboardLoadingPanel(),
                        error: (_, _) => const _DashboardErrorPanel(
                          title: 'Metrics unavailable',
                          message:
                              'We could not load hiring intelligence right now. Pull down to retry.',
                        ),
                        data: (data) => _ExecutiveMetricsGrid(
                          intelligence: data,
                          roleTheme: roleTheme,
                        ),
                      ),
                    ),
            ),

            // 3. Today's Hiring Workspace
            DashboardSection(
              title: "Today's Hiring Workspace",
              child: !canAccessAnalytics
                  ? _CompanyPermissionSection(
                      message:
                          permission?.restrictionMessage ??
                          'Company verification is required before viewing the hiring workspace.',
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: intelligenceAsync.when(
                        loading: () => const _DashboardLoadingPanel(),
                        error: (_, _) => const _DashboardErrorPanel(
                          title: 'Workspace unavailable',
                          message:
                              'Hiring tasks could not be loaded. Pull down to retry.',
                        ),
                        data: (data) => _HiringWorkspaceGrid(
                          intelligence: data,
                          roleTheme: roleTheme,
                        ),
                      ),
                    ),
            ),

            // 4. Hiring Pipeline Snapshot
            DashboardSection(
              title: 'Hiring Pipeline',
              actionText: 'Full Pipeline',
              onActionTap: canAccessAnalytics
                  ? () => context.push(RoutePaths.hiringPipeline)
                  : () => _showCompanyRestriction(context, permission),
              child: !canAccessAnalytics
                  ? _CompanyPermissionSection(
                      message:
                          permission?.restrictionMessage ??
                          'Company verification is required before viewing hiring pipeline analytics.',
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: intelligenceAsync.when(
                        loading: () => const _DashboardLoadingPanel(),
                        error: (_, _) => const _DashboardErrorPanel(
                          title: 'Pipeline unavailable',
                          message:
                              'Pipeline data could not be loaded right now.',
                        ),
                        data: (data) => _PipelinePreviewGrid(
                          intelligence: data,
                          roleTheme: roleTheme,
                        ),
                      ),
                    ),
            ),

            // 5. Hiring Analytics
            DashboardSection(
              title: 'Hiring Analytics',
              child: !canAccessAnalytics
                  ? _CompanyPermissionSection(
                      message:
                          permission?.restrictionMessage ??
                          'Company verification is required before viewing hiring analytics.',
                    )
                  : intelligenceAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: _DashboardLoadingPanel(),
                      ),
                      error: (_, _) => const DashboardEmptyState(
                        icon: Icons.analytics_outlined,
                        title: 'Hiring analytics unavailable',
                        message:
                            'We could not load hiring analytics right now.',
                      ),
                      data: (data) =>
                          _HiringAnalyticsSection(intelligence: data),
                    ),
            ),

            // 6. Job Health
            DashboardSection(
              title: 'Job Health',
              actionText: 'Manage Jobs',
              onActionTap: () => context.pushNamed(RouteNames.companyJobs),
              child: !canAccessAnalytics
                  ? _CompanyPermissionSection(
                      message:
                          permission?.restrictionMessage ??
                          'Company verification is required before viewing job health.',
                    )
                  : intelligenceAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: _DashboardLoadingPanel(),
                      ),
                      error: (_, _) => const DashboardEmptyState(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Job health unavailable',
                        message:
                            'We could not analyze active job health right now.',
                      ),
                      data: (data) => _JobHealthSection(intelligence: data),
                    ),
            ),

            // 7. Top Candidates
            DashboardSection(
              title: 'Top Candidates',
              actionText: 'Review Candidates',
              onActionTap: canAccessAnalytics
                  ? () => context.push(RoutePaths.hiringPipeline)
                  : () => _showCompanyRestriction(context, permission),
              child: !canAccessAnalytics
                  ? _CompanyPermissionSection(
                      message:
                          permission?.restrictionMessage ??
                          'Company verification is required before viewing candidate intelligence.',
                    )
                  : intelligenceAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: _DashboardLoadingPanel(),
                      ),
                      error: (_, _) => const DashboardEmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'Candidate intelligence unavailable',
                        message:
                            'Top candidate signals could not be loaded right now.',
                      ),
                      data: (data) => _TopCandidatesSection(intelligence: data),
                    ),
            ),

            // 8. Hiring Alerts
            DashboardSection(
              title: 'Hiring Alerts',
              child: intelligenceAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _DashboardLoadingPanel(),
                ),
                error: (_, _) => const DashboardEmptyState(
                  icon: Icons.notifications_active_outlined,
                  title: 'Alerts unavailable',
                  message: 'Hiring alerts could not be generated right now.',
                ),
                data: (data) => _HiringAlertsSection(intelligence: data),
              ),
            ),

            // 9. Quick Actions
            DashboardSection(
              title: 'Quick Action Center',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _CommandActionsGrid(
                  roleTheme: roleTheme,
                  permission: permission,
                ),
              ),
            ),

            // 10. Recent Hiring Activity / Employees
            DashboardSection(
              title: 'Hiring Lifecycle',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    DashboardEmptyState(
                      icon: Icons.badge_rounded,
                      title: 'Employees & onboarding',
                      message:
                          'Track active employees, pending joins, offers, and hiring analytics.',
                      actionLabel: 'Open Employees',
                      onAction: () =>
                          context.pushNamed(RouteNames.companyEmployees),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          context.pushNamed(RouteNames.companyHiringAnalytics),
                      child: const Text('View hiring analytics'),
                    ),
                  ],
                ),
              ),
            ),

            // 11. Recruiter Recommendations
            DashboardSection(
              title: 'Recruiter Recommendations',
              child: intelligenceAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _DashboardLoadingPanel(),
                ),
                error: (_, _) => const DashboardEmptyState(
                  icon: Icons.psychology_alt_rounded,
                  title: 'Recommendations unavailable',
                  message:
                      'We could not generate recruiter recommendations right now.',
                ),
                data: (data) => _RecommendationsSection(intelligence: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyHeroHeader extends StatelessWidget {
  const _CompanyHeroHeader({
    required this.companyName,
    this.photoUrl,
    required this.activeJobsCount,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onPostJob,
    required this.onViewPipeline,
    this.unreadCount = 0,
  });

  final String companyName;
  final String? photoUrl;
  final int activeJobsCount;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onPostJob;
  final VoidCallback onViewPipeline;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.companyPrimary.withValues(alpha: 0.15),
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.3),
        ),
        boxShadow: isDark ? AppTheme.darkShadowSm : AppTheme.lightShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.companyPrimary.withValues(
                    alpha: 0.2,
                  ),
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          companyName.isNotEmpty
                              ? companyName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.companyPrimary,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          activeJobsCount > 0
                              ? 'Hiring for $activeJobsCount roles'
                              : 'Ready to hire',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: onNotificationsTap,
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPostJob,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text(
                    'Post Job',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.companyPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onViewPipeline,
                  icon: const Icon(Icons.account_tree_rounded),
                  label: const Text(
                    'View Pipeline',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutiveMetricsGrid extends StatelessWidget {
  const _ExecutiveMetricsGrid({
    required this.intelligence,
    required this.roleTheme,
  });

  final CompanyHiringIntelligence intelligence;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final jobs = intelligence.jobSummary;
    final applications = intelligence.applicationSummary;

    return ResponsiveGrid(
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 6,
      wideColumns: 6,
      minChildWidth: 180,
      children: [
        _NavMetricCard(
          title: 'Active Jobs',
          value: jobs.activeJobs.toString(),
          icon: Icons.work_rounded,
          color: roleTheme.primary,
          onTap: () => context.pushNamed(RouteNames.companyJobs),
        ),
        _NavMetricCard(
          title: 'Open Positions',
          value: jobs.activeJobs.toString(),
          icon: Icons.business_center_rounded,
          color: AppColors.info,
          onTap: () => context.pushNamed(RouteNames.companyJobs),
        ),
        _NavMetricCard(
          title: 'Applicants',
          value: applications.totalApplications.toString(),
          icon: Icons.people_alt_rounded,
          color: roleTheme.primary,
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
        _NavMetricCard(
          title: 'Pending Reviews',
          value: (applications.applied + applications.screening).toString(),
          icon: Icons.rate_review_rounded,
          color: AppColors.warning,
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
        _NavMetricCard(
          title: 'Offers',
          value: applications.offer.toString(),
          icon: Icons.local_offer_rounded,
          color: AppColors.secondary,
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
        _NavMetricCard(
          title: 'Hired',
          value: (applications.hired + applications.selected).toString(),
          icon: Icons.workspace_premium_rounded,
          color: AppColors.success,
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
      ],
    );
  }
}

class _HiringWorkspaceGrid extends StatelessWidget {
  const _HiringWorkspaceGrid({
    required this.intelligence,
    required this.roleTheme,
  });

  final CompanyHiringIntelligence intelligence;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final applications = intelligence.applicationSummary;
    final interviews = intelligence.interviewSummary;
    final jobs = intelligence.jobSummary;
    final candidates = intelligence.candidateIntelligence;

    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      minChildWidth: 240,
      children: [
        _WorkspaceActionCard(
          title: 'Review Applicants',
          value: (applications.applied + applications.screening).toString(),
          description: applications.applied + applications.screening == 0
              ? 'No applicants waiting for initial review.'
              : 'Applicants are waiting for recruiter review.',
          icon: Icons.assignment_ind_rounded,
          color: AppColors.warning,
          buttonLabel: 'Open Pipeline',
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
        _WorkspaceActionCard(
          title: 'Candidate Decisions',
          value: candidates.candidatesNeedingReview.toString(),
          description: candidates.candidatesNeedingReview == 0
              ? 'No ranked candidates need immediate review.'
              : 'Ranked candidates need a next step decision.',
          icon: Icons.fact_check_rounded,
          color: roleTheme.primary,
          buttonLabel: 'Review',
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
        _WorkspaceActionCard(
          title: 'Interviews',
          value: (applications.interview + interviews.pendingEvaluations)
              .toString(),
          description:
              applications.interview + interviews.pendingEvaluations == 0
              ? 'No candidates are waiting in interview review.'
              : 'Interview-stage candidates need feedback and decisions.',
          icon: Icons.rate_review_rounded,
          color: AppColors.info,
          buttonLabel: 'Open Interviews',
          onTap: () => context.pushNamed(RouteNames.myInterviews),
        ),
        _WorkspaceActionCard(
          title: 'Zero Applicant Jobs',
          value: jobs.jobsWithZeroApplicants.toString(),
          description: jobs.jobsWithZeroApplicants == 0
              ? 'Every posted job has applicant activity.'
              : 'Some roles need visibility or requirement tuning.',
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          buttonLabel: 'Manage Jobs',
          onTap: () => context.pushNamed(RouteNames.companyJobs),
        ),
      ],
    );
  }
}

class _PipelinePreviewGrid extends StatelessWidget {
  const _PipelinePreviewGrid({
    required this.intelligence,
    required this.roleTheme,
  });

  final CompanyHiringIntelligence intelligence;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final funnel = intelligence.funnel;
    final applications = intelligence.applicationSummary;

    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 5,
      wideColumns: 5,
      minChildWidth: 210,
      children: [
        _PipelineStageCard(
          title: 'Applied',
          count: funnel.applied,
          rateLabel: '${applications.totalApplications} total',
          progress: _stageProgress(
            funnel.applied,
            applications.totalApplications,
          ),
          color: roleTheme.primary,
        ),
        _PipelineStageCard(
          title: 'Shortlisted',
          count: funnel.shortlisted,
          rateLabel: '${funnel.shortlistRate.toStringAsFixed(0)}% from applied',
          progress: funnel.shortlistRate / 100,
          color: AppColors.info,
        ),
        _PipelineStageCard(
          title: 'Interview',
          count: funnel.interviewScheduled,
          rateLabel:
              '${funnel.interviewRate.toStringAsFixed(0)}% from shortlist',
          progress: funnel.interviewRate / 100,
          color: AppColors.warning,
        ),
        _PipelineStageCard(
          title: 'Offers',
          count: applications.offer,
          rateLabel:
              '${_rate(applications.offer, applications.totalApplications).toStringAsFixed(0)}% of candidates',
          progress:
              _rate(applications.offer, applications.totalApplications) / 100,
          color: roleTheme.secondary,
        ),
        _PipelineStageCard(
          title: 'Hired',
          count: funnel.selected,
          rateLabel: '${funnel.selectionRate.toStringAsFixed(0)}% hired',
          progress: funnel.selectionRate / 100,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _PipelineStageCard extends StatelessWidget {
  const _PipelineStageCard({
    required this.title,
    required this.count,
    required this.rateLabel,
    required this.progress,
    required this.color,
  });

  final String title;
  final int count;
  final String rateLabel;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: count.toString(), color: color),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          _ProgressLine(value: progress, color: color),
          const SizedBox(height: 8),
          Text(
            rateLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HiringAnalyticsSection extends StatelessWidget {
  const _HiringAnalyticsSection({required this.intelligence});

  final CompanyHiringIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final analytics = _HiringAnalyticsSnapshot.from(intelligence);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            wideColumns: 4,
            minChildWidth: 230,
            children: [
              _AnalyticsTile(
                title: 'Total Applicants',
                value: intelligence.applicationSummary.totalApplications
                    .toString(),
                icon: Icons.groups_rounded,
                color: AppColors.companyPrimary,
                detail: 'Across all company jobs',
              ),
              _AnalyticsTile(
                title: 'Selection Rate',
                value:
                    '${_rate(intelligence.applicationSummary.selected, intelligence.applicationSummary.totalApplications).toStringAsFixed(0)}%',
                icon: Icons.workspace_premium_rounded,
                color: AppColors.success,
                detail: 'Selected from total applicants',
              ),
              _AnalyticsTile(
                title: 'Interview Rate',
                value:
                    '${_rate(intelligence.funnel.interviewScheduled, intelligence.applicationSummary.totalApplications).toStringAsFixed(0)}%',
                icon: Icons.event_available_rounded,
                color: AppColors.info,
                detail: 'Scheduled interviews from applicants',
              ),
              _AnalyticsTile(
                title: 'Average Match',
                value:
                    '${intelligence.candidateIntelligence.averageMatchScore.toStringAsFixed(0)}%',
                icon: Icons.auto_graph_rounded,
                color: AppColors.companySecondary,
                detail: 'From ranked candidate signals',
              ),
              _AnalyticsTile(
                title: 'Average Skill Score',
                value: analytics.averageSkillScore == null
                    ? 'N/A'
                    : '${analytics.averageSkillScore!.toStringAsFixed(0)}%',
                icon: Icons.psychology_rounded,
                color: AppColors.warning,
                detail: analytics.averageSkillScore == null
                    ? 'No ranked skill evidence yet'
                    : 'Average across top ranked candidates',
              ),
              const _AnalyticsTile(
                title: 'Average Hiring Time',
                value: 'N/A',
                icon: Icons.timer_outlined,
                color: AppColors.info,
                detail: 'Hiring date history is not exposed yet',
              ),
              _AnalyticsTile(
                title: 'Zero Applicant Jobs',
                value: intelligence.jobSummary.jobsWithZeroApplicants
                    .toString(),
                icon: Icons.campaign_rounded,
                color: AppColors.error,
                detail: 'Jobs needing visibility or requirement tuning',
              ),
              _AnalyticsTile(
                title: 'High Match Jobs',
                value: intelligence.jobSummary.jobsWithHighMatchCandidates
                    .toString(),
                icon: Icons.verified_user_rounded,
                color: AppColors.success,
                detail: 'Jobs with strong candidate signals',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AnalyticsPipelineCard(intelligence: intelligence),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            wideColumns: 3,
            minChildWidth: 280,
            children: [
              _AnalyticsHighlightCard(
                title: 'Highest Performing Job',
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
                primary:
                    analytics.highestPerformingJob?.jobTitle ??
                    'No job performance yet',
                secondary: analytics.highestPerformingJob == null
                    ? 'Publish jobs and collect applications to unlock this.'
                    : '${analytics.highestPerformingJob!.healthScore.toStringAsFixed(0)} health score',
              ),
              _AnalyticsHighlightCard(
                title: 'Highest Match Job',
                icon: Icons.track_changes_rounded,
                color: AppColors.companyPrimary,
                primary:
                    analytics.highestMatchJob?.jobTitle ?? 'No match data yet',
                secondary: analytics.highestMatchJob == null
                    ? 'Candidate matching appears after applications arrive.'
                    : '${analytics.highestMatchJob!.averageMatchScore.toStringAsFixed(0)}% average match',
              ),
              _AnalyticsHighlightCard(
                title: 'Highest Conversion Job',
                icon: Icons.account_tree_rounded,
                color: AppColors.info,
                primary:
                    analytics.highestConversionJob?.jobTitle ??
                    'No conversions yet',
                secondary: analytics.highestConversionJob == null
                    ? 'Selected candidates will unlock conversion insight.'
                    : '${analytics.highestConversionJob!.selectedCount} selected candidates',
              ),
              _AnalyticsHighlightCard(
                title: 'Most Skilled Candidate',
                icon: Icons.psychology_rounded,
                color: AppColors.warning,
                primary:
                    analytics.mostSkilled?.candidateName ?? 'No skill data yet',
                secondary: analytics.mostSkilled == null
                    ? 'Skill scores appear after ranked applications.'
                    : '${analytics.mostSkilled!.match.skillScoreAverage.toStringAsFixed(0)}% skill score for ${analytics.mostSkilled!.jobTitle}',
              ),
              _AnalyticsHighlightCard(
                title: 'Most Certified Candidate',
                icon: Icons.workspace_premium_rounded,
                color: AppColors.success,
                primary:
                    analytics.mostCertified?.candidateName ??
                    'No certificate signal yet',
                secondary: analytics.mostCertified == null
                    ? 'Active certificate signals are not available yet.'
                    : '${analytics.mostCertified!.match.certificateScore.toStringAsFixed(0)}% certificate signal',
              ),
              _AnalyticsHighlightCard(
                title: 'Highest Match Candidate',
                icon: Icons.stars_rounded,
                color: AppColors.companySecondary,
                primary:
                    analytics.highestMatch?.candidateName ?? 'No candidate yet',
                secondary: analytics.highestMatch == null
                    ? 'Ranked candidates will appear after applications.'
                    : '${analytics.highestMatch!.match.matchScore.toStringAsFixed(0)}% match for ${analytics.highestMatch!.jobTitle}',
              ),
              const _AnalyticsHighlightCard(
                title: 'Highest Grand Test',
                icon: Icons.military_tech_rounded,
                color: AppColors.info,
                primary: 'Not tracked yet',
                secondary:
                    'Grand test score is not exposed in the company intelligence provider.',
              ),
              _AnalyticsHighlightCard(
                title: 'Highest Portfolio',
                icon: Icons.folder_special_rounded,
                color: AppColors.accent,
                primary:
                    analytics.highestPortfolio?.candidateName ??
                    'No portfolio signal yet',
                secondary: analytics.highestPortfolio == null
                    ? 'Portfolio/project evidence appears through resume intelligence.'
                    : '${analytics.highestPortfolio!.match.projectScore.toStringAsFixed(0)}% project evidence',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AnalyticsRecommendations(snapshot: analytics),
        ],
      ),
    );
  }
}

class _AnalyticsPipelineCard extends StatelessWidget {
  const _AnalyticsPipelineCard({required this.intelligence});

  final CompanyHiringIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final applications = intelligence.applicationSummary;
    final stages = [
      _AnalyticsStage(
        'Applied',
        applications.totalApplications,
        AppColors.companyPrimary,
        1,
      ),
      _AnalyticsStage(
        'Reviewed',
        applications.shortlisted +
            applications.interviewScheduled +
            applications.interviewCompleted +
            applications.selected +
            applications.rejected +
            applications.onHold,
        AppColors.info,
        _stageRatio(
          applications.shortlisted +
              applications.interviewScheduled +
              applications.interviewCompleted +
              applications.selected +
              applications.rejected +
              applications.onHold,
          applications.totalApplications,
        ),
      ),
      _AnalyticsStage(
        'Shortlisted',
        intelligence.funnel.shortlisted,
        AppColors.warning,
        _stageRatio(
          intelligence.funnel.shortlisted,
          applications.totalApplications,
        ),
      ),
      _AnalyticsStage(
        'Interview',
        intelligence.funnel.interviewScheduled,
        AppColors.companySecondary,
        _stageRatio(
          intelligence.funnel.interviewScheduled,
          applications.totalApplications,
        ),
      ),
      _AnalyticsStage(
        'Selected',
        intelligence.funnel.selected,
        AppColors.success,
        _stageRatio(
          intelligence.funnel.selected,
          applications.totalApplications,
        ),
      ),
      const _AnalyticsStage('Hired', 0, AppColors.info, 0),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, AppColors.companyPrimary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enterprise Hiring Funnel',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Hired is shown as not tracked because the existing application status model currently ends at Selected.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            wideColumns: 6,
            minChildWidth: 150,
            children: [
              for (final stage in stages) _AnalyticsStageTile(stage: stage),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsStageTile extends StatelessWidget {
  const _AnalyticsStageTile({required this.stage});

  final _AnalyticsStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stage.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stage.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(label: stage.count.toString(), color: stage.color),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressLine(value: stage.progress, color: stage.color),
        ],
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.detail,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsHighlightCard extends StatelessWidget {
  const _AnalyticsHighlightCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            primary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            secondary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsRecommendations extends StatelessWidget {
  const _AnalyticsRecommendations({required this.snapshot});

  final _HiringAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final recommendations = snapshot.recommendations;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, AppColors.companyPrimary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Recommendations',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < recommendations.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  color: AppColors.companyPrimary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recommendations[index],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (index != recommendations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _JobHealthSection extends StatelessWidget {
  const _JobHealthSection({required this.intelligence});

  final CompanyHiringIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final health = intelligence.jobHealth;
    if (health.isEmpty) {
      return DashboardEmptyState(
        icon: Icons.monitor_heart_outlined,
        title: 'No jobs to analyze yet',
        message: 'Post a job and applicant health will appear here.',
        actionLabel: 'Post a Job',
        onAction: () => context.pushNamed(RouteNames.createJob),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ResponsiveGrid(
        mobileColumns: 1,
        tabletColumns: 2,
        desktopColumns: 3,
        wideColumns: 3,
        minChildWidth: 280,
        children: [
          for (final item in health.take(6))
            _JobHealthCard(
              health: item,
              onTap: () => context.pushNamed(
                RouteNames.jobApplicants,
                pathParameters: {'id': item.jobId},
              ),
            ),
        ],
      ),
    );
  }
}

class _TopCandidatesSection extends StatelessWidget {
  const _TopCandidatesSection({required this.intelligence});

  final CompanyHiringIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final candidates = intelligence.candidateIntelligence.topCandidates;
    if (candidates.isEmpty) {
      return DashboardEmptyState(
        icon: Icons.person_search_rounded,
        title: 'No ranked candidates yet',
        message:
            'Top candidates appear once applications arrive and matching data is available.',
        actionLabel: 'Manage Jobs',
        onAction: () => context.pushNamed(RouteNames.companyJobs),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ResponsiveGrid(
        mobileColumns: 1,
        tabletColumns: 2,
        desktopColumns: 3,
        wideColumns: 3,
        minChildWidth: 300,
        children: [
          for (final candidate in candidates.take(6))
            _CandidateCard(
              candidate: candidate,
              onTap: () => context.pushNamed(
                RouteNames.jobApplicants,
                pathParameters: {'id': candidate.jobId},
              ),
            ),
        ],
      ),
    );
  }
}

class _HiringAlertsSection extends StatelessWidget {
  const _HiringAlertsSection({required this.intelligence});

  final CompanyHiringIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final alerts = <_DashboardAlert>[
      if (intelligence.applicationSummary.applied > 0)
        _DashboardAlert(
          icon: Icons.rate_review_rounded,
          title:
              '${intelligence.applicationSummary.applied} applicants waiting for review',
          message:
              'Move strong applicants forward before the queue gets stale.',
          color: AppColors.warning,
          onTap: () => context.push(RoutePaths.hiringPipeline),
        ),
      if (intelligence.interviewSummary.pendingEvaluations > 0)
        _DashboardAlert(
          icon: Icons.fact_check_rounded,
          title:
              '${intelligence.interviewSummary.pendingEvaluations} interviews need evaluation',
          message: 'Complete feedback so candidate decisions stay clear.',
          color: AppColors.info,
          onTap: () => context.pushNamed(RouteNames.myInterviews),
        ),
      if (intelligence.jobSummary.jobsWithZeroApplicants > 0)
        _DashboardAlert(
          icon: Icons.campaign_rounded,
          title:
              '${intelligence.jobSummary.jobsWithZeroApplicants} jobs have no applicants',
          message:
              'Improve job clarity, skills, or visibility for these roles.',
          color: AppColors.error,
          onTap: () => context.pushNamed(RouteNames.companyJobs),
        ),
      if (intelligence.interviewSummary.upcomingInterviews > 0)
        _DashboardAlert(
          icon: Icons.event_available_rounded,
          title:
              '${intelligence.interviewSummary.upcomingInterviews} upcoming interviews',
          message: 'Prepare scorecards and questions for scheduled interviews.',
          color: AppColors.success,
          onTap: () => context.pushNamed(RouteNames.myInterviews),
        ),
    ];

    if (alerts.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No urgent hiring alerts',
        message:
            'Your hiring workspace is calm right now. Keep checking candidates and interviews.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ResponsiveGrid(
        mobileColumns: 1,
        tabletColumns: 2,
        desktopColumns: 2,
        wideColumns: 2,
        minChildWidth: 320,
        children: [for (final alert in alerts) _AlertTile(alert: alert)],
      ),
    );
  }
}

class _CommandActionsGrid extends StatelessWidget {
  const _CommandActionsGrid({
    required this.roleTheme,
    required this.permission,
  });

  final RoleThemeColors roleTheme;
  final CompanyPermissionState? permission;

  @override
  Widget build(BuildContext context) {
    final canManageHiring = permission?.canCreateJob ?? false;
    final canAccessAnalytics = permission?.canAccessAnalytics ?? false;
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      children: [
        SieInteractive(
          targetId: 'company.dashboard.action.post_job',
          button: true,
          child: QuickActionCard(
            title: 'Post Job',
            icon: Icons.post_add_rounded,
            color: AppColors.companyPrimary,
            onTap: canManageHiring
                ? () => context.pushNamed(RouteNames.createJob)
                : () => _showCompanyRestriction(context, permission),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.manage_jobs',
          button: true,
          child: QuickActionCard(
            title: 'Manage Jobs',
            icon: Icons.business_center_rounded,
            color: AppColors.info,
            onTap: () => context.pushNamed(RouteNames.companyJobs),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.pipeline',
          button: true,
          child: QuickActionCard(
            title: 'Hiring Pipeline',
            icon: Icons.account_tree_rounded,
            color: roleTheme.secondary,
            onTap: canAccessAnalytics
                ? () => context.push(RoutePaths.hiringPipeline)
                : () => _showCompanyRestriction(context, permission),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.ai_hiring',
          button: true,
          child: QuickActionCard(
            title: 'AI Hiring Assistant',
            icon: Icons.auto_awesome_rounded,
            color: AppColors.companyPrimary,
            onTap: canAccessAnalytics
                ? () => context.pushNamed(RouteNames.companyAiHiringAssistant)
                : () => _showCompanyRestriction(context, permission),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.career_intel',
          button: true,
          child: QuickActionCard(
            title: 'Talent Intelligence',
            icon: Icons.psychology_alt_rounded,
            color: AppColors.info,
            onTap: canAccessAnalytics
                ? () => context.pushNamed(RouteNames.careerIntelligence)
                : () => _showCompanyRestriction(context, permission),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.interviews',
          button: true,
          child: QuickActionCard(
            title: 'Interviews',
            icon: Icons.event_available_rounded,
            color: AppColors.warning,
            onTap: canManageHiring
                ? () => context.pushNamed(RouteNames.myInterviews)
                : () => _showCompanyRestriction(context, permission),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.review_candidates',
          button: true,
          child: QuickActionCard(
            title: 'Review Candidates',
            icon: Icons.manage_search_rounded,
            color: AppColors.success,
            onTap: canAccessAnalytics
                ? () => context.push(RoutePaths.hiringPipeline)
                : () => _showCompanyRestriction(context, permission),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.notifications',
          button: true,
          child: QuickActionCard(
            title: 'Notifications',
            icon: Icons.notifications_active_outlined,
            color: AppColors.info,
            onTap: () => context.pushNamed(RouteNames.notificationsInbox),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.profile',
          button: true,
          child: QuickActionCard(
            title: 'Company Profile',
            icon: Icons.domain_verification_rounded,
            color: AppColors.companySecondary,
            onTap: () => context.pushNamed(RouteNames.companyProfile),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.employees',
          button: true,
          child: QuickActionCard(
            title: 'Employees',
            icon: Icons.badge_rounded,
            color: AppColors.companyPrimary,
            onTap: () => context.pushNamed(RouteNames.companyEmployees),
          ),
        ),
        SieInteractive(
          targetId: 'company.dashboard.action.contact_support',
          button: true,
          child: QuickActionCard(
            title: 'Contact Support',
            icon: Icons.support_agent_outlined,
            color: AppColors.accent,
            onTap: () => context.pushNamed(RouteNames.contactUs),
          ),
        ),
      ],
    );
  }
}

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection({required this.intelligence});

  final CompanyHiringIntelligence intelligence;

  @override
  Widget build(BuildContext context) {
    final recommendations = intelligence.recommendations;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var index = 0; index < recommendations.length; index++) ...[
            _RecommendationTile(index: index + 1, text: recommendations[index]),
            if (index != recommendations.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _NavMetricCard extends StatelessWidget {
  const _NavMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: MetricCard(title: title, value: value, icon: icon, color: color),
    );
  }
}

class _WorkspaceActionCard extends StatelessWidget {
  const _WorkspaceActionCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    required this.buttonLabel,
    required this.onTap,
  });

  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobHealthCard extends StatelessWidget {
  const _JobHealthCard({required this.health, required this.onTap});

  final CompanyJobHealth health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _healthColor(health.healthStatus);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(context, color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    health.jobTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(label: health.healthStatus, color: color),
              ],
            ),
            const SizedBox(height: 14),
            _ProgressLine(value: health.healthScore / 100, color: color),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(
                  label: 'Applicants',
                  value: health.applicantCount.toString(),
                ),
                _MiniStat(
                  label: 'Avg Match',
                  value: '${health.averageMatchScore.toStringAsFixed(0)}%',
                ),
                _MiniStat(
                  label: 'Pending',
                  value: health.pendingReviewCount.toString(),
                ),
                _MiniStat(
                  label: 'Interviews',
                  value: health.interviewCount.toString(),
                ),
                _MiniStat(
                  label: 'Selected',
                  value: health.selectedCount.toString(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              health.reason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (health.topCandidate != null) ...[
              const SizedBox(height: 12),
              _StatusPill(
                label: 'Top: ${health.topCandidate!.candidateName}',
                color: AppColors.success,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.onTap});

  final CompanyCandidateSignal candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = candidate.match.matchScore;
    final color = score >= 75
        ? AppColors.success
        : score >= 55
        ? AppColors.warning
        : AppColors.info;
    final strengths = candidate.match.matchedSkills.take(3).toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(context, color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Text(
                    candidate.candidateName.isNotEmpty
                        ? candidate.candidateName[0].toUpperCase()
                        : 'C',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.candidateName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        candidate.jobTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: '${score.toStringAsFixed(0)}%',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProgressLine(value: score / 100, color: color),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(
                  label: 'Skill',
                  value:
                      '${candidate.match.skillScoreAverage.toStringAsFixed(0)}%',
                ),
                _MiniStat(
                  label: 'Resume',
                  value: '${candidate.match.resumeScore.toStringAsFixed(0)}%',
                ),
                _MiniStat(
                  label: 'Certs',
                  value:
                      '${candidate.match.certificateScore.toStringAsFixed(0)}%',
                ),
                _MiniStat(
                  label: 'Projects',
                  value: '${candidate.match.projectScore.toStringAsFixed(0)}%',
                ),
              ],
            ),
            if (strengths.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in strengths)
                    _StatusPill(label: skill, color: AppColors.companyPrimary),
                ],
              ),
            ],
            if (candidate.match.recommendationReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                candidate.match.recommendationReason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final _DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: alert.onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(context, alert.color),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(alert.icon, color: alert.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, AppColors.companyPrimary),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.companyPrimary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              index.toString().padLeft(2, '0'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.companyPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.48,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: value.clamp(0, 1).toDouble(),
        color: color,
        backgroundColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}

class _DashboardLoadingPanel extends StatelessWidget {
  const _DashboardLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(context, AppColors.companyPrimary),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DashboardErrorPanel extends StatelessWidget {
  const _DashboardErrorPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DashboardEmptyState(
      icon: Icons.cloud_off_outlined,
      title: title,
      message: message,
    );
  }
}

class _CompanyPermissionSection extends StatelessWidget {
  const _CompanyPermissionSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _panelDecoration(context, AppColors.warning),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.warning,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company verification required',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAlert {
  const _DashboardAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final VoidCallback onTap;
}

void _showCompanyRestriction(
  BuildContext context,
  CompanyPermissionState? permission,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        permission?.restrictionMessage ??
            'Company verification is required before performing this action.',
      ),
    ),
  );
}

class _HiringAnalyticsSnapshot {
  const _HiringAnalyticsSnapshot({
    required this.averageSkillScore,
    required this.highestPerformingJob,
    required this.highestMatchJob,
    required this.highestConversionJob,
    required this.mostSkilled,
    required this.mostCertified,
    required this.highestMatch,
    required this.highestPortfolio,
    required this.recommendations,
  });

  final double? averageSkillScore;
  final CompanyJobHealth? highestPerformingJob;
  final CompanyJobHealth? highestMatchJob;
  final CompanyJobHealth? highestConversionJob;
  final CompanyCandidateSignal? mostSkilled;
  final CompanyCandidateSignal? mostCertified;
  final CompanyCandidateSignal? highestMatch;
  final CompanyCandidateSignal? highestPortfolio;
  final List<String> recommendations;

  factory _HiringAnalyticsSnapshot.from(
    CompanyHiringIntelligence intelligence,
  ) {
    final candidates = intelligence.candidateIntelligence.topCandidates;
    final health = intelligence.jobHealth;
    final averageSkill = _averageOrNull(
      candidates.map((candidate) => candidate.match.skillScoreAverage),
    );

    final highestPerformingJob = _bestJob(
      health,
      (job) => job.healthScore,
      requirePositive: false,
    );
    final highestMatchJob = _bestJob(health, (job) => job.averageMatchScore);
    final highestConversionJob = _bestJob(
      health,
      (job) => job.selectedCount.toDouble(),
    );
    final mostSkilled = _bestCandidate(
      candidates,
      (candidate) => candidate.match.skillScoreAverage,
    );
    final mostCertified = _bestCandidate(
      candidates,
      (candidate) => candidate.match.certificateScore,
    );
    final highestMatch = _bestCandidate(
      candidates,
      (candidate) => candidate.match.matchScore,
      requirePositive: false,
    );
    final highestPortfolio = _bestCandidate(
      candidates,
      (candidate) => candidate.match.projectScore,
    );

    return _HiringAnalyticsSnapshot(
      averageSkillScore: averageSkill,
      highestPerformingJob: highestPerformingJob,
      highestMatchJob: highestMatchJob,
      highestConversionJob: highestConversionJob,
      mostSkilled: mostSkilled,
      mostCertified: mostCertified,
      highestMatch: highestMatch,
      highestPortfolio: highestPortfolio,
      recommendations: _analyticsRecommendations(
        intelligence: intelligence,
        averageSkillScore: averageSkill,
        highestMatch: highestMatch,
        highestConversionJob: highestConversionJob,
      ),
    );
  }
}

class _AnalyticsStage {
  const _AnalyticsStage(this.label, this.count, this.color, this.progress);

  final String label;
  final int count;
  final Color color;
  final double progress;
}

double? _averageOrNull(Iterable<num> values) {
  final list = values
      .map((value) => value.toDouble())
      .where((value) => value > 0)
      .toList();
  if (list.isEmpty) return null;
  return (list.reduce((a, b) => a + b) / list.length).clamp(0, 100).toDouble();
}

CompanyJobHealth? _bestJob(
  List<CompanyJobHealth> jobs,
  double Function(CompanyJobHealth job) score, {
  bool requirePositive = true,
}) {
  if (jobs.isEmpty) return null;
  final ranked = [...jobs]..sort((a, b) => score(b).compareTo(score(a)));
  final best = ranked.first;
  if (requirePositive && score(best) <= 0) return null;
  return best;
}

CompanyCandidateSignal? _bestCandidate(
  List<CompanyCandidateSignal> candidates,
  double Function(CompanyCandidateSignal candidate) score, {
  bool requirePositive = true,
}) {
  if (candidates.isEmpty) return null;
  final ranked = [...candidates]..sort((a, b) => score(b).compareTo(score(a)));
  final best = ranked.first;
  if (requirePositive && score(best) <= 0) return null;
  return best;
}

List<String> _analyticsRecommendations({
  required CompanyHiringIntelligence intelligence,
  required double? averageSkillScore,
  required CompanyCandidateSignal? highestMatch,
  required CompanyJobHealth? highestConversionJob,
}) {
  final recommendations = <String>[];
  if (intelligence.jobSummary.jobsWithZeroApplicants > 0) {
    recommendations.add(
      '${intelligence.jobSummary.jobsWithZeroApplicants} jobs have zero applicants. Improve job titles, required skills, or visibility.',
    );
  }
  if (intelligence.funnel.interviewScheduled == 0 &&
      intelligence.applicationSummary.totalApplications > 0) {
    recommendations.add(
      'Applicants exist, but interview conversion is still 0%. Shortlist qualified candidates and schedule interviews.',
    );
  }
  if (intelligence.funnel.selectionRate > 0 &&
      intelligence.funnel.selectionRate < 20) {
    recommendations.add(
      'Selection rate is below 20%. Review screening quality and interview criteria.',
    );
  }
  if ((averageSkillScore ?? 0) < 50 &&
      intelligence.candidateIntelligence.topCandidates.isNotEmpty) {
    recommendations.add(
      'Average skill score is low. Tighten job requirements or target courses with stronger skill evidence.',
    );
  }
  if (highestMatch != null && highestMatch.match.matchScore >= 75) {
    recommendations.add(
      '${highestMatch.candidateName} is a high-match candidate for ${highestMatch.jobTitle}. Review this profile first.',
    );
  }
  if (highestConversionJob != null && highestConversionJob.selectedCount > 0) {
    recommendations.add(
      '${highestConversionJob.jobTitle} is converting candidates. Use this job structure as a benchmark.',
    );
  }
  recommendations.add(
    'Average hiring time and hired-stage analytics require explicit hiring timestamps/statuses, so they are not estimated.',
  );
  recommendations.add(
    'Grand test ranking is not shown until grand test evidence is exposed to company intelligence.',
  );
  return recommendations.take(6).toList();
}

double _rate(int value, int total) {
  if (total <= 0) return 0;
  return (value / total * 100).clamp(0, 100).toDouble();
}

double _stageRatio(int value, int total) {
  if (total <= 0) return 0;
  return (value / total).clamp(0, 1).toDouble();
}

BoxDecoration _panelDecoration(BuildContext context, Color accent) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
    border: Border.all(color: accent.withValues(alpha: 0.18)),
    boxShadow: isDark ? AppTheme.darkShadowSm : AppTheme.lightShadowSm,
  );
}

Color _healthColor(String status) {
  return switch (status) {
    CompanyJobHealthStatus.excellent => AppColors.success,
    CompanyJobHealthStatus.healthy => AppColors.info,
    CompanyJobHealthStatus.needsAttention => AppColors.warning,
    CompanyJobHealthStatus.critical => AppColors.error,
    _ => AppColors.companyPrimary,
  };
}

double _stageProgress(int value, int total) {
  if (total <= 0) return 0;
  return (value / total).clamp(0, 1).toDouble();
}
