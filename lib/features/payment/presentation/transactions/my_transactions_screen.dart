import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/widgets/dashboard_empty_state.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../config/payfast_config.dart';
import '../../config/stripe_config.dart';
import '../../models/payment_intent_model.dart';
import '../../providers/payment_providers.dart';

/// Shared transaction history for student / teacher / freelancer / customer.
class MyTransactionsScreen extends ConsumerWidget {
  const MyTransactionsScreen({this.roleHint, super.key});

  final String? roleHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final intentsAsync = ref.watch(myPaymentIntentsProvider(uid));
    final role = UserRole.fromString(roleHint) ?? UserRole.teacher;

    return RoleFixedHeaderPage(
      role: role,
      title: 'My Transactions',
      subtitle: 'Demo Gateway payments, fees, and status for your account.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(RouteNames.dashboard);
      },
      scrollable: false,
      child: uid.isEmpty
          ? Center(
              child: DashboardEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Sign in required',
                message: 'Sign in to view your transactions.',
              ),
            )
          : intentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: DashboardEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load transactions',
                  message: e.toString(),
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(myPaymentIntentsProvider(uid)),
                ),
              ),
              data: (intents) {
                if (intents.isEmpty) {
                  return Center(
                    child: DashboardEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      message:
                          'When you pay with SkillForge Demo Gateway, every payment appears here.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: intents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _IntentTile(intent: intents[index]),
                );
              },
            ),
    );
  }
}

class _IntentTile extends StatelessWidget {
  const _IntentTile({required this.intent});

  final PaymentIntentModel intent;

  Color _statusColor() {
    if (intent.isPaid) return AppColors.success;
    if (intent.isFailed) return AppColors.error;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    intent.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    intent.status.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${intent.currency} ${intent.amount.toStringAsFixed(2)} · '
              '${intent.type} · ${intent.paymentMethod}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Platform fee: ${intent.currency} ${intent.platformFee.toStringAsFixed(2)}'
              '${intent.sellerNet > 0 && intent.sellerNet < intent.amount ? ' · Seller net: ${intent.currency} ${intent.sellerNet.toStringAsFixed(2)}' : ''}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gateway: ${paymentProviderLabel(intent.gateway.isNotEmpty ? intent.gateway : PayFastConfig.gatewayId)}'
              '${intent.metadata['isDemo'] == true || intent.gateway == PayFastConfig.gatewayId ? ' · DEMO' : ''} · '
              '${intent.createdAt.day}/${intent.createdAt.month}/${intent.createdAt.year}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (intent.intentId.isNotEmpty)
              Text(
                'Intent ${intent.intentId}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
