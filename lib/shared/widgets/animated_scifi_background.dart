import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/settings/providers/settings_providers.dart';

/// A premium animated sci-fi background used across SkillForge AI.
/// Provides moving particles, floating icons, and a deep ambient gradient.
class AnimatedSciFiBackground extends ConsumerStatefulWidget {
  const AnimatedSciFiBackground({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AnimatedSciFiBackground> createState() =>
      _AnimatedSciFiBackgroundState();
}

class _AnimatedSciFiBackgroundState
    extends ConsumerState<AnimatedSciFiBackground>
    with TickerProviderStateMixin {
  // Floating icons animation
  late final AnimationController _floatController;

  // Particle system
  late final AnimationController _particleController;

  final _random = Random();
  late final List<_ParticleData> _particles;
  late final List<_FloatingIconData> _floatingIcons;

  @override
  void initState() {
    super.initState();

    // Generate particles
    _particles = List.generate(40, (_) => _ParticleData.random(_random));

    // Study material floating icons
    _floatingIcons = const [
      _FloatingIconData(Icons.menu_book_rounded, 0.15, 0.2, 0.0),
      _FloatingIconData(Icons.code_rounded, 0.75, 0.15, 0.3),
      _FloatingIconData(Icons.school_rounded, 0.1, 0.7, 0.5),
      _FloatingIconData(Icons.psychology_rounded, 0.8, 0.65, 0.7),
      _FloatingIconData(Icons.lightbulb_rounded, 0.5, 0.85, 0.2),
      _FloatingIconData(Icons.edit_rounded, 0.85, 0.4, 0.4),
      _FloatingIconData(Icons.science_rounded, 0.2, 0.45, 0.6),
      _FloatingIconData(Icons.auto_stories_rounded, 0.6, 0.3, 0.8),
      // Additional icons for more density
      _FloatingIconData(Icons.calculate_rounded, 0.4, 0.1, 0.1),
      _FloatingIconData(Icons.brush_rounded, 0.9, 0.8, 0.9),
      _FloatingIconData(Icons.monitor_rounded, 0.3, 0.9, 0.4),
      _FloatingIconData(Icons.language_rounded, 0.7, 0.5, 0.6),
      _FloatingIconData(Icons.business_center_rounded, 0.15, 0.4, 0.2),
      _FloatingIconData(Icons.trending_up_rounded, 0.85, 0.25, 0.8),
      _FloatingIconData(Icons.emoji_objects_rounded, 0.45, 0.6, 0.3),
      _FloatingIconData(Icons.architecture_rounded, 0.25, 0.85, 0.7),
    ];

    // Floating icons
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionSettings = ref.watch(motionSettingsStreamProvider).value;
    final particlesEnabled = motionSettings?.particlesEnabled ?? true;

    return Stack(
      children: [
        // Background Base Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF040810),
                        const Color(0xFF0A0F1F),
                        const Color(0xFF0E142A),
                      ]
                    : [
                        const Color(0xFFDCE4FF),
                        const Color(0xFFEFE8FF),
                        const Color(0xFFD6F6FF),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        // Particle System
        if (particlesEnabled) ..._buildParticles(size, isDark),

        // Floating Study Icons
        if (particlesEnabled) ..._buildFloatingIcons(size, isDark),

        // Main Foreground Content
        Positioned.fill(child: widget.child),
      ],
    );
  }

  List<Widget> _buildFloatingIcons(Size size, bool isDark) {
    return _floatingIcons.map((icon) {
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, _) {
          final phase = icon.phase;
          final yOffset = sin((_floatController.value + phase) * pi * 2) * 15;
          final xOffset = cos((_floatController.value + phase) * pi * 2) * 8;
          final baseOpacity =
              0.12 + sin((_floatController.value + phase) * pi) * 0.08;

          return Positioned(
            left: icon.x * size.width + xOffset,
            top: icon.y * size.height + yOffset,
            child: Opacity(
              opacity: isDark ? baseOpacity : baseOpacity * 1.8,
              child: Icon(icon.icon, size: 32, color: AppColors.primary),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildParticles(Size size, bool isDark) {
    return _particles.map((p) {
      return AnimatedBuilder(
        animation: _particleController,
        builder: (context, _) {
          final progress = (_particleController.value + p.delay) % 1.0;
          final y = size.height * (1 - progress);
          final x = p.x * size.width + sin(progress * pi * 2 * p.speed) * 30;
          final opacity = sin(progress * pi) * 0.7 * p.opacity;

          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: p.size,
              height: p.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.color.withValues(
                  alpha: opacity.clamp(0.0, isDark ? 1.0 : 0.8),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class _FloatingIconData {
  const _FloatingIconData(this.icon, this.x, this.y, this.phase);
  final IconData icon;
  final double x;
  final double y;
  final double phase;
}

class _ParticleData {
  _ParticleData({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.color,
  });

  final double x;
  final double delay;
  final double speed;
  final double size;
  final double opacity;
  final Color color;

  factory _ParticleData.random(Random rng) {
    final colors = [
      AppColors.accent,
      const Color(0xFF80D8FF),
      const Color(0xFF40C4FF),
      const Color(0xFFB3E5FC),
    ];
    return _ParticleData(
      x: rng.nextDouble(),
      delay: rng.nextDouble(),
      speed: 0.5 + rng.nextDouble() * 1.5,
      size: 4 + rng.nextDouble() * 6,
      opacity: 0.3 + rng.nextDouble() * 0.7,
      color: colors[rng.nextInt(colors.length)],
    );
  }
}
