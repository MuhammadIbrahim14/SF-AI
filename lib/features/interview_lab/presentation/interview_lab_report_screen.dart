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

class InterviewLabReportScreen extends ConsumerWidget {
  const InterviewLabReportScreen({required this.sessionId, super.key});

  final String sessionId;

  UserRole _role(WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user?.primaryRole == UserRole.freelancer) return UserRole.freelancer;
    return UserRole.student;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(interviewLabSessionProvider(sessionId));
    final reportAsync =
        ref.watch(interviewLabReportForSessionProvider(sessionId));
    final badgesAsync = ref.watch(myInterviewLabBadgesProvider);

    return RoleFixedHeaderPage(
      role: _role(ref),
      title: 'Interview report',
      subtitle: 'AI senior interviewer debrief — private practice only.',
      child: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e'),
        ),
        data: (session) {
          return reportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'AI evaluation unavailable.\n$e',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        context.goNamed(RouteNames.interviewLabHome),
                    child: const Text('Back to Lab'),
                  ),
                ],
              ),
            ),
            data: (report) {
              if (session == null || report == null) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Report not available. If evaluation failed, retry finishing the session when AI is online.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            context.goNamed(RouteNames.interviewLabHome),
                        child: const Text('Back to Lab'),
                      ),
                    ],
                  ),
                );
              }

              final level = report.interviewLevel.isNotEmpty
                  ? report.interviewLevel
                  : InterviewLabInterviewLevel.fromScore(report.overallRating);
              final sessionBadges = badgesAsync.asData?.value
                      .where((b) => b.sessionId == sessionId)
                      .toList() ??
                  const <InterviewLabBadgeModel>[];

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: AppColors.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Overall Rating',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.overallRating.toStringAsFixed(0),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text('Interview level · $level'),
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.15),
                          ),
                          if (report.industryReadiness.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Industry readiness: ${report.industryReadiness}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            InterviewLabRoleTrack.displayLabel(session.roleTrack),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final entry in [
                          ('Technical', report.technicalScore),
                          ('Communication', report.communicationScore),
                          ('Confidence', report.confidenceScore),
                          ('Problem Solving', report.problemSolvingScore),
                          ('Architecture', report.architectureScore),
                          ('Code Quality', report.codeQualityScore),
                          (
                            'Professional Readiness',
                            report.professionalReadinessScore
                          ),
                          ('Professionalism', report.professionalismScore),
                        ])
                          SizedBox(
                            width: 150,
                            child: InterviewLabScoreChip(
                              label: entry.$1,
                              score: entry.$2,
                              explanation:
                                  report.scoreExplanations[entry.$1] ??
                                      report.scoreExplanations[
                                          entry.$1.toLowerCase()],
                            ),
                          ),
                      ],
                    ),
                    if (sessionBadges.isNotEmpty ||
                        report.badgesAwarded.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _Section(
                        title: 'Badges earned',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final b in sessionBadges)
                              Chip(
                                avatar: const Icon(Icons.military_tech_outlined),
                                label: Text(b.title),
                              ),
                            if (sessionBadges.isEmpty)
                              for (final key in report.badgesAwarded)
                                Chip(label: Text(key)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _Section(title: 'Interview summary', child: Text(report.summary)),
                    _Section(
                      title: 'Strengths',
                      child: _bullets(report.strengths),
                    ),
                    _Section(
                      title: 'Weaknesses',
                      child: _bullets(report.weakSkills),
                    ),
                    _Section(
                      title: 'Skills demonstrated',
                      child: _bullets(report.skillsDemonstrated),
                    ),
                    _Section(
                      title: 'Skills missing',
                      child: _bullets(report.skillsMissing),
                    ),
                    _Section(
                      title: 'Mistakes',
                      child: _bullets(report.mistakes),
                    ),
                    _Section(
                      title: 'Recommendations',
                      child: _bullets(report.recommendations),
                    ),
                    _Section(
                      title: 'Suggested learning path',
                      child: _bullets(report.learningPath),
                    ),
                    _Section(
                      title: 'Recommended SkillForge courses',
                      child: _bullets(report.recommendedCourses),
                    ),
                    _Section(
                      title: 'Recommended projects',
                      child: _bullets(report.recommendedProjects),
                    ),
                    _Section(
                      title: 'Recommended certifications',
                      child: _bullets(report.recommendedCertifications),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.goNamed(RouteNames.interviewLabHome),
                      child: const Text('Back to Interview Lab'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          context.pushNamed(RouteNames.interviewLabStart),
                      child: const Text('Practice again'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _bullets(List<String> items) {
    if (items.isEmpty) {
      return const Text('—');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
