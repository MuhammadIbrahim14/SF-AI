import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../core/theme/role_theme.dart';
import 'widgets/profile_section_scaffold.dart';

class SkillsPortfolioScreen extends StatelessWidget {
  const SkillsPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionScaffold(
      title: 'Skills & Portfolio',
      subtitle:
          'A verified showcase of your core competencies and public work.',
      builder: (context, profile) {
        final data = profile.details;
        final skills = _skillsForRole(
          profile.role,
          data,
        ).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        final expertise = _expertiseForRole(profile.role, data);
        final strength = _portfolioStrength(data);
        final roleTheme = getRoleTheme(profile.role);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity Header
                _BentoCard(
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: roleTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 40,
                          color: roleTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified Profile Strength: $strength%',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: strength / 100,
                                minHeight: 8,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation(
                                  roleTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _BentoSkills(
                          skills: skills,
                          expertise: expertise,
                          roleTheme: roleTheme,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 7,
                        child: _BentoLinks(data: data, roleTheme: roleTheme),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BentoSkills(
                        skills: skills,
                        expertise: expertise,
                        roleTheme: roleTheme,
                      ),
                      const SizedBox(height: 16),
                      _BentoLinks(data: data, roleTheme: roleTheme),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BentoSkills extends StatelessWidget {
  const _BentoSkills({
    required this.skills,
    required this.expertise,
    required this.roleTheme,
  });

  final List<String> skills;
  final String expertise;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return _BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Core Competencies',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expertise.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: AppColors.success,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (skills.isEmpty)
            Text(
              'No core competencies listed.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: skills
                  .map(
                    (skill) => _SkillBadge(label: skill, roleTheme: roleTheme),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _BentoLinks extends StatelessWidget {
  const _BentoLinks({required this.data, required this.roleTheme});

  final Map<String, dynamic> data;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final website =
        data['portfolioWebsite'] ?? data['portfolio'] ?? data['website'];
    final portfolioLinks = _portfolioLinks(
      data,
    ).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();

    return _BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Public Portfolio Links',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (data['linkedin']?.toString().isNotEmpty == true)
                _LinkBlock(
                  label: 'LinkedIn',
                  value: data['linkedin'],
                  icon: Icons.business_center_rounded,
                  color: const Color(0xFF0077B5),
                ),
              if (data['github']?.toString().isNotEmpty == true)
                _LinkBlock(
                  label: 'GitHub',
                  value: data['github'],
                  icon: Icons.code_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF24292e),
                ),
              if (data['behance']?.toString().isNotEmpty == true)
                _LinkBlock(
                  label: 'Behance',
                  value: data['behance'],
                  icon: Icons.palette_rounded,
                  color: const Color(0xFF1769ff),
                ),
              if (data['dribbble']?.toString().isNotEmpty == true)
                _LinkBlock(
                  label: 'Dribbble',
                  value: data['dribbble'],
                  icon: Icons.sports_basketball_rounded,
                  color: const Color(0xFFea4c89),
                ),
              if (website?.toString().isNotEmpty == true)
                _LinkBlock(
                  label: 'Personal Website',
                  value: website,
                  icon: Icons.language_rounded,
                  color: roleTheme.primary,
                ),
              ...portfolioLinks.map(
                (link) => _LinkBlock(
                  label: 'Project Link',
                  value: link,
                  icon: Icons.link_rounded,
                  color: roleTheme.primary,
                ),
              ),
            ],
          ),
          if (data['linkedin'] == null &&
              data['github'] == null &&
              data['behance'] == null &&
              website == null &&
              portfolioLinks.isEmpty)
            Text(
              'No portfolio links added yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SkillBadge extends StatelessWidget {
  const _SkillBadge({required this.label, required this.roleTheme});

  final String label;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: roleTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LinkBlock extends StatelessWidget {
  const _LinkBlock({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

Iterable<Object?> _skillsForRole(UserRole role, Map<String, dynamic> data) {
  final value = switch (role) {
    UserRole.student => data['skills'],
    UserRole.teacher => data['skillsTaught'] ?? data['specializations'],
    UserRole.freelancer => data['skills'] ?? data['services'],
    UserRole.company => <Object?>[data['industry']],
    _ => const <Object?>[],
  };
  return value is Iterable ? value : <Object?>[value];
}

String _expertiseForRole(UserRole role, Map<String, dynamic> data) {
  final years = data['experienceYears'];
  final experience = years is num ? years.toInt() : int.tryParse('$years') ?? 0;

  return switch (role) {
    UserRole.student => data['educationLevel']?.toString() ?? '',
    UserRole.teacher || UserRole.freelancer when experience >= 7 => 'Expert',
    UserRole.teacher ||
    UserRole.freelancer when experience >= 3 => 'Professional',
    UserRole.teacher || UserRole.freelancer => 'Developing',
    UserRole.company => data['industry']?.toString() ?? '',
    _ => '',
  };
}

int _portfolioStrength(Map<String, dynamic> data) {
  final fields = [
    data['linkedin'],
    data['github'],
    data['behance'],
    data['dribbble'],
    data['portfolioWebsite'] ?? data['portfolio'] ?? data['website'],
  ];
  final completed = fields.where((value) {
    return value != null && value.toString().trim().isNotEmpty;
  }).length;
  return ((completed / fields.length) * 100).round();
}

Iterable<Object?> _portfolioLinks(Map<String, dynamic> data) {
  final links = data['portfolioLinks'];
  return links is Iterable ? links : const [];
}
