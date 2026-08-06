import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/user_role.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/hiring_lifecycle_providers.dart';

class CompanyHiringAnalyticsScreen extends ConsumerWidget {
  const CompanyHiringAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(companyHiringAnalyticsProvider);
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Hiring Analytics',
      subtitle: 'Funnel, conversion, and hiring performance.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyEmployees),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: 'Offer acceptance',
                value: '${analytics.offerAcceptanceRate.toStringAsFixed(1)}%',
              ),
              _Metric(
                label: 'Interview completion',
                value:
                    '${analytics.interviewCompletionRate.toStringAsFixed(1)}%',
              ),
              _Metric(
                label: 'Employee conversion',
                value:
                    '${analytics.employeeConversionRate.toStringAsFixed(1)}%',
              ),
              _Metric(
                label: 'Avg hiring time',
                value: '${analytics.averageHiringDays.toStringAsFixed(1)} days',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Hiring Funnel',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...hiringLifecycleStages.map((stage) {
            final count = analytics.funnelCounts[stage] ?? 0;
            final max = analytics.totalApplications == 0
                ? 1
                : analytics.totalApplications;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(lifecycleStageLabel(stage))),
                      Text('$count'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: count / max,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          Text(
            'Top skills hired',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (analytics.topSkillsHired.isEmpty)
            const Text('No hired skill signals yet.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analytics.topSkillsHired
                  .map((skill) => Chip(label: Text(skill)))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
