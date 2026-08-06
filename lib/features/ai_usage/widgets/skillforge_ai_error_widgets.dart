import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../copilot/models/copilot_ai_response_model.dart';

class SkillForgeAiUnavailableCard extends StatelessWidget {
  const SkillForgeAiUnavailableCard({
    super.key,
    required this.title,
    required this.message,
    this.suggestions = const <String>[],
    this.onRetry,
    this.onEditRequest,
    this.providerAttempts = const <Map<String, dynamic>>[],
  });

  factory SkillForgeAiUnavailableCard.fromResponse(
    CopilotAiResponseModel response, {
    VoidCallback? onRetry,
    VoidCallback? onEditRequest,
  }) {
    return SkillForgeAiUnavailableCard(
      title: _friendlyTitle(response),
      message: _friendlyMessage(response),
      suggestions: response.suggestions,
      providerAttempts: response.providerAttempts,
      onRetry: onRetry,
      onEditRequest: onEditRequest,
    );
  }

  final String title;
  final String message;
  final List<String> suggestions;
  final VoidCallback? onRetry;
  final VoidCallback? onEditRequest;
  final List<Map<String, dynamic>> providerAttempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...suggestions
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('- '),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
          ],
          if (providerAttempts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: providerAttempts.map((attempt) {
                final provider = attempt['provider']?.toString() ?? 'AI';
                final status = attempt['status']?.toString() ?? 'failed';
                return Chip(label: Text('$provider: $status'));
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry AI'),
                ),
              if (onEditRequest != null)
                OutlinedButton.icon(
                  onPressed: onEditRequest,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Edit Request'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkillForgeAiProviderStatusBadge extends StatelessWidget {
  const SkillForgeAiProviderStatusBadge({
    super.key,
    required this.source,
    this.model,
  });

  final String? source;
  final String? model;

  @override
  Widget build(BuildContext context) {
    final label = switch ((source ?? '').trim()) {
      'openai' => 'OpenAI',
      'openaiBackup' => 'OpenAI Backup',
      'openaiWithRepair' => 'OpenAI + Repair',
      'gemini' => 'Gemini',
      'geminiBackup' => 'Gemini Backup',
      'geminiWithRepair' => 'Gemini + Repair',
      'quotaBlocked' => 'Quota Blocked',
      'validationFailed' => 'Validation Failed',
      'providerError' => 'Provider Error',
      'gatewayUnreachable' => 'Gateway Unreachable',
      'aiUnavailable' => 'AI Unavailable',
      'mock' => 'Mock Provider',
      _ => 'AI Provider',
    };
    return Chip(
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(model == null || model!.isEmpty ? label : '$label - $model'),
    );
  }
}

String _friendlyTitle(CopilotAiResponseModel response) {
  final code =
      response.safeErrorCode ?? response.blockedReason ?? response.status;
  return switch (code) {
    'quotaBlocked' => 'AI credits required',
    'gatewayUnreachable' => 'SkillForge AI is not reachable',
    'providerRateLimited' => 'AI is busy right now',
    'providerAuthError' => 'AI service is not configured',
    'validationFailed' || 'parserFailed' => 'AI response needs retry',
    _ =>
      response.title.isEmpty ? 'AI is temporarily unavailable' : response.title,
  };
}

String _friendlyMessage(CopilotAiResponseModel response) {
  final code =
      response.safeErrorCode ?? response.blockedReason ?? response.status;
  return switch (code) {
    'quotaBlocked' => 'You do not have enough AI credits for this action.',
    'gatewayUnreachable' =>
      'SkillForge AI is not reachable right now. Please make sure the AI Gateway is running and try again.',
    'providerRateLimited' => 'AI is busy right now. Please retry in a moment.',
    'providerAuthError' =>
      'AI service is not configured correctly. Please contact admin.',
    'validationFailed' || 'parserFailed' =>
      'AI generated a response, but it did not meet the required format. Please retry.',
    _ =>
      response.message.isEmpty
          ? 'SkillForge AI could not generate a response right now. Please retry in a moment.'
          : response.message,
  };
}
