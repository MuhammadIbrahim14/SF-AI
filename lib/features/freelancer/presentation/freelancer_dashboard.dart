import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/courses/providers/certificate_provider.dart';
import '../../../features/courses/providers/resume_provider.dart';
import '../../../features/courses/providers/skill_score_provider.dart';
import '../../../models/application_model.dart';
import '../../../models/freelancer_model.dart';
import '../../../models/freelancer_service_review_model.dart';
import '../../../models/interview_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/freelancer_provider.dart';
import '../../../providers/freelancer_service_review_provider.dart';
import '../../../providers/freelancer_wallet_provider.dart';
import '../../../providers/interview_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/service_request_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/dashboard_section.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/profile_completion_card.dart';
import '../../../shared/widgets/quick_action_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/role_theme.dart';
import '../../../shared/widgets/dashboard_shell.dart';

class FreelancerDashboard extends ConsumerWidget {
  const FreelancerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final freelancerAsync = ref.watch(freelancerProvider);
    final userId = userAsync.value?.uid ?? '';
    final reviewSummary = userId.isEmpty
        ? ReviewSummary.empty
        : ref.watch(freelancerReviewSummaryProvider(userId));
    final serviceRequests =
        ref.watch(freelancerServiceRequestsProvider).value ?? const [];
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final interviewsAsync = ref.watch(myInterviewsProvider);
    final certificatesAsync = ref.watch(studentCertificatesProvider);
    final skillScoresAsync = ref.watch(studentSkillScoresProvider);
    final resumeAsync = ref.watch(smartResumeProvider);
    final wallet = ref.watch(myFreelancerWalletProvider).value;
    final profile = ref.watch(profileDataProvider).value;
    ref.watch(profileCompletionSyncProvider);

    final user = userAsync.value;
    final freelancer = freelancerAsync.value;
    final applications = applicationsAsync.value ?? const <ApplicationModel>[];
    final interviews = interviewsAsync.value ?? const <InterviewModel>[];
    final certificates = certificatesAsync.value ?? const [];
    final skillScores = skillScoresAsync.value ?? const [];
    final resume = resumeAsync.value;
    final completion = profile?.completion;
    final roleTheme = getRoleTheme(UserRole.freelancer);

    final activeApplications = applications
        .where((application) => _isActiveApplication(application))
        .length;
    final upcomingInterviews = interviews
        .where((interview) => _isUpcomingInterview(interview))
        .length;
    final activeCertificates = certificates
        .where((certificate) => certificate.isActive)
        .length;
    final averageSkillScore = skillScores.isEmpty
        ? 0.0
        : skillScores
                  .map((score) => score.score)
                  .fold<double>(0, (total, score) => total + score) /
              skillScores.length;
    final resumeReadiness = resume?.resumeScore ?? 0.0;
    final completedServiceRequests = serviceRequests
        .where((request) => request.status == 'completed')
        .length;
    final portfolioStrength = _portfolioStrength(freelancer);
    final insights = _freelancerInsights(
      freelancer: freelancer,
      activeApplications: activeApplications,
      upcomingInterviews: upcomingInterviews,
      portfolioStrength: portfolioStrength,
      averageSkillScore: averageSkillScore,
      activeCertificates: activeCertificates,
      resumeReadiness: resumeReadiness,
    );

