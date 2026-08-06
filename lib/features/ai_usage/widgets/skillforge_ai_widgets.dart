import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_usage_models.dart';
import '../providers/ai_usage_provider.dart';

class SkillForgeAiSourceBadge extends StatelessWidget {
  const SkillForgeAiSourceBadge({
    super.key,
    required this.provider,
    this.model,
    this.fallbackUsed = false,
    this.repaired = false,
  });

  final String provider;
  final String? model;
  final bool fallbackUsed;
  final bool repaired;

  @override
  Widget build(BuildContext context) {
    final label = fallbackUsed
        ? 'AI Unavailable'
        : repaired
        ? '${_providerLabel(provider)} + Repair'
        : _providerLabel(provider);
    return _Pill(
      icon: Icons.auto_awesome_rounded,
      label: (model ?? '').trim().isEmpty ? label : '$label - $model',
      color: Theme.of(context).colorScheme.primary,
    );
  }

  String _providerLabel(String value) {
    return switch (value.toLowerCase()) {
      'openai' => 'OpenAI',
      'gemini' => 'Gemini',
      'openaiBackup' => 'OpenAI Backup',
      'openaiWithRepair' => 'OpenAI + Repair',
      'geminiBackup' => 'Gemini Backup',
      'geminiWithRepair' => 'Gemini + Repair',
      'quotaBlocked' => 'Quota Blocked',
      'validationFailed' => 'Validation Failed',
      'providerError' => 'Provider Error',
      'gatewayUnreachable' => 'Gateway Unreachable',
      'aiUnavailable' => 'AI Unavailable',
      'mock' => 'Mock Provider',
      _ => 'SkillForge AI',
    };
  }
}

class SkillForgeAiUsageBadge extends StatelessWidget {
  const SkillForgeAiUsageBadge({
    super.key,
    required this.provider,
    this.model,
    this.totalTokens,
    this.credits = 0,
    this.fallbackUsed = false,
  });

  final String provider;
  final String? model;
  final int? totalTokens;
  final int credits;
  final bool fallbackUsed;

  @override
  Widget build(BuildContext context) {
    final tokens = totalTokens == null ? '0 tokens' : '$totalTokens tokens';
    final creditLabel = fallbackUsed ? '0 credits' : '$credits credits';
    return _Pill(
      icon: Icons.data_usage_rounded,
      label:
          '${fallbackUsed ? 'AI Unavailable' : provider} - '
          '${model ?? 'model'} - $tokens - $creditLabel',
      color: Colors.cyanAccent.shade400,
    );
  }
}

class SkillForgeAiStatusBanner extends StatelessWidget {
  const SkillForgeAiStatusBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class SkillForgeAiErrorCard extends StatelessWidget {
  const SkillForgeAiErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SkillForgeAiStatusBanner(
      message: message,
      icon: Icons.warning_amber_rounded,
      color: Theme.of(context).colorScheme.error,
    );
  }
}

class SkillForgeAiReviewWarning extends StatelessWidget {
  const SkillForgeAiReviewWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkillForgeAiStatusBanner(
      message:
          'AI creates a draft only. Review carefully before saving or publishing.',
      icon: Icons.fact_check_rounded,
    );
  }
}

class SkillForgeAiCreditBalanceCard extends ConsumerWidget {
  const SkillForgeAiCreditBalanceCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(currentAiUserCreditsProvider);
    return creditsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => SkillForgeAiStatusBanner(
        message:
            'AI credits are using local defaults until the quota setup finishes.',
        icon: Icons.sync_problem_rounded,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      data: (credits) => _CreditCard(credits: credits, compact: compact),
    );
  }
}

class _CreditCard extends ConsumerWidget {
  const _CreditCard({required this.credits, required this.compact});

  final AiUserCreditsModel credits;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: compact
          ? Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _children(context, ref),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _children(context, ref),
            ),
    );
  }

  List<Widget> _children(BuildContext context, WidgetRef ref) {
    return [
      _Pill(
        icon: Icons.bolt_rounded,
        label: '${credits.remainingCredits} AI Credits left',
        color: Theme.of(context).colorScheme.primary,
      ),
      Text(
        'Used ${credits.usedCreditsThisMonth}/${credits.monthlyFreeCredits} monthly free credits'
        ' - Bonus ${credits.bonusCredits} - Resets ${credits.currentMonthKey}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      OutlinedButton.icon(
        onPressed: () => _showRequestDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request More AI Credits'),
      ),
    ];
  }

  Future<void> _showRequestDialog(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController(text: '50');
    final reason = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request AI Credits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Requested credits'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
    if (submit != true || !context.mounted) return;
    await ref
        .read(aiCreditRequestActionProvider.notifier)
        .requestMoreCredits(
          requestedCredits: int.tryParse(amount.text.trim()) ?? 0,
          reason: reason.text.trim(),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI credit request submitted.')),
    );
  }
}

class SkillForgeAiHeavyTaskDialog {
  const SkillForgeAiHeavyTaskDialog._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required int credits,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          'This is a heavy AI task and may consume $credits AI Credits. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
