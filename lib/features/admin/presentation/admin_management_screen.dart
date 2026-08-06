import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  final _lookupController = TextEditingController();

  @override
  void dispose() {
    _lookupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminsAsync = ref.watch(adminUsersProvider);
    final actionState = ref.watch(adminActionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'Admin Registry',
      subtitle: 'Create, remove, ban, and manage administrator access levels.',
      currentPath: RoutePaths.adminManagement,
      actions: [
        IconButton(
          tooltip: 'Refresh Registry',
          onPressed: () => ref.invalidate(adminUsersProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161616) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.adminPrimary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.adminPrimary.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: AppColors.adminPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'GRANT ADMIN ACCESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.adminPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Promote an existing Firebase user by email address or exact UID. This assigns standard Admin clearance.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final input = TextField(
                      controller: _lookupController,
                      decoration: InputDecoration(
                        labelText: 'User Email or UID',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createAdmin(),
                    );
                    final button = FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: actionState.isLoading ? null : _createAdmin,
                      icon: actionState.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text(
                        'Promote User',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );

                    if (constraints.maxWidth < 640) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [input, const SizedBox(height: 16), button],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: input),
                        const SizedBox(width: 16),
                        button,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'ACTIVE ADMINISTRATORS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          adminsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Center(
              child: Text(
                'Unable to load admins: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            data: (admins) {
              if (admins.isEmpty) {
                return const _EmptyAdmins();
              }
              return Column(
                children: admins
                    .map(
                      (admin) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdminCard(
                          admin: admin,
                          busy: actionState.isLoading,
                          onBan: () => _setAdminStatus(admin, 'banned'),
                          onSuspend: () => _setAdminStatus(admin, 'suspended'),
                          onRestore: () => _setAdminStatus(admin, 'active'),
                          onPromoteToSuperAdmin: () =>
                              _promoteToSuperAdmin(admin),
                          onRemove: () => _removeAdmin(admin),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createAdmin() async {
    final lookup = _lookupController.text.trim();
    if (lookup.isEmpty) {
      _showSnack('Enter a user email or UID first.');
      return;
    }

    final success = await ref
        .read(adminActionProvider.notifier)
        .createAdmin(lookup);
    if (!mounted) return;
    if (success) {
      _lookupController.clear();
      ref.invalidate(adminUsersProvider);
      _showSnack('Admin access granted.');
    } else {
      _showSnack(
        ref.read(adminActionProvider.notifier).errorMessage ??
            'Unable to create admin.',
      );
    }
  }

  Future<void> _setAdminStatus(UserModel admin, String status) async {
    final confirmed = await _confirm(
      title: '${_statusVerb(status)} Admin?',
      message:
          'This will change ${admin.email} to ${status.toUpperCase()} status.',
      destructive: status != 'active',
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(adminActionProvider.notifier)
        .updateAccountStatus(admin.uid, status);
    if (!mounted) return;
    ref.invalidate(adminUsersProvider);
    _showSnack(
      success
          ? 'Admin status updated.'
          : ref.read(adminActionProvider.notifier).errorMessage ??
                'Unable to update admin status.',
    );
  }

  Future<void> _removeAdmin(UserModel admin) async {
    final confirmed = await _confirm(
      title: 'Revoke Admin Access?',
      message:
          '${admin.email} will be completely demoted to Student and must complete onboarding again.',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(adminActionProvider.notifier)
        .removeAdmin(admin.uid);
    if (!mounted) return;
    ref.invalidate(adminUsersProvider);
    _showSnack(
      success
          ? 'Admin access revoked.'
          : ref.read(adminActionProvider.notifier).errorMessage ??
                'Unable to remove admin.',
    );
  }

  Future<void> _promoteToSuperAdmin(UserModel admin) async {
    final confirmed = await _confirm(
      title: 'Grant Super Admin Clearance?',
      message:
          '${admin.email} will receive critical platform controls, including maintenance mode and admin registry management.',
      destructive: false,
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(adminActionProvider.notifier)
        .promoteToSuperAdmin(admin.uid);
    if (!mounted) return;
    ref.invalidate(adminUsersProvider);
    _showSnack(
      success
          ? 'Super admin clearance granted.'
          : ref.read(adminActionProvider.notifier).errorMessage ??
                'Unable to promote admin.',
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required bool destructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              destructive ? Icons.warning_rounded : Icons.info_outline_rounded,
              color: destructive ? Colors.redAccent : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.admin,
    required this.busy,
    required this.onBan,
    required this.onSuspend,
    required this.onRestore,
    required this.onPromoteToSuperAdmin,
    required this.onRemove,
  });

  final UserModel admin;
  final bool busy;
  final VoidCallback onBan;
  final VoidCallback onSuspend;
  final VoidCallback onRestore;
  final VoidCallback onPromoteToSuperAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = _isSuperAdminRole(admin.primaryRole);
    final isProtected = admin.isSystemOwner;
    final isBlocked =
        admin.status.toLowerCase() == 'banned' ||
        admin.status.toLowerCase() == 'suspended';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: isProtected ? 0.8 : 0.3,
          ),
        ),
        boxShadow: [
          if (isProtected)
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: -2,
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarWidget(
                imageUrl: admin.profileImage,
                radius: 28,
                fallbackText: _initials(admin.fullName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.fullName.isEmpty ? 'Unnamed Admin' : admin.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      admin.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ClearanceBadge(isSuper: isSuperAdmin),
                        if (isProtected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'SYSTEM OWNER',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isBlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              admin.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (!isSuperAdmin && !isBlocked)
                OutlinedButton.icon(
                  onPressed: busy || isProtected ? null : onPromoteToSuperAdmin,
                  icon: const Icon(Icons.upgrade_rounded, size: 18),
                  label: const Text('Promote'),
                ),
              if (!isSuperAdmin && !isBlocked)
                OutlinedButton(
                  onPressed: busy || isProtected ? null : onSuspend,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                  child: const Text('Suspend'),
                ),
              if (!isSuperAdmin && !isBlocked)
                FilledButton.tonal(
                  onPressed: busy || isProtected ? null : onBan,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.5),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Ban'),
                ),
              if (!isSuperAdmin && isBlocked)
                FilledButton.icon(
                  onPressed: busy || isProtected ? null : onRestore,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Restore'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (!isSuperAdmin)
                FilledButton.icon(
                  onPressed: busy || isProtected ? null : onRemove,
                  icon: const Icon(Icons.person_remove_alt_1_rounded, size: 18),
                  label: const Text('Revoke'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 20), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ClearanceBadge extends StatelessWidget {
  const _ClearanceBadge({required this.isSuper});
  final bool isSuper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isSuper ? Colors.redAccent : Colors.blue).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isSuper ? Colors.redAccent : Colors.blue).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Text(
        isSuper ? 'SUPER CLEARANCE' : 'ADMIN CLEARANCE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: isSuper ? Colors.redAccent : Colors.blue,
        ),
      ),
    );
  }
}

class _EmptyAdmins extends StatelessWidget {
  const _EmptyAdmins();

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
              Icons.admin_panel_settings_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Registry is Empty',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Promote an existing user to create the first administrator.',
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

String _statusVerb(String status) {
  return switch (status) {
    'active' => 'Restore',
    'suspended' => 'Suspend',
    'banned' => 'Ban',
    _ => 'Update',
  };
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

bool _isSuperAdminRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '') ==
      'superadmin';
}
