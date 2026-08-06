import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/customer_workspace_shell.dart';

class CustomerDashboard extends ConsumerWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return CustomerWorkspaceShell(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CustomerHero(userName: user?.fullName ?? 'Customer'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'Browse Services',
                                subtitle: 'Hire top talent for your projects',
                                icon: Icons.design_services_rounded,
                                color: Colors.indigo,
                                onTap: () => context.goNamed(
                                  RouteNames.servicesMarketplace,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'Find Freelancers',
                                subtitle: 'Discover experts by skill',
                                icon: Icons.people_alt_rounded,
                                color: Colors.teal,
                                onTap: () => context.goNamed(
                                  RouteNames.freelancerDirectory,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _CustomerActionCard(
                              title: 'Browse Services',
                              subtitle: 'Hire top talent for your projects',
                              icon: Icons.design_services_rounded,
                              color: Colors.indigo,
                              onTap: () => context.goNamed(
                                RouteNames.servicesMarketplace,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _CustomerActionCard(
                              title: 'Find Freelancers',
                              subtitle: 'Discover experts by skill',
                              icon: Icons.people_alt_rounded,
                              color: Colors.teal,
                              onTap: () => context.goNamed(
                                RouteNames.freelancerDirectory,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'My Requests',
                                subtitle: 'Manage your custom service requests',
                                icon: Icons.assignment_rounded,
                                color: Colors.deepOrange,
                                onTap: () =>
                                    context.goNamed(RouteNames.serviceRequests),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'My Orders',
                                subtitle: 'Track your purchased services',
                                icon: Icons.shopping_bag_rounded,
                                color: Colors.purple,
                                onTap: () =>
                                    context.goNamed(RouteNames.serviceOrders),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _CustomerActionCard(
                              title: 'My Requests',
                              subtitle: 'Manage your custom service requests',
                              icon: Icons.assignment_rounded,
                              color: Colors.deepOrange,
                              onTap: () =>
                                  context.goNamed(RouteNames.serviceRequests),
                            ),
                            const SizedBox(height: 16),
                            _CustomerActionCard(
                              title: 'My Orders',
                              subtitle: 'Track your purchased services',
                              icon: Icons.shopping_bag_rounded,
                              color: Colors.purple,
                              onTap: () =>
                                  context.goNamed(RouteNames.serviceOrders),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      _CustomerActionCard(
                        title: 'AI Project Assistant',
                        subtitle: 'Draft briefs, requirements, and messages',
                        icon: Icons.auto_awesome_rounded,
                        color: Colors.indigoAccent,
                        onTap: () =>
                            context.goNamed(RouteNames.customerAiAssistant),
                      ),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'Request Builder',
                                subtitle: 'Create a clearer service request',
                                icon: Icons.post_add_rounded,
                                color: Colors.cyan,
                                onTap: () => context.goNamed(
                                  RouteNames.customerAiAssistant,
                                  queryParameters: {'task': 'serviceRequest'},
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'Delivery Checklist',
                                subtitle: 'Review work before approval',
                                icon: Icons.fact_check_rounded,
                                color: Colors.green,
                                onTap: () => context.goNamed(
                                  RouteNames.customerAiAssistant,
                                  queryParameters: {
                                    'task': 'deliveryChecklist',
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _CustomerActionCard(
                              title: 'Request Builder',
                              subtitle: 'Create a clearer service request',
                              icon: Icons.post_add_rounded,
                              color: Colors.cyan,
                              onTap: () => context.goNamed(
                                RouteNames.customerAiAssistant,
                                queryParameters: {'task': 'serviceRequest'},
                              ),
                            ),
                            const SizedBox(height: 16),
                            _CustomerActionCard(
                              title: 'Delivery Checklist',
                              subtitle: 'Review work before approval',
                              icon: Icons.fact_check_rounded,
                              color: Colors.green,
                              onTap: () => context.goNamed(
                                RouteNames.customerAiAssistant,
                                queryParameters: {'task': 'deliveryChecklist'},
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      _CustomerActionCard(
                        title: 'My Invoices',
                        subtitle: 'Download sandbox receipts and billing PDFs',
                        icon: Icons.receipt_long_rounded,
                        color: Colors.blueGrey,
                        onTap: () => context.goNamed(RouteNames.invoices),
                      ),
                      const SizedBox(height: 16),
                      _CustomerActionCard(
                        title: 'Demo Wallet',
                        subtitle:
                            'Add sandbox balance and review wallet ledger',
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.green,
                        onTap: () => context.go(RoutePaths.customerWallet),
                      ),
                      const SizedBox(height: 16),
                      _CustomerActionCard(
                        title: 'Resolution Center',
                        subtitle: 'Track revisions, disputes, and refunds',
                        icon: Icons.support_agent_rounded,
                        color: Colors.redAccent,
                        onTap: () =>
                            context.goNamed(RouteNames.customerResolutions),
                      ),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'Account Settings',
                                subtitle: 'Manage account preferences',
                                icon: Icons.manage_accounts_rounded,
                                color: Colors.blueGrey.shade700,
                                onTap: () => context.pushNamed(
                                  RouteNames.profileAccountSettings,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CustomerActionCard(
                                title: 'Support Tickets',
                                subtitle: 'Get help or report an issue',
                                icon: Icons.support_agent_rounded,
                                color: Colors.brown,
                                onTap: () => context.pushNamed(
                                  RouteNames.mySupportRequests,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _CustomerActionCard(
                          title: 'Account Settings',
                          subtitle: 'Manage account preferences',
                          icon: Icons.manage_accounts_rounded,
                          color: Colors.blueGrey.shade700,
                          onTap: () => context.pushNamed(
                            RouteNames.profileAccountSettings,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CustomerActionCard(
                          title: 'Support Tickets',
                          subtitle: 'Get help or report an issue',
                          icon: Icons.support_agent_rounded,
                          color: Colors.brown,
                          onTap: () => context.pushNamed(
                            RouteNames.mySupportRequests,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _EmptyActivityState(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerHero extends StatelessWidget {
  const _CustomerHero({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to hire top talent for your next project?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerActionCard extends StatelessWidget {
  const _CustomerActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? color.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent orders and requests will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
