import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../models/user_role.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../../ai_usage/widgets/skillforge_ai_widgets.dart';
import '../../../courses/presentation/course_premium_widgets.dart';
import '../models/ai_course_blueprint_model.dart';
import '../models/ai_course_requirement_model.dart';
import '../providers/teacher_ai_course_builder_provider.dart';
import '../services/ai_course_blueprint_validator.dart';

class TeacherAiCourseBuilderScreen extends ConsumerStatefulWidget {
  const TeacherAiCourseBuilderScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  ConsumerState<TeacherAiCourseBuilderScreen> createState() =>
      _TeacherAiCourseBuilderScreenState();
}

class _TeacherAiCourseBuilderScreenState
    extends ConsumerState<TeacherAiCourseBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _topicController;
  final _audienceController = TextEditingController(text: 'Beginners');
  final _levelController = TextEditingController(text: 'Beginner');
  final _weeksController = TextEditingController(text: '4');
  final _moduleCountController = TextEditingController(text: '4');
  final _lessonCountController = TextEditingController(text: '8');
  final _lessonDistributionController = TextEditingController();
  final _assignmentCountController = TextEditingController(text: '4');
  final _assignmentQuestionController = TextEditingController(text: '5');
  final _assignmentQuestionCountsController = TextEditingController();
  final _quizCountController = TextEditingController(text: '4');
  final _quizQuestionController = TextEditingController(text: '5');
  final _quizQuestionCountsController = TextEditingController();
  final _grandTestCountController = TextEditingController(text: '1');
  final _grandTestQuestionController = TextEditingController(text: '20');
  final _grandTestQuestionCountsController = TextEditingController();
  final _goalsController = TextEditingController();
  final _extraController = TextEditingController();
  final _titleEditController = TextEditingController();
  final _descriptionEditController = TextEditingController();
  bool _includeAssignments = true;
  bool _includeQuizzes = true;
  bool _includeGrandTest = true;
  bool _useCustomLessonDistribution = false;
  bool _useCustomAssignmentQuestionCounts = false;
  bool _useCustomQuizQuestionCounts = false;
  bool _useCustomGrandTestQuestionCounts = false;
  bool _avoidDuplicateQuestions = true;
  bool _requireUniqueLessons = true;
  String _assignmentType = 'mixed';
  String _difficultyLevel = 'beginner';
  String _languageStyle = 'mixed';
  String _contentDepth = 'normal';

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialPrompt ?? '');
  }

  @override
  void dispose() {
    _topicController.dispose();
    _audienceController.dispose();
    _levelController.dispose();
    _weeksController.dispose();
    _moduleCountController.dispose();
    _lessonCountController.dispose();
    _lessonDistributionController.dispose();
    _assignmentCountController.dispose();
    _assignmentQuestionController.dispose();
    _assignmentQuestionCountsController.dispose();
    _quizCountController.dispose();
    _quizQuestionController.dispose();
    _quizQuestionCountsController.dispose();
    _grandTestCountController.dispose();
    _grandTestQuestionController.dispose();
    _grandTestQuestionCountsController.dispose();
    _goalsController.dispose();
    _extraController.dispose();
    _titleEditController.dispose();
    _descriptionEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherAiCourseBuilderProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'AI Course Builder',
      subtitle: 'Generate, review, and save a teacher-approved course draft.',
      showBackButton: true,
      onBack: () => context.goNamed(RouteNames.teacherCourses),
      scrollable: false,
      child: CoursePremiumBackground(
        child: CoursePremiumListView(
          bottomPadding: 96,
          children: [
            CourseHeroHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Create Course with SkillForge AI',
              subtitle:
                  'AI drafts the blueprint. You review, edit, save draft, and publish only after confirmation.',
              trailing: FilledButton.tonalIcon(
                onPressed: state.isGenerating
                    ? null
                    : () => ref
                          .read(teacherAiCourseBuilderProvider.notifier)
                          .reset(),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),
            ),
            const SizedBox(height: 20),
            const SkillForgeAiCreditBalanceCard(compact: true),
            const SizedBox(height: 12),
            const SkillForgeAiReviewWarning(),
            const SizedBox(height: 20),
            _SafetyNotice(state: state),
            const SizedBox(height: 20),
            if (state.currentStep <= 1)
              _requirementsCard(onGenerate: _generate),
            if (state.isGenerating) ...[
              const SizedBox(height: 20),
              const _GeneratingCard(),
            ],
            if (state.blueprint != null) ...[
              const SizedBox(height: 20),
              _BlueprintPreviewCard(
                blueprint: state.blueprint!,
                requirements: state.requirements,
                validationErrors: state.validationErrors,
                titleController: _titleEditController,
                descriptionController: _descriptionEditController,
                onApplyTextEdits: () {
                  ref
                      .read(teacherAiCourseBuilderProvider.notifier)
                      .updateBlueprintText(
                        title: _titleEditController.text.trim(),
                        description: _descriptionEditController.text.trim(),
                      );
                },
              ),
              const SizedBox(height: 20),
              _SavePublishCard(
                isSaving: state.isSavingDraft,
                isPublishing: state.isPublishing,
                isValid: state.validationErrors.isEmpty,
                onSaveDraft: _saveDraft,
                onPublish: _confirmPublish,
              ),
            ],
            if ((state.errorMessage ?? '').isNotEmpty) ...[
              const SizedBox(height: 20),
              CoursePremiumMessage(
                icon: Icons.error_outline_rounded,
                title: 'AI Course Builder needs attention',
                message: state.errorMessage!,
              ),
              if (state.needsUpgrade) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showTeacherUpgradeDialog(
                    context: context,
                    ref: ref,
                    title: 'Upgrade your teaching plan',
                    message:
                        'Unlock more publishing and premium AI generation limits.',
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Upgrade plan'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    final requirements = _requirements();
    final requirementErrors = requirements.validate();
    if (requirementErrors.isNotEmpty) {
      _show(requirementErrors.join('\n'));
      return;
    }
    await ref
        .read(teacherAiCourseBuilderProvider.notifier)
        .generateCourse(requirements);
    final blueprint = ref.read(teacherAiCourseBuilderProvider).blueprint;
    if (blueprint != null && mounted) {
      _titleEditController.text = blueprint.title;
      _descriptionEditController.text = blueprint.description;
    }
  }

  Future<void> _saveDraft() async {
    final blueprint = ref.read(teacherAiCourseBuilderProvider).blueprint;
    if (blueprint?.sourceProvider == 'templateFallback') {
      final confirmed = await _confirmFallbackReview('save this draft');
      if (confirmed != true) return;
    }
    final success = await ref
        .read(teacherAiCourseBuilderProvider.notifier)
        .saveDraft();
    if (!mounted) return;
    final result = ref
        .read(teacherAiCourseBuilderProvider)
        .materializationResult;
    _show(
      success
          ? 'Draft saved: ${result?.summaryMessage() ?? 'course content saved'}'
          : 'Unable to save draft.',
    );
    if (success) context.goNamed(RouteNames.teacherCourses);
  }

  Future<void> _confirmPublish() async {
    final blueprint = ref.read(teacherAiCourseBuilderProvider).blueprint;
    if (blueprint?.sourceProvider == 'templateFallback') {
      final fallbackConfirmed = await _confirmFallbackReview(
        'publish this course',
      );
      if (fallbackConfirmed != true) return;
      if (!mounted) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish AI-generated course?'),
        content: const Text(
          'Are you sure you want to publish this AI-generated course? Please review all lessons, assignments, quizzes, and grand test before publishing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review more'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(teacherAiCourseBuilderProvider.notifier)
        .publishAfterConfirmation();
    if (!mounted) return;
    final result = ref
        .read(teacherAiCourseBuilderProvider)
        .materializationResult;
    _show(
      success
          ? 'Published: ${result?.summaryMessage() ?? 'course content published'}'
          : 'Unable to publish course.',
    );
    if (success) context.goNamed(RouteNames.teacherCourses);
  }

  Future<bool?> _confirmFallbackReview(String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI draft review required'),
        content: Text(
          'This draft came from an older AI-unavailable flow. Please review the lessons, assignments, quizzes, and grand test carefully before you $action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review more'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I reviewed it'),
          ),
        ],
      ),
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _requirementsCard({required VoidCallback onGenerate}) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 1 - Requirements',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            CoursePremiumTextField(
              controller: _topicController,
              label: 'Course topic/title',
              hintText: 'e.g. Flutter beginner app development',
              validator: _required,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final fields = [
                  CoursePremiumTextField(
                    controller: _audienceController,
                    label: 'Target audience',
                    validator: _required,
                  ),
                  CoursePremiumTextField(
                    controller: _levelController,
                    label: 'Level',
                    validator: _required,
                  ),
                  CoursePremiumTextField(
                    controller: _weeksController,
                    label: 'Duration weeks',
                    keyboardType: TextInputType.number,
                    validator: _required,
                  ),
                ];
                if (!wide) {
                  return Column(
                    children: [
                      for (final field in fields) ...[
                        field,
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: fields
                      .map((field) => SizedBox(width: 320, child: field))
                      .toList(),
                );
              },
            ),
            CoursePremiumTextField(
              controller: _goalsController,
              label: 'Learning goals',
              hintText: 'Write each goal on a new line',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            CoursePremiumTextField(
              controller: _extraController,
              label: 'Extra instructions',
              hintText: 'Audience context, tools, projects, tone...',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _StructureControls(
              moduleCountController: _moduleCountController,
              lessonCountController: _lessonCountController,
              lessonDistributionController: _lessonDistributionController,
              useCustomLessonDistribution: _useCustomLessonDistribution,
              onCustomLessonDistributionChanged: (value) =>
                  setState(() => _useCustomLessonDistribution = value),
            ),
            const SizedBox(height: 16),
            _AssessmentControls(
              includeAssignments: _includeAssignments,
              includeQuizzes: _includeQuizzes,
              includeGrandTest: _includeGrandTest,
              assignmentCountController: _assignmentCountController,
              assignmentQuestionController: _assignmentQuestionController,
              assignmentQuestionCountsController:
                  _assignmentQuestionCountsController,
              useCustomAssignmentQuestionCounts:
                  _useCustomAssignmentQuestionCounts,
              assignmentType: _assignmentType,
              quizCountController: _quizCountController,
              quizQuestionController: _quizQuestionController,
              quizQuestionCountsController: _quizQuestionCountsController,
              useCustomQuizQuestionCounts: _useCustomQuizQuestionCounts,
              grandTestCountController: _grandTestCountController,
              grandTestQuestionController: _grandTestQuestionController,
              grandTestQuestionCountsController:
                  _grandTestQuestionCountsController,
              useCustomGrandTestQuestionCounts:
                  _useCustomGrandTestQuestionCounts,
              onAssignmentTypeChanged: (value) =>
                  setState(() => _assignmentType = value),
              onCustomAssignmentCountsChanged: (value) =>
                  setState(() => _useCustomAssignmentQuestionCounts = value),
              onCustomQuizCountsChanged: (value) =>
                  setState(() => _useCustomQuizQuestionCounts = value),
              onCustomGrandTestCountsChanged: (value) =>
                  setState(() => _useCustomGrandTestQuestionCounts = value),
            ),
            const SizedBox(height: 16),
            _QualityControls(
              difficultyLevel: _difficultyLevel,
              languageStyle: _languageStyle,
              contentDepth: _contentDepth,
              avoidDuplicateQuestions: _avoidDuplicateQuestions,
              requireUniqueLessons: _requireUniqueLessons,
              onDifficultyChanged: (value) =>
                  setState(() => _difficultyLevel = value),
              onLanguageChanged: (value) =>
                  setState(() => _languageStyle = value),
              onDepthChanged: (value) => setState(() => _contentDepth = value),
              onAvoidDuplicatesChanged: (value) =>
                  setState(() => _avoidDuplicateQuestions = value),
              onRequireUniqueLessonsChanged: (value) =>
                  setState(() => _requireUniqueLessons = value),
            ),
            const SizedBox(height: 16),
            CoursePremiumMessage(
              icon: Icons.rule_rounded,
              title: 'Generation estimate',
              message: _requirements().estimateSummary,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: _includeAssignments,
                  label: const Text('Assignments'),
                  onSelected: (value) =>
                      setState(() => _includeAssignments = value),
                ),
                FilterChip(
                  selected: _includeQuizzes,
                  label: const Text('Quizzes'),
                  onSelected: (value) =>
                      setState(() => _includeQuizzes = value),
                ),
                FilterChip(
                  selected: _includeGrandTest,
                  label: const Text('Grand Test'),
                  onSelected: (value) =>
                      setState(() => _includeGrandTest = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Course with SkillForge AI'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  AiCourseRequirementModel _requirements() {
    return AiCourseRequirementModel(
      topic: _topicController.text.trim(),
      targetAudience: _audienceController.text.trim(),
      level: _levelController.text.trim(),
      durationWeeks: _int(_weeksController.text, 4),
      languageStyle: _languageStyle,
      learningGoals: _goalsController.text.trim(),
      includeAssignments: _includeAssignments,
      includeQuizzes: _includeQuizzes,
      includeGrandTest: _includeGrandTest,
      extraInstructions: _extraController.text.trim(),
      moduleCount: _int(_moduleCountController.text, 4),
      totalLessonCount: _int(_lessonCountController.text, 8),
      useCustomLessonDistribution: _useCustomLessonDistribution,
      lessonCountPerModule: _ints(_lessonDistributionController.text),
      assignmentCount: _int(_assignmentCountController.text, 4),
      defaultQuestionsPerAssignment: _int(
        _assignmentQuestionController.text,
        5,
      ),
      useCustomAssignmentQuestionCounts: _useCustomAssignmentQuestionCounts,
      assignmentQuestionCounts: _ints(_assignmentQuestionCountsController.text),
      assignmentType: _assignmentType,
      quizCount: _int(_quizCountController.text, 4),
      defaultQuestionsPerQuiz: _int(_quizQuestionController.text, 5),
      useCustomQuizQuestionCounts: _useCustomQuizQuestionCounts,
      quizQuestionCounts: _ints(_quizQuestionCountsController.text),
      grandTestCount: _int(_grandTestCountController.text, 1),
      defaultQuestionsPerGrandTest: _int(_grandTestQuestionController.text, 20),
      useCustomGrandTestQuestionCounts: _useCustomGrandTestQuestionCounts,
      grandTestQuestionCounts: _ints(_grandTestQuestionCountsController.text),
      difficultyLevel: _difficultyLevel,
      contentDepth: _contentDepth,
      avoidDuplicateQuestions: _avoidDuplicateQuestions,
      requireUniqueLessons: _requireUniqueLessons,
    );
  }
}

int _int(String value, int fallback) => int.tryParse(value.trim()) ?? fallback;

List<int> _ints(String value) => value
    .split(RegExp(r'[\s,]+'))
    .map((item) => int.tryParse(item.trim()))
    .whereType<int>()
    .toList();

class _StructureControls extends StatelessWidget {
  const _StructureControls({
    required this.moduleCountController,
    required this.lessonCountController,
    required this.lessonDistributionController,
    required this.useCustomLessonDistribution,
    required this.onCustomLessonDistributionChanged,
  });

  final TextEditingController moduleCountController;
  final TextEditingController lessonCountController;
  final TextEditingController lessonDistributionController;
  final bool useCustomLessonDistribution;
  final ValueChanged<bool> onCustomLessonDistributionChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Course structure'),
      childrenPadding: const EdgeInsets.only(top: 12),
      children: [
        _ResponsiveFields(
          children: [
            CoursePremiumTextField(
              controller: moduleCountController,
              label: 'Number of modules',
              keyboardType: TextInputType.number,
            ),
            CoursePremiumTextField(
              controller: lessonCountController,
              label: 'Total lessons',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: useCustomLessonDistribution,
          onChanged: onCustomLessonDistributionChanged,
          title: const Text('Custom lesson count per module'),
          subtitle: const Text('Example: 2,2,2,2'),
        ),
        if (useCustomLessonDistribution)
          CoursePremiumTextField(
            controller: lessonDistributionController,
            label: 'Lesson distribution',
            hintText: '2,2,2,2',
          ),
      ],
    );
  }
}

class _AssessmentControls extends StatelessWidget {
  const _AssessmentControls({
    required this.includeAssignments,
    required this.includeQuizzes,
    required this.includeGrandTest,
    required this.assignmentCountController,
    required this.assignmentQuestionController,
    required this.assignmentQuestionCountsController,
    required this.useCustomAssignmentQuestionCounts,
    required this.assignmentType,
    required this.quizCountController,
    required this.quizQuestionController,
    required this.quizQuestionCountsController,
    required this.useCustomQuizQuestionCounts,
    required this.grandTestCountController,
    required this.grandTestQuestionController,
    required this.grandTestQuestionCountsController,
    required this.useCustomGrandTestQuestionCounts,
    required this.onAssignmentTypeChanged,
    required this.onCustomAssignmentCountsChanged,
    required this.onCustomQuizCountsChanged,
    required this.onCustomGrandTestCountsChanged,
  });

  final bool includeAssignments;
  final bool includeQuizzes;
  final bool includeGrandTest;
  final TextEditingController assignmentCountController;
  final TextEditingController assignmentQuestionController;
  final TextEditingController assignmentQuestionCountsController;
  final bool useCustomAssignmentQuestionCounts;
  final String assignmentType;
  final TextEditingController quizCountController;
  final TextEditingController quizQuestionController;
  final TextEditingController quizQuestionCountsController;
  final bool useCustomQuizQuestionCounts;
  final TextEditingController grandTestCountController;
  final TextEditingController grandTestQuestionController;
  final TextEditingController grandTestQuestionCountsController;
  final bool useCustomGrandTestQuestionCounts;
  final ValueChanged<String> onAssignmentTypeChanged;
  final ValueChanged<bool> onCustomAssignmentCountsChanged;
  final ValueChanged<bool> onCustomQuizCountsChanged;
  final ValueChanged<bool> onCustomGrandTestCountsChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Assignments, quizzes, and grand test'),
      childrenPadding: const EdgeInsets.only(top: 12),
      children: [
        if (includeAssignments) ...[
          DropdownButtonFormField<String>(
            initialValue: assignmentType,
            decoration: const InputDecoration(labelText: 'Assignment type'),
            items: const [
              DropdownMenuItem(value: 'mcq', child: Text('MCQ')),
              DropdownMenuItem(value: 'written', child: Text('Written')),
              DropdownMenuItem(value: 'practical', child: Text('Practical')),
              DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
            ],
            onChanged: (value) {
              if (value != null) onAssignmentTypeChanged(value);
            },
          ),
          const SizedBox(height: 12),
          _ResponsiveFields(
            children: [
              CoursePremiumTextField(
                controller: assignmentCountController,
                label: 'Assignments',
                keyboardType: TextInputType.number,
              ),
              CoursePremiumTextField(
                controller: assignmentQuestionController,
                label: 'Questions per assignment',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: useCustomAssignmentQuestionCounts,
            onChanged: onCustomAssignmentCountsChanged,
            title: const Text('Custom assignment question counts'),
            subtitle: const Text('Example: 3,7,10'),
          ),
          if (useCustomAssignmentQuestionCounts)
            CoursePremiumTextField(
              controller: assignmentQuestionCountsController,
              label: 'Assignment question counts',
              hintText: '5,5,5,5',
            ),
        ],
        if (includeQuizzes) ...[
          const SizedBox(height: 12),
          _ResponsiveFields(
            children: [
              CoursePremiumTextField(
                controller: quizCountController,
                label: 'Quizzes',
                keyboardType: TextInputType.number,
              ),
              CoursePremiumTextField(
                controller: quizQuestionController,
                label: 'Questions per quiz',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: useCustomQuizQuestionCounts,
            onChanged: onCustomQuizCountsChanged,
            title: const Text('Custom quiz question counts'),
          ),
          if (useCustomQuizQuestionCounts)
            CoursePremiumTextField(
              controller: quizQuestionCountsController,
              label: 'Quiz question counts',
              hintText: '5,8',
            ),
        ],
        if (includeGrandTest) ...[
          const SizedBox(height: 12),
          _ResponsiveFields(
            children: [
              CoursePremiumTextField(
                controller: grandTestCountController,
                label: 'Grand tests',
                keyboardType: TextInputType.number,
              ),
              CoursePremiumTextField(
                controller: grandTestQuestionController,
                label: 'Questions per grand test',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: useCustomGrandTestQuestionCounts,
            onChanged: onCustomGrandTestCountsChanged,
            title: const Text('Custom grand test question counts'),
            subtitle: const Text('Example: 15,25'),
          ),
          if (useCustomGrandTestQuestionCounts)
            CoursePremiumTextField(
              controller: grandTestQuestionCountsController,
              label: 'Grand test question counts',
              hintText: '20',
            ),
        ],
      ],
    );
  }
}

class _QualityControls extends StatelessWidget {
  const _QualityControls({
    required this.difficultyLevel,
    required this.languageStyle,
    required this.contentDepth,
    required this.avoidDuplicateQuestions,
    required this.requireUniqueLessons,
    required this.onDifficultyChanged,
    required this.onLanguageChanged,
    required this.onDepthChanged,
    required this.onAvoidDuplicatesChanged,
    required this.onRequireUniqueLessonsChanged,
  });

  final String difficultyLevel;
  final String languageStyle;
  final String contentDepth;
  final bool avoidDuplicateQuestions;
  final bool requireUniqueLessons;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onDepthChanged;
  final ValueChanged<bool> onAvoidDuplicatesChanged;
  final ValueChanged<bool> onRequireUniqueLessonsChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Quality controls'),
      childrenPadding: const EdgeInsets.only(top: 12),
      children: [
        _ResponsiveFields(
          children: [
            _DropdownField(
              label: 'Difficulty',
              value: difficultyLevel,
              values: const ['beginner', 'intermediate', 'advanced'],
              onChanged: onDifficultyChanged,
            ),
            _DropdownField(
              label: 'Language style',
              value: languageStyle,
              values: const ['english', 'romanUrdu', 'mixed'],
              onChanged: onLanguageChanged,
            ),
            _DropdownField(
              label: 'Content depth',
              value: contentDepth,
              values: const ['short', 'normal', 'detailed'],
              onChanged: onDepthChanged,
            ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: avoidDuplicateQuestions,
          onChanged: (value) => onAvoidDuplicatesChanged(value ?? true),
          title: const Text('Avoid duplicate questions'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: requireUniqueLessons,
          onChanged: (value) => onRequireUniqueLessonsChanged(value ?? true),
          title: const Text('Require unique lesson topics'),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: 300, child: child))
              .toList(),
        );
      },
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.state});

  final TeacherAiCourseBuilderState state;

  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.blueprint?.sourceProvider == 'templateFallback'
                  ? 'This is an older AI-unavailable draft. No Firestore write happens until Save Draft or Publish.'
                  : 'AI can make mistakes. Review before saving or publishing. Generation does not write Firestore.',
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratingCard extends StatelessWidget {
  const _GeneratingCard();

  @override
  Widget build(BuildContext context) {
    return const CourseGlassCard(
      padding: EdgeInsets.all(24),
      child: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 18),
          Expanded(
            child: Text('Generating course blueprint with SkillForge AI...'),
          ),
        ],
      ),
    );
  }
}

class _BlueprintPreviewCard extends StatelessWidget {
  const _BlueprintPreviewCard({
    required this.blueprint,
    required this.requirements,
    required this.validationErrors,
    required this.titleController,
    required this.descriptionController,
    required this.onApplyTextEdits,
  });

  final AiCourseBlueprintModel blueprint;
  final AiCourseRequirementModel? requirements;
  final List<String> validationErrors;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final VoidCallback onApplyTextEdits;

  @override
  Widget build(BuildContext context) {
    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(label: Text(blueprint.sourceLabel)),
              if ((blueprint.aiModel ?? '').trim().isNotEmpty)
                Chip(label: Text('Model: ${blueprint.aiModel}')),
              if (blueprint.totalTokens != null)
                Chip(label: Text('${blueprint.totalTokens} tokens')),
              if (blueprint.repairedItemCount > 0)
                Chip(label: Text('${blueprint.repairedItemCount} repaired')),
              if (blueprint.fallbackItemCount > 0)
                Chip(label: Text('${blueprint.fallbackItemCount} repaired')),
              Chip(label: Text('${blueprint.modules.length} modules')),
              Chip(label: Text('${blueprint.totalLessonCount} lessons')),
              Chip(
                label: Text('${blueprint.totalAssignmentCount} assignments'),
              ),
              Chip(label: Text('${blueprint.totalQuizCount} quizzes')),
              Chip(
                label: Text(
                  '${blueprint.effectiveGrandTests.length} grand tests',
                ),
              ),
            ],
          ),
          if (requirements != null) ...[
            const SizedBox(height: 14),
            _CountSummary(
              requirements: requirements!,
              blueprint: blueprint,
              validationErrors: validationErrors,
            ),
          ],
          if (blueprint.sourceProvider == 'templateFallback') ...[
            const SizedBox(height: 14),
            CoursePremiumMessage(
              icon: Icons.info_outline_rounded,
              title: 'AI unavailable draft',
              message: [
                'This is a legacy AI-unavailable draft. New AI failures now show a retryable error instead of generated template content.',
                if ((blueprint.parseWarning ?? '').trim().isNotEmpty)
                  blueprint.parseWarning!,
                if ((blueprint.fallbackReason ?? '').trim().isNotEmpty)
                  'Reason: ${blueprint.fallbackReason}',
                'Review carefully before saving or publishing.',
              ].join('\n'),
            ),
          ],
          if (blueprint.normalizedContentSource.endsWith('WithRepair')) ...[
            const SizedBox(height: 14),
            CoursePremiumMessage(
              icon: Icons.construction_rounded,
              title: '${blueprint.sourceLabel} applied',
              message: [
                'OpenAI content was preserved where valid.',
                'Some missing or invalid items were repaired locally to match your selected counts.',
                if (blueprint.qualityWarnings.isNotEmpty)
                  ...blueprint.qualityWarnings.take(3),
              ].join('\n'),
            ),
          ],
          const SizedBox(height: 16),
          CoursePremiumTextField(
            controller: titleController,
            label: 'Editable title',
          ),
          const SizedBox(height: 12),
          CoursePremiumTextField(
            controller: descriptionController,
            label: 'Editable description',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onApplyTextEdits,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply text edits'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Blueprint Preview',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _BulletSection(
            title: 'Learning outcomes',
            items: blueprint.learningOutcomes,
          ),
          _BulletSection(
            title: 'Prerequisites',
            items: blueprint.prerequisites,
          ),
          for (final module in blueprint.modules)
            _ModulePreview(module: module),
          for (final grandTest in blueprint.effectiveGrandTests)
            _GrandTestPreview(grandTest: grandTest),
          _BulletSection(
            title: 'Grading rubric',
            items: blueprint.gradingRubric,
          ),
          _BulletSection(
            title: 'Certificate criteria',
            items: blueprint.certificateCriteria,
          ),
        ],
      ),
    );
  }
}

class _ModulePreview extends StatelessWidget {
  const _ModulePreview({required this.module});

  final AiCourseModuleBlueprintModel module;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Module ${module.order}: ${module.title}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(module.description),
          const SizedBox(height: 12),
          for (final lesson in module.lessons)
            _BlueprintItemCard(
              icon: Icons.play_lesson_rounded,
              badge: 'Creates Lesson',
              title: '${lesson.order}. ${lesson.title}',
              subtitle: lesson.objective,
              body: [
                if (lesson.summary.trim().isNotEmpty) lesson.summary,
                if (lesson.contentOutline.isNotEmpty)
                  'Outline: ${lesson.contentOutline.join(', ')}',
                if (lesson.practiceTasks.isNotEmpty)
                  'Practice: ${lesson.practiceTasks.join(', ')}',
                'Duration: ${lesson.durationMinutes} minutes',
              ],
            ),
          for (final assignment in module.assignments)
            _BlueprintItemCard(
              icon: Icons.assignment_turned_in_rounded,
              badge: 'Creates Project Assignment',
              title: assignment.title,
              subtitle: assignment.instructions,
              body: [
                if (assignment.rubric.isNotEmpty)
                  'Rubric: ${assignment.rubric.join(', ')}',
                'Marks: ${assignment.points <= 0 ? 100 : assignment.points}',
                'Due offset: ${assignment.dueOffsetDays <= 0 ? 7 : assignment.dueOffsetDays} days',
              ],
            ),
          if (module.quiz.questions.isNotEmpty)
            _BlueprintItemCard(
              icon: Icons.quiz_rounded,
              badge: 'Creates MCQ Assignment',
              title: module.quiz.title,
              subtitle:
                  'Passing score: ${module.quiz.passingScore}% • ${module.quiz.points} points',
              body: module.quiz.questions
                  .map(
                    (question) =>
                        '${question.question}\nCorrect: ${question.correctAnswer}',
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _CountSummary extends StatelessWidget {
  const _CountSummary({
    required this.requirements,
    required this.blueprint,
    required this.validationErrors,
  });

  final AiCourseRequirementModel requirements;
  final AiCourseBlueprintModel blueprint;
  final List<String> validationErrors;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Modules', requirements.moduleCount, blueprint.modules.length),
      ('Lessons', requirements.totalLessonCount, blueprint.totalLessonCount),
      (
        'Assignments',
        requirements.effectiveAssignmentCount,
        blueprint.totalAssignmentCount,
      ),
      (
        'Assignment questions',
        requirements.expectedAssignmentQuestionTotal,
        blueprint.totalAssignmentQuestionCount,
      ),
      ('Quizzes', requirements.effectiveQuizCount, blueprint.totalQuizCount),
      (
        'Quiz questions',
        requirements.expectedQuizQuestionTotal,
        blueprint.totalQuizQuestionCount,
      ),
      (
        'Grand tests',
        requirements.effectiveGrandTestCount,
        blueprint.effectiveGrandTests.length,
      ),
      (
        'Grand test questions',
        requirements.expectedGrandTestQuestionTotal,
        blueprint.totalGrandTestQuestionCount,
      ),
    ];
    final validation = const AiCourseBlueprintValidator().validate(
      blueprint: blueprint,
      requirements: requirements,
    );
    final valid = validationErrors.isEmpty;
    return CoursePremiumMessage(
      icon: valid ? Icons.verified_rounded : Icons.warning_amber_rounded,
      title:
          '${validation.qualityStatus} blueprint • ${validation.qualityScore}/100',
      message: [
        ...rows.map(
          (row) => '${row.$1}: Expected ${row.$2} / Generated ${row.$3}',
        ),
        if (validationErrors.isNotEmpty) ...['', ...validationErrors.take(6)],
      ].join('\n'),
    );
  }
}

class _GrandTestPreview extends StatelessWidget {
  const _GrandTestPreview({required this.grandTest});

  final AiGrandTestBlueprintModel grandTest;

  @override
  Widget build(BuildContext context) {
    if (grandTest.totalPoints <= 0 && grandTest.questions.isEmpty) {
      return const SizedBox.shrink();
    }
    return _BlueprintItemCard(
      icon: Icons.workspace_premium_rounded,
      badge: 'Creates Grand Test',
      title: grandTest.title,
      subtitle: grandTest.description,
      body: [
        if ((grandTest.practicalTask ?? '').trim().isNotEmpty)
          'Practical task: ${grandTest.practicalTask}',
        'Passing score: ${grandTest.passingScore}%',
        'Total points: ${grandTest.totalPoints}',
        if (grandTest.questions.isEmpty)
          'No direct grand test MCQs supplied. Module quiz questions will be reused safely where possible.',
        ...grandTest.questions
            .take(6)
            .map(
              (question) =>
                  '${question.question}\nCorrect: ${question.correctAnswer}',
            ),
      ],
    );
  }
}

class _BlueprintItemCard extends StatelessWidget {
  const _BlueprintItemCard({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              Chip(visualDensity: VisualDensity.compact, label: Text(badge)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...body
                .where((item) => item.trim().isNotEmpty)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(item),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $item'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavePublishCard extends StatelessWidget {
  const _SavePublishCard({
    required this.isSaving,
    required this.isPublishing,
    required this.isValid,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final bool isSaving;
  final bool isPublishing;
  final bool isValid;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final busy = isSaving || isPublishing;
    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: busy || !isValid ? null : onSaveDraft,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Save as Draft'),
          ),
          FilledButton.icon(
            onPressed: busy || !isValid ? null : onPublish,
            icon: isPublishing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_rounded),
            label: const Text('Publish Course'),
          ),
        ],
      ),
    );
  }
}
