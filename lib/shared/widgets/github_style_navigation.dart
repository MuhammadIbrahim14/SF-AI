import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../features/copilot/presentation/copilot_floating_button.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../navigation/role_navigation_config.dart';
import 'animated_scifi_background.dart';
import 'avatar_widget.dart';
import 'responsive_layout.dart';
import 'theme_orb_button.dart';

enum _NavigationMenuPanel { appMenu, roleActions }

class _RoleNavigationVisual {
  const _RoleNavigationVisual({
    required this.primary,
    required this.secondary,
    required this.tagline,
  });

  final Color primary;
  final Color secondary;
  final String tagline;
}

_RoleNavigationVisual _visualFor(UserRole role) {
  return switch (role) {
    UserRole.teacher => const _RoleNavigationVisual(
      primary: AppColors.teacherPrimary,
      secondary: AppColors.teacherSecondary,
      tagline: 'Create, mentor, and track learner outcomes',
    ),
    UserRole.company => const _RoleNavigationVisual(
      primary: AppColors.companyPrimary,
      secondary: AppColors.companySecondary,
      tagline: 'Hire verified talent and manage pipelines',
    ),
    UserRole.freelancer => const _RoleNavigationVisual(
      primary: AppColors.freelancerPrimary,
      secondary: AppColors.freelancerSecondary,
      tagline: 'Find work, track applications, and grow',
    ),
    _ => const _RoleNavigationVisual(
      primary: AppColors.studentPrimary,
      secondary: AppColors.studentSecondary,
      tagline: 'Learn, prove skills, and unlock opportunities',
    ),
  };
}

List<RoleNavigationDestination> _roleActionsFor(
  UserRole role,
  List<RoleNavigationDestination> destinations,
) {
  final actionPaths = switch (role) {
    UserRole.teacher => const {
      RoutePaths.teacherCourseCreate,
      RoutePaths.teacherStudentProgress,
      RoutePaths.teacherProfile,
    },
    UserRole.company => const {
      RoutePaths.createJob,
      RoutePaths.hiringPipeline,
      RoutePaths.myInterviews,
      RoutePaths.companyProfile,
    },
    UserRole.freelancer => const {
      RoutePaths.jobList,
      RoutePaths.myApplications,
      RoutePaths.myInterviews,
      RoutePaths.freelancerProfile,
    },
    _ => const {RoutePaths.studentProfile},
  };

  return destinations
      .where((item) => actionPaths.contains(item.path))
      .toList(growable: false);
}

class _NavigationMenuSectionData {
  const _NavigationMenuSectionData({required this.title, required this.items});

  final String title;
  final List<RoleNavigationDestination> items;
}

List<_NavigationMenuSectionData> _appMenuSections(
  List<RoleNavigationDestination> destinations,
) {
  return RoleNavigationConfig.appMenuSectionsFrom(destinations)
      .map(
        (section) => _NavigationMenuSectionData(
          title: section.title,
          items: section.items,
        ),
      )
      .toList(growable: false);
}

List<_NavigationMenuSectionData> _actionsMenuSections(
  List<RoleNavigationDestination> destinations,
) {
  final quickItems = destinations
      .where((item) => item.type != RoleNavigationDestinationType.profile)
      .toList(growable: false);
  final profileItems = destinations
      .where((item) => item.type == RoleNavigationDestinationType.profile)
      .toList(growable: false);

  return [
    if (quickItems.isNotEmpty)
      _NavigationMenuSectionData(title: 'Quick actions', items: quickItems),
    if (profileItems.isNotEmpty)
      _NavigationMenuSectionData(title: 'Profile', items: profileItems),
  ];
}

class GitHubStyleNavigationFrame extends ConsumerStatefulWidget {
  const GitHubStyleNavigationFrame({
    super.key,
    required this.role,
    required this.child,
    this.showBackButton = false,
    this.onBack,
  });

  final UserRole role;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  ConsumerState<GitHubStyleNavigationFrame> createState() =>
      _GitHubStyleNavigationFrameState();
}

