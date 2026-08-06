import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../courses/presentation/course_premium_widgets.dart';
import '../../payment/providers/payment_providers.dart';
import '../../payment/services/teacher_subscription_service.dart';
import '../../../shared/widgets/dashboard_section.dart';
import '../../../shared/widgets/dashboard_shell.dart';
import '../../../core/theme/role_theme.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/profile_completion_card.dart';
import '../../../shared/widgets/quick_action_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../data/models/teacher_dashboard_stats_model.dart';
import '../data/models/teacher_student_progress_model.dart';
import '../providers/teacher_ai_intelligence_provider.dart';
import '../providers/teacher_assessment_analytics_provider.dart';
import '../providers/teacher_dashboard_provider.dart';
import '../providers/teacher_grand_certificate_analytics_provider.dart';
import '../providers/teacher_productivity_hub_provider.dart';
import '../providers/teacher_student_progress_provider.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(teacherDashboardStatsProvider);
    final assessmentAnalyticsAsync = ref.watch(
      teacherAssessmentAnalyticsProvider,
    );
    final grandCertificateAnalyticsAsync = ref.watch(
      teacherGrandCertificateAnalyticsProvider,
    );
    final aiIntelligenceAsync = ref.watch(teacherAiIntelligenceProvider);
    final productivityHubAsync = ref.watch(teacherProductivityHubProvider);
    final studentProgressAsync = ref.watch(teacherStudentProgressProvider);
    final profile = ref.watch(profileDataProvider).value;
    ref.watch(profileCompletionSyncProvider);

    final user = userAsync.value;
    final completion = profile?.completion;
    final roleTheme = getRoleTheme(UserRole.teacher);
    final teacherAccessAsync = user?.uid != null
        ? ref.watch(teacherSubscriptionAccessProvider(user!.uid))
        : null;

    return RoleDashboardFrame(
      role: UserRole.teacher,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(teacherDashboardStatsProvider);
          ref.invalidate(teacherAssessmentAnalyticsProvider);
          ref.invalidate(teacherGrandCertificateAnalyticsProvider);
          ref.invalidate(teacherAiIntelligenceProvider);
          ref.invalidate(teacherProductivityHubProvider);
          ref.invalidate(teacherStudentProgressProvider);
          final uid = user?.uid;
          if (uid != null) {
            ref.invalidate(teacherSubscriptionAccessProvider(uid));
          }
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (completion != null && !completion.isComplete)
              ProfileCompletionCard(
                completionPercentage: completion.profileCompletionPercentage,
                isProfileImageMissing: completion.missingFields.contains(
                  'Profile image',
                ),
                missingFields: completion.missingFields,
                onCompleteProfileTap: () =>
                    context.pushNamed(RouteNames.teacherEditProfile),
                roleTheme: roleTheme,
              ),
            statsAsync.when(
              loading: () => const _DashboardLoading(),
              error: (error, _) => DashboardSection(
                title: 'Command Center',
                child: DashboardEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Dashboard metrics unavailable',
                  message:
                      'We could not load teaching activity right now. Pull down to retry.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(teacherDashboardStatsProvider),
                ),
              ),
              data: (stats) => _TeacherCommandCenter(
                stats: stats,
                assessmentAnalyticsAsync: assessmentAnalyticsAsync,
                grandCertificateAnalyticsAsync: grandCertificateAnalyticsAsync,
                aiIntelligenceAsync: aiIntelligenceAsync,
                productivityHubAsync: productivityHubAsync,
                studentProgress:
                    studentProgressAsync.value ??
                    const <TeacherStudentProgressModel>[],
                teacherAccessAsync: teacherAccessAsync,
                roleTheme: roleTheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherCommandCenter extends StatelessWidget {
  const _TeacherCommandCenter({
    required this.stats,
    required this.assessmentAnalyticsAsync,
    required this.grandCertificateAnalyticsAsync,
    required this.aiIntelligenceAsync,
    required this.productivityHubAsync,
    required this.studentProgress,
    required this.teacherAccessAsync,
    required this.roleTheme,
  });

  final TeacherDashboardStatsModel stats;
  final AsyncValue<TeacherAssessmentAnalytics> assessmentAnalyticsAsync;
  final AsyncValue<TeacherGrandCertificateAnalytics>
  grandCertificateAnalyticsAsync;
  final AsyncValue<TeacherAiIntelligence> aiIntelligenceAsync;
  final AsyncValue<TeacherProductivityHub> productivityHubAsync;
  final List<TeacherStudentProgressModel> studentProgress;
  final AsyncValue<TeacherSubscriptionAccess>? teacherAccessAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final atRiskStudents = studentProgress
        .where((item) => item.isAtRisk)
        .length;
    final needsAttentionStudents = studentProgress
        .where((item) => item.needsAttention)
        .length;
    final allowAnalytics =
        teacherAccessAsync?.value?.allowAnalytics ?? false;

    return Column(
      children: [
        DashboardSection(
          title: 'Teaching Impact',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ImpactCard(stats: stats, roleTheme: roleTheme),
          ),
        ),
        DashboardSection(
          title: 'Command Center',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _MetricsGrid(
              metrics: [
                _MetricSpec(
                  title: 'Total Courses',
                  value: stats.totalCourses.toString(),
                  icon: Icons.video_library_rounded,
                  color: roleTheme.primary,
                ),
                _MetricSpec(
                  title: 'Published',
                  value: stats.publishedCourses.toString(),
                  icon: Icons.public_rounded,
                  color: AppColors.success,
                ),
                _MetricSpec(
                  title: 'Drafts',
                  value: stats.draftCourses.toString(),
                  icon: Icons.edit_note_rounded,
                  color: AppColors.warning,
                ),
                _MetricSpec(
                  title: 'Students',
                  value: stats.totalEnrolledStudents.toString(),
                  icon: Icons.groups_rounded,
                  color: roleTheme.secondary,
                ),
                _MetricSpec(
                  title: 'Active Students',
                  value: stats.activeStudents.toString(),
                  icon: Icons.person_pin_circle_rounded,
                  color: AppColors.accent,
                ),
                _MetricSpec(
                  title: 'Assignments',
                  value: stats.totalAssignments.toString(),
                  icon: Icons.assignment_rounded,
                  color: roleTheme.primary,
                ),
                _MetricSpec(
                  title: 'Project Reviews',
                  value: stats.pendingProjectReviews.toString(),
                  icon: Icons.fact_check_rounded,
                  color: AppColors.warning,
                ),
                _MetricSpec(
                  title: 'Grand Tests',
                  value: stats.grandTestsCreated.toString(),
                  icon: Icons.workspace_premium_rounded,
                  color: roleTheme.secondary,
                ),
                _MetricSpec(
                  title: 'Certificates',
                  value: stats.certificatesIssued.toString(),
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                ),
                _MetricSpec(
                  title: 'Avg Test Score',
                  value: '${stats.averageGrandTestScore.toStringAsFixed(0)}%',
                  icon: Icons.analytics_rounded,
                  color: AppColors.accent,
                ),
                _MetricSpec(
                  title: 'At Risk',
                  value: atRiskStudents.toString(),
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.error,
                ),
                _MetricSpec(
                  title: 'Needs Attention',
                  value: needsAttentionStudents.toString(),
                  icon: Icons.volunteer_activism_rounded,
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ),
        DashboardSection(
          title: "Today's Workspace",
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _TodaysWorkspacePanel(
              productivityAsync: productivityHubAsync,
              roleTheme: roleTheme,
            ),
          ),
        ),
        DashboardSection(
          title: 'Quick Actions',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _QuickActionGrid(stats: stats, roleTheme: roleTheme),
          ),
        ),
        DashboardSection(
          title: 'AI Student Intelligence',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: allowAnalytics
                ? _AiStudentIntelligencePanel(
                    intelligenceAsync: aiIntelligenceAsync,
                    roleTheme: roleTheme,
                  )
                : _AnalyticsLockedCard(roleTheme: roleTheme),
          ),
        ),
        DashboardSection(
          title: 'Assessment Analytics',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: allowAnalytics
                ? _AssessmentAnalyticsPanel(
                    analyticsAsync: assessmentAnalyticsAsync,
                    roleTheme: roleTheme,
                  )
                : _AnalyticsLockedCard(roleTheme: roleTheme),
          ),
        ),
        DashboardSection(
          title: 'Grand Test & Certificates',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: allowAnalytics
                ? _GrandCertificateAnalyticsPanel(
                    analyticsAsync: grandCertificateAnalyticsAsync,
                    roleTheme: roleTheme,
                  )
                : _AnalyticsLockedCard(roleTheme: roleTheme),
          ),
        ),
        DashboardSection(
          title: 'Course Snapshot',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ProductivityCourseSnapshotPanel(
              productivityAsync: productivityHubAsync,
              roleTheme: roleTheme,
            ),
          ),
        ),
        DashboardSection(
          title: 'Teaching Insights',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _TeachingInsightsPanel(
              productivityAsync: productivityHubAsync,
              roleTheme: roleTheme,
            ),
          ),
        ),
        DashboardSection(
          title: 'Pending Work',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _PendingWorkList(stats: stats, roleTheme: roleTheme),
          ),
        ),
        DashboardSection(
          title: 'Recent Activity',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ActivityFeed(stats: stats, roleTheme: roleTheme),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsLockedCard extends StatelessWidget {
  const _AnalyticsLockedCard({required this.roleTheme});

  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      highlightColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Text(
                'Analytics locked',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to a Pro teaching plan to unlock assessment analytics, '
            'grand test insights, and AI student intelligence.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => context.pushNamed(RouteNames.teacherPlans),
            icon: const Icon(Icons.workspace_premium_rounded),
            label: const Text('Open Plan Management'),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_MetricSpec> metrics;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 5,
      children: [
        for (final item in metrics)
          MetricCard(
            title: item.title,
            value: item.value,
            icon: item.icon,
            color: item.color,
          ),
      ],
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.stats, required this.roleTheme});

  final TeacherDashboardStatsModel stats;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final impact = stats.teachingImpactScore / 100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: roleTheme.primary.withValues(alpha: isDark ? 0.24 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: roleTheme.primary.withValues(
                  alpha: isDark ? 0.08 : 0.06,
                ),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final score = _ImpactScoreRing(
                score: stats.teachingImpactScore,
                progress: impact.clamp(0, 1).toDouble(),
                roleTheme: roleTheme,
              );
              final details = _ImpactDetails(
                stats: stats,
                roleTheme: roleTheme,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [score, const SizedBox(height: 24), details],
                );
              }
              return Row(
                children: [
                  score,
                  const SizedBox(width: 32),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImpactScoreRing extends StatelessWidget {
  const _ImpactScoreRing({
    required this.score,
    required this.progress,
    required this.roleTheme,
  });

  final int score;
  final double progress;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: roleTheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
              boxShadow: [
                BoxShadow(
                  color: roleTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 156,
            height: 156,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  color: roleTheme.primary,
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: roleTheme.primary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Impact',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactDetails extends StatelessWidget {
  const _ImpactDetails({required this.stats, required this.roleTheme});

  final TeacherDashboardStatsModel stats;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: roleTheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Teaching Impact Score',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Calculated from published courses, students reached, assignments, certificates, and grand tests.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ImpactChip(
              label: '${stats.totalEnrolledStudents} students reached',
              icon: Icons.groups_rounded,
              roleTheme: roleTheme,
            ),
            _ImpactChip(
              label: '${stats.certificatesIssued} certificates',
              icon: Icons.workspace_premium_rounded,
              roleTheme: roleTheme,
            ),
            _ImpactChip(
              label:
                  '${stats.averageCourseCompletion.toStringAsFixed(0)}% avg completion',
              icon: Icons.trending_up_rounded,
              roleTheme: roleTheme,
            ),
          ],
        ),
      ],
    );
  }
}

