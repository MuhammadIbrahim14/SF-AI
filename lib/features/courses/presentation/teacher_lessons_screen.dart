import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/lms_ui/lms_section_card.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../../models/user_role.dart';
import '../data/models/lesson_model.dart';
import '../providers/enrollment_provider.dart';
import '../providers/lesson_provider.dart';
import 'course_premium_widgets.dart';

class TeacherLessonsScreen extends ConsumerWidget {
  const TeacherLessonsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(courseLessonsProvider(courseId));
    final enrollments = ref.watch(courseEnrollmentsProvider(courseId)).value;
    final actionState = ref.watch(lessonActionProvider);
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Course Studio',
      subtitle: 'Manage lessons, assignments, grand tests, and certificates.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.teacherCourses),
      scrollable: false,
      actions: [
        FilledButton.icon(
          onPressed: () => context.pushNamed(
            RouteNames.teacherLessonCreate,
            pathParameters: {'courseId': courseId},
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Lesson'),
        ),
      ],
      child: CoursePremiumBackground(
        child: lessonsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (lessons) {
            return CoursePremiumListView(
              bottomPadding: 96,
              children: [
                CourseHeroHeader(
                  icon: Icons.video_library_rounded,
                  title: 'Course Studio',
                  subtitle:
                      'Manage lessons, assignments, grand tests, and enrolled learners.',
                ),
                const SizedBox(height: 24),
                CourseGlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enrolled Students',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Active learners in this course',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          (enrollments?.length ?? 0).toString(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LmsSectionCard(
                  icon: Icons.quiz_rounded,
                  title: 'MCQ Assignments',
                  description: 'Create, publish, and review results',
                  onTap: () => context.pushNamed(
                    RouteNames.teacherAssignments,
                    pathParameters: {'courseId': courseId},
                  ),
                ),
                LmsSectionCard(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Grand Tests',
                  description: 'Create final tests and check eligibility',
                  onTap: () => context.pushNamed(
                    RouteNames.teacherGrandTests,
                    pathParameters: {'courseId': courseId},
                  ),
                ),
                LmsSectionCard(
                  icon: Icons.verified_rounded,
                  title: 'Certificate Center',
                  description: 'Issue and revoke course certificates',
                  onTap: () => context.pushNamed(
                    RouteNames.teacherCertificates,
                    pathParameters: {'courseId': courseId},
                  ),
                ),
                const SizedBox(height: 32),
                const CourseSectionTitle(
                  title: 'Curriculum',
                  subtitle: 'Lessons are listed in their current course order.',
                ),
                const SizedBox(height: 16),
                if (lessons.isEmpty)
                  const CoursePremiumMessage(
                    icon: Icons.video_library_outlined,
                    title: 'No lessons yet',
                    message: 'Add the first lesson to structure this course.',
                  )
                else
                  ...lessons.map(
                    (lesson) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LessonBar(
                        lesson: lesson,
                        courseId: courseId,
                        isBusy: actionState.isLoading,
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

class _LessonBar extends ConsumerWidget {
  const _LessonBar({
    required this.lesson,
    required this.courseId,
    required this.isBusy,
  });

  final LessonModel lesson;
  final String courseId;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.pushNamed(
            RouteNames.teacherLessonEdit,
            pathParameters: {'courseId': courseId, 'lessonId': lesson.lessonId},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${lesson.orderIndex}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${lesson.durationMinutes} min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (lesson.isPreview) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PREVIEW',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => context.pushNamed(
                        RouteNames.teacherLessonEdit,
                        pathParameters: {
                          'courseId': courseId,
                          'lessonId': lesson.lessonId,
                        },
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Archive',
                      onPressed: isBusy
                          ? null
                          : () => ref
                                .read(lessonActionProvider.notifier)
                                .archiveLesson(
                                  courseId: courseId,
                                  lessonId: lesson.lessonId,
                                ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.archive_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
