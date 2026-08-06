import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/user_provider.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/presentation/checkout/payfast_checkout_sheet.dart';
import '../data/models/marketplace_models.dart';
import '../providers/enrollment_provider.dart';
import '../providers/purchase_provider.dart';

/// Primary CTA on course detail for paid courses.
class CoursePurchaseButton extends ConsumerWidget {
  const CoursePurchaseButton({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
    this.onPurchased,
  });

  final String courseId;
  final String courseTitle;
  final String teacherId;
  final VoidCallback? onPurchased;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paidAsync = ref.watch(paidCourseConfigProvider(courseId));

    return paidAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.error_outline),
        label: const Text('Pricing unavailable'),
      ),
      data: (paid) {
        final label =
            'Buy with Demo Gateway · ${paid.currency} ${paid.discountedPrice.toStringAsFixed(2)}';
        return FilledButton.icon(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => CoursePurchaseDialog(
                courseId: courseId,
                courseTitle: courseTitle,
                teacherId: teacherId,
                paidConfig: paid,
                onSuccess: onPurchased,
              ),
            );
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        );
      },
    );
  }
}

class CoursePurchaseDialog extends ConsumerWidget {
  const CoursePurchaseDialog({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
    required this.paidConfig,
    this.onSuccess,
  });

  final String courseId;
  final String courseTitle;
  final String teacherId;
  final PaidCourseConfig paidConfig;
  final VoidCallback? onSuccess;

  Future<void> _startCheckout(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final result = await showPayFastCheckoutSheet(
      context: context,
      ref: ref,
      type: PaymentType.course,
      amount: paidConfig.discountedPrice,
      currency: paidConfig.currency,
      description: 'Course: $courseTitle',
      role: 'student',
      teacherId: teacherId,
      metadata: {
        'courseId': courseId,
        'courseTitle': courseTitle,
        'teacherId': teacherId,
      },
      title: 'Buy course',
    );

    if (!context.mounted) return;
    if (result != null && PaymentStatus.isSuccess(result.status)) {
      // Gateway Admin SDK writes enrollment; give Firestore a moment, then refresh.
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final enrolled = await ref
            .read(enrollmentRepositoryProvider)
            .getEnrollmentByStudentAndCourse(
              studentId: user.uid,
              courseId: courseId,
            );
        if (enrolled != null) break;
      }

      ref.invalidate(studentPurchaseHistoryProvider);
      ref.invalidate(hasPurchasedProvider);
      ref.invalidate(courseEnrollmentProvider(courseId));
      onSuccess?.call();
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Secure checkout',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(courseTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              _PriceBreakdown(config: paidConfig),
              const SizedBox(height: 12),
              Text(
                'Pay via SkillForge Demo Gateway (Card, JazzCash, Easypaisa, or Raast). '
                'DEMO MODE — no real money. SkillForge never stores your card number. '
                'Platform fee is settled to SkillForge; the teacher receives the seller share.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _startCheckout(context, ref),
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                  'Continue to Demo Gateway · ${paidConfig.currency} '
                  '${paidConfig.discountedPrice.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.config});

  final PaidCourseConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Price'),
              Text('${config.currency} ${config.price.toStringAsFixed(2)}'),
            ],
          ),
          if (config.hasDiscount) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount'),
                Text(
                  '- ${config.currency} ${config.discountAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${config.currency} ${config.discountedPrice.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
