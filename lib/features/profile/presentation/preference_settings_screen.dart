import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_role.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../settings/providers/settings_providers.dart';
import 'widgets/profile_navigation_card.dart';

class PreferenceSettingsScreen extends ConsumerWidget {
  const PreferenceSettingsScreen({super.key});

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
      title: 'Preferences Lab',
      subtitle: 'Tune appearance, language, and motion preferences.',
      showBackButton: true,
      scrollable: false,
      child: _CenteredSettingsList(
        children: [
          const _SettingsIntro(
            icon: Icons.tune_rounded,
            title: 'Make SkillForge yours',
            subtitle:
                'Choose the appearance and experience that works for you.',
          ),
          const SizedBox(height: 32),
          ProfileNavigationCard(
            index: 0,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Theme',
            subtitle: isForced
                ? '${isDark ? 'Dark' : 'Light'} appearance managed by admin'
                : '${isDark ? 'Dark' : 'Light'} appearance active',
            onTap: isForced
                ? null
                : () => ref.read(themeNotifierProvider.notifier).toggle(),
            trailing: Switch.adaptive(
              value: isDark,
              onChanged: isForced
                  ? null
                  : (_) => ref.read(themeNotifierProvider.notifier).toggle(),
            ),
          ),
          const SizedBox(height: 16),
          ProfileNavigationCard(
            index: 1,
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English',
            onTap: () => _showLanguageDialog(context),
          ),
          const SizedBox(height: 16),
          ProfileNavigationCard(
            index: 2,
            icon: Icons.animation_rounded,
            title: 'Motion & Effects',
            subtitle: 'Smooth transitions and animated cards are enabled',
            onTap: () => _showInformation(
              context,
              'Motion & Effects',
              'SkillForge currently uses the recommended motion settings.',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showLanguageDialog(BuildContext context) {
  return _showInformation(
    context,
    'Language',
    'English is currently the available application language.',
  );
}

Future<void> _showInformation(
  BuildContext context,
  String title,
  String message,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class _CenteredSettingsList extends StatelessWidget {
  const _CenteredSettingsList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600 ? 16.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: children),
            ),
          ),
        );
      },
    );
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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF121212)
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 36),
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
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              'SYS.PREF',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: colorScheme.onPrimary,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
