import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../config/stripe_config.dart';
import '../../models/stripe_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/stripe_checkout_service.dart';

/// Phase 4 — seller-side "Connect with Stripe" panel for teacher and
/// freelancer earnings surfaces.
///
/// Express onboarding happens on Stripe in **test mode**; SkillForge only
/// stores the resulting account id server-side. Sellers who skip onboarding
/// keep the existing sandbox wallet/escrow behaviour.
class StripeConnectCard extends ConsumerStatefulWidget {
  const StripeConnectCard({
    required this.role,
    this.accent = AppColors.primary,
    super.key,
  });

  /// `teacher` or `freelancer` — forwarded to the gateway.
  final String role;
  final Color accent;

  @override
  ConsumerState<StripeConnectCard> createState() => _StripeConnectCardState();
}

class _StripeConnectCardState extends ConsumerState<StripeConnectCard> {
  bool _busy = false;
  String? _error;

  Future<void> _startOnboarding() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(stripeCheckoutServiceProvider);
    try {
      final link = await service.startConnectOnboarding(role: widget.role);
      final opened = await service.openCheckout(link.url);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = opened
            ? null
            : 'Could not open the Stripe onboarding tab. Check your popup blocker.';
      });
      ref.invalidate(stripeConnectStatusProvider(widget.role));
    } on StripeCheckoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(stripePaymentsEnabledProvider).value ?? false;
    if (!enabled) return const SizedBox.shrink();

    final statusAsync = ref.watch(stripeConnectStatusProvider(widget.role));
    final status =
        statusAsync.value ?? const StripeConnectStatus.notConnected();
    final loading = statusAsync.isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, color: widget.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stripe payouts',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(
                label: loading ? 'Checking…' : status.label,
                connected: status.isConnected,
                muted: loading || status.isUnavailable,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.isUnavailable
                ? status.message ??
                      'Stripe Connect is not enabled on this environment yet.'
                : status.isConnected
                ? 'Your ${StripeConfig.label} account receives the seller '
                      'share directly, with the SkillForge platform fee taken '
                      'as an application fee.'
                : 'Connect a ${StripeConfig.label} Express account to receive '
                      'the seller share of Stripe payments directly. Sandbox '
                      'wallet balances keep working either way.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (status.hasAccount) ...[
            const SizedBox(height: 8),
            Text(
              'Account ${status.accountId}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy || status.isUnavailable
                    ? null
                    : _startOnboarding,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  _busy
                      ? 'Opening Stripe…'
                      : status.hasAccount
                      ? 'Continue Stripe onboarding'
                      : 'Connect with Stripe',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => ref.invalidate(
                        stripeConnectStatusProvider(widget.role),
                      ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh status'),
              ),
              Text(
                'Test mode only — no live payouts.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.connected,
    required this.muted,
  });

  final String label;
  final bool connected;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.outline
        : connected
        ? AppColors.success
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
