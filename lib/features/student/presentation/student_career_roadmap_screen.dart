import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/career_roadmap_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/career_roadmap_provider.dart';

class StudentCareerRoadmapScreen extends ConsumerWidget {
  const StudentCareerRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(studentCareerRoadmapProvider);
    final gapAsync = ref.watch(studentSkillGapProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Career Roadmap',
      subtitle: 'Verified skill gap analysis for your target role.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentCareerRoadmapProvider);
          ref.invalidate(studentSkillGapProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            roadmapAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InfoPanel(
                icon: Icons.warning_rounded,
                title: 'Roadmap unavailable',
                message: error.toString(),
              ),
              data: (roadmap) => _TargetRoleCard(roadmap: roadmap),
            ),
            const SizedBox(height: 18),
            gapAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InfoPanel(
                icon: Icons.warning_rounded,
                title: 'Skill gap unavailable',
                message: error.toString(),
              ),
              data: (analysis) => _SkillGapContent(analysis: analysis),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetRoleCard extends ConsumerStatefulWidget {
  const _TargetRoleCard({required this.roadmap});

  final CareerRoadmapModel? roadmap;

  @override
  ConsumerState<_TargetRoleCard> createState() => _TargetRoleCardState();
}

class _TargetRoleCardState extends ConsumerState<_TargetRoleCard> {
  late String _targetRole;

  @override
  void initState() {
    super.initState();
    _targetRole = widget.roadmap?.targetRole ?? careerTargetSkills.keys.first;
  }

  @override
  void didUpdateWidget(covariant _TargetRoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.roadmap?.targetRole;
    if (next != null && next != _targetRole) _targetRole = next;
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(careerRoadmapActionProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final selector = DropdownButtonFormField<String>(
            initialValue: _targetRole,
            items: [
              for (final role in careerTargetSkills.keys)
                DropdownMenuItem(value: role, child: Text(role)),
            ],
            onChanged: actionState.isLoading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _targetRole = value);
                  },
            decoration: const InputDecoration(labelText: 'Target career'),
          );
          final button = FilledButton.icon(
            onPressed: actionState.isLoading
                ? null
                : () async {
                    final success = await ref
                        .read(careerRoadmapActionProvider.notifier)
                        .saveTargetRole(_targetRole);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Roadmap updated from verified progress.'
                              : 'Unable to update roadmap.',
                        ),
                      ),
                    );
                  },
            icon: actionState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_rounded),
            label: const Text('Update Roadmap'),
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TargetIntro(roadmap: widget.roadmap),
                const SizedBox(height: 14),
                selector,
                const SizedBox(height: 12),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _TargetIntro(roadmap: widget.roadmap)),
              const SizedBox(width: 18),
              SizedBox(width: 280, child: selector),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _TargetIntro extends StatelessWidget {
  const _TargetIntro({required this.roadmap});

  final CareerRoadmapModel? roadmap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roadmap == null ? 'Choose your target role' : roadmap!.targetRole,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Only verified evidence counts: passed assignments, graded projects, grand tests, certificates, and calculated skill scores. Viewed lessons do not inflate mastery.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SkillGapContent extends StatelessWidget {
  const _SkillGapContent({required this.analysis});

  final SkillGapAnalysisModel analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressPanel(analysis: analysis),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final panels = [
              _SkillPanel(
                title: 'Mastered Skills',
                empty: 'No verified mastered skills yet.',
                skills: analysis.masteredSkills,
                color: AppColors.success,
              ),
              _SkillPanel(
                title: 'Weak Skills',
                empty: 'No weak verified skills detected.',
                skills: analysis.weakSkills,
                color: AppColors.warning,
              ),
              _SkillPanel(
                title: 'Missing Skills',
                empty: 'No missing target skills. Strong work.',
                skills: analysis.missingSkills,
                color: AppColors.error,
              ),
            ];
            if (!wide) {
              return Column(
                children: [
                  for (final panel in panels) ...[
                    panel,
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final panel in panels) ...[
                  Expanded(child: panel),
                  if (panel != panels.last) const SizedBox(width: 14),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _RecommendationsPanel(analysis: analysis),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.analysis});

  final SkillGapAnalysisModel analysis;

  @override
  Widget build(BuildContext context) {
    final progress = analysis.progressPercent.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${progress.round()}% ready for ${analysis.targetRole}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 12),
          Text(
            '${analysis.masteredSkills.length}/${analysis.requiredSkills.length} target skills verified.',
          ),
        ],
      ),
    );
  }
}

class _SkillPanel extends StatelessWidget {
  const _SkillPanel({
    required this.title,
    required this.empty,
    required this.skills,
    required this.color,
  });

  final String title;
  final String empty;
  final List<String> skills;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            Text(empty)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in skills)
                  Chip(
                    label: Text(skill),
                    backgroundColor: color.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecommendationsPanel extends StatelessWidget {
  const _RecommendationsPanel({required this.analysis});

  final SkillGapAnalysisModel analysis;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...analysis.recommendedCourses.map((item) => 'Course: $item'),
      ...analysis.recommendedProjects.map((item) => 'Project: $item'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Next Steps',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Keep completing verified projects and assessments.')
          else
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.arrow_forward_rounded),
                title: Text(item),
              ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: AppColors.studentPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}
