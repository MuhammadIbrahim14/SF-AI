import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/application_model.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/job_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/hiring_lifecycle_providers.dart';

enum _EmployeeDirectoryFilter {
  all,
  active,
  joiningSoon,
  hired,
  left,
}

class CompanyEmployeesScreen extends ConsumerStatefulWidget {
  const CompanyEmployeesScreen({super.key});

  @override
  ConsumerState<CompanyEmployeesScreen> createState() =>
      _CompanyEmployeesScreenState();
}

class _CompanyEmployeesScreenState
    extends ConsumerState<CompanyEmployeesScreen> {
  _EmployeeDirectoryFilter _filter = _EmployeeDirectoryFilter.all;
  final _searchCtrl = TextEditingController();
  String _query = '';
  var _remindersStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRemind());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _maybeRemind() async {
    if (_remindersStarted) return;
    _remindersStarted = true;
    final employees = ref.read(companyEmployeesProvider);
    if (employees.isEmpty) return;
    await ref.read(hiringLifecycleActionProvider.notifier).runEmploymentReminders(
          applications: employees,
          asCandidate: false,
        );
  }

  List<ApplicationModel> _applyLocalFilters(List<ApplicationModel> source) {
    Iterable<ApplicationModel> filtered = source;
    filtered = switch (_filter) {
      _EmployeeDirectoryFilter.active =>
        filtered.where((a) => a.isActiveEmployee),
      _EmployeeDirectoryFilter.joiningSoon =>
        filtered.where((a) => a.isJoiningSoon),
      _EmployeeDirectoryFilter.hired => filtered.where(
          (a) =>
              a.normalizedPipelineStage == 'hired' &&
              !a.isActiveEmployee &&
              !a.isJoiningSoon &&
              !a.isLeftEmployee,
        ),
      _EmployeeDirectoryFilter.left =>
        filtered.where((a) => a.isLeftEmployee),
      _EmployeeDirectoryFilter.all => filtered,
    };

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return filtered.toList();

    return filtered.where((app) {
      final user = ref.read(hiringUserProvider(app.applicantId)).asData?.value;
      final job = ref.read(jobDetailProvider(app.jobId)).asData?.value;
      final name = (user?.fullName ?? user?.email ?? '').toLowerCase();
      final title = app.displayJobTitle.toLowerCase();
      final dept = app.displayDepartment.toLowerCase();
      final jobTitle = (job?.title ?? '').toLowerCase();
      return name.contains(q) ||
          title.contains(q) ||
          dept.contains(q) ||
          jobTitle.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(companyEmployeesProvider);
    final analytics = ref.watch(companyHiringAnalyticsProvider);
    final theme = Theme.of(context);
    final visible = _applyLocalFilters(employees);
    final leftCount = employees.where((a) => a.isLeftEmployee).length;
    final hiredPipelineCount = employees
        .where(
          (a) =>
              a.normalizedPipelineStage == 'hired' &&
              !a.isActiveEmployee &&
              !a.isJoiningSoon &&
              !a.isLeftEmployee,
        )
        .length;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Employees',
      subtitle: 'Active employees, pending joins, and onboarding.',
      showBackButton: true,
      scrollable: false,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyDashboard),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                label: 'Active',
                value: '${analytics.activeEmployees}',
                color: AppColors.success,
              ),
              _StatChip(
                label: 'Joining Soon',
                value: '${analytics.pendingJoining}',
                color: AppColors.info,
              ),
              _StatChip(
                label: 'Hired',
                value: '$hiredPipelineCount',
                color: AppColors.primary,
              ),
              _StatChip(
                label: 'Left',
                value: '$leftCount',
                color: AppColors.error,
              ),
              _StatChip(
                label: 'Offers Sent',
                value: '${analytics.offersSent}',
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  context.pushNamed(RouteNames.companyHiringAnalytics),
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Hiring Analytics'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, role, or department',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in _EmployeeDirectoryFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabel(option)),
                      selected: _filter == option,
                      onSelected: (_) => setState(() => _filter = option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (employees.isEmpty)
            _EmptyEmployeesState(
              onOpenPipeline: () =>
                  context.pushNamed(RouteNames.hiringPipeline),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _query.trim().isEmpty
                    ? 'No employees match this filter.'
                    : 'No employees match your search.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...visible.map((app) => _EmployeeRow(application: app)),
        ],
      ),
    );
  }

  String _filterLabel(_EmployeeDirectoryFilter filter) {
    return switch (filter) {
      _EmployeeDirectoryFilter.all => 'All',
      _EmployeeDirectoryFilter.active => 'Active',
      _EmployeeDirectoryFilter.joiningSoon => 'Joining Soon',
      _EmployeeDirectoryFilter.hired => 'Hired',
      _EmployeeDirectoryFilter.left => 'Left',
    };
  }
}

class _EmployeeRow extends ConsumerWidget {
  const _EmployeeRow({required this.application});

  final ApplicationModel application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(hiringUserProvider(application.applicantId));
    final jobAsync = ref.watch(jobDetailProvider(application.jobId));
    final user = userAsync.asData?.value;
    final name = user?.fullName ?? user?.email ?? application.applicantId;
    final photoUrl = user?.photoUrl;
    final jobTitle = application.displayJobTitle.isNotEmpty
        ? application.displayJobTitle
        : (jobAsync.asData?.value?.title ?? 'Role TBD');
    final department = application.displayDepartment;
    final dateLabel = _dateLabel(application);
    final statusColor = _statusColor(application);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage:
              photoUrl != null && photoUrl.trim().isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
          child: photoUrl == null || photoUrl.trim().isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                )
              : null,
        ),
        title: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              department.isEmpty ? jobTitle : '$jobTitle · $department',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (dateLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.28)),
              ),
              child: Text(
                employmentStatusLabel(application.employmentStatus),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.pushNamed(
          RouteNames.companyEmployeeDetail,
          pathParameters: {'applicationId': application.id},
        ),
      ),
    );
  }

  String? _dateLabel(ApplicationModel app) {
    final fmt = DateFormat.yMMMd();
    if (app.joinedAt != null) {
      return 'Joined ${fmt.format(app.joinedAt!)}';
    }
    if (app.offerJoiningDate.trim().isNotEmpty) {
      return 'Joining ${app.offerJoiningDate}';
    }
    if (app.offboarding.leftAt != null) {
      return 'Left ${fmt.format(app.offboarding.leftAt!)}';
    }
    return null;
  }

  Color _statusColor(ApplicationModel app) {
    return switch (app.normalizedEmploymentStatus) {
      'active' => AppColors.success,
      'joining_soon' => AppColors.info,
      'left' => AppColors.error,
      _ => AppColors.primary,
    };
  }
}

class _EmptyEmployeesState extends StatelessWidget {
  const _EmptyEmployeesState({required this.onOpenPipeline});

  final VoidCallback onOpenPipeline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No employees or pending joins yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hire candidates from the Hiring Pipeline, then activate them here after they join.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenPipeline,
            icon: const Icon(Icons.account_tree_rounded),
            label: const Text('Open Hiring Pipeline'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
