import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../ai_usage/widgets/skillforge_ai_error_widgets.dart';
import '../models/marketplace_ai_draft_models.dart';
import '../services/marketplace_ai_quality_gates.dart';

class MarketplaceAiDraftPanel extends StatelessWidget {
  const MarketplaceAiDraftPanel({
    super.key,
    required this.response,
    this.accent = AppColors.freelancerPrimary,
    this.onApplyServiceListing,
    this.onApplyServiceRequest,
    this.onApplyTextDraft,
    this.onApplyProfile,
    this.onApplyChecklist,
    this.applyLabel = 'Apply to Form',
    this.onDiscard,
    this.showQualityWarnings = true,
  });

  final MarketplaceAiDraftResponse response;
  final Color accent;
  final VoidCallback? onApplyServiceListing;
  final VoidCallback? onApplyServiceRequest;
  final VoidCallback? onApplyTextDraft;
  final VoidCallback? onApplyProfile;
  final VoidCallback? onApplyChecklist;
  final String applyLabel;
  final VoidCallback? onDiscard;
  final bool showQualityWarnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (response.isUnavailable) {
      return SkillForgeAiUnavailableCard(
        title: response.title,
        message: response.summary,
        suggestions: response.suggestions,
      );
    }

    final checklist = response.fieldChecklist;
    final warnings = _warnings();

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
            children: [
              Chip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  response.provider.trim().isEmpty
                      ? 'AI Provider'
                      : 'Generated with ${response.provider}',
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
          if (checklist.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Structured fields',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in checklist)
                  Chip(
                    avatar: Icon(
                      entry.value
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: entry.value ? accent : null,
                    ),
                    label: Text(entry.key),
                  ),
              ],
            ),
          ],
          if (response.textDraft != null &&
              response.textDraft!.composedNoteBody.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Draft preview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(response.textDraft!.composedNoteBody),
          ],
          if (response.serviceListing != null &&
              response.serviceListing!.packagesPipeText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Packages',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(response.serviceListing!.packagesPipeText),
          ],
          if (response.comparison != null) ...[
            const SizedBox(height: 12),
            if (response.comparison!.notEnoughEvidence)
              const Text(
                'Not enough evidence to compare freelancers fairly.',
                style: TextStyle(fontWeight: FontWeight.w700),
              )
            else
              for (final candidate in response.comparison!.candidates.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${candidate['name'] ?? candidate['title'] ?? 'Candidate'}: '
                    '${candidate['summary'] ?? candidate['evidence'] ?? ''}',
                  ),
                ),
          ],
          if (response.acceptanceChecklist != null) ...[
            const SizedBox(height: 12),
            for (final item in response.acceptanceChecklist!.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('☐ ${item.label}'),
              ),
          ],
          if (showQualityWarnings && warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Soft quality checks',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  for (final warning in warnings)
                    Text('• $warning'),
                ],
              ),
            ),
          ],
          if (response.suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Suggestions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in response.suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item'),
              ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (response.hasServiceListing && onApplyServiceListing != null)
                FilledButton.icon(
                  onPressed: onApplyServiceListing,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.post_add_rounded),
                  label: Text(applyLabel),
                ),
              if (response.hasServiceRequest && onApplyServiceRequest != null)
                FilledButton.icon(
                  onPressed: onApplyServiceRequest,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.assignment_rounded),
                  label: Text(applyLabel),
                ),
              if (response.hasTextDraft && onApplyTextDraft != null)
                FilledButton.icon(
                  onPressed: onApplyTextDraft,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(applyLabel),
                ),
              if (response.hasProfile && onApplyProfile != null)
                FilledButton.icon(
                  onPressed: onApplyProfile,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.person_rounded),
                  label: Text(applyLabel),
                ),
              if (response.hasChecklist && onApplyChecklist != null)
                FilledButton.icon(
                  onPressed: onApplyChecklist,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(applyLabel),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  final payload = response.primaryApplyMap;
                  final text = payload != null
                      ? const JsonEncoder.withIndent('  ').convert(payload)
                      : [
                          response.title,
                          response.summary,
                          ...response.suggestions.map((item) => '- $item'),
                        ].join('\n\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI draft copied.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy Draft'),
              ),
              if (onDiscard != null)
                TextButton(onPressed: onDiscard, child: const Text('Discard')),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _warnings() {
    if (response.serviceListing != null) {
      return MarketplaceAiQualityGates.listingWarnings(response.serviceListing!);
    }
    if (response.serviceRequest != null) {
      return MarketplaceAiQualityGates.serviceRequestWarnings(
        response.serviceRequest!,
      );
    }
    if (response.profile != null) {
      return MarketplaceAiQualityGates.profileWarnings(response.profile!);
    }
    return const [];
  }
}
