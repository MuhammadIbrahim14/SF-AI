import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/job_match_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class JobListScreen extends ConsumerWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(allJobsProvider);
    final matchedJobsAsync = ref.watch(matchedJobsProvider);
    final currentRole =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.freelancer;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: currentRole,
      title: 'Opportunities',
      subtitle: 'Browse verified roles matched to your skills and profile.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(_dashboardRouteFor(currentRole)),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: jobsAsync.when(
          data: (jobs) {
            final activeJobs = jobs.where((j) => j.isActive).toList();

            if (activeJobs.isEmpty) {
              return const Center(
                child: Text('No jobs available at the moment.'),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allJobsProvider);
                ref.invalidate(matchedJobsProvider);
              },
              child: matchedJobsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _JobMatchMessage(
                  title: 'Sync Engine Offline',
                  message:
                      'Pull down to retry. We only show roles that fit your verified skill profile.',
                  detail: error.toString(),
                ),
                data: (matchedJobs) {
                  final visibleMatches = matchedJobs
                      .where(
                        (item) => isJobRelevantForCandidate(
                          job: item.job,
                          match: item.match,
                        ),
                      )
                      .toList();
                  final strongMatches = visibleMatches
                      .where((item) => item.match.isStrongMatch)
                      .toList();
                  final otherRelevantMatches = visibleMatches
                      .where((item) => !item.match.isStrongMatch)
                      .toList();

                  if (visibleMatches.isEmpty) {
                    return const _JobMatchMessage(
                      title: 'No Verified Matches Found',
                      message:
                          'Your profile is protected from unrelated jobs. Complete more skill assessments, projects, and resume details to unlock high-quality matches.',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.radar_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Career Radar Active',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We found ${visibleMatches.length} roles matching your verified skills. ${strongMatches.length} are high-confidence matches.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (strongMatches.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.error,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'High-Confidence Matches',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ...strongMatches.map(
                          (item) => _PremiumJobCard(item: item),
                        ),
                        const SizedBox(height: 32),
                      ],

                      if (otherRelevantMatches.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.explore_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Other Relevant Roles',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ...otherRelevantMatches.map(
                          (item) => _PremiumJobCard(item: item),
                        ),
                      ],
                    ],
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

class _PremiumJobCard extends StatelessWidget {
  const _PremiumJobCard({required this.item});

  final MatchedJobModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matchScore = item.match.matchScore;
    final isStrong = item.match.isStrongMatch;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isStrong
              ? AppColors.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: isStrong
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.jobDetail,
            pathParameters: {'id': item.job.id},
          ),
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
                        color: isDark
                            ? const Color(0xFF222222)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.business_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.job.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Company ID: ${item.job.companyId.substring(0, 8)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Match Score Ring
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (matchScore / 100).clamp(0.0, 1.0),
                            strokeWidth: 4,
                            color: isStrong
                                ? AppColors.success
                                : AppColors.primary,
                            backgroundColor:
                                (isStrong
                                        ? AppColors.success
                                        : AppColors.primary)
                                    .withValues(alpha: 0.1),
                          ),
                          Text(
                            matchScore.toStringAsFixed(0),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isStrong
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _IconText(
                      icon: Icons.location_on_rounded,
                      text: item.job.location,
                    ),
                    _IconText(icon: Icons.work_rounded, text: item.job.type),
                    _IconText(
                      icon: Icons.attach_money_rounded,
                      text: item.job.salaryRange,
                      color: AppColors.success,
                    ),
                    if (item.job.remoteAllowed)
                      const _IconText(
                        icon: Icons.public_rounded,
                        text: 'Remote Friendly',
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                Text(
                  'Verification Check',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...item.match.matchedSkills.map(
                      (skill) => _SkillChip(label: skill, isMatched: true),
                    ),
                    ...item.match.missingSkills.map(
                      (skill) => _SkillChip(label: skill, isMatched: false),
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
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: themeColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: themeColor,
          ),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.isMatched});

  final String label;
  final bool isMatched;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMatched
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.05),
        border: Border.all(
          color: isMatched
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMatched ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: isMatched ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isMatched ? AppColors.success : AppColors.error,
              decoration: isMatched ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobMatchMessage extends StatelessWidget {
  const _JobMatchMessage({
    required this.title,
    required this.message,
    this.detail,
  });

  final String title;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
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
                  Icons.shield_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  detail!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
