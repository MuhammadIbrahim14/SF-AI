import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../core/theme/role_theme.dart';
import '../../../models/user_role.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends ConsumerState<AdminUserManagementScreen> {
  String _query = '';
  String _role = 'all';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'User Management',
      subtitle: 'Search, inspect, ban, and restore platform accounts.',
      currentPath: RoutePaths.adminUserManagement,
      actions: [
        IconButton(
          tooltip: 'Refresh Registry',
          onPressed: () => ref.invalidate(allUsersProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or exact user ID...',
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  );
                  final filters = Row(
                    children: [
                      Container(
                        width: 1,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: _Dropdown(
                          label: 'Platform Role',
                          value: _role,
                          values: const [
                            'all',
                            'student',
                            'teacher',
                            'freelancer',
                            'company',
                            'admin',
                            'superAdmin',
                          ],
                          icon: Icons.shield_outlined,
                          onChanged: (value) => setState(() => _role = value),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: _Dropdown(
                          label: 'Account Status',
                          value: _status,
                          values: const [
                            'all',
                            'active',
                            'banned',
                            'suspended',
                          ],
                          icon: Icons.gavel_rounded,
                          onChanged: (value) => setState(() => _status = value),
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 800) {
                    return Column(
                      children: [search, const Divider(height: 16), filters],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: search),
                      Expanded(flex: 2, child: filters),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final visible = users.where(_matches).toList();
                if (visible.isEmpty) {
                  return const _Message(
                    icon: Icons.person_search_outlined,
                    title: 'No users found',
                    message: 'No accounts matched your search parameters.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = visible[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161616) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showSummary(user),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              AvatarWidget(
                                imageUrl: user.profileImage,
                                radius: 26,
                                fallbackText: _initials(user.fullName),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.fullName.isEmpty
                                                ? 'Unnamed account'
                                                : user.fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _RoleBadge(
                                    role: user.primaryRole ?? 'unassigned',
                                  ),
                                  const SizedBox(height: 6),
                                  _StatusBadge(status: user.status),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Message(
                icon: Icons.error_outline_rounded,
                title: 'Database Offline',
                message: error.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(UserModel user) {
    final textMatch =
        _query.isEmpty ||
        user.fullName.toLowerCase().contains(_query) ||
        user.email.toLowerCase().contains(_query) ||
        user.uid.toLowerCase().contains(_query);
    final roleMatch = _role == 'all' || user.primaryRole == _role;
    final statusMatch =
        _status == 'all' || user.status.toLowerCase() == _status;
    return textMatch && roleMatch && statusMatch;
  }

  Future<void> _showSummary(UserModel user) async {
    final operator = ref.read(currentUserProvider).value;
    final adminId = ref.read(authStateProvider).value?.uid;
    final isSelf = adminId == user.uid;
    final isSuperAdmin = _isSuperAdminRole(operator?.primaryRole);
    final targetIsAdmin = _isAdminRole(user.primaryRole);
    final canManage = !isSelf && (isSuperAdmin || !targetIsAdmin);
    final roleOptions = [
      'student',
      'teacher',
      'freelancer',
      'company',
      if (isSuperAdmin) ...['admin', 'superAdmin'],
    ];
    var selectedRole = roleOptions.contains(user.primaryRole)
        ? user.primaryRole!
        : roleOptions.first;
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final action = await showDialog<({String type, String value})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        imageUrl: user.profileImage,
                        radius: 28,
                        fallbackText: _initials(user.fullName),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName.isEmpty
                                  ? 'Unnamed user'
                                  : user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(status: user.status),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ACCOUNT DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _DataRow(
                                label: 'Account Type',
                                value: (user.primaryRole ?? 'Not assigned')
                                    .toUpperCase(),
                              ),
                              const Divider(height: 1),
                              _DataRow(
                                label: 'Profile Completed',
                                value: '${user.profileCompleted}%',
                              ),
                              const Divider(height: 1),
                              _DataRow(
                                label: 'Joined Date',
                                value: DateFormat.yMMMd().format(
                                  user.createdAt,
                                ),
                              ),
                              const Divider(height: 1),
                              _DataRow(
                                label: 'User ID',
                                value: user.uid,
                                isMonospace: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'COMPLIANCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _DataRow(
                                label: 'Privacy Policy',
                                value: user.privacyAccepted
                                    ? 'Accepted'
                                    : 'Not accepted',
                                isSuccess: user.privacyAccepted,
                              ),
                              const Divider(height: 1),
                              _DataRow(
                                label: 'Terms of Service',
                                value: user.termsAccepted
                                    ? 'Accepted'
                                    : 'Not accepted',
                                isSuccess: user.termsAccepted,
                              ),
                            ],
                          ),
                        ),

                        if (canManage) ...[
                          const SizedBox(height: 24),
                          Text(
                            'MODERATION CONTROLS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.error,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Override Role',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: roleOptions
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(
                                        role.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedRole = value);
                                }
                              },
                            ),
                          ),
                        ],
                        if (!canManage && !isSelf) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_rounded, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Only Super Administrators can modify admin accounts.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (canManage && user.status.toLowerCase() != 'suspended')
                        OutlinedButton(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop((type: 'status', value: 'suspended')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: const Text('Suspend'),
                        ),
                      if (canManage && user.freelancerUnlocked)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop((type: 'revoke_freelancer', value: '1')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange,
                            ),
                            child: const Text('Revoke Freelancer Unlock'),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      if (canManage &&
                          selectedRole !=
                              (user.primaryRole ?? roleOptions.first))
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilledButton.tonal(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop((type: 'role', value: selectedRole)),
                            child: const Text('Save Role'),
                          ),
                        ),
                      if (canManage)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  user.status.toLowerCase() == 'banned' ||
                                      user.status.toLowerCase() == 'suspended'
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop((
                              type: 'status',
                              value:
                                  user.status.toLowerCase() == 'banned' ||
                                      user.status.toLowerCase() == 'suspended'
                                  ? 'active'
                                  : 'banned',
                            )),
                            child: Text(
                              user.status.toLowerCase() == 'banned' ||
                                      user.status.toLowerCase() == 'suspended'
                                  ? 'Restore Access'
                                  : 'Ban Account',
                            ),
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
    if (action == null || !mounted) return;

    final success = switch (action.type) {
      'role' => await ref
          .read(adminActionProvider.notifier)
          .updateRole(user.uid, action.value),
      'revoke_freelancer' => await ref
          .read(adminActionProvider.notifier)
          .revokeFreelancerUnlock(user.uid),
      _ => await ref
          .read(adminActionProvider.notifier)
          .updateAccountStatus(user.uid, action.value),
    };
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? switch (action.type) {
                  'role' => 'User role updated to ${action.value}.',
                  'revoke_freelancer' =>
                    'Freelancer Bridge unlock revoked. Student data kept.',
                  _ => 'Account status updated to ${action.value}.',
                }
              : ref.read(adminActionProvider.notifier).errorMessage ??
                    'Unable to update user.',
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.isSuccess,
  });

  final String label;
  final String value;
  final bool isMonospace;
  final bool? isSuccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isSuccess != null)
            Icon(
              isSuccess! ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: isSuccess! ? Colors.green : Colors.redAccent,
            ),
          if (isSuccess != null) const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: isMonospace ? 'monospace' : null,
              color: isSuccess == false ? Colors.redAccent : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        hint: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        selectedItemBuilder: (context) {
          return values.map((val) {
            return Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  val == 'all' ? label : val.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            );
          }).toList();
        },
        items: values
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(
                  value == 'all' ? 'All' : value.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  Color _getRoleColor(BuildContext context) {
    final parsedRole = UserRole.fromString(role);
    if (parsedRole != null) {
      return getRoleTheme(parsedRole).primary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRoleColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'active' => Colors.green,
      'banned' => Colors.redAccent,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

bool _isAdminRole(String? role) {
  final normalized = _normalizeRole(role);
  return normalized == 'admin' || normalized == 'superadmin';
}

bool _isSuperAdminRole(String? role) {
  return _normalizeRole(role) == 'superadmin';
}

String _normalizeRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
