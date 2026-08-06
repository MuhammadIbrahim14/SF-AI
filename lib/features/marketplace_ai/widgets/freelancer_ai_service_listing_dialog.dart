import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_model.dart';
import '../../../models/freelancer_service_model.dart';
import '../../ai_usage/models/ai_usage_models.dart';
import '../models/marketplace_ai_draft_models.dart';
import '../services/marketplace_ai_context_loader.dart';
import '../services/marketplace_ai_service.dart';
import 'marketplace_ai_draft_panel.dart';

class FreelancerAiServiceListingDialog extends StatefulWidget {
  const FreelancerAiServiceListingDialog({
    super.key,
    required this.freelancerId,
    required this.freelancerName,
    required this.onApply,
    this.freelancer,
    this.existingService,
    this.draftFields = const <String, dynamic>{},
    this.platformSkillScore,
    this.knownCertificateIds = const <String>[],
    this.improve = false,
  });

  final String freelancerId;
  final String freelancerName;
  final FreelancerModel? freelancer;
  final FreelancerServiceModel? existingService;
  final Map<String, dynamic> draftFields;
  final double? platformSkillScore;
  final List<String> knownCertificateIds;
  final bool improve;
  final ValueChanged<Map<String, dynamic>> onApply;

  static Future<void> show({
    required BuildContext context,
    required String freelancerId,
    required String freelancerName,
    required ValueChanged<Map<String, dynamic>> onApply,
    FreelancerModel? freelancer,
    FreelancerServiceModel? existingService,
    Map<String, dynamic> draftFields = const {},
    double? platformSkillScore,
    List<String> knownCertificateIds = const [],
    bool improve = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FreelancerAiServiceListingDialog(
        freelancerId: freelancerId,
        freelancerName: freelancerName,
        freelancer: freelancer,
        existingService: existingService,
        draftFields: draftFields,
        platformSkillScore: platformSkillScore,
        knownCertificateIds: knownCertificateIds,
        improve: improve,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FreelancerAiServiceListingDialog> createState() =>
      _FreelancerAiServiceListingDialogState();
}

class _FreelancerAiServiceListingDialogState
    extends State<FreelancerAiServiceListingDialog> {
  final _prompt = TextEditingController();
  final _service = MarketplaceAiService();
  final _contextLoader = MarketplaceAiContextLoader();
  MarketplaceAiDraftResponse? _response;
  bool _loading = false;

  String get _taskType => widget.improve
      ? MarketplaceAiTaskType.freelancerServiceListingImprover
      : MarketplaceAiTaskType.freelancerServiceListingBuilder;

  @override
  void initState() {
    super.initState();
    _prompt.text = MarketplaceAiTaskType.defaultPrompt(improve: widget.improve);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = AiUsageDefaults.featureCosts[_taskType] ?? 1;
    return AlertDialog(
      title: Text(
        widget.improve
            ? 'Improve with SkillForge AI'
            : 'Create with SkillForge AI',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.freelancerPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.freelancerPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_moon_rounded,
                      color: AppColors.freelancerPrimary,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI drafts only. Review every field, then Save Draft or Publish yourself. AI never auto-publishes or sets verified badges.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
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
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Tell AI what kind of service listing you need...',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.freelancerPrimary,
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
                  applyLabel: 'Apply to Service Form',
                  onApplyServiceListing: () {
                    final listing = _response?.serviceListing;
                    if (listing == null) return;
                    widget.onApply(listing.toApplyMap());
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
      final safeContext = _contextLoader.buildServiceListingContext(
        freelancerId: widget.freelancerId,
        freelancerName: widget.freelancerName,
        freelancer: widget.freelancer,
        existingService: widget.existingService,
        draftFields: widget.draftFields,
        serviceId: widget.existingService?.serviceId,
        platformSkillScore: widget.platformSkillScore,
        knownCertificateIds: widget.knownCertificateIds,
      );
      final evidence = _contextLoader.evidenceFromContext(safeContext);
      final response = await _service.generateServiceListing(
        taskType: _taskType,
        prompt: _prompt.text.trim(),
        safeAppContext: safeContext,
        evidence: evidence,
      );
      if (!mounted) return;
      setState(() => _response = response);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
