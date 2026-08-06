import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../models/interview_lab_models.dart';
import '../providers/interview_lab_providers.dart';
import 'widgets/interview_lab_widgets.dart';

class InterviewLabSessionScreen extends ConsumerStatefulWidget {
  const InterviewLabSessionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<InterviewLabSessionScreen> createState() =>
      _InterviewLabSessionScreenState();
}

class _InterviewLabSessionScreenState
    extends ConsumerState<InterviewLabSessionScreen> {
  final _answerCtrl = TextEditingController();
  Timer? _tick;
  Timer? _autosave;
  int _elapsedSeconds = 0;
  int _questionStartedAt = 0;
  String? _boundQuestionId;
  bool _busy = false;
  String? _error;
  bool _finishing = false;
  bool _activating = false;
  bool _activationRequested = false;
  bool _expiryPromptShown = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
    _answerCtrl.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _autosave?.cancel();
    _answerCtrl.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 700), () async {
      final qid = _boundQuestionId;
      if (qid == null || !mounted) return;
      await ref.read(interviewLabActionProvider.notifier).autosaveDraft(
            sessionId: widget.sessionId,
            questionId: qid,
            answer: _answerCtrl.text,
          );
    });
  }

  void _bindQuestion(InterviewLabQuestionModel? q) {
    if (q == null) return;
    if (_boundQuestionId == q.questionId) return;
    _boundQuestionId = q.questionId;
    _answerCtrl.text = q.candidateAnswer ?? '';
    _questionStartedAt = _elapsedSeconds;
  }

  UserRole _pageRole() {
    final user = ref.read(currentUserProvider).value;
    if (user?.primaryRole == UserRole.freelancer) return UserRole.freelancer;
    return UserRole.student;
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave interview?'),
        content: const Text(
          'Your answers are auto-saved. You can resume later from Interview Lab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pause & leave'),
          ),
        ],
      ),
    );
    if (result == true) {
      await ref
          .read(interviewLabActionProvider.notifier)
          .pauseSession(widget.sessionId);
      return true;
    }
    return false;
  }

  Future<void> _ensureInProgress(InterviewLabSessionModel session) async {
    if (!mounted || _activationRequested) return;
    if (session.status != InterviewLabSessionStatus.ready &&
        session.status != InterviewLabSessionStatus.paused) {
      return;
    }
    _activationRequested = true;
    setState(() {
      _activating = true;
      _error = null;
    });
    final ok = await ref
        .read(interviewLabActionProvider.notifier)
        .beginAnswering(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _activating = false;
      if (!ok) {
        _activationRequested = false;
        _error = ref.read(interviewLabActionProvider.notifier).lastErrorMessage ??
            'Unable to resume this interview. Please try again.';
      }
    });
  }

  void _scheduleEnsureInProgress(InterviewLabSessionModel? session) {
    if (session == null) return;
    if (session.status != InterviewLabSessionStatus.ready &&
        session.status != InterviewLabSessionStatus.paused) {
      return;
    }
    if (_activationRequested || _activating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureInProgress(session);
    });
  }

  Future<void> _next({
    required InterviewLabSessionModel session,
    required List<InterviewLabQuestionModel> questions,
    required InterviewLabQuestionModel current,
    required bool skip,
  }) async {
    if (session.isTimerExpired) {
      await _finish(forcedByTimer: true);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = ref.read(interviewLabActionProvider.notifier);

    // Guarantee active status before submit/skip (covers pause → continue).
    if (session.status == InterviewLabSessionStatus.ready ||
        session.status == InterviewLabSessionStatus.paused) {
      final resumed = await notifier.beginAnswering(widget.sessionId);
      if (!resumed) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = notifier.lastErrorMessage ??
              'Unable to resume this interview. Please try again.';
        });
        return;
      }
    }

    if (current.critiqueLocked) {
      final nextIdx = session.currentQuestionIndex + 1;
      if (nextIdx < questions.length) {
        await notifier.goToQuestion(
          sessionId: widget.sessionId,
          questionIndex: nextIdx,
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }

    final spent = (_elapsedSeconds - _questionStartedAt).clamp(0, 3600);
    final ok = skip
        ? await notifier.skipQuestion(
            sessionId: widget.sessionId,
            questionId: current.questionId,
            timeSpentSeconds: spent,
          )
        : await notifier.submitAnswer(
            sessionId: widget.sessionId,
            questionId: current.questionId,
            answer: _answerCtrl.text,
            timeSpentSeconds: spent,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      final msg = notifier.lastErrorMessage ??
          'AI evaluation is temporarily unavailable. Please try again.';
      if (msg.toLowerCase().contains('timer')) {
        await _finish(forcedByTimer: true);
        return;
      }
      setState(() => _error = msg);
    }
  }

  Future<void> _previous({
    required InterviewLabSessionModel session,
  }) async {
    if (session.currentQuestionIndex <= 0) return;
    setState(() => _busy = true);
    await ref.read(interviewLabActionProvider.notifier).goToQuestion(
          sessionId: widget.sessionId,
          questionIndex: session.currentQuestionIndex - 1,
        );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish({
    bool forcedByTimer = false,
    bool skipConfirm = false,
  }) async {
    if (_finishing) return;

    if (!skipConfirm) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: !forcedByTimer,
        builder: (ctx) => AlertDialog(
          title: Text(forcedByTimer ? 'Time is up' : 'Finish interview?'),
          content: Text(
            forcedByTimer
                ? 'Your interview timer has ended. Finish now to generate your report from answered questions.'
                : 'We will run AI evaluation and open your professional report.',
          ),
          actions: [
            if (!forcedByTimer)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continue answering'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(forcedByTimer ? 'Generate report' : 'Finish'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() {
      _finishing = true;
      _error = null;
    });

    try {
      final questions =
          ref.read(interviewLabQuestionsProvider(widget.sessionId)).value ?? [];
      var session =
          ref.read(interviewLabSessionProvider(widget.sessionId)).value;
      if (session != null &&
          (session.status == InterviewLabSessionStatus.ready ||
              session.status == InterviewLabSessionStatus.paused)) {
        final resumed = await ref
            .read(interviewLabActionProvider.notifier)
            .beginAnswering(widget.sessionId);
        if (!resumed) {
          if (!mounted) return;
          setState(() {
            _finishing = false;
            _error = ref
                    .read(interviewLabActionProvider.notifier)
                    .lastErrorMessage ??
                'Unable to resume this interview before finishing.';
          });
          return;
        }
        session =
            ref.read(interviewLabSessionProvider(widget.sessionId)).value;
      }

      final timerExpired = forcedByTimer || (session?.isTimerExpired ?? false);

      if (!timerExpired && session != null && questions.isNotEmpty) {
        final idx = session.currentQuestionIndex.clamp(0, questions.length - 1);
        final current = questions[idx];
        if (!current.critiqueLocked && _answerCtrl.text.trim().isNotEmpty) {
          final submitted = await ref
              .read(interviewLabActionProvider.notifier)
              .submitAnswer(
                sessionId: widget.sessionId,
                questionId: current.questionId,
                answer: _answerCtrl.text,
                timeSpentSeconds:
                    (_elapsedSeconds - _questionStartedAt).clamp(0, 3600),
              );
          if (!submitted && mounted) {
            final msg = ref
                    .read(interviewLabActionProvider.notifier)
                    .lastErrorMessage ??
                '';
            if (!msg.toLowerCase().contains('timer')) {
              setState(() {
                _finishing = false;
                _error = msg.isEmpty
                    ? 'AI evaluation is temporarily unavailable.'
                    : msg;
              });
              return;
            }
          }
        }
      }

      final ok = await ref
          .read(interviewLabActionProvider.notifier)
          .completeSession(widget.sessionId)
          .timeout(
            const Duration(seconds: 100),
            onTimeout: () => false,
          );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _finishing = false;
          _error = ref
                  .read(interviewLabActionProvider.notifier)
                  .lastErrorMessage ??
              'Report generation timed out or failed. Please try Generate report again.';
        });
        return;
      }
      context.pushReplacementNamed(
        RouteNames.interviewLabReport,
        pathParameters: {'sessionId': widget.sessionId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _error = 'Could not generate report: $e';
      });
    }
  }

  void _maybePromptTimerExpiry(InterviewLabSessionModel session) {
    if (!session.isTimerExpired || _expiryPromptShown || _finishing || _busy) {
      return;
    }
    _expiryPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finishing) return;
      _finish(forcedByTimer: true);
    });
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtCountdown(InterviewLabSessionModel session) {
    if (!session.timerEnforced || session.timerDeadlineAt == null) {
      return _fmt(_elapsedSeconds);
    }
    if (session.isTimerExpired) return '0:00';
    return _fmt(session.timerRemainingSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionAsync =
        ref.watch(interviewLabSessionProvider(widget.sessionId));
    final questionsAsync =
        ref.watch(interviewLabQuestionsProvider(widget.sessionId));

    // Never call setState from the build path — schedule resume after frame.
    ref.listen<AsyncValue<InterviewLabSessionModel?>>(
      interviewLabSessionProvider(widget.sessionId),
      (previous, next) {
        _scheduleEnsureInProgress(next.asData?.value);
      },
    );
    _scheduleEnsureInProgress(sessionAsync.asData?.value);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && mounted) context.pop();
      },
      child: RoleFixedHeaderPage(
        role: _pageRole(),
        title: 'Practice interview',
        subtitle: 'Senior AI interviewer · adaptive follow-ups · auto-save',
        onBack: () async {
          final leave = await _confirmExit();
          if (leave && mounted) context.pop();
        },
        scrollable: true,
        child: sessionAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e'),
          ),
          data: (session) {
            if (session == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Session not found.'),
              );
            }

            if (_activating) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Resuming your interview…',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return questionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$e'),
              ),
              data: (questions) {
                if (questions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No questions in this session.'),
                  );
                }
                final idx =
                    session.currentQuestionIndex.clamp(0, questions.length - 1);
                final current = questions[idx];
                _bindQuestion(current);
                final progress = (idx + 1) / questions.length;
                final timerExpired = session.isTimerExpired;
                _maybePromptTimerExpiry(session);

                if (_finishing || _busy || _activating) {
                  return Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _finishing
                              ? 'Building your interview report…'
                              : _activating
                                  ? 'Resuming your interview…'
                                  : 'Senior interviewer is evaluating your answer…',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _finishing
                              ? 'Using AI when available. If the gateway is slow, an evidence-based report is generated from your answers.'
                              : _activating
                                  ? 'Restoring your paused session.'
                                  : 'Adaptive difficulty and follow-ups may apply.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Question ${idx + 1} of ${questions.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            avatar: Icon(
                              timerExpired
                                  ? Icons.timer_off_outlined
                                  : Icons.timer_outlined,
                              size: 18,
                            ),
                            label: Text(
                              session.timerEnforced &&
                                      session.timerDeadlineAt != null
                                  ? (timerExpired
                                      ? 'Time up'
                                      : _fmtCountdown(session))
                                  : _fmt(_elapsedSeconds),
                            ),
                            backgroundColor: timerExpired
                                ? AppColors.error.withValues(alpha: 0.12)
                                : null,
                          ),
                        ],
                      ),
                      if (timerExpired) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.error.withValues(alpha: 0.08),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Interview timer ended',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'New answers are closed. Finish now to generate your report from what you already completed.',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _finish(
                                  forcedByTimer: true,
                                  skipConfirm: true,
                                ),
                                icon: const Icon(Icons.flag_rounded),
                                label: const Text('Generate report'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              interviewLabCategoryLabel(current.category),
                            ),
                          ),
                          if (current.isFollowUp)
                            const Chip(
                              avatar: Icon(Icons.forum_outlined, size: 16),
                              label: Text('Follow-up'),
                            ),
                          Chip(
                            label: Text(current.difficulty),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        current.prompt,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _answerCtrl,
                        minLines: 8,
                        maxLines: 14,
                        enabled: !current.critiqueLocked && !timerExpired,
                        decoration: InputDecoration(
                          hintText: timerExpired
                              ? 'Timer ended — finish to generate your report.'
                              : 'Type your answer…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                        ),
                      ),
                      if (current.critiqueLocked &&
                          (current.aiCritique ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            color: AppColors.primary.withValues(alpha: 0.06),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interviewer feedback',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(current.aiCritique!),
                              if (current.scoreOverall != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Score ${current.scoreOverall!.toStringAsFixed(0)}'
                                  '${current.improvement != null && current.improvement!.isNotEmpty ? ' · ${current.improvement}' : ''}',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: (idx == 0 || timerExpired)
                                ? null
                                : () => _previous(session: session),
                            child: const Text('Previous'),
                          ),
                          OutlinedButton(
                            onPressed: (current.critiqueLocked || timerExpired)
                                ? null
                                : () => _next(
                                      session: session,
                                      questions: questions,
                                      current: current,
                                      skip: true,
                                    ),
                            child: const Text('Skip'),
                          ),
                          if (timerExpired)
                            FilledButton.icon(
                              onPressed: () => _finish(
                                forcedByTimer: true,
                                skipConfirm: true,
                              ),
                              icon: const Icon(Icons.flag_rounded),
                              label: const Text('Generate report'),
                            )
                          else if (idx < questions.length - 1)
                            FilledButton(
                              onPressed: () => _next(
                                session: session,
                                questions: questions,
                                current: current,
                                skip: false,
                              ),
                              child: Text(
                                current.critiqueLocked ? 'Continue' : 'Next',
                              ),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () => _finish(),
                              icon: const Icon(Icons.flag_rounded),
                              label: const Text('Finish'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timerExpired
                            ? 'Timer closed new answers. Your completed answers still count toward the report.'
                            : 'Each answer is AI-evaluated once (locked). Skip applies a confidence penalty.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
