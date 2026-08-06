import 'package:flutter/material.dart';

import '../../../../models/job_model.dart';
import '../../../ai_usage/models/ai_usage_models.dart';
import '../models/company_ai_hiring_models.dart';
import '../services/company_ai_hiring_service.dart';
import 'company_ai_hiring_panel.dart';

class CompanyAiJobPostBuilderDialog extends StatefulWidget {
  const CompanyAiJobPostBuilderDialog({
    super.key,
    required this.contextModel,
    required this.onApply,
    this.existingJob,
  });

  final CompanyAiContextModel contextModel;
  final JobModel? existingJob;
  final ValueChanged<Map<String, dynamic>> onApply;

  static Future<void> show({
    required BuildContext context,
    required CompanyAiContextModel contextModel,
    required ValueChanged<Map<String, dynamic>> onApply,
    JobModel? existingJob,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CompanyAiJobPostBuilderDialog(
        contextModel: contextModel,
        existingJob: existingJob,
        onApply: onApply,
      ),
    );
  }

  @override
  State<CompanyAiJobPostBuilderDialog> createState() =>
      _CompanyAiJobPostBuilderDialogState();
}

class _CompanyAiJobPostBuilderDialogState
    extends State<CompanyAiJobPostBuilderDialog> {
  final _prompt = TextEditingController();
  final _service = CompanyAiHiringService();
  CompanyAiHiringResponseModel? _response;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prompt.text = CompanyAiTaskType.defaultPrompt(_taskType);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingJob == null
            ? 'Create with SkillForge AI'
            : 'Improve with SkillForge AI',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CompanyAiFairHiringNotice(),
              const SizedBox(height: 12),
              Chip(
                avatar: const Icon(Icons.bolt_rounded, size: 16),
                label: Text(
                  'Estimated cost: ${AiUsageDefaults.featureCosts[_taskType] ?? 1} AI credits',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prompt,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Tell AI what kind of job post you need...',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_loading ? 'Generating...' : 'Generate Preview'),
              ),
              if (_response != null) ...[
                const SizedBox(height: 16),
                CompanyAiHiringPanel(
                  response: _response!,
                  onApplyJobPost: () {
                    widget.onApply(_response!.jobPost);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String get _taskType => widget.existingJob == null
      ? CompanyAiTaskType.companyJobPostBuilder
      : CompanyAiTaskType.companyJobPostImprover;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final response = await _service.generate(
        CompanyAiHiringRequestModel(
          taskType: _taskType,
          prompt: _prompt.text.trim(),
          context: widget.contextModel,
        ),
      );
      if (!mounted) return;
      setState(() => _response = response);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
