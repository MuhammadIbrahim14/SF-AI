import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../data/models/mcq_assignment_model.dart';
import '../providers/assignment_provider.dart';

class McqAttemptScreen extends ConsumerStatefulWidget {
  const McqAttemptScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  final String courseId;
  final String assignmentId;

  @override
  ConsumerState<McqAttemptScreen> createState() => _McqAttemptScreenState();
}

class _McqAttemptScreenState extends ConsumerState<McqAttemptScreen> {
  final Map<String, String> _answers = {};
  final List<_QuestionView> _questions = [];
  Timer? _timer;
  int _remainingSeconds = 0;
  int _warningsCount = 0;
  bool _initialized = false;
  bool _submitting = false;
  bool _exitDialogOpen = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignmentAsync = ref.watch(
      assignmentDetailProvider((
        courseId: widget.courseId,
        assignmentId: widget.assignmentId,
      )),
    );
    final attempt = ref
        .watch(
          studentAssignmentAttemptProvider((
            courseId: widget.courseId,
            assignmentId: widget.assignmentId,
          )),
        )
        .value;

    if (attempt?.isSubmitted == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('MCQ Assignment')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => _goToResult(),
            icon: const Icon(Icons.analytics_rounded),
            label: const Text('View Result'),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExitWarning();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MCQ Assignment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleExitWarning,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: assignmentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (assignment) {
              if (assignment == null || !assignment.isPublished) {
                return const Center(child: Text('Assignment unavailable.'));
              }
              if (!_initialized) _initialize(assignment);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    assignment.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Questions are randomized. Timer auto-submits when it ends.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_warningsCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Warnings: $_warningsCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (var index = 0; index < _questions.length; index++)
                    _QuestionTile(
                      index: index,
                      question: _questions[index],
                      selectedAnswer: _answers[_questions[index].questionId],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _answers[_questions[index].questionId] = value;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _submit(autoSubmitted: false),
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_submitting ? 'Submitting...' : 'Submit'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _initialize(McqAssignmentModel assignment) {
    _initialized = true;
    _remainingSeconds = max(1, assignment.timeLimitMinutes) * 60;
    final random = Random();
    final shuffled = [...assignment.questions]..shuffle(random);
    _questions
      ..clear()
      ..addAll(
        shuffled.map((question) {
          final options = [...question.options]..shuffle(random);
          return _QuestionView(
            questionId: question.questionId,
            question: question.question,
            options: options,
          );
        }),
      );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
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

  Future<void> _submit({required bool autoSubmitted}) async {
    if (_submitting) return;
    if (_answers.isEmpty && !autoSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Answer at least one question to submit.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    _timer?.cancel();

    final success = await ref
        .read(assignmentActionProvider.notifier)
        .submitAttempt(
          courseId: widget.courseId,
          assignmentId: widget.assignmentId,
          answers: _answers,
          warningsCount: _warningsCount,
          autoSubmitted: autoSubmitted,
        );
    if (!mounted) return;
    if (!success) {
      setState(() => _submitting = false);
      final message =
          ref.read(assignmentActionProvider.notifier).errorMessage ??
          'Unable to submit assignment.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _goToResult();
  }

  Future<void> _handleExitWarning() async {
    if (_exitDialogOpen || _submitting) return;
    _exitDialogOpen = true;
    setState(() => _warningsCount++);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave active attempt?'),
        content: const Text(
          'Leaving this attempt may submit or abandon your attempt. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || shouldLeave != true) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(
      RouteNames.studentAssignments,
      pathParameters: {'courseId': widget.courseId},
    );
  }

  void _goToResult() {
    context.goNamed(
      RouteNames.studentAssignmentResult,
      pathParameters: {
        'courseId': widget.courseId,
        'assignmentId': widget.assignmentId,
      },
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

class _QuestionView {
  const _QuestionView({
    required this.questionId,
    required this.question,
    required this.options,
  });

  final String questionId;
  final String question;
  final List<String> options;
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.index,
    required this.question,
    required this.selectedAnswer,
    required this.onChanged,
  });

  final int index;
  final _QuestionView question;
  final String? selectedAnswer;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${index + 1}. ${question.question}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...question.options.map((option) {
              final selected = option == selectedAnswer;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(option)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
