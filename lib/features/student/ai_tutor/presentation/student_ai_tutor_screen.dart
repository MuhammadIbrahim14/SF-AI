import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../models/user_role.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../../ai_usage/widgets/skillforge_ai_widgets.dart';
import '../../../courses/data/models/enrollment_model.dart';
import '../../../courses/providers/course_provider.dart';
import '../../../courses/providers/enrollment_provider.dart';
import '../../../courses/providers/lesson_provider.dart';
import '../models/student_ai_message_model.dart' as persisted;
import '../models/student_ai_thread_model.dart';
import '../models/student_ai_thread_scope.dart';
import '../models/student_ai_tutor_models.dart';
import '../providers/student_ai_chat_provider.dart';
import '../services/student_ai_context_service.dart';
import '../services/student_ai_tutor_service.dart';
import '../widgets/student_ai_tutor_widgets.dart';

class StudentAiTutorScreen extends ConsumerStatefulWidget {
  const StudentAiTutorScreen({
    super.key,
    this.courseId,
    this.lessonId,
    this.assignmentId,
    this.quizId,
    this.grandTestId,
    this.mode,
    this.source,
    this.action,
  });

  final String? courseId;
  final String? lessonId;
  final String? assignmentId;
  final String? quizId;
  final String? grandTestId;
  final String? mode;
  final String? source;
  final String? action;

  @override
  ConsumerState<StudentAiTutorScreen> createState() =>
      _StudentAiTutorScreenState();
}

