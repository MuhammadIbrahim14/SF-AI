import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/settings/providers/language_provider.dart';
import '../features/settings/providers/settings_providers.dart';
import '../features/admin/sie/admin_sie_scope.dart';
import '../features/company/sie/company_sie_scope.dart';
import '../features/freelancer/sie/freelancer_sie_scope.dart';
import '../features/student/sie/student_sie_scope.dart';
import '../features/student/sie/sie_visual_shell.dart';
import '../features/teacher/sie/teacher_sie_scope.dart';
import '../providers/theme_provider.dart';
import '../shared/widgets/animated_theme_switcher.dart';
import 'router/app_router.dart';

/// SkillForge AI — Root Application Widget
/// Configures MaterialApp.router with theme switching and GoRouter.
class SkillForgeApp extends ConsumerWidget {
  const SkillForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final themeSettings = ref.watch(themeSettingsStreamProvider).value;
    final motionSettings = ref.watch(motionSettingsStreamProvider).value;
    final locale = ref.watch(currentLocaleProvider);

    // Check if admin forced a theme mode
    final effectiveThemeMode = (themeSettings?.themeMode == 'dark')
        ? ThemeMode.dark
        : (themeSettings?.themeMode == 'light')
        ? ThemeMode.light
        : themeMode;

    final isDark = effectiveThemeMode == ThemeMode.dark;

    final overlayStyle = isDark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF080D1A),
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFFF0F2F8),
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    final motionEnabled =
        motionSettings?.animationsEnabled != false &&
        motionSettings?.reducedMotion != true;
    final speed = (motionSettings?.animationSpeed ?? 1.0).clamp(0.1, 3.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp.router(
        title: 'SkillForge AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(themeSettings),
        darkTheme: AppTheme.darkTheme(themeSettings),
        themeMode: effectiveThemeMode,
        // Kept shorter than the switcher's exit stage so the palette has fully
        // flipped by the time the new panel slides back into view.
        themeAnimationDuration: motionEnabled
            ? Duration(milliseconds: (420 / speed).round())
            : Duration.zero,
        themeAnimationCurve: Curves.easeInOutCubic,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(disableAnimations: !motionEnabled),
            child: AnimatedThemeSwitcher(
              isDark: isDark,
              enabled: motionEnabled,
              duration: Duration(milliseconds: (1100 / speed).round()),
              child: AdminSieRouteListener(
                child: CompanySieRouteListener(
                  child: FreelancerSieRouteListener(
                    child: TeacherSieRouteListener(
                      child: StudentSieRouteListener(
                        child: SieVisualShell(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        routerConfig: router,
        locale: locale,
        supportedLocales: const [Locale('en', ''), Locale('ur', '')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
