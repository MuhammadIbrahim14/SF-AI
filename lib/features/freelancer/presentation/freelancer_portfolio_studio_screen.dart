import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/courses/data/models/certificate_model.dart';
import '../../../features/courses/data/models/skill_score_model.dart';
import '../../../features/courses/data/models/smart_resume_model.dart';
import '../../../features/courses/providers/certificate_provider.dart';
import '../../../features/courses/providers/resume_provider.dart';
import '../../../features/courses/providers/skill_score_provider.dart';
import '../../../models/freelancer_model.dart';
import '../../../models/user_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/freelancer_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/quick_action_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class FreelancerPortfolioStudioScreen extends ConsumerWidget {
  const FreelancerPortfolioStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final freelancerAsync = ref.watch(freelancerProvider);
    final certificatesAsync = ref.watch(studentCertificatesProvider);
    final skillScoresAsync = ref.watch(studentSkillScoresProvider);
    final resumeAsync = ref.watch(smartResumeProvider);

    final user = userAsync.value;
    final freelancer = freelancerAsync.value;
    final certificates = certificatesAsync.value ?? const <CertificateModel>[];
    final skillScores = skillScoresAsync.value ?? const <SkillScoreModel>[];
    final resume = resumeAsync.value;
    final activeCertificates = certificates
        .where((certificate) => certificate.isActive)
        .toList();
    final averageSkillScore = skillScores.isEmpty
        ? 0.0
        : skillScores.fold<double>(0, (sum, score) => sum + score.score) /
              skillScores.length;
    final portfolioLinks = _portfolioLinks(freelancer);
    final socialLinks = _socialLinks(freelancer);
    final strength = _portfolioStrength(
      freelancer: freelancer,
      certificates: activeCertificates,
      skillScores: skillScores,
      resume: resume,
    );
    final recommendations = _recommendations(
      freelancer: freelancer,
      certificates: activeCertificates,
      skillScores: skillScores,
      resume: resume,
      strength: strength,
    );

    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Portfolio Studio',
      subtitle: 'Showcase your verified skills, services, and proof of work.',
      showBackButton: true,
      actions: [
        FilledButton.icon(
          onPressed: () => context.pushNamed(RouteNames.freelancerEditProfile),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit Profile'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (freelancerAsync.isLoading || userAsync.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            if (freelancerAsync.hasError)
              _StudioMessage(
                icon: Icons.error_outline_rounded,
                title: 'Portfolio data unavailable',
                message: freelancerAsync.error.toString(),
              )
            else ...[
              _PortfolioHero(
                user: user,
                freelancer: freelancer,
                strength: strength,
                certificatesCount: activeCertificates.length,
                skillScoresCount: skillScores.length,
                resumeScore: resume?.resumeScore ?? 0,
              ),
              const SizedBox(height: 22),
              ResponsiveGrid(
                minChildWidth: 220,
                children: [
                  MetricCard(
                    title: 'Portfolio Strength',
                    value: '$strength%',
                    icon: Icons.workspace_premium_rounded,
                    color: _scoreColor(strength.toDouble()),
                  ),
                  MetricCard(
                    title: 'Services',
                    value: '${freelancer?.services.length ?? 0}',
                    icon: Icons.design_services_rounded,
                    color: AppColors.freelancerPrimary,
                  ),
                  MetricCard(
                    title: 'Portfolio Links',
                    value: '${portfolioLinks.length + socialLinks.length}',
                    icon: Icons.link_rounded,
                    color: AppColors.freelancerSecondary,
                  ),
                  MetricCard(
                    title: 'Verified Skills',
                    value: skillScores.isEmpty
                        ? 'Pending'
                        : '${averageSkillScore.toStringAsFixed(0)}%',
                    icon: Icons.psychology_rounded,
                    color: _scoreColor(averageSkillScore),
                  ),
                  MetricCard(
                    title: 'Certificates',
                    value: '${activeCertificates.length}',
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                  ),
                  MetricCard(
                    title: 'Resume Readiness',
                    value: resume == null
                        ? 'Not ready'
                        : '${resume.resumeScore.toStringAsFixed(0)}%',
                    icon: Icons.description_rounded,
                    color: _scoreColor(resume?.resumeScore ?? 0),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 980;
                  if (!isDesktop) {
                    return Column(
                      children: [
                        _PortfolioSection(
                          title: 'Services & Skills',
                          icon: Icons.handyman_rounded,
                          child: _ServicesSkillsPanel(freelancer: freelancer),
                        ),
                        const SizedBox(height: 18),
                        _PortfolioSection(
                          title: 'Proof of Work',
                          icon: Icons.fact_check_rounded,
                          child: _ProofPanel(
                            certificates: activeCertificates,
                            skillScores: skillScores,
                            resume: resume,
                            freelancer: freelancer,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PortfolioSection(
                          title: 'Services & Skills',
                          icon: Icons.handyman_rounded,
                          child: _ServicesSkillsPanel(freelancer: freelancer),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _PortfolioSection(
                          title: 'Proof of Work',
                          icon: Icons.fact_check_rounded,
                          child: _ProofPanel(
                            certificates: activeCertificates,
                            skillScores: skillScores,
                            resume: resume,
                            freelancer: freelancer,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              _PortfolioSection(
                title: 'Portfolio Links Showcase',
                icon: Icons.public_rounded,
                child: _LinksShowcase(
                  portfolioLinks: portfolioLinks,
                  socialLinks: socialLinks,
                ),
              ),
              const SizedBox(height: 22),
              _PortfolioSection(
                title: 'Studio Recommendations',
                icon: Icons.auto_awesome_rounded,
                child: _RecommendationPanel(recommendations: recommendations),
              ),
              const SizedBox(height: 22),
              ResponsiveGrid(
                minChildWidth: 250,
                children: [
                  QuickActionCard(
                    title: 'Edit Profile',
                    icon: Icons.manage_accounts_rounded,
                    color: AppColors.freelancerPrimary,
                    onTap: () =>
                        context.pushNamed(RouteNames.freelancerEditProfile),
                  ),
                  QuickActionCard(
                    title: 'My Services',
                    icon: Icons.design_services_rounded,
                    color: AppColors.freelancerSecondary,
                    onTap: () =>
                        context.pushNamed(RouteNames.freelancerServices),
                  ),
                  QuickActionCard(
                    title: 'Portfolio Links',
                    icon: Icons.link_rounded,
                    color: AppColors.freelancerPrimary,
                    onTap: () => context.pushNamed(RouteNames.profilePortfolio),
                  ),
                  QuickActionCard(
                    title: 'Browse Jobs',
                    icon: Icons.search_rounded,
                    color: AppColors.info,
                    onTap: () => context.pushNamed(RouteNames.jobList),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({
    required this.user,
    required this.freelancer,
    required this.strength,
    required this.certificatesCount,
    required this.skillScoresCount,
    required this.resumeScore,
  });

  final UserModel? user;
  final FreelancerModel? freelancer;
  final int strength;
  final int certificatesCount;
  final int skillScoresCount;
  final double resumeScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'SkillForge Freelancer';
    final title = freelancer?.professionalTitle.trim().isNotEmpty == true
        ? freelancer!.professionalTitle.trim()
        : 'Freelance Professional';
    final category = freelancer?.category.trim().isNotEmpty == true
        ? freelancer!.category.trim()
        : 'Service provider';
    final strengthColor = _scoreColor(strength.toDouble());

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: AppColors.freelancerPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;
            final photoUrl = user?.photoUrl?.trim() ?? '';
            final identity = Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.freelancerPrimary.withValues(
                    alpha: 0.15,
                  ),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isNotEmpty
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.freelancerPrimary,
                          size: 34,
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.freelancerPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final trustSignals = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SignalPill(
                  label: '$strength% strength',
                  icon: Icons.workspace_premium_rounded,
                  color: strengthColor,
                ),
                _SignalPill(
                  label: '$certificatesCount certificates',
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                ),
                _SignalPill(
                  label: '$skillScoresCount skill scores',
                  icon: Icons.psychology_rounded,
                  color: AppColors.info,
                ),
                _SignalPill(
                  label: resumeScore <= 0
                      ? 'Resume pending'
                      : '${resumeScore.toStringAsFixed(0)}% resume',
                  icon: Icons.description_rounded,
                  color: _scoreColor(resumeScore),
                ),
              ],
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 18), trustSignals],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 22),
                Flexible(child: trustSignals),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.freelancerPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.freelancerPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ServicesSkillsPanel extends StatelessWidget {
  const _ServicesSkillsPanel({required this.freelancer});

  final FreelancerModel? freelancer;

  @override
  Widget build(BuildContext context) {
    final services = freelancer?.services ?? const <String>[];
    final skills = freelancer?.skills ?? const <String>[];
    final bio = freelancer?.bio.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bio.isNotEmpty) ...[
          Text(
            bio,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _ChipGroup(
          title: 'Services offered',
          emptyMessage: 'Add services in Edit Profile to clarify your offer.',
          icon: Icons.design_services_rounded,
          values: services,
          color: AppColors.freelancerPrimary,
        ),
        const SizedBox(height: 18),
        _ChipGroup(
          title: 'Skills',
          emptyMessage: 'Add skills so companies can match you accurately.',
          icon: Icons.auto_awesome_rounded,
          values: skills,
          color: AppColors.freelancerSecondary,
        ),
      ],
    );
  }
}

class _ProofPanel extends StatelessWidget {
  const _ProofPanel({
    required this.certificates,
    required this.skillScores,
    required this.resume,
    required this.freelancer,
  });

  final List<CertificateModel> certificates;
  final List<SkillScoreModel> skillScores;
  final SmartResumeModel? resume;
  final FreelancerModel? freelancer;

  @override
  Widget build(BuildContext context) {
    final topScores = [...skillScores]
      ..sort((a, b) => b.score.compareTo(a.score));
    final proofItems = [
      _ProofItem(
        title: 'SkillForge Certificates',
        value: certificates.isEmpty ? 'None yet' : '${certificates.length}',
        detail: certificates.isEmpty
            ? 'Earn certificates to strengthen client trust.'
            : certificates.take(2).map((item) => item.courseTitle).join(', '),
        icon: Icons.verified_rounded,
        color: certificates.isEmpty ? AppColors.warning : AppColors.success,
      ),
      _ProofItem(
        title: 'Verified Skill Scores',
        value: skillScores.isEmpty
            ? 'Pending'
            : '${topScores.first.score.toStringAsFixed(0)}%',
        detail: skillScores.isEmpty
            ? 'Complete assessments to verify capability.'
            : '${topScores.first.skillName} · ${topScores.first.level}',
        icon: Icons.psychology_rounded,
        color: skillScores.isEmpty ? AppColors.warning : AppColors.info,
      ),
      _ProofItem(
        title: 'Smart Resume',
        value: resume == null
            ? 'Not ready'
            : '${resume!.resumeScore.toStringAsFixed(0)}%',
        detail: resume == null
            ? 'Generate a smart resume to add verified proof.'
            : resume!.hasVerifiedData
            ? 'Verified data included'
            : 'Resume exists, add more verified data.',
        icon: Icons.description_rounded,
        color: resume == null
            ? AppColors.warning
            : _scoreColor(resume!.resumeScore),
      ),
      _ProofItem(
        title: 'Marketplace Signals',
        value: '${freelancer?.completedGigs ?? 0} gigs',
        detail: (freelancer?.rating ?? 0) > 0
            ? '${freelancer!.rating.toStringAsFixed(1)} rating'
            : 'Ratings will appear when real history exists.',
        icon: Icons.star_rounded,
        color: (freelancer?.completedGigs ?? 0) > 0
            ? AppColors.success
            : AppColors.freelancerPrimary,
      ),
    ];

    return ResponsiveGrid(
      minChildWidth: 220,
      children: proofItems.map(_ProofTile.new).toList(),
    );
  }
}

class _LinksShowcase extends StatelessWidget {
  const _LinksShowcase({
    required this.portfolioLinks,
    required this.socialLinks,
  });

  final List<_PortfolioLink> portfolioLinks;
  final List<_PortfolioLink> socialLinks;

  @override
  Widget build(BuildContext context) {
    final links = [...portfolioLinks, ...socialLinks];
    if (links.isEmpty) {
      return DashboardEmptyState(
        icon: Icons.link_off_rounded,
        title: 'No portfolio links yet',
        message:
            'Add GitHub, Behance, Dribbble, website, or live project links from Edit Profile.',
        actionLabel: 'Edit Profile',
        onAction: () => context.pushNamed(RouteNames.freelancerEditProfile),
      );
    }

    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 3,
      wideColumns: 4,
      minChildWidth: 220,
      spacing: 16,
      runSpacing: 16,
      children: links
          .map(
            (link) => _LinkTile(
              link: link,
              onCopy: () => _copyLink(context, link.url),
            ),
          )
          .toList(),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.recommendations});

  final List<_StudioRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < recommendations.length; index++) ...[
          _RecommendationTile(recommendation: recommendations[index]),
          if (index != recommendations.length - 1)
            Divider(
              height: 22,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.emptyMessage,
    required this.icon,
    required this.values,
    required this.color,
  });

  final String title;
  final String emptyMessage;
  final IconData icon;
  final List<String> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (values.isEmpty)
          Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (value) => Chip(
                    label: Text(value),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: color.withValues(alpha: 0.10),
                    side: BorderSide(color: color.withValues(alpha: 0.16)),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ProofTile extends StatelessWidget {
  const _ProofTile(this.item);

  final _ProofItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 24),
          const SizedBox(height: 14),
          Text(
            item.value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: item.color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
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

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link, required this.onCopy});

  final _PortfolioLink link;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: link.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(link.icon, color: link.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                link.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Copy link',
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: link.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(link.icon, color: link.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            link.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.recommendation});

  final _StudioRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: recommendation.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            recommendation.icon,
            color: recommendation.color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                recommendation.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioMessage extends StatelessWidget {
  const _StudioMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: DashboardEmptyState(icon: icon, title: title, message: message),
    );
  }
}

class _ProofItem {
  const _ProofItem({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _PortfolioLink {
  const _PortfolioLink({
    required this.label,
    required this.url,
    required this.icon,
    required this.color,
  });

  final String label;
  final String url;
  final IconData icon;
  final Color color;
}

class _StudioRecommendation {
  const _StudioRecommendation({
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

List<_PortfolioLink> _portfolioLinks(FreelancerModel? freelancer) {
  if (freelancer == null) return const [];
  final rawLinks = <String>{freelancer.portfolio, ...freelancer.portfolioLinks}
    ..removeWhere((link) => link.trim().isEmpty);
  return rawLinks
      .map(
        (url) => _PortfolioLink(
          label: _linkLabel(url),
          url: url.trim(),
          icon: Icons.workspaces_rounded,
          color: AppColors.freelancerPrimary,
        ),
      )
      .toList();
}

List<_PortfolioLink> _socialLinks(FreelancerModel? freelancer) {
  if (freelancer == null) return const [];
  final entries = <_PortfolioLink>[
    if (freelancer.github.trim().isNotEmpty)
      _PortfolioLink(
        label: 'GitHub',
        url: freelancer.github.trim(),
        icon: Icons.code_rounded,
        color: AppColors.info,
      ),
    if (freelancer.linkedin.trim().isNotEmpty)
      _PortfolioLink(
        label: 'LinkedIn',
        url: freelancer.linkedin.trim(),
        icon: Icons.business_center_rounded,
        color: AppColors.freelancerSecondary,
      ),
    if (freelancer.behance.trim().isNotEmpty)
      _PortfolioLink(
        label: 'Behance',
        url: freelancer.behance.trim(),
        icon: Icons.palette_rounded,
        color: AppColors.freelancerPrimary,
      ),
    if (freelancer.dribbble.trim().isNotEmpty)
      _PortfolioLink(
        label: 'Dribbble',
        url: freelancer.dribbble.trim(),
        icon: Icons.bubble_chart_rounded,
        color: AppColors.warning,
      ),
    if (freelancer.website.trim().isNotEmpty)
      _PortfolioLink(
        label: 'Website',
        url: freelancer.website.trim(),
        icon: Icons.public_rounded,
        color: AppColors.success,
      ),
  ];
  return entries;
}

String _linkLabel(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri?.host.isNotEmpty == true) return uri!.host;
  return 'Portfolio Link';
}

int _portfolioStrength({
  required FreelancerModel? freelancer,
  required List<CertificateModel> certificates,
  required List<SkillScoreModel> skillScores,
  required SmartResumeModel? resume,
}) {
  if (freelancer == null) return 0;
  var score = 0;
  if (freelancer.professionalTitle.trim().isNotEmpty) score += 8;
  if (freelancer.bio.trim().isNotEmpty) score += 10;
  if (freelancer.category.trim().isNotEmpty) score += 6;
  if (freelancer.services.isNotEmpty) score += 8;
  if (freelancer.services.length >= 3) score += 7;
  if (freelancer.skills.isNotEmpty) score += 8;
  if (freelancer.skills.length >= 5) score += 7;
  if (freelancer.hourlyRate > 0) score += 7;
  if (freelancer.experienceYears > 0) score += 7;
  final links =
      _portfolioLinks(freelancer).length + _socialLinks(freelancer).length;
  if (links > 0) score += 8;
  if (links >= 3) score += 6;
  if (certificates.isNotEmpty) score += 8;
  if (skillScores.isNotEmpty) score += 6;
  if ((resume?.resumeScore ?? 0) > 0) score += 4;
  return score.clamp(0, 100);
}

List<_StudioRecommendation> _recommendations({
  required FreelancerModel? freelancer,
  required List<CertificateModel> certificates,
  required List<SkillScoreModel> skillScores,
  required SmartResumeModel? resume,
  required int strength,
}) {
  final items = <_StudioRecommendation>[];
  if (freelancer == null) {
    return const [
      _StudioRecommendation(
        title: 'Create your freelancer profile',
        message:
            'Complete your freelancer profile before showcasing services publicly.',
        icon: Icons.person_add_alt_rounded,
        color: AppColors.warning,
      ),
    ];
  }
  if (freelancer.services.length < 2) {
    items.add(
      const _StudioRecommendation(
        title: 'Clarify services',
        message:
            'Add at least two services so clients understand exactly what you can deliver.',
        icon: Icons.design_services_rounded,
        color: AppColors.freelancerPrimary,
      ),
    );
  }
  if (freelancer.skills.length < 5) {
    items.add(
      const _StudioRecommendation(
        title: 'Add stronger skill signals',
        message:
            'More precise skills improve job matching and make your profile easier to trust.',
        icon: Icons.auto_awesome_rounded,
        color: AppColors.freelancerSecondary,
      ),
    );
  }
  if (_portfolioLinks(freelancer).length + _socialLinks(freelancer).length <
      2) {
    items.add(
      const _StudioRecommendation(
        title: 'Add proof links',
        message:
            'Add GitHub, Behance, Dribbble, portfolio, or website links to prove your work visually.',
        icon: Icons.link_rounded,
        color: AppColors.info,
      ),
    );
  }
  if (certificates.isEmpty) {
    items.add(
      const _StudioRecommendation(
        title: 'Earn SkillForge certificates',
        message:
            'Certificates help recruiters trust verified course and assessment performance.',
        icon: Icons.verified_outlined,
        color: AppColors.warning,
      ),
    );
  }
  if (skillScores.isEmpty) {
    items.add(
      const _StudioRecommendation(
        title: 'Verify skills with assessments',
        message:
            'Skill scores turn your profile from a claim into measured proof.',
        icon: Icons.psychology_alt_rounded,
        color: AppColors.warning,
      ),
    );
  }
  if ((resume?.resumeScore ?? 0) <= 0) {
    items.add(
      const _StudioRecommendation(
        title: 'Prepare your Smart Resume',
        message:
            'Resume readiness gives companies a clean summary of your verified capability.',
        icon: Icons.description_outlined,
        color: AppColors.freelancerPrimary,
      ),
    );
  }
  if (strength >= 80) {
    items.add(
      const _StudioRecommendation(
        title: 'Portfolio is client-ready',
        message:
            'Your profile has strong proof signals. Focus on applying only to jobs that match your skills.',
        icon: Icons.rocket_launch_rounded,
        color: AppColors.success,
      ),
    );
  }
  return items.take(5).toList();
}

Future<void> _copyLink(BuildContext context, String link) async {
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Portfolio link copied')));
}

Color _scoreColor(double score) {
  if (score >= 75) return AppColors.success;
  if (score >= 45) return AppColors.warning;
  return AppColors.freelancerPrimary;
}
