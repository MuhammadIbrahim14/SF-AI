import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_announcement_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/teacher_batch_session_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../courses/providers/course_provider.dart';
import '../../courses/providers/enrollment_provider.dart';
import '../../teacher/providers/teacher_batch_ops_provider.dart';
import '../providers/student_batch_provider.dart';

class StudentBatchDetailScreen extends ConsumerWidget {
  const StudentBatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batchesAsync = ref.watch(studentRosterBatchesProvider);
    final batch = ref.watch(studentBatchByIdProvider(batchId));
    final courses = ref.watch(publishedCoursesProvider).value ?? const [];
    final enrollments =
        ref.watch(studentEnrollmentsProvider).value ?? const [];
    final courseTitles = {
      for (final course in courses) course.id: course.title,
    };
    final enrolledCourseIds = {
      for (final enrollment in enrollments) enrollment.courseId,
    };

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: batch?.title ?? 'Class batch',
      subtitle: 'Announcements and upcoming sessions for this class.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentMyBatches),
      scrollable: false,
      child: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load batch: $error',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
        data: (_) {
          if (batch == null) {
            return DashboardEmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Batch not available',
              message:
                  'You are not on this class roster, or the batch was removed.',
              actionLabel: 'Back to My Classes',
              onAction: () => context.goNamed(RouteNames.studentMyBatches),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              _BatchHeaderCard(batch: batch),
              const SizedBox(height: 16),
              _CoursesSection(
                courseIds: batch.courseIds,
                courseTitles: courseTitles,
                enrolledCourseIds: enrolledCourseIds,
              ),
              const SizedBox(height: 16),
              _AnnouncementsSection(batchId: batch.batchId),
              const SizedBox(height: 16),
              _SessionsSection(batchId: batch.batchId),
            ],
          );
        },
      ),
    );
  }
}

class _BatchHeaderCard extends StatelessWidget {
  const _BatchHeaderCard({required this.batch});

  final TeacherBatchModel batch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDateRange(batch.startDate, batch.endDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  batch.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (batch.isArchived
                          ? theme.colorScheme.outline
                          : AppColors.success)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  batch.isArchived ? 'Archived' : 'Active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: batch.isArchived
                        ? theme.colorScheme.outline
                        : AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            batch.description.trim().isEmpty
                ? 'No description.'
                : batch.description.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            dateLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesSection extends StatelessWidget {
  const _CoursesSection({
    required this.courseIds,
    required this.courseTitles,
    required this.enrolledCourseIds,
  });

  final List<String> courseIds;
  final Map<String, String> courseTitles;
  final Set<String> enrolledCourseIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linked courses',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (courseIds.isEmpty)
            Text(
              'No courses linked to this batch.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...courseIds.map((courseId) {
              final title = courseTitles[courseId] ?? 'Course';
              final enrolled = enrolledCourseIds.contains(courseId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    enrolled ? 'Enrolled — open course' : 'Title only',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: enrolled
                      ? Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                  onTap: enrolled
                      ? () => context.pushNamed(
                            RouteNames.studentCourseDetail,
                            pathParameters: {'courseId': courseId},
                          )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection({required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final announcementsAsync =
        ref.watch(teacherBatchAnnouncementsProvider(batchId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Announcements',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Posts for this class batch only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          announcementsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Unable to load announcements.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No announcements yet for this batch.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (final item in items.take(12)) ...[
                    _AnnouncementTile(announcement: item),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final TeacherBatchAnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            announcement.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            announcement.body.isEmpty ? 'No details.' : announcement.body,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMd().add_jm().format(announcement.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsSection extends ConsumerWidget {
  const _SessionsSection({required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(teacherBatchSessionsProvider(batchId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming sessions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scheduled class meetings for this batch.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          sessionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Sessions are not available yet. Your teacher will publish '
              'upcoming meetings when ready.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            data: (items) {
              final now = DateTime.now();
              final upcoming = items.where((session) {
                final status =
                    TeacherBatchSessionStatus.normalize(session.status);
                if (status == TeacherBatchSessionStatus.cancelled ||
                    status == TeacherBatchSessionStatus.completed) {
                  return false;
                }
                return !session.startsAt.isBefore(
                  now.subtract(const Duration(hours: 2)),
                );
              }).toList();

              if (upcoming.isEmpty) {
                return Text(
                  'No upcoming sessions scheduled.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }

              return Column(
                children: [
                  for (final session in upcoming) ...[
                    _SessionTile(session: session),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final TeacherBatchSessionModel session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = DateFormat.yMMMd().add_jm().format(session.startsAt);
    final ends = session.endsAt == null
        ? null
        : DateFormat.jm().format(session.endsAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                TeacherBatchSessionStatus.label(session.status),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ends == null ? when : '$when – $ends',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (session.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(session.notes.trim(), style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

String _formatDateRange(DateTime? start, DateTime? end) {
  final fmt = DateFormat.yMMMd();
  if (start == null && end == null) return 'Dates TBD';
  if (start != null && end != null) {
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }
  if (start != null) return 'From ${fmt.format(start)}';
  return 'Until ${fmt.format(end!)}';
}
