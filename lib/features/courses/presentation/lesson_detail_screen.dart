import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/lesson_model.dart';
import '../data/repositories/enrollment_repository.dart';
import '../providers/enrollment_provider.dart';
import '../providers/lesson_provider.dart';
import 'course_premium_widgets.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  final String courseId;
  final String lessonId;

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  final Map<String, String> _checkpointAnswers = <String, String>{};
  final TextEditingController _reflectionController = TextEditingController();
  late final DateTime _openedAt;
  double _maxScrollPercent = 0;
  int _previousReadSeconds = 0;
  EnrollmentRepository? _enrollmentRepository;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _enrollmentRepository = ref.read(enrollmentRepositoryProvider);
    _studentId = ref.read(authStateProvider).value?.uid;
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    _persistReadTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(
      lessonDetailProvider((
        courseId: widget.courseId,
        lessonId: widget.lessonId,
      )),
    );
    final actionState = ref.watch(enrollmentActionProvider);
    // Study time already banked for this lesson, so the timer resumes instead
    // of restarting. Cached here so it is still available while disposing.
    _previousReadSeconds =
        ref
            .watch(
              lessonReadProgressProvider((
                courseId: widget.courseId,
                lessonId: widget.lessonId,
              )),
            )
            .value
            ?.readSeconds ??
        0;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Lesson Player',
      subtitle: 'Review lesson materials and update your progress.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentCourseLearn,
              pathParameters: {'courseId': widget.courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: lessonAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (lesson) {
            if (lesson == null) {
              return const CoursePremiumMessage(
                icon: Icons.search_off_rounded,
                title: 'Lesson not found',
                message: 'This lesson may have been archived.',
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: CoursePremiumListView(
                maxWidth: 860,
                bottomPadding: 120,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.pushNamed(
                          RouteNames.studentAiTutor,
                          queryParameters: {
                            'courseId': widget.courseId,
                            'lessonId': lesson.lessonId,
                            'source': 'lesson',
                            'action': 'explainLesson',
                            'mode': 'learning',
                          },
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Learn with AI'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.pushNamed(
                          RouteNames.studentAiTutor,
                          queryParameters: {
                            'courseId': widget.courseId,
                            'lessonId': lesson.lessonId,
                            'source': 'lesson',
                            'action': 'practiceLesson',
                            'mode': 'practiceMode',
                          },
                        ),
                        icon: const Icon(Icons.quiz_rounded),
                        label: const Text('Practice with AI'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CourseHeroHeader(
                    icon: Icons.play_circle_fill_rounded,
                    title: lesson.title,
                    subtitle:
                        'Module ${lesson.orderIndex} • ${lesson.durationMinutes} min',
                  ),
                  const SizedBox(height: 24),
                  _LessonOutcomeCard(lesson: lesson),
                  const SizedBox(height: 24),
                  _AboutLessonCard(lesson: lesson),
                  const SizedBox(height: 24),
                  if (lesson.videoUrl.trim().isNotEmpty ||
                      lesson.pdfLinks.isNotEmpty ||
                      lesson.externalLinks.isNotEmpty)
                    _LessonMaterials(lesson: lesson),
                  const SizedBox(height: 32),
                  _CompletionIntegrityCard(
                    lesson: lesson,
                    openedAt: _openedAt,
                    previousReadSeconds: _previousReadSeconds,
                    scrollPercent: _maxScrollPercent,
                    answers: _checkpointAnswers,
                    reflectionController: _reflectionController,
                    onAnswerChanged: (checkpointId, value) => setState(
                      () => _checkpointAnswers[checkpointId] = value,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _markComplete(context, lesson),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                    icon: actionState.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: const Text(
                      'Verify & Complete Lesson',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _handleScroll(ScrollNotification notification) {
    final maxExtent = notification.metrics.maxScrollExtent;
    if (maxExtent <= 0) return false;
    final percent = ((notification.metrics.pixels / maxExtent) * 100).clamp(
      0,
      100,
    );
    if (percent > _maxScrollPercent) {
      setState(() => _maxScrollPercent = percent.toDouble());
    }
    return false;
  }

  int get _elapsedSeconds => DateTime.now().difference(_openedAt).inSeconds;

  /// Seconds studied across visits: previously saved time plus this session.
  int get _totalReadSeconds => _previousReadSeconds + _elapsedSeconds;

  void _persistReadTime() {
    final repository = _enrollmentRepository;
    final studentId = _studentId;
    final seconds = _totalReadSeconds;
    if (repository == null || studentId == null) return;
    if (seconds <= _previousReadSeconds) return;
    // Fire and forget: leaving the lesson must not wait on the write.
    unawaited(
      repository
          .recordLessonReadSeconds(
            courseId: widget.courseId,
            lessonId: widget.lessonId,
            studentId: studentId,
            readSeconds: seconds,
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> _markComplete(BuildContext context, LessonModel lesson) async {
    final validation = _validateCompletion(lesson);
    if (!validation.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation.message)));
      return;
    }

    final success = await ref
        .read(enrollmentActionProvider.notifier)
        .markLessonComplete(
          courseId: widget.courseId,
          lessonId: widget.lessonId,
          verifiedCompleted: true,
          completionMode: lesson.completionMode,
          completionEvidence: {
            'readSeconds': _totalReadSeconds,
            'maxScrollPercent': _maxScrollPercent,
            'checkpointScorePercent': validation.scorePercent,
            'checkpointAnswers': _checkpointAnswers,
            'practicalReflection': _reflectionController.text.trim(),
            'criteriaSummary': lesson.completionCriteriaSummary,
          },
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Lesson verified and marked complete.'
              : ref.read(enrollmentActionProvider.notifier).errorMessage ??
                    'Unable to update progress.',
        ),
      ),
    );
  }

  _CompletionValidation _validateCompletion(LessonModel lesson) {
    if (!lesson.hasStrictCompletion) {
      return const _CompletionValidation.valid(scorePercent: 100);
    }
    if (lesson.minimumReadSeconds > 0 &&
        _totalReadSeconds < lesson.minimumReadSeconds) {
      return _CompletionValidation.invalid(
        'Spend at least ${lesson.minimumReadSeconds} seconds on this lesson before completing it. '
        'You have studied $_totalReadSeconds seconds.',
      );
    }
    if (lesson.minimumScrollPercent > 0 &&
        _maxScrollPercent < lesson.minimumScrollPercent) {
      return _CompletionValidation.invalid(
        'Review at least ${lesson.minimumScrollPercent}% of the lesson before completing it.',
      );
    }

    final requiredCheckpoints = lesson.checkpoints
        .where((checkpoint) => checkpoint.required)
        .toList();
    if ((lesson.requireCheckpoints || lesson.requireMiniQuizPass) &&
        requiredCheckpoints.isNotEmpty) {
      final unanswered = requiredCheckpoints.any(
        (checkpoint) =>
            (_checkpointAnswers[checkpoint.id] ?? '').trim().isEmpty,
      );
      if (unanswered) {
        return const _CompletionValidation.invalid(
          'Answer all required checkpoints first.',
        );
      }

      final quizItems = requiredCheckpoints
          .where((checkpoint) => checkpoint.correctAnswer.trim().isNotEmpty)
          .toList();
      if (quizItems.isNotEmpty) {
        final correct = quizItems.where((checkpoint) {
          final answer = (_checkpointAnswers[checkpoint.id] ?? '').trim();
          return answer.toLowerCase() ==
              checkpoint.correctAnswer.trim().toLowerCase();
        }).length;
        final score = ((correct / quizItems.length) * 100).round();
        if (lesson.requireMiniQuizPass && score < lesson.passingScorePercent) {
          return _CompletionValidation.invalid(
            'Checkpoint score is $score%. Required score is ${lesson.passingScorePercent}%.',
          );
        }
        return _CompletionValidation.valid(scorePercent: score);
      }
    }

    if (lesson.requirePracticalReflection &&
        _reflectionController.text.trim().length < 20) {
      return const _CompletionValidation.invalid(
        'Write a short practical reflection before completing this lesson.',
      );
    }
    return const _CompletionValidation.valid(scorePercent: 100);
  }
}

class _CompletionValidation {
  const _CompletionValidation._({
    required this.isValid,
    required this.message,
    required this.scorePercent,
  });

  const _CompletionValidation.valid({required int scorePercent})
    : this._(isValid: true, message: '', scorePercent: scorePercent);

  const _CompletionValidation.invalid(String message)
    : this._(isValid: false, message: message, scorePercent: 0);

  final bool isValid;
  final String message;
  final int scorePercent;
}

class _AboutLessonCard extends StatelessWidget {
  const _AboutLessonCard({required this.lesson});

  final LessonModel lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this lesson',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lesson.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonOutcomeCard extends StatelessWidget {
  const _LessonOutcomeCard({required this.lesson});

  final LessonModel lesson;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (lesson.learningObjectives.isNotEmpty)
        _InfoList(
          title: 'Learning objectives',
          items: lesson.learningObjectives,
        ),
      if (lesson.skillsCovered.isNotEmpty)
        _InfoList(title: 'Skills covered', items: lesson.skillsCovered),
      if (lesson.keyTakeaways.isNotEmpty)
        _InfoList(title: 'Key takeaways', items: lesson.keyTakeaways),
      if (lesson.prerequisites.isNotEmpty)
        _InfoList(title: 'Prerequisites', items: lesson.prerequisites),
    ];

    if (items.isEmpty && !lesson.hasStrictCompletion) {
      return const SizedBox.shrink();
    }

    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                icon: Icons.speed_rounded,
                label: lesson.lessonDifficulty,
              ),
              _MiniChip(
                icon: Icons.verified_user_rounded,
                label: LessonCompletionMode.label(lesson.completionMode),
              ),
              if (lesson.estimatedMinutes > 0)
                _MiniChip(
                  icon: Icons.schedule_rounded,
                  label: '${lesson.estimatedMinutes} min guided',
                ),
            ],
          ),
          if (lesson.completionCriteriaSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              lesson.completionCriteriaSummary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...items.expand((item) => [item, const SizedBox(height: 16)]),
          ],
        ],
      ),
    );
  }
}

