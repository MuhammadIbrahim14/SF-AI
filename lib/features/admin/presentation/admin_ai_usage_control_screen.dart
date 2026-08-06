import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../features/ai_usage/models/ai_usage_models.dart';
import '../../../features/ai_usage/providers/ai_usage_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminAiUsageControlScreen extends ConsumerWidget {
  const AdminAiUsageControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider);
    final quotas = ref.watch(aiRoleQuotasProvider);
    final costs = ref.watch(aiFeatureCostsProvider);
    final users = ref.watch(aiAllUserCreditsProvider);
    final requests = ref.watch(aiCreditRequestsProvider);
    final logs = ref.watch(aiUsageLogsProvider);

    final quotaCount = quotas.value?.length ?? 0;
    final costCount = costs.value?.length ?? 0;
    final userCount = users.value?.length ?? 0;
    final pendingRequests = requests.value
            ?.where((item) => item.status.toLowerCase() == 'pending')
            .length ??
        0;
    final logCount = logs.value?.length ?? 0;

    return AdminControlScaffold(
      title: 'AI Usage Control',
      subtitle: 'Govern AI Credits, quotas, costs, requests, and usage logs.',
      currentPath: RoutePaths.adminAiUsageControl,
      actions: [
        FilledButton.icon(
          onPressed: () => _seedDefaults(context, ref),
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: const Text('Seed Defaults'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AiUsageOverview(
            quotaCount: quotaCount,
            costCount: costCount,
            userCount: userCount,
            pendingRequests: pendingRequests,
            logCount: logCount,
            quotasLoading: quotas.isLoading,
            costsLoading: costs.isLoading,
            usersLoading: users.isLoading,
            requestsLoading: requests.isLoading,
            logsLoading: logs.isLoading,
          ),
          const SizedBox(height: 16),
          settings.when(
            loading: _loading,
            error: _error,
            data: (data) => _GlobalSettingsCard(settings: data),
          ),
          const SizedBox(height: 16),
          _SectionShell(
            title: 'Role Quotas',
            child: quotas.when(
              loading: _loading,
              error: _error,
              data: (items) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map((item) => _RoleQuotaCard(quota: item))
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionShell(
            title: 'Feature Credit Costs',
            child: costs.when(
              loading: _loading,
              error: _error,
              data: (items) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map((item) => _FeatureCostCard(feature: item))
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionShell(
            title: 'User Credits',
            child: users.when(
              loading: _loading,
              error: _error,
              data: (items) => _SimpleTable(
                headers: const ['User', 'Role', 'Remaining', 'Used', 'Bonus'],
                rows: items
                    .map(
                      (item) => [
                        _short(item.userId),
                        item.role,
                        item.remainingCredits.toString(),
                        item.usedCreditsThisMonth.toString(),
                        item.bonusCredits.toString(),
                      ],
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionShell(
            title: 'Credit Requests',
            child: requests.when(
              loading: _loading,
              error: _error,
              data: (items) => Column(
                children: items
                    .map((item) => _CreditRequestTile(request: item))
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionShell(
            title: 'Usage Logs',
            child: logs.when(
              loading: _loading,
              error: _error,
              data: (items) => _SimpleTable(
                headers: const [
                  'User',
                  'Task',
                  'Provider',
                  'Credits',
                  'Tokens',
                  'Status',
                ],
                rows: items
                    .map(
                      (item) => [
                        _short(item.userId),
                        item.taskType,
                        item.provider,
                        item.creditsCharged.toString(),
                        item.totalTokens.toString(),
                        item.status,
                      ],
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionShell(
            title: 'Future Paid Packs',
            child: ListTile(
              leading: Icon(Icons.lock_clock_rounded),
              title: Text('Paid AI Credit Packs'),
              subtitle: Text(
                'Disabled foundation only. No real payment integration is active.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDefaults(BuildContext context, WidgetRef ref) async {
    await ref
        .read(aiUsageAdminActionProvider.notifier)
        .seedDefaultConfiguration();
    if (!context.mounted) return;
    final result = ref.read(aiUsageAdminActionProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.hasError
              ? 'Unable to seed AI defaults. Check admin permissions.'
              : 'AI defaults are ready. Existing settings were preserved.',
        ),
      ),
    );
  }

  static Widget _loading() => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );

  static Widget _error(Object error, StackTrace stack) =>
      Padding(padding: const EdgeInsets.all(16), child: Text(error.toString()));
}

class _GlobalSettingsCard extends ConsumerWidget {
  const _GlobalSettingsCard({required this.settings});

  final AiSettingsModel settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionShell(
      title: 'Global AI Settings',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilterChip(
            label: const Text('AI Enabled'),
            selected: settings.enabled,
            onSelected: (value) => ref
                .read(aiUsageAdminActionProvider.notifier)
                .updateSettings(settings.copyWith(enabled: value)),
          ),
          FilterChip(
            label: const Text('Monthly Reset'),
            selected: settings.monthlyResetEnabled,
            onSelected: (value) => ref
                .read(aiUsageAdminActionProvider.notifier)
                .updateSettings(settings.copyWith(monthlyResetEnabled: value)),
          ),
          Chip(label: Text('Provider: ${settings.defaultProvider}')),
          const Chip(label: Text('Fallback: Disabled')),
        ],
      ),
    );
  }
}

class _AiUsageOverview extends StatelessWidget {
  const _AiUsageOverview({
    required this.quotaCount,
    required this.costCount,
    required this.userCount,
    required this.pendingRequests,
    required this.logCount,
    required this.quotasLoading,
    required this.costsLoading,
    required this.usersLoading,
    required this.requestsLoading,
    required this.logsLoading,
  });

  final int quotaCount;
  final int costCount;
  final int userCount;
  final int pendingRequests;
  final int logCount;
  final bool quotasLoading;
  final bool costsLoading;
  final bool usersLoading;
  final bool requestsLoading;
  final bool logsLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminPanelCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Usage Overview',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'All AI usage data is live. This summary shows quotas, costs, users, requests, and recent activity without changing any controls.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _OverviewStatCard(
                icon: Icons.shield_rounded,
                title: 'Role Quotas',
                value: quotasLoading ? '…' : '$quotaCount',
                color: theme.colorScheme.primary,
              ),
              _OverviewStatCard(
                icon: Icons.bolt_rounded,
                title: 'Feature Costs',
                value: costsLoading ? '…' : '$costCount',
                color: theme.colorScheme.secondary,
              ),
              _OverviewStatCard(
                icon: Icons.person_rounded,
                title: 'Users',
                value: usersLoading ? '…' : '$userCount',
                color: theme.colorScheme.tertiary ?? theme.colorScheme.primary,
              ),
              _OverviewStatCard(
                icon: Icons.pending_actions_rounded,
                title: 'Pending Requests',
                value: requestsLoading ? '…' : '$pendingRequests',
                color: theme.colorScheme.error,
              ),
              _OverviewStatCard(
                icon: Icons.timeline_rounded,
                title: 'Logs',
                value: logsLoading ? '…' : '$logCount',
                color: theme.colorScheme.inversePrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 164,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleQuotaCard extends ConsumerWidget {
  const _RoleQuotaCard({required this.quota});

  final AiRoleQuotaModel quota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        return SizedBox(
          width: mobile ? double.infinity : 280,
          child: AdminPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        quota.role.toUpperCase(),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusBadge(
                      enabled: quota.aiEnabled,
                      activeLabel: 'AI Active',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Monthly: ${quota.monthlyFreeCredits} credits'),
                Text('Daily requests: ${quota.maxDailyRequests}'),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: quota.aiEnabled,
                  title: const Text('AI enabled'),
                  onChanged: (value) {
                    ref
                        .read(aiUsageAdminActionProvider.notifier)
                        .updateRoleQuota(
                          AiRoleQuotaModel(
                            role: quota.role,
                            monthlyFreeCredits: quota.monthlyFreeCredits,
                            maxDailyRequests: quota.maxDailyRequests,
                            aiEnabled: value,
                            allowedFeatures: quota.allowedFeatures,
                          ),
                        );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => _editQuota(context, ref),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit quota'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editQuota(BuildContext context, WidgetRef ref) async {
    final monthly = TextEditingController(
      text: quota.monthlyFreeCredits.toString(),
    );
    final daily = TextEditingController(
      text: quota.maxDailyRequests.toString(),
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${quota.role} quota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: monthly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly credits'),
            ),
            TextField(
              controller: daily,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily requests'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true) return;
    await ref
        .read(aiUsageAdminActionProvider.notifier)
        .updateRoleQuota(
          AiRoleQuotaModel(
            role: quota.role,
            monthlyFreeCredits:
                int.tryParse(monthly.text.trim()) ?? quota.monthlyFreeCredits,
            maxDailyRequests:
                int.tryParse(daily.text.trim()) ?? quota.maxDailyRequests,
            aiEnabled: quota.aiEnabled,
            allowedFeatures: quota.allowedFeatures,
          ),
        );
  }
}

class _FeatureCostCard extends ConsumerWidget {
  const _FeatureCostCard({required this.feature});

  final AiFeatureCostModel feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        return SizedBox(
          width: mobile ? double.infinity : 300,
          child: AdminPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature.label,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusBadge(
                      enabled: feature.enabled,
                      activeLabel: 'Enabled',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(feature.taskType),
                Text('${feature.creditCost} credits'),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: feature.enabled,
                  title: const Text('Enabled'),
                  onChanged: (value) => ref
                      .read(aiUsageAdminActionProvider.notifier)
                      .updateFeatureCost(
                        AiFeatureCostModel(
                          taskType: feature.taskType,
                          label: feature.label,
                          creditCost: feature.creditCost,
                          isHeavy: feature.isHeavy,
                          enabled: value,
                        ),
                      ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editCost(context, ref),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit cost'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editCost(BuildContext context, WidgetRef ref) async {
    final cost = TextEditingController(text: feature.creditCost.toString());
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${feature.label}'),
        content: TextField(
          controller: cost,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Credit cost'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true) return;
    await ref
        .read(aiUsageAdminActionProvider.notifier)
        .updateFeatureCost(
          AiFeatureCostModel(
            taskType: feature.taskType,
            label: feature.label,
            creditCost: int.tryParse(cost.text.trim()) ?? feature.creditCost,
            isHeavy: feature.isHeavy,
            enabled: feature.enabled,
          ),
        );
  }
}

class _CreditRequestTile extends ConsumerWidget {
  const _CreditRequestTile({required this.request});

  final AiCreditRequestModel request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(
          '${_short(request.userId)} requested ${request.requestedCredits} credits',
        ),
        subtitle: Text(
          '${request.role} - ${request.reason} - ${request.status}',
        ),
        trailing: request.status == 'pending'
            ? Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => ref
                        .read(aiUsageAdminActionProvider.notifier)
                        .reviewRequest(request: request, status: 'approved'),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(aiUsageAdminActionProvider.notifier)
                        .reviewRequest(request: request, status: 'rejected'),
                    child: const Text('Reject'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SimpleTable extends StatelessWidget {
  const _SimpleTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No records yet.');
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateColor.resolveWith(
          (_) => theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        ),
        dataRowColor: WidgetStateColor.resolveWith(
          (_) => theme.colorScheme.surface.withValues(alpha: 0.95),
        ),
        columns: headers.map((item) => DataColumn(label: Text(item))).toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: row.map((item) => DataCell(Text(item))).toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.enabled,
    required this.activeLabel,
  });

  final bool enabled;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.withValues(alpha: 0.14) : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        enabled ? activeLabel : 'Disabled',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: enabled ? Colors.green.shade700 : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _short(String value) {
  if (value.length <= 10) return value;
  return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
}
