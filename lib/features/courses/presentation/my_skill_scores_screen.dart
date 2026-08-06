import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/skill_score_model.dart';
import '../providers/skill_score_provider.dart';
import 'course_premium_widgets.dart';

class MySkillScoresScreen extends ConsumerWidget {
  const MySkillScoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(studentSkillScoresProvider);
    final actionState = ref.watch(skillScoreActionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Verified Skills',
      subtitle: 'Review skill analytics calculated from real LMS activity.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: CoursePremiumBackground(
        child: scoresAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Skill mapping offline',
            message: error.toString(),
          ),
          data: (scores) {
            return CoursePremiumListView(
              maxWidth: 1000,
              children: [
                CourseHeroHeader(
                  icon: Icons.insights_rounded,
                  title: 'Skill Analytics',
                  subtitle:
                      'Real-time capability tracking based on your verified performance in courses and assessments.',
                  trailing: FilledButton.icon(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _recalculate(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: actionState.isLoading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: const Text(
                      'Sync Engine',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (scores.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.psychology_alt_outlined,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Verified Intelligence Found',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Complete assessments and projects to establish your verified skill baseline and synchronize your telemetry.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: actionState.isLoading
                              ? null
                              : () => _recalculate(context, ref),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.auto_graph_rounded),
                          label: const Text(
                            'Force Telemetry Sync',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Analytics Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      if (isWide) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                mainAxisExtent: 260,
                              ),
                          itemCount: scores.length,
                          itemBuilder: (context, index) =>
                              _SkillScoreCard(score: scores[index]),
                        );
                      } else {
                        return Column(
                          children: scores
                              .map(
                                (score) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _SkillScoreCard(score: score),
                                ),
                              )
                              .toList(),
                        );
                      }
                    },
                  ),
                ],
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _recalculate(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(skillScoreActionProvider.notifier)
        .recalculateMySkillScores();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Skill scores recalculated with course details.'
              : ref.read(skillScoreActionProvider.notifier).errorMessage ??
                    'Sync failed.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }
}

class _SkillScoreCard extends StatelessWidget {
  const _SkillScoreCard({required this.score});

  final SkillScoreModel score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (score.score / 100).clamp(0.0, 1.0);

    // Determine badge styling based on level
    Color badgeColor;
    IconData badgeIcon;
    switch (score.level.toLowerCase()) {
      case 'expert':
        badgeColor = Colors.deepPurpleAccent;
        badgeIcon = Icons.diamond_rounded;
        break;
      case 'advanced':
        badgeColor = AppColors.success;
        badgeIcon = Icons.military_tech_rounded;
        break;
      case 'intermediate':
        badgeColor = AppColors.primary;
        badgeIcon = Icons.trending_up_rounded;
        break;
      default:
        badgeColor = theme.colorScheme.onSurfaceVariant;
        badgeIcon = Icons.fitness_center_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.studentSkillScoreDetail,
            pathParameters: {'skillName': score.skillScoreId},
          ),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(badgeIcon, color: badgeColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.skillName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              score.level.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Proficiency',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${score.score.toStringAsFixed(0)}%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(badgeColor),
                  ),
                ),
                const SizedBox(height: 16),
                if (score.sourceCourses.isNotEmpty)
                  Text(
                    score.sourceCourses.length == 1
                        ? 'From: ${score.sourceCourses.first.title}'
                        : 'From ${score.sourceCourses.length} courses: ${score.sourceCourses.take(2).map((c) => c.title).join(', ')}${score.sourceCourses.length > 2 ? '…' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (score.sourceCourses.isNotEmpty) const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MiniPill(
                        label: 'MCQ ${score.mcqAverage.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(width: 8),
                      _MiniPill(
                        label:
                            'Proj ${score.projectAverage.toStringAsFixed(0)}%',
                      ),
                      if (score.grandTestAverage > 0) ...[
                        const SizedBox(width: 8),
                        _MiniPill(
                          label:
                              'Test ${score.grandTestAverage.toStringAsFixed(0)}%',
                        ),
                      ],
                      if (score.certificateBonusApplied) ...[
                        const SizedBox(width: 8),
                        _MiniPill(label: 'Cert Bonus', isAccent: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, this.isAccent = false});

  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent
            ? Colors.amber.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAccent
              ? Colors.amber.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: isAccent
              ? Colors.amber.shade700
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
