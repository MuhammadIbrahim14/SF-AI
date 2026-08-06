import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_service_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/freelancer_service_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class FreelancerServiceStudioScreen extends ConsumerWidget {
  const FreelancerServiceStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(myFreelancerServicesProvider);
    final actionState = ref.watch(freelancerServiceActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Service Studio',
      subtitle: 'Create, publish, and manage your freelancer service offers.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              context.pushNamed(RouteNames.freelancerServiceRequests),
          icon: const Icon(Icons.handshake_rounded, size: 18),
          label: const Text('Requests'),
        ),
        FilledButton.icon(
          onPressed: () =>
              context.pushNamed(RouteNames.freelancerServiceCreate),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create Service'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: servicesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Services unavailable',
            message: error.toString(),
          ),
          data: (services) {
            final published = services.where((item) => item.isLive).length;
            final drafts = services.where((item) => item.isDraft).length;
            final hidden = services.where((item) => item.isHidden).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (actionState.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                ResponsiveGrid(
                  minChildWidth: 220,
                  children: [
                    MetricCard(
                      title: 'Total Services',
                      value: '${services.length}',
                      icon: Icons.design_services_rounded,
                      color: AppColors.freelancerPrimary,
                    ),
                    MetricCard(
                      title: 'Published',
                      value: '$published',
                      icon: Icons.public_rounded,
                      color: AppColors.success,
                    ),
                    MetricCard(
                      title: 'Draft',
                      value: '$drafts',
                      icon: Icons.edit_note_rounded,
                      color: AppColors.warning,
                    ),
                    MetricCard(
                      title: 'Hidden',
                      value: '$hidden',
                      icon: Icons.visibility_off_rounded,
                      color: AppColors.freelancerSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (services.isEmpty)
                  DashboardEmptyState(
                    icon: Icons.add_business_rounded,
                    title: 'No services yet',
                    message:
                        'Create your first service offer. Keep it as draft while you polish the details, then publish when it is ready.',
                    actionLabel: 'Create Service',
                    onAction: () =>
                        context.pushNamed(RouteNames.freelancerServiceCreate),
                  )
                else
                  ResponsiveGrid(
                    minChildWidth: 310,
                    children: services
                        .map(
                          (service) => _ServiceCard(
                            service: service,
                            isBusy: actionState.isLoading,
                            onEdit: () => context.pushNamed(
                              RouteNames.freelancerServiceEdit,
                              pathParameters: {'serviceId': service.serviceId},
                            ),
                            onDuplicate: () =>
                                _duplicateService(context, ref, service),
                            onDelete: () =>
                                _confirmDelete(context, ref, service),
                            onPublishToggle: () =>
                                _togglePublish(context, ref, service),
                          ),
                        )
                        .toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _togglePublish(
    BuildContext context,
    WidgetRef ref,
    FreelancerServiceModel service,
  ) async {
    final notifier = ref.read(freelancerServiceActionProvider.notifier);
    final ok = service.isLive
        ? await notifier.unpublishService(service.serviceId)
        : await notifier.publishService(service.serviceId);
    if (!context.mounted) return;
    _showActionResult(
      context,
      ok: ok,
      fallback: service.isLive ? 'Service hidden.' : 'Service published.',
      notifier: notifier,
    );
  }

  Future<void> _duplicateService(
    BuildContext context,
    WidgetRef ref,
    FreelancerServiceModel service,
  ) async {
    final notifier = ref.read(freelancerServiceActionProvider.notifier);
    final id = await notifier.duplicateService(service.serviceId);
    if (!context.mounted) return;
    _showActionResult(
      context,
      ok: id != null,
      fallback: 'Draft copy created.',
      notifier: notifier,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FreelancerServiceModel service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete service?'),
        content: Text(
          'This will permanently delete "${service.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(freelancerServiceActionProvider.notifier);
    final ok = await notifier.deleteService(service.serviceId);
    if (!context.mounted) return;
    _showActionResult(
      context,
      ok: ok,
      fallback: 'Service deleted.',
      notifier: notifier,
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.isBusy,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onPublishToggle,
  });

  final FreelancerServiceModel service;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onPublishToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(service);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.design_services_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title.trim().isEmpty
                            ? 'Untitled Service'
                            : service.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusLabel(service),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              service.shortDescription.trim().isEmpty
                  ? 'No short description yet.'
                  : service.shortDescription,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (service.category.trim().isNotEmpty)
                  _ServiceChip(label: service.category),
                _ServiceChip(
                  label:
                      '${service.currency} ${service.startingPrice.toStringAsFixed(0)} ${service.pricingType}',
                ),
                if (service.estimatedDelivery.trim().isNotEmpty)
                  _ServiceChip(label: service.estimatedDelivery),
                ...service.tags.take(3).map((tag) => _ServiceChip(label: tag)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final primary = FilledButton.icon(
                  onPressed: isBusy ? null : onPublishToggle,
                  icon: Icon(
                    service.isLive
                        ? Icons.visibility_off_rounded
                        : Icons.public_rounded,
                    size: 18,
                  ),
                  label: Text(service.isLive ? 'Unpublish' : 'Publish'),
                );
                final edit = OutlinedButton.icon(
                  onPressed: isBusy ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      const SizedBox(height: 10),
                      edit,
                      const SizedBox(height: 10),
                      _OverflowActions(
                        isBusy: isBusy,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: primary),
                    const SizedBox(width: 10),
                    Expanded(child: edit),
                    const SizedBox(width: 8),
                    _OverflowActions(
                      isBusy: isBusy,
                      onDuplicate: onDuplicate,
                      onDelete: onDelete,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowActions extends StatelessWidget {
  const _OverflowActions({
    required this.isBusy,
    required this.onDuplicate,
    required this.onDelete,
  });

  final bool isBusy;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isBusy,
      tooltip: 'More actions',
      onSelected: (value) {
        if (value == 'duplicate') onDuplicate();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.copy_rounded),
            title: Text('Duplicate'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.freelancerPrimary.withValues(alpha: 0.10),
      side: BorderSide(
        color: AppColors.freelancerPrimary.withValues(alpha: 0.16),
      ),
    );
  }
}

Color _statusColor(FreelancerServiceModel service) {
  if (service.isLive) return AppColors.success;
  if (service.isHidden) return AppColors.freelancerSecondary;
  return AppColors.warning;
}

String _statusLabel(FreelancerServiceModel service) {
  if (service.isLive) return 'Published';
  if (service.isHidden) return 'Hidden';
  return 'Draft';
}

void _showActionResult(
  BuildContext context, {
  required bool ok,
  required String fallback,
  required FreelancerServiceActionNotifier notifier,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? fallback : notifier.errorMessage ?? 'Action failed.'),
    ),
  );
}
