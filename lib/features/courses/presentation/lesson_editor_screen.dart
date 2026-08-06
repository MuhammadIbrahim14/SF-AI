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
import '../../teacher/ai_tools/services/teacher_ai_generation_service.dart';
import '../../teacher/ai_tools/widgets/teacher_ai_generate_button.dart';
import '../../teacher/ai_tools/widgets/teacher_ai_preview_dialog.dart';
import '../data/models/lesson_model.dart';
import '../providers/lesson_provider.dart';
import 'course_premium_widgets.dart';

class LessonEditorScreen extends ConsumerWidget {
  const LessonEditorScreen({super.key, required this.courseId, this.lessonId});

  final String courseId;
  final String? lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = lessonId;
    if (id == null || id.isEmpty) {
      return _LessonEditorScaffold(courseId: courseId);
    }

    final lessonAsync = ref.watch(
      lessonDetailProvider((courseId: courseId, lessonId: id)),
    );
    return lessonAsync.when(
      loading: () => const RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Lesson',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Lesson',
        showBackButton: true,
        child: _LessonMessage(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load lesson',
          message: error.toString(),
        ),
      ),
      data: (lesson) {
        if (lesson == null) {
          return const RoleFixedHeaderPage(
            role: UserRole.teacher,
            title: 'Lesson unavailable',
            showBackButton: true,
            child: _LessonMessage(
              icon: Icons.search_off_rounded,
              title: 'Lesson not found',
              message: 'This lesson may have been archived.',
            ),
          );
        }
        return _LessonEditorScaffold(courseId: courseId, lesson: lesson);
      },
    );
  }
}

class _LessonEditorScaffold extends ConsumerWidget {
  const _LessonEditorScaffold({required this.courseId, this.lesson});

