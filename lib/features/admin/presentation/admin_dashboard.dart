import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/platform_stats.dart';
import '../../../models/user_role.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/theme/role_theme.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);
    final logsAsync = ref.watch(auditLogsProvider);
    final user = ref.watch(currentUserProvider).value;
    final roleTheme = getRoleTheme(UserRole.admin);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return AdminControlScaffold(
      title: 'Command Center',
      subtitle: 'Live platform telemetry and moderation activity.',
      currentPath: RoutePaths.adminDashboard,
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
          tooltip: 'Refresh Telemetry',
          onPressed: () {
            ref.invalidate(platformStatsProvider);
            ref.invalidate(auditLogsProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformStatsProvider);
          ref.invalidate(auditLogsProvider);
          ref.invalidate(currentUserProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            _WelcomeCard(
              name: user?.fullName ?? 'Administrator',
              roleTheme: roleTheme,
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                const Icon(Icons.analytics_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SYSTEM TELEMETRY',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) => _MetricsGrid(stats: stats),
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorCard(
                message: 'Telemetry Offline: $error',
                onRetry: () => ref.invalidate(platformStatsProvider),
              ),
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'CONTROL TERMINALS',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _WorkspaceGrid(
              isSuperAdmin: _isSuperAdminRole(user?.primaryRole),
              onUsers: () => context.go(RoutePaths.adminUserManagement),
              onAdmins: () => context.go(RoutePaths.adminManagement),
              onVerification: () => context.go(RoutePaths.adminVerification),
              onSettings: () => context.go(RoutePaths.adminSettings),
              onLogs: () => context.go(RoutePaths.adminAuditLogs),
              onTheme: () => context.go(RoutePaths.adminThemeSettings),
              onMotion: () => context.go(RoutePaths.adminMotionSettings),
              onLanguage: () => context.go(RoutePaths.adminLanguageSettings),
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                const Icon(Icons.security_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SECURITY LEDGER PREVIEW',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go(RoutePaths.adminAuditLogs),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Access Ledger',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const AdminPanelCard(
                    child: _EmptyMessage(
                      icon: Icons.shield_outlined,
                      title: 'Ledger Empty',
                      message:
                          'No security events recorded in the current timeframe.',
                    ),
                  );
                }
                return Container(
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
                    children: logs.take(5).map((log) {
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.data_object_rounded,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              log.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${log.action.replaceAll('_', ' ').toUpperCase()}   //   ${DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt)}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (log != logs.take(5).last)
                            Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.2),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const AdminPanelCard(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorCard(
                message: 'Ledger Offline: $error',
                onRetry: () => ref.invalidate(auditLogsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSuperAdminRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '') ==
      'superadmin';
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name, required this.roleTheme});

  final String name;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    //     final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    'SYSTEM SECURE',
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
                  'Operator: $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor platform growth, review critical verification queues, and audit system events.',
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
                Icons.admin_panel_settings_rounded,
                size: 48,
                color: roleTheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.stats});

  final PlatformStats stats;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Total Users',
        stats.totalUsers,
        Icons.groups_rounded,
        AppColors.primary,
      ),
      ('Students', stats.students, Icons.school_rounded, AppColors.info),
      (
        'Teachers',
        stats.teachers,
        Icons.cast_for_education_rounded,
        AppColors.secondary,
      ),
      ('Freelancers', stats.freelancers, Icons.work_rounded, AppColors.accent),
      ('Companies', stats.companies, Icons.business_rounded, AppColors.success),
      (
        'Jobs Active',
        stats.jobs,
        Icons.business_center_rounded,
        AppColors.warning,
      ),
      (
        'Applications',
        stats.applications,
        Icons.description_rounded,
        Colors.pinkAccent,
      ),
      (
        'Verifications',
        stats.pendingVerifications,
        Icons.pending_actions_rounded,
        Colors.orange,
      ),
      (
        'Banned Users',
        stats.bannedUsers,
        Icons.person_off_rounded,
        Colors.redAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 650
            ? 3
            : constraints.maxWidth >= 390
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 3.0 : 1.4,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            final isCritical =
                metric.$1 == 'Verifications' || metric.$1 == 'Banned Users';

            return _DataPanel(
              label: metric.$1,
              value: metric.$2,
              icon: metric.$3,
              color: metric.$4,
              isCritical: isCritical,
            );
          },
        );
      },
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isCritical,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical && value > 0
              ? color.withValues(alpha: 0.5)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          if (isCritical && value > 0)
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: -5,
            ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (isCritical && value > 0)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NumberFormat.compact().format(value),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 28,
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

class _WorkspaceGrid extends StatelessWidget {
  const _WorkspaceGrid({
    required this.isSuperAdmin,
    required this.onUsers,
    required this.onAdmins,
    required this.onVerification,
    required this.onSettings,
    required this.onLogs,
    required this.onTheme,
    required this.onMotion,
    required this.onLanguage,
  });

  final bool isSuperAdmin;
  final VoidCallback onUsers;
  final VoidCallback onAdmins;
  final VoidCallback onVerification;
  final VoidCallback onSettings;
  final VoidCallback onLogs;
  final VoidCallback onTheme;
  final VoidCallback onMotion;
  final VoidCallback onLanguage;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'User Database',
        'Search, ban, restore accounts.',
        Icons.people_alt_rounded,
        onUsers,
        false,
      ),
      (
        'Verification Queue',
        'Review teacher/company identities.',
        Icons.verified_user_rounded,
        onVerification,
        false,
      ),
      (
        'Audit Ledger',
        'Trace security actions.',
        Icons.receipt_long_rounded,
        onLogs,
        false,
      ),
      (
        'Admin Registry',
        'Manage administrator access.',
        Icons.admin_panel_settings_rounded,
        onAdmins,
        true,
      ),
      (
        'Platform Config',
        'Control global policies.',
        Icons.tune_rounded,
        onSettings,
        true,
      ),
      (
        'Theme Engine',
        'Global visual appearance.',
        Icons.color_lens_rounded,
        onTheme,
        true,
      ),
      (
        'Motion Engine',
        'Global animations.',
        Icons.animation_rounded,
        onMotion,
        true,
      ),
      (
        'Language Data',
        'Default locale system.',
        Icons.language_rounded,
        onLanguage,
        true,
      ),
    ];

    final visibleItems = items
        .where((item) => isSuperAdmin || item.$5 == false)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800
            ? 3
            : (constraints.maxWidth >= 500 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 3.5 : 2.5,
          ),
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            final slug = item.$1
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                .replaceAll(RegExp(r'^_|_$'), '');
            return SieInteractive(
              targetId: 'admin.dashboard.action.$slug',
              button: true,
              child: _ActionPanel(
                title: item.$1,
                subtitle: item.$2,
                icon: item.$3,
                onTap: item.$4,
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 40,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
