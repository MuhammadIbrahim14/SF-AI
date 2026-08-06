import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/application_model.dart';
import '../../../../models/job_model.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/application_provider.dart';
import '../../../../providers/company_provider.dart';
import '../../../../providers/job_provider.dart';
import '../../../../providers/user_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../../ai_usage/models/ai_usage_models.dart';
import '../../../ai_usage/providers/ai_usage_provider.dart';
import '../models/company_ai_hiring_models.dart';
import '../services/company_ai_hiring_service.dart';
import '../widgets/company_ai_hiring_panel.dart';

class CompanyAiHiringAssistantScreen extends ConsumerStatefulWidget {
  const CompanyAiHiringAssistantScreen({
    super.key,
    this.jobId,
    this.applicationId,
  });

  final String? jobId;
  final String? applicationId;

  @override
  ConsumerState<CompanyAiHiringAssistantScreen> createState() =>
      _CompanyAiHiringAssistantScreenState();
}

class _CompanyAiHiringAssistantScreenState
    extends ConsumerState<CompanyAiHiringAssistantScreen> {
  final _prompt = TextEditingController();
  final _service = CompanyAiHiringService();
  String _taskType = CompanyAiTaskType.companyHiringPipelineInsights;
  JobModel? _selectedJob;
  CompanyAiHiringResponseModel? _response;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prompt.text = CompanyAiTaskType.defaultPrompt(_taskType);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final company = ref.watch(companyProvider).value;
    final jobs = ref.watch(companyJobsProvider).value ?? const <JobModel>[];
    final applications =
        ref.watch(companyApplicationsProvider).value ??
        const <ApplicationModel>[];
    final credits = ref.watch(currentAiUserCreditsProvider).value;

    final selectedJob = _effectiveSelectedJob(jobs);
    final relevantApplications = selectedJob == null
        ? applications
        : applications.where((item) => item.jobId == selectedJob.id).toList();
    final contextModel = CompanyAiContextModel(
      companyId: user?.uid ?? '',
      companyName: company?.companyName ?? user?.fullName ?? 'Company',
      companyIndustry: company?.industry,
      job: selectedJob,
      applications: relevantApplications,
      pipelineStageCounts: _stageCounts(relevantApplications),
      hiringGoal: _prompt.text.trim(),
    );

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'AI Hiring Assistant',
      subtitle:
          'Create job posts, review candidates, and build interview kits.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyDashboard),
      scrollable: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          _Hero(
            remainingCredits: credits?.remainingCredits,
            selectedJobTitle: selectedJob?.title,
          ),
          const SizedBox(height: 16),
          const CompanyAiFairHiringNotice(),
          const SizedBox(height: 16),
          _TaskPicker(taskType: _taskType, onChanged: _changeTask),
          const SizedBox(height: 12),
          _TaskInfoCard(taskType: _taskType),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedJob?.id,
            decoration: const InputDecoration(
              labelText: 'Job context',
              helperText: 'Optional, but recommended for better AI output.',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All jobs / general pipeline'),
              ),
              ...jobs.map(
                (job) => DropdownMenuItem<String>(
                  value: job.id,
                  child: Text(job.title),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _selectedJob = _firstJobWhere(jobs, value ?? '');
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Hiring instructions',
              hintText:
                  'Example: create a technical interview kit for Flutter + Firebase candidates...',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : () => _generate(contextModel),
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _loading
                      ? 'Generating...'
                      : 'Generate (${AiUsageDefaults.featureCosts[_taskType] ?? 1} credits)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_response != null) ...[
            CompanyAiHiringPanel(response: _response!),
            const SizedBox(height: 12),
            _ResultActions(
              taskType: _taskType,
              selectedJob: selectedJob,
              onCreateJob: () => context.pushNamed(RouteNames.createJob),
              onEditJob: selectedJob == null
                  ? null
                  : () => context.pushNamed(
                      RouteNames.editJob,
                      pathParameters: {'id': selectedJob.id},
                    ),
              onOpenPipeline: () =>
                  context.pushNamed(RouteNames.hiringPipeline),
            ),
          ],
          if (_response == null)
            _EmptyAssistantState(
              applicationCount: relevantApplications.length,
              jobCount: jobs.length,
            ),
        ],
      ),
    );
  }

  void _changeTask(String value) {
    setState(() {
      _taskType = value;
      _response = null;
      _prompt.text = CompanyAiTaskType.defaultPrompt(value);
    });
  }

  JobModel? _effectiveSelectedJob(List<JobModel> jobs) {
    if (_selectedJob != null) {
      return _firstJobWhere(jobs, _selectedJob!.id);
    }
    final id = widget.jobId;
    if (id == null || id.isEmpty) return null;
    return _firstJobWhere(jobs, id);
  }

  JobModel? _firstJobWhere(List<JobModel> jobs, String id) {
    for (final job in jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  Map<String, int> _stageCounts(List<ApplicationModel> applications) {
    final counts = <String, int>{};
    for (final application in applications) {
      counts.update(
        application.normalizedStatus,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  Future<void> _generate(CompanyAiContextModel contextModel) async {
    setState(() => _loading = true);
    try {
      final response = await _service.generate(
        CompanyAiHiringRequestModel(
          taskType: _taskType,
          prompt: _prompt.text.trim().isEmpty
              ? 'Generate ${CompanyAiTaskType.label(_taskType)} for this hiring context.'
              : _prompt.text.trim(),
          context: contextModel,
        ),
      );
      if (!mounted) return;
      setState(() => _response = response);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.remainingCredits, required this.selectedJobTitle});

  final int? remainingCredits;
  final String? selectedJobTitle;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final textWidth = availableWidth < 620 ? availableWidth - 92 : 520.0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.companyPrimary.withValues(alpha: 0.22),
            AppColors.companySecondary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.24),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.psychology_alt_rounded, size: 42),
          SizedBox(
            width: textWidth.clamp(220.0, 520.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company AI Hiring Assistant',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  selectedJobTitle == null
                      ? 'Use AI for job posts, candidate review, interview kits, and pipeline insights.'
                      : 'Context: $selectedJobTitle',
                ),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.bolt_rounded, size: 16),
            label: Text('${remainingCredits ?? 0} credits'),
          ),
        ],
      ),
    );
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({required this.taskType, required this.onChanged});

  final String taskType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final cardWidth = isWide
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 560
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: CompanyAiTaskType.all.map((task) {
            final selected = taskType == task;
            return SizedBox(
              width: cardWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onChanged(task),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.companyPrimary.withValues(alpha: 0.16)
                        : Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? AppColors.companyPrimary
                          : Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _taskIcon(task),
                            size: 20,
                            color: selected
                                ? AppColors.companyPrimary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              CompanyAiTaskType.label(task),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${AiUsageDefaults.featureCosts[task] ?? 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CompanyAiTaskType.description(task),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _taskIcon(String task) {
    return switch (task) {
      CompanyAiTaskType.companyJobPostBuilder ||
      CompanyAiTaskType.companyJobPostImprover => Icons.post_add_rounded,
      CompanyAiTaskType.companyCandidateSummary ||
      CompanyAiTaskType.companyCandidateComparison ||
      CompanyAiTaskType.companyShortlistAssistant => Icons.groups_rounded,
      CompanyAiTaskType.companyInterviewQuestionBuilder ||
      CompanyAiTaskType.companyInterviewScorecardBuilder ||
      CompanyAiTaskType.companyInterviewKitBuilder => Icons.fact_check_rounded,
      CompanyAiTaskType.companyCandidateMessageDraft => Icons.mail_rounded,
      CompanyAiTaskType.companySkillGapAnalysis => Icons.psychology_rounded,
      _ => Icons.insights_rounded,
    };
  }
}

class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.taskType});

  final String taskType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.companyPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.companyPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${CompanyAiTaskType.label(taskType)}: ${CompanyAiTaskType.description(taskType)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.taskType,
    required this.selectedJob,
    required this.onCreateJob,
    required this.onOpenPipeline,
    this.onEditJob,
  });

  final String taskType;
  final JobModel? selectedJob;
  final VoidCallback onCreateJob;
  final VoidCallback? onEditJob;
  final VoidCallback onOpenPipeline;

  @override
  Widget build(BuildContext context) {
    final isJobPostTask =
        taskType == CompanyAiTaskType.companyJobPostBuilder ||
        taskType == CompanyAiTaskType.companyJobPostImprover;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (isJobPostTask && selectedJob == null)
          FilledButton.icon(
            onPressed: onCreateJob,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Open Job Form'),
          ),
        if (isJobPostTask && selectedJob != null)
          FilledButton.icon(
            onPressed: onEditJob,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Open Selected Job Editor'),
          ),
        if (!isJobPostTask)
          OutlinedButton.icon(
            onPressed: onOpenPipeline,
            icon: const Icon(Icons.account_tree_rounded),
            label: const Text('Open Hiring Pipeline'),
          ),
      ],
    );
  }
}

class _EmptyAssistantState extends StatelessWidget {
  const _EmptyAssistantState({
    required this.applicationCount,
    required this.jobCount,
  });

  final int applicationCount;
  final int jobCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'Ready. Current context has $jobCount jobs and $applicationCount relevant applications. Choose an action and generate a preview.',
      ),
    );
  }
}