class _CompletionIntegrityCard extends StatelessWidget {
  const _CompletionIntegrityCard({
    required this.lesson,
    required this.openedAt,
    required this.previousReadSeconds,
    required this.scrollPercent,
    required this.answers,
    required this.reflectionController,
    required this.onAnswerChanged,
  });

  final LessonModel lesson;
  final DateTime openedAt;
  final int previousReadSeconds;
  final double scrollPercent;
  final Map<String, String> answers;
  final TextEditingController reflectionController;
  final void Function(String checkpointId, String value) onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.hasStrictCompletion ? 'Completion integrity' : 'Completion',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lesson.hasStrictCompletion
                ? 'Complete the required evidence before the lesson can be verified.'
                : 'This lesson uses simple completion. Review the content, then mark it complete.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ReadTimeTracker(
            openedAt: openedAt,
            previousReadSeconds: previousReadSeconds,
            requiredSeconds: lesson.minimumReadSeconds,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                icon: Icons.vertical_align_bottom_rounded,
                label: '${scrollPercent.toStringAsFixed(0)}% reviewed',
              ),
              if (lesson.minimumScrollPercent > 0)
                _MiniChip(
                  icon: Icons.fact_check_rounded,
                  label: 'Need ${lesson.minimumScrollPercent}% review',
                ),
            ],
          ),
          if (lesson.checkpoints.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...lesson.checkpoints.map(
              (checkpoint) => _CheckpointQuestion(
                checkpoint: checkpoint,
                value: answers[checkpoint.id] ?? '',
                onChanged: (value) => onAnswerChanged(checkpoint.id, value),
              ),
            ),
          ],
          if (lesson.requirePracticalReflection) ...[
            const SizedBox(height: 16),
            TextField(
              controller: reflectionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Practical reflection',
                hintText:
                    'Briefly explain how you would apply this lesson in a real project.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Live "seconds studied" counter. Ticks every second and, when the lesson has
/// a required reading time, shows progress towards it.
class _ReadTimeTracker extends StatefulWidget {
  const _ReadTimeTracker({
    required this.openedAt,
    required this.previousReadSeconds,
    required this.requiredSeconds,
  });

  final DateTime openedAt;
  final int previousReadSeconds;
  final int requiredSeconds;

  @override
  State<_ReadTimeTracker> createState() => _ReadTimeTrackerState();
}

class _ReadTimeTrackerState extends State<_ReadTimeTracker> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studiedSeconds =
        widget.previousReadSeconds +
        DateTime.now().difference(widget.openedAt).inSeconds;
    final requiredSeconds = widget.requiredSeconds;
    final hasRequirement = requiredSeconds > 0;
    final isMet = !hasRequirement || studiedSeconds >= requiredSeconds;
    final remaining = hasRequirement
        ? (requiredSeconds - studiedSeconds).clamp(0, requiredSeconds)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isMet ? Icons.timer_rounded : Icons.lock_clock_rounded,
              size: 18,
              color: isMet ? Colors.green : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasRequirement
                    ? 'Read time ${studiedSeconds}s of ${requiredSeconds}s required'
                    : 'Read time ${studiedSeconds}s',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              _formatDuration(studiedSeconds),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (hasRequirement) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (studiedSeconds / requiredSeconds).clamp(0, 1).toDouble(),
              valueColor: AlwaysStoppedAnimation(
                isMet ? Colors.green : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMet
                ? 'Required reading time completed.'
                : '${remaining}s of reading time left before you can complete this lesson.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
  }
}

class _CheckpointQuestion extends StatelessWidget {
  const _CheckpointQuestion({
    required this.checkpoint,
    required this.value,
    required this.onChanged,
  });

  final LessonCheckpointModel checkpoint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            checkpoint.question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (checkpoint.options.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: checkpoint.options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option),
                      selected: value == option,
                      onSelected: (_) => onChanged(option),
                    ),
                  )
                  .toList(),
            )
          else
            TextField(
              minLines: 2,
              maxLines: 4,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Write your answer or reflection...',
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonMaterials extends StatelessWidget {
  const _LessonMaterials({required this.lesson});

  final LessonModel lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lesson Materials',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        if (lesson.videoUrl.trim().isNotEmpty)
          _ResourceTile(
            icon: Icons.play_circle_rounded,
            title: 'Video Lesson',
            text: lesson.videoUrl,
          ),
        ...lesson.pdfLinks.map(
          (link) => _ResourceTile(
            icon: Icons.picture_as_pdf_rounded,
            title: 'PDF Handout',
            text: link,
          ),
        ),
        ...lesson.externalLinks.map(
          (link) => _ResourceTile(
            icon: Icons.link_rounded,
            title: 'External Resource',
            text: link,
          ),
        ),
      ],
    );
  }
}

class _InfoList extends StatelessWidget {
  const _InfoList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

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

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
