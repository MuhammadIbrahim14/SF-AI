import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../settings/providers/settings_providers.dart';
import '../../../shared/widgets/animated_scifi_background.dart';

/// SkillForge AI — Splash Screen
/// Premium launch screen with animated background,
/// and typing animation for tagline.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Main logo animation
  late final AnimationController _logoController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  // Typing animation
  late final AnimationController _typingController;

  // Shimmer ring
  late final AnimationController _ringController;

  final String _tagline = 'Empowering the future of work';

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Typing effect
    _typingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _tagline.length * 60),
    );

    // Ring shimmer
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Stagger the animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _typingController.forward();
    });

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    // Navigate to home — redirect guard handles the rest
    context.go(RoutePaths.home);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _typingController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state so it loads in the background
    ref.watch(authStateProvider);
    final motionSettings = ref.watch(motionSettingsStreamProvider).value;
    final shimmerEnabled = motionSettings?.shimmerEnabled ?? true;

    return Scaffold(
      body: AnimatedSciFiBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Animated Ring + Logo ───────────
                      _buildAnimatedLogo(shimmerEnabled),
                      const SizedBox(height: 36),

                      // ─── App Name ──────────────────────
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFB0C4FF),
                            Colors.white,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'SkillForge AI',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Typing Tagline ────────────────
                      _buildTypingTagline(),

                      const SizedBox(height: 48),

                      // ─── Loading Dots ──────────────────
                      _buildLoadingDots(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ANIMATED LOGO with rotating ring
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAnimatedLogo(bool shimmerEnabled) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (context, _) {
              return Transform.rotate(
                angle: shimmerEnabled ? _ringController.value * pi * 2 : 0,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.transparent, width: 2),
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.0),
                        AppColors.primary.withValues(alpha: 0.5),
                        AppColors.accent.withValues(alpha: 0.3),
                        AppColors.secondary.withValues(alpha: 0.5),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Inner glow circle
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  blurRadius: 60,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 55,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TYPING TAGLINE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTypingTagline() {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, _) {
        final charCount = (_typingController.value * _tagline.length).floor();
        final displayText = _tagline.substring(0, charCount);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            // Blinking cursor
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, _) {
                final visible = (_ringController.value * 4).floor() % 2 == 0;
                return Opacity(
                  opacity: visible ? 1.0 : 0.0,
                  child: Text(
                    '|',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LOADING DOTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.33;
            final value = ((_ringController.value + delay) % 1.0);
            final opacity = (sin(value * pi)).clamp(0.2, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
