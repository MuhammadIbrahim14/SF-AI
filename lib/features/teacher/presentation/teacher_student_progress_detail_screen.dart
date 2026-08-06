import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/dashboard_section.dart';
import '../../../shared/widgets/dashboard_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/role_theme.dart';
import '../data/models/teacher_student_progress_model.dart';
import '../providers/teacher_student_progress_provider.dart';

class TeacherStudentProgressDetailScreen extends ConsumerWidget {
  const TeacherStudentProgressDetailScreen({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      teacherStudentProgressDetailProvider(studentId),
    );
    final roleTheme = getRoleTheme(UserRole.teacher);

    return RoleDashboardFrame(
      role: UserRole.teacher,
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DashboardEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Student detail unavailable',
          message: 'We could not load this learner profile right now.',
          actionLabel: 'Retry',
          onAction: () =>
              ref.invalidate(teacherStudentProgressDetailProvider(studentId)),
        ),
        data: (detail) {
          if (detail == null) {
            return const DashboardEmptyState(
              icon: Icons.person_search_rounded,
              title: 'Student not found',
              message:
                  'This learner is not enrolled in one of your active course records.',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _DetailHero(detail: detail, roleTheme: roleTheme),
              DashboardSection(
                title: 'Performance Snapshot',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _MetricsGrid(
                    metrics: [
                      _MetricSpec(
                        title: 'Avg Progress',
                        value: '${detail.averageProgress.toStringAsFixed(0)}%',
                        icon: Icons.trending_up_rounded,
                        color: roleTheme.primary,
                      ),
                      _MetricSpec(
                        title: 'Avg Score',
                        value: '${detail.averageScore.toStringAsFixed(0)}%',
                        icon: Icons.grade_rounded,
                        color: roleTheme.secondary,
                      ),
                      _MetricSpec(
                        title: 'Lessons',
                        value:
                            '${detail.completedLessons}/${detail.totalLessons}',
                        icon: Icons.play_circle_rounded,
                        color: roleTheme.primary,
                      ),
                      _MetricSpec(
                        title: 'Certificates',
                        value: detail.certificatesEarned.toString(),
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
              DashboardSection(
                title: 'Course Progress',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      for (final record in detail.records) ...[
                        _CourseProgressCard(record: record),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
              DashboardSection(
                title: 'Skill Scores',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: detail.skillScores.isEmpty
                      ? const DashboardEmptyState(
                          icon: Icons.psychology_outlined,
                          title: 'No skill scores yet',
                          message:
                              'Skill score evidence appears after assignments, grand tests, certificates, or resume intelligence updates.',
                        )
                      : _SkillScoreGrid(skills: detail.skillScores),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.detail, required this.roleTheme});

  final TeacherStudentProgressDetailModel detail;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final worstRisk = detail.records.any((item) => item.isAtRisk)
        ? TeacherProgressRisk.atRisk
        : detail.records.any((item) => item.needsAttention)
        ? TeacherProgressRisk.needsAttention
        : TeacherProgressRisk.healthy;
    final color = _riskColor(worstRisk);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              roleTheme.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Text(
                detail.studentName.isEmpty
                    ? '?'
                    : detail.studentName[0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.studentName,
                    style: AppTypography.headlineSmall.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail.studentEmail,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatusPill(
                    label: TeacherProgressRisk.label(worstRisk),
                    color: color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.record});

  final TeacherStudentProgressModel record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final riskColor = _riskColor(record.riskStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.courseTitle,
                  style: AppTypography.titleMedium.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusPill(
                label: TeacherProgressRisk.label(record.riskStatus),
                color: riskColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ProgressTile(
                label: 'Lessons',
                value: record.lessonProgress,
                subtitle:
                    '${record.completedLessons}/${record.totalLessons} completed',
              ),
              _ProgressTile(
                label: 'Assignments',
                value: record.assignmentCompletion,
                subtitle:
                    '${record.completedAssignments}/${record.totalAssignments} complete',
              ),
              _InfoTile(
                label: 'Average Score',
                value: '${record.averageScore.toStringAsFixed(0)}%',
              ),
              _InfoTile(label: 'Project', value: _title(record.projectStatus)),
              _InfoTile(
                label: 'Grand Test',
                value: _title(record.grandTestStatus),
              ),
              _InfoTile(
                label: 'Certificate',
                value: _title(record.certificateStatus),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in record.riskReasons)
                _ReasonChip(reason: reason),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillScoreGrid extends StatelessWidget {
  const _SkillScoreGrid({required this.skills});

  final List<TeacherStudentSkillSnapshot> skills;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 3,
      wideColumns: 4,
      children: [for (final skill in skills) _SkillCard(skill: skill)],
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});

  final TeacherStudentSkillSnapshot skill;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            skill.skillName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleSmall.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (skill.score / 100).clamp(0, 1)),
          const SizedBox(height: 8),
          Text(
            '${skill.score.toStringAsFixed(0)}% • ${skill.level}',
            style: AppTypography.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final double value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (value / 100).clamp(0, 1)),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(0)}% • $subtitle',
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reason,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_MetricSpec> metrics;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      wideColumns: 4,
      children: [
        for (final item in metrics)
          MetricCard(
            title: item.title,
            value: item.value,
            icon: item.icon,
            color: item.color,
          ),
      ],
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

Color _riskColor(String value) {
  return switch (value) {
    TeacherProgressRisk.atRisk => AppColors.error,
    TeacherProgressRisk.needsAttention => AppColors.warning,
    _ => AppColors.success,
  };
}

String _title(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
