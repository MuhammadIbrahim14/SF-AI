import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';

import '../../../shared/widgets/sci_fi_input.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/premium_auth_scaffold.dart';
import '../../../app/router/route_names.dart';
import 'widgets/social_auth_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _staggerController;

  // Typing Effect Variables for Multi-Role Ecosystem
  int _roleIndex = 0;
  int _charIndex = 0;
  String _currentText = "";
  Timer? _typingTimer;

  final List<Map<String, String>> _ecosystemRoles = [
    {
      "role": "FREELANCER",
      "line":
          "Fetching freelancer... Offer services, manage orders, deliver client work.",
    },
    {
      "role": "STUDENT",
      "line":
          "Fetching student... Learn skills, complete projects, build career portfolio.",
    },
    {
      "role": "TEACHER / MENTOR",
      "line":
          "Fetching mentor... Create courses, guide learners, track class progress.",
    },
    {
      "role": "COMPANY / ENTERPRISE",
      "line":
          "Fetching company... Post jobs, evaluate talent, hire verified candidates.",
    },
    {
      "role": "CUSTOMER / CLIENT",
      "line":
          "Fetching customer... Request services, hire freelancers, review delivered work.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTypingEffect();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutExpo,
          ),
        );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _entranceController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _staggerController.forward();
    });
  }

  void _startTypingEffect() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      final fullText = _ecosystemRoles[_roleIndex]["line"]!;
      if (_charIndex < fullText.length) {
        setState(() {
          _currentText += fullText[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _charIndex = 0;
            _currentText = "";
            _roleIndex = (_roleIndex + 1) % _ecosystemRoles.length;
          });
          _startTypingEffect();
        });
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _entranceController.dispose();
    _staggerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!success && mounted) {
      final errorMsg =
          ref.read(authNotifierProvider.notifier).errorMessage ??
          'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleSocialLogin(_SocialAuthProvider provider) async {
    final accountType = _isCustomerMode(context)
        ? UserAccountType.customer
        : UserAccountType.professional;
    final notifier = ref.read(authNotifierProvider.notifier);
    final success = switch (provider) {
      _SocialAuthProvider.google => await notifier.signInWithGoogle(
        accountType: accountType,
      ),
      _SocialAuthProvider.github => await notifier.signInWithGitHub(
        accountType: accountType,
      ),
    };

    if (!success && mounted) {
      _showAuthError(
        notifier.errorMessage ?? 'Social sign-in failed. Please try again.',
      );
    }
  }

  void _showAuthError(String message) {
    final isCancelled = message.toLowerCase().contains('cancel');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isCancelled ? null : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          // Left Panel: Dynamic Keyboard/Terminal Typing Effect (Hidden on Mobile)
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                color: colorScheme.surfaceContainerLowest,
                padding: const EdgeInsets.all(60.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SKILLFORGE AI",
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "The Multiverse Core Ecosystem Platform",
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Terminal Interface Box
                    Container(
                      height: 180,
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amberAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "SYSTEM_LOG // ACCESS_POINT",
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 0.5),
                          Text(
                            ">> TARGET_IDENTITY: ${_ecosystemRoles[_roleIndex]["role"]}",
                            style: TextStyle(
                              color: AppColors.accent,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "$_currentTextâ–ˆ",
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontFamily: 'monospace',
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right Panel: Fix, Non-Scrolling Clean Auth Module
          Expanded(
            flex: 4,
            child: PremiumAuthScaffold(
              title: 'Initialize Session',
              subtitle: 'Awaiting Identity Verification.',
              isLoading: authState.isLoading,
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildAuthForm(colorScheme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm(ColorScheme colorScheme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStaggeredWidget(
                index: 0,
                child: SciFiInput(
                  controller: _emailController,
                  label: 'Identity Key (Email)',
                  hint: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
              ),
              const SizedBox(height: 20),
              _buildStaggeredWidget(
                index: 1,
                child: SciFiInput(
                  controller: _passwordController,
                  label: 'Access Protocol (Password)',
                  hint: 'Enter your password',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _buildStaggeredWidget(
                  index: 2,
                  child: TextButton(
                    onPressed: () => context.goNamed(RouteNames.forgotPassword),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    child: const Text('Bypass Protocol? (Forgot Password)'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildStaggeredWidget(
                index: 3,
                child: PrimaryButton(
                  text: 'Authenticate',
                  icon: Icons.fingerprint_rounded,
                  isLoading: ref.watch(authNotifierProvider).isLoading,
                  onPressed: _handleLogin,
                ),
              ),
              const SizedBox(height: 20),
              _buildStaggeredWidget(
                index: 4,
                child: SocialAuthButtons(
                  isLoading: ref.watch(authNotifierProvider).isLoading,
                  onGoogle: () =>
                      _handleSocialLogin(_SocialAuthProvider.google),
                  onGitHub: () =>
                      _handleSocialLogin(_SocialAuthProvider.github),
                ),
              ),
              const SizedBox(height: 24),
              _buildStaggeredWidget(
                index: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "No identity established? ",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    GestureDetector(
                      onTap: () => context.goNamed(
                        RouteNames.signup,
                        queryParameters: _authQueryParameters(context),
                      ),
                      child: const Text(
                        'Initialize Core',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildStaggeredWidget(
                index: 6,
                child: TextButton.icon(
                  onPressed: () => context.go(RoutePaths.home),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                  label: Text(
                    'Abort Mission (Home)',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaggeredWidget({required int index, required Widget child}) {
    final start = index * 0.12;
    final end = (start + 0.35).clamp(0.0, 1.0);

    final slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(start, end, curve: Curves.easeOutExpo),
          ),
        );

    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(opacity: fadeAnim, child: child),
    );
  }
}

enum _SocialAuthProvider { google, github }

Map<String, String> _authQueryParameters(BuildContext context) {
  final params = GoRouterState.of(context).uri.queryParameters;
  return {
    if (params['mode'] == 'customer') 'mode': 'customer',
    if ((params['returnUrl'] ?? '').trim().isNotEmpty)
      'returnUrl': params['returnUrl']!,
  };
}

bool _isCustomerMode(BuildContext context) {
  return GoRouterState.of(context).uri.queryParameters['mode'] == 'customer';
}
