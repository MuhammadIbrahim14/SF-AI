import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ai_usage/widgets/skillforge_ai_error_widgets.dart';
import '../models/company_ai_hiring_models.dart';

class CompanyAiFairHiringNotice extends StatelessWidget {
  const CompanyAiFairHiringNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.companyPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance_rounded, color: AppColors.companyPrimary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fair hiring mode: AI uses only role-relevant evidence, ignores protected attributes, and never changes candidate status automatically.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyAiHiringPanel extends StatelessWidget {
  const CompanyAiHiringPanel({
    super.key,
    required this.response,
    this.onApplyJobPost,
  });

  final CompanyAiHiringResponseModel response;
  final VoidCallback? onApplyJobPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (response.isUnavailable) {
      return SkillForgeAiUnavailableCard(
        title: response.title,
        message: response.summary,
        suggestions: response.recommendations,
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  response.sourceProvider.trim().isEmpty
                      ? 'AI Provider'
                      : 'Generated with ${response.sourceProvider}',
                ),
              ),
              const Chip(
                avatar: Icon(Icons.fact_check_rounded, size: 16),
                label: Text('Manual review required'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            response.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(response.summary),
          const SizedBox(height: 14),
          _NextStepStrip(response: response),
          if (response.hasJobPost && onApplyJobPost != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onApplyJobPost,
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Apply Job Post to Form'),
            ),
          ],
          const SizedBox(height: 16),
          if (response.hasJobPost) ...[
            _JobPostPreview(jobPost: response.jobPost),
            const SizedBox(height: 16),
          ],
          if (response.structuredData['messageDraft'] is Map) ...[
            CompanyAiMessageDraftCard.fromData(
              Map<String, dynamic>.from(
                response.structuredData['messageDraft'] as Map,
              ),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: const JsonEncoder.withIndent(
                    '  ',
                  ).convert(response.structuredData),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI output copied for review.')),
              );
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy Full Output'),
          ),
          const SizedBox(height: 16),
          _StructuredDataView(data: response.structuredData),
          if (response.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ListBlock(
              title: 'Recommendations',
              items: response.recommendations,
            ),
          ],
          if (response.safetyNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ListBlock(title: 'Safety notes', items: response.safetyNotes),
          ],
        ],
      ),
    );
  }
}

class CompanyAiMessageDraftCard extends StatelessWidget {
  const CompanyAiMessageDraftCard({
    super.key,
    required this.subject,
    required this.body,
  });

  final String subject;
  final String body;

  factory CompanyAiMessageDraftCard.fromData(Map<String, dynamic> data) {
    return CompanyAiMessageDraftCard(
      subject: data['subject']?.toString() ?? 'Candidate update',
      body: data['body']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subject, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SelectableText(body),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: 'Subject: $subject\n\n$body'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Draft copied. Review before sending.'),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy Draft'),
        ),
      ],
    );
  }
}

class _NextStepStrip extends StatelessWidget {
  const _NextStepStrip({required this.response});

  final CompanyAiHiringResponseModel response;

  @override
  Widget build(BuildContext context) {
    final text = switch (response.taskType) {
      CompanyAiTaskType.companyJobPostBuilder =>
        'Review the generated fields. In the job form, press "Apply Job Post to Form", then manually save.',
      CompanyAiTaskType.companyJobPostImprover =>
        'Compare the improved draft below with your selected job. Apply only the changes you approve.',
      CompanyAiTaskType.companyCandidateMessageDraft =>
        'Copy the draft, review it, then send manually from your normal communication flow.',
      CompanyAiTaskType.companyCandidateComparison ||
      CompanyAiTaskType.companyShortlistAssistant =>
        'Use this as a review order, not a hiring decision. Candidate statuses were not changed.',
      CompanyAiTaskType.companyInterviewQuestionBuilder ||
      CompanyAiTaskType.companyInterviewScorecardBuilder ||
      CompanyAiTaskType.companyInterviewKitBuilder =>
        'Use this kit during interview preparation. Scores must still be entered manually.',
      CompanyAiTaskType.companyHiringPipelineInsights ||
      CompanyAiTaskType.companySkillGapAnalysis =>
        'Use these insights as a manual checklist for improving the pipeline and job clarity.',
      _ => 'Review the output manually before using it.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.companyPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.next_plan_rounded, color: AppColors.companyPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPostPreview extends StatelessWidget {
  const _JobPostPreview({required this.jobPost});

  final Map<String, dynamic> jobPost;

  @override
  Widget build(BuildContext context) {
    final title = _text('title', 'Generated job post');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(_text('summary', _text('description'))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_text('category').isNotEmpty)
                _PreviewChip(label: 'Category', value: _text('category')),
              if (_text('experienceLevel').isNotEmpty)
                _PreviewChip(label: 'Level', value: _text('experienceLevel')),
              if (_text('employmentType').isNotEmpty)
                _PreviewChip(label: 'Type', value: _text('employmentType')),
              if (_text('locationType').isNotEmpty)
                _PreviewChip(label: 'Location', value: _text('locationType')),
              if (_text('minimumSkillScore').isNotEmpty)
                _PreviewChip(
                  label: 'Skill Score',
                  value: _text('minimumSkillScore'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PreviewList(
            title: 'Required skills',
            items: _list('requiredSkills'),
          ),
          _PreviewList(
            title: 'Preferred skills',
            items: _list('preferredSkills'),
          ),
          _PreviewList(title: 'Requirements', items: _list('requirements')),
          _PreviewList(
            title: 'Screening questions',
            items: _list('screeningQuestions'),
          ),
        ],
      ),
    );
  }

  String _text(String key, [String fallback = '']) {
    final value = jobPost[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _list(String key) {
    final value = jobPost[key];
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
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
      padding: const EdgeInsets.only(top: 10),
      child: _ListBlock(title: title, items: items),
    );
  }
}

class _StructuredDataView extends StatelessWidget {
  const _StructuredDataView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Text('No structured output available.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _DataValue(title: _label(entry.key), value: entry.value),
        );
      }).toList(),
    );
  }

  String _label(String value) {
    return value
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .trim();
  }
}

class _DataValue extends StatelessWidget {
  const _DataValue({required this.title, required this.value});

  final String title;
  final Object? value;

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
        if (value is Map)
          ...Map<String, dynamic>.from(value as Map).entries.map(
            (entry) => _DataValue(title: entry.key, value: entry.value),
          )
        else if (value is Iterable)
          _ListBlock(
            title: '',
            items: (value as Iterable).map((item) => item.toString()).toList(),
          )
        else
          SelectableText(value?.toString() ?? '-'),
      ],
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        if (title.isNotEmpty) const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18),
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
