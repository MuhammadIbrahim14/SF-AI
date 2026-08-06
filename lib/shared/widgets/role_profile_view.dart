import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/profile_completion.dart';
import '../../models/user_role.dart';
import '../../core/theme/role_theme.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/profile_provider.dart';
import '../../features/profile/presentation/widgets/profile_navigation_card.dart';
import 'avatar_widget.dart';
import 'role_fixed_header_page.dart';

class RoleProfileView extends ConsumerWidget {
  const RoleProfileView({
    super.key,
    required this.role,
    required this.editRouteName,
  });

  final UserRole role;
  final String editRouteName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);
    final roleTheme = getRoleTheme(role);
    ref.watch(profileCompletionSyncProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final companyApplications = role == UserRole.company
        ? ref.watch(companyApplicationsProvider).value?.length ?? 0
        : 0;
    final companyJobs = role == UserRole.company
        ? ref.watch(companyJobsProvider).value?.length ?? 0
        : 0;

    return RoleFixedHeaderPage(
      role: role,
      title: 'Profile Center',
      subtitle:
          'Manage your identity, role profile, security, and preferences.',
      scrollable: false,
      actions: [
        IconButton.filledTonal(
          tooltip: 'Edit profile',
          onPressed: () => context.pushNamed(editRouteName),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileMessage(
          icon: Icons.error_outline_rounded,
          message: error.toString(),
        ),
        data: (profile) {
          if (profile == null || profile.role != role) {
            return const _ProfileMessage(
              icon: Icons.person_off_outlined,
              message: 'Profile data is not available.',
            );
          }

          final user = profile.user;
          final details = profile.details;
          final displayName = role == UserRole.company
              ? _text(details['companyName'], user.fullName)
              : user.fullName;
          final initial = displayName.trim().isEmpty
              ? 'U'
              : displayName.trim()[0].toUpperCase();
          final navigationItems = _navigationItems(roleTheme);
          final completion = profile.completion;
          final stats = _statsForRole(
            role,
            details,
            completion.profileCompletionPercentage,
            companyApplications,
            companyJobs,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth < 600 ? 16.0 : 32.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PremiumHeroCard(
                          role: role,
                          roleTheme: roleTheme,
                          imageUrl: user.profileImage,
                          fallbackText: initial,
                          displayName: displayName,
                          email: user.email,
                          completion: completion.profileCompletionPercentage,
                          isVerified: firebaseUser?.emailVerified ?? false,
                          onEdit: () => context.pushNamed(editRouteName),
                        ),
                        if (!completion.isComplete) ...[
                          const SizedBox(height: 16),
                          _ProfileCompletionInsights(
                            completion: completion,
                            roleTheme: roleTheme,
                            onCompleteProfile: () =>
                                context.pushNamed(editRouteName),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Quick overview',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        _QuickStats(stats: stats),
                        const SizedBox(height: 28),
                        Text(
                          'Manage your profile',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Open a focused space for each part of your account.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: navigationItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: constraints.maxWidth < 380
                                    ? 1
                                    : constraints.maxWidth < 700
                                    ? 2
                                    : 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: constraints.maxWidth < 380
                                    ? 2.05
                                    : 1.18,
                              ),
                          itemBuilder: (context, index) {
                            final item = navigationItems[index];
                            return ProfileNavigationCard(
                              index: index,
                              icon: item.icon,
                              title: item.title,
                              subtitle: item.subtitle,
                              accentColor: item.color,
                              onTap: () => context.pushNamed(item.routeName),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileCompletionInsights extends StatelessWidget {
  const _ProfileCompletionInsights({
    required this.completion,
    required this.onCompleteProfile,
    required this.roleTheme,
  });

  final ProfileCompletionResult completion;
  final VoidCallback onCompleteProfile;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageMissing = completion.missingFields.contains('Profile image');

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: roleTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_circle_outlined,
                      color: roleTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete your account',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${completion.completedFields.length} of '
                          '${completion.totalFields} required fields completed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
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
                      color: roleTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${completion.profileCompletionPercentage}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: roleTheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (imageMissing)
                _CompletionSuggestion(
                  icon: Icons.add_a_photo_outlined,
                  text: 'Upload profile image',
                  emphasized: true,
                  roleTheme: roleTheme,
                ),
              ...completion.missingFields
                  .where((field) => field != 'Profile image')
                  .take(5)
                  .map(
                    (field) => _CompletionSuggestion(
                      icon: Icons.add_circle_outline_rounded,
                      text: 'Add $field',
                      roleTheme: roleTheme,
                    ),
                  ),
              if (completion.missingFields.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '+${completion.missingFields.length - 6} more required fields',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onCompleteProfile,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Complete Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionSuggestion extends StatelessWidget {
  const _CompletionSuggestion({
    required this.icon,
    required this.text,
    this.emphasized = false,
    required this.roleTheme,
  });

  final IconData icon;
  final String text;
  final bool emphasized;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: emphasized ? roleTheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: emphasized ? roleTheme.primary : colorScheme.onSurface,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.role,
    required this.roleTheme,
    required this.imageUrl,
    required this.fallbackText,
    required this.displayName,
    required this.email,
    required this.completion,
    required this.isVerified,
    required this.onEdit,
  });

  final UserRole role;
  final RoleThemeColors roleTheme;
  final String? imageUrl;
  final String fallbackText;
  final String displayName;
  final String email;
  final int completion;
  final bool isVerified;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final details = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isEmpty ? role.label : displayName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: compact ? TextAlign.center : TextAlign.start,
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: compact ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  _HeroBadge(
                    icon: role.icon,
                    label: role.label,
                    roleTheme: roleTheme,
                  ),
                  _HeroBadge(
                    icon: isVerified
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded,
                    label: isVerified ? 'Verified' : 'Verification pending',
                    roleTheme: roleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: completion.clamp(0, 100) / 100,
                        minHeight: 8,
                        backgroundColor: roleTheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        color: roleTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$completion%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: roleTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Profile completion',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );

          final avatar = Hero(
            tag: 'profile-avatar-${role.name}',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: AvatarWidget(
                imageUrl: imageUrl,
                radius: 54,
                fallbackText: fallbackText,
              ),
            ),
          );

          if (compact) {
            return Column(
              children: [avatar, const SizedBox(height: 24), details],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 32),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.roleTheme,
  });

  final IconData icon;
  final String label;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: roleTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: roleTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: roleTheme.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: roleTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.stats});

  final List<_ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          final cardWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stats
                .map(
                  (stat) => SizedBox(
                    width: cardWidth,
                    child: _StatCard(stat: stat),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: stats.indexed.map((entry) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.$1 == stats.length - 1 ? 0 : 10,
                ),
                child: _StatCard(stat: entry.$2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 126),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(stat.icon, color: stat.color, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _ProfileNavigationItem {
  const _ProfileNavigationItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final Color color;
}

List<_ProfileStat> _statsForRole(
  UserRole role,
  Map<String, dynamic> data,
  int completion,
  int companyApplications,
  int companyJobs,
) {
  return switch (role) {
    UserRole.student => [
      _ProfileStat(
        label: 'Skills',
        value: _count(data['skills']).toString(),
        icon: Icons.auto_awesome_rounded,
        color: AppColors.studentPrimary,
      ),
      _ProfileStat(
        label: 'Courses',
        value: _count(data['enrolledCourses']).toString(),
        icon: Icons.menu_book_rounded,
        color: AppColors.secondary,
      ),
      _ProfileStat(
        label: 'Certificates',
        value: _number(data['completedCourses']).toString(),
        icon: Icons.workspace_premium_rounded,
        color: AppColors.warning,
      ),
    ],
    UserRole.teacher => [
      _ProfileStat(
        label: 'Students',
        value: _number(data['totalStudents']).toString(),
        icon: Icons.groups_rounded,
        color: AppColors.teacherPrimary,
      ),
      _ProfileStat(
        label: 'Courses',
        value: _number(data['coursesCreated']).toString(),
        icon: Icons.video_library_rounded,
        color: AppColors.secondary,
      ),
      _ProfileStat(
        label: 'Rating',
        value: _rating(data['rating']),
        icon: Icons.star_rounded,
        color: AppColors.warning,
      ),
    ],
    UserRole.freelancer => [
      _ProfileStat(
        label: 'Gigs',
        value: _number(data['completedGigs']).toString(),
        icon: Icons.work_history_rounded,
        color: AppColors.freelancerPrimary,
      ),
      _ProfileStat(
        label: 'Earnings',
        value: _money(data['earnings']),
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
      ),
      _ProfileStat(
        label: 'Portfolio',
        value: '${_portfolioStrength(data)}%',
        icon: Icons.pie_chart_rounded,
        color: AppColors.accent,
      ),
    ],
    UserRole.company => [
      _ProfileStat(
        label: 'Jobs Posted',
        value: companyJobs.toString(),
        icon: Icons.business_center_rounded,
        color: AppColors.companyPrimary,
      ),
      _ProfileStat(
        label: 'Applications',
        value: companyApplications.toString(),
        icon: Icons.description_rounded,
        color: AppColors.companySecondary,
      ),
      _ProfileStat(
        label: 'Hiring Score',
        value: '$completion%',
        icon: Icons.analytics_rounded,
        color: AppColors.warning,
      ),
    ],
    _ => const [],
  };
}

List<_ProfileNavigationItem> _navigationItems(RoleThemeColors roleTheme) {
  return [
    _ProfileNavigationItem(
      title: 'Personal Information',
      subtitle: 'Identity, contact, and bio',
      icon: Icons.person_outline_rounded,
      routeName: RouteNames.profilePersonal,
      color: roleTheme.primary,
    ),
    _ProfileNavigationItem(
      title: 'Professional Information',
      subtitle: 'Experience and role details',
      icon: Icons.badge_outlined,
      routeName: RouteNames.profileProfessional,
      color: roleTheme.secondary,
    ),
    _ProfileNavigationItem(
      title: 'Skills & Portfolio',
      subtitle: 'Capabilities and public work',
      icon: Icons.auto_awesome_rounded,
      routeName: RouteNames.profilePortfolio,
      color: AppColors.accent,
    ),
    _ProfileNavigationItem(
      title: 'Security Center',
      subtitle: 'App Lock, PIN, and status',
      icon: Icons.shield_outlined,
      routeName: RouteNames.securitySettings,
      color: AppColors.success,
    ),
    _ProfileNavigationItem(
      title: 'Preferences',
      subtitle: 'Theme, language, and motion',
      icon: Icons.tune_rounded,
      routeName: RouteNames.profilePreferences,
      color: AppColors.warning,
    ),
    _ProfileNavigationItem(
      title: 'Notifications',
      subtitle: 'Alerts and communication',
      icon: Icons.notifications_none_rounded,
      routeName: RouteNames.profileNotifications,
      color: AppColors.info,
    ),
    _ProfileNavigationItem(
      title: 'Account Settings',
      subtitle: 'Privacy, settings, and logout',
      icon: Icons.manage_accounts_outlined,
      routeName: RouteNames.profileAccountSettings,
      color: AppColors.error,
    ),
    _ProfileNavigationItem(
      title: 'Legal & Consent',
      subtitle: 'Policies, terms, and deletion',
      icon: Icons.policy_outlined,
      routeName: RouteNames.privacyPolicy,
      color: AppColors.info,
    ),
  ];
}

int _count(Object? value) {
  if (value is Iterable) return value.length;
  return _number(value);
}

int _number(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _rating(Object? value) {
  final rating = value is num ? value.toDouble() : double.tryParse('$value');
  return rating == null || rating == 0 ? 'New' : rating.toStringAsFixed(1);
}

String _money(Object? value) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value');
  if (amount == null || amount == 0) return '\$0';
  return '\$${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
}

int _portfolioStrength(Map<String, dynamic> data) {
  final fields = [
    data['portfolio'],
    data['linkedin'],
    data['github'],
    data['portfolioLinks'],
  ];
  var completed = 0;
  for (final field in fields) {
    if (field is Iterable && field.isNotEmpty) {
      completed++;
    } else if (field != null && field.toString().trim().isNotEmpty) {
      completed++;
    }
  }
  return ((completed / fields.length) * 100).round();
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
