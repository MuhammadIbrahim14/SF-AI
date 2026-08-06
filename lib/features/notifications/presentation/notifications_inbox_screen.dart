import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_notification_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class NotificationsInboxScreen extends ConsumerStatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  ConsumerState<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState
    extends ConsumerState<NotificationsInboxScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final role =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.student;
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: role,
      title: 'Notifications',
      subtitle: unreadCount > 0
          ? '$unreadCount unread'
          : 'Updates across learning, hiring, and more',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(RouteNames.dashboard);
        }
      },
      actions: [
        if (unreadCount > 0)
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationActionProvider.notifier)
                  .markAllRead();
            },
            child: const Text('Mark all read'),
          ),
      ],
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryFilterBar(
            selected: _categoryFilter,
            onSelected: (value) => setState(() => _categoryFilter = value),
          ),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load notifications.\n$error',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
              data: (items) {
                final filtered = _categoryFilter == null
                    ? items
                    : items
                          .where(
                            (n) =>
                                n.effectiveCategory.toLowerCase() ==
                                _categoryFilter,
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const DashboardEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: "You're all caught up",
                    message:
                        'New alerts from batches, hiring, and support will show up here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = filtered[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () => _openNotification(notification),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotification(UserNotificationModel notification) async {
    if (!notification.read) {
      await ref
          .read(notificationActionProvider.notifier)
          .markRead(notification.id);
    }

    final routeName = notification.routeName?.trim();
    if (routeName == null || routeName.isEmpty) return;
    if (!mounted) return;

    final params = notification.routeParams;
    try {
      context.pushNamed(
        routeName,
        pathParameters: {
          for (final entry in params.entries)
            if (entry.key.isNotEmpty && entry.value.isNotEmpty)
              entry.key: entry.value,
        },
        queryParameters: {
          for (final entry in params.entries)
            if (entry.key.startsWith('q_') && entry.value.isNotEmpty)
              entry.key.substring(2): entry.value,
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $error')),
      );
    }
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _filters = <(String?, String)>[
    (null, 'All'),
    ('hiring', 'Hiring'),
    ('batch', 'Batches'),
    ('learning', 'Learning'),
    ('commerce', 'Commerce'),
    ('support', 'Support'),
    ('admin', 'Admin'),
    ('system', 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final filter in _filters) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter.$2),
                selected: selected == filter.$1,
                onSelected: (_) => onSelected(filter.$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final UserNotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    final time = DateFormat.MMMd().add_jm().format(notification.createdAt);
    final category = notification.effectiveCategory;

    return Material(
      color: unread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _categoryColor(category).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: _categoryColor(category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.info,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (category.isNotEmpty) category,
                        time,
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'hiring':
        return Icons.work_outline_rounded;
      case 'batch':
        return Icons.groups_rounded;
      case 'learning':
        return Icons.menu_book_rounded;
      case 'commerce':
        return Icons.storefront_outlined;
      case 'support':
        return Icons.support_agent_rounded;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'hiring':
        return AppColors.companyPrimary;
      case 'batch':
        return AppColors.teacherPrimary;
      case 'learning':
        return AppColors.studentPrimary;
      case 'commerce':
        return AppColors.freelancerPrimary;
      case 'support':
        return AppColors.info;
      case 'admin':
        return AppColors.adminPrimary;
      default:
        return AppColors.info;
    }
  }
}
