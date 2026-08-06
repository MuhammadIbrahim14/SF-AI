import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../courses/data/models/course_model.dart';
import '../../courses/presentation/course_premium_widgets.dart';
import '../../courses/presentation/pricing_setup_widgets.dart';
import '../../courses/providers/course_provider.dart';
import '../../courses/providers/purchase_provider.dart';
import '../providers/payment_providers.dart';

/// Teacher marketplace: set paid pricing on owned courses (Pro plan only).
class TeacherPaidCoursesScreen extends ConsumerWidget {
  const TeacherPaidCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherId = ref.watch(authStateProvider).value?.uid ?? '';
    final coursesAsync = ref.watch(teacherCoursesProvider);
    final accessAsync = ref.watch(teacherSubscriptionAccessProvider(teacherId));

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Paid Courses',
      subtitle: 'Price your courses for the student marketplace.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(RouteNames.teacherDashboard);
      },
      scrollable: false,
      child: CoursePremiumBackground(
        child: accessAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CoursePremiumMessage(
            icon: Icons.error_outline,
            title: 'Unable to load plan',
            message: e.toString(),
          ),
          data: (access) {
            if (!access.allowPaidCourses) {
              return CoursePremiumListView(
                children: [
                  CourseGlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pro plan required',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Paid course pricing is locked on the free plan. '
                          'Upgrade to unlock the marketplace.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              context.pushNamed(RouteNames.teacherPlans),
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: const Text('View plans'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return coursesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => CoursePremiumMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load courses',
                message: e.toString(),
              ),
              data: (courses) {
                if (courses.isEmpty) {
                  return CoursePremiumListView(
                    children: [
                      CourseGlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('Create a course first, then set pricing here.'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () =>
                                  context.pushNamed(RouteNames.teacherCourses),
                              child: const Text('Go to courses'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return CoursePremiumListView(
                  children: [
                    CourseGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Set prices for each course. Students will see Buy instead of free enroll.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...courses.map(
                      (course) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PaidCourseRow(
                          course: course,
                          teacherId: teacherId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PaidCourseRow extends ConsumerWidget {
  const _PaidCourseRow({
    required this.course,
    required this.teacherId,
  });

  final CourseModel course;
  final String teacherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paidAsync = ref.watch(paidCourseConfigProvider(course.id));
    final theme = Theme.of(context);

    return CourseGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              paidAsync.when(
                data: (c) => CoursePill(
                  icon: c.isPaid
                      ? Icons.payments_rounded
                      : Icons.school_outlined,
                  label: c.isPaid
                      ? '${c.currency} ${c.discountedPrice.toStringAsFixed(2)}'
                      : 'Free',
                ),
                loading: () => const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            course.isPublished ? 'Published' : course.status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TeacherPricingCard(
            courseId: course.id,
            teacherId: teacherId,
            isPremiumTeacher: true,
            onEditPressed: () {
              final config = paidAsync.value;
              showDialog(
                context: context,
                builder: (_) => PricingSetupDialog(
                  courseId: course.id,
                  currentConfig: config,
                  teacherId: teacherId,
                  onSuccess: () {
                    ref.invalidate(paidCourseConfigProvider(course.id));
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
