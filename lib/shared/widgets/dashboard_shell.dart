import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../navigation/role_navigation_config.dart';
import 'avatar_widget.dart';
import 'github_style_navigation.dart';
import 'responsive_layout.dart';

/// SkillForge AI — Base Dashboard Shell
/// Reusable dashboard layout shared by all role dashboards.
class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.role, this.stats});

  final UserRole role;

  /// Optional list of stat cards to display in the grid.
  /// Each entry is a map with keys: 'label', 'value', 'icon', 'color'.
  final List<Map<String, dynamic>>? stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final roleTheme = getRoleTheme(role);

    Future<void> signOut() async {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!context.mounted) return;

      final result = ref.read(authNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
        return;
      }

      context.go(RoutePaths.home);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dashboardBody = CustomScrollView(
          slivers: [
            // ─── Header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    // Profile avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: roleTheme.gradient,
                        boxShadow: [
                          BoxShadow(
                            color: roleTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child:
                            userAsync.whenOrNull(
                              data: (user) => Text(
                                user?.fullName.isNotEmpty == true
                                    ? user!.fullName[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ) ??
                            const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          userAsync.when(
                            data: (user) => Text(
                              (user?.fullName ?? '').isNotEmpty
                                  ? user!.fullName
                                  : 'User',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            loading: () => Container(
                              width: 120,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.shimmerBase,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            error: (e, st) => Text(
                              'User',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Logout button
                    IconButton(
                      onPressed: signOut,
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: 'Sign Out',
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Role Badge ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: roleTheme.gradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: roleTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(role.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${role.label} Dashboard',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Stats Grid ─────────────────────────────────────────
            if (stats != null && stats!.isNotEmpty)
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final crossAxisCount = width >= 900
                      ? 4
                      : width >= 640
                      ? 3
                      : 2;

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: width >= 900 ? 1.65 : 1.45,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final stat = stats![index];
                        return _StatCard(
                          label: stat['label'] as String,
                          value: stat['value'] as String,
                          icon: stat['icon'] as IconData,
                          color: stat['color'] as Color,
                        );
                      }, childCount: stats!.length),
                    ),
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Coming Soon ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.construction_rounded,
                        size: 48,
                        color: AppColors.accent.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'More Features Coming Soon',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We're building amazing tools for your ${role.label.toLowerCase()} journey.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );

        if (width > 1100) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _DesktopDashboardSidebar(role: role),
                  Expanded(child: dashboardBody),
                ],
              ),
            ),
          );
        }

        if (width >= 700) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _TabletDashboardRail(role: role),
                  Expanded(child: dashboardBody),
                ],
              ),
            ),
          );
        }

        return Scaffold(body: SafeArea(child: dashboardBody));
      },
    );
  }
}

/// Responsive frame for the production role dashboards.
///
/// Keeps each dashboard's existing body/data logic intact while giving desktop
/// and tablet layouts a proper navigation surface instead of leaving the page
/// visually anchored to the left side.
class RoleDashboardFrame extends ConsumerWidget {
  const RoleDashboardFrame({
    super.key,
    required this.role,
    required this.child,
    this.header,
  });

  final UserRole role;
  final Widget child;

  /// Optional sticky header shown above the scrollable [child] on all breakpoints.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final content = header != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header!,
                  Expanded(child: child),
                ],
              )
            : child;

        if (UserRole.selectableRoles.contains(role)) {
          // Shell roles already have _RoleTopNavigationBar (bell lives there).
          // Pass [child] only — do not mount DashboardHeader as a second bar.
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: GitHubStyleNavigationFrame(role: role, child: child),
            ),
          );
        }

        if (AppBreakpoints.isDesktop(width)) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RoleDashboardSidebar(role: role),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        if (AppBreakpoints.isTablet(width)) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RoleDashboardRail(role: role),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(child: content),
          bottomNavigationBar: RoleDashboardBottomNav(role: role),
        );
      },
    );
  }
}

class _RoleDashboardSidebar extends ConsumerStatefulWidget {
  const _RoleDashboardSidebar({required this.role});

  final UserRole role;

  @override
  ConsumerState<_RoleDashboardSidebar> createState() =>
      _RoleDashboardSidebarState();
}

class _RoleDashboardSidebarState extends ConsumerState<_RoleDashboardSidebar> {
  bool _isCollapsed = false;

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (!mounted) return;

