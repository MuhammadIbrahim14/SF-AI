import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/application_model.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/job_provider.dart';
import '../../../../providers/user_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../../company/hiring_lifecycle/providers/hiring_lifecycle_providers.dart';

class MyEmploymentScreen extends ConsumerStatefulWidget {
  const MyEmploymentScreen({super.key});

  @override
  ConsumerState<MyEmploymentScreen> createState() => _MyEmploymentScreenState();
}

class _MyEmploymentScreenState extends ConsumerState<MyEmploymentScreen> {
  var _remindersStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRemind());
  }

  Future<void> _maybeRemind() async {
    if (_remindersStarted) return;
    _remindersStarted = true;
    final apps = ref.read(myEmploymentProvider);
    if (apps.isEmpty) return;
    await ref.read(hiringLifecycleActionProvider.notifier).runEmploymentReminders(
          applications: apps,
          asCandidate: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final employment = ref.watch(myEmploymentProvider);
    final currentRole =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.freelancer;
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: currentRole,
      title: 'My Employment',
      subtitle: 'Offers accepted, onboarding, and active roles.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              currentRole == UserRole.student
                  ? RouteNames.studentDashboard
                  : RouteNames.freelancerDashboard,
            ),
      scrollable: false,
      child: employment.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 56,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No employment yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When you accept an offer or join a company, it will appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () =>
                          context.pushNamed(RouteNames.myApplications),
                      child: const Text('Open applications'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: employment.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final app = employment[index];
                return _EmploymentHomeTile(app: app);
              },
            ),
    );
  }
}

class _EmploymentHomeTile extends ConsumerWidget {
  const _EmploymentHomeTile({required this.app});

  final ApplicationModel app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobAsync = ref.watch(jobDetailProvider(app.jobId));
    final jobTitle = jobAsync.asData?.value?.title ?? app.displayJobTitle;
    final checklist = app.onboardingChecklist;
    final done = checklist.where((i) => i.completed).length;
    final pct = checklist.isEmpty
        ? 0
        : ((done / checklist.length) * 100).round();
    final next = _nextAction(app);

    return Material(
      color: AppColors.primary.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.pushNamed(
          RouteNames.myEmploymentDetail,
          pathParameters: {'applicationId': app.id},
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
                      jobTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(employmentStatusLabel(app.employmentStatus)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                app.displayDepartment.isEmpty
                    ? app.displayJobTitle
                    : '${app.displayJobTitle} · ${app.displayDepartment}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!app.isLeftEmployee) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: checklist.isEmpty ? 0 : done / checklist.length,
                ),
                const SizedBox(height: 6),
                Text('Onboarding $pct% · Next: $next'),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Employment ended — view history'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _nextAction(ApplicationModel app) {
    if (app.isLeftEmployee) return 'View ended employment';
    if (app.isJoiningSoon) return 'Prepare to join';
    for (final item in app.onboardingChecklist) {
      if (!item.completed && item.isCandidateCompletable) {
        return item.title;
      }
    }
    if (!app.welcomePack.isPublished) return 'Wait for welcome pack';
    return 'Stay in touch with HR';
  }
}
