import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A reusable cinematic background featuring organic floating particles
/// and study-themed holographic icons.
class CinematicBackground extends StatefulWidget {
  const CinematicBackground({super.key, this.particlesEnabled = true});

  final bool particlesEnabled;

  @override
  State<CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<CinematicBackground>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _particleController;

  final _random = Random();
  late final List<_ParticleData> _particles;
  late final List<_FloatingIconData> _floatingIcons;

  @override
  void initState() {
    super.initState();

    _particles = List.generate(20, (_) => _ParticleData.random(_random));

    _floatingIcons = const [
      _FloatingIconData(Icons.menu_book_rounded, 0.15, 0.2, 0.0),
      _FloatingIconData(Icons.code_rounded, 0.75, 0.15, 0.3),
      _FloatingIconData(Icons.school_rounded, 0.1, 0.7, 0.5),
      _FloatingIconData(Icons.psychology_rounded, 0.8, 0.65, 0.7),
      _FloatingIconData(Icons.lightbulb_rounded, 0.5, 0.85, 0.2),
      _FloatingIconData(Icons.edit_rounded, 0.85, 0.4, 0.4),
      _FloatingIconData(Icons.science_rounded, 0.2, 0.45, 0.6),
      _FloatingIconData(Icons.auto_stories_rounded, 0.6, 0.3, 0.8),
    ];

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

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
    if (!widget.particlesEnabled) return const SizedBox.expand();

    final size = MediaQuery.of(context).size;

    return Stack(
      children: [..._buildParticles(size), ..._buildFloatingIcons(size)],
    );
  }

  List<Widget> _buildFloatingIcons(Size size) {
    return _floatingIcons.map((icon) {
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, _) {
          final phase = icon.phase;
          final yOffset = sin((_floatController.value + phase) * pi * 2) * 15;
          final xOffset = cos((_floatController.value + phase) * pi * 2) * 8;
          final opacity =
              0.06 + sin((_floatController.value + phase) * pi) * 0.04;

          return Positioned(
            left: icon.x * size.width + xOffset,
            top: icon.y * size.height + yOffset,
            child: Opacity(
              opacity: opacity,
              child: Icon(icon.icon, size: 32, color: AppColors.primary),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildParticles(Size size) {
    return _particles.map((p) {
      return AnimatedBuilder(
        animation: _particleController,
        builder: (context, _) {
          final progress = (_particleController.value + p.delay) % 1.0;
          final y = size.height * (1 - progress);
          final x = p.x * size.width + sin(progress * pi * 2 * p.speed) * 30;
          final opacity = sin(progress * pi) * 0.4 * p.opacity;

          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: p.size,
              height: p.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.color.withValues(alpha: opacity.clamp(0.0, 1.0)),
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
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      Colors.white,
    ];
    return _ParticleData(
      x: rng.nextDouble(),
      delay: rng.nextDouble(),
      speed: 0.5 + rng.nextDouble() * 1.5,
      size: 2 + rng.nextDouble() * 4,
      opacity: 0.3 + rng.nextDouble() * 0.7,
      color: colors[rng.nextInt(colors.length)],
    );
  }
}
