import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';

class CustomerAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomerAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final theme = Theme.of(context);

    final currentPath = GoRouter.of(context)
        .routeInformationProvider
        .value
        .uri
        .path
        .replaceAll(RegExp(r'\/+\z'), '');
    final isCustomerDashboard = currentPath == RoutePaths.customerDashboard;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.colorScheme.surface,
      centerTitle: false,
      leading: isCustomerDashboard
          ? null
          : IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.customerDashboard);
                }
              },
            ),
      title: InkWell(
        onTap: () => context.goNamed(RouteNames.customerDashboard),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SkillForge',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Desktop Navigation Links
        if (MediaQuery.of(context).size.width > 800) ...[
          _NavButton(
            label: 'Services',
            onTap: () => context.goNamed(RouteNames.servicesMarketplace),
          ),
          _NavButton(
            label: 'Freelancers',
            onTap: () => context.goNamed(RouteNames.freelancerDirectory),
          ),
          _NavButton(
            label: 'My Requests',
            onTap: () => context.goNamed(RouteNames.serviceRequests),
          ),
          _NavButton(
            label: 'My Orders',
            onTap: () => context.goNamed(RouteNames.serviceOrders),
          ),
          _NavButton(
            label: 'Wallet',
            onTap: () => context.go(RoutePaths.customerWallet),
          ),
          _NavButton(
            label: 'Resolutions',
            onTap: () => context.goNamed(RouteNames.customerResolutions),
          ),
          const SizedBox(width: 8),
        ],

        IconButton(
          tooltip: 'Notifications',
          onPressed: () =>
              context.pushNamed(RouteNames.notificationsInbox),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),

        // User Avatar / Dropdown
        PopupMenuButton<String>(
          offset: const Offset(0, kToolbarHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Customer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'dashboard',
              child: const Row(
                children: [
                  Icon(Icons.dashboard_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Dashboard'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'account',
              child: const Row(
                children: [
                  Icon(Icons.manage_accounts_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Account Settings'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'support',
              child: const Row(
                children: [
                  Icon(Icons.support_agent_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Support Tickets'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'resolutions',
              child: const Row(
                children: [
                  Icon(Icons.rule_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Resolution Center'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'wallet',
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Demo Wallet'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
                  const SizedBox(width: 12),
                  Text('Log out', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'dashboard':
                context.goNamed(RouteNames.customerDashboard);
                break;
              case 'account':
                context.pushNamed(RouteNames.profileAccountSettings);
                break;
              case 'support':
                context.pushNamed(RouteNames.mySupportRequests);
                break;
              case 'resolutions':
                context.pushNamed(RouteNames.customerResolutions);
                break;
              case 'wallet':
                context.go(RoutePaths.customerWallet);
                break;
              case 'logout':
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.goNamed(RouteNames.home);
                }
                break;
            }
          },
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(label),
    );
  }
}