class _StudentAiTutorScreenState extends ConsumerState<StudentAiTutorScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  late final StudentAiContextService _contextService;
  late final StudentAiTutorService _tutorService;
  StudentAiTutorContextModel? _context;
  StudentAiThreadModel? _thread;
  List<persisted.StudentAiMessageModel> _latestMessages =
      const <persisted.StudentAiMessageModel>[];
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contextService = StudentAiContextService(FirebaseFirestore.instance);
    _tutorService = StudentAiTutorService();
    _context = StudentAiTutorContextModel(
      studentId: FirebaseAuth.instance.currentUser?.uid ?? 'student',
      languagePreference: 'mixed',
      difficultyLevel: 'beginner',
      mode: widget.mode ?? 'learning',
    );
    _loadContext();
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorContext =
        _context ??
        StudentAiTutorContextModel(
          studentId: FirebaseAuth.instance.currentUser?.uid ?? 'student',
          languagePreference: 'mixed',
          difficultyLevel: 'beginner',
          mode: widget.mode ?? 'learning',
        );
    final thread = _thread;
    final messagesAsync = thread == null
        ? null
        : ref.watch(studentAiMessagesProvider(thread.id));

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: thread?.title ?? 'Ask SkillForge AI',
      subtitle: _scopeLabel(tutorContext),
      showBackButton: true,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              children: [
                const SkillForgeAiCreditBalanceCard(compact: true),
                const SizedBox(height: 14),
                _AiTutorHeroCard(contextModel: tutorContext),
                if ((widget.action ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _PreselectedActionCard(action: widget.action!.trim()),
                ],
                const SizedBox(height: 14),
                StudentAiQuickActions(onAction: _sendQuickAction),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  SkillForgeAiErrorCard(message: _error!),
                ],
                const SizedBox(height: 18),
                _buildMessageArea(messagesAsync),
                if (_sending) ...[
                  const SizedBox(height: 14),
                  const _ThinkingIndicator(),
                ],
                if ((widget.courseId ?? '').trim().isEmpty) ...[
                  const SizedBox(height: 26),
                  _EnrolledCoursesSection(onAsk: _openTutorForCourse),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _Composer(
              controller: _input,
              sending: _sending,
              onSend: () => _send(
                StudentAiTutorTaskType.tutorChat,
                _input.text.trim(),
                _context?.mode ?? 'learning',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadContext() async {
    final studentId = FirebaseAuth.instance.currentUser?.uid ?? 'student';
    try {
      final contextModel = await _contextService.buildContext(
        studentId: studentId,
        courseId: widget.courseId,
        lessonId: widget.lessonId,
        assignmentId: widget.assignmentId,
        quizId: widget.quizId,
        grandTestId: widget.grandTestId,
        mode: widget.mode,
      );
      if (!mounted) return;
      setState(() {
        _context = contextModel;
      });
      await _loadThread(contextModel);
    } catch (_) {
      if (!mounted) return;
      final fallbackContext = StudentAiTutorContextModel(
        studentId: studentId,
        languagePreference: 'mixed',
        difficultyLevel: 'beginner',
        mode: widget.mode ?? 'learning',
      );
      setState(() {
        _context = fallbackContext;
        _error =
            'Tutor opened in general mode because course context was unavailable.';
      });
      await _loadThread(fallbackContext);
    }
  }

  Future<void> _loadThread(StudentAiTutorContextModel contextModel) async {
    try {
      final thread = await ref
          .read(studentAiChatRepositoryProvider)
          .getOrCreateThread(context: contextModel, scope: _threadScope);
      if (!mounted) return;
      setState(() {
        _thread = thread;
      });
      _scrollToBottomSoon();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load AI chat memory. Please retry.';
      });
    }
  }

  Widget _buildMessageArea(
    AsyncValue<List<persisted.StudentAiMessageModel>>? messagesAsync,
  ) {
    if (_thread == null || messagesAsync == null) {
      return const _TutorLoadingCard();
    }

    return messagesAsync.when(
      loading: () => const _TutorLoadingCard(),
      error: (_, _) => _TutorErrorCard(
        message: 'Unable to load saved AI chat right now.',
        onRetry: () => ref.invalidate(studentAiMessagesProvider(_thread!.id)),
      ),
      data: (messages) {
        _latestMessages = messages;
        if (messages.isEmpty) {
          return _StarterPromptsCard(
            scope: _threadScope,
            onPrompt: (prompt) =>
                _send(StudentAiTutorTaskType.tutorChat, prompt, 'learning'),
          );
        }
        _scrollToBottomSoon();
        return Column(
          children: [
            for (final message in messages)
              StudentAiMessageBubble(
                message: _toBubble(message),
                failed: message.isFailed,
                onCopy: message.isAssistant
                    ? () => _copyAssistantMessage(message.content)
                    : null,
                onRetry: message.isFailed ? _retryLastUserMessage : null,
              ),
          ],
        );
      },
    );
  }

  StudentAiTutorMessageModel _toBubble(
    persisted.StudentAiMessageModel message,
  ) {
    if (message.isUser) {
      return StudentAiTutorMessageModel(text: message.content, isStudent: true);
    }
    final response = message.structuredData.isNotEmpty
        ? StudentAiTutorResponseModel.fromStructuredMap(
            message.structuredData,
            fallbackContent: message.content,
          )
        : StudentAiTutorResponseModel(
            title: message.isFailed
                ? 'SkillForge AI could not answer'
                : 'SkillForge AI Tutor',
            answer: message.content,
            sourceProvider: message.source ?? 'aiUnavailable',
            isFallback: false,
            isRepaired: false,
            model: message.model,
            creditCost: message.creditsCharged,
            safetyNotes: message.safetyNotes,
            qualityWarnings: [
              if ((message.errorCode ?? '').trim().isNotEmpty)
                message.errorCode!,
            ],
          );
    return StudentAiTutorMessageModel(
      text: message.content,
      isStudent: false,
      response: response,
    );
  }

  Future<void> _copyAssistantMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI response copied.')));
  }

  void _retryLastUserMessage() {
    final userMessages = _latestMessages.where((message) => message.isUser);
    if (userMessages.isEmpty) return;
    final last = userMessages.last;
    _send(
      last.taskType ?? StudentAiTutorTaskType.tutorChat,
      last.content,
      _context?.mode ?? 'learning',
    );
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendQuickAction(String taskType, String prompt, String mode) {
    _send(taskType, prompt, mode);
  }

  void _openTutorForCourse(
    String courseId, {
    String? lessonId,
    String? action,
    String? mode,
  }) {
    context.pushNamed(
      RouteNames.studentAiTutor,
      queryParameters: {
        'courseId': courseId,
        if ((lessonId ?? '').trim().isNotEmpty) 'lessonId': lessonId!.trim(),
        if ((action ?? '').trim().isNotEmpty) 'action': action!.trim(),
        if ((mode ?? '').trim().isNotEmpty) 'mode': mode!.trim(),
        'source': lessonId == null ? 'course' : 'lesson',
      },
    );
  }

  Future<void> _send(String taskType, String prompt, String mode) async {
    if (prompt.trim().isEmpty ||
        _sending ||
        _context == null ||
        _thread == null) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _input.clear();
    });
    try {
      final base = _context!;
      final scopedContext = StudentAiTutorContextModel(
        studentId: base.studentId,
        courseId: base.courseId,
        courseTitle: base.courseTitle,
        lessonId: base.lessonId,
        lessonTitle: base.lessonTitle,
        lessonContentSummary: base.lessonContentSummary,
        currentTopic: base.currentTopic,
        assignmentId: base.assignmentId,
        quizId: base.quizId,
        grandTestId: base.grandTestId,
        attemptId: base.attemptId,
        recentScore: base.recentScore,
        weakTopics: base.weakTopics,
        completedLessons: base.completedLessons,
        pendingAssignments: base.pendingAssignments,
        upcomingTests: base.upcomingTests,
        languagePreference: base.languagePreference,
        difficultyLevel: base.difficultyLevel,
        mode: mode,
      );
      final repo = ref.read(studentAiChatRepositoryProvider);
      await repo.saveUserMessage(
        threadId: _thread!.id,
        context: scopedContext,
        content: prompt,
        taskType: taskType,
      );
      final recentMessages = await repo.getRecentMessages(_thread!.id);
      final response = await _tutorService.ask(
        taskType: taskType,
        prompt: prompt,
        context: scopedContext,
        threadId: _thread!.id,
        recentMessages: recentMessages,
      );
      await repo.saveAssistantMessage(
        threadId: _thread!.id,
        context: scopedContext,
        response: response,
        taskType: taskType,
      );
    } catch (_) {
      try {
        if (_thread != null && _context != null) {
          await ref
              .read(studentAiChatRepositoryProvider)
              .saveAssistantMessage(
                threadId: _thread!.id,
                context: _context!,
                response: StudentAiTutorResponseModel(
                  title: 'SkillForge AI is temporarily unavailable',
                  answer:
                      'SkillForge AI could not generate a response right now. Please retry in a moment.',
                  sourceProvider: 'gatewayUnreachable',
                  isFallback: false,
                  isRepaired: false,
                  creditCost: 0,
                  safetyNotes: const [
                    'No progress, score, or submission was changed.',
                  ],
                  suggestedNextActions: const [
                    'Retry the same question.',
                    'Check that the AI Gateway is running.',
                  ],
                  qualityWarnings: const ['gatewayUnreachable'],
                ),
                taskType: taskType,
              );
        }
      } catch (_) {
        // The visible page error below is the fallback if persistence also fails.
      }
      if (!mounted) return;
      setState(() {
        _error = 'AI Tutor is temporarily unavailable. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  StudentAiThreadScope get _threadScope {
    if ((widget.lessonId ?? '').trim().isNotEmpty) {
      return StudentAiThreadScope.lesson;
    }
    if ((widget.courseId ?? '').trim().isNotEmpty) {
      return StudentAiThreadScope.course;
    }
    return StudentAiThreadScope.general;
  }

  String _scopeLabel(StudentAiTutorContextModel context) {
    if ((context.lessonTitle ?? '').trim().isNotEmpty) {
      return 'Continuing lesson chat for ${context.lessonTitle}.';
    }
    if ((context.courseTitle ?? '').trim().isNotEmpty) {
      return 'Continuing course chat for ${context.courseTitle}.';
    }
    return 'Choose a course or ask for help with your learning.';
  }
}

class _AiTutorHeroCard extends StatelessWidget {
  const _AiTutorHeroCard({required this.contextModel});

  final StudentAiTutorContextModel contextModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLesson = (contextModel.lessonTitle ?? '').trim().isNotEmpty;
    final hasCourse = (contextModel.courseTitle ?? '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.tertiary.withValues(alpha: 0.10),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLesson
                          ? 'Lesson AI workspace'
                          : hasCourse
                          ? 'Course AI workspace'
                          : 'Your AI learning workspace',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ask questions, simplify concepts, generate practice, and revise with safe learning support.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StudentAiContextCard(context: contextModel),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SkillForge AI helps you understand, practice, and revise. It will not submit work, change progress, or edit scores.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreselectedActionCard extends StatelessWidget {
  const _PreselectedActionCard({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final label = switch (action) {
      'explainLesson' => 'Explain this lesson',
      'summarizeLesson' => 'Summarize this lesson',
      'practiceLesson' => 'Make practice questions',
      'revisionPlan' => 'Create a revision plan',
      'courseStudyPlan' => 'Create a course study plan',
      'askCourse' => 'Ask about this course',
      'practiceCourse' => 'Practice this course',
      _ => 'AI action ready',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label selected. Review the context, then click the matching action chip when ready.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Thinking...',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarterPromptsCard extends StatelessWidget {
  const _StarterPromptsCard({required this.scope, required this.onPrompt});

  final StudentAiThreadScope scope;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompts = scope == StudentAiThreadScope.lesson
        ? const [
            'Explain this lesson in simple words.',
            'Give me real-life examples.',
            'Make 5 practice questions.',
            'Help me understand the checkpoints.',
          ]
        : scope == StudentAiThreadScope.course
        ? const [
            'Explain this course roadmap.',
            'What should I study first?',
            'Create a 7-day revision plan.',
            'Make practice questions for this course.',
          ]
        : const [
            'Help me choose what to study today.',
            'Create a weekly learning plan.',
            'Explain a difficult concept simply.',
            'Give me practice questions.',
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start this AI chat',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This conversation will be saved for this exact ${scope == StudentAiThreadScope.lesson
                ? 'lesson'
                : scope == StudentAiThreadScope.course
                ? 'course'
                : 'workspace'}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(prompt),
                  onPressed: () => onPrompt(prompt),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnrolledCoursesSection extends ConsumerWidget {
  const _EnrolledCoursesSection({required this.onAsk});

  final void Function(
    String courseId, {
    String? lessonId,
    String? action,
    String? mode,
  })
  onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(studentEnrollmentsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your enrolled courses',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a course for context-aware explanations, practice, and revision.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        enrollmentsAsync.when(
          loading: () => const _TutorLoadingCard(),
          error: (error, _) => _TutorErrorCard(
            message: 'Unable to load enrolled courses right now.',
            onRetry: () => ref.invalidate(studentEnrollmentsProvider),
          ),
          data: (enrollments) {
            if (enrollments.isEmpty) {
              return _NoCoursesCard(
                onBrowse: () => context.pushNamed(RouteNames.studentCourses),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: enrollments
                      .where((item) => item.courseId.trim().isNotEmpty)
                      .map(
                        (enrollment) => SizedBox(
                          width: isWide
                              ? (constraints.maxWidth - 14) / 2
                              : constraints.maxWidth,
                          child: _TutorCourseCard(
                            enrollment: enrollment,
                            onAsk: onAsk,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _TutorCourseCard extends ConsumerWidget {
  const _TutorCourseCard({required this.enrollment, required this.onAsk});

  final EnrollmentModel enrollment;
  final void Function(
    String courseId, {
    String? lessonId,
    String? action,
    String? mode,
  })
  onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(enrollment.courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(enrollment.courseId));
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: courseAsync.when(
          loading: () => const _TutorLoadingCard(compact: true),
          error: (_, _) => const Text('Course details unavailable.'),
          data: (course) {
            final title = (course?.title ?? '').trim().isEmpty
                ? 'Enrolled course'
                : course!.title;
            final teacher = (course?.teacherName ?? '').trim().isEmpty
                ? 'Verified Instructor'
                : course!.teacherName;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teacher,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (enrollment.progressPercent / 100)
                      .clamp(0, 1)
                      .toDouble(),
                ),
                const SizedBox(height: 6),
                Text(
                  '${enrollment.progressPercent.toStringAsFixed(0)}% complete',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Ask about this course'),
                      onPressed: () => onAsk(
                        enrollment.courseId,
                        action: 'askCourse',
                        mode: 'learning',
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                      ),
                      label: const Text('Study plan'),
                      onPressed: () => onAsk(
                        enrollment.courseId,
                        action: 'courseStudyPlan',
                        mode: 'revisionPlan',
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.quiz_rounded, size: 18),
                      label: const Text('Practice'),
                      onPressed: () => onAsk(
                        enrollment.courseId,
                        action: 'practiceCourse',
                        mode: 'practiceMode',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                lessonsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (lessons) {
                    final visible = lessons
                        .where((lesson) => !lesson.isArchived)
                        .take(4)
                        .toList();
                    if (visible.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No lessons available yet. You can still ask about the course topic.',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text('Lesson AI actions (${visible.length})'),
                      children: [
                        for (final lesson in visible)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              lesson.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton.icon(
                              onPressed: () => onAsk(
                                enrollment.courseId,
                                lessonId: lesson.lessonId,
                                action: 'explainLesson',
                                mode: 'learning',
                              ),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Explain'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TutorLoadingCard extends StatelessWidget {
  const _TutorLoadingCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Row(
          children: const [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 12),
            Text('Loading learning context...'),
          ],
        ),
      ),
    );
  }
}

class _TutorErrorCard extends StatelessWidget {
  const _TutorErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _NoCoursesCard extends StatelessWidget {
  const _NoCoursesCard({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.school_outlined, size: 34),
            const SizedBox(height: 10),
            Text(
              'No enrolled courses found yet.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can still ask general learning questions, or browse courses to unlock lesson-specific AI help.',
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Browse Courses'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ask SkillForge Tutor',
              hintText: 'e.g. Is lesson ko simple Roman Urdu me samjhao',
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: sending ? null : onSend,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Ask'),
        ),
      ],
    );
  }
}