class _ImpactChip extends StatelessWidget {
  const _ImpactChip({
    required this.label,
    required this.icon,
    required this.roleTheme,
  });

  final String label;
  final IconData icon;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: roleTheme.primary.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: roleTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: roleTheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.white : roleTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.stats, required this.roleTheme});

  final TeacherDashboardStatsModel stats;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionSpec(
        title: 'AI Course Builder',
        icon: Icons.auto_awesome_rounded,
        color: roleTheme.primary,
        onTap: () => context.pushNamed(RouteNames.teacherAiCourseBuilder),
      ),
      _ActionSpec(
        title: 'Career Intelligence',
        icon: Icons.psychology_alt_rounded,
        color: roleTheme.secondary,
        onTap: () => context.pushNamed(RouteNames.careerIntelligence),
      ),
      _ActionSpec(
        title: 'Create Course',
        icon: Icons.add_circle_outline_rounded,
        color: roleTheme.primary,
        onTap: () => context.pushNamed(RouteNames.teacherCourseCreate),
      ),
      _ActionSpec(
        title: 'My Courses',
        icon: Icons.video_library_rounded,
        color: AppColors.accent,
        onTap: () => context.pushNamed(RouteNames.teacherCourses),
      ),
      _ActionSpec(
        title: 'Add Lesson',
        icon: Icons.playlist_add_rounded,
        color: roleTheme.secondary,
        onTap: () => _withCourse(context, stats, (courseId) {
          context.pushNamed(
            RouteNames.teacherLessonCreate,
            pathParameters: {'courseId': courseId},
          );
        }),
      ),
      _ActionSpec(
        title: 'Create Assignment',
        icon: Icons.add_task_rounded,
        color: roleTheme.primary,
        onTap: () => _withCourse(context, stats, (courseId) {
          context.pushNamed(
            RouteNames.teacherAssignments,
            pathParameters: {'courseId': courseId},
          );
        }),
      ),
      _ActionSpec(
        title: 'Review Projects',
        icon: Icons.fact_check_rounded,
        color: AppColors.warning,
        onTap: () => _reviewProjects(context, stats),
      ),
      _ActionSpec(
        title: 'Create Grand Test',
        icon: Icons.workspace_premium_rounded,
        color: roleTheme.secondary,
        onTap: () => _withCourse(context, stats, (courseId) {
          context.pushNamed(
            RouteNames.teacherGrandTestCreate,
            pathParameters: {'courseId': courseId},
          );
        }),
      ),
      _ActionSpec(
        title: 'Manage Certificates',
        icon: Icons.verified_rounded,
        color: AppColors.success,
        onTap: () => _withCourse(context, stats, (courseId) {
          context.pushNamed(
            RouteNames.teacherCertificates,
            pathParameters: {'courseId': courseId},
          );
        }),
      ),
      _ActionSpec(
        title: 'Student Progress',
        icon: Icons.insights_rounded,
        color: AppColors.accent,
        onTap: () => context.push(RoutePaths.teacherStudentProgress),
      ),
      _ActionSpec(
        title: 'Batches',
        icon: Icons.groups_2_rounded,
        color: roleTheme.primary,
        onTap: () => context.pushNamed(RouteNames.teacherBatches),
      ),
      _ActionSpec(
        title: 'Plan Management',
        icon: Icons.workspace_premium_outlined,
        color: roleTheme.secondary,
        onTap: () => context.pushNamed(RouteNames.teacherPlans),
      ),
      _ActionSpec(
        title: 'Teacher Wallet',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        onTap: () => context.pushNamed(RouteNames.teacherWallet),
      ),
      _ActionSpec(
        title: 'Profile',
        icon: Icons.person_outline_rounded,
        color: Colors.purple,
        onTap: () => context.pushNamed(RouteNames.teacherProfile),
      ),
      _ActionSpec(
        title: 'Portfolio Builder',
        icon: Icons.web_outlined,
        color: Colors.indigo,
        onTap: () => context.pushNamed(RouteNames.portfolioBuilder),
      ),
      _ActionSpec(
        title: 'Contact Support',
        icon: Icons.support_agent_outlined,
        color: AppColors.accent,
        onTap: () => context.pushNamed(RouteNames.contactUs),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => ResponsiveGrid(
        mobileColumns: 1,
        tabletColumns: 2,
        desktopColumns: 4,
        wideColumns: 4,
        minChildWidth: 240,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final action in actions)
            SieInteractive(
              targetId:
                  'teacher.dashboard.action.${action.title.toLowerCase().replaceAll(' ', '_')}',
              button: true,
              child: QuickActionCard(
                title: action.title,
                icon: action.icon,
                color: action.color,
                onTap: action.onTap,
              ),
            ),
        ],
      ),
    );
  }

  void _reviewProjects(BuildContext context, TeacherDashboardStatsModel stats) {
    final pending = stats.firstPendingProject;
    if (pending != null) {
      context.pushNamed(
        RouteNames.teacherProjectSubmissions,
        pathParameters: {
          'courseId': pending.courseId,
          'assignmentId': pending.assignmentId,
        },
      );
      return;
    }
    _withCourse(context, stats, (courseId) {
      context.pushNamed(
        RouteNames.teacherProjectAssignments,
        pathParameters: {'courseId': courseId},
      );
    });
  }
}

