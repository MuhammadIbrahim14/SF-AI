import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/job_match_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/interview_provider.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_shell.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/dashboard_section.dart';
import '../../../shared/widgets/profile_completion_card.dart';
import '../../../shared/navigation/role_navigation_config.dart';
import '../../courses/providers/enrollment_provider.dart';
import '../../../core/theme/role_theme.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final studentAsync = ref.watch(studentProvider);
    final matchedJobsAsync = ref.watch(matchedJobsProvider);
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final interviewsAsync = ref.watch(myInterviewsProvider);
    final profile = ref.watch(profileDataProvider).value;
    final enrollments = ref.watch(studentEnrollmentsProvider).value;
    ref.watch(profileCompletionSyncProvider);

    final user = userAsync.value;
    final student = studentAsync.value;
    final completion = profile?.completion;
    final enrolledCourseCount =
        enrollments?.length ?? student?.enrolledCourses.length ?? 0;
    final completedCourseCount =
        enrollments
            ?.where(
              (enrollment) =>
                  enrollment.isCompleted || enrollment.progressPercent >= 100,
            )
            .length ??
        0;
    final hasApplications = (applicationsAsync.value ?? const []).isNotEmpty;
    final hasInterviews = (interviewsAsync.value ?? const []).isNotEmpty;
    final showInterviewAction = hasApplications || hasInterviews;
    final roleTheme = getRoleTheme(UserRole.student);

    return RoleDashboardFrame(
      role: UserRole.student,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(studentProvider);
          ref.invalidate(allJobsProvider);
          ref.invalidate(myApplicationsProvider);
          ref.invalidate(myInterviewsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // Profile Completion
            if (completion != null && !completion.isComplete)
              ProfileCompletionCard(
                completionPercentage: completion.profileCompletionPercentage,
                isProfileImageMissing: completion.missingFields.contains(
                  'Profile image',
                ),
                missingFields: completion.missingFields,
                onCompleteProfileTap: () =>
                    context.pushNamed(RouteNames.studentEditProfile),
                roleTheme: roleTheme,
              ),

            // Bento Dashboard Grid
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _BentoStatCard(
                                title: 'Enrolled Courses',
                                value: enrolledCourseCount.toString(),
                                icon: Icons.menu_book_rounded,
                                color: Colors.blue,
                                onTap: () => context.pushNamed(
                                  RouteNames.studentEnrolledCourses,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _BentoStatCard(
                                title: 'Completed',
                                value: completedCourseCount.toString(),
                                icon: Icons.workspace_premium_rounded,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _BentoStatCard(
                              title: 'Enrolled Courses',
                              value: enrolledCourseCount.toString(),
                              icon: Icons.menu_book_rounded,
                              color: Colors.blue,
                              onTap: () => context.pushNamed(
                                RouteNames.studentEnrolledCourses,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _BentoStatCard(
                              title: 'Completed Courses',
                              value: completedCourseCount.toString(),
                              icon: Icons.workspace_premium_rounded,
                              color: Colors.green,
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // Active Skills Bento Box
                      _BentoSkillsBox(
                        studentSkills: student?.skills ?? [],
                        roleTheme: roleTheme,
                      ),

                      const SizedBox(height: 24),

                      // Credentials & Career Tools Grid
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _BentoActionCard(
                                title: 'Skill Scores',
                                subtitle: 'View analytics',
                                icon: Icons.psychology_rounded,
                                color: Colors.purple,
                                onTap: () => context.pushNamed(
                                  RouteNames.studentSkillScores,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _BentoActionCard(
                                title: 'My Certificates',
                                subtitle: 'Verified proof',
                                icon: Icons.workspace_premium_rounded,
                                color: Colors.amber.shade600,
                                onTap: () => context.pushNamed(
                                  RouteNames.studentCertificates,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _BentoActionCard(
                              title: 'Skill Scores',
                              subtitle: 'View learning analytics',
                              icon: Icons.psychology_rounded,
                              color: Colors.purple,
                              onTap: () => context.pushNamed(
                                RouteNames.studentSkillScores,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _BentoActionCard(
                              title: 'My Certificates',
                              subtitle: 'Access verified credentials',
                              icon: Icons.workspace_premium_rounded,
                              color: Colors.amber.shade600,
                              onTap: () => context.pushNamed(
                                RouteNames.studentCertificates,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'Smart Resume',
                        subtitle: 'AI-generated career profile',
                        icon: Icons.description_rounded,
                        color: Colors.teal,
                        isFullWidth: true,
                        onTap: () =>
                            context.pushNamed(RouteNames.studentResume),
                      ),

                      const SizedBox(height: 16),

                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _BentoActionCard(
                                title: 'My Classes',
                                subtitle: 'Batches · sessions · announcements',
                                icon: Icons.groups_2_rounded,
                                color: Colors.blueGrey,
                                onTap: () => context.pushNamed(
                                  RouteNames.studentMyBatches,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _BentoActionCard(
                                title: 'Join class batch',
                                subtitle: 'Enter invite code',
                                icon: Icons.vpn_key_rounded,
                                color: Colors.blueGrey.shade700,
                                onTap: () => context.pushNamed(
                                  RouteNames.studentJoinBatch,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _BentoActionCard(
                          title: 'My Classes',
                          subtitle:
                              'Batches, sessions, and class announcements',
                          icon: Icons.groups_2_rounded,
                          color: Colors.blueGrey,
                          isFullWidth: true,
                          onTap: () =>
                              context.pushNamed(RouteNames.studentMyBatches),
                        ),
                        const SizedBox(height: 16),
                        _BentoActionCard(
                          title: 'Join class batch',
                          subtitle: 'Enter invite code from your teacher',
                          icon: Icons.vpn_key_rounded,
                          color: Colors.blueGrey.shade700,
                          isFullWidth: true,
                          onTap: () =>
                              context.pushNamed(RouteNames.studentJoinBatch),
                        ),
                      ],

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'Career Roadmap',
                        subtitle: 'Verified skill gap and next steps',
                        icon: Icons.route_rounded,
                        color: Colors.blueAccent,
                        isFullWidth: true,
                        onTap: () =>
                            context.pushNamed(RouteNames.studentCareerRoadmap),
                      ),

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'AI Career Intelligence',
                        subtitle: 'Readiness, resume, portfolio, market insights',
                        icon: Icons.psychology_alt_rounded,
                        color: Colors.indigo,
                        isFullWidth: true,
                        onTap: () =>
                            context.pushNamed(RouteNames.careerIntelligence),
                      ),

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'Freelancer Bridge',
                        subtitle: 'Showcase verified skills publicly',
                        icon: Icons.rocket_launch_rounded,
                        color: Colors.green,
                        isFullWidth: true,
                        onTap: () => context.pushNamed(
                          RouteNames.studentFreelancerBridge,
                        ),
                      ),

                      if (user?.canUseFreelancerMode == true) ...[
                        const SizedBox(height: 16),
                        _StudentFreelancerModeCard(
                          freelancerMode:
                              user?.primaryRoleEnum == UserRole.freelancer,
                          switching: ref.watch(roleNotifierProvider).isLoading,
                          onSwitchToFreelancer: () async {
                            final ok = await ref
                                .read(roleNotifierProvider.notifier)
                                .setPrimaryRoleOnly(UserRole.freelancer);
                            if (!context.mounted) return;
                            if (ok) {
                              context.goNamed(RouteNames.freelancerDashboard);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ref
                                            .read(roleNotifierProvider)
                                            .error
                                            ?.toString() ??
                                        'Unable to switch mode.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'Ask SkillForge Tutor',
                        subtitle:
                            'Explain lessons, practice, and revise safely',
                        icon: Icons.auto_awesome_rounded,
                        color: Colors.cyan,
                        isFullWidth: true,
                        onTap: () =>
                            context.pushNamed(RouteNames.studentAiTutor),
                      ),

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'AI Interview Lab',
                        subtitle:
                            'Practice role interviews with AI â€” private, not hiring',
                        icon: Icons.record_voice_over_rounded,
                        color: Colors.deepPurple,
                        isFullWidth: true,
                        onTap: () =>
                            context.pushNamed(RouteNames.interviewLab),
                      ),

                      const SizedBox(height: 16),

                      _BentoActionCard(
                        title: 'View Services',
                        subtitle: 'Hire top talent for your projects',
                        icon: Icons.design_services_rounded,
                        color: Colors.indigo,
                        isFullWidth: true,
                        onTap: () =>
                            context.pushNamed(RouteNames.servicesMarketplace),
                      ),

                      if (showInterviewAction) ...[
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final apps =
                                applicationsAsync.value ?? const [];
                            final hasPendingOffer = apps.any(
                              (a) =>
                                  a.normalizedOfferStatus == 'sent' ||
                                  a.normalizedOfferStatus == 'clarification',
                            );
                            return _BentoActionCard(
                              title: hasPendingOffer
                                  ? 'Pending Job Offer'
                                  : 'My Applications',
                              subtitle: hasPendingOffer
                                  ? 'A company sent you an offer — review & respond'
                                  : 'Track applications, offers, and hiring status',
                              icon: hasPendingOffer
                                  ? Icons.mark_email_unread_rounded
                                  : Icons.assignment_turned_in_rounded,
                              color: hasPendingOffer
                                  ? Colors.teal
                                  : Colors.deepOrange,
                              isFullWidth: true,
                              onTap: () => context.pushNamed(
                                RouteNames.myApplications,
                              ),
                            );
                          },
                        ),
                        Builder(
                          builder: (context) {
                            final apps =
                                applicationsAsync.value ?? const [];
                            final hasEmployment = apps.any(
                              (a) =>
                                  a.isJoiningSoon ||
                                  a.isActiveEmployee ||
                                  a.isLeftEmployee,
                            );
                            if (!hasEmployment) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                _BentoActionCard(
                                  title: 'My Employment',
                                  subtitle:
                                      'Onboarding, welcome pack, documents, and HR',
                                  icon: Icons.badge_rounded,
                                  color: Colors.blueGrey,
                                  isFullWidth: true,
                                  onTap: () => context.pushNamed(
                                    RouteNames.myEmployment,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (hasInterviews) ...[
                          const SizedBox(height: 16),
                          _BentoActionCard(
                            title: 'My Interviews',
                            subtitle: 'Upcoming and past hiring interviews',
                            icon: Icons.event_available_rounded,
                            color: Colors.indigo,
                            isFullWidth: true,
                            onTap: () =>
                                context.pushNamed(RouteNames.myInterviews),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 16),
                        _CareerReadinessCard(
                          onLearn: () =>
                              context.pushNamed(RouteNames.studentCourses),
                          onBuildResume: () =>
                              context.pushNamed(RouteNames.studentResume),
                          roleTheme: roleTheme,
                        ),
                      ],

                      const SizedBox(height: 16),

                      _StudentMissingNavActionCards(
                        coveredRouteNames: {
                          RouteNames.studentEnrolledCourses,
                          RouteNames.studentSkillScores,
                          RouteNames.studentCertificates,
                          RouteNames.studentResume,
                          RouteNames.studentMyBatches,
                          RouteNames.studentJoinBatch,
                          RouteNames.studentCareerRoadmap,
                          RouteNames.careerIntelligence,
                          RouteNames.studentFreelancerBridge,
                          RouteNames.studentAiTutor,
                          RouteNames.interviewLab,
                          RouteNames.servicesMarketplace,
                          RouteNames.jobList,
                          if (showInterviewAction) RouteNames.myApplications,
                          if (hasInterviews) RouteNames.myInterviews,
                          if (!showInterviewAction) RouteNames.studentCourses,
                        },
                        roleTheme: roleTheme,
                      ),
                    ],
                  );
                },
              ),
            ),

            DashboardSection(
              title: 'Career Match Engine',
              actionText: 'Browse All Jobs',
              onActionTap: () => context.pushNamed(RouteNames.jobList),
              child: matchedJobsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const DashboardEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Job matching is unavailable',
                  message:
                      'We could not calculate your job matches right now. Pull down to retry.',
                ),
                data: (matchedJobs) {
                  final relevantJobs = matchedJobs
                      .where(
                        (item) => isJobRelevantForCandidate(
                          job: item.job,
                          match: item.match,
                        ),
                      )
                      .toList();
                  final topMatch = relevantJobs.isEmpty
                      ? null
                      : relevantJobs.first;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _CareerMatchActionCard(
                      relevantCount: relevantJobs.length,
                      topMatch: topMatch,
                      onBrowse: () => context.pushNamed(RouteNames.jobList),
                      roleTheme: roleTheme,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoStatCard extends StatelessWidget {
  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetId =
        'student.dashboard.stat.${title.toLowerCase().replaceAll(' ', '_')}';

    return SieInteractive(
      targetId: targetId,
      button: onTap != null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      if (onTap != null)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: color,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BentoSkillsBox extends StatelessWidget {
  const _BentoSkillsBox({required this.studentSkills, required this.roleTheme});
  final List<String> studentSkills;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [roleTheme.primary, roleTheme.secondary],
                ).createShader(bounds),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Verified Skills Engine',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (studentSkills.isEmpty)
            Text(
              'No skills added yet. Complete courses to build your skill tree.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: studentSkills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: roleTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: roleTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      color: roleTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StudentMissingNavActionCards extends StatelessWidget {
  const _StudentMissingNavActionCards({
    required this.coveredRouteNames,
    required this.roleTheme,
  });

  final Set<String> coveredRouteNames;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final sections = RoleNavigationConfig.appMenuSectionsFor(UserRole.student);
    final missing = <RoleNavigationDestination>[];

    for (final section in sections) {
      for (final item in section.items) {
        if (!coveredRouteNames.contains(item.routeName)) {
          missing.add(item);
        }
      }
    }

    if (missing.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var i = 0; i < missing.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _BentoActionCard(
            title: missing[i].label,
            subtitle: missing[i].description ?? 'Open ${missing[i].label}',
            icon: missing[i].icon,
            color: _studentNavActionColor(missing[i], roleTheme),
            isFullWidth: true,
            onTap: () => context.pushNamed(missing[i].routeName),
          ),
        ],
      ],
    );
  }
}

Color _studentNavActionColor(
  RoleNavigationDestination item,
  RoleThemeColors theme,
) {
  return switch (item.actionGroup) {
    RoleNavigationActionGroup.learning => Colors.blue,
    RoleNavigationActionGroup.jobs => Colors.deepOrange,
    RoleNavigationActionGroup.profile => Colors.purple,
    _ => theme.secondary,
  };
}

class _BentoActionCard extends StatelessWidget {
  const _BentoActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetId =
        'student.dashboard.action.${title.toLowerCase().replaceAll(' ', '_')}';

    return SieInteractive(
      targetId: targetId,
      button: true,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerMatchActionCard extends StatelessWidget {
  const _CareerMatchActionCard({
    required this.relevantCount,
    required this.onBrowse,
    this.topMatch,
    required this.roleTheme,
  });

  final int relevantCount;
  final MatchedJobModel? topMatch;
  final VoidCallback onBrowse;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasMatches = relevantCount > 0 && topMatch != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            roleTheme.secondary.withValues(alpha: 0.15),
            roleTheme.primary.withValues(alpha: 0.08),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: roleTheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: theme.brightness == Brightness.dark
            ? AppTheme.darkShadowMd
            : AppTheme.lightShadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: roleTheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.workspaces_rounded,
                  color: roleTheme.secondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMatches
                          ? '$relevantCount matched ${relevantCount == 1 ? 'job' : 'jobs'} unlocked'
                          : 'Unlock premium job matches',
                      style: AppTypography.titleMedium.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasMatches
                          ? 'Based on your verified skills, scores, and smart resume data.'
                          : 'Jobs appear only when your verified skills match company requirements. Keep learning to unlock.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasMatches) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topMatch!.job.title,
                          style: AppTypography.titleMedium.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${topMatch!.match.matchScore.toStringAsFixed(0)}% MATCH',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      topMatch!.job.type,
                      topMatch!.job.location,
                    ].where((value) => value.trim().isNotEmpty).join(' â€¢ '),
                    style: AppTypography.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (topMatch!.match.matchedSkills.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topMatch!.match.matchedSkills
                          .take(3)
                          .map(
                            (skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                skill,
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.radar_rounded, size: 20),
              label: Text(
                hasMatches ? 'View Matching Jobs' : 'Explore Opportunities',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: roleTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerReadinessCard extends StatelessWidget {
  const _CareerReadinessCard({
    required this.onLearn,
    required this.onBuildResume,
    required this.roleTheme,
  });

  final VoidCallback onLearn;
  final VoidCallback onBuildResume;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: roleTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: roleTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Career Accelerator',
                      style: AppTypography.titleMedium.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Interviews unlock after you become eligible for real jobs. Build skills and earn certificates.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReadinessChip(label: 'Learn skills', roleTheme: roleTheme),
              _ReadinessChip(label: 'Pass assessments', roleTheme: roleTheme),
              _ReadinessChip(label: 'Earn certificates', roleTheme: roleTheme),
              _ReadinessChip(label: 'Build resume', roleTheme: roleTheme),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onLearn,
                  icon: const Icon(Icons.school_rounded, size: 18),
                  label: const Text(
                    'Start Learning',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onBuildResume,
                  icon: const Icon(Icons.description_rounded, size: 18),
                  label: const Text(
                    'Build Resume',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

class _StudentFreelancerModeCard extends StatelessWidget {
  const _StudentFreelancerModeCard({
    required this.freelancerMode,
    required this.switching,
    required this.onSwitchToFreelancer,
  });

  final bool freelancerMode;
  final bool switching;
  final VoidCallback onSwitchToFreelancer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  freelancerMode ? 'Freelancer mode active' : 'Freelancer mode unlocked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch primary role to Freelancer to manage paid services. Student learning data stays intact.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: switching || freelancerMode ? null : onSwitchToFreelancer,
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }
}

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.label, required this.roleTheme});

  final String label;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: roleTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: roleTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: roleTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
