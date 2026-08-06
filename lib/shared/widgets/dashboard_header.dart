import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/role_theme.dart';
import '../../providers/theme_provider.dart';
import '../../features/settings/providers/settings_providers.dart';
import 'avatar_widget.dart';
import 'theme_orb_button.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    required this.roleTitle,
    required this.roleTheme,
    this.photoUrl,
    this.onProfileTap,
    this.onNotificationTap,
    this.unreadCount = 0,
  });

  final String userName;
  final String roleTitle;
  final RoleThemeColors roleTheme;
  final String? photoUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final int unreadCount;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final themeSettings = ref.watch(themeSettingsStreamProvider).value;
    final isThemeForced =
        themeSettings?.themeMode == 'dark' ||
        themeSettings?.themeMode == 'light';

    return Padding(
      // Floating margins — sides + top
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface.withValues(alpha: 0.60)
                  : colorScheme.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: roleTheme.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // Role badge — pill style
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        roleTheme.primary.withValues(
                          alpha: isDark ? 0.25 : 0.15,
                        ),
                        roleTheme.primary.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: roleTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    roleTitle.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? roleTheme.secondary : roleTheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Greeting
                Expanded(
                  child: Text(
                    'Welcome, $userName',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Notification bell — always visible; tap navigates when wired
                _NavIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: onNotificationTap,
                  color: colorScheme.onSurface.withValues(alpha: 0.85),
                  badgeCount: unreadCount,
                  tooltip: 'Notifications',
                ),
                const SizedBox(width: 4),

                // Theme Switcher Orb
                ThemeOrbButton(
                  isDark: isDark,
                  isManaged: isThemeForced,
                  onToggle: isThemeForced
                      ? null
                      : () => ref.read(themeNotifierProvider.notifier).toggle(),
                ),
                const SizedBox(width: 8),

                // Divider
                Container(
                  height: 20,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        colorScheme.outlineVariant.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Avatar with glow ring
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          roleTheme.primary.withValues(alpha: 0.5),
                          roleTheme.primary.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: roleTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: AvatarWidget(
                      imageUrl: photoUrl,
                      radius: 16,
                      fallbackText: userName.isNotEmpty
                          ? userName[0].toUpperCase()
                          : 'U',
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.badgeCount = 0,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final int badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 22),
              if (showBadge)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
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
    );
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
