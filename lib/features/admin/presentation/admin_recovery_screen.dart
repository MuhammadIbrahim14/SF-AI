import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/user_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminRecoveryScreen extends ConsumerWidget {
  const AdminRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    final actionState = ref.watch(adminActionProvider);
    final user = ref.watch(currentUserProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'System Recovery Center',
      subtitle: 'Emergency maintenance access and platform health monitor.',
      currentPath: RoutePaths.adminRecovery,
      actions: [
        IconButton(
          tooltip: 'Refresh Status',
          onPressed: () => ref.invalidate(platformSettingsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load platform status',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
        data: (settings) {
          final isMaintenance = settings.maintenanceMode;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              // Massive Status Panel
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isMaintenance
                      ? Colors.redAccent.withValues(alpha: isDark ? 0.15 : 0.05)
                      : Colors.green.withValues(alpha: isDark ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isMaintenance
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.green.withValues(alpha: 0.5),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMaintenance
                          ? Colors.redAccent.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isMaintenance
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : Colors.green.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isMaintenance
                            ? Icons.lock_clock_rounded
                            : Icons.check_circle_rounded,
                        size: 64,
                        color: isMaintenance ? Colors.redAccent : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isMaintenance
                          ? 'CRITICAL MAINTENANCE ACTIVE'
                          : 'SYSTEM FULLY OPERATIONAL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: isMaintenance ? Colors.redAccent : Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isMaintenance
                          ? 'Standard user traffic is currently blocked. Only administrators with recovery access can view this screen.'
                          : 'Platform is open and accepting traffic normally. No emergency blocks are active.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Emergency Control Zone
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'EMERGENCY CONTROLS',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Use this action to instantly override the global maintenance lock and reopen the platform. This should only be done once system stability is verified.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: !isMaintenance || actionState.isLoading
                            ? null
                            : () => _disableMaintenance(context, ref),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          disabledForegroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: actionState.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_open_rounded),
                        label: const Text(
                          'OVERRIDE MAINTENANCE MODE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Telemetry Data Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final principal = _TelemetryCard(
                    title: 'Recovery Principal',
                    icon: Icons.admin_panel_settings_rounded,
                    color: Colors.purpleAccent,
                    children: [
                      _StatusRow(
                        label: 'Signed in as',
                        value: user?.email ?? 'Unknown administrator',
                      ),
                      _StatusRow(
                        label: 'Assigned Role',
                        value: (user?.primaryRole ?? 'SYSTEM_OWNER')
                            .toUpperCase(),
                      ),
                      _StatusRow(
                        label: 'System Owner Flag',
                        value: user?.isSystemOwner == true
                            ? 'VERIFIED'
                            : 'FALSE',
                        valueColor: user?.isSystemOwner == true
                            ? Colors.green
                            : null,
                      ),
                    ],
                  );

                  final telemetry = _TelemetryCard(
                    title: 'Platform Telemetry',
                    icon: Icons.memory_rounded,
                    color: Colors.blueAccent,
                    children: [
                      _StatusRow(
                        label: 'Maintenance Lock',
                        value: settings.maintenanceMode
                            ? 'ENGAGED'
                            : 'DISABLED',
                        valueColor: settings.maintenanceMode
                            ? Colors.redAccent
                            : Colors.green,
                      ),
                      _StatusRow(
                        label: 'Global Registration',
                        value: settings.registrationEnabled
                            ? 'ACTIVE'
                            : 'BLOCKED',
                      ),
                      _StatusRow(
                        label: 'Version Target',
                        value: settings.latestVersion,
                      ),
                      _StatusRow(
                        label: 'Min Supported',
                        value: settings.minimumSupportedVersion,
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 640) {
                    return Column(
                      children: [
                        principal,
                        const SizedBox(height: 16),
                        telemetry,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: principal),
                      const SizedBox(width: 16),
                      Expanded(child: telemetry),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _disableMaintenance(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(adminActionProvider.notifier)
        .setMaintenanceMode(false);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Maintenance mode disabled. Platform is live.'
              : ref.read(adminActionProvider.notifier).errorMessage ??
                    'Unable to disable maintenance mode.',
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
