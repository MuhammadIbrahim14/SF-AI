import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../features/copilot/presentation/copilot_floating_button.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/user_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class AdminControlScaffold extends ConsumerWidget {
  const AdminControlScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentPath,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final String currentPath;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDashboard =
        currentPath == RoutePaths.adminDashboard ||
        currentPath == RoutePaths.superAdminDashboard;
    final isSigningOut = ref.watch(authNotifierProvider).isLoading;
    final user = ref.watch(currentUserProvider).value;
    final hasRecoveryAccess =
        _isSuperAdminRole(user?.primaryRole) || (user?.isSystemOwner ?? false);
    final maintenanceActive =
        ref.watch(platformSettingsProvider).value?.maintenanceMode == true;
    final logoutDisabled =
        maintenanceActive &&
        ((user?.isSystemOwner ?? false) || hasRecoveryAccess);
    const logoutDisabledMessage =
        'Logout is disabled during maintenance to prevent platform lockout.';

    Future<void> logout() async {
      if (logoutDisabled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(logoutDisabledMessage)));
        return;
      }
      if (!context.mounted) return;

      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'You will need to sign in again to access the Admin Center.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log out'),
            ),
          ],
        ),
      );
      if (shouldLogout != true || !context.mounted) return;

      await ref.read(authNotifierProvider.notifier).signOut();
      if (!context.mounted) return;

      final result = ref.read(authNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
      }
    }

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          hasRecoveryAccess
              ? RoutePaths.superAdminDashboard
              : RoutePaths.adminDashboard,
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: _AdminGitHubNavigationFrame(
          title: title,
          subtitle: subtitle,
          currentPath: currentPath,
          body: body,
          actions: actions,
          isDashboard: isDashboard,
          isSigningOut: isSigningOut,
          hasRecoveryAccess: hasRecoveryAccess,
          maintenanceActive: maintenanceActive,
          logoutDisabled: logoutDisabled,
          logoutDisabledMessage: logoutDisabledMessage,
          userName: user?.fullName ?? 'Admin',
          userEmail: user?.email,
          onBack: goBack,
          onLogout: logout,
        ),
      ),
    );
  }
}

enum _AdminMenuPanel { appMenu, accountMenu }

