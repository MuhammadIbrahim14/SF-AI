// ignore_for_file: unused_element_parameter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/admin_monetization_providers.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/providers/payment_providers.dart';
import '../../courses/presentation/marketplace_admin_widgets.dart';
import 'widgets/admin_control_scaffold.dart';

const _tabContentPadding = EdgeInsets.fromLTRB(20, 4, 20, 28);

class MonetizationCenterScreen extends ConsumerWidget {
  const MonetizationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: AdminControlScaffold(
        title: 'Monetization Center',
        subtitle:
            'Teacher plans, AI credit packs, transactions, and marketplace revenue.',
        currentPath: RoutePaths.adminMonetization,
        body: const Column(
          children: [
            _MonetizationTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _PlansTab(),
                  _CreditPacksTab(),
                  _TransactionsTab(),
                  _MarketplaceTab(),
                  _DashboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonetizationTabBar extends StatelessWidget {
  const _MonetizationTabBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: colorScheme.onPrimaryContainer,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          indicator: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          tabs: const [
            Tab(text: 'Plans'),
            Tab(text: 'Credit Packs'),
            Tab(text: 'Transactions'),
            Tab(text: 'Marketplace'),
            Tab(text: 'Dashboard'),
          ],
        ),
      ),
    );
  }
}

/// Shared header used at the top of a monetization tab, styled like the rest of
/// the admin control screens.
class _TabIntro extends StatelessWidget {
  const _TabIntro({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return AdminPanelCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) return header;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 16), action!],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: header),
              const SizedBox(width: 16),
              action!,
            ],
          );
        },
      ),
    );
  }
}