class _TodaysWorkspacePanel extends StatelessWidget {
  const _TodaysWorkspacePanel({
    required this.productivityAsync,
    required this.roleTheme,
  });

  final AsyncValue<TeacherProductivityHub> productivityAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return productivityAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const DashboardEmptyState(
        icon: Icons.workspaces_outline,
        title: 'Workspace unavailable',
        message: 'Today’s workspace could not be loaded. Pull down to retry.',
      ),
      data: (hub) {
        if (!hub.hasActionableWork) {
          return const DashboardEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Workspace is clear',
            message:
                'No urgent reviews, certificate tasks, or student follow-ups are pending right now.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProductivityWorkloadGrid(hub: hub, roleTheme: roleTheme),
            const SizedBox(height: 16),
            _WorkspaceQueueCard(hub: hub, roleTheme: roleTheme),
          ],
        );
      },
    );
  }
}

class _ProductivityWorkloadGrid extends StatelessWidget {
  const _ProductivityWorkloadGrid({required this.hub, required this.roleTheme});

  final TeacherProductivityHub hub;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final cards = hub.workloadCards.take(4).toList();
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      children: [
        for (final card in cards)
          MetricCard(
            title: card.title,
            value: card.count.toString(),
            icon: _iconFor(card.iconName),
            color: _priorityColor(card.priority, roleTheme),
          ),
      ],
    );
  }
}

class _WorkspaceQueueCard extends StatelessWidget {
  const _WorkspaceQueueCard({required this.hub, required this.roleTheme});

  final TeacherProductivityHub hub;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.view_timeline_rounded,
            color: roleTheme.primary,
            title: "Today's Workspace",
            subtitle:
                'Your highest priority reviews, student feedback, and certification work.',
          ),
          const SizedBox(height: 18),
          if (hub.workspaceItems.isEmpty)
            Text(
              'No workspace items need attention right now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...hub.workspaceItems.map(
              (item) => _WorkspaceItemRow(item: item, roleTheme: roleTheme),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceItemRow extends StatelessWidget {
  const _WorkspaceItemRow({required this.item, required this.roleTheme});

  final TeacherWorkspaceItem item;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(item.priority, roleTheme);
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openWorkspaceItem(context, item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.22,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Row(
          children: [
            _IconBubble(icon: _iconFor(item.iconName), color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MiniStatusPill(label: item.count.toString(), color: color),
          ],
        ),
      ),
    );
  }
}

