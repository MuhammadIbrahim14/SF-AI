import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/application_model.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/application_provider.dart';
import '../../../../providers/company_permission_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../hiring_lifecycle/presentation/widgets/hiring_timeline_panel.dart';
import '../../hiring_lifecycle/providers/hiring_lifecycle_providers.dart';
import '../models/company_candidate_intelligence_models.dart';
import '../providers/company_candidate_intelligence_providers.dart';

class CompanyCandidateIntelligenceScreen extends ConsumerStatefulWidget {
  const CompanyCandidateIntelligenceScreen({
    required this.applicationId,
    super.key,
  });

  final String applicationId;

  @override
  ConsumerState<CompanyCandidateIntelligenceScreen> createState() =>
      _CompanyCandidateIntelligenceScreenState();
}

class _CompanyCandidateIntelligenceScreenState
    extends ConsumerState<CompanyCandidateIntelligenceScreen> {
  bool _enriching = false;
  String? _notesDraft;
  String? _error;

  Future<void> _runAi(
    CompanyCandidateIntelligenceProfile profile,
  ) async {
    setState(() {
      _enriching = true;
      _error = null;
    });
    final result = await ref
        .read(companyCandidateIntelligenceActionProvider.notifier)
        .enrich(widget.applicationId);
    if (!mounted) return;
    setState(() {
      _enriching = false;
      if (result == null) {
        _error = ref
                .read(companyCandidateIntelligenceActionProvider.notifier)
                .lastErrorMessage ??
            'AI evaluation unavailable. Ensure the AI Gateway is running.';
      }
    });
  }

  Future<void> _saveNotes(String applicationId, String notes) async {
    final permission = await ref.read(companyPermissionProvider.future);
    permission.ensureCanManageHiring();
    await ref.read(applicationActionProvider.notifier).updateHiringData(
          applicationId: applicationId,
          companyNotes: notes,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private HR notes saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync =
        ref.watch(companyCandidateIntelligenceProvider(widget.applicationId));
    final permission = ref.watch(companyPermissionProvider).value;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Candidate Intelligence',
      subtitle: 'ATS profile · Interview Lab evidence · advisory AI only',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.hiringPipeline),
      child: permission?.canViewApplicants != true
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Company verification required to view candidates.'),
            )
          : profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$e'),
              ),
              data: (profile) {
                _notesDraft ??= profile.application.companyNotes;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(profile: profile),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _enriching
                                ? null
                                : () => _runAi(profile),
                            icon: _enriching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(
                              _enriching
                                  ? 'Generating AI insights…'
                                  : 'Generate AI Summary & Match',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.pushNamed(
                              RouteNames.companyCandidateCompare,
                              queryParameters: {
                                'jobId': profile.job.id,
                                'ids': widget.applicationId,
                              },
                            ),
                            icon: const Icon(Icons.compare_arrows),
                            label: const Text('Compare'),
                          ),
                          if (profile.labSessions.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => context.pushNamed(
                                RouteNames.companyInterviewLabReport,
                                pathParameters: {
                                  'sessionId':
                                      profile.labSessions.first.sessionId,
                                },
                                queryParameters: {
                                  'applicationId': widget.applicationId,
                                },
                              ),
                              icon: const Icon(Icons.record_voice_over_outlined),
                              label: const Text('Latest Interview Report'),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _Section(
                        title: 'AI Summary',
                        child: Text(
                          profile.aiSummary.isEmpty
                              ? 'Generate AI insights to produce a professional summary. Never hardcoded.'
                              : profile.aiSummary,
                        ),
                      ),
                      _Section(
                        title: 'AI Recommendation',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.aiRecommendation.isEmpty
                                  ? 'Pending AI recommendation'
                                  : profile.aiRecommendation,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (profile.aiRecommendationReason.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(profile.aiRecommendationReason),
                            ],
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Job match score',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${profile.jobMatchPercent.toStringAsFixed(0)}% · ${profile.job.title}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.companyPrimary,
                              ),
                            ),
                            if (profile.jobMatchReasoning.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(profile.jobMatchReasoning),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Matching: ${profile.matchingSkills.isEmpty ? '—' : profile.matchingSkills.join(', ')}',
                            ),
                            Text(
                              'Missing: ${profile.missingSkills.isEmpty ? '—' : profile.missingSkills.join(', ')}',
                            ),
                          ],
                        ),
                      ),
                      _ScoreGrid(profile: profile),
                      _Section(
                        title: 'Profile & portfolio',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Completion: ${profile.profileCompletion}%'),
                            Text(
                              profile.portfolioHeadline.isEmpty
                                  ? 'Headline: —'
                                  : profile.portfolioHeadline,
                            ),
                            Text(
                              'Skills: ${profile.skills.isEmpty ? '—' : profile.skills.join(', ')}',
                            ),
                            Text(
                              'Portfolio: ${profile.portfolioLinks.isEmpty ? '—' : profile.portfolioLinks.join('\n')}',
                            ),
                            Text('Bio: ${profile.candidate.bio.isEmpty ? '—' : profile.candidate.bio}'),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Certificates',
                        child: profile.certificates.isEmpty
                            ? const Text('No certificates yet.')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final c in profile.certificates)
                                    Text('• ${c.courseTitle}'),
                                ],
                              ),
                      ),
                      _Section(
                        title: 'Completed courses',
                        child: profile.completedCourseTitles.isEmpty
                            ? const Text('No completed courses listed.')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final t in profile.completedCourseTitles)
                                    Text('• $t'),
                                ],
                              ),
                      ),
                      _Section(
                        title: 'Skill badges (Interview Lab)',
                        child: profile.badges.isEmpty
                            ? const Text('No Interview Lab badges yet.')
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final b in profile.badges)
                                    Chip(label: Text(b.title)),
                                ],
                              ),
                      ),
                      _Section(
                        title: 'Interview history',
                        child: profile.labSessions.isEmpty
                            ? const Text(
                                'No completed AI Interview Lab sessions.',
                              )
                            : Column(
                                children: [
                                  for (final s in profile.labSessions)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${s.roleTrack} · ${s.overallScore.toStringAsFixed(0)}',
                                      ),
                                      subtitle: Text(
                                        '${s.difficulty} · ${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => context.pushNamed(
                                        RouteNames.companyInterviewLabReport,
                                        pathParameters: {
                                          'sessionId': s.sessionId,
                                        },
                                        queryParameters: {
                                          'applicationId':
                                              widget.applicationId,
                                        },
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      if (profile.progress != null)
                        _Section(
                          title: 'Learning progress',
                          child: Text(
                            profile.progress!.insights.isEmpty
                                ? 'Average overall ${profile.progress!.averageOverall.toStringAsFixed(0)} across ${profile.progress!.completedInterviews} interviews.'
                                : profile.progress!.insights.join('\n'),
                          ),
                        ),
                      _Section(
                        title: 'Private HR notes (company only)',
                        child: Column(
                          children: [
                            TextField(
                              controller: TextEditingController(
                                text: _notesDraft,
                              ),
                              minLines: 3,
                              maxLines: 6,
                              onChanged: (v) => _notesDraft = v,
                              decoration: const InputDecoration(
                                hintText: 'Internal notes — never shown to candidate',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () => _saveNotes(
                                  profile.application.id,
                                  _notesDraft ?? '',
                                ),
                                child: const Text('Save notes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Hiring lifecycle',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Stage: ${lifecycleStageLabel(profile.application.normalizedLifecycleStage)}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => ref
                                      .read(
                                        hiringLifecycleActionProvider.notifier,
                                      )
                                      .markResumeReviewed(
                                        profile.application.id,
                                      ),
                                  child: const Text('Resume Reviewed'),
                                ),
                                OutlinedButton(
                                  onPressed: () => ref
                                      .read(
                                        hiringLifecycleActionProvider.notifier,
                                      )
                                      .markPortfolioReviewed(
                                        profile.application.id,
                                      ),
                                  child: const Text('Portfolio Reviewed'),
                                ),
                                OutlinedButton(
                                  onPressed: () => ref
                                      .read(
                                        hiringLifecycleActionProvider.notifier,
                                      )
                                      .markAiInterviewCompleted(
                                        profile.application.id,
                                      ),
                                  child: const Text('AI Interview Done'),
                                ),
                                FilledButton(
                                  onPressed: () => context.pushNamed(
                                    RouteNames.companyEmployeeDetail,
                                    pathParameters: {
                                      'applicationId': profile.application.id,
                                    },
                                  ),
                                  child: const Text('Employee / Offer Hub'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            HiringTimelinePanel(
                              applicationId: profile.application.id,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Company can view, compare, shortlist, reject, and hire. '
                        'Interview Lab reports and scores are read-only.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile});
  final CompanyCandidateIntelligenceProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.companyPrimary.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.candidate.fullName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${profile.job.title} · ${pipelineStageLabel(profile.application.normalizedPipelineStage)}'
            ' · ${lifecycleStageLabel(profile.application.normalizedLifecycleStage)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Readiness · ${profile.readinessLevel}')),
              Chip(
                label: Text(
                  'Interview · ${profile.overallInterviewScore.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.profile});
  final CompanyCandidateIntelligenceProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Technical', profile.technicalScore),
      ('Communication', profile.communicationScore),
      ('Confidence', profile.confidenceScore),
      ('Problem Solving', profile.problemSolvingScore),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final i in items)
            Container(
              width: 140,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.$1, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text(
                    i.$2.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.companyPrimary,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
