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
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class CreateEditMcqAssignmentScreen extends ConsumerWidget {
  const CreateEditMcqAssignmentScreen({
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
      return _AssignmentEditorScaffold(courseId: courseId);
    }

    final assignmentAsync = ref.watch(
      assignmentDetailProvider((courseId: courseId, assignmentId: id)),
    );
    return assignmentAsync.when(
      loading: () => const RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit MCQ',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit MCQ',
        showBackButton: true,
        child: Center(child: Text(error.toString())),
      ),
      data: (assignment) {
        if (assignment == null) {
          return const RoleFixedHeaderPage(
            role: UserRole.teacher,
            title: 'Assignment unavailable',
            showBackButton: true,
            child: Center(child: Text('Assignment not found.')),
          );
        }
        return _AssignmentEditorScaffold(
          courseId: courseId,
          assignment: assignment,
        );
      },
    );
  }
}

class _AssignmentEditorScaffold extends ConsumerWidget {
  const _AssignmentEditorScaffold({required this.courseId, this.assignment});

  final String courseId;
  final McqAssignmentModel? assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(assignmentActionProvider);
    final isEditing = assignment != null;

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: isEditing ? 'Edit MCQ Assignment' : 'Create MCQ Assignment',
      subtitle: 'Build timed MCQ assessments with marks and explanations.',
      showBackButton: true,
      onBack: () => _goBack(context),
      scrollable: false,
      child: CoursePremiumBackground(
        child: _AssignmentForm(
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
    _AssignmentFormData data,
  ) async {
    final now = DateTime.now();
    final current = assignment;
    final model = McqAssignmentModel(
      assignmentId: current?.assignmentId ?? '',
      courseId: courseId,
      teacherId: current?.teacherId ?? '',
      title: data.title,
      description: data.description,
      skillsCovered: data.skillsCovered,
      passingMarks: data.passingMarks,
      totalMarks: data.totalMarks,
      timeLimitMinutes: data.timeLimitMinutes,
      dueDate: data.dueDate,
      questions: data.questions,
      status: current?.status ?? AssignmentStatus.draft,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
      publishedAt: current?.publishedAt,
      archivedAt: current?.archivedAt,
    );

    final notifier = ref.read(assignmentActionProvider.notifier);
    final success = current == null
        ? await notifier.createAssignment(model)
        : await notifier.updateAssignment(model);
    if (!context.mounted) return;

    final message = success
        ? 'Assignment saved as draft.'
        : notifier.errorMessage ?? 'Unable to save assignment.';
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
      RouteNames.teacherAssignments,
      pathParameters: {'courseId': courseId},
    );
  }
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({
    required this.courseId,
    required this.onSubmit,
    this.assignment,
    this.isSubmitting = false,
  });

