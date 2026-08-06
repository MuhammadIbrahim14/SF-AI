import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/utils/app_logger.dart';
import '../../settings/data/models/theme_settings_model.dart';
import '../../settings/data/repositories/settings_repository_impl.dart';
import '../../settings/providers/settings_providers.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminThemeSettingsScreen extends ConsumerStatefulWidget {
  const AdminThemeSettingsScreen({super.key});

  @override
  ConsumerState<AdminThemeSettingsScreen> createState() =>
      _AdminThemeSettingsScreenState();
}

class _AdminThemeSettingsScreenState
    extends ConsumerState<AdminThemeSettingsScreen> {
  ThemeSettingsModel? _draft;
  bool _initialized = false;
  bool _isSaving = false;

  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _accentController = TextEditingController();
  final _backgroundController = TextEditingController();
  final _surfaceController = TextEditingController();

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _accentController.dispose();
    _backgroundController.dispose();
    _surfaceController.dispose();
    super.dispose();
  }

  void _syncControllers(ThemeSettingsModel settings) {
    if (_primaryController.text != (settings.primaryColor ?? '')) {
      _primaryController.text = settings.primaryColor ?? '';
    }
    if (_secondaryController.text != (settings.secondaryColor ?? '')) {
      _secondaryController.text = settings.secondaryColor ?? '';
    }
    if (_accentController.text != (settings.accentColor ?? '')) {
      _accentController.text = settings.accentColor ?? '';
    }
    if (_backgroundController.text != (settings.backgroundColor ?? '')) {
      _backgroundController.text = settings.backgroundColor ?? '';
    }
    if (_surfaceController.text != (settings.surfaceColor ?? '')) {
      _surfaceController.text = settings.surfaceColor ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(themeSettingsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'Brand & Theme Studio',
      subtitle: 'Manage core design tokens, colors, and layout aesthetics.',
      currentPath: RoutePaths.adminThemeSettings,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _initialized = false;
            ref.invalidate(themeSettingsStreamProvider);
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
                'Unable to load theme engine',
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
            _draft = settings ?? const ThemeSettingsModel();
            _syncControllers(_draft!);
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
                      title: 'Global Branding Colors',
                      description:
                          'Provide 6 or 8 digit HEX codes. Leave blank to inherit system defaults.',
                      icon: Icons.palette_rounded,
                      color: Colors.blueAccent,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final primary = _ColorSwatchInput(
                              label: 'Primary',
                              controller: _primaryController,
                              onChanged: (val) =>
                                  _update(draft.copyWith(primaryColor: val)),
                            );
                            final secondary = _ColorSwatchInput(
                              label: 'Secondary',
                              controller: _secondaryController,
                              onChanged: (val) =>
                                  _update(draft.copyWith(secondaryColor: val)),
                            );
                            final accent = _ColorSwatchInput(
                              label: 'Accent',
                              controller: _accentController,
                              onChanged: (val) =>
                                  _update(draft.copyWith(accentColor: val)),
                            );

                            if (constraints.maxWidth < 800) {
                              return Column(
                                children: [
                                  primary,
                                  const SizedBox(height: 16),
                                  secondary,
                                  const SizedBox(height: 16),
                                  accent,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: primary),
                                const SizedBox(width: 16),
                                Expanded(child: secondary),
                                const SizedBox(width: 16),
                                Expanded(child: accent),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final background = _ColorSwatchInput(
                              label: 'Background',
                              controller: _backgroundController,
                              onChanged: (val) =>
                                  _update(draft.copyWith(backgroundColor: val)),
                            );
                            final surface = _ColorSwatchInput(
                              label: 'Surface',
                              controller: _surfaceController,
                              onChanged: (val) =>
                                  _update(draft.copyWith(surfaceColor: val)),
                            );

                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  background,
                                  const SizedBox(height: 16),
                                  surface,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: background),
                                const SizedBox(width: 16),
                                Expanded(child: surface),
                                const Spacer(),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Shapes & Materials',
                      description:
                          'Configure borders, elevation, and glassmorphism support.',
                      icon: Icons.format_shapes_rounded,
                      color: Colors.purpleAccent,
                      children: [
                        _SliderControl(
                          label: 'Border Radius',
                          value: draft.borderRadius ?? 20.0,
                          min: 0,
                          max: 40,
                          suffix: 'px',
                          onChanged: (val) =>
                              _update(draft.copyWith(borderRadius: val)),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        _SliderControl(
                          label: 'Card Elevation',
                          value: draft.cardElevation ?? 0.0,
                          min: 0,
                          max: 20,
                          suffix: 'dp',
                          onChanged: (val) =>
                              _update(draft.copyWith(cardElevation: val)),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.blur_on_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Glassmorphism Surfaces',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Enable translucent premium materials where supported.',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Switch.adaptive(
                              value: draft.glassmorphismEnabled,
                              onChanged: (value) => _update(
                                draft.copyWith(glassmorphismEnabled: value),
                              ),
                              activeThumbColor: Colors.purpleAccent,
                              activeTrackColor: Colors.purpleAccent.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Environment Mode',
                      description:
                          'Force the platform into a specific appearance, or respect user preference.',
                      icon: Icons.brightness_6_rounded,
                      color: Colors.orange,
                      children: [
                        DropdownButtonFormField<String?>(
                          initialValue: draft.themeMode ?? 'system',
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF161616)
                                : Colors.white,
                          ),
                          icon: const Icon(Icons.expand_more_rounded),
                          items: const [
                            DropdownMenuItem(
                              value: 'system',
                              child: Row(
                                children: [
                                  Icon(Icons.brightness_auto_rounded, size: 18),
                                  SizedBox(width: 12),
                                  Text(
                                    'Respect User System Setting',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'light',
                              child: Row(
                                children: [
                                  Icon(Icons.light_mode_rounded, size: 18),
                                  SizedBox(width: 12),
                                  Text(
                                    'Force Light Mode',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'dark',
                              child: Row(
                                children: [
                                  Icon(Icons.dark_mode_rounded, size: 18),
                                  SizedBox(width: 12),
                                  Text(
                                    'Force Dark Mode',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              _update(draft.copyWith(themeMode: val)),
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
                          'Save Theme Engine',
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

  void _update(ThemeSettingsModel value) {
    setState(() => _draft = value);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;

    final colors = [
      draft.primaryColor,
      draft.secondaryColor,
      draft.accentColor,
      draft.backgroundColor,
      draft.surfaceColor,
    ];
    final invalidColor = colors.any((color) {
      final value = color?.trim() ?? '';
      return value.isNotEmpty &&
          !RegExp(r'^#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value);
    });
    if (invalidColor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use valid 6 or 8 digit HEX color values.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final adminId = ref.read(authStateProvider).value?.uid;
      if (adminId == null) throw StateError('Administrator is not signed in.');
      await ref
          .read(settingsRepositoryProvider)
          .updateThemeSettings(draft, adminId: adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Theme engine settings published.')),
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

class _ColorSwatchInput extends StatelessWidget {
  const _ColorSwatchInput({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = controller.text.trim();
    Color? parsedColor;
    if (text.isNotEmpty &&
        RegExp(r'^#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(text)) {
      try {
        parsedColor = Color(
          int.parse(text.replaceAll('#', ''), radix: 16),
        ).withAlpha(255);
      } catch (_) {
        AppLogger.debug('Theme color preview could not be parsed.');
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  parsedColor ??
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: parsedColor == null
                ? Icon(
                    Icons.format_color_reset_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'e.g. #FF5500',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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

class _SliderControl extends StatelessWidget {
  const _SliderControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${value.toStringAsFixed(1)}$suffix',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
