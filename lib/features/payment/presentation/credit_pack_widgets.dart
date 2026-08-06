import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/user_provider.dart';
import '../models/payment_models.dart';
import '../presentation/checkout/payfast_checkout_sheet.dart';
import '../providers/payment_providers.dart';
import 'invoice_widgets.dart';

class CreditPackList extends ConsumerWidget {
  const CreditPackList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(paymentCreditPacksProvider);
    return packsAsync.when(
      data: (packs) {
        if (packs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Text(
              'No credit packs available yet. Ask an admin to create packs.',
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, idx) => CreditPackCard(pack: packs[idx]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load packs: $e')),
    );
  }
}

class CreditPackCard extends ConsumerWidget {
  const CreditPackCard({required this.pack, super.key});

  final CreditPackModel pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pack.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(pack.description),
          const SizedBox(height: 8),
          Text(
            '${pack.currency} ${pack.price.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pack.credits} credits'
            '${pack.bonusCredits > 0 ? ' + ${pack.bonusCredits} bonus' : ''}',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final result = await showDialog<PaymentProcessResult>(
                context: context,
                builder: (_) => CreditPackPurchaseDialog(pack: pack),
              );
              if (result != null && context.mounted) {
                ref.invalidate(paymentCreditPacksProvider);
              }
            },
            child: const Text('Buy with Demo Gateway'),
          ),
        ],
      ),
    );
  }
}

class CreditPackPurchaseDialog extends ConsumerWidget {
  const CreditPackPurchaseDialog({required this.pack, super.key});

  final CreditPackModel pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Buy ${pack.name}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(pack.description),
              const SizedBox(height: 8),
              Text(
                '${pack.currency} ${pack.price.toStringAsFixed(2)} · '
                '${pack.credits + pack.bonusCredits} total credits',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete payment on SkillForge Demo Gateway. DEMO MODE — no real money. SkillForge never stores your card number.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: user == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        final result = await showPayFastCheckoutSheet(
                          context: context,
                          ref: ref,
                          type: PaymentType.creditPack,
                          amount: pack.price,
                          currency: pack.currency,
                          description: pack.name,
                          role: 'teacher',
                          creditPackId: pack.packId,
                          teacherId: user.uid,
                          title: 'Buy AI credits',
                        );
                        if (result == null || !context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (_) => PaymentInvoiceDialog(
                            transactionId: result.transactionId,
                            paymentId: result.paymentId,
                            amount: result.amount,
                            currency: result.currency,
                            status: result.status,
                            description: result.message,
                          ),
                        );
                      },
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Continue to Demo Gateway'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
