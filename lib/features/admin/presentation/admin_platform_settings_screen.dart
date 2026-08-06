import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/platform_settings.dart';
import '../../../providers/admin_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminPlatformSettingsScreen extends ConsumerStatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  ConsumerState<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends ConsumerState<AdminPlatformSettingsScreen> {
  PlatformSettings? _draft;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    final actionState = ref.watch(adminActionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'Platform Governance',
      subtitle: 'Manage access, registration, and verification policies.',
      currentPath: RoutePaths.adminSettings,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _initialized = false;
            ref.invalidate(platformSettingsProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load settings',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
        data: (settings) {
          if (!_initialized) {
            _draft = settings;
            _initialized = true;
          }
          final draft = _draft ?? settings;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    _SettingsGroup(
                      title: 'System Access & Safety',
                      description:
                          'Critical controls that immediately affect platform availability.',
                      icon: Icons.security_rounded,
                      color: Colors.redAccent,
                      children: [
                        _ToggleRow(
                          title: 'Maintenance Mode',
                          subtitle:
                              'Instantly lock out non-admin users from the platform.',
                          value: draft.maintenanceMode,
                          onChanged: (value) =>
                              _update(draft.copyWith(maintenanceMode: value)),
                          isDestructive: true,
                          icon: Icons.engineering_rounded,
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          title: 'SIE Engine (Global)',
                          subtitle:
                              'Master On/Off for Spatial Interaction Engine across all roles. '
                              'OFF arms the kill switch and blocks SIE bootstrap.',
                          value: draft.sieGloballyEnabled,
                          onChanged: (value) => _update(
                            draft.copyWith(sieGloballyEnabled: value),
                          ),
                          isDestructive: !draft.sieGloballyEnabled,
                          icon: Icons.gesture_rounded,
                        ),
                        if (draft.maintenanceMode) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Maintenance Announcement',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: ValueKey(draft.appAnnouncement),
                                  initialValue: draft.appAnnouncement,
                                  maxLines: 2,
                                  maxLength: 240,
                                  decoration: InputDecoration(
                                    hintText:
                                        'e.g., We are undergoing critical maintenance...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF161616)
                                        : Colors.white,
                                  ),
                                  onChanged: (value) => _update(
                                    draft.copyWith(appAnnouncement: value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Registration Policy',
                      description:
                          'Control who is allowed to create new accounts on the platform.',
                      icon: Icons.group_add_rounded,
                      color: Colors.blue,
                      children: [
                        _ToggleRow(
                          title: 'Global Registration',
                          subtitle: 'Allow new users to sign up.',
                          value: draft.registrationEnabled,
                          onChanged: (value) => _update(
                            draft.copyWith(registrationEnabled: value),
                          ),
                          icon: Icons.how_to_reg_rounded,
                        ),
                        const Divider(height: 32),
                        _ToggleRow(
                          title: 'Teacher Onboarding',
                          subtitle: 'Allow users to register as Teachers.',
                          value: draft.teacherSignupEnabled,
                          onChanged: draft.registrationEnabled
                              ? (value) => _update(
                                  draft.copyWith(teacherSignupEnabled: value),
                                )
                              : null,
                          icon: Icons.school_rounded,
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          title: 'Company Onboarding',
                          subtitle: 'Allow users to register as Companies.',
                          value: draft.companySignupEnabled,
                          onChanged: draft.registrationEnabled
                              ? (value) => _update(
                                  draft.copyWith(companySignupEnabled: value),
                                )
                              : null,
                          icon: Icons.business_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Verification Requirements',
                      description:
                          'Enforce manual review for specific roles before they are fully active.',
                      icon: Icons.verified_user_rounded,
                      color: Colors.green,
                      children: [
                        _ToggleRow(
                          title: 'Teacher Verification',
                          subtitle:
                              'Require admin review for new Teacher profiles.',
                          value: draft.requireTeacherVerification,
                          onChanged: (value) => _update(
                            draft.copyWith(requireTeacherVerification: value),
                          ),
                          icon: Icons.school_rounded,
                        ),
                        const Divider(height: 32),
                        _ToggleRow(
                          title: 'Company Verification',
                          subtitle:
                              'Require admin review for new Company profiles.',
                          value: draft.requireCompanyVerification,
                          onChanged: (value) => _update(
                            draft.copyWith(requireCompanyVerification: value),
                          ),
                          icon: Icons.business_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Legal & Governance',
                      description:
                          'Publish Privacy, Terms, Deletion, Refund, and Delivery policies for public trust and payment partners.',
                      icon: Icons.account_balance_rounded,
                      color: AppColors.primary,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              context.pushNamed(RouteNames.adminLegalEditor),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.16),
                                  AppColors.secondary.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  child: const Icon(
                                    Icons.gavel_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Policy Command Center',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Edit & publish all legal documents in one premium workspace.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'App Versioning',
                      description:
                          'Manage minimum version requirements and update notifications.',
                      icon: Icons.system_update_rounded,
                      color: Colors.purple,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final latest = _buildVersionField(
                              label: 'Latest Version',
                              value: draft.latestVersion,
                              onChanged: (value) =>
                                  _update(draft.copyWith(latestVersion: value)),
                            );
                            final minimum = _buildVersionField(
                              label: 'Minimum Supported',
                              value: draft.minimumSupportedVersion,
                              onChanged: (value) => _update(
                                draft.copyWith(minimumSupportedVersion: value),
                              ),
                            );

                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  latest,
                                  const SizedBox(height: 16),
                                  minimum,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: latest),
                                const SizedBox(width: 16),
                                Expanded(child: minimum),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Update Notification Prompt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('update-title-${draft.updateTitle}'),
                          initialValue: draft.updateTitle,
                          decoration: InputDecoration(
                            labelText: 'Notification Title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF161616)
                                : Colors.white,
                          ),
                          onChanged: (value) =>
                              _update(draft.copyWith(updateTitle: value)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey(
                            'update-message-${draft.updateMessage}',
                          ),
                          initialValue: draft.updateMessage,
                          maxLines: 2,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: 'Notification Message',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF161616)
                                : Colors.white,
                          ),
                          onChanged: (value) =>
                              _update(draft.copyWith(updateMessage: value)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (draft != settings)
                        Text(
                          'Unsaved changes',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: actionState.isLoading ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: actionState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: const Text(
                          'Save & Publish',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVersionField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.commit_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: isDark ? const Color(0xFF161616) : Colors.white,
      ),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
      ),
      onChanged: onChanged,
    );
  }

  void _update(PlatformSettings value) {
    setState(() => _draft = value);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final success = await ref
        .read(adminActionProvider.notifier)
        .savePlatformSettings(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Platform settings saved.'
              : ref.read(adminActionProvider.notifier).errorMessage ??
                    'Unable to save platform settings.',
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.isDestructive = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDestructive ? Colors.redAccent : Colors.green;
    return Opacity(
      opacity: onChanged == null ? 0.5 : 1.0,
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}
