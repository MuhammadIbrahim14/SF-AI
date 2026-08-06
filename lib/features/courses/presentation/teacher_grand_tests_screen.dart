import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/grand_test_model.dart';
import '../data/models/mcq_assignment_model.dart';
import '../providers/grand_test_provider.dart';
import 'course_premium_widgets.dart';

class TeacherGrandTestsScreen extends ConsumerWidget {
  const TeacherGrandTestsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(teacherGrandTestsProvider(courseId));
    final actionState = ref.watch(grandTestActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Exam Control Center',
      subtitle: 'Create grand tests, check eligibility, and review attempts.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherCourseLessons,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      actions: [
        FilledButton.icon(
          onPressed: () => context.pushNamed(
            RouteNames.teacherGrandTestCreate,
            pathParameters: {'courseId': courseId},
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Grand Test'),
        ),
      ],
      child: CoursePremiumBackground(
        child: testsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (tests) {
            if (tests.isEmpty) {
              return const CoursePremiumMessage(
                icon: Icons.workspace_premium_outlined,
                title: 'No grand tests yet',
                message:
                    'Create a high-stakes final assessment when learners are ready.',
              );
            }
            return CoursePremiumListView(
              maxWidth: 1000,
              bottomPadding: 96,
              children: [
                const CourseHeroHeader(
                  icon: Icons.security_rounded,
                  title: 'Exam Control Center',
                  subtitle:
                      'Create final assessments, monitor live eligibility, and review high-stakes attempts.',
                ),
                const SizedBox(height: 24),
                ...tests.map(
                  (test) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _GrandTestCard(
                      test: test,
                      busy: actionState.isLoading,
                      onEdit: () => context.pushNamed(
                        RouteNames.teacherGrandTestEdit,
                        pathParameters: {
                          'courseId': courseId,
                          'grandTestId': test.grandTestId,
                        },
                      ),
                      onPublish: test.isPublished
                          ? null
                          : () => _publish(context, ref, test.grandTestId),
                      onArchive: test.isArchived
                          ? null
                          : () => _archive(context, ref, test.grandTestId),
                      onEligibility: () => context.pushNamed(
                        RouteNames.teacherGrandTestEligibility,
                        pathParameters: {
                          'courseId': courseId,
                          'grandTestId': test.grandTestId,
                        },
                      ),
                      onAttempts: () => context.pushNamed(
                        RouteNames.teacherGrandTestAttempts,
                        pathParameters: {
                          'courseId': courseId,
                          'grandTestId': test.grandTestId,
                        },
                      ),
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

  Future<void> _publish(
    BuildContext context,
    WidgetRef ref,
    String grandTestId,
  ) async {
    final success = await ref
        .read(grandTestActionProvider.notifier)
        .publishGrandTest(courseId: courseId, grandTestId: grandTestId);
    if (!context.mounted) return;
    _showResult(context, ref, success, 'Grand test published.');
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    String grandTestId,
  ) async {
    final success = await ref
        .read(grandTestActionProvider.notifier)
        .archiveGrandTest(courseId: courseId, grandTestId: grandTestId);
    if (!context.mounted) return;
    _showResult(context, ref, success, 'Grand test archived.');
  }

  void _showResult(
    BuildContext context,
    WidgetRef ref,
    bool success,
    String successMessage,
  ) {
    final message = success
        ? successMessage
        : ref.read(grandTestActionProvider.notifier).errorMessage ??
              'Unable to update grand test.';
    if (!success && message.toLowerCase().contains('upgrade')) {
      showTeacherUpgradeDialog(
        context: context,
        ref: ref,
        message: message,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GrandTestCard extends StatelessWidget {
  const _GrandTestCard({
    required this.test,
    required this.busy,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
    required this.onEligibility,
    required this.onAttempts,
  });

  final GrandTestModel test;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onArchive;
  final VoidCallback onEligibility;
  final VoidCallback onAttempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPublished = test.isPublished;

    return CourseGlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            test.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusBadge(status: test.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          icon: Icons.timer_rounded,
                          text: '${test.durationMinutes} min',
                          color: Colors.blue,
                        ),
                        _MetaPill(
                          icon: Icons.military_tech_rounded,
                          text: '${test.totalMarks} marks',
                          color: Colors.orange,
                        ),
                        _MetaPill(
                          icon: Icons.fitness_center_rounded,
                          text: test.difficulty,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            test.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onAttempts,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.analytics_rounded),
                label: const Text(
                  'Attempts',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onEligibility,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.secondary,
                ),
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text(
                  'Eligibility Check',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!isPublished)
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text(
                    'Publish Test',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit Config'),
              ),
              if (!test.isArchived)
                TextButton.icon(
                  onPressed: busy ? null : onArchive,
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Archive'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPublished = status == AssignmentStatus.published;
    final isArchived = status == AssignmentStatus.archived;

    final color = isPublished
        ? Colors.green
        : isArchived
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublished
                ? Icons.online_prediction_rounded
                : isArchived
                ? Icons.archive_rounded
                : Icons.edit_note_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