  final String courseId;
  final McqAssignmentModel? assignment;
  final ValueChanged<_AssignmentFormData> onSubmit;
  final bool isSubmitting;

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = TeacherAiGenerationService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _skillsController;
  late final TextEditingController _passingController;
  late final TextEditingController _timeController;
  late final TextEditingController _dueDateController;
  late final List<_QuestionDraft> _questions;
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
    _skillsController = TextEditingController(
      text: assignment?.skillsCovered.join(', ') ?? '',
    );
    _passingController = TextEditingController(
      text: assignment == null ? '1' : assignment.passingMarks.toString(),
    );
    _timeController = TextEditingController(
      text: assignment == null ? '30' : assignment.timeLimitMinutes.toString(),
    );
    _dueDateController = TextEditingController(
      text: assignment?.dueDate == null
          ? ''
          : assignment!.dueDate!.toIso8601String().split('T').first,
    );
    _questions =
        assignment?.questions
            .map((question) => _QuestionDraft.fromModel(question))
            .toList() ??
        [_QuestionDraft()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    _passingController.dispose();
    _timeController.dispose();
    _dueDateController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final totalMarks = _totalMarks();
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
                        ? 'Assessment Builder'
                        : 'Edit Assessment',
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
                      label: 'Generate Quiz / MCQs with AI',
                      onPressed: _generateQuizWithAi,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Core Details',
                    color: AppColors.primary,
                    children: [
                      CoursePremiumTextField(
                        controller: _titleController,
                        label: 'Assessment Title',
                        hintText: 'e.g. Midterm Examination',
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _descriptionController,
                        label: 'Description & Instructions',
                        hintText: 'What should students know before starting?',
                        minLines: 3,
                        maxLines: 5,
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _skillsController,
                        label: 'Skills Covered',
                        hintText:
                            'Comma separated e.g. React, State Management',
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 560;
                          final fields = [
                            CoursePremiumTextField(
                              controller: _passingController,
                              label: 'Passing Marks',
                              hintText: 'Out of $totalMarks',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _positiveNumber,
                            ),
                            CoursePremiumTextField(
                              controller: _timeController,
                              label: 'Time Limit (Min)',
                              hintText: 'e.g. 45',
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
                                for (var i = 0; i < fields.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 20),
                                  fields[i],
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: fields[0]),
                              const SizedBox(width: 20),
                              Expanded(child: fields[1]),
                              const SizedBox(width: 20),
                              Expanded(child: fields[2]),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _Section(
                    title: 'Questions Bank',
                    color: AppColors.secondary,
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => setState(() {
                        _questions.add(_QuestionDraft());
                      }),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.15,
                        ),
                        foregroundColor: AppColors.secondary,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Add Question',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    children: [
                      for (
                        var index = 0;
                        index < _questions.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 24),
                        _QuestionCard(
                          index: index,
                          draft: _questions[index],
                          canRemove: _questions.length > 1,
                          onRemove: () => setState(() {
                            final removed = _questions.removeAt(index);
                            removed.dispose();
                          }),
                          onMarksChanged: () => setState(() {}),
                        ),
                      ],
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
                          ? 'Saving Assessment...'
                          : 'Save Assessment Draft',
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

  int _totalMarks() {
    return _questions.fold<int>(0, (total, question) {
      return total + (int.tryParse(question.marks.text.trim()) ?? 0);
    });
  }

  List<String> _commaList(TextEditingController controller) {
    return controller.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _generateQuizWithAi() async {
    final config = await TeacherAiRequirementDialog.show(
      context: context,
      taskType: TeacherAiTaskType.quizBuilder,
      title: 'AI Quiz Requirements',
      initialTopic: _titleController.text.trim().isEmpty
          ? 'this assessment'
          : _titleController.text.trim(),
      initialQuestionCount: _questions.length < 5 ? 5 : _questions.length,
      initialDurationMinutes: int.tryParse(_timeController.text.trim()),
      initialTotalPoints: _totalMarks() <= 0 ? 100 : _totalMarks(),
    );
    if (!mounted || config == null) return;
    setState(() => _isAiGenerating = true);
    try {
      final skills = _commaList(_skillsController);
      final result = await _aiService.generate(
        TeacherAiGenerationRequestModel(
          taskType: TeacherAiTaskType.quizBuilder,
          prompt: config.prompt,
          courseId: widget.courseId,
          currentTitle: _titleController.text.trim(),
          currentDescription: _descriptionController.text.trim(),
          skills: skills,
          questionCount: config.questionCount,
          durationMinutes: config.durationMinutes,
          difficulty: config.difficulty,
          extraContext: {
            'targetScreen': 'mcqAssignmentEditor',
            'manualApplyOnly': true,
            ...config.extraContext,
          },
        ),
      );
      if (!mounted) return;
      final apply = await TeacherAiPreviewDialog.show(context, result);
      if (!mounted || !apply) return;
      _applyAiQuiz(result);
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  void _applyAiQuiz(TeacherAiGenerationResultModel result) {
    setState(() {
      _titleController.text = result.stringValue(
        'title',
        fallback: _titleController.text,
      );
      _descriptionController.text = result.stringValue(
        'description',
        fallback: result.stringValue(
          'instructions',
          fallback: _descriptionController.text,
        ),
      );
      final skills = result.stringList('skills');
      if (skills.isNotEmpty) _skillsController.text = skills.join(', ');
      final duration = result.intValue(
        'durationMinutes',
        fallback: int.tryParse(_timeController.text.trim()) ?? 30,
      );
      _timeController.text = duration.toString();
      _passingController.text = result
          .intValue(
            'passingScore',
            fallback: int.tryParse(_passingController.text.trim()) ?? 1,
          )
          .toString();
      for (final question in _questions) {
        question.dispose();
      }
      _questions
        ..clear()
        ..addAll(result.mapList('questions').map(_QuestionDraft.fromAiMap));
      if (_questions.isEmpty) _questions.add(_QuestionDraft());
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final questions = <McqQuestionModel>[];
    for (var index = 0; index < _questions.length; index++) {
      final draft = _questions[index];
      final options = draft.options.text
          .split('\n')
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toList();
      final correct = draft.correctAnswer.text.trim();
      if (options.length < 2) {
        _showError('Question ${index + 1} needs at least two options.');
        return;
      }
      if (!options.any(
        (option) => option.toLowerCase() == correct.toLowerCase(),
      )) {
        _showError(
          'Question ${index + 1} correct answer must exactly match an option.',
        );
        return;
      }
      questions.add(
        McqQuestionModel(
          questionId: draft.questionId,
          question: draft.question.text.trim(),
          options: options,
          correctAnswer: correct,
          marksPerQuestion: int.parse(draft.marks.text.trim()),
          explanation: draft.explanation.text.trim(),
        ),
      );
    }

    setState(() => _hasUnsavedChanges = false);
    widget.onSubmit(
      _AssignmentFormData(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        skillsCovered: _commaList(_skillsController),
        passingMarks: int.parse(_passingController.text.trim()),
        totalMarks: _totalMarks(),
        timeLimitMinutes: int.parse(_timeController.text.trim()),
        dueDate: DateTime.tryParse(_dueDateController.text.trim()),
        questions: uniquifyMcqQuestionIds(questions),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _QuestionDraft {
  _QuestionDraft()
    : questionId = createMcqQuestionId(),
      question = TextEditingController(),
      options = TextEditingController(text: 'Option A\nOption B'),
      correctAnswer = TextEditingController(),
      marks = TextEditingController(text: '1'),
      explanation = TextEditingController();

  _QuestionDraft.fromModel(McqQuestionModel model)
    : questionId = model.questionId,
      question = TextEditingController(text: model.question),
      options = TextEditingController(text: model.options.join('\n')),
      correctAnswer = TextEditingController(text: model.correctAnswer),
      marks = TextEditingController(text: model.marksPerQuestion.toString()),
      explanation = TextEditingController(text: model.explanation);

  _QuestionDraft.fromAiMap(Map<String, dynamic> data)
    : questionId = createMcqQuestionId(),
      question = TextEditingController(
        text: data['question']?.toString() ?? '',
      ),
      options = TextEditingController(
        text: data['options'] is Iterable
            ? (data['options'] as Iterable)
                  .map((option) => option?.toString() ?? '')
                  .where((option) => option.trim().isNotEmpty)
                  .join('\n')
            : 'Option A\nOption B',
      ),
      correctAnswer = TextEditingController(
        text: data['correctAnswer']?.toString() ?? '',
      ),
      marks = TextEditingController(
        text: (data['marks'] ?? data['points'] ?? 1).toString(),
      ),
      explanation = TextEditingController(
        text: data['explanation']?.toString() ?? '',
      );

  final String questionId;
  final TextEditingController question;
  final TextEditingController options;
  final TextEditingController correctAnswer;
  final TextEditingController marks;
  final TextEditingController explanation;

  void dispose() {
    question.dispose();
    options.dispose();
    correctAnswer.dispose();
    marks.dispose();
    explanation.dispose();
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.onMarksChanged,
  });

  final int index;
  final _QuestionDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onMarksChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      padding: const EdgeInsets.all(24),
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
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  color: Colors.red,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 20),
          CoursePremiumTextField(
            controller: draft.question,
            label: 'Question prompt',
            hintText: 'What is the purpose of...?',
            minLines: 2,
            maxLines: 4,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          CoursePremiumTextField(
            controller: draft.options,
            label: 'Answer Options',
            hintText: 'Write each option on a new line',
            minLines: 3,
            maxLines: 6,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 500;
              final fields = [
                CoursePremiumTextField(
                  controller: draft.correctAnswer,
                  label: 'Correct Answer',
                  hintText: 'Must EXACTLY match one option',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                CoursePremiumTextField(
                  controller: draft.marks,
                  label: 'Marks',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onMarksChanged(),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a positive number';
                    }
                    return null;
                  },
                ),
              ];

              if (!isWide) {
                return Column(
                  children: [fields[0], const SizedBox(height: 20), fields[1]],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: fields[0]),
                  const SizedBox(width: 20),
                  Expanded(flex: 1, child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          CoursePremiumTextField(
            controller: draft.explanation,
            label: 'Explanation (Optional)',
            hintText: 'Shown after student answers',
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.color,
    required this.children,
    this.trailing,
  });

  final String title;
  final Color color;
  final List<Widget> children;
  final Widget? trailing;

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
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _AssignmentFormData {
  const _AssignmentFormData({
    required this.title,
    required this.description,
    required this.skillsCovered,
    required this.passingMarks,
    required this.totalMarks,
    required this.timeLimitMinutes,
    required this.dueDate,
    required this.questions,
  });

  final String title;
  final String description;
  final List<String> skillsCovered;
  final int passingMarks;
  final int totalMarks;
  final int timeLimitMinutes;
  final DateTime? dueDate;
  final List<McqQuestionModel> questions;
}
