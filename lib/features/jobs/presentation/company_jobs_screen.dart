import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/job_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/company_permission_provider.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class CompanyJobsScreen extends ConsumerWidget {
  const CompanyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(companyJobsProvider);
    final permissionAsync = ref.watch(companyPermissionProvider);
    final permission = permissionAsync.value;
    final canManageHiring = permission?.canCreateJob ?? false;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Job Postings',
      subtitle: 'Manage open roles, candidates, and smart matching.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyDashboard),
      scrollable: false,
      actions: [
        FilledButton.icon(
          onPressed: canManageHiring
              ? () => context.pushNamed(RouteNames.createJob)
              : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Post Job',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.companyPrimary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      child: ColoredBox(
        color: Colors.transparent,
        child: jobsAsync.when(
          data: (jobs) {
            if (jobs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: DashboardEmptyState(
                    icon: Icons.business_center_outlined,
                    title: 'No Active Roles',
                    message:
                        'You haven\'t posted any open roles yet. Start building your team by posting your first job.',
                    actionLabel: canManageHiring ? 'Post a Job' : null,
                    onAction: canManageHiring
                        ? () => context.pushNamed(RouteNames.createJob)
                        : null,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(companyJobsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: jobs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final appsAsync = ref.watch(jobApplicationsProvider(job.id));
                  final liveCount = appsAsync.value?.length ?? job.applicantCount;
                  return _CompanyJobCard(
                    job: job,
                    liveApplicantCount: liveCount,
                    canManageHiring: canManageHiring,
                    restrictedMessage:
                        permission?.restrictionMessage ??
                        'Company verification is required before managing hiring actions.',
                    onTap: () {
                      if (!canManageHiring) {
                        _showRestriction(context, permission);
                        return;
                      }
                      context.pushNamed(
                        RouteNames.jobApplicants,
                        pathParameters: {'id': job.id},
                      );
                    },
                    onEdit: () {
                      if (!canManageHiring) {
                        _showRestriction(context, permission);
                        return;
                      }
                      context.pushNamed(
                        RouteNames.editJob,
                        pathParameters: {'id': job.id},
                      );
                    },
                    onDelete: () {
                      if (!canManageHiring) {
                        _showRestriction(context, permission);
                        return;
                      }
                      _deleteJob(context, ref, job);
                    },
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  void _showRestriction(
    BuildContext context,
    CompanyPermissionState? permission,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permission?.restrictionMessage ??
              'Company verification is required before managing hiring actions.',
        ),
      ),
    );
  }

  Future<void> _deleteJob(
    BuildContext context,
    WidgetRef ref,
    JobModel job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job?'),
        content: Text(
          'Are you sure you want to delete "${job.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(jobActionProvider.notifier)
        .deleteJob(job.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(companyJobsProvider);
      ref.invalidate(allJobsProvider);
      ref.invalidate(matchedJobsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job posting deleted.')));
    } else {
      final error = ref.read(jobActionProvider).error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete job: $error')));
    }
  }
}

class _CompanyJobCard extends StatelessWidget {
  const _CompanyJobCard({
    required this.job,
    required this.canManageHiring,
    required this.restrictedMessage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.liveApplicantCount,
  });

  final JobModel job;
  final int? liveApplicantCount;
  final bool canManageHiring;
  final String restrictedMessage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.elevatedSurface
            : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: job.isActive
              ? AppColors.companyPrimary.withValues(alpha: 0.3)
              : (isDark ? AppColors.divider : AppColors.lightDivider),
        ),
        boxShadow: job.isActive
            ? [
                BoxShadow(
                  color: AppColors.companyPrimary.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: job.isActive
                                      ? AppColors.success.withValues(
                                          alpha: 0.15,
                                        )
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: job.isActive
                                        ? AppColors.success.withValues(
                                            alpha: 0.3,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  job.isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: job.isActive
                                        ? AppColors.success
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!canManageHiring)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.26,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'VERIFICATION REQUIRED',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (job.matchingEnabled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.companyPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 12,
                                        color: AppColors.companyPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'SMART MATCH',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: AppColors.companyPrimary,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            job.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${job.location} • ${job.type}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Application Count Badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.divider
                              : AppColors.lightDivider,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            (liveApplicantCount ?? job.applicantCount)
                                .toString(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'APPLICANTS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                if (!canManageHiring) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            restrictedMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.people_alt_rounded, size: 18),
                      label: const Text(
                        'View Candidates',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.companyPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          tooltip: 'Edit Job',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          tooltip: 'Delete Job',
                          color: AppColors.error,
                        ),
                      ],
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
