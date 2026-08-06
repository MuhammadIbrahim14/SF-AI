import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../settings/data/models/language_settings_model.dart';
import '../../settings/data/repositories/settings_repository_impl.dart';
import '../../settings/providers/settings_providers.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminLanguageSettingsScreen extends ConsumerStatefulWidget {
  const AdminLanguageSettingsScreen({super.key});

  @override
  ConsumerState<AdminLanguageSettingsScreen> createState() =>
      _AdminLanguageSettingsScreenState();
}

class _AdminLanguageSettingsScreenState
    extends ConsumerState<AdminLanguageSettingsScreen> {
  LanguageSettingsModel? _draft;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(languageSettingsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'Global Language Center',
      subtitle: 'Manage regional localization and supported languages.',
      currentPath: RoutePaths.adminLanguageSettings,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _initialized = false;
            ref.invalidate(languageSettingsStreamProvider);
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
                'Unable to load language settings',
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
            _draft = settings ?? const LanguageSettingsModel();
            _initialized = true;
          }
          final draft = _draft!;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    _SettingsGroup(
                      title: 'Platform Default Locale',
                      description:
                          'Select the primary language assigned to users upon registration.',
                      icon: Icons.language_rounded,
                      color: Colors.indigoAccent,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final en = _RegionCard(
                              code: 'en',
                              name: 'English',
                              region: 'United States',
                              isSelected: draft.defaultLanguage == 'en',
                              isEnabled: draft.enabledLanguages.contains('en'),
                              onSelect: () {
                                if (draft.enabledLanguages.contains('en')) {
                                  _update(
                                    draft.copyWith(defaultLanguage: 'en'),
                                  );
                                }
                              },
                            );
                            final ur = _RegionCard(
                              code: 'ur',
                              name: 'Urdu',
                              region: 'Pakistan',
                              isSelected: draft.defaultLanguage == 'ur',
                              isEnabled: draft.enabledLanguages.contains('ur'),
                              onSelect: () {
                                if (draft.enabledLanguages.contains('ur')) {
                                  _update(
                                    draft.copyWith(defaultLanguage: 'ur'),
                                  );
                                }
                              },
                            );

                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [en, const SizedBox(height: 16), ur],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: en),
                                const SizedBox(width: 16),
                                Expanded(child: ur),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Enabled Languages',
                      description:
                          'Languages available for users to select in their account settings.',
                      icon: Icons.checklist_rtl_rounded,
                      color: Colors.green,
                      children: [
                        _ToggleRow(
                          code: 'en',
                          name: 'English',
                          isEnabled: draft.enabledLanguages.contains('en'),
                          isDefault: draft.defaultLanguage == 'en',
                          onChanged: (enabled) =>
                              _toggleLanguage(draft, 'en', enabled),
                        ),
                        const Divider(height: 32),
                        _ToggleRow(
                          code: 'ur',
                          name: 'Urdu',
                          isEnabled: draft.enabledLanguages.contains('ur'),
                          isDefault: draft.defaultLanguage == 'ur',
                          onChanged: (enabled) =>
                              _toggleLanguage(draft, 'ur', enabled),
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
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: const Text(
                          'Save Language Settings',
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

  void _update(LanguageSettingsModel value) {
    setState(() => _draft = value);
  }

  void _toggleLanguage(
    LanguageSettingsModel draft,
    String language,
    bool enabled,
  ) {
    final languages = [...draft.enabledLanguages];
    if (enabled) {
      if (!languages.contains(language)) languages.add(language);
    } else {
      if (languages.length == 1 || draft.defaultLanguage == language) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The default language must remain enabled.'),
          ),
        );
        return;
      }
      languages.remove(language);
    }
    _update(draft.copyWith(enabledLanguages: languages));
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;

    setState(() => _isSaving = true);
    try {
      final adminId = ref.read(authStateProvider).value?.uid;
      if (adminId == null) throw StateError('Administrator is not signed in.');
      await ref
          .read(settingsRepositoryProvider)
          .updateLanguageSettings(draft, adminId: adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Language settings published.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.code,
    required this.name,
    required this.region,
    required this.isSelected,
    required this.isEnabled,
    required this.onSelect,
  });

  final String code;
  final String name;
  final String region;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onSelect : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.indigoAccent.withValues(alpha: isDark ? 0.2 : 0.05)
                  : (isDark
                        ? const Color(0xFF161616)
                        : const Color(0xFFFAFAFA)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.indigoAccent
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.indigoAccent
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        region,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.indigoAccent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.code,
    required this.name,
    required this.isEnabled,
    required this.isDefault,
    required this.onChanged,
  });

  final String code;
  final String name;
  final bool isEnabled;
  final bool isDefault;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: Colors.indigoAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isEnabled
                    ? 'Available for user selection'
                    : 'Hidden from user selection',
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
          value: isEnabled,
          onChanged: isDefault ? null : onChanged,
          activeThumbColor: Colors.green,
          activeTrackColor: Colors.green.withValues(alpha: 0.2),
        ),
      ],
    );
  }
}
