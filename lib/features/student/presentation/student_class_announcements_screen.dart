import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/student_batch_provider.dart';

class StudentClassAnnouncementsScreen extends ConsumerWidget {
  const StudentClassAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final announcementsAsync = ref.watch(studentClassAnnouncementsProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'My class announcements',
      subtitle: 'Updates from class batches you are on.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentMyBatches),
      scrollable: false,
      child: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load announcements: $error',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return DashboardEmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements yet',
              message:
                  'When your teacher posts to a batch you are on, it will show here.',
              actionLabel: 'Join a class batch',
              onAction: () =>
                  context.pushNamed(RouteNames.studentJoinBatch),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentClassAnnouncementsProvider);
              await ref.read(studentClassAnnouncementsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.batch.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.announcement.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.announcement.body.isEmpty
                            ? 'No details.'
                            : item.announcement.body,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat.yMMMd()
                            .add_jm()
                            .format(item.announcement.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
