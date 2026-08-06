import 'package:flutter/material.dart';

import '../../../ai_usage/widgets/skillforge_ai_widgets.dart';
import '../models/teacher_ai_generation_result_model.dart';
import 'teacher_ai_quality_status_badge.dart';

class TeacherAiPreviewDialog extends StatelessWidget {
  const TeacherAiPreviewDialog({super.key, required this.result});

  final TeacherAiGenerationResultModel result;

  static Future<bool> show(
    BuildContext context,
    TeacherAiGenerationResultModel result,
  ) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => TeacherAiPreviewDialog(result: result),
    );
    return value == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
      title: Row(
        children: [
          Expanded(
            child: Text(
              result.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SkillForgeAiSourceBadge(
                    provider: result.sourceProvider,
                    model: result.model,
                    fallbackUsed: result.isFallback,
                    repaired: result.contentSource.toLowerCase().contains(
                      'repair',
                    ),
                  ),
                  TeacherAiQualityStatusBadge(
                    status: result.qualityStatus,
                    isValid: result.isValid,
                  ),
                  SkillForgeAiUsageBadge(
                    provider: result.sourceProvider,
                    model: result.model,
                    totalTokens: result.totalTokens,
                    credits: result.creditCost,
                    fallbackUsed: result.isFallback,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(result.message, style: theme.textTheme.bodyMedium),
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ListBlock(
                  title: 'Review notes',
                  items: result.warnings,
                  color: Colors.orangeAccent,
                ),
              ],
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ListBlock(
                  title: 'Validation errors',
                  items: result.errors,
                  color: Colors.redAccent,
                ),
              ],
              const SizedBox(height: 16),
              _DataPreview(data: result.data),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: result.isValid
              ? () => Navigator.of(context).pop(true)
              : null,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Apply draft'),
        ),
      ],
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $item'),
            ),
        ],
      ),
    );
  }
}

class _DataPreview extends StatelessWidget {
  const _DataPreview({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = data['questions'] is Iterable
        ? (data['questions'] as Iterable).length
        : 0;
    final deliverables = _stringItems(data['deliverables']);
    final milestones = _stringItems(data['milestones']);
    final rubric = _stringItems(data['rubric']);
    final checklist = _stringItems(data['submissionChecklist']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title']?.toString() ?? 'AI Draft',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (data['description'] ??
                    data['summary'] ??
                    data['instructions'] ??
                    '')
                .toString(),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          if (questions > 0) ...[
            const SizedBox(height: 12),
            Text(
              '$questions questions prepared',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ..._questionPreview(data['questions']),
          ],
          if (deliverables.isNotEmpty)
            _PreviewList(title: 'Deliverables', items: deliverables),
          if (milestones.isNotEmpty)
            _PreviewList(title: 'Milestones', items: milestones),
          if (checklist.isNotEmpty)
            _PreviewList(title: 'Submission checklist', items: checklist),
          if (rubric.isNotEmpty) _PreviewList(title: 'Rubric', items: rubric),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (data['durationMinutes'] != null)
                Chip(label: Text('${data['durationMinutes']} min')),
              if (data['passingScore'] != null)
                Chip(label: Text('Passing ${data['passingScore']}')),
              if (data['totalPoints'] != null)
                Chip(label: Text('${data['totalPoints']} points')),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _stringItems(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .take(8)
          .toList();
    }
    return const <String>[];
  }

  List<Widget> _questionPreview(Object? value) {
    if (value is! Iterable) return const <Widget>[];
    return value
        .whereType<Map>()
        .take(5)
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '- ${item['question'] ?? 'Question'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.title, required this.items});

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
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $item'),
            ),
        ],
      ),
    );
  }
}