  final String courseId;
  final LessonModel? lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = lesson != null;
    final actionState = ref.watch(lessonActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: isEditing ? 'Edit Lesson' : 'Add Lesson',
      subtitle: 'Structure lesson content, resources, and preview access.',
      showBackButton: true,
      onBack: () => _goBack(context),
      scrollable: false,
      child: CoursePremiumBackground(
        child: _LessonForm(
          courseId: courseId,
          lesson: lesson,
          isSubmitting: actionState.isLoading,
          onSubmit: (data) => _save(context, ref, data),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    _LessonFormData data,
  ) async {
    final notifier = ref.read(lessonActionProvider.notifier);
    final currentLesson = lesson;
    final success = currentLesson == null
        ? await notifier.createLesson(
            courseId: courseId,
            title: data.title,
            description: data.description,
            orderIndex: data.orderIndex,
            videoUrl: data.videoUrl,
            pdfLinks: data.pdfLinks,
            externalLinks: data.externalLinks,
            durationMinutes: data.durationMinutes,
            isPreview: data.isPreview,
            learningObjectives: data.learningObjectives,
            skillsCovered: data.skillsCovered,
            prerequisites: data.prerequisites,
            estimatedMinutes: data.estimatedMinutes,
            keyTakeaways: data.keyTakeaways,
            lessonDifficulty: data.lessonDifficulty,
            completionMode: data.completionMode,
            minimumReadSeconds: data.minimumReadSeconds,
            minimumScrollPercent: data.minimumScrollPercent,
            requireCheckpoints: data.requireCheckpoints,
            requireMiniQuizPass: data.requireMiniQuizPass,
            requirePracticalReflection: data.requirePracticalReflection,
            passingScorePercent: data.passingScorePercent,
            allowRetry: data.allowRetry,
            maxAttempts: data.maxAttempts,
            completionCriteriaSummary: data.completionCriteriaSummary,
            checkpoints: data.checkpoints,
          )
        : await notifier.updateLesson(
            currentLesson.copyWith(
              title: data.title,
              description: data.description,
              orderIndex: data.orderIndex,
              videoUrl: data.videoUrl,
              pdfLinks: data.pdfLinks,
              externalLinks: data.externalLinks,
              durationMinutes: data.durationMinutes,
              isPreview: data.isPreview,
              learningObjectives: data.learningObjectives,
              skillsCovered: data.skillsCovered,
              prerequisites: data.prerequisites,
              estimatedMinutes: data.estimatedMinutes,
              keyTakeaways: data.keyTakeaways,
              lessonDifficulty: data.lessonDifficulty,
              completionMode: data.completionMode,
              minimumReadSeconds: data.minimumReadSeconds,
              minimumScrollPercent: data.minimumScrollPercent,
              requireCheckpoints: data.requireCheckpoints,
              requireMiniQuizPass: data.requireMiniQuizPass,
              requirePracticalReflection: data.requirePracticalReflection,
              passingScorePercent: data.passingScorePercent,
              allowRetry: data.allowRetry,
              maxAttempts: data.maxAttempts,
              completionCriteriaSummary: data.completionCriteriaSummary,
              checkpoints: data.checkpoints,
            ),
          );

    if (!context.mounted) return;

    final message = success
        ? currentLesson == null
              ? 'Lesson created.'
              : 'Lesson updated.'
        : notifier.errorMessage ??
              (currentLesson == null
                  ? 'Unable to create lesson.'
                  : 'Unable to update lesson.');
    if (!success && message.toLowerCase().contains('upgrade')) {
      await showTeacherUpgradeDialog(
        context: context,
        ref: ref,
        message: message,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (success) {
      context.goNamed(
        RouteNames.teacherCourseLessons,
        pathParameters: {'courseId': courseId},
      );
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(
      RouteNames.teacherCourseLessons,
      pathParameters: {'courseId': courseId},
    );
  }
}

class _LessonForm extends StatefulWidget {
  const _LessonForm({
    required this.courseId,
    required this.onSubmit,
    this.lesson,
    this.isSubmitting = false,
  });

  final String courseId;
  final LessonModel? lesson;
  final ValueChanged<_LessonFormData> onSubmit;
  final bool isSubmitting;

  @override
  State<_LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends State<_LessonForm> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = TeacherAiGenerationService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late final TextEditingController _videoController;
  late final TextEditingController _pdfController;
  late final TextEditingController _externalController;
  late final TextEditingController _durationController;
  late final TextEditingController _objectivesController;
  late final TextEditingController _skillsController;
  late final TextEditingController _prerequisitesController;
  late final TextEditingController _takeawaysController;
  late final TextEditingController _estimatedMinutesController;
  late final TextEditingController _minimumReadSecondsController;
  late final TextEditingController _minimumScrollPercentController;
  late final TextEditingController _passingScoreController;
  late final TextEditingController _maxAttemptsController;
  late final TextEditingController _criteriaSummaryController;
  late final TextEditingController _checkpointController;
  late bool _isPreview;
  late bool _requireCheckpoints;
  late bool _requireMiniQuizPass;
  late bool _requirePracticalReflection;
  late bool _allowRetry;
  late String _completionMode;
  late String _lessonDifficulty;
  bool _isAiGenerating = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _titleController = TextEditingController(text: lesson?.title ?? '');
    _descriptionController = TextEditingController(
      text: lesson?.description ?? '',
    );
    _orderController = TextEditingController(
      text: lesson == null ? '1' : lesson.orderIndex.toString(),
    );
    _videoController = TextEditingController(text: lesson?.videoUrl ?? '');
    _pdfController = TextEditingController(
      text: lesson?.pdfLinks.join('\n') ?? '',
    );
    _externalController = TextEditingController(
      text: lesson?.externalLinks.join('\n') ?? '',
    );
    _durationController = TextEditingController(
      text: lesson == null || lesson.durationMinutes == 0
          ? ''
          : lesson.durationMinutes.toString(),
    );
    _objectivesController = TextEditingController(
      text: lesson?.learningObjectives.join('\n') ?? '',
    );
    _skillsController = TextEditingController(
      text: lesson?.skillsCovered.join(', ') ?? '',
    );
    _prerequisitesController = TextEditingController(
      text: lesson?.prerequisites.join('\n') ?? '',
    );
    _takeawaysController = TextEditingController(
      text: lesson?.keyTakeaways.join('\n') ?? '',
    );
    _estimatedMinutesController = TextEditingController(
      text: lesson == null || lesson.estimatedMinutes == 0
          ? ''
          : lesson.estimatedMinutes.toString(),
    );
    _minimumReadSecondsController = TextEditingController(
      text: lesson == null || lesson.minimumReadSeconds == 0
          ? ''
          : lesson.minimumReadSeconds.toString(),
    );
    _minimumScrollPercentController = TextEditingController(
      text: lesson == null || lesson.minimumScrollPercent == 0
          ? ''
          : lesson.minimumScrollPercent.toString(),
    );
    _passingScoreController = TextEditingController(
      text: (lesson?.passingScorePercent ?? 70).toString(),
    );
    _maxAttemptsController = TextEditingController(
      text: lesson == null || lesson.maxAttempts == 0
          ? ''
          : lesson.maxAttempts.toString(),
    );
    _criteriaSummaryController = TextEditingController(
      text: lesson?.completionCriteriaSummary ?? '',
    );
    _checkpointController = TextEditingController(
      text: lesson?.checkpoints.map(_checkpointToLine).join('\n') ?? '',
    );
    _isPreview = lesson?.isPreview ?? false;
    _requireCheckpoints = lesson?.requireCheckpoints ?? false;
    _requireMiniQuizPass = lesson?.requireMiniQuizPass ?? false;
    _requirePracticalReflection = lesson?.requirePracticalReflection ?? false;
    _allowRetry = lesson?.allowRetry ?? true;
    _completionMode = lesson?.completionMode ?? LessonCompletionMode.simple;
    _lessonDifficulty = lesson?.lessonDifficulty ?? 'Beginner';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    _videoController.dispose();
    _pdfController.dispose();
    _externalController.dispose();
    _durationController.dispose();
    _objectivesController.dispose();
    _skillsController.dispose();
    _prerequisitesController.dispose();
    _takeawaysController.dispose();
    _estimatedMinutesController.dispose();
    _minimumReadSecondsController.dispose();
    _minimumScrollPercentController.dispose();
    _passingScoreController.dispose();
    _maxAttemptsController.dispose();
    _criteriaSummaryController.dispose();
    _checkpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    widget.lesson == null ? 'Add Lesson' : 'Edit Lesson',
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
                      label: 'Generate Lesson with AI',
                      onPressed: _generateLessonWithAi,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CourseGlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'CORE DETAILS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _titleController,
                          label: 'Lesson Title',
                          hintText: 'e.g. Introduction to Variables',
                          validator: _required,
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hintText: 'What will be covered in this lesson?',
                          minLines: 4,
                          maxLines: 6,
                          validator: _required,
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 560;
                            final fields = [
                              CoursePremiumTextField(
                                controller: _orderController,
                                label: 'Order Index',
                                hintText: 'e.g. 1',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _positiveNumber,
                              ),
                              CoursePremiumTextField(
                                controller: _durationController,
                                label: 'Duration (minutes)',
                                hintText: 'e.g. 15',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _nonNegativeNumber,
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
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.divider
                                  : AppColors.lightDivider,
                            ),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isPreview,
                            activeThumbColor: theme.colorScheme.primary,
                            onChanged: (value) =>
                                setState(() => _isPreview = value),
                            title: Text(
                              'Preview Lesson',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              'Allow non-enrolled students to watch this as a teaser.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CourseGlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'MEDIA & LINKS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _videoController,
                          label: 'Video URL',
                          hintText: 'YouTube, Vimeo, or hosted video link',
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _pdfController,
                          label: 'PDF Handout Links',
                          hintText: 'One link per line',
                          minLines: 3,
                          maxLines: 5,
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _externalController,
                          label: 'External Reference Links',
                          hintText: 'One link per line',
                          minLines: 3,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CourseGlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'LEARNING INTEGRITY',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
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
                          controller: _skillsController,
                          label: 'Skills Covered',
                          hintText: 'Comma separated e.g. Variables, Loops',
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _takeawaysController,
                          label: 'Key Takeaways',
                          hintText: 'One takeaway per line',
                          minLines: 3,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _prerequisitesController,
                          label: 'Prerequisites',
                          hintText: 'One prerequisite per line',
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 560;
                            final fields = [
                              DropdownButtonFormField<String>(
                                initialValue: _lessonDifficulty,
                                decoration: const InputDecoration(
                                  labelText: 'Lesson Difficulty',
                                ),
                                items:
                                    const [
                                          'Beginner',
                                          'Intermediate',
                                          'Advanced',
                                        ]
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(item),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) => setState(
                                  () => _lessonDifficulty = value ?? 'Beginner',
                                ),
                              ),
                              CoursePremiumTextField(
                                controller: _estimatedMinutesController,
                                label: 'Estimated Minutes',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _optionalNonNegativeNumber,
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
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: _completionMode,
                          decoration: const InputDecoration(
                            labelText: 'Completion Mode',
                            helperText:
                                'Simple keeps old behavior. Strict requires all selected evidence.',
                          ),
                          items: LessonCompletionMode.values
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(LessonCompletionMode.label(mode)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _completionMode =
                                value ?? LessonCompletionMode.simple,
                          ),
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 560;
                            final fields = [
                              CoursePremiumTextField(
                                controller: _minimumReadSecondsController,
                                label: 'Minimum Read Seconds',
                                hintText: '0 for none',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _optionalNonNegativeNumber,
                              ),
                              CoursePremiumTextField(
                                controller: _minimumScrollPercentController,
                                label: 'Minimum Scroll %',
                                hintText: '0-100',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _optionalPercent,
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
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilterChip(
                              label: const Text('Require checkpoints'),
                              selected: _requireCheckpoints,
                              onSelected: (value) =>
                                  setState(() => _requireCheckpoints = value),
                            ),
                            FilterChip(
                              label: const Text('Require quiz pass'),
                              selected: _requireMiniQuizPass,
                              onSelected: (value) =>
                                  setState(() => _requireMiniQuizPass = value),
                            ),
                            FilterChip(
                              label: const Text('Require reflection'),
                              selected: _requirePracticalReflection,
                              onSelected: (value) => setState(
                                () => _requirePracticalReflection = value,
                              ),
                            ),
                            FilterChip(
                              label: const Text('Allow retry'),
                              selected: _allowRetry,
                              onSelected: (value) =>
                                  setState(() => _allowRetry = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 560;
                            final fields = [
                              CoursePremiumTextField(
                                controller: _passingScoreController,
                                label: 'Passing Score %',
                                hintText: '70',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _percent,
                              ),
                              CoursePremiumTextField(
                                controller: _maxAttemptsController,
                                label: 'Max Attempts',
                                hintText: '0 for unlimited',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _optionalNonNegativeNumber,
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
                          controller: _criteriaSummaryController,
                          label: 'Completion Criteria Summary',
                          hintText:
                              'Explain what students must do before completion unlocks.',
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 20),
                        CoursePremiumTextField(
                          controller: _checkpointController,
                          label: 'Checkpoints / Mini Quiz',
                          hintText:
                              'One per line: Question | Correct answer | option 1, option 2, option 3',
                          minLines: 4,
                          maxLines: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: widget.isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                    icon: widget.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      widget.isSubmitting ? 'Saving changes...' : 'Save Lesson',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
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

  String? _positiveNumber(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a positive number';
    return null;
  }

  String? _nonNegativeNumber(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  String? _optionalNonNegativeNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }

  String? _percent(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'Enter a value from 0 to 100';
    }
    return null;
  }

  String? _optionalPercent(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _percent(text);
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

  List<LessonCheckpointModel> _checkpoints() {
    final lines = _lineList(_checkpointController);
    return lines.asMap().entries.map((entry) {
      final parts = entry.value.split('|').map((item) => item.trim()).toList();
      final question = parts.isNotEmpty ? parts[0] : entry.value;
      final correctAnswer = parts.length > 1 ? parts[1] : '';
      final options = parts.length > 2
          ? parts[2]
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const <String>[];
      return LessonCheckpointModel(
        id: 'checkpoint_${entry.key + 1}',
        question: question,
        type: options.isEmpty ? 'reflection' : 'mcq',
        options: options,
        correctAnswer: correctAnswer,
        explanation: '',
        points: options.isEmpty ? 0 : 1,
        required: true,
        order: entry.key + 1,
      );
    }).toList();
  }

  String _checkpointToLine(LessonCheckpointModel checkpoint) {
    final parts = [
      checkpoint.question,
      checkpoint.correctAnswer,
      checkpoint.options.join(', '),
    ].where((item) => item.trim().isNotEmpty).toList();
    return parts.join(' | ');
  }

  Future<void> _generateLessonWithAi() async {
    setState(() => _isAiGenerating = true);
    try {
      final result = await _aiService.generate(
        TeacherAiGenerationRequestModel(
          taskType: TeacherAiTaskType.lessonBuilder,
          prompt:
              'Create or improve a lesson for ${_titleController.text.trim().isEmpty ? 'this course' : _titleController.text.trim()}.',
          courseId: widget.courseId,
          currentTitle: _titleController.text.trim(),
          currentDescription: _descriptionController.text.trim(),
          durationMinutes: int.tryParse(_durationController.text.trim()),
          extraContext: const {
            'targetScreen': 'lessonEditor',
            'manualApplyOnly': true,
          },
        ),
      );
      if (!mounted) return;
      final apply = await TeacherAiPreviewDialog.show(context, result);
      if (!mounted || !apply) return;
      setState(() {
        _titleController.text = result.stringValue(
          'title',
          fallback: _titleController.text,
        );
        _descriptionController.text = _lessonDescription(result);
        _durationController.text = result
            .intValue('durationMinutes', fallback: 35)
            .toString();
        final outline = result.stringList('contentOutline');
        final tasks = result.stringList('practiceTasks');
        if (outline.isNotEmpty) _objectivesController.text = outline.join('\n');
        if (tasks.isNotEmpty) _takeawaysController.text = tasks.join('\n');
      });
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  String _lessonDescription(dynamic result) {
    final outline = result.stringList('contentOutline');
    final examples = result.stringList('examples');
    final tasks = result.stringList('practiceTasks');
    final buffer = StringBuffer()
      ..writeln(result.stringValue('summary'))
      ..writeln()
      ..writeln('Objective: ${result.stringValue('objective')}');
    if (outline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Outline:')
        ..writeln(outline.map((item) => '- $item').join('\n'));
    }
    if (examples.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Examples:')
        ..writeln(examples.map((item) => '- $item').join('\n'));
    }
    if (tasks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Practice Tasks:')
        ..writeln(tasks.map((item) => '- $item').join('\n'));
    }
    return buffer.toString().trim();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _hasUnsavedChanges = false);
    widget.onSubmit(
      _LessonFormData(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        orderIndex: int.parse(_orderController.text.trim()),
        videoUrl: _videoController.text.trim(),
        pdfLinks: _lineList(_pdfController),
        externalLinks: _lineList(_externalController),
        durationMinutes: int.parse(_durationController.text.trim()),
        isPreview: _isPreview,
        learningObjectives: _lineList(_objectivesController),
        skillsCovered: _commaList(_skillsController),
        prerequisites: _lineList(_prerequisitesController),
        estimatedMinutes:
            int.tryParse(_estimatedMinutesController.text.trim()) ?? 0,
        keyTakeaways: _lineList(_takeawaysController),
        lessonDifficulty: _lessonDifficulty,
        completionMode: _completionMode,
        minimumReadSeconds:
            int.tryParse(_minimumReadSecondsController.text.trim()) ?? 0,
        minimumScrollPercent:
            int.tryParse(_minimumScrollPercentController.text.trim()) ?? 0,
        requireCheckpoints: _requireCheckpoints,
        requireMiniQuizPass: _requireMiniQuizPass,
        requirePracticalReflection: _requirePracticalReflection,
        passingScorePercent:
            int.tryParse(_passingScoreController.text.trim()) ?? 70,
        allowRetry: _allowRetry,
        maxAttempts: int.tryParse(_maxAttemptsController.text.trim()) ?? 0,
        completionCriteriaSummary: _criteriaSummaryController.text.trim(),
        checkpoints: _checkpoints(),
      ),
    );
  }
}

class _LessonFormData {
  const _LessonFormData({
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.videoUrl,
    required this.pdfLinks,
    required this.externalLinks,
    required this.durationMinutes,
    required this.isPreview,
    required this.learningObjectives,
    required this.skillsCovered,
    required this.prerequisites,
    required this.estimatedMinutes,
    required this.keyTakeaways,
    required this.lessonDifficulty,
    required this.completionMode,
    required this.minimumReadSeconds,
    required this.minimumScrollPercent,
    required this.requireCheckpoints,
    required this.requireMiniQuizPass,
    required this.requirePracticalReflection,
    required this.passingScorePercent,
    required this.allowRetry,
    required this.maxAttempts,
    required this.completionCriteriaSummary,
    required this.checkpoints,
  });

  final String title;
  final String description;
  final int orderIndex;
  final String videoUrl;
  final List<String> pdfLinks;
  final List<String> externalLinks;
  final int durationMinutes;
  final bool isPreview;
  final List<String> learningObjectives;
  final List<String> skillsCovered;
  final List<String> prerequisites;
  final int estimatedMinutes;
  final List<String> keyTakeaways;
  final String lessonDifficulty;
  final String completionMode;
  final int minimumReadSeconds;
  final int minimumScrollPercent;
  final bool requireCheckpoints;
  final bool requireMiniQuizPass;
  final bool requirePracticalReflection;
  final int passingScorePercent;
  final bool allowRetry;
  final int maxAttempts;
  final String completionCriteriaSummary;
  final List<LessonCheckpointModel> checkpoints;
}

class _LessonMessage extends StatelessWidget {
  const _LessonMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