class _AdminNavigationVisual {
  const _AdminNavigationVisual({
    required this.primary,
    required this.secondary,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final Color primary;
  final Color secondary;
  final String title;
  final String subtitle;
  final IconData icon;
}

_AdminNavigationVisual _adminVisualFor(bool hasRecoveryAccess) {
  return hasRecoveryAccess
      ? const _AdminNavigationVisual(
          primary: AppColors.superAdminPrimary,
          secondary: AppColors.superAdminSecondary,
          title: 'Super Admin',
          subtitle: 'Recovery, maintenance and platform control',
          icon: Icons.security_rounded,
        )
      : const _AdminNavigationVisual(
          primary: AppColors.adminPrimary,
          secondary: AppColors.adminSecondary,
          title: 'Admin Center',
          subtitle: 'Platform operations and moderation',
          icon: Icons.admin_panel_settings_rounded,
        );
}

class _AdminGitHubNavigationFrame extends StatefulWidget {
  const _AdminGitHubNavigationFrame({
    required this.title,
    required this.subtitle,
    required this.currentPath,
    required this.body,
    required this.actions,
    required this.isDashboard,
    required this.isSigningOut,
    required this.hasRecoveryAccess,
    required this.maintenanceActive,
    required this.logoutDisabled,
    required this.logoutDisabledMessage,
    required this.userName,
    required this.userEmail,
    required this.onBack,
    required this.onLogout,
  });

  final String title;
  final String subtitle;
  final String currentPath;
  final Widget body;
  final List<Widget> actions;
  final bool isDashboard;
  final bool isSigningOut;
  final bool hasRecoveryAccess;
  final bool maintenanceActive;
  final bool logoutDisabled;
  final String logoutDisabledMessage;
  final String userName;
  final String? userEmail;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<_AdminGitHubNavigationFrame> createState() =>
      _AdminGitHubNavigationFrameState();
}

class _AdminGitHubNavigationFrameState
    extends State<_AdminGitHubNavigationFrame> {
  _AdminMenuPanel? _openPanel;

  void _togglePanel(_AdminMenuPanel panel) {
    setState(() => _openPanel = _openPanel == panel ? null : panel);
  }

  void _closePanel() {
    if (_openPanel == null) return;
    setState(() => _openPanel = null);
  }

  void _navigateTo(String path) {
    _closePanel();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final visual = _adminVisualFor(widget.hasRecoveryAccess);
    final items = _itemsFor(widget.hasRecoveryAccess);
    final activeItem = _activeAdminItem(widget.currentPath, items);
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final mobile = width < 700;
    final tablet = width >= 700 && width < 1100;
    final horizontalInset = mobile
        ? 10.0
        : tablet
        ? 18.0
        : 24.0;
    final menuTop = mobile ? 66.0 : 72.0;
    final maxMenuHeight =
        (media.size.height - menuTop - media.padding.bottom - 14).clamp(
          280.0,
          560.0,
        );
    final appMenuWidth = mobile
        ? null
        : (width - (horizontalInset * 2)).clamp(330.0, tablet ? 430.0 : 440.0);
    final accountMenuWidth = mobile
        ? null
        : (width - (horizontalInset * 2)).clamp(330.0, tablet ? 400.0 : 410.0);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _openPanel != null) {
          _closePanel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdminGitHubTopNav(
                visual: visual,
                activeItem: activeItem,
                userName: widget.userName,
                isAppMenuOpen: _openPanel == _AdminMenuPanel.appMenu,
                isAccountMenuOpen: _openPanel == _AdminMenuPanel.accountMenu,
                onAppMenuTap: () => _togglePanel(_AdminMenuPanel.appMenu),
                onAccountTap: () => _togglePanel(_AdminMenuPanel.accountMenu),
              ),
              _AdminPageHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                actions: widget.actions,
                isDashboard: widget.isDashboard,
                onBack: widget.onBack,
              ),
              if (widget.maintenanceActive) const _MaintenanceWarningBanner(),
              Expanded(child: widget.body),
            ],
          ),
          if (_openPanel != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closePanel,
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            top: menuTop,
            left: horizontalInset,
            right: mobile ? horizontalInset : null,
            child: _AdminFloatingMenuTransition(
              visible: _openPanel == _AdminMenuPanel.appMenu,
              alignment: Alignment.topLeft,
              child: _AdminMenuCard(
                width: appMenuWidth?.toDouble(),
                maxHeight: maxMenuHeight.toDouble(),
                title: 'Admin navigation',
                subtitle: visual.subtitle,
                accentColor: visual.primary,
                children: [
                  for (final section in _adminMenuSections(items))
                    _AdminMenuSection(
                      title: section.title,
                      children: [
                        for (final item in section.items)
                          _AdminMenuTile(
                            item: item,
                            selected: item.path == widget.currentPath,
                            accentColor: visual.primary,
                            onTap: () => _navigateTo(item.path),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: menuTop,
            right: horizontalInset,
            left: mobile ? horizontalInset : null,
            child: _AdminFloatingMenuTransition(
              visible: _openPanel == _AdminMenuPanel.accountMenu,
              alignment: Alignment.topRight,
              child: _AdminMenuCard(
                width: accountMenuWidth?.toDouble(),
                maxHeight: maxMenuHeight.toDouble(),
                title: widget.userName,
                subtitle: widget.userEmail ?? visual.title,
                accentColor: visual.primary,
                children: [
                  _AdminMenuSection(
                    title: 'Shortcuts',
                    children: [
                      if (widget.hasRecoveryAccess)
                        _AdminMenuTile(
                          item: _findAdminItem(RoutePaths.adminRecovery),
                          selected:
                              widget.currentPath == RoutePaths.adminRecovery,
                          accentColor: visual.primary,
                          onTap: () => _navigateTo(RoutePaths.adminRecovery),
                        ),
                      if (widget.hasRecoveryAccess)
                        _AdminMenuTile(
                          item: _findAdminItem(RoutePaths.adminSettings),
                          selected:
                              widget.currentPath == RoutePaths.adminSettings,
                          accentColor: visual.primary,
                          onTap: () => _navigateTo(RoutePaths.adminSettings),
                        ),
                      _AdminMenuTile(
                        item: _findAdminItem(RoutePaths.adminAuditLogs),
                        selected:
                            widget.currentPath == RoutePaths.adminAuditLogs,
                        accentColor: visual.primary,
                        onTap: () => _navigateTo(RoutePaths.adminAuditLogs),
                      ),
                    ],
                  ),
                  Divider(
                    height: 24,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  _AdminLogoutTile(
                    isSigningOut: widget.isSigningOut,
                    logoutDisabled: widget.logoutDisabled,
                    logoutDisabledMessage: widget.logoutDisabledMessage,
                    onTap: () {
                      _closePanel();
                      widget.onLogout();
                    },
                  ),
                ],
              ),
            ),
          ),
          const CopilotFloatingButton(),
        ],
      ),
    );
  }
}

class _AdminGitHubTopNav extends StatelessWidget {
  const _AdminGitHubTopNav({
    required this.visual,
    required this.activeItem,
    required this.userName,
    required this.isAppMenuOpen,
    required this.isAccountMenuOpen,
    required this.onAppMenuTap,
    required this.onAccountTap,
  });

  final _AdminNavigationVisual visual;
  final _AdminDestination? activeItem;
  final String userName;
  final bool isAppMenuOpen;
  final bool isAccountMenuOpen;
  final VoidCallback onAppMenuTap;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 700;
    final desktop = width >= 1100;
    final horizontalPadding = mobile ? 10.0 : 24.0;
    final navHeight = mobile
        ? 52.0
        : desktop
        ? 62.0
        : 56.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        mobile ? 8 : 12,
        horizontalPadding,
        mobile ? 6 : 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: navHeight,
            padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface.withValues(alpha: isDark ? 0.76 : 0.92),
                  colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.46 : 0.64,
                  ),
                  visual.primary.withValues(alpha: isDark ? 0.11 : 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).shadowColor.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _AdminTopIconButton(
                  tooltip: 'Open admin menu',
                  icon: isAppMenuOpen
                      ? Icons.close_rounded
                      : Icons.apps_rounded,
                  selected: isAppMenuOpen,
                  accentColor: visual.primary,
                  onTap: onAppMenuTap,
                ),
                const SizedBox(width: 10),
                if (width >= 390) ...[
                  Container(
                    width: mobile ? 32 : 34,
                    height: mobile ? 32 : 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [visual.primary, visual.secondary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: visual.primary.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(visual.icon, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: mobile
                      ? Text(
                          visual.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visual.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              visual.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                ),
                if (desktop && activeItem != null) ...[
                  _AdminCurrentPagePill(
                    item: activeItem!,
                    accentColor: visual.primary,
                  ),
                  const SizedBox(width: 10),
                ],
                _AdminTopIconButton(
                  tooltip: 'Open admin account actions',
                  icon: isAccountMenuOpen
                      ? Icons.close_rounded
                      : Icons.bolt_rounded,
                  selected: isAccountMenuOpen,
                  accentColor: visual.primary,
                  onTap: onAccountTap,
                ),
                const SizedBox(width: 8),
                _AdminAvatarButton(
                  userName: userName,
                  selected: isAccountMenuOpen,
                  accentColor: visual.primary,
                  onTap: onAccountTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.isDashboard,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final bool isDashboard;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 700 ? 16.0 : 28.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 16),
      child: Row(
        children: [
          if (!isDashboard) ...[
            IconButton(
              tooltip: 'Back to dashboard',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final mobile = MediaQuery.of(context).size.width < 700;
                if (mobile) {
                  return SizedBox(
                    height: 44,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: actions
                            .map((w) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: w,
                                ))
                            .toList(),
                      ),
                    ),
                  );
                }
                return Row(children: actions);
              },
            ),
        ],
      ),
    );
  }
}

class _AdminTopIconButton extends StatefulWidget {
  const _AdminTopIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_AdminTopIconButton> createState() => _AdminTopIconButtonState();
}

class _AdminTopIconButtonState extends State<_AdminTopIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: widget.selected
                ? widget.accentColor.withValues(alpha: 0.14)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.selected
                        ? widget.accentColor.withValues(alpha: 0.38)
                        : colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.icon),
                    color: widget.selected
                        ? widget.accentColor
                        : colorScheme.onSurfaceVariant,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAvatarButton extends StatelessWidget {
  const _AdminAvatarButton({
    required this.userName,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String userName;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';
    return Tooltip(
      message: 'Open admin actions',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: selected
                    ? [accentColor, accentColor.withValues(alpha: 0.45)]
                    : [
                        accentColor.withValues(alpha: 0.48),
                        Colors.white.withValues(alpha: 0.16),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: selected ? 0.32 : 0.18),
                  blurRadius: selected ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminCurrentPagePill extends StatelessWidget {
  const _AdminCurrentPagePill({required this.item, required this.accentColor});

  final _AdminDestination item;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.selectedIcon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminFloatingMenuTransition extends StatelessWidget {
  const _AdminFloatingMenuTransition({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              alignment: alignment,
              child: child,
            ),
          );
        },
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.children,
    this.width,
    this.maxHeight = 560,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget> children;
  final double? width;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            width: width,
            constraints: BoxConstraints(maxHeight: maxHeight),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface.withValues(alpha: isDark ? 0.90 : 0.96),
                  colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.58 : 0.76,
                  ),
                  accentColor.withValues(alpha: isDark ? 0.10 : 0.055),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.82),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
                  blurRadius: 34,
                  spreadRadius: -8,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.14),
                  blurRadius: 28,
                  spreadRadius: -14,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: accentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminMenuSection extends StatelessWidget {
  const _AdminMenuSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile({
    required this.item,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final _AdminDestination item;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? accentColor.withValues(alpha: isDark ? 0.2 : 0.11)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 4 : 0,
                  height: 30,
                  margin: EdgeInsets.only(right: selected ? 10 : 0),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? accentColor.withValues(alpha: 0.16)
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected
                        ? accentColor
                        : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: accentColor, size: 18)
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminLogoutTile extends StatelessWidget {
  const _AdminLogoutTile({
    required this.isSigningOut,
    required this.logoutDisabled,
    required this.logoutDisabledMessage,
    required this.onTap,
  });

  final bool isSigningOut;
  final bool logoutDisabled;
  final String logoutDisabledMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = logoutDisabled ? AppColors.warning : AppColors.error;
    return _AdminAccountActionTile(
      icon: isSigningOut ? null : Icons.logout_rounded,
      progress: isSigningOut,
      label: isSigningOut
          ? 'Logging out...'
          : logoutDisabled
          ? 'Logout disabled'
          : 'Log out',
      subtitle: logoutDisabled ? logoutDisabledMessage : 'End admin session',
      color: color,
      onTap: onTap,
    );
  }
}

class _AdminAccountActionTile extends StatelessWidget {
  const _AdminAccountActionTile({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.icon,
    this.progress = false,
  });

  final IconData? icon;
  final bool progress;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: progress
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      : Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSectionData {
  const _AdminSectionData({required this.title, required this.items});

  final String title;
  final List<_AdminDestination> items;
}

List<_AdminSectionData> _adminMenuSections(List<_AdminDestination> items) {
  List<_AdminDestination> matching(Set<String> paths) {
    return items.where((item) => paths.contains(item.path)).toList();
  }

  final control = matching({
    RoutePaths.adminDashboard,
    RoutePaths.superAdminDashboard,
    RoutePaths.adminCommerceOrders,
    RoutePaths.adminAiUsageControl,
    RoutePaths.adminMonetization,
    RoutePaths.adminFinanceCenter,
    RoutePaths.adminSuperTransactions,
    RoutePaths.adminAuditLogs,
  });
  final users = matching({
    RoutePaths.adminUserManagement,
    RoutePaths.adminVerification,
    RoutePaths.adminInbox,
    RoutePaths.notificationsInbox,
  });
  final settings = matching({
    RoutePaths.adminSettings,
    RoutePaths.adminThemeSettings,
    RoutePaths.adminMotionSettings,
    RoutePaths.adminSieControl,
    RoutePaths.adminLanguageSettings,
    RoutePaths.adminInterviewLab,
    RoutePaths.adminReleaseCenter,
  });
  final system = matching({
    RoutePaths.adminManagement,
    RoutePaths.adminRecovery,
  });

  return [
    if (control.isNotEmpty) _AdminSectionData(title: 'Control', items: control),
    if (users.isNotEmpty) _AdminSectionData(title: 'Users', items: users),
    if (settings.isNotEmpty)
      _AdminSectionData(title: 'Settings', items: settings),
    if (system.isNotEmpty) _AdminSectionData(title: 'System', items: system),
  ];
}

_AdminDestination? _activeAdminItem(
  String currentPath,
  List<_AdminDestination> items,
) {
  for (final item in items) {
    if (item.path == currentPath) return item;
  }
  return null;
}

_AdminDestination _findAdminItem(String path) {
  return _items.firstWhere((item) => item.path == path);
}

class AdminPanelCard extends StatelessWidget {
  const AdminPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkShadowSm
            : AppTheme.lightShadowSm,
      ),
      child: child,
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'active' || 'approved' || 'verified' => Colors.green,
      'banned' || 'rejected' => Theme.of(context).colorScheme.error,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        normalized.replaceAll('_', ' ').toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MaintenanceWarningBanner extends StatelessWidget {
  const _MaintenanceWarningBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Maintenance mode is currently active.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.superOnly = false,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final bool superOnly;
}

const _items = [
  _AdminDestination(
    label: 'Dashboard',
    path: RoutePaths.adminDashboard,
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  _AdminDestination(
    label: 'Support Inbox',
    path: RoutePaths.adminInbox,
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox_rounded,
  ),
  _AdminDestination(
    label: 'Notifications',
    path: RoutePaths.notificationsInbox,
    icon: Icons.notifications_none_outlined,
    selectedIcon: Icons.notifications_rounded,
  ),
  _AdminDestination(
    label: 'Super Dashboard',
    path: RoutePaths.superAdminDashboard,
    icon: Icons.security_outlined,
    selectedIcon: Icons.security_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Admin Management',
    path: RoutePaths.adminManagement,
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Recovery',
    path: RoutePaths.adminRecovery,
    icon: Icons.health_and_safety_outlined,
    selectedIcon: Icons.health_and_safety_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Users',
    path: RoutePaths.adminUserManagement,
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
  ),
  _AdminDestination(
    label: 'Verification',
    path: RoutePaths.adminVerification,
    icon: Icons.verified_user_outlined,
    selectedIcon: Icons.verified_user_rounded,
  ),
  _AdminDestination(
    label: 'Platform Settings',
    path: RoutePaths.adminSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Theme Engine',
    path: RoutePaths.adminThemeSettings,
    icon: Icons.color_lens_outlined,
    selectedIcon: Icons.color_lens_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Motion Engine',
    path: RoutePaths.adminMotionSettings,
    icon: Icons.animation_outlined,
    selectedIcon: Icons.animation_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'SIE Engine',
    path: RoutePaths.adminSieControl,
    icon: Icons.gesture_outlined,
    selectedIcon: Icons.gesture_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Language System',
    path: RoutePaths.adminLanguageSettings,
    icon: Icons.language_outlined,
    selectedIcon: Icons.language_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Interview Lab',
    path: RoutePaths.adminInterviewLab,
    icon: Icons.psychology_alt_outlined,
    selectedIcon: Icons.psychology_alt_rounded,
    superOnly: true,
  ),
  _AdminDestination(
    label: 'Audit Logs',
    path: RoutePaths.adminAuditLogs,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  _AdminDestination(
    label: 'Release Center',
    path: RoutePaths.adminReleaseCenter,
    icon: Icons.download_for_offline_outlined,
    selectedIcon: Icons.download_for_offline_rounded,
  ),
  _AdminDestination(
    label: 'Commerce Orders',
    path: RoutePaths.adminCommerceOrders,
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
  ),
  _AdminDestination(
    label: 'AI Usage Control',
    path: RoutePaths.adminAiUsageControl,
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
  ),
  _AdminDestination(
    label: 'AI Credits',
    path: RoutePaths.adminAiCredits,
    icon: Icons.toll_outlined,
    selectedIcon: Icons.toll_rounded,
  ),
  _AdminDestination(
    label: 'Monetization',
    path: RoutePaths.adminMonetization,
    icon: Icons.monetization_on_outlined,
    selectedIcon: Icons.monetization_on_rounded,
  ),
  _AdminDestination(
    label: 'Email Settings',
    path: RoutePaths.adminEmailSettings,
    icon: Icons.mark_email_unread_outlined,
    selectedIcon: Icons.mark_email_read_rounded,
  ),
  _AdminDestination(
    label: 'Finance Center',
    path: RoutePaths.adminFinanceCenter,
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics_rounded,
  ),
  _AdminDestination(
    label: 'Super Transactions',
    path: RoutePaths.adminSuperTransactions,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  _AdminDestination(
    label: 'Payout Queue',
    path: RoutePaths.adminPayouts,
    icon: Icons.outbound_outlined,
    selectedIcon: Icons.outbound_rounded,
  ),
  _AdminDestination(
    label: 'Resolution Desk',
    path: RoutePaths.adminResolutionDesk,
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent_rounded,
  ),
  _AdminDestination(
    label: 'Resolution AI Analyst',
    path: RoutePaths.adminResolutionAiAnalyst,
    icon: Icons.psychology_alt_outlined,
    selectedIcon: Icons.psychology_alt_rounded,
  ),
];

List<_AdminDestination> _itemsFor(bool isSuperAdmin) {
  return _items.where((item) {
    if (isSuperAdmin && item.path == RoutePaths.adminDashboard) return false;
    return isSuperAdmin || !item.superOnly;
  }).toList();
}

bool _isSuperAdminRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '') ==
      'superadmin';
}
