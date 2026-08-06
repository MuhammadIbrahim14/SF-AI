import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/marketplace_models.dart';
import '../providers/course_provider.dart';
import '../providers/enrollment_provider.dart';
import '../providers/purchase_provider.dart';
import 'course_premium_widgets.dart';

/// Student hub for paid course purchases — receipts, access, and progress.
class StudentPaidCoursesScreen extends ConsumerWidget {
  const StudentPaidCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = ref.watch(authStateProvider).value?.uid ?? '';
    final purchasesAsync = ref.watch(studentPurchaseHistoryProvider(studentId));
    final enrollmentsAsync = ref.watch(studentEnrollmentsProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'My Paid Courses',
      subtitle: 'Purchases, receipts, and access to courses you bought.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: CoursePremiumBackground(
        child: studentId.isEmpty
            ? const CoursePremiumMessage(
                icon: Icons.person_off_outlined,
                title: 'Sign in required',
                message: 'Please sign in to view your paid courses.',
              )
            : purchasesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => CoursePremiumMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Unable to load purchases',
                  message: error.toString(),
                ),
                data: (purchases) {
                  final enrollments = enrollmentsAsync.value ?? const [];
                  final progressByCourse = {
                    for (final e in enrollments) e.courseId: e.progressPercent,
                  };
                  final totalSpent = purchases.fold<double>(
                    0,
                    (sum, p) => sum + p.finalAmount,
                  );
                  final currency = purchases.isNotEmpty
                      ? purchases.first.currency
                      : 'USD';

                  if (purchases.isEmpty) {
                    return CoursePremiumListView(
                      children: [
                        const CourseHeroHeader(
                          icon: Icons.shopping_bag_outlined,
                          title: 'No paid courses yet',
                          subtitle:
                              'Browse the marketplace and purchase a course to see it here.',
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () =>
                              context.pushNamed(RouteNames.studentCourses),
                          icon: const Icon(Icons.explore_rounded),
                          label: const Text('Browse courses'),
                        ),
                      ],
                    );
                  }

                  return CoursePremiumListView(
                    maxWidth: 1000,
                    bottomPadding: 96,
                    children: [
                      CourseGlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Purchase summary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${purchases.length} paid course'
                                    '${purchases.length == 1 ? '' : 's'} · '
                                    'Total spent $currency ${totalSpent.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.verified_rounded,
                              size: 40,
                              color: AppColors.success.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...purchases.map(
                        (purchase) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _PaidCourseCard(
                            purchase: purchase,
                            progressPercent:
                                progressByCourse[purchase.courseId] ?? 0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _PaidCourseCard extends ConsumerWidget {
  const _PaidCourseCard({
    required this.purchase,
    required this.progressPercent,
  });

  final CoursePurchase purchase;
  final double progressPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(purchase.courseId));
    final theme = Theme.of(context);
    final isComplete = progressPercent >= 100;

    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      child: courseAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Text('Unable to load course details.'),
        data: (course) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course?.title ?? 'Course',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Purchased ${_fmt(purchase.purchasedAt)} · '
                          '${purchase.paymentMethod}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${purchase.currency} ${purchase.finalAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                      if (purchase.discountAmount > 0)
                        Text(
                          'Saved ${purchase.currency} ${purchase.discountAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.receipt_long_rounded,
                    label: purchase.purchaseId.length > 10
                        ? 'Receipt …${purchase.purchaseId.substring(purchase.purchaseId.length - 8)}'
                        : 'Receipt ${purchase.purchaseId}',
                  ),
                  _InfoChip(
                    icon: Icons.trending_up_rounded,
                    label: isComplete
                        ? 'Completed'
                        : '${progressPercent.toStringAsFixed(0)}% progress',
                  ),
                  if (purchase.transactionReference != null &&
                      purchase.transactionReference!.trim().isNotEmpty)
                    _InfoChip(
                      icon: Icons.tag_rounded,
                      label: purchase.transactionReference!,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.pushNamed(
                        RouteNames.studentCourseLearn,
                        pathParameters: {'courseId': purchase.courseId},
                      ),
                      icon: Icon(
                        isComplete
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(isComplete ? 'Review course' : 'Continue'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.pushNamed(
                        RouteNames.studentEnrolledCourses,
                      ),
                      icon: const Icon(Icons.school_rounded),
                      label: const Text('All enrollments'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(DateTime date) => DateFormat.yMMMd().add_jm().format(date);
