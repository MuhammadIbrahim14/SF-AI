import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/copilot_action_model.dart';
import '../providers/copilot_provider.dart';

class CopilotQuickActions extends ConsumerWidget {
  const CopilotQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(copilotQuickActionsProvider);
    if (actions.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          _CopilotQuickActionChip(
            action: action,
            colorScheme: colorScheme,
            onTap: () => ref
                .read(copilotProvider.notifier)
                .executeQuickAction(context, action),
          ),
      ],
    );
  }
}

class _CopilotQuickActionChip extends StatelessWidget {
  const _CopilotQuickActionChip({
    required this.action,
    required this.colorScheme,
    required this.onTap,
  });

  final CopilotActionModel action;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(_iconFor(action.actionId), size: 17),
      label: Text(action.label),
      tooltip: action.unavailableReason ?? action.label,
      onPressed: onTap,
      side: BorderSide(color: colorScheme.outlineVariant),
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
    );
  }
}

IconData _iconFor(String actionId) {
  if (actionId.toLowerCase().contains('wallet')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (actionId.toLowerCase().contains('order')) {
    return Icons.receipt_long_rounded;
  }
  if (actionId.toLowerCase().contains('resolution') ||
      actionId.toLowerCase().contains('dispute')) {
    return Icons.support_agent_rounded;
  }
  if (actionId.toLowerCase().contains('payout')) {
    return Icons.outbound_rounded;
  }
  if (actionId.toLowerCase().contains('support')) {
    return Icons.help_center_rounded;
  }
  if (actionId.toLowerCase().contains('law')) {
    return Icons.gavel_rounded;
  }
  return Icons.auto_awesome_rounded;
}
