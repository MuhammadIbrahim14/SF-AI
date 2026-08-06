import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../ai_usage/models/ai_usage_models.dart';
import '../models/marketplace_ai_draft_models.dart';
import '../services/marketplace_ai_context_loader.dart';
import '../services/marketplace_ai_service.dart';
import 'marketplace_ai_draft_panel.dart';

/// Small dialog: generate a notes/message draft and Apply into a controller.
class MarketplaceAiNotesDraftDialog extends StatefulWidget {
  const MarketplaceAiNotesDraftDialog({
    super.key,
    required this.taskType,
    required this.onApplyBody,
    this.title = 'Draft with SkillForge AI',
    this.initialPrompt = '',
    this.safeAppContext = const <String, dynamic>{},
    this.evidence = const MarketplaceAiKnownEvidence(),
    this.role = 'freelancer',
    this.accountType = 'professional',
    this.accent = AppColors.freelancerPrimary,
    this.applyLabel = 'Apply to Notes',
  });

  final String taskType;
  final ValueChanged<String> onApplyBody;
  final String title;
  final String initialPrompt;
  final Map<String, dynamic> safeAppContext;
  final MarketplaceAiKnownEvidence evidence;
  final String role;
  final String accountType;
  final Color accent;
  final String applyLabel;

  static Future<void> show({
    required BuildContext context,
    required String taskType,
    required ValueChanged<String> onApplyBody,
    String title = 'Draft with SkillForge AI',
    String initialPrompt = '',
    Map<String, dynamic> safeAppContext = const {},
    MarketplaceAiKnownEvidence evidence = const MarketplaceAiKnownEvidence(),
    String role = 'freelancer',
    String accountType = 'professional',
    Color accent = AppColors.freelancerPrimary,
    String applyLabel = 'Apply to Notes',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MarketplaceAiNotesDraftDialog(
        taskType: taskType,
        onApplyBody: onApplyBody,
        title: title,
        initialPrompt: initialPrompt,
        safeAppContext: safeAppContext,
        evidence: evidence,
        role: role,
        accountType: accountType,
        accent: accent,
        applyLabel: applyLabel,
      ),
    );
  }

  @override
  State<MarketplaceAiNotesDraftDialog> createState() =>
      _MarketplaceAiNotesDraftDialogState();
}

class _MarketplaceAiNotesDraftDialogState
    extends State<MarketplaceAiNotesDraftDialog> {
  final _prompt = TextEditingController();
  final _service = MarketplaceAiService();
  MarketplaceAiDraftResponse? _response;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prompt.text = widget.initialPrompt;
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = AiUsageDefaults.featureCosts[widget.taskType] ?? 1;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI fills the notes field only. You still submit manually. '
                'Nothing is published, paid, messaged, or escrowed automatically.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Chip(
                avatar: const Icon(Icons.bolt_rounded, size: 16),
                label: Text('Estimated cost: $cost AI credits'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prompt,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Context for AI',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                style: FilledButton.styleFrom(backgroundColor: widget.accent),
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
                MarketplaceAiDraftPanel(
                  response: _response!,
                  accent: widget.accent,
                  applyLabel: widget.applyLabel,
                  onApplyTextDraft: () {
                    final body =
                        _response?.textDraft?.composedNoteBody.trim() ?? '';
                    if (body.isEmpty) return;
                    widget.onApplyBody(body);
                    Navigator.of(context).pop();
                  },
                  onDiscard: () => setState(() => _response = null),
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

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final response = await _service.generate(
        taskType: widget.taskType,
        prompt: _prompt.text.trim(),
        safeAppContext: widget.safeAppContext,
        evidence: widget.evidence,
        role: widget.role,
        accountType: widget.accountType,
      );
      if (!mounted) return;
      setState(() => _response = response);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Dialog for customer service request AI fill.
class MarketplaceAiServiceRequestDialog extends StatefulWidget {
  const MarketplaceAiServiceRequestDialog({
    super.key,
    required this.onApply,
    this.initialPrompt = '',
    this.safeAppContext = const <String, dynamic>{},
    this.evidence = const MarketplaceAiKnownEvidence(),
  });

  final ValueChanged<Map<String, dynamic>> onApply;
  final String initialPrompt;
  final Map<String, dynamic> safeAppContext;
  final MarketplaceAiKnownEvidence evidence;

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<Map<String, dynamic>> onApply,
    String initialPrompt = '',
    Map<String, dynamic> safeAppContext = const {},
    MarketplaceAiKnownEvidence evidence = const MarketplaceAiKnownEvidence(),
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MarketplaceAiServiceRequestDialog(
        onApply: onApply,
        initialPrompt: initialPrompt,
        safeAppContext: safeAppContext,
        evidence: evidence,
      ),
    );
  }

  @override
  State<MarketplaceAiServiceRequestDialog> createState() =>
      _MarketplaceAiServiceRequestDialogState();
}

class _MarketplaceAiServiceRequestDialogState
    extends State<MarketplaceAiServiceRequestDialog> {
  final _prompt = TextEditingController();
  final _service = MarketplaceAiService();
  final _loader = MarketplaceAiContextLoader();
  MarketplaceAiDraftResponse? _response;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prompt.text = widget.initialPrompt.isNotEmpty
        ? widget.initialPrompt
        : 'Draft a clear service request from my idea. Fill project title and '
            'requirements. Recommend a package only from the listing context. '
            'Do not invent budget beyond the selected package.';
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const task = MarketplaceAiTaskType.customerServiceRequestDraft;
    final cost = AiUsageDefaults.featureCosts[task] ?? 1;
    return AlertDialog(
      title: const Text('Fill request with AI'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AI fills the request form only. You review, then Submit Request yourself.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Chip(
                avatar: const Icon(Icons.bolt_rounded, size: 16),
                label: Text('Estimated cost: $cost AI credits'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prompt,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'What do you need?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.studentPrimary,
                ),
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
                MarketplaceAiDraftPanel(
                  response: _response!,
                  accent: AppColors.studentPrimary,
                  applyLabel: 'Apply to Request Form',
                  onApplyServiceRequest: () {
                    final draft = _response?.serviceRequest;
                    if (draft == null) return;
                    widget.onApply(draft.toApplyMap());
                    Navigator.of(context).pop();
                  },
                  onDiscard: () => setState(() => _response = null),
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

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final hydrated = await _loader.hydrateIds(
        serviceId: widget.safeAppContext['serviceId']?.toString(),
        requestId: widget.safeAppContext['requestId']?.toString(),
        orderId: widget.safeAppContext['orderId']?.toString(),
      );
      final response = await _service.generate(
        taskType: MarketplaceAiTaskType.customerServiceRequestDraft,
        prompt: _prompt.text.trim(),
        safeAppContext: {...hydrated, ...widget.safeAppContext},
        evidence: widget.evidence,
        role: 'customer',
        accountType: 'customer',
        screen: 'ServiceRequestForm',
      );
      if (!mounted) return;
      setState(() => _response = response);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
