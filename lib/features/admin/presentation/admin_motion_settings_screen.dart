import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../settings/data/models/motion_settings_model.dart';
import '../../settings/data/repositories/settings_repository_impl.dart';
import '../../settings/providers/settings_providers.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminMotionSettingsScreen extends ConsumerStatefulWidget {
  const AdminMotionSettingsScreen({super.key});

  @override
  ConsumerState<AdminMotionSettingsScreen> createState() =>
      _AdminMotionSettingsScreenState();
}

class _AdminMotionSettingsScreenState
    extends ConsumerState<AdminMotionSettingsScreen> {
  MotionSettingsModel? _draft;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(motionSettingsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'Motion Engine',
      subtitle: 'Manage animations, shimmer, and platform rendering effects.',
      currentPath: RoutePaths.adminMotionSettings,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _initialized = false;
            ref.invalidate(motionSettingsStreamProvider);
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
                'Unable to load motion engine',
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
            _draft = settings ?? const MotionSettingsModel();
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
                      title: 'Core Rendering Engine',
                      description:
                          'Control foundational UI transitions and accessibility modes.',
                      icon: Icons.animation_rounded,
                      color: Colors.teal,
                      children: [
                        _EngineCard(
                          title: 'Global Animations',
                          description:
                              'Enable or disable all complex UI transitions and micro-interactions.',
                          icon: Icons.auto_awesome_motion_rounded,
                          value: draft.animationsEnabled,
                          onChanged: (val) =>
                              _update(draft.copyWith(animationsEnabled: val)),
                          activeColor: Colors.teal,
                        ),
                        const SizedBox(height: 16),
                        _EngineCard(
                          title: 'Reduced Motion (Accessibility)',
                          description:
                              'Force minimal animations for users sensitive to motion.',
                          icon: Icons.accessible_forward_rounded,
                          value: draft.reducedMotion,
                          onChanged: (val) =>
                              _update(draft.copyWith(reducedMotion: val)),
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Visual Effects',
                      description:
                          'Toggle decorative and loading states across the platform.',
                      icon: Icons.flare_rounded,
                      color: Colors.amber.shade700,
                      children: [
                        _EngineCard(
                          title: 'Shimmer Loading States',
                          description:
                              'Display skeleton animations while fetching remote data.',
                          icon: Icons.gradient_rounded,
                          value: draft.shimmerEnabled,
                          onChanged: (val) =>
                              _update(draft.copyWith(shimmerEnabled: val)),
                          activeColor: Colors.amber.shade700,
                        ),
                        const SizedBox(height: 16),
                        _EngineCard(
                          title: 'Background Particle Effects',
                          description:
                              'Render decorative particles on hero screens (high CPU usage).',
                          icon: Icons.bubble_chart_rounded,
                          value: draft.particlesEnabled,
                          onChanged: (val) =>
                              _update(draft.copyWith(particlesEnabled: val)),
                          activeColor: Colors.amber.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Performance Tuning',
                      description:
                          'Adjust the global timescale multiplier for all system animations.',
                      icon: Icons.speed_rounded,
                      color: Colors.redAccent,
                      children: [
                        _SpeedControl(
                          value: draft.animationSpeed,
                          onChanged: (val) =>
                              _update(draft.copyWith(animationSpeed: val)),
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
                          'Save Motion Engine',
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

  void _update(MotionSettingsModel value) {
    setState(() => _draft = value);
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
          .updateMotionSettings(draft, adminId: adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Motion engine settings published.')),
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

class _EngineCard extends StatelessWidget {
  const _EngineCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: isDark ? 0.15 : 0.05)
            : (isDark ? const Color(0xFF161616) : const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.5)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: value ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value
                  ? activeColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
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
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: value
                            ? activeColor
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        value ? 'ACTIVE' : 'IDLE',
                        style: TextStyle(
                          color: value
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
            activeTrackColor: activeColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _SpeedControl extends StatelessWidget {
  const _SpeedControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    String speedLabel = 'Normal';
    if (value < 0.8) speedLabel = 'Fast (Snappy)';
    if (value > 1.2) speedLabel = 'Slow (Dramatic)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Timescale Multiplier',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  speedLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${value.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: Colors.redAccent,
            inactiveTrackColor: Colors.redAccent.withValues(alpha: 0.1),
            thumbColor: Colors.redAccent,
            overlayColor: Colors.redAccent.withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: value,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
