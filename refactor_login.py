import os
import re

path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\login_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add premium_auth_scaffold import
if 'premium_auth_scaffold.dart' not in content:
    content = content.replace("import '../../../shared/widgets/primary_button.dart';", "import '../../../shared/widgets/primary_button.dart';\nimport '../../../shared/widgets/premium_auth_scaffold.dart';")

# Remove _coreController
content = re.sub(r'late final AnimationController _coreController;\n', '', content)
content = re.sub(r'_coreController = AnimationController\(.*?vsync: this,\s*duration: const Duration\(seconds: 20\),\s*\)\.\.repeat\(\);\n', '', content, flags=re.DOTALL)
content = re.sub(r'_coreController\.dispose\(\);\n', '', content)

# Replace build method and _buildAuthForm
build_replacement = """  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumAuthScaffold(
      title: 'Initialize Session',
      subtitle: 'Welcome back to the SkillForge AI terminal.',
      isLoading: authState.isLoading,
      child: _buildAuthForm(colorScheme),
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
                child: CustomTextField(
                  controller: _emailController,
                  label: 'Identity Key (Email)',
                  hint: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
              ),
              const SizedBox(height: 20),

              _buildStaggeredWidget(
                index: 1,
                child: CustomTextField(
                  controller: _passwordController,
                  label: 'Access Protocol (Password)',
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
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
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
              const SizedBox(height: 32),

              _buildStaggeredWidget(
                index: 3,
                child: PrimaryButton(
                  text: 'Authenticate',
                  icon: Icons.fingerprint_rounded,
                  isLoading: ref.watch(authNotifierProvider).isLoading,
                  onPressed: _handleLogin,
                ),
              ),
              const SizedBox(height: 32),

              _buildStaggeredWidget(
                index: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "No identity established? ",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    GestureDetector(
                      onTap: () => context.goNamed(RouteNames.signup),
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
              const SizedBox(height: 24),
              _buildStaggeredWidget(
                index: 5,
                child: TextButton.icon(
                  onPressed: () => context.go(RoutePaths.home),
                  icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurfaceVariant, size: 16),
                  label: Text('Abort Mission (Home)', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }"""

# Use regex to replace the build method and everything down to _buildStaggeredWidget
# Be careful with the match
content = re.sub(r'  @override\s*Widget build\(BuildContext context\).*?Widget _buildStaggeredWidget', build_replacement + '\n\n  Widget _buildStaggeredWidget', content, flags=re.DOTALL)

# Remove _AICorePainter
content = re.sub(r'class _AICorePainter extends CustomPainter {.*?}\n', '', content, flags=re.DOTALL)

# Remove _buildBrandStoryOverlay entirely
content = re.sub(r'  Widget _buildBrandStoryOverlay\(.*?}\n', '', content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
