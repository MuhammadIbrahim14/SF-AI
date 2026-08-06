import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../settings/providers/settings_providers.dart';
import 'widgets/profile_navigation_card.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeSettingsStreamProvider).value;
    final isForced =
        themeSettings?.themeMode == 'dark' ||
        themeSettings?.themeMode == 'light';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.student;

    return RoleFixedHeaderPage(
      role: role,
      title: 'Trust & Command Center',
      subtitle: 'Manage account preferences, compliance, and sign-out.',
      showBackButton: true,
      scrollable: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final horizontal = isMobile ? 16.0 : 32.0;

          Widget buildGrid(List<Widget> cards) {
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cards
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: c,
                      ),
                    )
                    .toList(),
              );
            }

            List<Widget> rows = [];
            for (int i = 0; i < cards.length; i += 2) {
              rows.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: i + 1 < cards.length
                            ? cards[i + 1]
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(children: rows);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      title: 'System Preferences',
                      icon: Icons.settings_rounded,
                    ),
                    buildGrid([
                      ProfileNavigationCard(
                        index: 0,
                        icon: Icons.dark_mode_outlined,
                        title: 'Theme',
                        subtitle: isForced
                            ? '${isDark ? 'Dark' : 'Light'} appearance managed by admin'
                            : '${isDark ? 'Dark' : 'Light'} appearance active',
                        onTap: isForced
                            ? null
                            : () => ref
                                  .read(themeNotifierProvider.notifier)
                                  .toggle(),
                        trailing: Switch.adaptive(
                          value: isDark,
                          onChanged: isForced
                              ? null
                              : (_) => ref
                                    .read(themeNotifierProvider.notifier)
                                    .toggle(),
                        ),
                      ),
                      ProfileNavigationCard(
                        index: 1,
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: 'English',
                        onTap: () =>
                            context.pushNamed(RouteNames.profilePreferences),
                      ),
                      ProfileNavigationCard(
                        index: 2,
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage account and activity alerts',
                        onTap: () =>
                            context.pushNamed(RouteNames.profileNotifications),
                      ),
                      ProfileNavigationCard(
                        index: 3,
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy',
                        subtitle: 'Review local security and account privacy',
                        onTap: () =>
                            context.pushNamed(RouteNames.securitySettings),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    const _SectionHeader(
                      title: 'Compliance & Trust',
                      icon: Icons.verified_user_rounded,
                    ),
                    buildGrid([
                      ProfileNavigationCard(
                        index: 4,
                        icon: Icons.policy_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How SkillForge AI handles your data',
                        onTap: () =>
                            context.pushNamed(RouteNames.privacyPolicy),
                      ),
                      ProfileNavigationCard(
                        index: 5,
                        icon: Icons.article_outlined,
                        title: 'Terms of Service',
                        subtitle:
                            'Rules and responsibilities for using the app',
                        onTap: () =>
                            context.pushNamed(RouteNames.termsOfService),
                      ),
                      ProfileNavigationCard(
                        index: 6,
                        icon: Icons.replay_circle_filled_outlined,
                        title: 'Return & Refund Policy',
                        subtitle: 'Digital purchase and refund rules',
                        onTap: () =>
                            context.pushNamed(RouteNames.returnRefundPolicy),
                      ),
                      ProfileNavigationCard(
                        index: 7,
                        icon: Icons.local_shipping_outlined,
                        title: 'Shipping & Service Policy',
                        subtitle: 'How digital products and services are delivered',
                        onTap: () => context.pushNamed(
                          RouteNames.shippingServicePolicy,
                        ),
                      ),
                      ProfileNavigationCard(
                        index: 8,
                        icon: Icons.support_agent_rounded,
                        title: 'Contact Support',
                        subtitle:
                            'Get help with privacy, terms, or your account',
                        onTap: () => context.pushNamed(RouteNames.contactUs),
                      ),
                      ProfileNavigationCard(
                        index: 9,
                        icon: Icons.inbox_outlined,
                        title: 'My Support Requests',
                        subtitle: 'Track tickets and view support responses',
                        onTap: () =>
                            context.pushNamed(RouteNames.mySupportRequests),
                      ),
                      ProfileNavigationCard(
                        index: 10,
                        icon: Icons.handshake_rounded,
                        title: 'My Service Requests',
                        subtitle:
                            'Track freelancer requests and delivery status',
                        onTap: () =>
                            context.pushNamed(RouteNames.serviceRequests),
                      ),
                      ProfileNavigationCard(
                        index: 11,
                        icon: Icons.receipt_long_rounded,
                        title: 'My Orders',
                        subtitle:
                            'View sandbox orders created from accepted service requests',
                        onTap: () => context.pushNamed(
                          role == UserRole.freelancer
                              ? RouteNames.freelancerServiceOrders
                              : RouteNames.serviceOrders,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    const _SectionHeader(
                      title: 'Account Deletion',
                      icon: Icons.warning_rounded,
                      isDestructive: true,
                    ),
                    buildGrid([
                      ProfileNavigationCard(
                        index: 12,
                        icon: Icons.person_remove_rounded,
                        title: 'Account Deletion Policy',
                        subtitle:
                            'Request deletion and understand data handling',
                        onTap: () =>
                            context.pushNamed(RouteNames.accountDeletionPolicy),
                      ),
                      ProfileNavigationCard(
                        index: 13,
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        subtitle: 'Sign out of this SkillForge AI account',
                        isDestructive: true,
                        onTap: () => _confirmLogout(context, ref),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.isDestructive = false,
  });

  final String title;
  final IconData icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