class _GitHubStyleNavigationFrameState
    extends ConsumerState<GitHubStyleNavigationFrame> {
  _NavigationMenuPanel? _openPanel;
  bool _isLoggingOut = false;

  void _togglePanel(_NavigationMenuPanel panel) {
    setState(() {
      _openPanel = _openPanel == panel ? null : panel;
    });
  }

  void _closePanel() {
    if (_openPanel == null) return;
    setState(() => _openPanel = null);
  }

  void _navigateTo(String path) {
    _closePanel();
    context.go(path);
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    _closePanel();
    setState(() => _isLoggingOut = true);

    await ref.read(authNotifierProvider.notifier).signOut();
    if (!mounted) return;

    final result = ref.read(authNotifierProvider);
    if (result.hasError) {
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
      return;
    }

    context.go(RoutePaths.home);
  }

  void _safeBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final fallbackRoute = switch (widget.role) {
      UserRole.teacher => RouteNames.teacherDashboard,
      UserRole.company => RouteNames.companyDashboard,
      UserRole.freelancer => RouteNames.freelancerDashboard,
      UserRole.admin => RouteNames.adminDashboard,
      UserRole.superAdmin => RouteNames.superAdminDashboard,
      _ => RouteNames.studentDashboard,
    };

    try {
      context.goNamed(fallbackRoute);
    } catch (_) {
      context.go(RoutePaths.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = RoleNavigationConfig.destinationsFor(widget.role);
    final roleActions = _roleActionsFor(widget.role, destinations);
    final visual = _visualFor(widget.role);
    final user = ref.watch(currentUserProvider).value;
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isMobile = AppBreakpoints.isMobile(width);
    final isTablet = AppBreakpoints.isTablet(width);
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalInset = isMobile
        ? 10.0
        : isTablet
        ? 18.0
        : 24.0;
    final menuTop = isMobile ? 66.0 : 72.0;
    final maxMenuHeight =
        (media.size.height -
                menuTop -
                media.padding.bottom -
                media.viewInsets.bottom -
                14)
            .clamp(280.0, 560.0);
    final appMenuWidth = isMobile
        ? null
        : (width - (horizontalInset * 2)).clamp(
            320.0,
            isTablet ? 420.0 : 430.0,
          );
    final actionsMenuWidth = isMobile
        ? null
        : (width - (horizontalInset * 2)).clamp(
            320.0,
            isTablet ? 390.0 : 400.0,
          );

    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    final activePath = RoleNavigationConfig.activePathFor(
      currentPath,
      destinations,
    );
    final activeDestination = destinations
        .where((item) => item.path == activePath)
        .cast<RoleNavigationDestination?>()
        .firstOrNull;
    final appSections = _appMenuSections(destinations);
    final actionSections = _actionsMenuSections(roleActions);

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
      child: AnimatedSciFiBackground(
        child: Stack(
          children: [
            Column(
              children: [
                _RoleTopNavigationBar(
                  role: widget.role,
                  visual: visual,
                  userName: user?.fullName ?? widget.role.label,
                  photoUrl: user?.photoUrl,
                  activeDestination: activeDestination,
                  isAppMenuOpen: _openPanel == _NavigationMenuPanel.appMenu,
                  isActionsMenuOpen:
                      _openPanel == _NavigationMenuPanel.roleActions,
                  onAppMenuTap: () =>
                      _togglePanel(_NavigationMenuPanel.appMenu),
                  onActionsTap: () =>
                      _togglePanel(_NavigationMenuPanel.roleActions),
                  onProfileTap: () =>
                      _togglePanel(_NavigationMenuPanel.roleActions),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: AppBreakpoints.isDesktop(width) ? 10 : 4,
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            ),
            if (widget.showBackButton)
              Positioned(
                top: isMobile ? 94 : 100,
                left: horizontalInset,
                child: _FixedBackButton(
                  accentColor: visual.primary,
                  onPressed: _safeBack,
                ),
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
              right: isMobile ? horizontalInset : null,
              child: _FloatingMenuTransition(
                visible: _openPanel == _NavigationMenuPanel.appMenu,
                alignment: Alignment.topLeft,
                child: _NavigationMenuCard(
                  width: appMenuWidth?.toDouble(),
                  maxHeight: maxMenuHeight.toDouble(),
                  title: 'SkillForge',
                  subtitle: '${widget.role.label} workspace',
                  accentColor: visual.primary,
                  children: [
                    for (final section in appSections)
                      _NavigationMenuSection(
                        title: section.title,
                        children: [
                          for (final item in section.items)
                            _NavigationMenuTile(
                              icon: item.path == activePath
                                  ? item.selectedIcon
                                  : item.icon,
                              label: item.label,
                              description: item.description,
                              selected: item.path == activePath,
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
              left: isMobile ? horizontalInset : null,
              child: _FloatingMenuTransition(
                visible: _openPanel == _NavigationMenuPanel.roleActions,
                alignment: Alignment.topRight,
                child: _NavigationMenuCard(
                  width: actionsMenuWidth?.toDouble(),
                  maxHeight: maxMenuHeight.toDouble(),
                  title: '${widget.role.label} actions',
                  subtitle: user?.email ?? '${widget.role.label} workspace',
                  accentColor: visual.primary,
                  children: [
                    for (final section in actionSections)
                      _NavigationMenuSection(
                        title: section.title,
                        children: [
                          for (final item in section.items)
                            _NavigationMenuTile(
                              icon: item.path == activePath
                                  ? item.selectedIcon
                                  : item.icon,
                              label: item.label,
                              description: item.description,
                              selected: item.path == activePath,
                              accentColor: visual.primary,
                              onTap: () => _navigateTo(item.path),
                            ),
                        ],
                      ),
                    _NavigationMenuSection(
                      title: 'Account',
                      children: [
                        _NavigationMenuTile(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          description: 'Account preferences and app settings',
                          selected:
                              currentPath == RoutePaths.profileAccountSettings,
                          accentColor: visual.primary,
                          onTap: () =>
                              _navigateTo(RoutePaths.profileAccountSettings),
                        ),
                        _NavigationMenuTile(
                          icon: Icons.security_outlined,
                          label: 'Security',
                          description: 'App lock, PIN and biometric settings',
                          selected: currentPath == RoutePaths.securitySettings,
                          accentColor: visual.primary,
                          onTap: () => _navigateTo(RoutePaths.securitySettings),
                        ),
                      ],
                    ),
                    Divider(
                      height: 24,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    _NavigationMenuTile(
                      icon: _isLoggingOut
                          ? Icons.hourglass_top_rounded
                          : Icons.logout_rounded,
                      label: _isLoggingOut ? 'Logging out...' : 'Logout',
                      description: _isLoggingOut
                          ? 'Ending your current session'
                          : 'Sign out of this session',
                      selected: false,
                      accentColor: AppColors.error,
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
            ),
            const CopilotFloatingButton(),
          ],
        ),
      ),
    );
  }
}

class _FixedBackButton extends StatelessWidget {
  const _FixedBackButton({required this.accentColor, required this.onPressed});

  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.16),
          shape: StadiumBorder(
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: accentColor, size: 20),
                  const SizedBox(width: 7),
                  Text(
                    'Back',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTopNavigationBar extends ConsumerWidget {
  const _RoleTopNavigationBar({
    required this.role,
    required this.visual,
    required this.userName,
    required this.photoUrl,
    required this.activeDestination,
    required this.isAppMenuOpen,
    required this.isActionsMenuOpen,
    required this.onAppMenuTap,
    required this.onActionsTap,
    required this.onProfileTap,
  });

  final UserRole role;
  final _RoleNavigationVisual visual;
  final String userName;
  final String? photoUrl;
  final RoleNavigationDestination? activeDestination;
  final bool isAppMenuOpen;
  final bool isActionsMenuOpen;
  final VoidCallback onAppMenuTap;
  final VoidCallback onActionsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme Switcher Logic
    final themeSettings = ref.watch(themeSettingsStreamProvider).value;
    final isThemeForced =
        themeSettings?.themeMode == 'dark' ||
        themeSettings?.themeMode == 'light';

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = AppBreakpoints.isMobile(width);
    final isDesktop = AppBreakpoints.isDesktop(width);
    final isNarrowMobile = width < 390;
    final horizontalPadding = isMobile ? 10.0 : 24.0;
    final navHeight = isMobile
        ? 52.0
        : isDesktop
        ? 62.0
        : 56.0;
    final avatarRadius = isMobile ? 16.0 : 17.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isMobile ? 8 : 12,
        horizontalPadding,
        isMobile ? 6 : 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: navHeight,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface.withValues(alpha: isDark ? 0.76 : 0.92),
                  colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.46 : 0.64,
                  ),
                  visual.primary.withValues(alpha: isDark ? 0.10 : 0.06),
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
                _TopNavIconButton(
                  tooltip: 'Open ${role.label.toLowerCase()} menu',
                  icon: isAppMenuOpen
                      ? Icons.close_rounded
                      : Icons.apps_rounded,
                  selected: isAppMenuOpen,
                  accentColor: visual.primary,
                  onTap: onAppMenuTap,
                ),
                SizedBox(width: isMobile ? 8 : 10),
                if (!isNarrowMobile) ...[
                  Container(
                    width: isMobile ? 32 : 34,
                    height: isMobile ? 32 : 34,
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
                    child: Icon(role.icon, color: Colors.white, size: 19),
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                ],
                if (!isMobile)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SkillForge ${role.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          visual.tagline,
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
                  )
                else
                  Expanded(
                    child: Text(
                      role.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                if (isDesktop && activeDestination != null) ...[
                  _CurrentPagePill(
                    label: activeDestination!.label,
                    icon: activeDestination!.selectedIcon,
                    accentColor: visual.primary,
                  ),
                  const SizedBox(width: 10),
                ],
                _NotificationBellButton(
                  unreadCount: ref.watch(unreadNotificationCountProvider),
                  onTap: () =>
                      context.pushNamed(RouteNames.notificationsInbox),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                _TopNavIconButton(
                  tooltip: '${role.label} actions',
                  icon: isActionsMenuOpen
                      ? Icons.close_rounded
                      : Icons.bolt_rounded,
                  selected: isActionsMenuOpen,
                  accentColor: visual.primary,
                  onTap: onActionsTap,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                // Theme Switcher Orb
                Transform.scale(
                  scale: 0.8,
                  child: ThemeOrbButton(
                    isDark: isDark,
                    isManaged: isThemeForced,
                    onToggle: isThemeForced
                        ? null
                        : () =>
                              ref.read(themeNotifierProvider.notifier).toggle(),
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                _ProfileAvatarButton(
                  userName: userName,
                  photoUrl: photoUrl,
                  radius: avatarRadius,
                  selected: isActionsMenuOpen,
                  accentColor: visual.primary,
                  onTap: onProfileTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showBadge = unreadCount > 0;

    return Tooltip(
      message: 'Notifications',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 21,
                ),
                if (showBadge)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
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

class _CurrentPagePill extends StatelessWidget {
  const _CurrentPagePill({
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
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

class _TopNavIconButton extends StatefulWidget {
  const _TopNavIconButton({
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
  State<_TopNavIconButton> createState() => _TopNavIconButtonState();
}

class _TopNavIconButtonState extends State<_TopNavIconButton> {
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

class _ProfileAvatarButton extends StatefulWidget {
  const _ProfileAvatarButton({
    required this.userName,
    required this.photoUrl,
    required this.radius,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String userName;
  final String? photoUrl;
  final double radius;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<_ProfileAvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open profile actions',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.selected
                        ? [
                            widget.accentColor,
                            widget.accentColor.withValues(alpha: 0.42),
                          ]
                        : [
                            widget.accentColor.withValues(alpha: 0.42),
                            Colors.white.withValues(alpha: 0.16),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(
                        alpha: widget.selected ? 0.32 : 0.18,
                      ),
                      blurRadius: widget.selected ? 18 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AvatarWidget(
                  imageUrl: widget.photoUrl,
                  radius: widget.radius,
                  fallbackText: widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : 'U',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingMenuTransition extends StatelessWidget {
  const _FloatingMenuTransition({
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

class _NavigationMenuCard extends StatelessWidget {
  const _NavigationMenuCard({
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
                          Icons.auto_awesome_rounded,
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

class _NavigationMenuSection extends StatelessWidget {
  const _NavigationMenuSection({required this.title, required this.children});

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

class _NavigationMenuTile extends StatelessWidget {
  const _NavigationMenuTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
    this.description,
  });

  final IconData icon;
  final String label;
  final String? description;
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
                    icon,
                    color: selected
                        ? accentColor
                        : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: selected
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                        ),
                      ],
                    ],
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
