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
import '../data/models/grand_test_model.dart';
import '../data/models/mcq_assignment_model.dart';
import '../providers/grand_test_provider.dart';
import 'course_premium_widgets.dart';

class CreateEditGrandTestScreen extends ConsumerWidget {
  const CreateEditGrandTestScreen({
    super.key,
    required this.courseId,
    this.grandTestId,
  });

  final String courseId;
  final String? grandTestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = grandTestId;
    if (id == null || id.isEmpty) return _Scaffold(courseId: courseId);

    final testAsync = ref.watch(
      grandTestDetailProvider((courseId: courseId, grandTestId: id)),
    );
    return testAsync.when(
      loading: () => const RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Exam',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Exam',
        showBackButton: true,
        child: Center(child: Text(error.toString())),
      ),
      data: (test) {
        if (test == null) {
          return const RoleFixedHeaderPage(
            role: UserRole.teacher,
            title: 'Exam unavailable',
            showBackButton: true,
            child: Center(child: Text('Grand test not found.')),
          );
        }
        return _Scaffold(courseId: courseId, test: test);
      },
    );
  }
}

class _Scaffold extends ConsumerWidget {
  const _Scaffold({required this.courseId, this.test});

  final String courseId;
  final GrandTestModel? test;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(grandTestActionProvider);
    final isEditing = test != null;

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: isEditing ? 'Edit Config' : 'Exam Builder Studio',
      subtitle: 'Configure questions, timing, scoring, and eligibility rules.',
      showBackButton: true,
      onBack: () => _goBack(context),
      scrollable: false,
      child: CoursePremiumBackground(
        child: _GrandTestForm(
          courseId: courseId,
          test: test,
          isSubmitting: actionState.isLoading,
          onSubmit: (data) => _save(context, ref, data),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    _GrandTestFormData data,
  ) async {
    final now = DateTime.now();
    final current = test;
    final model = GrandTestModel(
      grandTestId: current?.grandTestId ?? '',
      courseId: courseId,
      teacherId: current?.teacherId ?? '',
      title: data.title,
      description: data.description,
      instructions: data.instructions,
      skillsCovered: data.skillsCovered,
      totalMarks: data.totalMarks,
      passingMarks: data.passingMarks,
      durationMinutes: data.durationMinutes,
      difficulty: data.difficulty,
      status: current?.status ?? AssignmentStatus.draft,
      questions: data.questions,
      requiredLessonProgressPercent: data.requiredLessonProgressPercent,
      requiredAssignmentCompletionPercent:
          data.requiredAssignmentCompletionPercent,
      requiredAverageScorePercent: data.requiredAverageScorePercent,
      requireProjectSubmission: data.requireProjectSubmission,
      maxAttempts: data.maxAttempts,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
      publishedAt: current?.publishedAt,
      archivedAt: current?.archivedAt,
    );

    final notifier = ref.read(grandTestActionProvider.notifier);
    final success = current == null
        ? await notifier.createGrandTest(model)
        : await notifier.updateGrandTest(model);
    if (!context.mounted) return;
    final message = success
        ? 'Grand test saved successfully.'
        : notifier.errorMessage ?? 'Unable to save grand test.';
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
      RouteNames.teacherGrandTests,
      pathParameters: {'courseId': courseId},
    );
  }
}

class _GrandTestForm extends StatefulWidget {
  const _GrandTestForm({
    required this.courseId,
    required this.onSubmit,
    this.test,
    this.isSubmitting = false,
  });

  final String courseId;
  final GrandTestModel? test;
  final ValueChanged<_GrandTestFormData> onSubmit;
  final bool isSubmitting;

  @override
  State<_GrandTestForm> createState() => _GrandTestFormState();
}

