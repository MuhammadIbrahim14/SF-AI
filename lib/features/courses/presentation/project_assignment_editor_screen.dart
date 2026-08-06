import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../ai_usage/widgets/skillforge_ai_widgets.dart';
import '../../teacher/ai_tools/models/teacher_ai_generation_request_model.dart';
import '../../teacher/ai_tools/models/teacher_ai_generation_result_model.dart';
import '../../teacher/ai_tools/services/teacher_ai_generation_service.dart';
import '../../teacher/ai_tools/widgets/teacher_ai_generate_button.dart';
import '../../teacher/ai_tools/widgets/teacher_ai_preview_dialog.dart';
import '../../teacher/ai_tools/widgets/teacher_ai_requirement_dialog.dart';
import '../data/models/mcq_assignment_model.dart';
import '../data/models/project_assignment_model.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class ProjectAssignmentEditorScreen extends ConsumerWidget {
  const ProjectAssignmentEditorScreen({
    super.key,
    required this.courseId,
    this.assignmentId,
  });

  final String courseId;
  final String? assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = assignmentId;
    if (id == null || id.isEmpty) {
      return _EditorScaffold(courseId: courseId);
    }

    final assignmentAsync = ref.watch(
      projectAssignmentDetailProvider((courseId: courseId, assignmentId: id)),
    );
    return assignmentAsync.when(
      loading: () => const RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Project',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Project',
        showBackButton: true,
        child: Center(child: Text(error.toString())),
      ),
      data: (assignment) {
        if (assignment == null) {
          return const RoleFixedHeaderPage(
            role: UserRole.teacher,
            title: 'Project unavailable',
            showBackButton: true,
            child: Center(child: Text('Project assignment not found.')),
          );
        }
        return _EditorScaffold(courseId: courseId, assignment: assignment);
      },
    );
  }
}

class _EditorScaffold extends ConsumerWidget {
  const _EditorScaffold({required this.courseId, this.assignment});

