import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/course_model.dart';
import '../providers/course_provider.dart';
import '../providers/enrollment_provider.dart';
import '../providers/lesson_provider.dart';
import '../providers/purchase_provider.dart';
import 'course_premium_widgets.dart';
import 'purchase_widgets.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Course Details',
      subtitle: 'Review course content, resources, lessons, and enrollment.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(RouteNames.studentCourses);
      },
      scrollable: false,
      child: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CoursePremiumMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load course',
          message: error.toString(),
        ),
        data: (course) {
          if (course == null || !course.isPublished) {
            return const CoursePremiumMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Course unavailable',
              message:
                  'This course is not published or is no longer available.',
            );
          }

          return _CourseDetailContent(course: course);
        },
      ),
    );
  }
}

class _CourseDetailContent extends ConsumerWidget {
  const _CourseDetailContent({required this.course});

  final CourseModel course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final enrollmentAsync = ref.watch(courseEnrollmentProvider(course.id));
    final lessonsAsync = ref.watch(courseLessonsProvider(course.id));
    final enrollment = enrollmentAsync.value;
    // Recompute progress against the course content that exists right now.
    ref.watch(courseProgressSyncProvider(course.id));
    //     final actionState = ref.watch(enrollmentActionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          child: Column(
            children: [
              // Immersive Hero Header
              SizedBox(
                height: isWide ? 400 : 300,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    course.thumbnailUrl == null
                        ? ColoredBox(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 80,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          )
                        : Image.network(
                            course.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.grey.shade200,
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 80,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            isDark
                                ? Colors.black.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.9),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Transform.translate(
                offset: const Offset(0, -60),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: _buildMainContentColumn(
                                  context,
                                  isDark,
                                  lessonsAsync,
                                  enrollment,
                                ),
                              ),
                              const SizedBox(width: 40),
                              Expanded(
                                flex: 4,
                                child: _buildEnrollmentSidebar(
                                  context,
                                  isDark,
                                  enrollmentAsync,
                                  enrollment,
                                  ref,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildEnrollmentSidebar(
                                context,
                                isDark,
                                enrollmentAsync,
                                enrollment,
                                ref,
                              ),
                              const SizedBox(height: 32),
                              _buildMainContentColumn(
                                context,
                                isDark,
                                lessonsAsync,
                                enrollment,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContentColumn(
    BuildContext context,
    bool isDark,
    AsyncValue lessonsAsync,
    var enrollment,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.signal_cellular_alt_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              course.level.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.folder_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              course.category.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          course.title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        if (course.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            course.subtitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 32),
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created by',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  course.teacherName.trim().isEmpty
                      ? 'Verified Instructor'
                      : course.teacherName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.language_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      course.language,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),

        Text(
          'About this course',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          course.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.8,
            color: colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 48),

        if (enrollment != null) ...[
          _CourseAiTutorCard(course: course),
          const SizedBox(height: 48),
        ],

        if (course.skillsCovered.isNotEmpty) ...[
          Text(
            'Skills you will gain',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: course.skillsCovered.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      skill,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 48),
        ],

        _buildChecklistSection(
          context,
          'What you will learn',
          course.learningOutcomes,
          Icons.check_circle_rounded,
          AppColors.success,
        ),
        const SizedBox(height: 32),
        _buildChecklistSection(
          context,
          'Who is this for',
          course.targetAudience,
          Icons.person_rounded,
          AppColors.primary,
        ),
        const SizedBox(height: 32),
        _buildChecklistSection(
          context,
          'Prerequisites',
          course.prerequisites,
          Icons.info_rounded,
          colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 32),

        _ResourcesCard(course: course),
        const SizedBox(height: 32),

        if (enrollment != null) ...[
          Text(
            'Course Curriculum',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          lessonsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (lessons) {
              if (lessons.isEmpty) {
                return const Text('No lessons have been added yet.');
              }
              return Column(
                children: lessons.map<Widget>((lesson) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          lesson.orderIndex.toString(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        lesson.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_rounded, size: 14),
                            const SizedBox(width: 4),
                            Text('${lesson.durationMinutes} minutes'),
                          ],
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Explain with AI',
                            onPressed: () => context.pushNamed(
                              RouteNames.studentAiTutor,
                              queryParameters: {
                                'courseId': course.id,
                                'lessonId': lesson.lessonId,
                                'source': 'lesson',
                                'action': 'explainLesson',
                                'mode': 'learning',
                              },
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.pushNamed(
                        RouteNames.studentLessonDetail,
                        pathParameters: {
                          'courseId': course.id,
                          'lessonId': lesson.lessonId,
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 48),
        ],
      ],
    );
  }

  Widget _buildChecklistSection(
    BuildContext context,
    String title,
    List<String> items,
    IconData icon,
    Color iconColor,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(height: 1.5, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollmentSidebar(
    BuildContext context,
    bool isDark,
    AsyncValue enrollmentAsync,
    dynamic enrollment,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionState = ref.watch(enrollmentActionProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.accent,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                'Premium',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (enrollmentAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (enrollment == null) ...[
            Builder(
              builder: (context) {
                final paidAsync = ref.watch(paidCourseConfigProvider(course.id));
                return paidAsync.when(
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, _) => OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(paidCourseConfigProvider(course.id)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Retry pricing check',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  data: (paid) {
                    if (paid.isPaid) {
                      final user = ref.watch(currentUserProvider).value;
                      if (user != null) {
                        final purchasedAsync = ref.watch(
                          hasPurchasedProvider((
                            studentId: user.uid,
                            courseId: course.id,
                          )),
                        );
                        final purchased = purchasedAsync.value == true;
                        if (purchased) {
                          return FilledButton.icon(
                            onPressed: () {
                              ref.invalidate(
                                courseEnrollmentProvider(course.id),
                              );
                              ref.invalidate(
                                hasPurchasedProvider((
                                  studentId: user.uid,
                                  courseId: course.id,
                                )),
                              );
                            },
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(
                              'Purchase recorded · Refresh access',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                      }
                      return CoursePurchaseButton(
                        courseId: course.id,
                        courseTitle: course.title,
                        teacherId: course.teacherId,
                        onPurchased: () {
                          ref.invalidate(courseEnrollmentProvider(course.id));
                          final uid =
                              ref.read(currentUserProvider).value?.uid;
                          if (uid != null) {
                            ref.invalidate(
                              hasPurchasedProvider((
                                studentId: uid,
                                courseId: course.id,
                              )),
                            );
                          }
                        },
                      );
                    }
                    return FilledButton.icon(
                      onPressed: actionState.isLoading
                          ? null
                          : () => _enroll(context, ref, course.id),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: actionState.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.school_rounded),
                      label: Text(
                        actionState.isLoading ? 'Enrolling...' : 'Enroll Now',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ]
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${enrollment.progressPercent.toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: (enrollment.progressPercent / 100)
                        .clamp(0, 1)
                        .toDouble(),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  enrollment.totalRequirements > 0
                      ? '${enrollment.completedRequirements}/${enrollment.totalRequirements} required items · '
                            '${enrollment.completedLessons}/${enrollment.totalLessons} lessons completed'
                      : '${enrollment.completedLessons}/${enrollment.totalLessons} lessons completed',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pushNamed(
                RouteNames.studentCourseLearn,
                pathParameters: {'courseId': course.id},
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text(
                'Continue Learning',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),

          _SidebarStat(
            icon: Icons.timer_rounded,
            label: '${course.durationMinutes} Minutes total',
          ),
          const SizedBox(height: 16),
          _SidebarStat(
            icon: Icons.video_library_rounded,
            label: '${course.lessonCount} Modules',
          ),
          const SizedBox(height: 16),
          _SidebarStat(
            icon: Icons.assignment_rounded,
            label: 'Certificate of completion',
          ),
          const SizedBox(height: 16),
          _SidebarStat(
            icon: Icons.all_inclusive_rounded,
            label: 'Full lifetime access',
          ),
        ],
      ),
    );
  }

  Future<void> _enroll(
    BuildContext context,
    WidgetRef ref,
    String courseId,
  ) async {
    final success = await ref
        .read(enrollmentActionProvider.notifier)
        .enroll(courseId);
    if (!context.mounted) return;

    final message = success
        ? 'Successfully enrolled. Happy learning!'
        : ref.read(enrollmentActionProvider.notifier).errorMessage ??
              'Unable to enroll in this course.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SidebarStat extends StatelessWidget {
  const _SidebarStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CourseAiTutorCard extends StatelessWidget {
  const _CourseAiTutorCard({required this.course});

  final CourseModel course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Learn faster with SkillForge AI',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ask course questions, build a revision plan, or practice with AI. AI helps you learn; it will not submit work for you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _openTutor(context, action: 'askCourse', mode: 'learning'),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Ask about this course'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openTutor(
                  context,
                  action: 'practiceCourse',
                  mode: 'practiceMode',
                ),
                icon: const Icon(Icons.quiz_rounded),
                label: const Text('Generate practice'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openTutor(
                  context,
                  action: 'courseStudyPlan',
                  mode: 'revisionPlan',
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Create revision plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openTutor(
    BuildContext context, {
    required String action,
    required String mode,
  }) {
    context.pushNamed(
      RouteNames.studentAiTutor,
      queryParameters: {
        'courseId': course.id,
        'source': 'course',
        'action': action,
        'mode': mode,
      },
    );
  }
}

class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard({required this.course});

  final CourseModel course;

  @override
  Widget build(BuildContext context) {
    final hasYoutube = course.youtubeIntroUrl.trim().isNotEmpty;
    final hasPdfs = course.pdfResourceLinks.isNotEmpty;
    final hasExternalLinks = course.externalLinks.isNotEmpty;

    if (!hasYoutube && !hasPdfs && !hasExternalLinks) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course Resources',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        if (hasYoutube)
          _LinkRow(
            icon: Icons.play_circle_fill_rounded,
            label: 'YouTube Intro',
            url: course.youtubeIntroUrl,
          ),
        if (hasPdfs) ...[
          if (hasYoutube) const SizedBox(height: 12),
          ...course.pdfResourceLinks.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LinkRow(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF Document',
                url: url,
              ),
            ),
          ),
        ],
        if (hasExternalLinks) ...[
          if (hasYoutube || hasPdfs) const SizedBox(height: 12),
          ...course.externalLinks.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LinkRow(
                icon: Icons.link_rounded,
                label: 'Reference Link',
                url: url,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  url,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
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
