import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/lms_ui/lms_progress_card.dart';
import '../../../shared/widgets/lms_ui/lms_section_card.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/enrollment_model.dart';
import '../providers/course_provider.dart';
import '../providers/enrollment_provider.dart';
import '../providers/lesson_provider.dart';
import 'course_premium_widgets.dart';

class StudentCourseLearningScreen extends ConsumerWidget {
  const StudentCourseLearningScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(courseId));
    final enrollmentAsync = ref.watch(courseEnrollmentProvider(courseId));
    // Recompute progress against the course content that exists right now.
    ref.watch(courseProgressSyncProvider(courseId));

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Continue Learning',
      subtitle: 'Resume lessons, assignments, and grand test preparation.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentEnrolledCourses),
      scrollable: false,
      child: CoursePremiumBackground(
        child: courseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (course) {
            if (course == null) {
              return const Center(child: Text('Course not found.'));
            }
            final enrollment = enrollmentAsync.value;
            if (enrollment == null) {
              return const Center(
                child: Text('Enroll before viewing lessons.'),
              );
            }

            return CoursePremiumListView(
              maxWidth: 940,
              children: [
                CourseHeroHeader(
                  icon: Icons.play_circle_fill_rounded,
                  title: course.title,
                  subtitle:
                      'Continue lessons, assignments, and your grand test.',
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${enrollment.progressPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Text('complete'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LmsProgressCard(
                  progress: (enrollment.progressPercent / 100)
                      .clamp(0, 1)
                      .toDouble(),
                  label: 'Overall course completion',
                ),
                const SizedBox(height: 12),
                _RequirementBreakdown(enrollment: enrollment),
                const SizedBox(height: 20),
                LmsSectionCard(
                  icon: Icons.quiz_rounded,
                  title: 'MCQ Assignments',
                  description: 'View and attempt published quizzes',
                  onTap: () => context.pushNamed(
                    RouteNames.studentAssignments,
                    pathParameters: {'courseId': courseId},
                  ),
                ),
                const SizedBox(height: 12),
                LmsSectionCard(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Grand Test',
                  description: 'Check your final test eligibility',
                  onTap: () => context.pushNamed(
                    RouteNames.studentGrandTestOverview,
                    pathParameters: {'courseId': courseId},
                  ),
                ),
                const SizedBox(height: 12),
                lessonsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text(error.toString()),
                  data: (lessons) {
                    if (lessons.isEmpty) {
                      return const Text('No lessons have been added yet.');
                    }
                    return Column(
                      children: lessons.map((lesson) {
                        return CourseGlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(lesson.orderIndex.toString()),
                              ),
                              title: Text(lesson.title),
                              subtitle: Text('${lesson.durationMinutes} min'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.pushNamed(
                                RouteNames.studentLessonDetail,
                                pathParameters: {
                                  'courseId': courseId,
                                  'lessonId': lesson.lessonId,
                                },
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shows what still stands between the student and 100%: only the modules the
/// course actually uses are listed.
class _RequirementBreakdown extends StatelessWidget {
  const _RequirementBreakdown({required this.enrollment});

  final EnrollmentModel enrollment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = CourseRequirementKind.values
        .map((kind) => (kind: kind, count: enrollment.requirement(kind)))
        .where((entry) => entry.count.isConfigured)
        .toList();

    if (configured.isEmpty) {
      return Text(
        '${enrollment.completedLessons}/${enrollment.totalLessons} lessons completed',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${enrollment.completedRequirements}/${enrollment.totalRequirements} required items completed',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: configured.map((entry) {
            return Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                entry.count.isComplete
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: entry.count.isComplete
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(
                '${CourseRequirementKind.label(entry.kind)} '
                '${entry.count.completed}/${entry.count.total}',
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
