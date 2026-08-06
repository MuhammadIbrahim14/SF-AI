import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/service_request_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

enum _ClientRequestSort { newest, deadlineSoon, statusPriority }

class MyServiceRequestsScreen extends ConsumerStatefulWidget {
  const MyServiceRequestsScreen({super.key});

  @override
  ConsumerState<MyServiceRequestsScreen> createState() =>
      _MyServiceRequestsScreenState();
}

class _MyServiceRequestsScreenState
    extends ConsumerState<MyServiceRequestsScreen> {
  String _filter = _RequestFilter.all;
  _ClientRequestSort _sort = _ClientRequestSort.newest;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final role = UserRole.fromString(user?.primaryRole) ?? UserRole.student;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view service requests.')),
      );
    }

    final requestsAsync = ref.watch(myServiceRequestsProvider);
    return RoleFixedHeaderPage(
      role: role,
      title: 'My Service Requests',
      subtitle: 'Track freelancer requests from submitted to completed.',
      showBackButton: true,
      actions: [
        FilledButton.icon(
          onPressed: () => context.goNamed(RouteNames.servicesMarketplace),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Browse Services'),
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
            if (requests.isEmpty) {
              return DashboardEmptyState(
                icon: Icons.inbox_outlined,
                title: 'No service requests yet',
                message:
                    'Browse published services and send a request when you find the right freelancer.',
                actionLabel: 'Browse Services',
                onAction: () => context.goNamed(RouteNames.servicesMarketplace),
              );
            }

            final filtered = _sorted(_filtered(requests));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ClientMetrics(requests: requests),
                const SizedBox(height: 18),
                _ClientControls(
                  selectedFilter: _filter,
                  sort: _sort,
                  requests: requests,
                  onFilterChanged: (value) => setState(() => _filter = value),
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
                const SizedBox(height: 18),
                if (filtered.isEmpty)
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
                    itemBuilder: (context, index) => _RequestCard(
                      request: filtered[index],
                      onTap: () => context.pushNamed(
                        RouteNames.serviceRequestDetail,
                        pathParameters: {
                          'requestId': filtered[index].requestId,
                        },
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

  List<ServiceRequestModel> _filtered(List<ServiceRequestModel> requests) {
    return requests.where((request) {
      return switch (_filter) {
        _RequestFilter.pending =>
          request.status == ServiceRequestStatus.pending,
        _RequestFilter.active => request.isActive,
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
        _ClientRequestSort.deadlineSoon => _deadlineValue(
          a,
        ).compareTo(_deadlineValue(b)),
        _ClientRequestSort.statusPriority => _statusPriority(
          a.status,
        ).compareTo(_statusPriority(b.status)),
        _ClientRequestSort.newest => b.createdAt.compareTo(a.createdAt),
      };
    });
    return sorted;
  }
}

class _ClientMetrics extends StatelessWidget {
  const _ClientMetrics({required this.requests});

  final List<ServiceRequestModel> requests;

  @override
  Widget build(BuildContext context) {
    final pending = requests
        .where((item) => item.status == ServiceRequestStatus.pending)
        .length;
    final active = requests.where((item) => item.isActive).length;
    final delivered = requests
        .where((item) => item.status == ServiceRequestStatus.delivered)
        .length;
    final completed = requests
        .where((item) => item.status == ServiceRequestStatus.completed)
        .length;
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
          title: 'Total',
          value: '${requests.length}',
          icon: Icons.all_inbox_rounded,
          color: AppColors.freelancerPrimary,
        ),
        MetricCard(
          title: 'Pending',
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          title: 'Active',
          value: '$active',
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
}

class _ClientControls extends StatelessWidget {
  const _ClientControls({
    required this.selectedFilter,
    required this.sort,
    required this.requests,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final String selectedFilter;
  final _ClientRequestSort sort;
  final List<ServiceRequestModel> requests;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_ClientRequestSort> onSortChanged;

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
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<_ClientRequestSort>(
              value: sort,
              borderRadius: BorderRadius.circular(16),
              items: _ClientRequestSort.values
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
        _RequestFilter.active => request.isActive,
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final ServiceRequestModel request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy');
    final color = _statusColor(request.status);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                '${request.serviceTitle} • ${request.freelancerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetaChip(
                    icon: Icons.payments_rounded,
                    label:
                        '${request.currency} ${request.budget.toStringAsFixed(0)}',
                    color: color,
                  ),
                  _MetaChip(
                    icon: Icons.priority_high_rounded,
                    label: _priorityLabel(request.priority),
                    color: _priorityColor(request.priority),
                  ),
                  _MetaChip(
                    icon: Icons.calendar_today_rounded,
                    label: 'Submitted ${formatter.format(request.createdAt)}',
                    color: AppColors.freelancerPrimary,
                  ),
                  _MetaChip(
                    icon: Icons.update_rounded,
                    label: 'Updated ${formatter.format(request.updatedAt)}',
                    color: AppColors.info,
                  ),
                  if (request.deadline != null)
                    _MetaChip(
                      icon: Icons.flag_rounded,
                      label: 'Due ${formatter.format(request.deadline!)}',
                      color: AppColors.warning,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nextClientAction(request),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
      avatar: Icon(icon, size: 16, color: color),
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
  static const active = 'active';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const closed = 'closed';

  static const values = [all, pending, active, delivered, completed, closed];
}

int _deadlineValue(ServiceRequestModel request) {
  return request.deadline?.millisecondsSinceEpoch ?? 8640000000000000;
}

int _statusPriority(String status) {
  return switch (status) {
    ServiceRequestStatus.delivered => 0,
    ServiceRequestStatus.inProgress => 1,
    ServiceRequestStatus.accepted => 2,
    ServiceRequestStatus.pending => 3,
    ServiceRequestStatus.completed => 4,
    _ => 5,
  };
}

String _filterLabel(String filter) {
  return switch (filter) {
    _RequestFilter.pending => 'Pending',
    _RequestFilter.active => 'Active',
    _RequestFilter.delivered => 'Delivered',
    _RequestFilter.completed => 'Completed',
    _RequestFilter.closed => 'Cancelled / Rejected',
    _ => 'All',
  };
}

String _sortLabel(_ClientRequestSort sort) {
  return switch (sort) {
    _ClientRequestSort.deadlineSoon => 'Deadline soon',
    _ClientRequestSort.statusPriority => 'Needs action',
    _ClientRequestSort.newest => 'Newest',
  };
}

String _nextClientAction(ServiceRequestModel request) {
  return switch (request.status) {
    ServiceRequestStatus.pending =>
      'Next action: wait for the freelancer to accept or reject.',
    ServiceRequestStatus.accepted =>
      'Next action: freelancer should start the work.',
    ServiceRequestStatus.inProgress =>
      'Next action: wait for delivery from the freelancer.',
    ServiceRequestStatus.delivered =>
      'Next action: review delivery and mark completed if satisfied.',
    ServiceRequestStatus.completed =>
      'Closed: this request has been completed.',
    ServiceRequestStatus.rejected =>
      'Closed: freelancer rejected this request.',
    ServiceRequestStatus.cancelled => 'Closed: this request was cancelled.',
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

String _statusLabel(String status) {
  return switch (status) {
    ServiceRequestStatus.inProgress => 'In Progress',
    _ => status[0].toUpperCase() + status.substring(1),
  };
}
