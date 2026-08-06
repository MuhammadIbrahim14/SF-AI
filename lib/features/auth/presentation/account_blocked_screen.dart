import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/premium_auth_scaffold.dart';

/// SkillForge AI â€” Zero-Views Cinematic Account Blocked Screen
/// Modified UI to match the cinematic flow, preserving existing logic.
class AccountBlockedScreen extends ConsumerWidget {
  const AccountBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch loading state from existing auth provider
    final isSigningOut = ref.watch(authNotifierProvider).isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    // Use the premium scaffold to match login/signup
    return PremiumAuthScaffold(
      // Themed title and subtitle appropriate for blocked state
      title: 'Access Restricted',
      subtitle: 'Your connection to SkillForge AI has been severed.',
      isLoading: isSigningOut,
      child: _buildContent(
        context: context,
        ref: ref,
        isSigningOut: isSigningOut,
        colorScheme: colorScheme,
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required bool isSigningOut,
    required ColorScheme colorScheme,
  }) {
    // Column layout with standardized cinematic spacing
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),

        // Centered Block Icon with specific sizing and error color
        Center(
          child: Icon(
            Icons.block_rounded,
            size: 80, // Slightly larger visual impact
            color: colorScheme.error,
          ),
        ),
        const SizedBox(height: 32),

        // Description text aligned to center, using onSurfaceVariant
        Text(
          'This account matrix cannot access SkillForge protocols. '
          'Please establish contact with platform support command '
          'if you believe this restriction is an anomaly.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.6, // Increased line height for sci-fi readability
          ),
        ),
        const SizedBox(height: 56),

        // Primary Button Wrapped in Shadow Container for Cinematic Glow
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: PrimaryButton(
            // Themed text for sci-fi atmosphere
            text: 'Terminate Connection',
            icon: Icons.power_settings_new_rounded,
            isLoading: isSigningOut,
            // Logic remains identical to original provided code
            onPressed: isSigningOut
                ? null
                : () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) {
                      context.goNamed(RouteNames.login);
                    }
                  },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
