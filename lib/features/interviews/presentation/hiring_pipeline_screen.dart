import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/application_model.dart';
import '../../../models/job_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class HiringPipelineScreen extends ConsumerStatefulWidget {
  const HiringPipelineScreen({super.key});

  @override
  ConsumerState<HiringPipelineScreen> createState() =>
      _HiringPipelineScreenState();
}

class _HiringPipelineScreenState extends ConsumerState<HiringPipelineScreen> {
  String _stage = 'all';
  String _query = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(companyApplicationsProvider);
    final jobsAsync = ref.watch(companyJobsProvider);

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Hiring Pipeline',
      subtitle: 'Move candidates manually from application to final decision.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyDashboard),
      scrollable: false,
      child: applicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (applications) {
          if (applications.isEmpty) {
            return DashboardEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No candidates yet',
              message:
                  'Applications will appear here after candidates apply to your jobs.',
              actionLabel: 'Post a Job',
              onAction: () => context.pushNamed(RouteNames.createJob),
            );
          }

          final jobsById = {
            for (final job in jobsAsync.value ?? const <JobModel>[])
              job.id: job,
          };
          final visible = _filter(applications, jobsById);
          final ranked = [...visible]..sort(_rankSort);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(companyApplicationsProvider);
              ref.invalidate(companyJobsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                _PipelineSummary(applications: applications),
                const SizedBox(height: 16),
                _FairHiringBanner(),
                const SizedBox(height: 16),
                _PipelineToolbar(
                  stage: _stage,
                  controller: _searchController,
                  onStageChanged: (value) => setState(() => _stage = value),
                  onQueryChanged: (value) => setState(() => _query = value),
                  onOpenAi: () =>
                      context.pushNamed(RouteNames.companyAiHiringAssistant),
                ),
                const SizedBox(height: 20),
                if (_stage == 'all' && _query.trim().isEmpty)
                  _StageBoard(applications: ranked, jobsById: jobsById)
                else if (ranked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: DashboardEmptyState(
                      icon: Icons.manage_search_rounded,
                      title: 'No candidates found',
                      message:
                          'Try another stage, skill, name, job, or title search.',
                    ),
                  )
                else
                  ...ranked.map(
                    (application) => _PipelineCandidateCard(
                      application: application,
                      job: jobsById[application.jobId],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<ApplicationModel> _filter(
    List<ApplicationModel> applications,
    Map<String, JobModel> jobsById,
  ) {
    final query = _query.trim().toLowerCase();
    return applications.where((application) {
      final stageMatches =
          _stage == 'all' || application.normalizedPipelineStage == _stage;
      if (!stageMatches) return false;
      if (query.isEmpty) return true;

      final job = jobsById[application.jobId];
      final haystack = [
        application.applicantId,
        application.role,
        application.coverLetter,
        application.evaluationSummary,
        application.rankingReason,
        application.companyNotes,
        application.offerDetails,
        application.recommendedNextStep,
        ...application.matchedSkills,
        ...application.missingSkills,
        job?.title ?? '',
        job?.category ?? '',
        ...(job?.requiredSkills ?? const <String>[]),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }
}

class _PipelineSummary extends StatelessWidget {
  const _PipelineSummary({required this.applications});

  final List<ApplicationModel> applications;

  int _count(String stage) {
    return applications
        .where((item) => item.normalizedPipelineStage == stage)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final stats = [
          _SummaryStat('Total', applications.length, AppColors.companyPrimary),
          _SummaryStat('New', _count('applied'), AppColors.info),
          _SummaryStat('Shortlisted', _count('shortlisted'), AppColors.primary),
          _SummaryStat('Interviews', _count('interview'), AppColors.warning),
          _SummaryStat('Offers', _count('offer'), AppColors.secondary),
          _SummaryStat('Hired', _count('hired'), AppColors.success),
          _SummaryStat('Rejected', _count('rejected'), AppColors.error),
          _SummaryStat('Talent Pool', _count('talentPool'), Colors.teal),
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(context),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: wide ? (constraints.maxWidth - 42) / 4 : 150,
                  child: _SummaryTile(stat: stat),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PipelineToolbar extends StatelessWidget {
  const _PipelineToolbar({
    required this.stage,
    required this.controller,
    required this.onStageChanged,
    required this.onQueryChanged,
    required this.onOpenAi,
  });

  final String stage;
  final TextEditingController controller;
  final ValueChanged<String> onStageChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: stage == 'all',
                onSelected: (_) => onStageChanged('all'),
              ),
              for (final item in applicationPipelineStages)
                ChoiceChip(
                  label: Text(pipelineStageLabel(item)),
                  selected: stage == item,
                  onSelected: (_) => onStageChanged(item),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final search = TextField(
                controller: controller,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search talent pool by skill, job, title, notes...',
                ),
              );
              final aiButton = FilledButton.icon(
                onPressed: onOpenAi,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('AI Hiring Assistant'),
              );
              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 10), aiButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  aiButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StageBoard extends StatelessWidget {
  const _StageBoard({required this.applications, required this.jobsById});

  final List<ApplicationModel> applications;
  final Map<String, JobModel> jobsById;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = applicationPipelineStages.map((stage) {
          final items = applications
              .where((item) => item.normalizedPipelineStage == stage)
              .toList();
          return _StageColumn(
            stage: stage,
            applications: items,
            jobsById: jobsById,
          );
        }).toList();

        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final column in columns) ...[
                column,
                const SizedBox(height: 14),
              ],
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in columns) ...[
                SizedBox(width: 330, child: column),
                const SizedBox(width: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.stage,
    required this.applications,
    required this.jobsById,
  });

  final String stage;
  final List<ApplicationModel> applications;
  final Map<String, JobModel> jobsById;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pipelineStageLabel(stage),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CountBadge(count: applications.length),
            ],
          ),
          const SizedBox(height: 12),
          if (applications.isEmpty)
            Text(
              'No candidates',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final application in applications)
              _PipelineCandidateCard(
                application: application,
                job: jobsById[application.jobId],
                compact: true,
              ),
        ],
      ),
    );
  }
}

