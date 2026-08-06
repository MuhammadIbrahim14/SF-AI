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

class SkillScoreDetailScreen extends ConsumerWidget {
  const SkillScoreDetailScreen({super.key, required this.skillName});

  final String skillName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(studentSkillScoreDetailProvider(skillName));
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Skill Analytics',
      subtitle: 'Inspect score evidence and proficiency breakdown.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentSkillScores),
      scrollable: false,
      child: CoursePremiumBackground(
        child: scoreAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Skill score unavailable',
            message: error.toString(),
          ),
          data: (score) {
            if (score == null) {
              return const CoursePremiumMessage(
                icon: Icons.psychology_alt_outlined,
                title: 'Skill score not found',
                message:
                    'Return to the analytics dashboard and force a sync check.',
              );
            }

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

            return CoursePremiumListView(
              maxWidth: 900,
              children: [
                // Hero Section
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest.withValues(
                      alpha: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.05),
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
                          color: badgeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(badgeIcon, size: 64, color: badgeColor),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        score.skillName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          score.level.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: badgeColor,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            score.score.toStringAsFixed(0),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                              fontSize: 80,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 4),
                            child: Text(
                              '%',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'VERIFIED PROFICIENCY SCORE',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Telemetry Updated: ${_dateLabel(score.updatedAt)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Score Breakdown Grid
                Text(
                  'Score Breakdown',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _MetricBox(
                          label: 'MCQ Avg',
                          value: '${score.mcqAverage.toStringAsFixed(0)}%',
                          icon: Icons.quiz_rounded,
                        ),
                        _MetricBox(
                          label: 'Project Avg',
                          value: '${score.projectAverage.toStringAsFixed(0)}%',
                          icon: Icons.code_rounded,
                        ),
                        _MetricBox(
                          label: 'Test Avg',
                          value:
                              '${score.grandTestAverage.toStringAsFixed(0)}%',
                          icon: Icons.workspace_premium_rounded,
                        ),
                        _MetricBox(
                          label: 'Cert Bonus',
                          value: score.certificateBonusApplied
                              ? '+Applied'
                              : 'None',
                          icon: Icons.verified_rounded,
                          isHighlight: score.certificateBonusApplied,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Source Evidence
                Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Verified Source Evidence',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This score is deterministically calculated using only real, verified LMS performance data.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                _EvidenceCard(
                  title: 'Source Courses',
                  icon: Icons.menu_book_rounded,
                  items: score.sourceCourses,
                  emptyText: 'No course evidence recorded.',
                ),
                _EvidenceCard(
                  title: 'Verified Projects & Assignments',
                  icon: Icons.assignment_turned_in_rounded,
                  items: score.sourceAssignments,
                  emptyText: 'No assignment evidence recorded.',
                ),
                _EvidenceCard(
                  title: 'Grand Tests',
                  icon: Icons.workspace_premium_rounded,
                  items: score.sourceGrandTests,
                  emptyText: 'No grand test evidence recorded.',
                ),
                _EvidenceCard(
                  title: 'Certificates Earned',
                  icon: Icons.verified_rounded,
                  items: score.sourceCertificates,
                  emptyText: 'No certificate evidence recorded.',
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.success.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight
              ? AppColors.success.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          if (!isHighlight)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isHighlight
                    ? AppColors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: isHighlight
                        ? AppColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isHighlight
                  ? AppColors.success
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<SkillSourceRef> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ...items.map((item) => _EvidenceRow(item: item)),
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item});

  final SkillSourceRef item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseLabel = item.courseTitle.trim().isNotEmpty
        ? item.courseTitle.trim()
        : (item.courseId.trim().isNotEmpty ? item.courseId : '');
    final subtitle = item.subtitle.trim().isNotEmpty
        ? item.subtitle.trim()
        : (courseLabel.isNotEmpty ? 'From: $courseLabel' : '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (courseLabel.isNotEmpty &&
              !subtitle.toLowerCase().contains(courseLabel.toLowerCase())) ...[
            const SizedBox(height: 4),
            Text(
              'Course: $courseLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
