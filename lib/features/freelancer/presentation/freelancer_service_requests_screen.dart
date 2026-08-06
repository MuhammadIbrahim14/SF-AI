import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/service_request_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

enum _FreelancerRequestSort { newest, deadlineSoon, priority }

class FreelancerServiceRequestsScreen extends ConsumerStatefulWidget {
  const FreelancerServiceRequestsScreen({super.key});

  @override
  ConsumerState<FreelancerServiceRequestsScreen> createState() =>
      _FreelancerServiceRequestsScreenState();
}

class _FreelancerServiceRequestsScreenState
    extends ConsumerState<FreelancerServiceRequestsScreen> {
  String _filter = _RequestFilter.all;
  _FreelancerRequestSort _sort = _FreelancerRequestSort.newest;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(freelancerServiceRequestsProvider);
    final actionState = ref.watch(serviceRequestActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Service Requests',
      subtitle: 'Manage incoming client work from request to delivery.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.goNamed(RouteNames.freelancerServices),
          icon: const Icon(Icons.design_services_rounded, size: 18),
          label: const Text('My Services'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Requests unavailable',
            message: error.toString(),
          ),
          data: (requests) {
            final filtered = _sorted(_filtered(requests));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (actionState.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (requests.isNotEmpty) ...[
                  _FreelancerMetrics(requests: requests),
                  const SizedBox(height: 18),
                  _FreelancerControls(
                    selectedFilter: _filter,
                    sort: _sort,
                    requests: requests,
                    onFilterChanged: (value) => setState(() => _filter = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                  ),
                  const SizedBox(height: 18),
                ],
                if (requests.isEmpty)
                  DashboardEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'No service requests yet',
                    message:
                        'Promote your services and keep your portfolio proof polished. Incoming client requests will appear here.',
                    actionLabel: 'View Marketplace',
                    onAction: () =>
                        context.goNamed(RouteNames.servicesMarketplace),
                  )
                else if (filtered.isEmpty)
                  DashboardEmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No requests in this view',
                    message: 'Try another status filter or sort option.',
                    actionLabel: 'Show All',
                    onAction: () =>
                        setState(() => _filter = _RequestFilter.all),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final request = filtered[index];
                      return _FreelancerRequestCard(
                        request: request,
                        isBusy: actionState.isLoading,
                        onOpen: () => context.pushNamed(
                          RouteNames.serviceRequestDetail,
                          pathParameters: {'requestId': request.requestId},
                        ),
                        onAction: (status) =>
                            _updateStatus(context, ref, request, status),
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

  List<ServiceRequestModel> _filtered(List<ServiceRequestModel> requests) {
    return requests.where((request) {
      return switch (_filter) {
        _RequestFilter.pending =>
          request.status == ServiceRequestStatus.pending,
        _RequestFilter.accepted =>
          request.status == ServiceRequestStatus.accepted,
        _RequestFilter.inProgress =>
          request.status == ServiceRequestStatus.inProgress,
        _RequestFilter.delivered =>
          request.status == ServiceRequestStatus.delivered,
        _RequestFilter.completed =>
          request.status == ServiceRequestStatus.completed,
        _RequestFilter.closed =>
          request.status == ServiceRequestStatus.cancelled ||
              request.status == ServiceRequestStatus.rejected,
        _ => true,
      };
    }).toList();
  }

  List<ServiceRequestModel> _sorted(List<ServiceRequestModel> requests) {
    final sorted = [...requests];
    sorted.sort((a, b) {
      return switch (_sort) {
        _FreelancerRequestSort.deadlineSoon => _deadlineValue(
          a,
        ).compareTo(_deadlineValue(b)),
        _FreelancerRequestSort.priority => _priorityRank(
          a.priority,
        ).compareTo(_priorityRank(b.priority)),
        _FreelancerRequestSort.newest => b.createdAt.compareTo(a.createdAt),
      };
    });
    return sorted;
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
    String status,
  ) async {
    final noteController = TextEditingController(text: request.freelancerNote);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_statusLabel(status)} request'),
        content: TextField(
          controller: noteController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Freelancer note',
            helperText: 'Visible to the client. No chat thread is created.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(serviceRequestActionProvider.notifier);
    final ok = await notifier.updateFreelancerStatus(
      requestId: request.requestId,
      status: status,
      freelancerNote: note.isEmpty ? null : note,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Request updated.' : notifier.errorMessage ?? 'Update failed.',
        ),
      ),
    );
  }
}

class _FreelancerMetrics extends StatelessWidget {
  const _FreelancerMetrics({required this.requests});

  final List<ServiceRequestModel> requests;

  @override
  Widget build(BuildContext context) {
    final pending = _count(requests, ServiceRequestStatus.pending);
    final accepted = _count(requests, ServiceRequestStatus.accepted);
    final inProgress = _count(requests, ServiceRequestStatus.inProgress);
    final delivered = _count(requests, ServiceRequestStatus.delivered);
    final completed = _count(requests, ServiceRequestStatus.completed);
    final closed = requests
        .where(
          (item) =>
              item.status == ServiceRequestStatus.cancelled ||
              item.status == ServiceRequestStatus.rejected,
        )
        .length;

    return ResponsiveGrid(
      minChildWidth: 180,
      children: [
        MetricCard(
          title: 'Pending',
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Accepted',
          value: '$accepted',
          icon: Icons.handshake_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'In Progress',
          value: '$inProgress',
          icon: Icons.sync_rounded,
          color: AppColors.info,
        ),
        MetricCard(
          title: 'Delivered',
          value: '$delivered',
          icon: Icons.inventory_2_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Completed',
          value: '$completed',
          icon: Icons.verified_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Closed',
          value: '$closed',
          icon: Icons.block_rounded,
          color: AppColors.error,
        ),
      ],
    );
  }

  int _count(List<ServiceRequestModel> requests, String status) {
    return requests.where((item) => item.status == status).length;
  }
}

class _FreelancerControls extends StatelessWidget {
  const _FreelancerControls({
    required this.selectedFilter,
    required this.sort,
    required this.requests,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final String selectedFilter;
  final _FreelancerRequestSort sort;
  final List<ServiceRequestModel> requests;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_FreelancerRequestSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ..._RequestFilter.values.map(
            (filter) => ChoiceChip(
              selected: selectedFilter == filter,
              label: Text('${_filterLabel(filter)} (${_filterCount(filter)})'),
              onSelected: (_) => onFilterChanged(filter),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<_FreelancerRequestSort>(
              value: sort,
              borderRadius: BorderRadius.circular(16),
              items: _FreelancerRequestSort.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text('Sort: ${_sortLabel(item)}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  int _filterCount(String filter) {
    return requests.where((request) {
      return switch (filter) {
        _RequestFilter.pending =>
          request.status == ServiceRequestStatus.pending,
        _RequestFilter.accepted =>
          request.status == ServiceRequestStatus.accepted,
        _RequestFilter.inProgress =>
          request.status == ServiceRequestStatus.inProgress,
        _RequestFilter.delivered =>
          request.status == ServiceRequestStatus.delivered,
        _RequestFilter.completed =>
          request.status == ServiceRequestStatus.completed,
        _RequestFilter.closed =>
          request.status == ServiceRequestStatus.cancelled ||
              request.status == ServiceRequestStatus.rejected,
        _ => true,
      };
    }).length;
  }
}

class _FreelancerRequestCard extends StatelessWidget {
  const _FreelancerRequestCard({
    required this.request,
    required this.isBusy,
    required this.onOpen,
    required this.onAction,
  });

  final ServiceRequestModel request;
  final bool isBusy;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy');
    final color = _statusColor(request.status);
    final actions = _actionsFor(request.status);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.projectTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${request.serviceTitle} • ${request.clientName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.clientEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                request.requirements,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.payments_rounded,
                    label:
                        '${request.currency} ${request.budget.toStringAsFixed(0)}',
                    color: color,
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: 'Updated ${formatter.format(request.updatedAt)}',
                    color: AppColors.info,
                  ),
                  if (request.deadline != null)
                    _InfoChip(
                      icon: Icons.flag_rounded,
                      label: 'Due ${formatter.format(request.deadline!)}',
                      color: AppColors.warning,
                    ),
                  _InfoChip(
                    icon: Icons.priority_high_rounded,
                    label: _priorityLabel(request.priority),
                    color: _priorityColor(request.priority),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _nextFreelancerAction(request),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: actions
                      .map(
                        (status) => OutlinedButton(
                          onPressed: isBusy ? null : () => onAction(status),
                          child: Text(_statusLabel(status)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.16)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RequestFilter {
  const _RequestFilter._();

  static const all = 'all';
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const inProgress = 'inProgress';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const closed = 'closed';

  static const values = [
    all,
    pending,
    accepted,
    inProgress,
    delivered,
    completed,
    closed,
  ];
}

List<String> _actionsFor(String status) {
  return switch (status) {
    ServiceRequestStatus.pending => [
      ServiceRequestStatus.accepted,
      ServiceRequestStatus.rejected,
    ],
    ServiceRequestStatus.accepted => [ServiceRequestStatus.inProgress],
    ServiceRequestStatus.inProgress => [ServiceRequestStatus.delivered],
    _ => const <String>[],
  };
}

int _deadlineValue(ServiceRequestModel request) {
  return request.deadline?.millisecondsSinceEpoch ?? 8640000000000000;
}

int _priorityRank(String priority) {
  return switch (priority) {
    ServiceRequestPriority.high => 0,
    ServiceRequestPriority.normal => 1,
    _ => 2,
  };
}

String _filterLabel(String filter) {
  return switch (filter) {
    _RequestFilter.pending => 'Pending',
    _RequestFilter.accepted => 'Accepted',
    _RequestFilter.inProgress => 'In Progress',
    _RequestFilter.delivered => 'Delivered',
    _RequestFilter.completed => 'Completed',
    _RequestFilter.closed => 'Rejected / Cancelled',
    _ => 'All',
  };
}

String _sortLabel(_FreelancerRequestSort sort) {
  return switch (sort) {
    _FreelancerRequestSort.deadlineSoon => 'Deadline soon',
    _FreelancerRequestSort.priority => 'Priority',
    _FreelancerRequestSort.newest => 'Newest',
  };
}

String _nextFreelancerAction(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.pending =>
      'Next action: accept the request or reject it with a helpful note.',
    ServiceRequestStatus.accepted =>
      'Next action: move to in progress when work starts.',
    ServiceRequestStatus.inProgress =>
      'Next action: mark delivered when ready for client review.',
    ServiceRequestStatus.delivered =>
      'Next action: wait for the client to mark completed.',
    ServiceRequestStatus.completed => 'Closed: client marked this completed.',
    ServiceRequestStatus.rejected => 'Closed: you rejected this request.',
    ServiceRequestStatus.cancelled => 'Closed: client cancelled this request.',
    _ => 'Next action: review request details.',
  };
}

String _priorityLabel(String priority) {
  return priority[0].toUpperCase() + priority.substring(1);
}

Color _priorityColor(String priority) {
  return switch (priority) {
    ServiceRequestPriority.high => AppColors.error,
    ServiceRequestPriority.low => AppColors.info,
    _ => AppColors.freelancerSecondary,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'All' => 'All',
    ServiceRequestStatus.inProgress => 'In Progress',
    _ => status[0].toUpperCase() + status.substring(1),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    ServiceRequestStatus.accepted ||
    ServiceRequestStatus.inProgress => AppColors.info,
    ServiceRequestStatus.delivered ||
    ServiceRequestStatus.completed => AppColors.success,
    ServiceRequestStatus.rejected ||
    ServiceRequestStatus.cancelled => AppColors.error,
    _ => AppColors.warning,
  };
}