class _PipelineCandidateCard extends ConsumerWidget {
  const _PipelineCandidateCard({
    required this.application,
    required this.job,
    this.compact = false,
  });

  final ApplicationModel application;
  final JobModel? job;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final score = application.advisoryScore;
    final date = DateFormat.yMMMd().format(application.appliedAt);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 10 : 14),
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.companyPrimary.withValues(
                  alpha: 0.14,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.companyPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidate ${_shortId(application.applicantId)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      job?.title ?? 'Job ${_shortId(application.jobId)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Applied $date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StagePill(stage: application.normalizedPipelineStage),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (score > 0)
                _InfoChip(
                  icon: Icons.leaderboard_rounded,
                  label: 'Advisory ${score.toStringAsFixed(0)}%',
                ),
              if (application.normalizedOfferStatus != 'none')
                _InfoChip(
                  icon: Icons.local_offer_rounded,
                  label: 'Offer ${application.normalizedOfferStatus}',
                ),
              if (application.talentPoolSaved)
                const _InfoChip(
                  icon: Icons.bookmark_added_rounded,
                  label: 'Talent Pool',
                ),
            ],
          ),
          if (application.matchedSkills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in application.matchedSkills.take(4))
                  Chip(label: Text(skill)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            application.recommendedNextStep.trim().isEmpty
                ? _nextStepText(application)
                : application.recommendedNextStep,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (!compact && application.evaluationSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              application.evaluationSummary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          // Show offer details if an offer exists
          if (!compact &&
              (application.offerSalary.isNotEmpty ||
                  application.offerJoiningDate.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Offer Details',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (application.offerSalary.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Salary:',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '${application.offerSalary} ${application.offerCurrency}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (application.offerJoiningDate.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Join:',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          application.offerJoiningDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  RouteNames.companyCandidateIntelligence,
                  pathParameters: {'applicationId': application.id},
                ),
                icon: const Icon(Icons.psychology_alt_rounded),
                label: const Text('Intelligence'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  RouteNames.jobApplicants,
                  pathParameters: {'id': application.jobId},
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Review'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Move stage',
                onSelected: (stage) => _moveStage(context, ref, stage),
                itemBuilder: (context) => [
                  for (final stage in applicationPipelineStages)
                    PopupMenuItem(
                      value: stage,
                      child: Text('Move to ${pipelineStageLabel(stage)}'),
                    ),
                ],
                child: const _ActionChipButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Move',
                ),
              ),
              TextButton.icon(
                onPressed: () => _openOfferDialog(context, ref),
                icon: const Icon(Icons.local_offer_rounded),
                label: const Text('Offer'),
              ),
              TextButton.icon(
                onPressed: () => _openNotesDialog(context, ref),
                icon: const Icon(Icons.note_alt_rounded),
                label: const Text('Notes'),
              ),
              TextButton.icon(
                onPressed: () => _toggleTalentPool(context, ref),
                icon: Icon(
                  application.talentPoolSaved
                      ? Icons.bookmark_remove_rounded
                      : Icons.bookmark_add_outlined,
                ),
                label: Text(
                  application.talentPoolSaved ? 'Remove Pool' : 'Save Talent',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _moveStage(
    BuildContext context,
    WidgetRef ref,
    String stage,
  ) async {
    final success = await ref
        .read(applicationActionProvider.notifier)
        .updateHiringData(
          applicationId: application.id,
          pipelineStage: stage,
          recommendedNextStep: _recommendedNextStepFor(stage),
          talentPoolSaved: stage == 'talentPool' ? true : null,
        );
    if (!context.mounted) return;
    _showResult(
      context,
      success,
      successMessage: 'Candidate moved to ${pipelineStageLabel(stage)}.',
    );
  }

  Future<void> _toggleTalentPool(BuildContext context, WidgetRef ref) async {
    final next = !application.talentPoolSaved;
    final success = await ref
        .read(applicationActionProvider.notifier)
        .updateHiringData(
          applicationId: application.id,
          pipelineStage: next
              ? 'talentPool'
              : application.normalizedPipelineStage,
          talentPoolSaved: next,
          recommendedNextStep: next
              ? 'Saved for future roles. Use search to rediscover this candidate.'
              : 'Review candidate for the current hiring stage.',
        );
    if (!context.mounted) return;
    _showResult(
      context,
      success,
      successMessage: next
          ? 'Candidate saved to talent pool.'
          : 'Candidate removed from talent pool.',
    );
  }

  Future<void> _openNotesDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: application.companyNotes);
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recruiter Notes'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Internal notes for this candidate...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null) return;
    final success = await ref
        .read(applicationActionProvider.notifier)
        .updateHiringData(applicationId: application.id, companyNotes: notes);
    if (!context.mounted) return;
    _showResult(context, success, successMessage: 'Notes saved.');
  }

  Future<void> _openOfferDialog(BuildContext context, WidgetRef ref) async {
    final detailsController = TextEditingController(
      text: application.offerDetails,
    );
    String offerStatus = application.normalizedOfferStatus == 'none'
        ? 'draft'
        : application.normalizedOfferStatus;

    final result = await showDialog<({String status, String details})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Offer Management'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: offerStatus,
                  items: [
                    for (final status in applicationOfferStatuses.where(
                      (item) => item != 'none',
                    ))
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => offerStatus = value);
                  },
                  decoration: const InputDecoration(labelText: 'Offer Status'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Offer Details',
                    hintText:
                        'Draft message, budget/salary, start date, and next steps. No offer is sent automatically.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((
                status: offerStatus,
                details: detailsController.text.trim(),
              )),
              child: const Text('Save Offer'),
            ),
          ],
        ),
      ),
    );
    detailsController.dispose();
    if (result == null) return;
    final sent = result.status == 'sent';
    final success = await ref
        .read(applicationActionProvider.notifier)
        .updateHiringData(
          applicationId: application.id,
          pipelineStage: result.status == 'accepted' ? 'hired' : 'offer',
          applicationStatus: result.status == 'accepted'
              ? 'hired'
              : result.status == 'sent'
                  ? 'offer'
                  : null,
          offerStatus: result.status,
          offerDetails: result.details,
          candidateVisibleStatus: result.status == 'sent'
              ? 'offer_pending'
              : result.status == 'accepted'
                  ? 'hired'
                  : result.status == 'declined'
                      ? 'offer_declined'
                      : null,
          offerMessage: result.status == 'draft' ? null : result.details,
          offerSentAt: sent ? DateTime.now() : null,
          lifecycleStage: result.status == 'sent'
              ? 'offer_sent'
              : result.status == 'accepted'
                  ? 'offer_accepted'
                  : result.status == 'declined'
                      ? 'offer_declined'
                      : null,
          recommendedNextStep: sent
              ? 'Offer sent. Candidate can respond in My Applications.'
              : 'Offer ${result.status}. Follow up manually with the candidate.',
        );
    if (!context.mounted) return;
    _showResult(
      context,
      success,
      successMessage: sent
          ? 'Offer sent. Candidate can view it under My Applications.'
          : 'Offer details saved.',
    );
  }
}

