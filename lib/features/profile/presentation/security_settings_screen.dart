import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../providers/app_lock_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import 'widgets/lock_status_card.dart';
import 'widgets/security_tile.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final lockAsync = ref.watch(appLockProvider);
    final lockState = lockAsync.value ?? const AppLockState();
    final role =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.student;

    return RoleFixedHeaderPage(
      role: role,
      title: 'Identity Vault',
      subtitle: 'Manage App Lock, PIN, and biometric unlock.',
      showBackButton: true,
      scrollable: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final horizontalPadding = isMobile ? 16.0 : 32.0;

          Widget buildGrid(List<Widget> cards) {
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cards
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: c,
                      ),
                    )
                    .toList(),
              );
            }

            List<Widget> rows = [];
            for (int i = 0; i < cards.length; i += 2) {
              rows.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: i + 1 < cards.length
                            ? cards[i + 1]
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(children: rows);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SecurityHeader(colorScheme: colorScheme),
                    const SizedBox(height: 32),
                    LockStatusCard(
                      isAppLockEnabled: lockState.isEnabled,
                      isPinConfigured: lockState.isEnabled,
                      isBiometricEnabled: lockState.isBiometricEnabled,
                    ),
                    if (lockAsync.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (lockState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _SecurityMessage(
                        message: lockState.errorMessage!,
                        isError: true,
                      ),
                    ],
                    if (lockState.failedAttempts > 0) ...[
                      const SizedBox(height: 12),
                      _SecurityMessage(
                        message:
                            '${lockState.failedAttempts} failed PIN '
                            '${lockState.failedAttempts == 1 ? 'attempt' : 'attempts'}',
                      ),
                    ],
                    const SizedBox(height: 40),
                    const _SectionTitle(
                      title: 'App Lock',
                      subtitle:
                          'Control access to SkillForge AI on this device.',
                    ),
                    const SizedBox(height: 16),
                    buildGrid([
                      SecurityTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Enable App Lock',
                        subtitle: lockState.isEnabled
                            ? 'App Lock is already protecting this device.'
                            : 'Protect the app with a secure 4 or 6 digit PIN.',
                        onTap: lockState.isEnabled
                            ? null
                            : () => context.pushNamed(RouteNames.setupPin),
                      ),
                      SecurityTile(
                        icon: Icons.pin_outlined,
                        title: 'Change PIN',
                        subtitle: lockState.isEnabled
                            ? 'Replace your current App Lock PIN.'
                            : 'Available after App Lock has been enabled.',
                        onTap: lockState.isEnabled
                            ? () => context.pushNamed(RouteNames.changePin)
                            : null,
                      ),
                      SecurityTile(
                        icon: Icons.lock_open_outlined,
                        title: 'Disable PIN',
                        subtitle: lockState.isEnabled
                            ? 'Verify your PIN and remove App Lock.'
                            : 'App Lock is currently off.',
                        isDestructive: true,
                        onTap: lockState.isEnabled
                            ? () => context.pushNamed(RouteNames.disablePin)
                            : null,
                      ),
                    ]),
                    const SizedBox(height: 32),
                    const _SectionTitle(
                      title: 'Biometrics',
                      subtitle:
                          'Use supported device authentication for faster access.',
                    ),
                    const SizedBox(height: 16),
                    buildGrid([
                      SecurityTile(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biometric Unlock',
                        subtitle: _biometricSubtitle(lockState),
                        onTap:
                            lockState.isEnabled &&
                                lockState.isBiometricAvailable
                            ? () => _toggleBiometrics(
                                context,
                                ref,
                                !lockState.isBiometricEnabled,
                              )
                            : null,
                        trailing: Switch.adaptive(
                          value: lockState.isBiometricEnabled,
                          onChanged:
                              lockState.isEnabled &&
                                  lockState.isBiometricAvailable
                              ? (enabled) =>
                                    _toggleBiometrics(context, ref, enabled)
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 32),
                    const _PrivacyNote(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _biometricSubtitle(AppLockState state) {
    if (!state.isEnabled) {
      return 'Enable App Lock first. PIN fallback always remains available.';
    }
    if (!state.isBiometricAvailable) {
      return 'Not available or not enrolled on this device/browser.';
    }
    return state.isBiometricEnabled
        ? '${state.biometricLabel} is enabled on this device.'
        : 'Use ${state.biometricLabel.toLowerCase()} for faster access.';
  }

  static Future<void> _toggleBiometrics(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final success = await ref
        .read(appLockProvider.notifier)
        .setBiometricEnabled(enabled);
    if (!context.mounted) return;

    final message = success
        ? enabled
              ? 'Biometric unlock enabled.'
              : 'Biometric unlock disabled.'
        : ref.read(appLockProvider).value?.errorMessage ??
              'Unable to update biometric unlock.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF087F5B)
            : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _SecurityMessage extends StatelessWidget {
  const _SecurityMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.shield_rounded,
              color: colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identity Vault',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage how this device protects your account and local data.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your PIN is hashed with your Firebase UID and stored in secure '
              'on-device storage. Biometric preferences stay local, and no '
              'PIN or biometric data is sent to Firestore.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