  final String courseId;
  final ProjectAssignmentModel? assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(assignmentActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: assignment == null ? 'Project Builder Studio' : 'Edit Project',
      subtitle:
          'Define requirements, instructions, skills, marks, and due date.',
      showBackButton: true,
      onBack: () => _goBack(context),
      scrollable: false,
      child: CoursePremiumBackground(
        child: _ProjectForm(
          courseId: courseId,
          assignment: assignment,
          isSubmitting: actionState.isLoading,
          onSubmit: (data) => _save(context, ref, data),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    _ProjectFormData data,
  ) async {
    final now = DateTime.now();
    final current = assignment;
    final model = ProjectAssignmentModel(
      assignmentId: current?.assignmentId ?? '',
      courseId: courseId,
      teacherId: current?.teacherId ?? '',
      title: data.title,
      description: data.description,
      requirements: data.requirements,
      instructions: data.instructions,
      maxMarks: data.maxMarks,
      dueDate: data.dueDate,
      skillsCovered: data.skillsCovered,
      status: current?.status ?? AssignmentStatus.draft,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
      publishedAt: current?.publishedAt,
      archivedAt: current?.archivedAt,
      projectGoal: data.projectGoal,
      realWorldScenario: data.realWorldScenario,
      learningObjectives: data.learningObjectives,
      skillsDemonstrated: data.skillsDemonstrated,
      deliverables: data.deliverables,
      milestones: data.milestones,
      acceptanceCriteria: data.acceptanceCriteria,
      submissionChecklist: data.submissionChecklist,
      estimatedCompletionHours: data.estimatedCompletionHours,
      difficultyLevel: data.difficultyLevel,
      rubricCriteria: data.rubricCriteria,
      starterGuidance: data.starterGuidance,
      resources: data.resources,
    );

    final notifier = ref.read(assignmentActionProvider.notifier);
    final success = current == null
        ? await notifier.createProjectAssignment(model)
        : await notifier.updateProjectAssignment(model);
    if (!context.mounted) return;

    final message = success
        ? 'Project assignment saved as draft.'
        : notifier.errorMessage ?? 'Unable to save project assignment.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (success) _goBack(context);
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(
      RouteNames.teacherProjectAssignments,
      pathParameters: {'courseId': courseId},
    );
  }
}

class _ProjectForm extends StatefulWidget {
  const _ProjectForm({
    required this.courseId,
    required this.onSubmit,
    this.assignment,
    this.isSubmitting = false,
  });

  final String courseId;
  final ProjectAssignmentModel? assignment;
  final ValueChanged<_ProjectFormData> onSubmit;
  final bool isSubmitting;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = TeacherAiGenerationService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _requirementsController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _maxMarksController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _skillsController;
  late final TextEditingController _projectGoalController;
  late final TextEditingController _scenarioController;
  late final TextEditingController _objectivesController;
  late final TextEditingController _skillsDemonstratedController;
  late final TextEditingController _deliverablesController;
  late final TextEditingController _milestonesController;
  late final TextEditingController _acceptanceController;
  late final TextEditingController _checklistController;
  late final TextEditingController _estimatedHoursController;
  late final TextEditingController _rubricController;
  late final TextEditingController _starterGuidanceController;
  late final TextEditingController _resourcesController;
  late String _difficultyLevel;
  bool _isAiGenerating = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignment;
    _titleController = TextEditingController(text: assignment?.title ?? '');
    _descriptionController = TextEditingController(
      text: assignment?.description ?? '',
    );
    _requirementsController = TextEditingController(
      text: assignment?.requirements.join('\n') ?? '',
    );
    _instructionsController = TextEditingController(
      text: assignment?.instructions ?? '',
    );
    _maxMarksController = TextEditingController(
      text: assignment == null ? '100' : assignment.maxMarks.toString(),
    );
    _dueDateController = TextEditingController(
      text: assignment?.dueDate == null
          ? ''
          : assignment!.dueDate!.toIso8601String().split('T').first,
    );
    _skillsController = TextEditingController(
      text: assignment?.skillsCovered.join(', ') ?? '',
    );
    _projectGoalController = TextEditingController(
      text: assignment?.projectGoal ?? '',
    );
    _scenarioController = TextEditingController(
      text: assignment?.realWorldScenario ?? '',
    );
    _objectivesController = TextEditingController(
      text: assignment?.learningObjectives.join('\n') ?? '',
    );
    _skillsDemonstratedController = TextEditingController(
      text: assignment?.skillsDemonstrated.join(', ') ?? '',
    );
    _deliverablesController = TextEditingController(
      text: assignment?.deliverables.join('\n') ?? '',
    );
    _milestonesController = TextEditingController(
      text: assignment?.milestones.join('\n') ?? '',
    );
    _acceptanceController = TextEditingController(
      text: assignment?.acceptanceCriteria.join('\n') ?? '',
    );
    _checklistController = TextEditingController(
      text: assignment?.submissionChecklist.join('\n') ?? '',
    );
    _estimatedHoursController = TextEditingController(
      text: assignment == null || assignment.estimatedCompletionHours == 0
          ? ''
          : assignment.estimatedCompletionHours.toString(),
    );
    _rubricController = TextEditingController(
      text: assignment?.rubricCriteria.join('\n') ?? '',
    );
    _starterGuidanceController = TextEditingController(
      text: assignment?.starterGuidance.join('\n') ?? '',
    );
    _resourcesController = TextEditingController(
      text: assignment?.resources.join('\n') ?? '',
    );
    _difficultyLevel = assignment?.difficultyLevel ?? 'Beginner';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _instructionsController.dispose();
    _maxMarksController.dispose();
    _dueDateController.dispose();
    _skillsController.dispose();
    _projectGoalController.dispose();
    _scenarioController.dispose();
    _objectivesController.dispose();
    _skillsDemonstratedController.dispose();
    _deliverablesController.dispose();
    _milestonesController.dispose();
    _acceptanceController.dispose();
    _checklistController.dispose();
    _estimatedHoursController.dispose();
    _rubricController.dispose();
    _starterGuidanceController.dispose();
    _resourcesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return UnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges && !widget.isSubmitting,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.assignment == null
                        ? 'Project Builder Studio'
                        : 'Edit Project',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SkillForgeAiCreditBalanceCard(compact: true),
                  const SizedBox(height: 10),
                  const SkillForgeAiReviewWarning(),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TeacherAiGenerateButton(
                      isLoading: _isAiGenerating,
                      label: 'Generate Assignment with AI',
                      onPressed: _generateAssignmentWithAi,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '1. Project Overview',
                    color: AppColors.primary,
                    children: [
                      CoursePremiumTextField(
                        controller: _titleController,
                        label: 'Project Title',
                        hintText: 'e.g. Build a E-commerce Dashboard',
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _descriptionController,
                        label: 'Project Description',
                        hintText: 'What is the goal of this project?',
                        minLines: 3,
                        maxLines: 5,
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _projectGoalController,
                        label: 'Project Goal',
                        hintText:
                            'What real outcome should the student build by the end?',
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _scenarioController,
                        label: 'Real-world Scenario',
                        hintText:
                            'Describe the client/product/business situation.',
                        minLines: 3,
                        maxLines: 5,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '2. Requirements',
                    color: AppColors.secondary,
                    children: [
                      CoursePremiumTextField(
                        controller: _requirementsController,
                        label: 'Acceptance Criteria / Requirements',
                        hintText: 'Write each requirement on a new line',
                        minLines: 4,
                        maxLines: 8,
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _instructionsController,
                        label: 'Submission Instructions',
                        hintText:
                            'e.g. Please host your code on GitHub and provide a Vercel live demo link.',
                        minLines: 3,
                        maxLines: 6,
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _deliverablesController,
                        label: 'Deliverables',
                        hintText: 'One deliverable per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _milestonesController,
                        label: 'Milestones',
                        hintText: 'One milestone per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _acceptanceController,
                        label: 'Acceptance Criteria',
                        hintText: 'One acceptance criterion per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _checklistController,
                        label: 'Submission Checklist',
                        hintText: 'One checklist item per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '3. Skills Covered',
                    color: Colors.blue,
                    children: [
                      CoursePremiumTextField(
                        controller: _skillsController,
                        label: 'Target Skills',
                        hintText:
                            'Comma separated e.g. React, State Management, API Integration',
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _objectivesController,
                        label: 'Learning Objectives',
                        hintText: 'One objective per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _skillsDemonstratedController,
                        label: 'Skills Demonstrated',
                        hintText: 'Comma separated skills students must prove',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '4. Evaluation',
                    color: Colors.purple,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 500;
                          final fields = [
                            CoursePremiumTextField(
                              controller: _maxMarksController,
                              label: 'Maximum Marks',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _positiveNumber,
                            ),
                            CoursePremiumTextField(
                              controller: _dueDateController,
                              readOnly: true,
                              label: 'Due Date',
                              hintText: 'Optional',
                              suffixIcon: const Icon(
                                Icons.calendar_today_rounded,
                              ),
                              onTap: _pickDueDate,
                            ),
                          ];

                          if (!isWide) {
                            return Column(
                              children: [
                                fields[0],
                                const SizedBox(height: 20),
                                fields[1],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: fields[0]),
                              const SizedBox(width: 20),
                              Expanded(child: fields[1]),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 500;
                          final fields = [
                            CoursePremiumTextField(
                              controller: _estimatedHoursController,
                              label: 'Estimated Completion Hours',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _difficultyLevel,
                              decoration: const InputDecoration(
                                labelText: 'Difficulty Level',
                              ),
                              items:
                                  const ['Beginner', 'Intermediate', 'Advanced']
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) => setState(
                                () => _difficultyLevel = value ?? 'Beginner',
                              ),
                            ),
                          ];
                          return isWide
                              ? Row(
                                  children: [
                                    Expanded(child: fields[0]),
                                    const SizedBox(width: 20),
                                    Expanded(child: fields[1]),
                                  ],
                                )
                              : Column(
                                  children: [
                                    fields[0],
                                    const SizedBox(height: 20),
                                    fields[1],
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _rubricController,
                        label: 'Rubric Criteria',
                        hintText: 'One rubric criterion per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _starterGuidanceController,
                        label: 'Starter Guidance',
                        hintText: 'One guidance tip per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _resourcesController,
                        label: 'Resources',
                        hintText: 'One resource/link per line',
                        minLines: 3,
                        maxLines: 6,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: widget.isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      backgroundColor: AppColors.primary,
                    ),
                    icon: widget.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, color: Colors.white),
                    label: Text(
                      widget.isSubmitting
                          ? 'Saving Project...'
                          : 'Save Project Draft',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _markDirty() {
    if (_hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dueDateController.text) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _dueDateController.text = selected.toIso8601String().split('T').first;
    });
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _positiveNumber(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a positive number';
    return null;
  }

  List<String> _lineList(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _commaList(TextEditingController controller) {
    return controller.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _generateAssignmentWithAi() async {
    final config = await TeacherAiRequirementDialog.show(
      context: context,
      taskType: TeacherAiTaskType.projectAssignmentBuilder,
      title: 'AI Project Assignment Requirements',
      initialTopic: _titleController.text.trim().isEmpty
          ? 'this course project'
          : _titleController.text.trim(),
      initialQuestionCount: 4,
      initialDurationMinutes: 7,
      initialTotalPoints: int.tryParse(_maxMarksController.text.trim()) ?? 100,
    );
    if (!mounted || config == null) return;
    setState(() => _isAiGenerating = true);
    try {
      final result = await _aiService.generate(
        TeacherAiGenerationRequestModel(
          taskType: TeacherAiTaskType.projectAssignmentBuilder,
          prompt: config.prompt,
          courseId: widget.courseId,
          currentTitle: _titleController.text.trim(),
          currentDescription: _descriptionController.text.trim(),
          skills: _commaList(_skillsController),
          questionCount: config.questionCount,
          durationMinutes: config.durationMinutes,
          difficulty: config.difficulty,
          extraContext: {
            'targetScreen': 'projectAssignmentEditor',
            'submissionType': 'project',
            'manualApplyOnly': true,
            ...config.extraContext,
          },
        ),
      );
      if (!mounted) return;
      final apply = await TeacherAiPreviewDialog.show(context, result);
      if (!mounted || !apply) return;
      _applyAiAssignment(result);
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  void _applyAiAssignment(TeacherAiGenerationResultModel result) {
    setState(() {
      _titleController.text = result.stringValue(
        'title',
        fallback: _titleController.text,
      );
      _descriptionController.text = result.stringValue(
        'description',
        fallback: _descriptionController.text,
      );
      _projectGoalController.text = result.stringValue(
        'projectGoal',
        fallback: _projectGoalController.text,
      );
      _scenarioController.text = result.stringValue(
        'scenario',
        fallback: _scenarioController.text,
      );
      final requirements = [
        ...result.stringList('requirements'),
        ...result
            .stringList('deliverables')
            .map((item) => 'Deliverable: $item'),
        ...result.stringList('milestones').map((item) => 'Milestone: $item'),
        ...result
            .stringList('submissionChecklist')
            .map((item) => 'Checklist: $item'),
        ...result.stringList('rubric').map((item) => 'Rubric: $item'),
      ];
      if (requirements.isNotEmpty) {
        _requirementsController.text = requirements.join('\n');
      }
      final deliverables = result.stringList('deliverables');
      if (deliverables.isNotEmpty) {
        _deliverablesController.text = deliverables.join('\n');
      }
      final milestones = result.stringList('milestones');
      if (milestones.isNotEmpty) {
        _milestonesController.text = milestones.join('\n');
      }
      final checklist = result.stringList('submissionChecklist');
      if (checklist.isNotEmpty) {
        _checklistController.text = checklist.join('\n');
      }
      final rubric = result.stringList('rubric');
      if (rubric.isNotEmpty) _rubricController.text = rubric.join('\n');
      final guidance = result.stringList('starterGuidance');
      if (guidance.isNotEmpty) {
        _starterGuidanceController.text = guidance.join('\n');
      }
      _instructionsController.text = result.stringValue(
        'instructions',
        fallback: [
          result.stringValue('scenario'),
          ...result
              .stringList('starterGuidance')
              .map((item) => 'Starter guidance: $item'),
          _instructionsController.text,
        ].where((item) => item.trim().isNotEmpty).join('\n\n'),
      );
      final skills = result.stringList('skills');
      if (skills.isNotEmpty) _skillsController.text = skills.join(', ');
      final objectives = result.stringList('learningObjectives');
      if (objectives.isNotEmpty) {
        _objectivesController.text = objectives.join('\n');
      }
      _maxMarksController.text = result
          .intValue(
            'totalPoints',
            fallback: int.tryParse(_maxMarksController.text.trim()) ?? 100,
          )
          .toString();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _hasUnsavedChanges = false);
    widget.onSubmit(
      _ProjectFormData(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requirements: _lineList(_requirementsController),
        instructions: _instructionsController.text.trim(),
        maxMarks: int.parse(_maxMarksController.text.trim()),
        dueDate: DateTime.tryParse(_dueDateController.text.trim()),
        skillsCovered: _commaList(_skillsController),
        projectGoal: _projectGoalController.text.trim(),
        realWorldScenario: _scenarioController.text.trim(),
        learningObjectives: _lineList(_objectivesController),
        skillsDemonstrated: _commaList(_skillsDemonstratedController),
        deliverables: _lineList(_deliverablesController),
        milestones: _lineList(_milestonesController),
        acceptanceCriteria: _lineList(_acceptanceController),
        submissionChecklist: _lineList(_checklistController),
        estimatedCompletionHours:
            int.tryParse(_estimatedHoursController.text.trim()) ?? 0,
        difficultyLevel: _difficultyLevel,
        rubricCriteria: _lineList(_rubricController),
        starterGuidance: _lineList(_starterGuidanceController),
        resources: _lineList(_resourcesController),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.color,
    required this.children,
  });

  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _ProjectFormData {
  const _ProjectFormData({
    required this.title,
    required this.description,
    required this.requirements,
    required this.instructions,
    required this.maxMarks,
    required this.dueDate,
    required this.skillsCovered,
    required this.projectGoal,
    required this.realWorldScenario,
    required this.learningObjectives,
    required this.skillsDemonstrated,
    required this.deliverables,
    required this.milestones,
    required this.acceptanceCriteria,
    required this.submissionChecklist,
    required this.estimatedCompletionHours,
    required this.difficultyLevel,
    required this.rubricCriteria,
    required this.starterGuidance,
    required this.resources,
  });

  final String title;
  final String description;
  final List<String> requirements;
  final String instructions;
  final int maxMarks;
  final DateTime? dueDate;
  final List<String> skillsCovered;
  final String projectGoal;
  final String realWorldScenario;
  final List<String> learningObjectives;
  final List<String> skillsDemonstrated;
  final List<String> deliverables;
  final List<String> milestones;
  final List<String> acceptanceCriteria;
  final List<String> submissionChecklist;
  final int estimatedCompletionHours;
  final String difficultyLevel;
  final List<String> rubricCriteria;
  final List<String> starterGuidance;
  final List<String> resources;
}
