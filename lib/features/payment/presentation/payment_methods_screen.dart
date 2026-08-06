import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../config/payfast_config.dart';

/// Preferred SkillForge Demo Gateway methods (no PAN storage).
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  String? _preferred;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).value?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      body: uid.isEmpty
          ? const Center(child: Text('Sign in required'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ref
                  .watch(firestoreProvider)
                  .collection('saved_payment_methods')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final preferred =
                    _preferred ?? data?['preferredMethod']?.toString() ?? 'card';

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE69C)),
                      ),
                      child: Text(
                        PayFastConfig.demoBanner,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF856404),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preferred demo payment method',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SkillForge never stores full card numbers. Checkout runs on '
                      'SkillForge Demo Gateway (${PayFastConfig.merchantDisplayName}).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...PayFastConfig.methods.map((method) {
                      final selected = preferred == method.id;
                      return Card(
                        child: RadioListTile<String>(
                          value: method.id,
                          groupValue: preferred,
                          title: Text(method.label),
                          subtitle: Text(method.subtitle),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _preferred = v),
                          secondary: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected ? AppColors.primary : null,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await ref
                                  .read(firestoreProvider)
                                  .collection('saved_payment_methods')
                                  .doc(uid)
                                  .set({
                                'userId': uid,
                                'preferredMethod': preferred,
                                'gateway': PayFastConfig.gatewayId,
                                'isDemo': true,
                                'environment': 'demo',
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                              if (!mounted) return;
                              setState(() => _saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Preferred method saved.'),
                                ),
                              );
                            },
                      child: Text(_saving ? 'Saving…' : 'Save preference'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
