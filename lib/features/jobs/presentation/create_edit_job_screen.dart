import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/job_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/company_permission_provider.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/responsive_pair.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../company/ai_hiring/models/company_ai_hiring_models.dart';
import '../../company/ai_hiring/widgets/company_ai_job_post_builder_dialog.dart';

class CreateEditJobScreen extends ConsumerStatefulWidget {
  const CreateEditJobScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<CreateEditJobScreen> createState() =>
      _CreateEditJobScreenState();
}

class _CreateEditJobScreenState extends ConsumerState<CreateEditJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _typeController = TextEditingController(text: 'Full-time');
  final _salaryController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _requiredSkillsController = TextEditingController();
  final _preferredSkillsController = TextEditingController();
  final _categoryController = TextEditingController();
  final _experienceLevelController = TextEditingController();
  final _minimumSkillScoreController = TextEditingController(text: '0');

  bool _isActive = true;
  bool _remoteAllowed = false;
  bool _matchingEnabled = true;
  bool _targetStudents = true;
  bool _targetFreelancers = false;
  JobModel? _existingJob;
  bool _isLoadingJob = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      _loadJob();
    }
  }

  void _loadJob() async {
    setState(() {
      _isLoadingJob = true;
      _loadError = null;
    });

    try {
      final job = await ref.read(jobDetailProvider(widget.jobId!).future);
      if (!mounted) return;

      if (job == null) {
        setState(() {
          _loadError = 'This job could not be found.';
          _isLoadingJob = false;
        });
        return;
      }

      setState(() {
        _existingJob = job;
        _titleController.text = job.title;
        _descriptionController.text = job.description;
        _locationController.text = job.location;
        _typeController.text = job.type;
        _salaryController.text = job.salaryRange;
        _requirementsController.text = job.requirements.join('\n');
        _requiredSkillsController.text = job.requiredSkills.join(', ');
        _preferredSkillsController.text = job.preferredSkills.join(', ');
        _categoryController.text = job.category;
        _experienceLevelController.text = job.experienceLevel;
        _minimumSkillScoreController.text = job.minimumSkillScore.toString();
        _isActive = job.isActive;
        _remoteAllowed = job.remoteAllowed;
        _matchingEnabled = job.matchingEnabled;
        _targetStudents =
            job.targetRoles.contains('student') ||
            job.targetRoles.contains('both');
        _targetFreelancers =
            job.targetRoles.contains('freelancer') ||
            job.targetRoles.contains('both');
        _isLoadingJob = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load job: $error';
        _isLoadingJob = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _typeController.dispose();
    _salaryController.dispose();
    _requirementsController.dispose();
    _requiredSkillsController.dispose();
    _preferredSkillsController.dispose();
    _categoryController.dispose();
    _experienceLevelController.dispose();
    _minimumSkillScoreController.dispose();
    super.dispose();
  }

  void _saveJob() async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canCreateJob) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    if (!mounted) return;
    if (widget.jobId != null && _existingJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait until the job loads.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final requirements = _requirementsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final requiredSkills = _commaList(_requiredSkillsController.text);
    final preferredSkills = _commaList(_preferredSkillsController.text);
    final targetRoles = <String>[
      if (_targetStudents) 'student',
      if (_targetFreelancers) 'freelancer',
    ];

    final job = JobModel(
      id: _existingJob?.id ?? '',
      companyId: _existingJob?.companyId ?? user.uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      requirements: requirements,
      location: _locationController.text.trim(),
      type: _typeController.text.trim(),
      salaryRange: _salaryController.text.trim(),
      isActive: _isActive,
      createdAt: _existingJob?.createdAt ?? DateTime.now(),
      applicantCount: _existingJob?.applicantCount ?? 0,
      requiredSkills: requiredSkills.isNotEmpty ? requiredSkills : requirements,
      preferredSkills: preferredSkills,
      minimumSkillScore:
          int.tryParse(_minimumSkillScoreController.text.trim()) ?? 0,
      targetRoles: targetRoles.isEmpty ? const ['student'] : targetRoles,
      experienceLevel: _experienceLevelController.text.trim(),
      category: _categoryController.text.trim(),
      remoteAllowed: _remoteAllowed,
      matchingEnabled: _matchingEnabled,
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(jobActionProvider.notifier);
    final success = _existingJob == null
        ? await notifier.createJob(job)
        : await notifier.updateJob(job);

    if (mounted) {
      if (success) {
        ref.invalidate(companyJobsProvider);
        ref.invalidate(allJobsProvider);
        ref.invalidate(matchedJobsProvider);
        if (job.id.isNotEmpty) {
          ref.invalidate(jobDetailProvider(job.id));
        }
        context.goNamed(RouteNames.companyJobs);
      } else {
        final error = ref.read(jobActionProvider).error;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save job: $error')));
      }
    }
  }

  void _openAiJobBuilder() {
    final user = ref.read(currentUserProvider).value;
    CompanyAiJobPostBuilderDialog.show(
      context: context,
      existingJob: _existingJob,
      contextModel: CompanyAiContextModel(
        companyId: user?.uid ?? _existingJob?.companyId ?? '',
        companyName: user?.fullName ?? 'Company',
        job: _draftJobForAi(user?.uid ?? _existingJob?.companyId ?? ''),
      ),
      onApply: _applyAiJobPost,
    );
  }

  JobModel _draftJobForAi(String companyId) {
    return JobModel(
      id: _existingJob?.id ?? '',
      companyId: companyId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      requirements: _requirementsController.text
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      location: _locationController.text.trim(),
      type: _typeController.text.trim(),
      salaryRange: _salaryController.text.trim(),
      isActive: _isActive,
      createdAt: _existingJob?.createdAt ?? DateTime.now(),
      requiredSkills: _commaList(_requiredSkillsController.text),
      preferredSkills: _commaList(_preferredSkillsController.text),
      minimumSkillScore:
          int.tryParse(_minimumSkillScoreController.text.trim()) ?? 0,
      targetRoles: [
        if (_targetStudents) 'student',
        if (_targetFreelancers) 'freelancer',
      ],
      experienceLevel: _experienceLevelController.text.trim(),
      category: _categoryController.text.trim(),
      remoteAllowed: _remoteAllowed,
      matchingEnabled: _matchingEnabled,
      updatedAt: DateTime.now(),
    );
  }

  void _applyAiJobPost(Map<String, dynamic> jobPost) {
    final normalized = _flattenAiJobPost(jobPost);

    String text(String key, [String fallback = '']) {
      final value = normalized[key];
      return value?.toString().trim().isNotEmpty == true
          ? value.toString().trim()
          : fallback;
    }

    List<String> list(String key) {
      final value = normalized[key];
      if (value is Iterable) {
        return value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }
      if (value is String) {
        return value
            .split(RegExp(r'[\n,;]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    setState(() {
      _titleController.text = text('title', _titleController.text);
      _descriptionController.text = text(
        'description',
        text('summary', _descriptionController.text),
      );
      final responsibilities = list('responsibilities');
      final requirements = [
        ...list('requirements'),
        ...responsibilities.map((item) => 'Responsibility: $item'),
        ...list('screeningQuestions').map((item) => 'Screening: $item'),
      ];
      if (requirements.isNotEmpty) {
        _requirementsController.text = requirements.join('\n');
      }
      final requiredSkills = list('requiredSkills');
      if (requiredSkills.isNotEmpty) {
        _requiredSkillsController.text = requiredSkills.join(', ');
      }
      final preferredSkills = list('preferredSkills');
      if (preferredSkills.isNotEmpty) {
        _preferredSkillsController.text = preferredSkills.join(', ');
      }
      _experienceLevelController.text = text(
        'experienceLevel',
        _experienceLevelController.text,
      );
      _typeController.text = text('employmentType', _typeController.text);
      _categoryController.text = text('category', _categoryController.text);
      _locationController.text = text('location', _locationController.text);
      _salaryController.text = text('salaryRange', _salaryController.text);
      final minScore = _intValue(
        normalized['minimumSkillScore'] ??
            normalized['minSkillScore'] ??
            normalized['skillScore'],
      );
      if (minScore != null) {
        _minimumSkillScoreController.text = minScore.clamp(0, 100).toString();
      }
      final locationType = text('locationType').toLowerCase();
      if (locationType.contains('remote') || locationType.contains('hybrid')) {
        _remoteAllowed = true;
      }
      final targetRoles = list(
        'targetRoles',
      ).map((item) => item.toLowerCase()).toSet();
      if (targetRoles.isNotEmpty) {
        _targetStudents =
            targetRoles.contains('student') || targetRoles.contains('students');
        _targetFreelancers =
            targetRoles.contains('freelancer') ||
            targetRoles.contains('freelancers');
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI draft applied. Review every field, then save.'),
      ),
    );
  }

  Map<String, dynamic> _flattenAiJobPost(Map<String, dynamic> source) {
    final nested = source['jobPost'];
    final result = <String, dynamic>{
      if (nested is Map) ...Map<String, dynamic>.from(nested),
      ...source,
    };
    result.remove('jobPost');

    void alias(String target, List<String> keys) {
      if (result[target] != null) return;
      for (final key in keys) {
        final value = result[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          result[target] = value;
          return;
        }
      }
    }

    alias('category', const ['jobCategory', 'department', 'field']);
    alias('employmentType', const ['type', 'jobType', 'workType']);
    alias('minimumSkillScore', const [
      'minScore',
      'minSkillScore',
      'requiredSkillScore',
      'skillScoreThreshold',
    ]);
    alias('locationType', const ['workMode', 'workArrangement']);
    alias('salaryRange', const ['salary', 'compensation', 'budget']);
    return result;
  }

  int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      final direct = int.tryParse(value.trim());
      if (direct != null) return direct;
      final match = RegExp(r'\d{1,3}').firstMatch(value);
      return match == null ? null : int.tryParse(match.group(0)!);
    }
    return null;
  }

  Widget _buildFormSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.elevatedSurface
            : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.divider : AppColors.lightDivider,
                ),
              ),
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.companyPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(jobActionProvider).isLoading;
    final permissionAsync = ref.watch(companyPermissionProvider);
    final permission = permissionAsync.value;
    final canManageHiring = permission?.canCreateJob ?? false;
    //     final isDark = Theme.of(context).brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: _existingJob == null ? 'Post New Role' : 'Edit Role',
      subtitle: 'Configure job details, matching rules, and visibility.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyJobs),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: _isLoadingJob
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_loadError!, textAlign: TextAlign.center),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!canManageHiring) ...[
                            _VerificationRestrictionPanel(
                              message:
                                  permission?.restrictionMessage ??
                                  'Company verification is required before posting jobs.',
                            ),
                            const SizedBox(height: 24),
                          ],
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.companyPrimary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.companyPrimary.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.companyPrimary,
                                ),
                                const Text(
                                  'SkillForge AI can draft or improve this job post. Preview first, then apply manually.',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                OutlinedButton.icon(
                                  onPressed: canManageHiring
                                      ? _openAiJobBuilder
                                      : null,
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: Text(
                                    _existingJob == null
                                        ? 'Create with AI'
                                        : 'Improve with AI',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildFormSection(
                            title: 'Core Details',
                            subtitle: 'Basic information about the role',
                            icon: Icons.work_outline_rounded,
                            children: [
                              CustomTextField(
                                controller: _titleController,
                                label: 'Job Title',
                                hint: 'e.g. Senior Flutter Developer',
                                validator: (val) => val == null || val.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              ResponsivePair(
                                first: CustomTextField(
                                  controller: _categoryController,
                                  label: 'Category',
                                  hint: 'e.g. Mobile Development',
                                ),
                                second: CustomTextField(
                                  controller: _experienceLevelController,
                                  label: 'Experience Level',
                                  hint: 'e.g. Junior, Mid, Senior',
                                ),
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _descriptionController,
                                label: 'Job Description',
                                hint: 'Describe the role...',
                                maxLines: 5,
                                validator: (val) => val == null || val.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),

                          _buildFormSection(
                            title: 'Logistics & Compensation',
                            subtitle: 'Where and how they will work',
                            icon: Icons.location_on_outlined,
                            children: [
                              ResponsivePair(
                                first: CustomTextField(
                                  controller: _locationController,
                                  label: 'Location',
                                  hint: 'e.g. Remote, NY',
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                second: CustomTextField(
                                  controller: _typeController,
                                  label: 'Type',
                                  hint: 'e.g. Full-time',
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _salaryController,
                                label: 'Salary Range',
                                hint: 'e.g. \$80k - \$120k',
                                validator: (val) => val == null || val.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Remote Allowed',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Candidates can work from anywhere',
                                ),
                                value: _remoteAllowed,
                                activeThumbColor: AppColors.companyPrimary,
                                onChanged: (val) =>
                                    setState(() => _remoteAllowed = val),
                              ),
                            ],
                          ),

                          _buildFormSection(
                            title: 'Skills & Requirements',
                            subtitle: 'What the ideal candidate looks like',
                            icon: Icons.psychology_outlined,
                            children: [
                              CustomTextField(
                                controller: _requiredSkillsController,
                                label: 'Required Skills (comma separated)',
                                hint: 'e.g. Flutter, Firebase, Dart',
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _preferredSkillsController,
                                label: 'Preferred Skills (comma separated)',
                                hint: 'e.g. Riverpod, UI Design',
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _requirementsController,
                                label: 'Additional Requirements (One per line)',
                                hint:
                                    'e.g. 3+ years Flutter experience\nStrong Dart knowledge',
                                maxLines: 4,
                              ),
                            ],
                          ),

                          _buildFormSection(
                            title: 'Matching & Targeting',
                            subtitle: 'Configure AI recommendations',
                            icon: Icons.auto_awesome_rounded,
                            children: [
                              CustomTextField(
                                controller: _minimumSkillScoreController,
                                label: 'Minimum Skill Score (0-100)',
                                hint: 'e.g. 70',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Smart Matching Enabled',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Allow AI to recommend best-fit candidates',
                                ),
                                value: _matchingEnabled,
                                activeThumbColor: AppColors.companyPrimary,
                                onChanged: (val) =>
                                    setState(() => _matchingEnabled = val),
                              ),
                              const Divider(height: 32),
                              const Text(
                                'Target Audience',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Students / Recent Grads'),
                                activeColor: AppColors.companyPrimary,
                                value: _targetStudents,
                                onChanged: (val) => setState(
                                  () => _targetStudents = val ?? true,
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Freelancers'),
                                activeColor: AppColors.companyPrimary,
                                value: _targetFreelancers,
                                onChanged: (val) => setState(
                                  () => _targetFreelancers = val ?? false,
                                ),
                              ),
                            ],
                          ),

                          _buildFormSection(
                            title: 'Publishing',
                            subtitle: 'Visibility settings',
                            icon: Icons.public_rounded,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Active Job Posting',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Job will be visible to candidates',
                                ),
                                value: _isActive,
                                activeThumbColor: AppColors.companyPrimary,
                                onChanged: (val) =>
                                    setState(() => _isActive = val),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: _existingJob == null
                                ? 'Publish Job Posting'
                                : 'Save Changes',
                            backgroundColor: AppColors.companyPrimary,
                            isLoading: isSaving || _isLoadingJob,
                            onPressed: canManageHiring ? _saveJob : null,
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

List<String> _commaList(String value) {
  return value
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class _VerificationRestrictionPanel extends StatelessWidget {
  const _VerificationRestrictionPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company verification required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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