class _ProductivityCourseSnapshotPanel extends StatelessWidget {
  const _ProductivityCourseSnapshotPanel({
    required this.productivityAsync,
    required this.roleTheme,
  });

  final AsyncValue<TeacherProductivityHub> productivityAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return productivityAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const DashboardEmptyState(
        icon: Icons.video_library_outlined,
        title: 'Course snapshot unavailable',
        message: 'Course productivity data could not be loaded right now.',
      ),
      data: (hub) {
        if (hub.courseSnapshots.isEmpty) {
          return const DashboardEmptyState(
            icon: Icons.video_library_outlined,
            title: 'No course snapshot yet',
            message:
                'Course health appears once students enroll and interact with lessons or assessments.',
          );
        }
        return ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 1,
          desktopColumns: 2,
          wideColumns: 2,
          minChildWidth: 360,
          children: [
            for (final course in hub.courseSnapshots)
              _ProductivityCourseSnapshotCard(
                course: course,
                roleTheme: roleTheme,
              ),
          ],
        );
      },
    );
  }
}

class _ProductivityCourseSnapshotCard extends StatelessWidget {
  const _ProductivityCourseSnapshotCard({
    required this.course,
    required this.roleTheme,
  });

  final TeacherCourseHealth course;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (course.healthLabel) {
      TeacherCourseHealthLabel.excellent => AppColors.success,
      TeacherCourseHealthLabel.healthy => AppColors.accent,
      TeacherCourseHealthLabel.needsAttention => AppColors.warning,
      _ => AppColors.error,
    };
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: Icons.video_library_rounded, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course.activeLearners}/${course.studentCount} active learners',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniStatusPill(
                label: TeacherCourseHealthLabel.label(course.healthLabel),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (course.healthScore / 100).clamp(0, 1).toDouble(),
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyMetric(
                label: 'Completion',
                value: '${course.completionRate.toStringAsFixed(0)}%',
              ),
              _TinyMetric(
                label: 'Assignment',
                value: '${course.assignmentAverage.toStringAsFixed(0)}%',
              ),
              _TinyMetric(
                label: 'Project',
                value: '${course.projectCompletion.toStringAsFixed(0)}%',
              ),
              _TinyMetric(
                label: 'Grand',
                value: '${course.grandTestPassRate.toStringAsFixed(0)}%',
              ),
              _TinyMetric(
                label: 'Cert',
                value: '${course.certificateCompletion.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeachingInsightsPanel extends StatelessWidget {
  const _TeachingInsightsPanel({
    required this.productivityAsync,
    required this.roleTheme,
  });

  final AsyncValue<TeacherProductivityHub> productivityAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return productivityAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const DashboardEmptyState(
        icon: Icons.tips_and_updates_outlined,
        title: 'Teaching insights unavailable',
        message: 'Rule-based teaching insights could not be loaded right now.',
      ),
      data: (hub) {
        return _AnalyticsGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnalyticsCardHeader(
                icon: Icons.tips_and_updates_rounded,
                color: roleTheme.secondary,
                title: 'Teaching Insights',
                subtitle:
                    'Rule-based productivity guidance from your existing LMS data.',
              ),
              const SizedBox(height: 18),
              for (final insight in hub.teachingInsights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_circle_right_rounded,
                        size: 18,
                        color: roleTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AiStudentIntelligencePanel extends StatelessWidget {
  const _AiStudentIntelligencePanel({
    required this.intelligenceAsync,
    required this.roleTheme,
  });

  final AsyncValue<TeacherAiIntelligence> intelligenceAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return intelligenceAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const DashboardEmptyState(
        icon: Icons.psychology_alt_outlined,
        title: 'Student intelligence unavailable',
        message:
            'The intelligence layer could not be loaded right now. Pull down to retry.',
      ),
      data: (intelligence) {
        final hasData =
            intelligence.topPerformers.isNotEmpty ||
            intelligence.atRiskStudents.isNotEmpty ||
            intelligence.needsAttentionStudents.isNotEmpty ||
            intelligence.courseHealth.isNotEmpty ||
            intelligence.totalWorkload > 0;
        if (!hasData) {
          return const DashboardEmptyState(
            icon: Icons.psychology_alt_outlined,
            title: 'No intelligence signals yet',
            message:
                'Student insights appear after learners enroll, submit work, and complete assessments.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AiWorkloadSummary(
              intelligence: intelligence,
              roleTheme: roleTheme,
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: 1,
              desktopColumns: 2,
              wideColumns: 2,
              minChildWidth: 360,
              children: [
                _StudentIntelligenceListCard(
                  title: 'Top Performers',
                  subtitle:
                      'Ranked from score, progress, assignments, and certificates.',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.success,
                  students: intelligence.topPerformers,
                  emptyMessage: 'No top performer pattern yet.',
                  isRiskList: false,
                ),
                _StudentIntelligenceListCard(
                  title: 'At-Risk Students',
                  subtitle: 'Only students with real risk signals are shown.',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.error,
                  students: intelligence.atRiskStudents,
                  emptyMessage: 'No at-risk students detected.',
                  isRiskList: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: 1,
              desktopColumns: 2,
              wideColumns: 2,
              minChildWidth: 360,
              children: [
                _TeacherInboxCard(
                  intelligence: intelligence,
                  roleTheme: roleTheme,
                ),
                _CourseHealthCard(
                  intelligence: intelligence,
                  roleTheme: roleTheme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AiRecommendationStrip(
              recommendations: intelligence.recommendations,
              roleTheme: roleTheme,
            ),
          ],
        );
      },
    );
  }
}

class _AiWorkloadSummary extends StatelessWidget {
  const _AiWorkloadSummary({
    required this.intelligence,
    required this.roleTheme,
  });

  final TeacherAiIntelligence intelligence;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      children: [
        MetricCard(
          title: 'Today Workload',
          value: intelligence.totalWorkload.toString(),
          icon: Icons.dynamic_feed_rounded,
          color: roleTheme.primary,
        ),
        MetricCard(
          title: 'Project Reviews',
          value: intelligence.pendingProjectReviews.toString(),
          icon: Icons.rate_review_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Certificates Pending',
          value: intelligence.pendingCertificates.toString(),
          icon: Icons.card_membership_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Grand Test Signals',
          value: intelligence.pendingGrandTestSignals.toString(),
          icon: Icons.workspace_premium_rounded,
          color: roleTheme.secondary,
        ),
      ],
    );
  }
}

class _StudentIntelligenceListCard extends StatelessWidget {
  const _StudentIntelligenceListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.students,
    required this.emptyMessage,
    required this.isRiskList,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<TeacherStudentIntelligence> students;
  final String emptyMessage;
  final bool isRiskList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: icon,
            color: color,
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 18),
          if (students.isEmpty)
            Text(
              emptyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...students
                .take(4)
                .map(
                  (student) => _StudentIntelligenceRow(
                    student: student,
                    color: color,
                    isRiskList: isRiskList,
                  ),
                ),
        ],
      ),
    );
  }
}

