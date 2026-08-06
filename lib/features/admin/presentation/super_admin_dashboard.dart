import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/theme/role_theme.dart';
import '../../../models/user_role.dart';
import 'widgets/admin_control_scaffold.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operator = ref.watch(currentUserProvider).value;
    final statsAsync = ref.watch(platformStatsProvider);
    final roleTheme = getRoleTheme(UserRole.superAdmin);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return AdminControlScaffold(
      title: 'Global Control Center',
      subtitle:
          'Critical system actions, global platform settings, and security controls.',
      currentPath: RoutePaths.superAdminDashboard,
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () =>
              context.pushNamed(RouteNames.notificationsInbox),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        IconButton(
          tooltip: 'Refresh Status',
          onPressed: () {
            ref.invalidate(platformStatsProvider);
            ref.invalidate(currentUserProvider);
            ref.invalidate(adminUsersProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformStatsProvider);
          ref.invalidate(currentUserProvider);
          ref.invalidate(adminUsersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            _Hero(
              operatorName: operator?.fullName ?? 'Super Administrator',
              roleTheme: roleTheme,
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'GLOBAL PLATFORM CONTROLS',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ActionGrid(
              onMaintenanceToggle: () => _toggleMaintenance(context, ref),
              onClearCache: () => _clearCache(context, ref),
              onAdmins: () => context.go(RoutePaths.adminManagement),
              onSettings: () => context.go(RoutePaths.adminSettings),
              onRecovery: () => context.go(RoutePaths.adminRecovery),
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                const Icon(Icons.monitor_heart_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PLATFORM SNAPSHOT',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) => LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 800
                      ? 4
                      : (constraints.maxWidth > 500 ? 2 : 1);
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: columns == 1 ? 3.0 : 1.6,
                    ),
                    children: [
                      _Metric(
                        label: 'Total Platform Users',
                        value: stats.totalUsers.toString(),
                        icon: Icons.people_alt_rounded,
                        color: AppColors.primary,
                      ),
                      _Metric(
                        label: 'Administrators',
                        value:
                            'Secured', // Stats object doesn't have total admins natively.
                        icon: Icons.admin_panel_settings_rounded,
                        color: AppColors.secondary,
                      ),
                      _Metric(
                        label: 'Total Platform Jobs',
                        value: stats.jobs.toString(),
                        icon: Icons.work_rounded,
                        color: AppColors.info,
                      ),
                      _Metric(
                        label: 'Pending Reviews',
                        value: stats.pendingVerifications.toString(),
                        icon: Icons.assignment_late_rounded,
                        color: stats.pendingVerifications > 0
                            ? Colors.orange
                            : AppColors.success,
                      ),
                    ],
                  );
                },
              ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorCard(
                message: 'Stats Offline: $error',
                onRetry: () => ref.invalidate(platformStatsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMaintenance(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(platformSettingsProvider).value;
    final currentlyActive = settings?.maintenanceMode ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          currentlyActive
              ? 'Disable Maintenance Mode?'
              : 'Enable Maintenance Mode?',
        ),
        content: Text(
          currentlyActive
              ? 'This will restore full platform access for all standard users, students, and companies.'
              : 'CRITICAL WARNING: This will lock out all non-admin users immediately. Active sessions will be rejected. Use only for severe issues or planned updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: currentlyActive
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(currentlyActive ? 'Restore Platform' : 'LOCK PLATFORM'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(adminActionProvider.notifier)
        .setMaintenanceMode(!currentlyActive);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (currentlyActive ? 'Platform restored.' : 'Platform locked.')
              : ref.read(adminActionProvider.notifier).errorMessage ??
                    'Action failed.',
        ),
      ),
    );
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Global System Caches?'),
        content: const Text(
          'This will force a refresh of platform settings, roles, and statistics for all active admin sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear Caches'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ref.invalidate(platformSettingsProvider);
    ref.invalidate(platformStatsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(currentUserProvider);
    ref.invalidate(auditLogsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Global caches cleared successfully.')),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.operatorName, required this.roleTheme});

  final String operatorName;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleTheme.primary, roleTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: roleTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: roleTheme.primary.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: roleTheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'SUPER ADMIN PRIVILEGES',
                    style: TextStyle(
                      color: roleTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Operator: $operatorName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Proceed with caution. You have global write access to maintenance modes, admin promotion, and platform configurations.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width > 600)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roleTheme.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: roleTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.security_rounded,
                size: 48,
                color: roleTheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid({
    required this.onMaintenanceToggle,
    required this.onClearCache,
    required this.onAdmins,
    required this.onSettings,
    required this.onRecovery,
  });

  final VoidCallback onMaintenanceToggle;
  final VoidCallback onClearCache;
  final VoidCallback onAdmins;
  final VoidCallback onSettings;
  final VoidCallback onRecovery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenanceActive =
        ref.watch(platformSettingsProvider).value?.maintenanceMode == true;

    final items = [
      (
        'Maintenance Mode',
        maintenanceActive
            ? 'Currently active. Platform is locked.'
            : 'Lock platform for standard users.',
        maintenanceActive ? Icons.lock_rounded : Icons.lock_open_rounded,
        maintenanceActive ? Colors.redAccent : Colors.orange,
        onMaintenanceToggle,
      ),
      (
        'Admin Registry',
        'Promote/demote super admins.',
        Icons.admin_panel_settings_rounded,
        AppColors.primary,
        onAdmins,
      ),
      (
        'Platform Config',
        'Global app variables and rules.',
        Icons.tune_rounded,
        AppColors.secondary,
        onSettings,
      ),
      (
        'Recovery Control',
        'Direct firestore mutations.',
        Icons.health_and_safety_rounded,
        Colors.pinkAccent,
        onRecovery,
      ),
      (
        'Clear Global Cache',
        'Force sync all admin clients.',
        Icons.cleaning_services_rounded,
        Colors.teal,
        onClearCache,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 3.5 : 2.2,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final isCritical = item.$1 == 'Maintenance Mode';

            return InkWell(
              onTap: item.$5,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCritical && maintenanceActive
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    if (isCritical && maintenanceActive)
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: -5,
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.$4.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.$4.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(item.$3, color: item.$4, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isCritical && maintenanceActive
                                  ? Colors.redAccent
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}
