import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/company_permission_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../../interview_lab/models/interview_lab_models.dart';
import '../../../interview_lab/providers/interview_lab_providers.dart';
import '../providers/company_candidate_intelligence_providers.dart';

/// Read-only Interview Lab report viewer for company ATS.
class CompanyInterviewLabReportViewerScreen extends ConsumerWidget {
  const CompanyInterviewLabReportViewerScreen({
    required this.sessionId,
    this.applicationId,
    super.key,
  });

  final String sessionId;
  final String? applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final permission = ref.watch(companyPermissionProvider).value;
    final sessionAsync = ref.watch(interviewLabSessionProvider(sessionId));
    final questionsAsync = ref.watch(interviewLabQuestionsProvider(sessionId));
    final reportAsync =
        ref.watch(interviewLabReportForSessionProvider(sessionId));

    // Ensure access bridge when opened from an application.
    if (applicationId != null && applicationId!.isNotEmpty) {
      ref.watch(companyCandidateIntelligenceProvider(applicationId!));
    }

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Interview Lab report',
      subtitle: 'Read-only practice evidence · not editable by company',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.hiringPipeline),
      child: permission?.canViewApplicants != true
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Company verification required.'),
            )
          : sessionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$e'),
              ),
              data: (session) {
                if (session == null) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Session not found or access denied.'),
                  );
                }
                return reportAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$e'),
                  ),
                  data: (report) {
                    return questionsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('$e'),
                      data: (questions) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                InterviewLabRoleTrack.displayLabel(
                                  session.roleTrack,
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Difficulty ${session.difficulty} · '
                                'Time ${session.timeConsumedSeconds ~/ 60}m '
                                '${session.timeConsumedSeconds % 60}s · '
                                'Overall ${(report?.overallRating ?? session.overallScore).toStringAsFixed(0)}',
                              ),
                              if (report != null) ...[
                                const SizedBox(height: 12),
                                Text(report.summary),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        'Tech ${report.technicalScore.toStringAsFixed(0)}',
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        'Comm ${report.communicationScore.toStringAsFixed(0)}',
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        'Level ${report.interviewLevel}',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 18),
                              Text(
                                'Questions & answers',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final q in questions)
                                _QaCard(question: q),
                              if (report != null &&
                                  report.recommendations.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Recommendations',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                for (final r in report.recommendations)
                                  Text('• $r'),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                'Scores and feedback are immutable for company users.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _QaCard extends StatelessWidget {
  const _QaCard({required this.question});
  final InterviewLabQuestionModel question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${question.orderIndex + 1}${question.isFollowUp ? ' (follow-up)' : ''} · ${question.difficulty}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.companyPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(question.prompt, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            'Answer: ${question.isSkipped ? '(skipped)' : (question.candidateAnswer ?? '—')}',
          ),
          if ((question.aiCritique ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'AI feedback: ${question.aiCritique}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Score ${question.scoreOverall?.toStringAsFixed(0) ?? '—'} · '
            '${question.timeSpentSeconds}s',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