class _StudentIntelligenceRow extends StatelessWidget {
  const _StudentIntelligenceRow({
    required this.student,
    required this.color,
    required this.isRiskList,
  });

  final TeacherStudentIntelligence student;
  final Color color;
  final bool isRiskList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = student.studentName.trim().isEmpty
        ? 'S'
        : student.studentName.trim()[0].toUpperCase();
    final subtitle = isRiskList
        ? (student.riskReasons.isEmpty
              ? student.courseLabel
              : student.riskReasons.first)
        : '${student.courseLabel} • ${student.strongestArea}';

    return InkWell(
      onTap: () => context.pushNamed(
        RouteNames.teacherStudentProgressDetail,
        pathParameters: {'studentId': student.studentId},
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.22,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Text(
                initials,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniStatusPill(
                  label: isRiskList
                      ? student.priority
                      : '${student.overallScore.toStringAsFixed(0)}%',
                  color: color,
                ),
                if (student.certificateCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${student.certificateCount} certs',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherInboxCard extends StatelessWidget {
  const _TeacherInboxCard({
    required this.intelligence,
    required this.roleTheme,
  });

  final TeacherAiIntelligence intelligence;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.inbox_rounded,
            color: roleTheme.primary,
            title: 'Teacher Inbox',
            subtitle: 'Work items generated from real LMS activity.',
          ),
          const SizedBox(height: 18),
          if (intelligence.inboxItems.isEmpty)
            Text(
              'No urgent work items right now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...intelligence.inboxItems.map((item) => _InboxRow(item: item)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push(RoutePaths.teacherStudentProgress),
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Open Student Progress'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item});

  final TeacherInboxItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.priority) {
      TeacherInsightPriority.high => AppColors.error,
      TeacherInsightPriority.medium => AppColors.warning,
      _ => AppColors.success,
    };
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(item.iconName), color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniStatusPill(
            label: TeacherInsightPriority.label(item.priority),
            color: color,
          ),
        ],
      ),
    );
  }
}

class _CourseHealthCard extends StatelessWidget {
  const _CourseHealthCard({
    required this.intelligence,
    required this.roleTheme,
  });

  final TeacherAiIntelligence intelligence;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.monitor_heart_rounded,
            color: roleTheme.secondary,
            title: 'Course Health',
            subtitle:
                'Completion, assessment, projects, Grand Tests, and certificates.',
          ),
          const SizedBox(height: 18),
          if (intelligence.courseHealth.isEmpty)
            Text(
              'Course health appears after students enroll.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...intelligence.courseHealth
                .take(4)
                .map((course) => _CourseHealthRow(course: course)),
        ],
      ),
    );
  }
}

class _CourseHealthRow extends StatelessWidget {
  const _CourseHealthRow({required this.course});

