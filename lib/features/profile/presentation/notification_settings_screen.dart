import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_events.dart';
import '../../../models/user_role.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import 'widgets/profile_navigation_card.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  final Map<String, bool> _categories = {
    for (final key in NotificationCategories.preferenceKeys) key: true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await ref
          .read(notificationRepositoryProvider)
          .getNotificationPrefs(uid);
      if (prefs != null && mounted) {
        setState(() {
          _pushEnabled = prefs['push'] != false;
          _emailEnabled = prefs['email'] != false;
          final categories = prefs['categories'];
          if (categories is Map) {
            for (final key in NotificationCategories.preferenceKeys) {
              final value = categories[key];
              if (value is bool) {
                _categories[key] = value;
              }
            }
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(
        uid: uid,
        data: {
          'notificationPrefs': {
            'push': _pushEnabled,
            'email': _emailEnabled,
            'categories': Map<String, bool>.from(_categories),
          },
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preferences: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setPush(bool value) async {
    setState(() => _pushEnabled = value);
    await _persist();
  }

  Future<void> _setEmail(bool value) async {
    setState(() => _emailEnabled = value);
    await _persist();
  }

  Future<void> _setCategory(String key, bool value) async {
    setState(() => _categories[key] = value);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final role =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.student;

    return RoleFixedHeaderPage(
      role: role,
      title: 'Notification Hub',
      subtitle: 'Control account, activity, and product notifications.',
      showBackButton: true,
      scrollable: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 600 ? 16.0 : 32.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SettingsIntro(
                            icon: Icons.notifications_active_rounded,
                            title: 'Notification Hub',
                            subtitle:
                                'Control how and when SkillForge AI alerts you.',
                          ),
                          const SizedBox(height: 32),
                          ProfileNavigationCard(
                            index: 0,
                            title: 'Push Notifications',
                            subtitle:
                                'Stored for future delivery (in-app works now)',
                            icon: Icons.notifications_active_outlined,
                            onTap: () => _setPush(!_pushEnabled),
                            trailing: Switch.adaptive(
                              value: _pushEnabled,
                              onChanged: _saving ? null : _setPush,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ProfileNavigationCard(
                            index: 1,
                            title: 'Email Updates',
                            subtitle:
                                'Stored for future email channel (not sent yet)',
                            icon: Icons.alternate_email_rounded,
                            onTap: () => _setEmail(!_emailEnabled),
                            trailing: Switch.adaptive(
                              value: _emailEnabled,
                              onChanged: _saving ? null : _setEmail,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'In-app categories',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Disabled categories are skipped when new alerts are created. '
                            'System alerts always deliver.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ...NotificationCategories.preferenceKeys
                              .asMap()
                              .entries
                              .map((entry) {
                                final index = entry.key + 2;
                                final key = entry.value;
                                final enabled = _categories[key] ?? true;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ProfileNavigationCard(
                                    index: index,
                                    title: _categoryLabel(key),
                                    subtitle: _categorySubtitle(key),
                                    icon: _categoryIcon(key),
                                    onTap: () => _setCategory(key, !enabled),
                                    trailing: Switch.adaptive(
                                      value: enabled,
                                      onChanged: _saving
                                          ? null
                                          : (value) =>
                                                _setCategory(key, value),
                                    ),
                                  ),
                                );
                              }),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ProfileNavigationCard(
                              index:
                                  NotificationCategories.preferenceKeys.length +
                                  2,
                              title: 'System',
                              subtitle:
                                  'Always on — payments and account-critical alerts',
                              icon: Icons.security_rounded,
                              onTap: () {},
                              trailing: Switch.adaptive(
                                value: true,
                                onChanged: null,
                              ),
                            ),
                          ),
                          if (_saving)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _categoryLabel(String key) {
    switch (key) {
      case NotificationCategories.batch:
        return 'Batches';
      case NotificationCategories.learning:
        return 'Learning';
      case NotificationCategories.hiring:
        return 'Hiring';
      case NotificationCategories.commerce:
        return 'Commerce';
      case NotificationCategories.support:
        return 'Support';
      case NotificationCategories.admin:
        return 'Admin decisions';
      case NotificationCategories.marketing:
        return 'Tips & Announcements';
      default:
        return key;
    }
  }

  String _categorySubtitle(String key) {
    switch (key) {
      case NotificationCategories.batch:
        return 'Join requests, announcements, sessions';
      case NotificationCategories.learning:
        return 'Assignments, grades, certificates';
      case NotificationCategories.hiring:
        return 'Applications, interviews, offers';
      case NotificationCategories.commerce:
        return 'Service requests and orders';
      case NotificationCategories.support:
        return 'Ticket updates';
      case NotificationCategories.admin:
        return 'Verification and payout decisions';
      case NotificationCategories.marketing:
        return 'Marketing announcements are disabled for this deployment';
      default:
        return '';
    }
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case NotificationCategories.batch:
        return Icons.groups_rounded;
      case NotificationCategories.learning:
        return Icons.menu_book_rounded;
      case NotificationCategories.hiring:
        return Icons.work_outline_rounded;
      case NotificationCategories.commerce:
        return Icons.storefront_outlined;
      case NotificationCategories.support:
        return Icons.support_agent_rounded;
      case NotificationCategories.admin:
        return Icons.admin_panel_settings_outlined;
      case NotificationCategories.marketing:
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 40),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