    final result = ref.read(authNotifierProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
      return;
    }

    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).value;
    final destinations = RoleNavigationConfig.destinationsFor(widget.role);
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    final activePath = RoleNavigationConfig.activePathFor(
      currentPath,
      destinations,
    );
    final roleTheme = getRoleTheme(widget.role);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 88 : 272,
      padding: EdgeInsets.fromLTRB(
        _isCollapsed ? 12 : 18,
        22,
        _isCollapsed ? 12 : 18,
        18,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: _isCollapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: [
          _DashboardBrand(role: widget.role, isCollapsed: _isCollapsed),
          const SizedBox(height: 20),
          if (_isCollapsed)
            AvatarWidget(
              imageUrl: user?.photoUrl,
              radius: 20,
              fallbackText: (user?.fullName ?? 'U').isNotEmpty
                  ? (user?.fullName ?? 'U')[0].toUpperCase()
                  : 'U',
            )
          else
            _SidebarIdentity(role: widget.role, name: user?.fullName ?? 'User'),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final item = destinations[index];
                return Tooltip(
                  message: _isCollapsed ? item.label : '',
                  child: _RoleSidebarItem(
                    destination: item,
                    selected: item.path == activePath,
                    onTap: () => context.go(item.path),
                    roleTheme: roleTheme,
                    isCollapsed: _isCollapsed,
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemCount: destinations.length,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isCollapsed)
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            )
          else
            IconButton(
              tooltip: 'Sign Out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          const SizedBox(height: 12),
          IconButton(
            tooltip: _isCollapsed ? 'Expand' : 'Collapse',
            onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
            icon: Icon(
              _isCollapsed
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
            ),
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _RoleDashboardRail extends ConsumerWidget {
  const _RoleDashboardRail({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleTheme = getRoleTheme(role);
    final destinations = RoleNavigationConfig.destinationsFor(
      role,
    ).take(6).toList();
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    final activePath = RoleNavigationConfig.activePathFor(
      currentPath,
      destinations,
    );
    final user = ref.watch(currentUserProvider).value;

    Future<void> signOut() async {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!context.mounted) return;

      final result = ref.read(authNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
        return;
      }

      context.go(RoutePaths.home);
    }

    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          _DashboardBrand(role: role, isCollapsed: true),
          const SizedBox(height: 20),
          AvatarWidget(
            imageUrl: user?.photoUrl,
            radius: 20,
            fallbackText: (user?.fullName ?? 'U').isNotEmpty
                ? (user?.fullName ?? 'U')[0].toUpperCase()
                : 'U',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final item = destinations[index];
                return Tooltip(
                  message: item.label,
                  child: _RoleSidebarItem(
                    destination: item,
                    selected: item.path == activePath,
                    onTap: () => context.go(item.path),
                    roleTheme: roleTheme,
                    isCollapsed: true,
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemCount: destinations.length,
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class RoleDashboardBottomNav extends StatelessWidget {
  const RoleDashboardBottomNav({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    if (!AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)) {
      return const SizedBox.shrink();
    }

    final destinations = RoleNavigationConfig.destinationsFor(
      role,
    ).take(4).toList();
    if (destinations.isEmpty) return const SizedBox.shrink();

    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    final activePath = RoleNavigationConfig.activePathFor(
      currentPath,
      destinations,
    );
    final selectedIndex = destinations.indexWhere(
      (item) => item.path == activePath,
    );

    final roleTheme = getRoleTheme(role);

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => context.go(destinations[index].path),
      indicatorColor: roleTheme.primary.withValues(alpha: 0.15),
      destinations: [
        for (final item in destinations)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
      ],
    );
  }
}

class _DashboardBrand extends StatelessWidget {
  const _DashboardBrand({required this.role, this.isCollapsed = false});

  final UserRole role;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final roleTheme = getRoleTheme(role);
    return Row(
      mainAxisAlignment: isCollapsed
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: roleTheme.gradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: roleTheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(role.icon, color: Colors.white, size: 20),
        ),
        if (!isCollapsed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SkillForge AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  role.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleSidebarItem extends StatelessWidget {
  const _RoleSidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.roleTheme,
    this.isCollapsed = false,
  });

  final RoleNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final RoleThemeColors roleTheme;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected
          ? roleTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: selected
                    ? roleTheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? (isDark ? Colors.white : colorScheme.onSurface)
                          : colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: roleTheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopDashboardSidebar extends ConsumerWidget {
  const _DesktopDashboardSidebar({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final colorScheme = Theme.of(context).colorScheme;
    final roleTheme = getRoleTheme(role);

    Future<void> signOut() async {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!context.mounted) return;

      final result = ref.read(authNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
        return;
      }

      context.go(RoutePaths.home);
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SkillForge AI',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          _SidebarIdentity(role: role, name: user?.fullName ?? 'User'),
          const SizedBox(height: 24),
          _SidebarItem(
            icon: role.icon,
            label: '${role.label} Dashboard',
            selected: true,
            roleTheme: roleTheme,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _TabletDashboardRail extends ConsumerWidget {
  const _TabletDashboardRail({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleTheme = getRoleTheme(role);

    Future<void> signOut() async {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!context.mounted) return;

      final result = ref.read(authNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
        return;
      }

      context.go(RoutePaths.home);
    }

    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: roleTheme.primary.withValues(alpha: 0.15),
            child: Icon(role.icon, color: roleTheme.primary),
          ),
          const SizedBox(height: 24),
          _RailIcon(
            icon: Icons.dashboard_rounded,
            selected: true,
            roleTheme: roleTheme,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _SidebarIdentity extends StatelessWidget {
  const _SidebarIdentity({required this.role, required this.name});

  final UserRole role;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Text(name.isEmpty ? '?' : name[0].toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'User' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.roleTheme,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? roleTheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? roleTheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? roleTheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.selected,
    required this.roleTheme,
  });

  final IconData icon;
  final bool selected;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? roleTheme.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: selected ? roleTheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Individual stat card widget used in the dashboard grid.
class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