class _PlansTab extends ConsumerWidget {
  const _PlansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plansAsync = ref.watch(adminPlansProvider);
    return plansAsync.when(
      data: (plans) => ListView(
        padding: _tabContentPadding,
        children: [
          _TabIntro(
            icon: Icons.workspace_premium_rounded,
            title: 'Teacher subscription plans',
            message:
                'Build premium plans with limits, AI credits, and billing cadence that teachers can purchase directly.',
            action: FilledButton.icon(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const _PlanCreateDialog(),
                );
                if (!context.mounted) return;
                ref.invalidate(adminPlansProvider);
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Create plan'),
            ),
          ),
          const SizedBox(height: 16),
          if (plans.isEmpty)
            const DashboardEmptyState(
              icon: Icons.workspace_premium_outlined,
              title: 'No plans published yet',
              message:
                  'Create a plan to give teachers a paid tier with course, lesson, and AI credit limits.',
            )
          else
            ...plans.map((plan) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AdminPanelCard(
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
                                Text(
                                  plan.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plan.description.isEmpty
                                      ? 'Premium teacher subscription'
                                      : plan.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _PlanStatusChip(isActive: plan.isActive),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        children: [
                          Text(
                            '${plan.currency} ${plan.price.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            '/ ${plan.interval}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: plan.features
                            .map(
                              (feature) => Chip(
                                label: Text(feature.replaceAll('_', ' ')),
                                labelStyle: theme.textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                backgroundColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LimitPill(label: 'Courses', value: plan.maxPublishedCourses.toString()),
                          _LimitPill(label: 'Lessons', value: plan.maxLessonsPerCourse.toString()),
                          _LimitPill(label: 'Assignments', value: plan.maxAssignmentsPerCourse.toString()),
                          _LimitPill(label: 'AI credits', value: '${plan.maxAiCreditsPerMonth}/mo'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (_) => _PlanEditDialog(plan: plan),
                              );
                              if (!context.mounted) return;
                              ref.invalidate(adminPlansProvider);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final updated = PaymentPlanModel(
                                planId: plan.planId,
                                name: plan.name,
                                description: plan.description,
                                price: plan.price,
                                currency: plan.currency,
                                interval: plan.interval,
                                features: plan.features,
                                isActive: !plan.isActive,
                                maxPublishedCourses: plan.maxPublishedCourses,
                                maxLessonsPerCourse: plan.maxLessonsPerCourse,
                                maxAssignmentsPerCourse: plan.maxAssignmentsPerCourse,
                                maxProjectsPerCourse: plan.maxProjectsPerCourse,
                                maxGrandTestsPerCourse: plan.maxGrandTestsPerCourse,
                                maxAiCreditsPerMonth: plan.maxAiCreditsPerMonth,
                                allowPaidCourses: plan.allowPaidCourses,
                                allowAnalytics: plan.allowAnalytics,
                                createdAt: plan.createdAt,
                                updatedAt: DateTime.now(),
                              );
                              await ref.read(paymentRepositoryProvider).upsertPlan(updated);
                              ref.invalidate(adminPlansProvider);
                            },
                            icon: Icon(
                              plan.isActive
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            label: Text(plan.isActive ? 'Hide' : 'Show'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Padding(
        padding: _tabContentPadding,
        child: DashboardEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Plans unavailable',
          message: 'Could not load subscription plans. Try again in a moment.',
        ),
      ),
    );
  }
}

class _PlanStatusChip extends StatelessWidget {
  const _PlanStatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'PAUSED',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LimitPill extends StatelessWidget {
  const _LimitPill({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlanCreateDialog extends ConsumerStatefulWidget {
  const _PlanCreateDialog({super.key});

  @override
  ConsumerState<_PlanCreateDialog> createState() => _PlanCreateDialogState();
}

class _PlanCreateDialogState extends ConsumerState<_PlanCreateDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _maxCourses = TextEditingController(text: '10');
  final TextEditingController _maxLessons = TextEditingController(text: '100');
  final TextEditingController _maxAssignments = TextEditingController(text: '50');
  final TextEditingController _maxProjects = TextEditingController(text: '20');
  final TextEditingController _maxGrandTests = TextEditingController(text: '10');
  final TextEditingController _aiCredits = TextEditingController(text: '2500');
  String _currency = 'USD';
  String _interval = 'monthly';
  bool _allowPaidCourses = true;
  bool _allowAnalytics = true;
  bool get _isValid =>
      _name.text.trim().isNotEmpty && (double.tryParse(_price.text) ?? 0) >= 0;

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _maxCourses.dispose();
    _maxLessons.dispose();
    _maxAssignments.dispose();
    _maxProjects.dispose();
    _maxGrandTests.dispose();
    _aiCredits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Create plan'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => _onChanged(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _onChanged(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      items: const ['USD', 'EUR', 'PKR']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                      decoration: const InputDecoration(labelText: 'Currency'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _interval,
                      items: const ['monthly', 'yearly']
                          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _interval = v ?? 'monthly'),
                      decoration: const InputDecoration(labelText: 'Interval'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Teaching limits',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxCourses,
                      decoration: const InputDecoration(labelText: 'Courses'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxLessons,
                      decoration: const InputDecoration(labelText: 'Lessons'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxAssignments,
                      decoration:
                          const InputDecoration(labelText: 'Assignments'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxProjects,
                      decoration: const InputDecoration(labelText: 'Projects'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxGrandTests,
                      decoration:
                          const InputDecoration(labelText: 'Grand tests'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _aiCredits,
                      decoration:
                          const InputDecoration(labelText: 'AI credits/mo'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow paid courses'),
                value: _allowPaidCourses,
                onChanged: (v) => setState(() => _allowPaidCourses = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow analytics'),
                value: _allowAnalytics,
                onChanged: (v) => setState(() => _allowAnalytics = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid
              ? () async {
                  final now = DateTime.now();
                  final features = <String>[
                    if (_allowAnalytics) 'analytics',
                    if (_allowPaidCourses) 'paid_courses',
                    'ai_assistant',
                    'priority_support',
                  ];
                  final plan = PaymentPlanModel(
                    planId: 'plan_${now.microsecondsSinceEpoch}',
                    name: _name.text.isNotEmpty ? _name.text : 'Plan',
                    description: _description.text,
                    price: double.tryParse(_price.text) ?? 0,
                    currency: _currency,
                    interval: _interval,
                    features: features,
                    isActive: true,
                    maxPublishedCourses:
                        int.tryParse(_maxCourses.text) ?? 10,
                    maxLessonsPerCourse:
                        int.tryParse(_maxLessons.text) ?? 100,
                    maxAssignmentsPerCourse:
                        int.tryParse(_maxAssignments.text) ?? 50,
                    maxProjectsPerCourse:
                        int.tryParse(_maxProjects.text) ?? 20,
                    maxGrandTestsPerCourse:
                        int.tryParse(_maxGrandTests.text) ?? 10,
                    maxAiCreditsPerMonth:
                        int.tryParse(_aiCredits.text) ?? 2500,
                    allowPaidCourses: _allowPaidCourses,
                    allowAnalytics: _allowAnalytics,
                    createdAt: now,
                    updatedAt: now,
                  );
                  await ref.read(paymentRepositoryProvider).upsertPlan(plan);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PlanEditDialog extends ConsumerStatefulWidget {
  const _PlanEditDialog({required this.plan, super.key});
  final PaymentPlanModel plan;

  @override
  ConsumerState<_PlanEditDialog> createState() => _PlanEditDialogState();
}

class _PlanEditDialogState extends ConsumerState<_PlanEditDialog> {
  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _description;
  late TextEditingController _maxCourses;
  late TextEditingController _maxLessons;
  late TextEditingController _maxAssignments;
  late TextEditingController _maxProjects;
  late TextEditingController _maxGrandTests;
  late TextEditingController _aiCredits;
  late bool _allowPaidCourses;
  late bool _allowAnalytics;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name = TextEditingController(text: plan.name);
    _price = TextEditingController(text: plan.price.toString());
    _description = TextEditingController(text: plan.description);
    _maxCourses =
        TextEditingController(text: plan.maxPublishedCourses.toString());
    _maxLessons =
        TextEditingController(text: plan.maxLessonsPerCourse.toString());
    _maxAssignments =
        TextEditingController(text: plan.maxAssignmentsPerCourse.toString());
    _maxProjects =
        TextEditingController(text: plan.maxProjectsPerCourse.toString());
    _maxGrandTests =
        TextEditingController(text: plan.maxGrandTestsPerCourse.toString());
    _aiCredits =
        TextEditingController(text: plan.maxAiCreditsPerMonth.toString());
    _allowPaidCourses = plan.allowPaidCourses;
    _allowAnalytics = plan.allowAnalytics;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _maxCourses.dispose();
    _maxLessons.dispose();
    _maxAssignments.dispose();
    _maxProjects.dispose();
    _maxGrandTests.dispose();
    _aiCredits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit plan'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxCourses,
                      decoration: const InputDecoration(labelText: 'Courses'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxLessons,
                      decoration: const InputDecoration(labelText: 'Lessons'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxAssignments,
                      decoration:
                          const InputDecoration(labelText: 'Assignments'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxProjects,
                      decoration: const InputDecoration(labelText: 'Projects'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxGrandTests,
                      decoration:
                          const InputDecoration(labelText: 'Grand tests'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _aiCredits,
                      decoration:
                          const InputDecoration(labelText: 'AI credits/mo'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow paid courses'),
                value: _allowPaidCourses,
                onChanged: (v) => setState(() => _allowPaidCourses = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow analytics'),
                value: _allowAnalytics,
                onChanged: (v) => setState(() => _allowAnalytics = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final updated = PaymentPlanModel(
              planId: widget.plan.planId,
              name: _name.text,
              description: _description.text,
              price: double.tryParse(_price.text) ?? widget.plan.price,
              currency: widget.plan.currency,
              interval: widget.plan.interval,
              features: [
                if (_allowAnalytics) 'analytics',
                if (_allowPaidCourses) 'paid_courses',
                'ai_assistant',
                'priority_support',
              ],
              isActive: widget.plan.isActive,
              maxPublishedCourses:
                  int.tryParse(_maxCourses.text) ?? widget.plan.maxPublishedCourses,
              maxLessonsPerCourse:
                  int.tryParse(_maxLessons.text) ?? widget.plan.maxLessonsPerCourse,
              maxAssignmentsPerCourse: int.tryParse(_maxAssignments.text) ??
                  widget.plan.maxAssignmentsPerCourse,
              maxProjectsPerCourse: int.tryParse(_maxProjects.text) ??
                  widget.plan.maxProjectsPerCourse,
              maxGrandTestsPerCourse: int.tryParse(_maxGrandTests.text) ??
                  widget.plan.maxGrandTestsPerCourse,
              maxAiCreditsPerMonth: int.tryParse(_aiCredits.text) ??
                  widget.plan.maxAiCreditsPerMonth,
              allowPaidCourses: _allowPaidCourses,
              allowAnalytics: _allowAnalytics,
              createdAt: widget.plan.createdAt,
              updatedAt: DateTime.now(),
            );
            await ref.read(paymentRepositoryProvider).upsertPlan(updated);
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CreditPacksTab extends ConsumerWidget {
  const _CreditPacksTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final packsAsync = ref.watch(adminAllCreditPacksProvider);
    return packsAsync.when(
      data: (packs) => ListView(
        padding: _tabContentPadding,
        children: [
          _TabIntro(
            icon: Icons.toll_rounded,
            title: 'AI credit packs',
            message:
                'One-off credit bundles users can buy on top of their plan allowance.',
            action: FilledButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Create credit pack'),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const _CreditPackCreateDialog(),
                );
                if (!context.mounted) return;
                ref.invalidate(adminAllCreditPacksProvider);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (packs.isEmpty)
            const DashboardEmptyState(
              icon: Icons.toll_outlined,
              title: 'No credit packs yet',
              message:
                  'Create a pack to let users top up AI credits without changing their plan.',
            )
          else
            ...packs.map((pack) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AdminPanelCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pack.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${pack.credits} credits • ${pack.bonusCredits} bonus • ${pack.currency} ${pack.price.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => _CreditPackEditDialog(pack: pack),
                          );
                          if (!context.mounted) return;
                          ref.invalidate(adminAllCreditPacksProvider);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Padding(
        padding: _tabContentPadding,
        child: DashboardEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Credit packs unavailable',
          message: 'Could not load credit packs. Try again in a moment.',
        ),
      ),
    );
  }
}

class _CreditPackCreateDialog extends ConsumerStatefulWidget {
  const _CreditPackCreateDialog({super.key});

  @override
  ConsumerState<_CreditPackCreateDialog> createState() => _CreditPackCreateDialogState();
}

class _CreditPackCreateDialogState extends ConsumerState<_CreditPackCreateDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _credits = TextEditingController();
  final TextEditingController _bonus = TextEditingController();
  bool get _isValidPack => _name.text.trim().isNotEmpty && (double.tryParse(_price.text) ?? 0) > 0 && (int.tryParse(_credits.text) ?? 0) > 0;
  void _onPackChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _credits.dispose();
    _bonus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Create credit pack'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), onChanged: (_) => _onPackChanged()),
            const SizedBox(height: 8),
            TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number, onChanged: (_) => _onPackChanged()),
            const SizedBox(height: 8),
            TextField(controller: _credits, decoration: const InputDecoration(labelText: 'Credits'), keyboardType: TextInputType.number, onChanged: (_) => _onPackChanged()),
            const SizedBox(height: 8),
            TextField(controller: _bonus, decoration: const InputDecoration(labelText: 'Bonus Credits'), keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isValidPack
              ? () async {
                  final now = DateTime.now();
                  final pack = CreditPackModel(
                    packId: 'pack_${now.microsecondsSinceEpoch}',
                    name: _name.text.isNotEmpty ? _name.text : 'Pack',
                    description: '',
                    credits: int.tryParse(_credits.text) ?? 0,
                    bonusCredits: int.tryParse(_bonus.text) ?? 0,
                    price: double.tryParse(_price.text) ?? 0,
                    currency: 'USD',
                    isActive: true,
                    createdAt: now,
                    updatedAt: now,
                  );
                  await ref.read(paymentRepositoryProvider).upsertCreditPack(pack);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CreditPackEditDialog extends ConsumerStatefulWidget {
  const _CreditPackEditDialog({required this.pack, super.key});
  final CreditPackModel pack;

  @override
  ConsumerState<_CreditPackEditDialog> createState() => _CreditPackEditDialogState();
}

class _CreditPackEditDialogState extends ConsumerState<_CreditPackEditDialog> {
  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _credits;
  late TextEditingController _bonus;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pack.name);
    _price = TextEditingController(text: widget.pack.price.toString());
    _credits = TextEditingController(text: widget.pack.credits.toString());
    _bonus = TextEditingController(text: widget.pack.bonusCredits.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _credits.dispose();
    _bonus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit credit pack'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price')),
            const SizedBox(height: 8),
            TextField(controller: _credits, decoration: const InputDecoration(labelText: 'Credits')),
            const SizedBox(height: 8),
            TextField(controller: _bonus, decoration: const InputDecoration(labelText: 'Bonus Credits')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final updated = CreditPackModel(
              packId: widget.pack.packId,
              name: _name.text,
              description: widget.pack.description,
              credits: int.tryParse(_credits.text) ?? widget.pack.credits,
              bonusCredits: int.tryParse(_bonus.text) ?? widget.pack.bonusCredits,
              price: double.tryParse(_price.text) ?? widget.pack.price,
              currency: widget.pack.currency,
              isActive: widget.pack.isActive,
              createdAt: widget.pack.createdAt,
              updatedAt: DateTime.now(),
            );
            await ref.read(paymentRepositoryProvider).upsertCreditPack(updated);
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _MarketplaceTab extends ConsumerWidget {
  const _MarketplaceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: _tabContentPadding,
      children: const [
        _TabIntro(
          icon: Icons.storefront_rounded,
          title: 'Course marketplace',
          message: 'Configure paid-course marketplace settings and review sales.',
        ),
        SizedBox(height: 16),
        MarketplaceOverviewCard(),
        SizedBox(height: 16),
        AdminSalesOverview(),
      ],
    );
  }
}

class _TransactionsTab extends ConsumerWidget {
  const _TransactionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(adminTransactionsProvider(const {}));
    final paymentsAsync = ref.watch(adminPaymentsProvider(const {'status': PaymentStatus.success}));

    return ListView(
      padding: _tabContentPadding,
      children: [
        txAsync.when(
          data: (txs) => _TransactionSection(
            title: 'Recent transactions',
            icon: Icons.swap_horiz_rounded,
            emptyMessage: 'No transactions yet.',
            children: txs
                .take(8)
                .map(
                  (tx) => _TransactionTile(
                    title: tx.description,
                    subtitle: '${tx.gateway} • ${tx.status}',
                    value: '${tx.currency} ${tx.amount.toStringAsFixed(2)}',
                  ),
                )
                .toList(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        paymentsAsync.when(
          data: (payments) => _TransactionSection(
            title: 'Purchases history',
            icon: Icons.receipt_long_rounded,
            emptyMessage: 'No completed purchases yet.',
            children: payments
                .take(8)
                .map(
                  (payment) => _TransactionTile(
                    title: payment.description,
                    subtitle: payment.type,
                    value:
                        '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                    status: payment.status,
                  ),
                )
                .toList(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TransactionSection extends StatelessWidget {
  const _TransactionSection({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AdminPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Text(
              emptyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    this.status,
  });

  final String title;
  final String subtitle;
  final String value;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        tileColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (status != null)
                Text(
                  status!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue30 = ref.watch(revenueSummaryProvider(30));
    final activeSubs = ref.watch(adminActiveSubscriptionsProvider);
    final pendingPayments = ref.watch(adminPendingPaymentsProvider);

    return SingleChildScrollView(
      padding: _tabContentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TabIntro(
            icon: Icons.insights_rounded,
            title: 'Monetization overview',
            message:
                'Live revenue, subscription, and payment counters for the current deployment.',
          ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            minChildWidth: 240,
            children: [
              revenue30.when(
                data: (total) => _MetricCard(
                  title: 'Revenue (30d)',
                  value: 'USD ${total.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success,
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              activeSubs.when(
                data: (list) => _MetricCard(
                  title: 'Active subscriptions',
                  value: list.length.toString(),
                  icon: Icons.repeat_rounded,
                  color: AppColors.info,
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              pendingPayments.when(
                data: (list) => _MetricCard(
                  title: 'Pending payments',
                  value: list.length.toString(),
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warning,
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminPanelCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