    return RoleDashboardFrame(
      role: UserRole.freelancer,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(freelancerProvider);
          ref.invalidate(myApplicationsProvider);
          ref.invalidate(myInterviewsProvider);
          ref.invalidate(studentCertificatesProvider);
          ref.invalidate(studentSkillScoresProvider);
          ref.invalidate(smartResumeProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _FreelancerHero(
              name: user?.fullName ?? 'Freelancer',
              title: freelancer?.professionalTitle,
              category: freelancer?.category,
              photoUrl: user?.photoUrl,
              portfolioStrength: portfolioStrength,
              unreadCount: ref.watch(unreadNotificationCountProvider),
              onProfileTap: () =>
                  context.pushNamed(RouteNames.freelancerProfile),
              onEditProfileTap: () =>
                  context.pushNamed(RouteNames.freelancerEditProfile),
              onNotificationsTap: () =>
                  context.pushNamed(RouteNames.notificationsInbox),
            ),

            if (user?.freelancerUnlocked == true ||
                (user?.roles.any(
                      (role) => role.trim().toLowerCase() == 'student',
                    ) ??
                    false))
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: OutlinedButton.icon(
                  onPressed: ref.watch(roleNotifierProvider).isLoading
                      ? null
                      : () async {
                          final ok = await ref
                              .read(roleNotifierProvider.notifier)
                              .setPrimaryRoleOnly(UserRole.student);
                          if (!context.mounted) return;
                          if (ok) {
                            context.goNamed(RouteNames.studentDashboard);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref
                                          .read(roleNotifierProvider)
                                          .error
                                          ?.toString() ??
                                      'Unable to switch to Student mode.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.school_rounded),
                  label: const Text('Back to Student mode'),
                ),
              ),

            if (completion != null && !completion.isComplete)
              ProfileCompletionCard(
                completionPercentage: completion.profileCompletionPercentage,
                isProfileImageMissing: completion.missingFields.contains(
                  'Profile image',
                ),
                missingFields: completion.missingFields,
                onCompleteProfileTap: () =>
                    context.pushNamed(RouteNames.freelancerEditProfile),
                roleTheme: roleTheme,
              ),

            DashboardSection(
              title: 'Freelancer Workspace',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ResponsiveGrid(
                  minChildWidth: 230,
                  children: [
                    MetricCard(
                      title: 'Active Applications',
                      value: activeApplications.toString(),
                      icon: Icons.send_rounded,
                      color: AppColors.freelancerPrimary,
                    ),
                    MetricCard(
                      title: 'Interviews Scheduled',
                      value: upcomingInterviews.toString(),
                      icon: Icons.event_available_rounded,
                      color: AppColors.freelancerSecondary,
                    ),
                    MetricCard(
                      title: 'Portfolio Strength',
                      value: '$portfolioStrength%',
                      icon: Icons.workspaces_outline,
                      color: _scoreColor(portfolioStrength.toDouble()),
                    ),
                    MetricCard(
                      title: 'Skill Readiness',
                      value: averageSkillScore == 0
                          ? 'Pending'
                          : '${averageSkillScore.toStringAsFixed(0)}%',
                      icon: Icons.psychology_rounded,
                      color: _scoreColor(averageSkillScore),
                    ),
                    MetricCard(
                      title: 'Certificates',
                      value: activeCertificates.toString(),
                      icon: Icons.verified_rounded,
                      color: AppColors.success,
                    ),
                    MetricCard(
                      title: 'Resume Readiness',
                      value: resumeReadiness == 0
                          ? 'Not ready'
                          : '${resumeReadiness.toStringAsFixed(0)}%',
                      icon: Icons.description_rounded,
                      color: _scoreColor(resumeReadiness),
                    ),
                    MetricCard(
                      title: 'Reputation',
                      value: reviewSummary.hasReviews
                          ? reviewSummary.averageRating.toStringAsFixed(1)
                          : 'New',
                      trendValue:
                          '${reviewSummary.reviewCount} review${reviewSummary.reviewCount == 1 ? '' : 's'}',
                      icon: Icons.star_rounded,
                      color: AppColors.warning,
                    ),
                    MetricCard(
                      title: 'Completed Requests',
                      value: '$completedServiceRequests',
                      icon: Icons.verified_rounded,
                      color: AppColors.success,
                    ),
                    MetricCard(
                      title: 'Available Balance',
                      value: wallet == null
                          ? 'Sandbox'
                          : _money(wallet.availableBalance, wallet.currency),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.success,
                    ),
                    MetricCard(
                      title: 'Pending Earnings',
                      value: wallet == null
                          ? '0'
                          : _money(wallet.pendingBalance, wallet.currency),
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ),

            DashboardSection(
              title: 'Opportunity Center',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ResponsiveGrid(
                  minChildWidth: 240,
                  children: [
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.portfolio_studio',
                      button: true,
                      child: QuickActionCard(
                        title: 'Portfolio Studio',
                        icon: Icons.workspace_premium_rounded,
                        color: AppColors.freelancerPrimary,
                        onTap: () => context.pushNamed(
                          RouteNames.freelancerPortfolioStudio,
                        ),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.my_services',
                      button: true,
                      child: QuickActionCard(
                        title: 'My Services',
                        icon: Icons.design_services_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () =>
                            context.pushNamed(RouteNames.freelancerServices),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.service_requests',
                      button: true,
                      child: QuickActionCard(
                        title: 'Service Requests',
                        icon: Icons.handshake_rounded,
                        color: AppColors.freelancerPrimary,
                        onTap: () => context.pushNamed(
                          RouteNames.freelancerServiceRequests,
                        ),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.ai_work_assistant',
                      button: true,
                      child: QuickActionCard(
                        title: 'AI Work Assistant',
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.freelancerPrimary,
                        onTap: () => context
                            .pushNamed(RouteNames.freelancerAiAssistant),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.career_intel',
                      button: true,
                      child: QuickActionCard(
                        title: 'Career Intelligence',
                        icon: Icons.psychology_alt_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () =>
                            context.pushNamed(RouteNames.careerIntelligence),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.interview_lab',
                      button: true,
                      child: QuickActionCard(
                        title: 'AI Interview Lab',
                        icon: Icons.record_voice_over_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () =>
                            context.pushNamed(RouteNames.interviewLab),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.draft_proposal',
                      button: true,
                      child: QuickActionCard(
                        title: 'Draft Proposal',
                        icon: Icons.edit_note_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () => context.pushNamed(
                          RouteNames.freelancerAiAssistant,
                          queryParameters: {'task': 'proposal'},
                        ),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.delivery_helper',
                      button: true,
                      child: QuickActionCard(
                        title: 'Delivery Helper',
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.info,
                        onTap: () => context.pushNamed(
                          RouteNames.freelancerAiAssistant,
                          queryParameters: {'task': 'deliveryNote'},
                        ),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.orders',
                      button: true,
                      child: QuickActionCard(
                        title: 'Orders',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () => context
                            .pushNamed(RouteNames.freelancerServiceOrders),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.wallet',
                      button: true,
                      child: QuickActionCard(
                        title: 'Wallet / Earnings',
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.success,
                        onTap: () =>
                            context.pushNamed(RouteNames.freelancerWallet),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.payouts',
                      button: true,
                      child: QuickActionCard(
                        title: 'Payouts',
                        icon: Icons.outbound_rounded,
                        color: AppColors.info,
                        onTap: () =>
                            context.pushNamed(RouteNames.freelancerPayouts),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.invoices',
                      button: true,
                      child: QuickActionCard(
                        title: 'Invoices',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.warning,
                        onTap: () =>
                            context.pushNamed(RouteNames.freelancerInvoices),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.resolutions',
                      button: true,
                      child: QuickActionCard(
                        title: 'Resolution Center',
                        icon: Icons.support_agent_rounded,
                        color: AppColors.error,
                        onTap: () => context
                            .pushNamed(RouteNames.freelancerResolutions),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.browse_jobs',
                      button: true,
                      child: QuickActionCard(
                        title: 'Browse Jobs',
                        icon: Icons.search_rounded,
                        color: AppColors.freelancerPrimary,
                        onTap: () => context.pushNamed(RouteNames.jobList),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.my_applications',
                      button: true,
                      child: QuickActionCard(
                        title: 'My Applications',
                        icon: Icons.assignment_turned_in_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () =>
                            context.pushNamed(RouteNames.myApplications),
                      ),
                    ),
                    if ((applicationsAsync.value ?? const []).any(
                      (a) =>
                          a.isJoiningSoon ||
                          a.isActiveEmployee ||
                          a.isLeftEmployee,
                    ))
                      SieInteractive(
                        targetId: 'freelancer.dashboard.action.my_employment',
                        button: true,
                        child: QuickActionCard(
                          title: 'My Employment',
                          icon: Icons.badge_rounded,
                          color: AppColors.info,
                          onTap: () =>
                              context.pushNamed(RouteNames.myEmployment),
                        ),
                      ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.my_interviews',
                      button: true,
                      child: QuickActionCard(
                        title: 'My Interviews',
                        icon: Icons.event_note_rounded,
                        color: AppColors.info,
                        onTap: () =>
                            context.pushNamed(RouteNames.myInterviews),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.edit_profile',
                      button: true,
                      child: QuickActionCard(
                        title: 'Edit Profile',
                        icon: Icons.manage_accounts_rounded,
                        color: AppColors.freelancerPrimary,
                        onTap: () => context
                            .pushNamed(RouteNames.freelancerEditProfile),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.portfolio_links',
                      button: true,
                      child: QuickActionCard(
                        title: 'Portfolio & Links',
                        icon: Icons.link_rounded,
                        color: AppColors.freelancerSecondary,
                        onTap: () =>
                            context.pushNamed(RouteNames.profilePortfolio),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.profile',
                      button: true,
                      child: QuickActionCard(
                        title: 'Profile',
                        icon: Icons.person_outline_rounded,
                        color: AppColors.freelancerPrimary,
                        onTap: () =>
                            context.pushNamed(RouteNames.freelancerProfile),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.portfolio_builder',
                      button: true,
                      child: QuickActionCard(
                        title: 'Portfolio Builder',
                        icon: Icons.web_outlined,
                        color: Colors.indigo,
                        onTap: () =>
                            context.pushNamed(RouteNames.portfolioBuilder),
                      ),
                    ),
                    SieInteractive(
                      targetId: 'freelancer.dashboard.action.contact_support',
                      button: true,
                      child: QuickActionCard(
                        title: 'Contact Support',
                        icon: Icons.support_agent_outlined,
                        color: AppColors.accent,
                        onTap: () => context.pushNamed(RouteNames.contactUs),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            DashboardSection(
              title: 'Portfolio Strength',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _PortfolioStrengthCard(
                  freelancer: freelancer,
                  strength: portfolioStrength,
                  onEditProfileTap: () =>
                      context.pushNamed(RouteNames.freelancerEditProfile),
                ),
              ),
            ),

            DashboardSection(
              title: 'Freelancer Insights',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _InsightsPanel(insights: insights),
              ),
            ),

            DashboardSection(
              title: 'Next Best Actions',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ResponsiveGrid(
                  minChildWidth: 280,
                  children: [
                    if (applications.isEmpty)
                      DashboardEmptyState(
                        icon: Icons.explore_rounded,
                        title: 'No applications yet',
                        message:
                            'Browse matched opportunities and apply when your skills fit the job requirements.',
                        actionLabel: 'Browse Jobs',
                        onAction: () => context.pushNamed(RouteNames.jobList),
                      )
                    else
                      _StatusSummaryCard(
                        title: 'Applications in motion',
                        value: '$activeApplications active',
                        message:
                            'Keep your profile and portfolio updated while companies review your applications.',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.freelancerPrimary,
                      ),
                    if (upcomingInterviews == 0)
                      DashboardEmptyState(
                        icon: Icons.calendar_month_outlined,
                        title: 'No interviews scheduled',
                        message:
                            'Your interviews will appear here after a company moves your application forward.',
                        actionLabel: 'View Applications',
                        onAction: () =>
                            context.pushNamed(RouteNames.myApplications),
                      )
                    else
                      _StatusSummaryCard(
                        title: 'Interview readiness',
                        value: '$upcomingInterviews upcoming',
                        message:
                            'Review your applications and prepare portfolio proof before the interview.',
                        icon: Icons.event_available_rounded,
                        color: AppColors.freelancerSecondary,
                      ),
                    if (_portfolioLinksCount(freelancer) == 0)
                      DashboardEmptyState(
                        icon: Icons.link_off_rounded,
                        title: 'Portfolio links missing',
                        message:
                            'Add GitHub, Behance, website, or project links so companies can verify your work.',
                        actionLabel: 'Edit Profile',
                        onAction: () =>
                            context.pushNamed(RouteNames.freelancerEditProfile),
                      ),
                    if ((freelancer?.skills.length ?? 0) == 0)
                      DashboardEmptyState(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Skills missing',
                        message:
                            'Add your strongest skills to improve job match quality and profile clarity.',
                        actionLabel: 'Edit Profile',
                        onAction: () =>
                            context.pushNamed(RouteNames.freelancerEditProfile),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreelancerHero extends StatelessWidget {
  const _FreelancerHero({
    required this.name,
    required this.portfolioStrength,
    required this.onProfileTap,
    required this.onEditProfileTap,
    required this.onNotificationsTap,
    this.title,
    this.category,
    this.photoUrl,
    this.unreadCount = 0,
  });

  final String name;
  final String? title;
  final String? category;
  final String? photoUrl;
  final int portfolioStrength;
  final VoidCallback onProfileTap;
  final VoidCallback onEditProfileTap;
  final VoidCallback onNotificationsTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headline = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Freelance Professional';
    final subline = category?.trim().isNotEmpty == true
        ? category!.trim()
        : 'Build your proof, apply smarter, and track hiring momentum.';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.freelancerPrimary.withValues(alpha: 0.20),
            AppColors.freelancerSecondary.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.freelancerPrimary.withValues(alpha: 0.28),
        ),
        boxShadow: isDark ? AppTheme.darkShadowSm : AppTheme.lightShadowSm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 680;
          final identity = Row(
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.freelancerPrimary.withValues(
                    alpha: 0.18,
                  ),
                  backgroundImage: photoUrl?.isNotEmpty == true
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: photoUrl?.isNotEmpty == true
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.freelancerPrimary,
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.freelancerPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final strength = _HeroStrengthBadge(strength: portfolioStrength);
          final notifications = IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationsTap,
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          );
          final action = FilledButton.icon(
            onPressed: onEditProfileTap,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Improve Profile'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.freelancerPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    notifications,
                  ],
                ),
                const SizedBox(height: 20),
                strength,
                const SizedBox(height: 14),
                action,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 18),
              strength,
              const SizedBox(width: 8),
              notifications,
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _HeroStrengthBadge extends StatelessWidget {
  const _HeroStrengthBadge({required this.strength});

  final int strength;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(strength.toDouble());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            '$strength% portfolio',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioStrengthCard extends StatelessWidget {
  const _PortfolioStrengthCard({
    required this.freelancer,
    required this.strength,
    required this.onEditProfileTap,
  });

  final FreelancerModel? freelancer;
  final int strength;
  final VoidCallback onEditProfileTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _scoreColor(strength.toDouble());
    final checks = [
      _StrengthCheck(
        label: 'Professional title',
        complete: freelancer?.professionalTitle.trim().isNotEmpty == true,
      ),
      _StrengthCheck(
        label: 'Services listed',
        complete: (freelancer?.services.length ?? 0) >= 2,
      ),
      _StrengthCheck(
        label: 'Skills added',
        complete: (freelancer?.skills.length ?? 0) >= 4,
      ),
      _StrengthCheck(
        label: 'Hourly rate',
        complete: (freelancer?.hourlyRate ?? 0) > 0,
      ),
      _StrengthCheck(
        label: 'Experience',
        complete: (freelancer?.experienceYears ?? 0) > 0,
      ),
      _StrengthCheck(
        label: 'Portfolio/social links',
        complete: _portfolioLinksCount(freelancer) >= 2,
      ),
      _StrengthCheck(
        label: 'Bio/about',
        complete: freelancer?.bio.trim().isNotEmpty == true,
      ),
    ];

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile proof score',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$strength%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: strength / 100,
              minHeight: 10,
              color: color,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.08,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            minChildWidth: 210,
            children: checks
                .map(
                  (check) => _ChecklistTile(
                    label: check.label,
                    complete: check.complete,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEditProfileTap,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Update profile'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.freelancerPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.insights});

  final List<_FreelancerInsight> insights;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: [
          for (var index = 0; index < insights.length; index++) ...[
            _InsightTile(insight: insights[index]),
            if (index != insights.length - 1)
              Divider(
                height: 22,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.12),
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final _FreelancerInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: insight.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(insight.icon, color: insight.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                insight.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({
    required this.title,
    required this.value,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppColors.freelancerPrimary.withValues(alpha: 0.14),
        ),
        boxShadow: isDark ? AppTheme.darkShadowSm : AppTheme.lightShadowSm,
      ),
      child: child,
    );
  }
}

class _StrengthCheck {
  const _StrengthCheck({required this.label, required this.complete});

  final String label;
  final bool complete;
}

class _FreelancerInsight {
  const _FreelancerInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

List<_FreelancerInsight> _freelancerInsights({
  required FreelancerModel? freelancer,
  required int activeApplications,
  required int upcomingInterviews,
  required int portfolioStrength,
  required double averageSkillScore,
  required int activeCertificates,
  required double resumeReadiness,
}) {
  final insights = <_FreelancerInsight>[];

  if ((freelancer?.skills.length ?? 0) < 4) {
    insights.add(
      const _FreelancerInsight(
        title: 'Improve match quality',
        message:
            'Add more skills to help the matching engine understand which jobs are actually relevant for you.',
        icon: Icons.auto_awesome_rounded,
        color: AppColors.warning,
      ),
    );
  }
  if (_portfolioLinksCount(freelancer) < 2) {
    insights.add(
      const _FreelancerInsight(
        title: 'Complete your portfolio links',
        message:
            'Companies trust profiles faster when GitHub, Behance, website, or project proof is available.',
        icon: Icons.link_rounded,
        color: AppColors.freelancerPrimary,
      ),
    );
  }
  if ((freelancer?.hourlyRate ?? 0) <= 0) {
    insights.add(
      const _FreelancerInsight(
        title: 'Add hourly rate',
        message:
            'A visible rate improves profile clarity and helps companies understand your availability level.',
        icon: Icons.payments_outlined,
        color: AppColors.freelancerSecondary,
      ),
    );
  }
  if (activeApplications > 0) {
    insights.add(
      _FreelancerInsight(
        title: 'Applications are active',
        message:
            'You have $activeApplications active application${activeApplications == 1 ? '' : 's'} in review. Keep your profile fresh while companies evaluate.',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      ),
    );
  }
  if (upcomingInterviews > 0) {
    insights.add(
      _FreelancerInsight(
        title: 'Interview momentum',
        message:
            'You have $upcomingInterviews upcoming interview${upcomingInterviews == 1 ? '' : 's'}. Prepare proof of work and concise project stories.',
        icon: Icons.event_available_rounded,
        color: AppColors.info,
      ),
    );
  }
  if (averageSkillScore > 0 && averageSkillScore < 65) {
    insights.add(
      const _FreelancerInsight(
        title: 'Skill readiness needs work',
        message:
            'Your verified skill score is still building. Complete learning proof and assessments before applying to strict jobs.',
        icon: Icons.psychology_alt_rounded,
        color: AppColors.warning,
      ),
    );
  }
  if (activeCertificates > 0 ||
      resumeReadiness > 0 ||
      portfolioStrength >= 75) {
    insights.add(
      const _FreelancerInsight(
        title: 'Trust signals detected',
        message:
            'Your profile has useful hiring evidence. Apply to roles where your skills and proof match the requirements.',
        icon: Icons.verified_rounded,
        color: AppColors.success,
      ),
    );
  }

  if (insights.isEmpty) {
    insights.add(
      const _FreelancerInsight(
        title: 'Start with your profile proof',
        message:
            'Add services, skills, portfolio links, and rate first. Strong profiles unlock better job discovery.',
        icon: Icons.rocket_launch_rounded,
        color: AppColors.freelancerPrimary,
      ),
    );
  }

  return insights.take(5).toList();
}

bool _isActiveApplication(ApplicationModel application) {
  return switch (application.normalizedStatus) {
    'rejected' || 'withdrawn' || 'selected' => false,
    _ => true,
  };
}

bool _isUpcomingInterview(InterviewModel interview) {
  final status = interview.status.trim().toLowerCase();
  if (status != 'scheduled' && status != 'rescheduled') return false;
  return interview.scheduledAt.isAfter(
    DateTime.now().subtract(const Duration(hours: 2)),
  );
}

int _portfolioStrength(FreelancerModel? freelancer) {
  if (freelancer == null) return 0;
  var score = 0;
  if (freelancer.professionalTitle.trim().isNotEmpty) score += 10;
  if (freelancer.services.isNotEmpty) score += 8;
  if (freelancer.services.length >= 2) score += 7;
  if (freelancer.skills.isNotEmpty) score += 10;
  if (freelancer.skills.length >= 4) score += 10;
  if (freelancer.hourlyRate > 0) score += 10;
  if (freelancer.experienceYears > 0) score += 10;
  final links = _portfolioLinksCount(freelancer);
  if (links > 0) score += 10;
  if (links >= 2) score += 10;
  if (freelancer.bio.trim().isNotEmpty) score += 15;
  return score.clamp(0, 100);
}

int _portfolioLinksCount(FreelancerModel? freelancer) {
  if (freelancer == null) return 0;
  final links = <String>{
    ...freelancer.portfolioLinks,
    freelancer.portfolio,
    freelancer.linkedin,
    freelancer.github,
    freelancer.behance,
    freelancer.dribbble,
    freelancer.website,
  };
  links.removeWhere((link) => link.trim().isEmpty);
  return links.length;
}

Color _scoreColor(double score) {
  if (score >= 75) return AppColors.success;
  if (score >= 45) return AppColors.warning;
  return AppColors.freelancerPrimary;
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
