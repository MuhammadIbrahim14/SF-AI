import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../settings/providers/settings_providers.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/theme_orb_button.dart';
import '../../../shared/widgets/animated_scifi_background.dart';

/// SkillForge AI — Premium Home / Landing Page
/// SaaS-style landing page outlining the entire platform ecosystem.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _floatingController;
  late final AnimationController _pulseController;
  late final ScrollController _scrollController;

  // Scroll-triggered animation values
  double _scrollOffset = 0;
  final double _maxWidth = 1100.0;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() => _scrollOffset = _scrollController.offset);
      });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Coming Soon',
              style: TextStyle(color: AppColors.primary),
            ),
          ],
        ),
        content: Text('$title is currently under development. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fallback if providers aren't strictly required but they are present in imports
    final themeSettings = ref.watch(themeSettingsStreamProvider).value;
    final isThemeForced =
        themeSettings?.themeMode == 'dark' ||
        themeSettings?.themeMode == 'light';

    return Scaffold(
      body: AnimatedSciFiBackground(
        child: Stack(
          children: [
            // Main scrollable content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom App Bar
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildAppBar(context, isDark, isThemeForced),
                    ),
                  ),
                ),

                // 1. Hero Section
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildHeroSection(context, isDark),
                    ),
                  ),
                ),

                // 2. Platform Overview
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildPlatformOverview(context, isDark),
                    ),
                  ),
                ),

                // 5. How It Works Section
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildHowItWorks(context, isDark),
                    ),
                  ),
                ),

                // 3. Hire Freelancers Section
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildHireFreelancers(context, isDark),
                    ),
                  ),
                ),

                // 4. Download Section - REMOVED (already available in app download)
                // Keeping _buildDownloadSection method for backward compatibility
                // but not rendering it on home screen

                // 6. Trust & Security
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildTrustAndSecurity(context, isDark),
                    ),
                  ),
                ),

                // 7. User Guide
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildUserGuide(context, isDark),
                    ),
                  ),
                ),

                // 8. Preferences Section
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildPreferences(context, isDark),
                    ),
                  ),
                ),

                // 9. Footer Section
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: _buildFooter(context, isDark),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),

            _ScrollToTopButton(
              visible: _scrollOffset > 520,
              onTap: _scrollToTop,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context, bool isDark, bool isThemeForced) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'SkillForge AI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                ThemeOrbButton(
                  isDark: isDark,
                  isManaged: isThemeForced,
                  onToggle: isThemeForced
                      ? null
                      : () => ref.read(themeNotifierProvider.notifier).toggle(),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.goNamed(RouteNames.login),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => context.goNamed(RouteNames.signup),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Get Started'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. HERO SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeroSection(BuildContext context, bool isDark) {
    final heroFade = CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    final heroSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _heroController,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return FadeTransition(
      opacity: heroFade,
      child: SlideTransition(
        position: heroSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'The Ultimate Career Ecosystem',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isDark
                      ? [Colors.white, const Color(0xFFB0C4FF)]
                      : [AppColors.primary, AppColors.secondary],
                ).createShader(bounds),
                child: Text(
                  'SkillForge AI',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -1.5,
                    fontSize: isMobile ? 48 : 72,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Learn skills. Prove them. Build your resume. Get hired.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  fontSize: isMobile ? 18 : 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  PrimaryButton(
                    text: 'Get Started',
                    icon: Icons.rocket_launch_rounded,
                    onPressed: () => context.goNamed(RouteNames.signup),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.pushNamed(RouteNames.downloads),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download App'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. PLATFORM OVERVIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPlatformOverview(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Column(
        children: [
          _SectionHeader(
            title: 'One Platform. Four Ecosystems.',
            subtitle:
                'SkillForge AI brings learning and hiring into a single verified environment.',
            isDark: isDark,
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _EcosystemCard(
                    title: 'Students',
                    description:
                        'Take courses, practice with AI assignments, pass grand tests, and automatically build a smart resume verified by the blockchain.',
                    icon: Icons.school_rounded,
                    color: AppColors.primary,
                    width: isDesktop
                        ? (constraints.maxWidth / 2) - 10
                        : double.infinity,
                    isDark: isDark,
                  ),
                  _EcosystemCard(
                    title: 'Teachers',
                    description:
                        'Create engaging courses, assign AI-graded tasks, issue certificates, and build a powerful teaching portfolio.',
                    icon: Icons.cast_for_education_rounded,
                    color: AppColors.secondary,
                    width: isDesktop
                        ? (constraints.maxWidth / 2) - 10
                        : double.infinity,
                    isDark: isDark,
                  ),
                  _EcosystemCard(
                    title: 'Companies',
                    description:
                        'Post jobs and match instantly with candidates whose skills are cryptographically verified through our platform tests.',
                    icon: Icons.business_rounded,
                    color: AppColors.success,
                    width: isDesktop
                        ? (constraints.maxWidth / 2) - 10
                        : double.infinity,
                    isDark: isDark,
                  ),
                  _EcosystemCard(
                    title: 'Freelancers',
                    description:
                        'Showcase verified skill scores, complete client requests, and guarantee your abilities to global employers.',
                    icon: Icons.work_rounded,
                    color: AppColors.accent,
                    width: isDesktop
                        ? (constraints.maxWidth / 2) - 10
                        : double.infinity,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. HIRE FREELANCERS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHireFreelancers(BuildContext context, bool isDark) {
    final services = [
      'Flutter App Development',
      'Website Development',
      'UI/UX Design',
      'Firebase Integration',
      'Admin Dashboards',
      'Automation Tools',
      'Portfolio Websites',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: _GlassBox(
        isDark: isDark,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            _SectionHeader(
              title: 'Hire Verified Freelancers',
              subtitle:
                  'Need a project done? Request services directly from SkillForge verified top-tier talent.',
              isDark: isDark,
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: services
                  .map(
                    (service) => Chip(
                      label: Text(
                        service,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 40),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      context.goNamed(RouteNames.servicesMarketplace),
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Request a Project'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.goNamed(RouteNames.freelancerDirectory),
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text('Hire Verified Talent'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. DOWNLOAD SECTION
  // ═══════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════
  // 5. HOW IT WORKS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHowItWorks(BuildContext context, bool isDark) {
    final steps = [
      {'title': 'Learn', 'icon': Icons.menu_book_rounded},
      {'title': 'Practice', 'icon': Icons.code_rounded},
      {'title': 'Grand Test', 'icon': Icons.fact_check_rounded},
      {'title': 'Certificate', 'icon': Icons.workspace_premium_rounded},
      {'title': 'Smart Resume', 'icon': Icons.document_scanner_rounded},
      {'title': 'Job Match', 'icon': Icons.handshake_rounded},
      {'title': 'Interview', 'icon': Icons.event_available_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Column(
        children: [
          _SectionHeader(
            title: 'How It Works',
            subtitle:
                'A seamless pipeline from zero knowledge to getting hired.',
            isDark: isDark,
          ),
          const SizedBox(height: 40),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 24,
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index % 2 != 0) {
                return Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white30 : Colors.black26,
                  size: 16,
                );
              }
              final stepIndex = index ~/ 2;
              final step = steps[stepIndex];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      step['icon'] as IconData,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. TRUST & SECURITY
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTrustAndSecurity(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: _GlassBox(
        isDark: isDark,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            _SectionHeader(
              title: 'Built on Trust & Security',
              subtitle:
                  'Enterprise-grade security protecting your data, skills, and identity.',
              isDark: isDark,
            ),
            const SizedBox(height: 40),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: [
                _TrustBadge(
                  icon: Icons.lock_rounded,
                  title: 'App Lock',
                  isDark: isDark,
                ),
                _TrustBadge(
                  icon: Icons.verified_rounded,
                  title: 'Verified Skills',
                  isDark: isDark,
                ),
                _TrustBadge(
                  icon: Icons.security_rounded,
                  title: 'Secure Data',
                  isDark: isDark,
                ),
                _TrustBadge(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Authentic Certificates',
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.goNamed(RouteNames.privacyPolicy),
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  onPressed: () => context.goNamed(RouteNames.termsOfService),
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: () =>
                      context.goNamed(RouteNames.accountDeletionPolicy),
                  child: const Text('Account Deletion'),
                ),
                TextButton(
                  onPressed: () =>
                      context.goNamed(RouteNames.returnRefundPolicy),
                  child: const Text('Return & Refund'),
                ),
                TextButton(
                  onPressed: () =>
                      context.goNamed(RouteNames.shippingServicePolicy),
                  child: const Text('Shipping & Service'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. USER GUIDE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildUserGuide(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Column(
        children: [
          _SectionHeader(
            title: 'Documentation & Guides',
            subtitle: 'Learn how to maximize your success on SkillForge AI.',
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _GuideCard(
                title: 'Student Guide',
                icon: Icons.menu_book,
                isDark: isDark,
                onTap: () => _showComingSoon(context, 'Student Guide'),
              ),
              _GuideCard(
                title: 'Teacher Guide',
                icon: Icons.co_present,
                isDark: isDark,
                onTap: () => _showComingSoon(context, 'Teacher Guide'),
              ),
              _GuideCard(
                title: 'Company Guide',
                icon: Icons.business_center,
                isDark: isDark,
                onTap: () => _showComingSoon(context, 'Company Guide'),
              ),
              _GuideCard(
                title: 'Freelancer Guide',
                icon: Icons.laptop_mac,
                isDark: isDark,
                onTap: () => _showComingSoon(context, 'Freelancer Guide'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. PREFERENCES
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPreferences(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Column(
        children: [
          Text(
            'Future-Ready Features',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              Chip(
                label: const Text('Dark & Light Modes'),
                avatar: const Icon(Icons.brightness_6, size: 16),
              ),
              Chip(
                label: const Text('Multi-language Support'),
                avatar: const Icon(Icons.language, size: 16),
              ),
              Chip(
                label: const Text('Motion Preferences'),
                avatar: const Icon(Icons.animation, size: 16),
              ),
              Chip(
                label: const Text('Accessibility Friendly'),
                avatar: const Icon(Icons.accessibility_new, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. FOOTER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.cardBorder : AppColors.lightCardBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'SkillForge AI',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              InkWell(
                onTap: () => context.goNamed(RouteNames.privacyPolicy),
                child: const Text('Privacy Policy'),
              ),
              InkWell(
                onTap: () => context.goNamed(RouteNames.termsOfService),
                child: const Text('Terms of Service'),
              ),
              InkWell(
                onTap: () => context.goNamed(RouteNames.accountDeletionPolicy),
                child: const Text('Account Deletion'),
              ),
              InkWell(
                onTap: () => context.goNamed(RouteNames.returnRefundPolicy),
                child: const Text('Return & Refund'),
              ),
              InkWell(
                onTap: () => context.goNamed(RouteNames.shippingServicePolicy),
                child: const Text('Shipping & Service'),
              ),
              InkWell(
                onTap: () => context.pushNamed(RouteNames.contactUs),
                child: const Text('Contact Support'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Version: v1.0.0-beta  |  © ${DateTime.now().year} SkillForge AI. All rights reserved.',
            style: TextStyle(
              color: isDark ? Colors.white30 : Colors.black38,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EcosystemCard extends StatelessWidget {
  const _EcosystemCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.width,
    required this.isDark,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double width;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _GlassBox(
        isDark: isDark,
        borderRadius: 24.0,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.title,
    required this.isDark,
  });
  final IconData icon;
  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.cardLight : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.success, size: 32),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 160,
        child: _GlassBox(
          isDark: isDark,
          borderRadius: 16.0,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollToTopButton extends StatefulWidget {
  const _ScrollToTopButton({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  State<_ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<_ScrollToTopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coreColor = isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFFD700);

    return Positioned(
      right: 24,
      bottom: 24,
      child: SafeArea(
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            opacity: widget.visible ? 1 : 0,
            child: Tooltip(
              message: 'Scroll to top',
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) {
                  setState(() => _pressed = false);
                  widget.onTap();
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: widget.visible ? (_pressed ? 0.92 : 1) : 0.82,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final glow = 0.4 + (_pulseController.value * 0.3);
                      return Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF060A18)
                              : const Color(0xFFF5F7FC),
                          boxShadow: [
                            BoxShadow(
                              color: coreColor.withValues(alpha: glow),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(
                            color: coreColor.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: coreColor,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({
    required this.child,
    this.padding,
    this.borderRadius = 32.0,
    required this.isDark,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
