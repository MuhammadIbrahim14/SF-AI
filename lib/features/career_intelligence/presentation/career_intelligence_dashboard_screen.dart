import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../models/career_intelligence_models.dart';
import '../providers/career_intelligence_providers.dart';

class CareerIntelligenceDashboardScreen extends ConsumerWidget {
  const CareerIntelligenceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final role =
        UserRole.fromString(user?.primaryRole) ?? UserRole.student;
    final reportAsync = ref.watch(careerIntelligenceReportProvider);
    final busy = ref.watch(careerIntelligenceActionProvider).isLoading;
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: role,
      title: 'AI Career Intelligence',
      subtitle: _subtitleFor(role),
      showBackButton: true,
      scrollable: false,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(_dashboardRoute(role)),
      actions: [
        IconButton(
          tooltip: 'Refresh AI insights',
          onPressed: busy
              ? null
              : () async {
                  await ref
                      .read(careerIntelligenceActionProvider.notifier)
                      .refresh();
                },
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      child: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load insights: $e'),
          ),
        ),
        data: (report) {
          if (report == null) {
            return const Center(child: Text('Sign in to view career insights.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ReadinessHero(report: report),
              if (report.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Banner(
                  color: AppColors.warning,
                  text: report.errorMessage,
                ),
              ],
              const SizedBox(height: 16),
              _SectionCard(
                title: 'AI Summary',
                child: Text(report.summary),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Key Insights',
                child: _BulletList(report.insights),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Recommendations',
                child: _BulletList(report.recommendations),
              ),
              const SizedBox(height: 12),
              _SkillGapCard(gap: report.skillGap),
              const SizedBox(height: 12),
              _RoadmapCard(plan: report.roadmap),
              const SizedBox(height: 12),
              _ReviewCard(title: 'Resume Review', review: report.resumeReview),
              const SizedBox(height: 12),
              _ReviewCard(
                title: 'Portfolio Review',
                review: report.portfolioReview,
              ),
              const SizedBox(height: 12),
              _MarketCard(insights: report.marketInsights),
              if (role == UserRole.freelancer) ...[
                const SizedBox(height: 12),
                _RecommendedServicesCard(report: report),
              ],
              const SizedBox(height: 12),
              _AchievementsCard(badges: report.achievements),
              const SizedBox(height: 12),
              _FocusedActions(
                role: role,
                busy: busy,
                onRun: (task) async {
                  final result = await ref
                      .read(careerIntelligenceActionProvider.notifier)
                      .runTask(task);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result == null
                            ? 'Unable to run focused analysis.'
                            : 'Focused analysis updated.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                report.fromCache
                    ? 'Cached · updated ${DateFormat.yMMMd().add_jm().format(report.updatedAt)}'
                    : 'Live · ${DateFormat.yMMMd().add_jm().format(report.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitleFor(UserRole role) {
    return switch (role) {
      UserRole.freelancer =>
        'Pricing, portfolio, market demand, and service growth.',
      UserRole.teacher =>
        'Course health, weak topics, and content recommendations.',
      UserRole.company =>
        'Hiring analytics, skill trends, and recruitment bottlenecks.',
      _ =>
        'Readiness, skill gaps, roadmaps, resume & portfolio guidance.',
    };
  }

  String _dashboardRoute(UserRole role) {
    return switch (role) {
      UserRole.freelancer => RouteNames.freelancerDashboard,
      UserRole.teacher => RouteNames.teacherDashboard,
      UserRole.company => RouteNames.companyDashboard,
      _ => RouteNames.studentDashboard,
    };
  }
}

class _ReadinessHero extends StatelessWidget {
  const _ReadinessHero({required this.report});
  final CareerIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.info.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (report.readinessScore / 100).clamp(0, 1),
                  strokeWidth: 8,
                  color: AppColors.primary,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
                Center(
                  child: Text(
                    '${report.readinessScore.toStringAsFixed(0)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${report.role} · AI ${report.aiAvailable ? 'online' : 'offline baseline'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (report.metrics['estimatedSalaryRange'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Est. salary range: ${report.metrics['estimatedSalaryRange']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                if (report.metrics['recommendedCareerPath'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Path: ${report.metrics['recommendedCareerPath']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillGapCard extends StatelessWidget {
  const _SkillGapCard({required this.gap});
  final CareerSkillGap gap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Skill Gap Analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress ${gap.progressPercent.toStringAsFixed(0)}% · '
            '~${gap.estimatedLearningHours}h estimated',
          ),
          const SizedBox(height: 8),
          Text('Current', style: Theme.of(context).textTheme.titleSmall),
          _ChipWrap(gap.currentSkills),
          const SizedBox(height: 8),
          Text('Missing', style: Theme.of(context).textTheme.titleSmall),
          _ChipWrap(gap.missingSkills),
          const SizedBox(height: 8),
          Text('Learning path', style: Theme.of(context).textTheme.titleSmall),
          _BulletList(gap.suggestedPath),
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.plan});
  final CareerRoadmapPlan plan;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '30 / 60 / 90 Day Roadmap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.focus.isNotEmpty) Text('Focus: ${plan.focus}'),
          const SizedBox(height: 8),
          Text('30 days', style: Theme.of(context).textTheme.titleSmall),
          _BulletList(plan.days30),
          Text('60 days', style: Theme.of(context).textTheme.titleSmall),
          _BulletList(plan.days60),
          Text('90 days', style: Theme.of(context).textTheme.titleSmall),
          _BulletList(plan.days90),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.review});
  final String title;
  final CareerReviewResult review;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '$title · ${review.score.toStringAsFixed(0)}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(review.summary.isEmpty ? 'No review yet.' : review.summary),
          if (review.atsReady) ...[
            const SizedBox(height: 6),
            const Text('ATS readiness: strong'),
          ],
          const SizedBox(height: 8),
          Text('Strengths', style: Theme.of(context).textTheme.titleSmall),
          _BulletList(review.strengths),
          Text('Improvements', style: Theme.of(context).textTheme.titleSmall),
          _BulletList(review.improvements),
          if (review.missingSections.isNotEmpty) ...[
            Text(
              'Missing sections',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _BulletList(review.missingSections),
          ],
        ],
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.insights});
  final CareerMarketInsights insights;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Market Insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending', style: Theme.of(context).textTheme.titleSmall),
          _ChipWrap(insights.trendingSkills),
          const SizedBox(height: 8),
          Text('Most demanded', style: Theme.of(context).textTheme.titleSmall),
          _ChipWrap(insights.mostDemanded),
          const SizedBox(height: 8),
          Text(
            'Highest paying signals',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _ChipWrap(insights.highestPaying),
          const SizedBox(height: 8),
          Text(
            'Recommended certifications',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _BulletList(insights.recommendedCertifications),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.badges});
  final List<CareerAchievementBadge> badges;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Achievements',
      child: badges.isEmpty
          ? const Text('Keep learning — badges unlock from real progress.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges
                  .map(
                    (b) => Chip(
                      avatar: const Icon(Icons.workspace_premium_rounded, size: 16),
                      label: Text(b.title),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _FocusedActions extends StatelessWidget {
  const _FocusedActions({
    required this.role,
    required this.busy,
    required this.onRun,
  });

  final UserRole role;
  final bool busy;
  final Future<void> Function(String taskType) onRun;

  @override
  Widget build(BuildContext context) {
    final tasks = <(String, String)>[
      ('Skill Gap', CareerIntelligenceTaskType.skillGap),
      ('Learning Roadmap', CareerIntelligenceTaskType.learningRoadmap),
      ('Resume Review', CareerIntelligenceTaskType.resumeReview),
      ('Portfolio Review', CareerIntelligenceTaskType.portfolioReview),
      ('Market Insights', CareerIntelligenceTaskType.marketInsights),
    ];
    return _SectionCard(
      title: 'Focused AI Actions',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tasks
            .map(
              (t) => OutlinedButton(
                onPressed: busy ? null : () => onRun(t.$2),
                child: Text(t.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No items yet.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('None yet.');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((e) => Chip(label: Text(e))).toList(),
    );
  }
}

class _RecommendedServicesCard extends StatelessWidget {
  const _RecommendedServicesCard({required this.report});
  final CareerIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final raw = report.metrics['recommendedServices'];
    final items = <String>[];
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is Map) {
          final title = (item['title'] ?? item['name'] ?? '').toString().trim();
          if (title.isNotEmpty) items.add(title);
        } else if (item != null && item.toString().trim().isNotEmpty) {
          items.add(item.toString().trim());
        }
      }
    }
    if (items.isEmpty && report.recommendations.isNotEmpty) {
      items.addAll(
        report.recommendations
            .where((r) => r.toLowerCase().contains('service'))
            .take(3),
      );
    }

    return _SectionCard(
      title: 'Recommended Services',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            const Text(
              'No service recommendations yet. Refresh Career Intelligence after updating your skills.',
            )
          else
            for (final item in items.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item)),
                    FilledButton.tonal(
                      onPressed: () {
                        MarketplaceAiPendingApply.careerListingHint = item;
                        context.pushNamed(
                          RouteNames.freelancerServiceCreate,
                          extra: {
                            'aiServiceListing': {
                              'title': item,
                              'shortDescription':
                                  'Career Intelligence suggested this listing. Review and complete with AI or manually.',
                              'fullDescription': '',
                              'assumptions': [
                                'Deep-linked from Career Intelligence recommendedServices.',
                              ],
                              'manualReviewNotes': [
                                'Apply/create with AI, then Save Draft or Publish yourself.',
                              ],
                            },
                          },
                        );
                      },
                      child: const Text('Create listing'),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              context.pushNamed(
                RouteNames.freelancerAiAssistant,
                queryParameters: {
                  'task': 'service',
                },
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Open Listing Builder AI'),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text),
    );
  }
}
