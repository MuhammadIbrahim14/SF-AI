import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../models/interview_lab_models.dart';
import '../providers/interview_lab_providers.dart';
import 'widgets/interview_lab_widgets.dart';

class InterviewLabHomeScreen extends ConsumerWidget {
  const InterviewLabHomeScreen({super.key});

  UserRole _role(WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user?.roles.contains(UserRole.freelancer) == true &&
        user?.primaryRole == UserRole.freelancer) {
      return UserRole.freelancer;
    }
    return UserRole.student;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final role = _role(ref);
    final analyticsAsync = ref.watch(interviewLabAnalyticsProvider);
    final sessionsAsync = ref.watch(myInterviewLabSessionsProvider);

    return RoleFixedHeaderPage(
      role: role,
      title: 'AI Interview Lab',
      subtitle: 'Practice interviews with AI — not a real hiring interview.',
      scrollable: true,
      child: analyticsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Unable to load lab analytics: $e'),
        ),
        data: (analytics) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Interview Lab',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sharpen technical, communication, and problem-solving skills '
                        'with AI-generated practice interviews. Results stay private to you.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      if (analytics.resumable != null) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.pushNamed(
                            RouteNames.interviewLabSession,
                            pathParameters: {
                              'sessionId': analytics.resumable!.sessionId,
                            },
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            'Resume ${InterviewLabRoleTrack.displayLabel(analytics.resumable!.roleTrack)}',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                InterviewLabActionCard(
                  primary: true,
                  title: 'Practice Interview',
                  subtitle: 'Choose a role, difficulty, and start a timed AI session.',
                  icon: Icons.mic_none_rounded,
                  onTap: () => context.pushNamed(RouteNames.interviewLabStart),
                ),
                const SizedBox(height: 12),
                InterviewLabActionCard(
                  title: 'Interview History',
                  subtitle: 'Browse past sessions, reports, and scores.',
                  icon: Icons.history_rounded,
                  onTap: () => context.pushNamed(RouteNames.interviewLabHistory),
                ),
                const SizedBox(height: 24),
                Text(
                  'AI Performance',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 720;
                    final cards = [
                      InterviewLabStatCard(
                        label: 'Latest Score',
                        value: analytics.latestScore <= 0
                            ? '—'
                            : analytics.latestScore.toStringAsFixed(0),
                        icon: Icons.stars_rounded,
                      ),
                      InterviewLabStatCard(
                        label: 'Average Score',
                        value: analytics.averageScore <= 0
                            ? '—'
                            : analytics.averageScore.toStringAsFixed(0),
                        icon: Icons.insights_rounded,
                      ),
                      InterviewLabStatCard(
                        label: 'Completed',
                        value: '${analytics.completedCount}',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      InterviewLabStatCard(
                        label: 'Highest Score',
                        value: analytics.highestScore <= 0
                            ? '—'
                            : analytics.highestScore.toStringAsFixed(0),
                        icon: Icons.emoji_events_outlined,
                      ),
                    ];
                    if (wide) {
                      return SizedBox(
                        height: 150,
                        child: Row(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        ),
                      );
                    }
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: cards,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Interview Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _InsightPanel(
                  title: 'Most practiced',
                  body: InterviewLabRoleTrack.displayLabel(
                    analytics.mostPracticedTrack,
                  ),
                ),
                const SizedBox(height: 10),
                _InsightPanel(
                  title: 'Weak skills',
                  body: analytics.weakSkills.isEmpty
                      ? 'Complete an interview to unlock skill insights.'
                      : analytics.weakSkills.join(' · '),
                ),
                const SizedBox(height: 10),
                _InsightPanel(
                  title: 'Recommended courses',
                  body: analytics.recommendedCourses.isEmpty
                      ? 'Practice a session to get course suggestions.'
                      : analytics.recommendedCourses.join('\n'),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final progress =
                        ref.watch(myInterviewLabProgressProvider).asData?.value;
                    final badges =
                        ref.watch(myInterviewLabBadgesProvider).asData?.value ??
                            const [];
                    if (progress == null && badges.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (progress != null && progress.insights.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _InsightPanel(
                            title: 'Long-term progress',
                            body: progress.insights.join('\n'),
                          ),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _InsightPanel(
                            title: 'Badges',
                            body: badges
                                .take(6)
                                .map((b) => '• ${b.title}')
                                .join('\n'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (analytics.scoreTrend.length >= 2) ...[
                  const SizedBox(height: 16),
                  _TrendBar(scores: analytics.scoreTrend),
                ],
                const SizedBox(height: 24),
                Text(
                  'Previous Interviews',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                sessionsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (sessions) {
                    final recent = sessions.take(5).toList();
                    if (recent.isEmpty) {
                      return _EmptyHint(
                        message:
                            'No practice interviews yet. Start your first session.',
                        actionLabel: 'Start practice',
                        onAction: () =>
                            context.pushNamed(RouteNames.interviewLabStart),
                      );
                    }
                    return Column(
                      children: [
                        for (final s in recent)
                          _SessionTile(
                            session: s,
                            onOpen: () {
                              if (s.isCompleted && (s.reportId ?? '').isNotEmpty) {
                                context.pushNamed(
                                  RouteNames.interviewLabReport,
                                  pathParameters: {'sessionId': s.sessionId},
                                );
                              } else {
                                context.pushNamed(
                                  RouteNames.interviewLabSession,
                                  pathParameters: {'sessionId': s.sessionId},
                                );
                              }
                            },
                          ),
                        TextButton(
                          onPressed: () =>
                              context.pushNamed(RouteNames.interviewLabHistory),
                          child: const Text('View all history'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.scores});

  final List<double> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = scores.fold<double>(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Improvement trend',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final s in scores) ...[
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 12 + (s / max) * 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onOpen});

  final InterviewLabSessionModel session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Icon(Icons.record_voice_over_outlined, color: AppColors.primary),
        ),
        title: Text(
          InterviewLabRoleTrack.displayLabel(session.roleTrack),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${interviewLabStatusLabel(session.status)} · ${session.difficulty}'
          '${session.isCompleted ? ' · Score ${session.overallScore.toStringAsFixed(0)}' : ''}',
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