class _GrandTestFormState extends State<_GrandTestForm> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = TeacherAiGenerationService();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _instructions;
  late final TextEditingController _skills;
  late final TextEditingController _passingMarks;
  late final TextEditingController _duration;
  late final TextEditingController _difficulty;
  late final TextEditingController _lessonReq;
  late final TextEditingController _assignmentReq;
  late final TextEditingController _scoreReq;
  late final TextEditingController _maxAttempts;
  late bool _requireProject;
  late final List<_QuestionDraft> _questions;
  bool _isAiGenerating = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final test = widget.test;
    _title = TextEditingController(text: test?.title ?? '');
    _description = TextEditingController(text: test?.description ?? '');
    _instructions = TextEditingController(text: test?.instructions ?? '');
    _skills = TextEditingController(text: test?.skillsCovered.join(', ') ?? '');
    _passingMarks = TextEditingController(
      text: test == null ? '50' : test.passingMarks.toString(),
    );
    _duration = TextEditingController(
      text: test == null ? '90' : test.durationMinutes.toString(),
    );
    _difficulty = TextEditingController(text: test?.difficulty ?? 'Hard');
    _lessonReq = TextEditingController(
      text: (test?.requiredLessonProgressPercent ?? 80).toStringAsFixed(0),
    );
    _assignmentReq = TextEditingController(
      text: (test?.requiredAssignmentCompletionPercent ?? 70).toStringAsFixed(
        0,
      ),
    );
    _scoreReq = TextEditingController(
      text: (test?.requiredAverageScorePercent ?? 60).toStringAsFixed(0),
    );
    _maxAttempts = TextEditingController(
      text: test == null ? '1' : test.maxAttempts.toString(),
    );
    _requireProject = test?.requireProjectSubmission ?? true;
    _questions =
        test?.questions
            .map((question) => _QuestionDraft.fromModel(question))
            .toList() ??
        [_QuestionDraft()];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _instructions.dispose();
    _skills.dispose();
    _passingMarks.dispose();
    _duration.dispose();
    _difficulty.dispose();
    _lessonReq.dispose();
    _assignmentReq.dispose();
    _scoreReq.dispose();
    _maxAttempts.dispose();
    for (final question in _questions) {
      question.dispose();
    }
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
                    widget.test == null
                        ? 'Exam Builder Studio'
                        : 'Edit Exam Configuration',
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
                      label: 'Generate Grand Test with AI',
                      onPressed: _generateGrandTestWithAi,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '1. Test Overview',
                    color: AppColors.primary,
                    children: [
                      CoursePremiumTextField(
                        controller: _title,
                        label: 'Exam Title',
                        hintText: 'e.g. Master Course Final Exam',
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _description,
                        label: 'Description',
                        hintText: 'What is the purpose of this exam?',
                        minLines: 2,
                        maxLines: 4,
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _skills,
                        label: 'Skills Evaluated',
                        hintText: 'Comma separated e.g. Node.js, System Design',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '2. Rules & Instructions',
                    color: AppColors.secondary,
                    children: [
                      CoursePremiumTextField(
                        controller: _instructions,
                        label: 'Student Instructions',
                        hintText:
                            'e.g. This exam is strictly timed. No pausing allowed.',
                        minLines: 3,
                        maxLines: 6,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '3. Timing & Scoring Config',
                    color: Colors.orange,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 500;
                          final fields = [
                            CoursePremiumTextField(
                              controller: _duration,
                              label: 'Duration (Minutes)',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _required,
                            ),
                            CoursePremiumTextField(
                              controller: _passingMarks,
                              label: 'Passing Marks',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _required,
                            ),
                            CoursePremiumTextField(
                              controller: _difficulty,
                              label: 'Difficulty Level',
                              hintText: 'e.g. Hard, Expert',
                              validator: _required,
                            ),
                          ];

                          if (!isWide) {
                            return Column(
                              children: [
                                fields[0],
                                const SizedBox(height: 20),
                                fields[1],
                                const SizedBox(height: 20),
                                fields[2],
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
                  const SizedBox(height: 24),
                  _Section(
                    title: '4. Eligibility Rules',
                    color: Colors.purple,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 500;
                          final fields = [
                            CoursePremiumTextField(
                              controller: _lessonReq,
                              label: 'Min Lesson Progress (%)',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _required,
                            ),
                            CoursePremiumTextField(
                              controller: _assignmentReq,
                              label: 'Min Assignment Completion (%)',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _required,
                            ),
                            CoursePremiumTextField(
                              controller: _scoreReq,
                              label: 'Min Average Score (%)',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _required,
                            ),
                          ];

                          if (!isWide) {
                            return Column(
                              children: [
                                fields[0],
                                const SizedBox(height: 20),
                                fields[1],
                                const SizedBox(height: 20),
                                fields[2],
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
                      const SizedBox(height: 20),
                      CoursePremiumTextField(
                        controller: _maxAttempts,
                        label: 'Maximum Allowed Attempts',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? AppColors.divider
                                : AppColors.lightDivider,
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          value: _requireProject,
                          activeThumbColor: Colors.purple,
                          onChanged: (value) =>
                              setState(() => _requireProject = value),
                          title: const Text(
                            'Require project submission prior to exam (if projects exist)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '5. Questions Bank',
                    color: Colors.teal,
                    trailing: FilledButton.tonalIcon(
                      onPressed: () =>
                          setState(() => _questions.add(_QuestionDraft())),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.withValues(alpha: 0.15),
                        foregroundColor: Colors.teal,
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
                        : const Icon(
                            Icons.security_rounded,
                            color: Colors.white,
                          ),
                    label: Text(
                      widget.isSubmitting
                          ? 'Securing Configuration...'
                          : 'Save Exam Configuration',
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

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  List<String> _commaList(TextEditingController controller) {
    return controller.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int _totalMarks() {
    return _questions.fold<int>(0, (total, question) {
      return total + (int.tryParse(question.marks.text.trim()) ?? 0);
    });
  }

  Future<void> _generateGrandTestWithAi() async {
    final config = await TeacherAiRequirementDialog.show(
      context: context,
      taskType: TeacherAiTaskType.grandTestBuilder,
      title: 'AI Grand Test Requirements',
      initialTopic: _title.text.trim().isEmpty
          ? 'this course'
          : _title.text.trim(),
      initialQuestionCount: _questions.length < 10 ? 10 : _questions.length,
      initialDurationMinutes: int.tryParse(_duration.text.trim()),
      initialTotalPoints: _totalMarks() <= 0 ? 100 : _totalMarks(),
    );
    if (!mounted || config == null) return;
    setState(() => _isAiGenerating = true);
    try {
      final result = await _aiService.generate(
        TeacherAiGenerationRequestModel(
          taskType: TeacherAiTaskType.grandTestBuilder,
          prompt: config.prompt,
          courseId: widget.courseId,
          currentTitle: _title.text.trim(),
          currentDescription: _description.text.trim(),
          skills: _commaList(_skills),
          questionCount: config.questionCount,
          durationMinutes: config.durationMinutes,
          difficulty: config.difficulty,
          extraContext: {
            'targetScreen': 'grandTestEditor',
            'manualApplyOnly': true,
            ...config.extraContext,
          },
        ),
      );
      if (!mounted) return;
      final apply = await TeacherAiPreviewDialog.show(context, result);
      if (!mounted || !apply) return;
      _applyAiGrandTest(result);
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  void _applyAiGrandTest(TeacherAiGenerationResultModel result) {
    setState(() {
      _title.text = result.stringValue('title', fallback: _title.text);
      _description.text = result.stringValue(
        'description',
        fallback: _description.text,
      );
      _instructions.text = result.stringValue(
        'instructions',
        fallback: [
          _instructions.text,
          result.stringValue('practicalTask'),
          ...result.stringList('rubric').map((item) => 'Rubric: $item'),
        ].where((item) => item.trim().isNotEmpty).join('\n\n'),
      );
      final skills = result.stringList('skills');
      if (skills.isNotEmpty) _skills.text = skills.join(', ');
      _duration.text = result
          .intValue(
            'durationMinutes',
            fallback: int.tryParse(_duration.text.trim()) ?? 90,
          )
          .toString();
      _difficulty.text = result.stringValue(
        'difficulty',
        fallback: _difficulty.text,
      );
      _passingMarks.text = result
          .intValue(
            'passingScore',
            fallback: int.tryParse(_passingMarks.text.trim()) ?? 50,
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
    final questions = <GrandTestQuestionModel>[];
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
          'Question ${index + 1} correct answer must EXACTLY match an option.',
        );
        return;
      }
      questions.add(
        GrandTestQuestionModel(
          questionId: draft.questionId,
          question: draft.question.text.trim(),
          options: options,
          correctAnswer: correct,
          marks: int.parse(draft.marks.text.trim()),
          explanation: draft.explanation.text.trim(),
          difficulty: draft.difficulty.text.trim(),
          skillTag: draft.skillTag.text.trim(),
        ),
      );
    }
    final totalMarks = questions.fold<int>(
      0,
      (sum, question) => sum + question.marks,
    );
    setState(() => _hasUnsavedChanges = false);
    widget.onSubmit(
      _GrandTestFormData(
        title: _title.text.trim(),
        description: _description.text.trim(),
        instructions: _instructions.text.trim(),
        skillsCovered: _commaList(_skills),
        totalMarks: totalMarks,
        passingMarks: int.parse(_passingMarks.text.trim()),
        durationMinutes: int.parse(_duration.text.trim()),
        difficulty: _difficulty.text.trim(),
        questions: uniquifyGrandTestQuestionIds(questions),
        requiredLessonProgressPercent: double.parse(_lessonReq.text.trim()),
        requiredAssignmentCompletionPercent: double.parse(
          _assignmentReq.text.trim(),
        ),
        requiredAverageScorePercent: double.parse(_scoreReq.text.trim()),
        requireProjectSubmission: _requireProject,
        maxAttempts: int.parse(_maxAttempts.text.trim()),
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
      explanation = TextEditingController(),
      difficulty = TextEditingController(text: 'Medium'),
      skillTag = TextEditingController();

  _QuestionDraft.fromModel(GrandTestQuestionModel model)
    : questionId = model.questionId,
      question = TextEditingController(text: model.question),
      options = TextEditingController(text: model.options.join('\n')),
      correctAnswer = TextEditingController(text: model.correctAnswer),
      marks = TextEditingController(text: model.marks.toString()),
      explanation = TextEditingController(text: model.explanation),
      difficulty = TextEditingController(text: model.difficulty),
      skillTag = TextEditingController(text: model.skillTag);

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
      ),
      difficulty = TextEditingController(
        text: data['difficulty']?.toString() ?? 'Medium',
      ),
      skillTag = TextEditingController(
        text: data['skillTag']?.toString() ?? '',
      );

  final String questionId;
  final TextEditingController question;
  final TextEditingController options;
  final TextEditingController correctAnswer;
  final TextEditingController marks;
  final TextEditingController explanation;
  final TextEditingController difficulty;
  final TextEditingController skillTag;

  void dispose() {
    question.dispose();
    options.dispose();
    correctAnswer.dispose();
    marks.dispose();
    explanation.dispose();
    difficulty.dispose();
    skillTag.dispose();
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _QuestionDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;

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
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.teal,
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
            hintText: 'What is the correct syntax for...?',
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
          CoursePremiumTextField(
            controller: draft.correctAnswer,
            label: 'Correct Answer',
            hintText: 'Must EXACTLY match one option',
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 500;
              final fields = [
                CoursePremiumTextField(
                  controller: draft.marks,
                  label: 'Marks',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                CoursePremiumTextField(
                  controller: draft.difficulty,
                  label: 'Difficulty',
                  hintText: 'e.g. Medium',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                CoursePremiumTextField(
                  controller: draft.skillTag,
                  label: 'Skill Tag',
                  hintText: 'e.g. Logic',
                ),
              ];

              if (!isWide) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: 20),
                    fields[1],
                    const SizedBox(height: 20),
                    fields[2],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 16),
                  Expanded(child: fields[1]),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: fields[2]),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          CoursePremiumTextField(
            controller: draft.explanation,
            label: 'Explanation (Optional)',
            hintText: 'Shown after student finishes exam',
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

class _GrandTestFormData {
  const _GrandTestFormData({
    required this.title,
    required this.description,
    required this.instructions,
    required this.skillsCovered,
    required this.totalMarks,
    required this.passingMarks,
    required this.durationMinutes,
    required this.difficulty,
    required this.questions,
    required this.requiredLessonProgressPercent,
    required this.requiredAssignmentCompletionPercent,
    required this.requiredAverageScorePercent,
    required this.requireProjectSubmission,
    required this.maxAttempts,
  });

  final String title;
  final String description;
  final String instructions;
  final List<String> skillsCovered;
  final int totalMarks;
  final int passingMarks;
  final int durationMinutes;
  final String difficulty;
  final List<GrandTestQuestionModel> questions;
  final double requiredLessonProgressPercent;
  final double requiredAssignmentCompletionPercent;
  final double requiredAverageScorePercent;
  final bool requireProjectSubmission;
  final int maxAttempts;
}
