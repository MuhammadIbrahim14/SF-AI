import 'package:flutter/material.dart';

import '../../../ai_usage/widgets/skillforge_ai_error_widgets.dart';
import '../../../ai_usage/widgets/skillforge_ai_widgets.dart';
import '../models/student_ai_tutor_models.dart';

class StudentAiContextCard extends StatelessWidget {
  const StudentAiContextCard({super.key, required this.context});

  final StudentAiTutorContextModel context;

  @override
  Widget build(BuildContext context_) {
    final theme = Theme.of(context_);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Chip(label: Text(context.courseTitle ?? 'General learning')),
          if ((context.lessonTitle ?? '').isNotEmpty)
            Chip(label: Text('Lesson: ${context.lessonTitle}')),
          Chip(label: Text('Mode: ${context.mode}')),
          Chip(label: Text('Language: ${context.languagePreference}')),
        ],
      ),
    );
  }
}

class StudentAiQuickActions extends StatelessWidget {
  const StudentAiQuickActions({super.key, required this.onAction});

  final void Function(String taskType, String prompt, String mode) onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionChip(
          icon: Icons.lightbulb_rounded,
          label: 'Explain lesson',
          onTap: () => onAction(
            StudentAiTutorTaskType.lessonExplain,
            'Explain this lesson in simple words with examples.',
            'learning',
          ),
        ),
        _ActionChip(
          icon: Icons.psychology_rounded,
          label: 'Simplify concept',
          onTap: () => onAction(
            StudentAiTutorTaskType.conceptSimplifier,
            'Simplify the main concept like I am learning it for the first time.',
            'learning',
          ),
        ),
        _ActionChip(
          icon: Icons.summarize_rounded,
          label: 'Summarize',
          onTap: () => onAction(
            StudentAiTutorTaskType.lessonSummary,
            'Summarize this lesson into key points and one practice task.',
            'learning',
          ),
        ),
        _ActionChip(
          icon: Icons.quiz_rounded,
          label: 'Practice questions',
          onTap: () => onAction(
            StudentAiTutorTaskType.practiceQuestions,
            'Create 10 practice questions with explanations.',
            'practiceMode',
          ),
        ),
        _ActionChip(
          icon: Icons.tips_and_updates_rounded,
          label: 'Give examples',
          onTap: () => onAction(
            StudentAiTutorTaskType.lessonExplain,
            'Give practical examples for this topic and explain how each example works.',
            'learning',
          ),
        ),
        _ActionChip(
          icon: Icons.calendar_month_rounded,
          label: 'Revision plan',
          onTap: () => onAction(
            StudentAiTutorTaskType.revisionPlan,
            'Create a practical 7-day revision plan.',
            'revisionPlan',
          ),
        ),
      ],
    );
  }
}

class StudentAiMessageBubble extends StatelessWidget {
  const StudentAiMessageBubble({
    super.key,
    required this.message,
    this.failed = false,
    this.onRetry,
    this.onCopy,
  });

  final StudentAiTutorMessageModel message;
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final response = message.response;
    final align = message.isStudent
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.isStudent
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: response == null
              ? SelectableText(message.text)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SkillForgeAiSourceBadge(
                          provider: response.sourceProvider,
                          model: response.model,
                          fallbackUsed: response.isFallback,
                          repaired: response.isRepaired,
                        ),
                        SkillForgeAiUsageBadge(
                          provider: response.sourceProvider,
                          model: response.model,
                          totalTokens: response.totalTokens,
                          credits: response.creditCost,
                          fallbackUsed: response.isFallback,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (response.isUnavailable || failed) ...[
                      SkillForgeAiUnavailableCard(
                        title: response.title,
                        message: response.answer,
                        suggestions: response.suggestedNextActions,
                        onRetry: onRetry,
                      ),
                    ] else ...[
                      Text(
                        response.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(response.answer),
                      _ListSection(
                        title: 'Steps',
                        items: response.explanationSteps,
                      ),
                      _ListSection(title: 'Examples', items: response.examples),
                      _ListSection(title: 'Hints', items: response.hints),
                      if (response.practiceQuestions.isNotEmpty)
                        StudentPracticeQuestionsCard(
                          questions: response.practiceQuestions,
                        ),
                      _ListSection(
                        title: 'Revision plan',
                        items: response.revisionPlan,
                      ),
                      _ListSection(
                        title: 'Next actions',
                        items: response.suggestedNextActions,
                      ),
                      _ListSection(
                        title: 'Safety notes',
                        items: response.safetyNotes,
                      ),
                      _ListSection(
                        title: 'Review notes',
                        items: response.qualityWarnings,
                      ),
                    ],
                    if (onCopy != null && !failed) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onCopy,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy'),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class StudentPracticeQuestionsCard extends StatelessWidget {
  const StudentPracticeQuestionsCard({super.key, required this.questions});

  final List<StudentPracticeQuestionModel> questions;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practice questions',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final question in questions.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.question,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (question.options.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        question.options.map((item) => '- $item').join('\n'),
                      ),
                    ),
                  if (question.correctAnswer.isNotEmpty)
                    Text('Answer: ${question.correctAnswer}'),
                  if (question.explanation.isNotEmpty)
                    Text('Why: ${question.explanation}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (final item in items.take(8)) Text('- $item'),
        ],
      ),
    );
  }
}