class _FairHiringBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ranking and AI summaries are advisory only. The company must manually review every candidate and click any status or offer action.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.stat});

  final _SummaryStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: stat.color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            stat.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.companyPrimary.withValues(alpha: 0.16),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: AppColors.companyPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (normalizePipelineStage(stage)) {
      'hired' => AppColors.success,
      'rejected' => AppColors.error,
      'interview' => AppColors.info,
      'offer' => AppColors.secondary,
      'talentPool' => Colors.teal,
      _ => AppColors.companyPrimary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        pipelineStageLabel(stage).toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SummaryStat {
  const _SummaryStat(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

BoxDecoration _panelDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
  );
}

int _rankSort(ApplicationModel a, ApplicationModel b) {
  final score = b.advisoryScore.compareTo(a.advisoryScore);
  if (score != 0) return score;
  return b.appliedAt.compareTo(a.appliedAt);
}

String _nextStepText(ApplicationModel application) {
  if (application.recommendedNextStep.trim().isNotEmpty) {
    return application.recommendedNextStep;
  }
  return _recommendedNextStepFor(application.normalizedPipelineStage);
}

String _recommendedNextStepFor(String stage) {
  return switch (normalizePipelineStage(stage)) {
    'applied' => 'Review application evidence and move to screening.',
    'screening' => 'Compare skills and decide whether to shortlist.',
    'shortlisted' => 'Schedule or prepare an interview.',
    'interview' => 'Complete evaluation and decide offer/reject/talent pool.',
    'offer' => 'Maintain offer draft/status manually.',
    'hired' => 'Candidate is marked hired.',
    'rejected' => 'Candidate has been rejected.',
    'talentPool' => 'Saved for future roles and searchable in this pipeline.',
    _ => 'Open candidate details to review next steps.',
  };
}

void _showResult(
  BuildContext context,
  bool success, {
  required String successMessage,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success ? successMessage : 'Unable to update candidate.'),
    ),
  );
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}
