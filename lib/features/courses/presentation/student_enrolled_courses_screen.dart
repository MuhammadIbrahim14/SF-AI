import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/enrollment_model.dart';
import '../providers/course_provider.dart';
import '../providers/enrollment_provider.dart';
import 'course_premium_widgets.dart';

class StudentEnrolledCoursesScreen extends ConsumerWidget {
  const StudentEnrolledCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(studentEnrollmentsProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'My Enrolled Courses',
      subtitle: 'Continue learning and track course progress.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: CoursePremiumBackground(
        child: enrollmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load enrollments',
            message: error.toString(),
          ),
          data: (enrollments) {
            if (enrollments.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.school_outlined,
                title: 'No enrolled courses yet',
                message: 'Enroll in a published course to start learning.',
              );
            }
            return CoursePremiumListView(
              maxWidth: 1000,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.rocket_launch_rounded,
                  title: 'Active Learning',
                  subtitle:
                      'Continue building your skills and complete your courses to unlock career matches.',
                ),
                const SizedBox(height: 32),
                ...enrollments.map(
                  (enrollment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _EnrollmentCard(enrollment: enrollment),
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

class _EnrollmentCard extends ConsumerWidget {
  const _EnrollmentCard({required this.enrollment});

  final EnrollmentModel enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(enrollment.courseId));
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Recompute against live course content so newly published lessons or
    // quizzes pull the ring back below 100%.
    ref.watch(courseProgressSyncProvider(enrollment.courseId));

    return CourseGlassCard(
      padding: const EdgeInsets.all(24),
      onTap: () => context.pushNamed(
        RouteNames.studentCourseLearn,
        pathParameters: {'courseId': enrollment.courseId},
      ),
      child: courseAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Text('Unable to load course details.'),
        data: (course) {
          final isComplete = enrollment.progressPercent >= 100;
          final accentColor = isComplete ? Colors.green : Colors.blue;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (enrollment.progressPercent / 100).clamp(0, 1),
                      strokeWidth: 6,
                      backgroundColor: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      color: accentColor,
                    ),
                    Center(
                      child: isComplete
                          ? Icon(
                              Icons.check_rounded,
                              color: accentColor,
                              size: 32,
                            )
                          : Text(
                              '${enrollment.progressPercent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: accentColor,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course?.title ?? 'Loading...',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                        ),
                        if (isComplete)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'COMPLETED',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isComplete
                          ? 'Course fully completed. Ready for certificates and tests.'
                          : 'In progress. Keep going to unlock your next skill level.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _CourseStat(
                          icon: Icons.video_library_rounded,
                          label: '${course?.lessonCount ?? 0} Lessons',
                        ),
                        const SizedBox(width: 16),
                        _CourseStat(
                          icon: Icons.category_rounded,
                          label: course?.category ?? 'Category',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isComplete
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isComplete
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded,
                      color: isComplete ? Colors.green : Colors.blue,
                      size: 28,
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

class _CourseStat extends StatelessWidget {
  const _CourseStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