  final TeacherCourseHealth course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (course.healthLabel) {
      TeacherCourseHealthLabel.excellent => AppColors.success,
      TeacherCourseHealthLabel.healthy => AppColors.accent,
      TeacherCourseHealthLabel.needsAttention => AppColors.warning,
      _ => AppColors.error,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.courseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniStatusPill(
                label: TeacherCourseHealthLabel.label(course.healthLabel),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (course.healthScore / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyMetric(label: 'Students', value: '${course.studentCount}'),
              _TinyMetric(label: 'Active', value: '${course.activeLearners}'),
              _TinyMetric(
                label: 'Progress',
                value: '${course.completionRate.toStringAsFixed(0)}%',
              ),
              _TinyMetric(
                label: 'Grand',
                value: '${course.grandTestPassRate.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiRecommendationStrip extends StatelessWidget {
  const _AiRecommendationStrip({
    required this.recommendations,
    required this.roleTheme,
  });

  final List<String> recommendations;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.auto_awesome_rounded,
            color: roleTheme.primary,
            title: 'AI Teaching Recommendations',
            subtitle:
                'Rule-based guidance generated from your real classroom data.',
          ),
          const SizedBox(height: 18),
          for (final recommendation in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_circle_right_rounded,
                    size: 18,
                    color: roleTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AssessmentAnalyticsPanel extends StatelessWidget {
  const _AssessmentAnalyticsPanel({
    required this.analyticsAsync,
    required this.roleTheme,
  });

  final AsyncValue<TeacherAssessmentAnalytics> analyticsAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return analyticsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => DashboardEmptyState(
        icon: Icons.analytics_outlined,
        title: 'Assessment analytics unavailable',
        message:
            'Assignment and project insights could not be loaded right now. Pull down to retry.',
      ),
      data: (analytics) {
        if (!analytics.hasAnyData) {
          return const DashboardEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No assessment data yet',
            message:
                'Create assignments and review submissions to unlock teacher analytics.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AssessmentOverviewGrid(analytics: analytics, roleTheme: roleTheme),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: 1,
              desktopColumns: 2,
              wideColumns: 2,
              minChildWidth: 360,
              children: [
                _AssessmentBreakdownCard(
                  title: 'Assignment Performance',
                  subtitle: 'MCQ attempts, scores, pass rate, and gaps.',
                  icon: Icons.quiz_rounded,
                  color: roleTheme.primary,
                  items: analytics.assignmentBreakdowns,
                  emptyMessage: 'No MCQ attempts have been submitted yet.',
                  actionLabel: 'Open Results',
                  onAction:
                      analytics.firstAssignmentCourseId == null ||
                          analytics.firstAssignmentId == null
                      ? null
                      : () => context.pushNamed(
                          RouteNames.teacherAssignmentResults,
                          pathParameters: {
                            'courseId': analytics.firstAssignmentCourseId!,
                            'assignmentId': analytics.firstAssignmentId!,
                          },
                        ),
                ),
                _AssessmentBreakdownCard(
                  title: 'Project Review Analytics',
                  subtitle: 'Submissions, grading progress, and review load.',
                  icon: Icons.folder_special_rounded,
                  color: AppColors.warning,
                  items: analytics.projectBreakdowns,
                  emptyMessage: 'No project submissions have arrived yet.',
                  actionLabel: 'Review Queue',
                  onAction:
                      analytics.firstProjectCourseId == null ||
                          analytics.firstProjectId == null
                      ? null
                      : () => context.pushNamed(
                          RouteNames.teacherProjectSubmissions,
                          pathParameters: {
                            'courseId': analytics.firstProjectCourseId!,
                            'assignmentId': analytics.firstProjectId!,
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: 1,
              desktopColumns: 2,
              wideColumns: 2,
              minChildWidth: 360,
              children: [
                _StudentSignalCard(analytics: analytics, roleTheme: roleTheme),
                _RecommendationCard(
                  recommendations: analytics.recommendations,
                  roleTheme: roleTheme,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AssessmentOverviewGrid extends StatelessWidget {
  const _AssessmentOverviewGrid({
    required this.analytics,
    required this.roleTheme,
  });

  final TeacherAssessmentAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      children: [
        MetricCard(
          title: 'Active MCQs',
          value: analytics.activeAssignments.toString(),
          icon: Icons.assignment_turned_in_rounded,
          color: roleTheme.primary,
        ),
        MetricCard(
          title: 'Completed Attempts',
          value: analytics.completedAttempts.toString(),
          icon: Icons.done_all_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Pending Attempts',
          value: analytics.pendingAttempts.toString(),
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Avg MCQ Score',
          value: '${analytics.averageScore.toStringAsFixed(0)}%',
          icon: Icons.insights_rounded,
          color: AppColors.accent,
        ),
        MetricCard(
          title: 'Pass Rate',
          value: '${analytics.passRate.toStringAsFixed(0)}%',
          icon: Icons.verified_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Low Scores',
          value: analytics.lowScoreCount.toString(),
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
        ),
        MetricCard(
          title: 'Pending Reviews',
          value: analytics.pendingProjectReviews.toString(),
          icon: Icons.rate_review_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Avg Project Score',
          value: '${analytics.averageProjectScore.toStringAsFixed(0)}%',
          icon: Icons.folder_copy_rounded,
          color: roleTheme.secondary,
        ),
      ],
    );
  }
}

class _AssessmentBreakdownCard extends StatelessWidget {
  const _AssessmentBreakdownCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyMessage,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<TeacherAssignmentBreakdown> items;
  final String emptyMessage;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.take(3).map((item) => _BreakdownRow(item: item)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item});

  final TeacherAssignmentBreakdown item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = item.averageScore < 50
        ? AppColors.error
        : item.averageScore < 70
        ? AppColors.warning
        : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.22,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MiniStatusPill(label: item.type, color: scoreColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyMetric(
                  label: 'Attempts',
                  value: item.totalAttempts.toString(),
                ),
                _TinyMetric(
                  label: 'Avg',
                  value: '${item.averageScore.toStringAsFixed(0)}%',
                ),
                _TinyMetric(
                  label: 'Pass',
                  value: '${item.passRate.toStringAsFixed(0)}%',
                ),
                _TinyMetric(
                  label: 'Pending',
                  value: item.pendingCount.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentSignalCard extends StatelessWidget {
  const _StudentSignalCard({required this.analytics, required this.roleTheme});

  final TeacherAssessmentAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.psychology_alt_rounded,
                color: roleTheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Student Performance Signals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SignalLine(
            icon: Icons.emoji_events_rounded,
            color: AppColors.success,
            title: 'Top performers',
            value: analytics.topPerformers.isEmpty
                ? 'Waiting for high scores'
                : analytics.topPerformers
                      .take(2)
                      .map((item) => item.label)
                      .join(', '),
          ),
          const SizedBox(height: 12),
          _SignalLine(
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            title: 'Struggling students',
            value: analytics.strugglingStudents.isEmpty
                ? 'No low-score pattern yet'
                : '${analytics.strugglingStudents.length} need review',
          ),
          const SizedBox(height: 12),
          _SignalLine(
            icon: Icons.rate_review_rounded,
            color: AppColors.warning,
            title: 'Need feedback',
            value:
                '${analytics.studentsNeedingFeedback} project submissions pending',
          ),
          const SizedBox(height: 12),
          _SignalLine(
            icon: Icons.assignment_late_rounded,
            color: roleTheme.secondary,
            title: 'Missing work',
            value:
                '${analytics.studentsNotAttemptedCount + analytics.missingProjectSubmissions} expected submissions missing',
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendations,
    required this.roleTheme,
  });

  final List<String> recommendations;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.tips_and_updates_rounded,
                color: roleTheme.secondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Actionable Recommendations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final recommendation in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_circle_right_rounded,
                    size: 18,
                    color: roleTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SignalLine extends StatelessWidget {
  const _SignalLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.26,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnalyticsGlassCard extends StatelessWidget {
  const _AnalyticsGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GrandCertificateAnalyticsPanel extends StatelessWidget {
  const _GrandCertificateAnalyticsPanel({
    required this.analyticsAsync,
    required this.roleTheme,
  });

  final AsyncValue<TeacherGrandCertificateAnalytics> analyticsAsync;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return analyticsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const DashboardEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Grand Test analytics unavailable',
        message:
            'Grand Test and certificate insights could not be loaded right now. Pull down to retry.',
      ),
      data: (analytics) {
        if (!analytics.hasAnyData) {
          return const DashboardEmptyState(
            icon: Icons.workspace_premium_outlined,
            title: 'No Grand Test or certificate data yet',
            message:
                'Publish Grand Tests and issue certificates to unlock certification analytics.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GrandCertificateOverviewGrid(
              analytics: analytics,
              roleTheme: roleTheme,
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: 1,
              desktopColumns: 2,
              wideColumns: 2,
              minChildWidth: 360,
              children: [
                _GrandTestBreakdownCard(
                  analytics: analytics,
                  roleTheme: roleTheme,
                ),
                _CertificatePipelineCard(
                  analytics: analytics,
                  roleTheme: roleTheme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: 1,
              desktopColumns: 2,
              wideColumns: 2,
              minChildWidth: 360,
              children: [
                _GrandStudentSignalsCard(
                  analytics: analytics,
                  roleTheme: roleTheme,
                ),
                _GrandCertificateRecommendationCard(
                  analytics: analytics,
                  roleTheme: roleTheme,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GrandCertificateOverviewGrid extends StatelessWidget {
  const _GrandCertificateOverviewGrid({
    required this.analytics,
    required this.roleTheme,
  });

  final TeacherGrandCertificateAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      children: [
        MetricCard(
          title: 'Active Grand Tests',
          value: analytics.activeGrandTests.toString(),
          icon: Icons.workspace_premium_rounded,
          color: roleTheme.primary,
        ),
        MetricCard(
          title: 'Grand Attempts',
          value: analytics.totalGrandAttempts.toString(),
          icon: Icons.assignment_turned_in_rounded,
          color: AppColors.accent,
        ),
        MetricCard(
          title: 'Grand Pass Rate',
          value: '${analytics.grandPassRate.toStringAsFixed(0)}%',
          icon: Icons.verified_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Avg Grand Score',
          value: '${analytics.averageGrandScore.toStringAsFixed(0)}%',
          icon: Icons.analytics_rounded,
          color: roleTheme.secondary,
        ),
        MetricCard(
          title: 'No Attempt',
          value: analytics.noAttemptStudents.toString(),
          icon: Icons.person_off_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Warnings',
          value: analytics.warningAttempts.toString(),
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
        ),
        MetricCard(
          title: 'Certificates',
          value: analytics.activeCertificates.toString(),
          icon: Icons.card_membership_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Pending Certificates',
          value: analytics.pendingCertificateIssuance.toString(),
          icon: Icons.workspace_premium_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _GrandTestBreakdownCard extends StatelessWidget {
  const _GrandTestBreakdownCard({
    required this.analytics,
    required this.roleTheme,
  });

  final TeacherGrandCertificateAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.workspace_premium_rounded,
            color: roleTheme.primary,
            title: 'Grand Test Performance',
            subtitle: 'Attempts, pass rate, warnings, and score spread.',
          ),
          const SizedBox(height: 18),
          if (analytics.grandTestBreakdowns.isEmpty)
            Text(
              'No Grand Test attempts yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...analytics.grandTestBreakdowns
                .take(3)
                .map((item) => _GrandBreakdownRow(item: item)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed:
                  analytics.firstGrandTestCourseId == null ||
                      analytics.firstGrandTestId == null
                  ? null
                  : () => context.pushNamed(
                      RouteNames.teacherGrandTestAttempts,
                      pathParameters: {
                        'courseId': analytics.firstGrandTestCourseId!,
                        'grandTestId': analytics.firstGrandTestId!,
                      },
                    ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Attempts'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificatePipelineCard extends StatelessWidget {
  const _CertificatePipelineCard({
    required this.analytics,
    required this.roleTheme,
  });

  final TeacherGrandCertificateAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.card_membership_rounded,
            color: AppColors.success,
            title: 'Certification Pipeline',
            subtitle: 'Issued, pending, revoked, and course-level trust data.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyMetric(
                label: 'Issued',
                value: analytics.totalCertificatesIssued.toString(),
              ),
              _TinyMetric(
                label: 'Active',
                value: analytics.activeCertificates.toString(),
              ),
              _TinyMetric(
                label: 'Revoked',
                value: analytics.revokedCertificates.toString(),
              ),
              _TinyMetric(
                label: 'Avg',
                value:
                    '${analytics.averageCertificateScore.toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (analytics.certificateBreakdowns.isEmpty)
            Text(
              'No certificate pipeline data yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...analytics.certificateBreakdowns
                .take(3)
                .map((item) => _CertificateBreakdownRow(item: item)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: analytics.firstCertificateCourseId == null
                  ? null
                  : () => context.pushNamed(
                      RouteNames.teacherCertificates,
                      pathParameters: {
                        'courseId': analytics.firstCertificateCourseId!,
                      },
                    ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Certificates'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrandStudentSignalsCard extends StatelessWidget {
  const _GrandStudentSignalsCard({
    required this.analytics,
    required this.roleTheme,
  });

  final TeacherGrandCertificateAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.school_rounded,
            color: roleTheme.secondary,
            title: 'Grand Test Student Signals',
            subtitle:
                'Top scorers, failed attempts, and certification momentum.',
          ),
          const SizedBox(height: 18),
          _SignalLine(
            icon: Icons.emoji_events_rounded,
            color: AppColors.success,
            title: 'Top scorers',
            value: analytics.topScorers.isEmpty
                ? 'Waiting for submitted attempts'
                : analytics.topScorers
                      .take(2)
                      .map(
                        (student) =>
                            '${student.label} (${student.score.toStringAsFixed(0)}%)',
                      )
                      .join(', '),
          ),
          const SizedBox(height: 12),
          _SignalLine(
            icon: Icons.close_rounded,
            color: AppColors.error,
            title: 'Failed attempts',
            value: analytics.failedStudents.isEmpty
                ? 'No failed submissions yet'
                : '${analytics.failedStudents.length} students need revision',
          ),
          const SizedBox(height: 12),
          _SignalLine(
            icon: Icons.trending_up_rounded,
            color: AppColors.warning,
            title: 'Close to passing',
            value:
                '${analytics.closeToPassingStudents} students are within 10% of passing',
          ),
          const SizedBox(height: 12),
          _SignalLine(
            icon: Icons.card_membership_rounded,
            color: roleTheme.primary,
            title: 'Most certified',
            value: analytics.topCertifiedStudents.isEmpty
                ? 'No certificate leaders yet'
                : analytics.topCertifiedStudents
                      .take(2)
                      .map(
                        (student) =>
                            '${student.label} (${student.certificateCount})',
                      )
                      .join(', '),
          ),
        ],
      ),
    );
  }
}

class _GrandCertificateRecommendationCard extends StatelessWidget {
  const _GrandCertificateRecommendationCard({
    required this.analytics,
    required this.roleTheme,
  });

  final TeacherGrandCertificateAnalytics analytics;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnalyticsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsCardHeader(
            icon: Icons.auto_awesome_rounded,
            color: roleTheme.primary,
            title: 'Certification Intelligence',
            subtitle: 'Actions that keep tests fair and certificates credible.',
          ),
          const SizedBox(height: 18),
          if (!analytics.eligibilityBreakdownAvailable)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Exact eligibility blocker breakdown is calculated live on the eligibility screen, so this dashboard only shows stored attempt/certificate signals.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          for (final recommendation in analytics.recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_circle_right_rounded,
                    size: 18,
                    color: roleTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GrandBreakdownRow extends StatelessWidget {
  const _GrandBreakdownRow({required this.item});

  final GrandTestAnalyticsBreakdown item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = item.averageScore < 50
        ? AppColors.error
        : item.averageScore < 70
        ? AppColors.warning
        : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.22,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MiniStatusPill(label: item.status, color: scoreColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyMetric(
                  label: 'Attempts',
                  value: item.totalAttempts.toString(),
                ),
                _TinyMetric(
                  label: 'Passed',
                  value: item.passedCount.toString(),
                ),
                _TinyMetric(
                  label: 'Avg',
                  value: '${item.averageScore.toStringAsFixed(0)}%',
                ),
                _TinyMetric(
                  label: 'No attempt',
                  value: item.noAttemptCount.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateBreakdownRow extends StatelessWidget {
  const _CertificateBreakdownRow({required this.item});

  final CertificateCourseBreakdown item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.22,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyMetric(
                  label: 'Eligible',
                  value: item.eligibleStudents.toString(),
                ),
                _TinyMetric(
                  label: 'Issued',
                  value: item.issuedCertificates.toString(),
                ),
                _TinyMetric(
                  label: 'Pending',
                  value: item.pendingIssuance.toString(),
                ),
                _TinyMetric(
                  label: 'Score',
                  value: '${item.averageFinalScore.toStringAsFixed(0)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCardHeader extends StatelessWidget {
  const _AnalyticsCardHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBubble(icon: icon, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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

class _PendingWorkList extends StatelessWidget {
  const _PendingWorkList({required this.stats, required this.roleTheme});

  final TeacherDashboardStatsModel stats;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    if (stats.pendingWorks.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No pending work',
        message:
            'Project reviews, grand test attempts, and certificate candidates will appear here.',
      );
    }

    return Column(
      children: stats.pendingWorks
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingWorkCard(
                item: item,
                roleTheme: roleTheme,
                onTap: () => _openPendingWork(context, item, stats),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openPendingWork(
    BuildContext context,
    TeacherPendingWorkItem item,
    TeacherDashboardStatsModel stats,
  ) {
    if (item.assignmentId != null && item.courseId != null) {
      context.pushNamed(
        RouteNames.teacherProjectSubmissions,
        pathParameters: {
          'courseId': item.courseId!,
          'assignmentId': item.assignmentId!,
        },
      );
      return;
    }
    if (item.grandTestId != null && item.courseId != null) {
      context.pushNamed(
        RouteNames.teacherGrandTestAttempts,
        pathParameters: {
          'courseId': item.courseId!,
          'grandTestId': item.grandTestId!,
        },
      );
      return;
    }
    _withCourse(context, stats, (courseId) {
      context.pushNamed(
        RouteNames.teacherCertificates,
        pathParameters: {'courseId': courseId},
      );
    });
  }
}

class _PendingWorkCard extends StatelessWidget {
  const _PendingWorkCard({
    required this.item,
    required this.onTap,
    required this.roleTheme,
  });

  final TeacherPendingWorkItem item;
  final VoidCallback onTap;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            _IconBubble(
              icon: _iconFor(item.iconName),
              color: roleTheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                item.count.toString(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.stats, required this.roleTheme});

  final TeacherDashboardStatsModel stats;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    if (stats.activities.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.timeline_rounded,
        title: 'No activity yet',
        message:
            'Enrollments, submissions, attempts, and certificates will appear here as your courses grow.',
      );
    }

    return Column(
      children: stats.activities
          .map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityCard(activity: activity, roleTheme: roleTheme),
            ),
          )
          .toList(),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.roleTheme});

  final TeacherDashboardActivityItem activity;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _IconBubble(
            icon: _iconFor(activity.iconName),
            color: roleTheme.secondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _relativeTime(activity.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _ActionSpec {
  const _ActionSpec({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

void _withCourse(
  BuildContext context,
  TeacherDashboardStatsModel stats,
  void Function(String courseId) action,
) {
  final courseId = stats.primaryCourseId;
  if (courseId == null || courseId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create a course first to unlock this action.'),
      ),
    );
    return;
  }
  action(courseId);
}

IconData _iconFor(String name) {
  return switch (name) {
    'project' => Icons.folder_special_rounded,
    'grandTest' => Icons.workspace_premium_rounded,
    'certificate' => Icons.verified_rounded,
    'enrollment' => Icons.person_add_alt_1_rounded,
    'assignment' => Icons.assignment_turned_in_rounded,
    'attention' => Icons.volunteer_activism_rounded,
    'risk' => Icons.warning_amber_rounded,
    'activity' => Icons.timeline_rounded,
    'course' => Icons.video_library_rounded,
    _ => Icons.insights_rounded,
  };
}

Color _priorityColor(String priority, RoleThemeColors roleTheme) {
  return switch (priority) {
    TeacherInsightPriority.high => AppColors.error,
    TeacherInsightPriority.medium => AppColors.warning,
    TeacherInsightPriority.low => roleTheme.secondary,
    _ => roleTheme.primary,
  };
}

void _openWorkspaceItem(BuildContext context, TeacherWorkspaceItem item) {
  if (item.iconName == 'project' &&
      item.courseId != null &&
      item.assignmentId != null) {
    context.pushNamed(
      RouteNames.teacherProjectSubmissions,
      pathParameters: {
        'courseId': item.courseId!,
        'assignmentId': item.assignmentId!,
      },
    );
    return;
  }
  if (item.iconName == 'grandTest' &&
      item.courseId != null &&
      item.grandTestId != null) {
    context.pushNamed(
      RouteNames.teacherGrandTestAttempts,
      pathParameters: {
        'courseId': item.courseId!,
        'grandTestId': item.grandTestId!,
      },
    );
    return;
  }
  if (item.iconName == 'certificate' && item.courseId != null) {
    context.pushNamed(
      RouteNames.teacherCertificates,
      pathParameters: {'courseId': item.courseId!},
    );
    return;
  }
  context.push(RoutePaths.teacherStudentProgress);
}

String _relativeTime(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inDays > 0) return '${difference.inDays}d ago';
  if (difference.inHours > 0) return '${difference.inHours}h ago';
  if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
  return 'Just now';
}
