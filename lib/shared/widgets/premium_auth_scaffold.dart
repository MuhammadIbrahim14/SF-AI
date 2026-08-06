import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_providers.dart';
import 'theme_orb_button.dart';
import 'cinematic_background.dart';

class PremiumAuthScaffold extends ConsumerStatefulWidget {
  final Widget child;
  final String title;
  final String subtitle;
  final bool isLoading;
  final String loadingMessage;

  const PremiumAuthScaffold({
    super.key,
    required this.child,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    this.loadingMessage = 'Establishing connection...',
  });

  @override
  ConsumerState<PremiumAuthScaffold> createState() =>
      _PremiumAuthScaffoldState();
}

class _PremiumAuthScaffoldState extends ConsumerState<PremiumAuthScaffold> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final themeSettings = ref.watch(themeSettingsStreamProvider).value;
    final isThemeForced =
        themeSettings?.themeMode == 'dark' ||
        themeSettings?.themeMode == 'light';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Cinematic Background
          Positioned.fill(child: CinematicBackground(particlesEnabled: true)),

          // Main Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                return Row(
                  children: [
                    // Left Side: Massive HUD Typography (Only on larger screens)
                    if (isDesktop)
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 64.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    colorScheme.primary.withValues(alpha: 0.9),
                                    colorScheme.tertiary.withValues(alpha: 0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Text(
                                  'SKILL\nFORGE\nCORE',
                                  style: TextStyle(
                                    fontSize: 140,
                                    height: 0.85,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                width: 80,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary,
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'AI-DRIVEN FREELANCING MAINFRAME\nCONNECTION PROTOCOL INITIATED.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Right Side / Center: The 3D Form
                    Expanded(
                      flex: 6,
                      child: Center(
                        child: Transform(
                          alignment: FractionalOffset.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // perspective
                            ..rotateY(
                              isDesktop ? -0.12 : 0,
                            ), // Slight tilt on desktop
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(
                                          0xFF06080A,
                                        ).withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.4,
                                          )
                                        : colorScheme.primary.withValues(
                                            alpha: 0.6,
                                          ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(
                                        alpha: isDark ? 0.2 : 0.1,
                                      ),
                                      blurRadius: 100,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 40,
                                      sigmaY: 40,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 48,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Top Section: Animated AI Orb
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: ThemeOrbButton(
                                              isDark: isDark,
                                              isManaged: isThemeForced,
                                              onToggle:
                                                  null, // Purely visual in auth screen
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Text(
                                            widget.title.toUpperCase(),
                                            textAlign: TextAlign.left,
                                            style: theme
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                  height: 1.1,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            widget.subtitle,
                                            textAlign: TextAlign.left,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  height: 1.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          const SizedBox(height: 48),

                                          // Form Content
                                          widget.child,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Loading Overlay
          if (widget.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          widget.loadingMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
