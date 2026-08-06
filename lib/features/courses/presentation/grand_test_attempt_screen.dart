import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/grand_test_attempt_model.dart';
import '../data/models/grand_test_model.dart';
import '../providers/grand_test_provider.dart';

class GrandTestAttemptScreen extends ConsumerStatefulWidget {
  const GrandTestAttemptScreen({
    super.key,
    required this.courseId,
    required this.grandTestId,
  });

  final String courseId;
  final String grandTestId;

  @override
  ConsumerState<GrandTestAttemptScreen> createState() =>
      _GrandTestAttemptScreenState();
}

class _GrandTestAttemptScreenState extends ConsumerState<GrandTestAttemptScreen>
    with WidgetsBindingObserver {
  late final Future<GrandTestAttemptModel?> _attemptFuture;
  final Map<String, String> _answers = {};
  Timer? _timer;
  GrandTestAttemptModel? _attempt;
  List<GrandTestQuestionModel> _questions = const [];
  int _currentIndex = 0;
  int _remainingSeconds = 0;
  int _warningsCount = 0;
  bool _initialized = false;
  bool _initializationScheduled = false;
  bool _submitting = false;
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attemptFuture = Future.microtask(
      () => ref
          .read(grandTestActionProvider.notifier)
          .startAttempt(
            courseId: widget.courseId,
            grandTestId: widget.grandTestId,
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized || _submitting || _attempt?.isSubmitted == true) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      setState(() => _warningsCount++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testAsync = ref.watch(
      grandTestDetailProvider((
        courseId: widget.courseId,
        grandTestId: widget.grandTestId,
      )),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExitWarning();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFF5F5F7), // Extra dark/clean for exam mode
        appBar: AppBar(
          title: const Text(
            'Certification Exam',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF161616) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _handleExitWarning,
            tooltip: 'Exit Exam',
          ),
          actions: [
            if (_initialized && !_submitting && _attempt?.isSubmitted != true)
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _remainingSeconds < 300
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _remainingSeconds < 300
                          ? AppColors.error
                          : AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: _remainingSeconds < 300
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _remainingSeconds < 300
                              ? AppColors.error
                              : AppColors.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<GrandTestAttemptModel?>(
            future: _attemptFuture,
            builder: (context, attemptSnapshot) {
              if (attemptSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (attemptSnapshot.hasError || attemptSnapshot.data == null) {
                final error =
                    attemptSnapshot.error ??
                    ref.read(grandTestActionProvider.notifier).errorMessage ??
                    'Unable to start grand test.';
                final attemptLimitReached = _isAttemptLimitError(error);
                return _MessageState(
                  icon: attemptLimitReached
                      ? Icons.verified_user_rounded
                      : Icons.lock_outline_rounded,
                  title: attemptLimitReached
                      ? 'Attempt limit reached'
                      : 'Exam locked',
                  message: attemptLimitReached
                      ? 'You have already used the available attempt for this certification. You can review your official result, but retakes are currently locked.'
                      : error.toString(),
                  actionLabel: attemptLimitReached
                      ? 'View Official Result'
                      : 'Back to Dashboard',
                  onAction: attemptLimitReached
                      ? _goToResult
                      : () => context.goNamed(
                          RouteNames.studentGrandTestOverview,
                          pathParameters: {'courseId': widget.courseId},
                        ),
                );
              }

              final attempt = attemptSnapshot.data!;
              if (attempt.isSubmitted) {
                return _MessageState(
                  icon: Icons.analytics_rounded,
                  title: 'Exam Already Submitted',
                  message:
                      'This certification attempt is locked and securely stored.',
                  actionLabel: 'View Score Report',
                  onAction: _goToResult,
                );
              }

              return testAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(error.toString())),
                data: (test) {
                  if (test == null || !test.isPublished) {
                    return const Center(
                      child: Text('Certification unavailable.'),
                    );
                  }
                  if (!_initialized) {
                    _scheduleInitialize(test, attempt);
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_questions.isEmpty) {
                    return const Center(child: Text('No questions available.'));
                  }

                  final question = _questions[_currentIndex];
                  final progress = (_currentIndex + 1) / _questions.length;
                  final options =
                      attempt.optionOrder[question.questionId] ??
                      question.options;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        children: [
                          // Progress Bar Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF161616)
                                  : Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Question ${_currentIndex + 1} of ${_questions.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: theme
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.3),
                                      valueColor: AlwaysStoppedAnimation(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_warningsCount > 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 24,
                              ),
                              color: AppColors.error.withValues(alpha: 0.1),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Warning: Focus lost $_warningsCount times. Continuous focus loss may void attempt.',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Main Question Area
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                Text(
                                  question.question,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        height: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 40),

                                // Answer Options
                                ...options.map((option) {
                                  final isSelected =
                                      _answers[question.questionId] == option;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _submitting
                                            ? null
                                            : () {
                                                setState(() {
                                                  _answers[question
                                                          .questionId] =
                                                      option;
                                                });
                                              },
                                        borderRadius: BorderRadius.circular(16),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : (isDark
                                                      ? const Color(0xFF1E1E1E)
                                                      : Colors.white),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : theme
                                                        .colorScheme
                                                        .outlineVariant
                                                        .withValues(alpha: 0.4),
                                              width: isSelected ? 2 : 1,
                                            ),
                                            boxShadow: isSelected
                                                ? null
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: isDark
                                                                ? 0.2
                                                                : 0.02,
                                                          ),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : theme
                                                              .colorScheme
                                                              .outlineVariant,
                                                    width: isSelected ? 6 : 2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight: isSelected
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: isSelected
                                                            ? AppColors.primary
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          // Navigation Footer
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF161616)
                                  : Colors.white,
                              border: Border(
                                top: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _currentIndex == 0 || _submitting
                                      ? null
                                      : () => setState(() => _currentIndex--),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (_currentIndex == _questions.length - 1)
                                  FilledButton.icon(
                                    onPressed: _submitting
                                        ? null
                                        : () => _confirmSubmit(
                                            autoSubmitted: false,
                                          ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: _submitting
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 20,
                                          ),
                                    label: Text(
                                      _submitting
                                          ? 'Submitting...'
                                          : 'Submit Exam',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                else
                                  FilledButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(() => _currentIndex++),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.onSurface,
                                      foregroundColor:
                                          theme.colorScheme.surface,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Next Question',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _initialize(GrandTestModel test, GrandTestAttemptModel attempt) {
    final byId = {
      for (final question in test.questions) question.questionId: question,
    };
    final ordered = <GrandTestQuestionModel>[
      for (final id in attempt.questionOrder)
        if (byId[id] != null) byId[id]!,
    ];
    for (final question in test.questions) {
      if (!ordered.any((item) => item.questionId == question.questionId)) {
        ordered.add(question);
      }
    }

    final totalSeconds = test.durationMinutes * 60;
    final elapsed = DateTime.now().difference(attempt.startedAt).inSeconds;
    final remainingSeconds = (totalSeconds - elapsed).clamp(0, totalSeconds);

    setState(() {
      _initialized = true;
      _initializationScheduled = false;
      _attempt = attempt;
      _answers
        ..clear()
        ..addAll(attempt.answers);
      _warningsCount = attempt.warningsCount;
      _questions = ordered;
      _remainingSeconds = remainingSeconds;
    });

    if (remainingSeconds <= 0) {
      Future.microtask(() {
        if (mounted) _submit(autoSubmitted: true);
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _scheduleInitialize(GrandTestModel test, GrandTestAttemptModel attempt) {
    if (_initializationScheduled) return;
    _initializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      _initialize(test, attempt);
    });
  }

  void _tick() {
    if (!mounted || _submitting) return;
    if (_remainingSeconds <= 1) {
      setState(() => _remainingSeconds = 0);
      _submit(autoSubmitted: true);
      return;
    }
    setState(() => _remainingSeconds--);
  }

  Future<void> _confirmSubmit({required bool autoSubmitted}) async {
    if (_answers.isEmpty && !autoSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Answer at least one question to submit.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final answeredCount = _answers.length;
    final totalCount = _questions.length;
    final unanswered = totalCount - answeredCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Certification Exam?'),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered questions. Your attempt will be permanently locked after submission.'
              : 'You have answered all questions. Your attempt will be permanently locked after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm Submission'),
          ),
        ],
      ),
    );
    if (confirm == true) await _submit(autoSubmitted: autoSubmitted);
  }

  Future<void> _submit({required bool autoSubmitted}) async {
    if (_submitting) return;
    final attempt = _attempt;
    if (attempt == null) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    final success = await ref
        .read(grandTestActionProvider.notifier)
        .submitAttempt(
          courseId: widget.courseId,
          grandTestId: widget.grandTestId,
          attemptId: attempt.attemptId,
          answers: Map<String, String>.from(_answers),
          warningsCount: _warningsCount,
          autoSubmitted: autoSubmitted,
        );
    if (!mounted) return;
    if (!success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(grandTestActionProvider.notifier).errorMessage ??
                'Unable to submit exam. Retrying may be required.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      return;
    }
    _goToResult();
  }

  Future<void> _handleExitWarning() async {
    if (_exitDialogOpen || _submitting) return;
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave active attempt?'),
        content: const Text(
          'Leaving this attempt may submit or abandon your attempt. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay in Exam'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Leave Anyway'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || leave != true) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        RouteNames.studentGrandTestOverview,
        pathParameters: {'courseId': widget.courseId},
      );
    }
  }

  void _goToResult() {
    context.goNamed(
      RouteNames.studentGrandTestResult,
      pathParameters: {
        'courseId': widget.courseId,
        'grandTestId': widget.grandTestId,
      },
    );
  }

  bool _isAttemptLimitError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('maximum grand test attempts used') ||
        message.contains('maximum') && message.contains('attempt');
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
