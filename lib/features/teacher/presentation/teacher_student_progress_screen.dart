import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import '../../../shared/widgets/dashboard_section.dart';
import '../../../shared/widgets/dashboard_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/role_theme.dart';
import '../data/models/teacher_student_progress_model.dart';
import '../providers/teacher_student_progress_provider.dart';

class TeacherStudentProgressScreen extends ConsumerStatefulWidget {
  const TeacherStudentProgressScreen({super.key});

  @override
  ConsumerState<TeacherStudentProgressScreen> createState() =>
      _TeacherStudentProgressScreenState();
}

class _TeacherStudentProgressScreenState
    extends ConsumerState<TeacherStudentProgressScreen> {
  String _courseId = 'all';
  String _risk = 'all';
  String _progress = 'all';
  String _grandTest = 'all';
  String _certificate = 'all';

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(teacherStudentProgressProvider);
    final roleTheme = getRoleTheme(UserRole.teacher);

    return RoleDashboardFrame(
      role: UserRole.teacher,
      child: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DashboardEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Student analytics unavailable',
          message:
              'We could not load student progress right now. Pull back and retry.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(teacherStudentProgressProvider),
        ),
        data: (records) {
          final filtered = _applyFilters(records);
          final summaries = _studentSummaries(records);
          final filteredSummaries = _studentSummaries(filtered);
          final courses = {
            for (final item in records) item.courseId: item.courseTitle,
          };
          final atRisk = summaries.where((item) => item.isAtRisk).length;
          final needsAttention = summaries
              .where((item) => item.needsAttention)
              .length;
          final healthy = summaries
              .where((item) => item.riskStatus == TeacherProgressRisk.healthy)
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teacherStudentProgressProvider);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _HeroHeader(
                  totalStudents: records
                      .map((item) => item.studentId)
                      .toSet()
                      .length,
                  totalRecords: records.length,
                  roleTheme: roleTheme,
                ),
                DashboardSection(
                  title: 'Progress Health',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _MetricsGrid(
                      metrics: [
                        _MetricSpec(
                          title: 'At Risk',
                          value: atRisk.toString(),
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.error,
                        ),
                        _MetricSpec(
                          title: 'Needs Attention',
                          value: needsAttention.toString(),
                          icon: Icons.volunteer_activism_rounded,
                          color: AppColors.warning,
                        ),
                        _MetricSpec(
                          title: 'Healthy',
                          value: healthy.toString(),
                          icon: Icons.health_and_safety_rounded,
                          color: AppColors.success,
                        ),
                        _MetricSpec(
                          title: 'Avg Progress',
                          value:
                              '${_averageSummary(summaries, (item) => item.averageProgress).toStringAsFixed(0)}%',
                          icon: Icons.trending_up_rounded,
                          color: roleTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const DashboardSection(
                  title: 'Risk Guide',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: _RiskGuide(),
                  ),
                ),
                DashboardSection(
                  title: 'Data Filters',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _FilterPanel(
                      courseId: _courseId,
                      risk: _risk,
                      progress: _progress,
                      grandTest: _grandTest,
                      certificate: _certificate,
                      courses: courses,
                      onCourseChanged: (value) =>
                          setState(() => _courseId = value),
                      onRiskChanged: (value) => setState(() => _risk = value),
                      onProgressChanged: (value) =>
                          setState(() => _progress = value),
                      onGrandTestChanged: (value) =>
                          setState(() => _grandTest = value),
                      onCertificateChanged: (value) =>
                          setState(() => _certificate = value),
                    ),
                  ),
                ),
                DashboardSection(
                  title: 'Students Overview',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: filtered.isEmpty
                        ? const DashboardEmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'No matching students',
                            message:
                                'Adjust filters or wait for learners to enroll in your courses.',
                          )
                        : _StudentProgressGrid(
                            summaries: filteredSummaries,
                            roleTheme: roleTheme,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<TeacherStudentProgressModel> _applyFilters(
    List<TeacherStudentProgressModel> records,
  ) {
    return records.where((item) {
      if (_courseId != 'all' && item.courseId != _courseId) return false;
      if (_risk != 'all' && item.riskStatus != _risk) return false;
      if (_grandTest != 'all' && item.grandTestStatus != _grandTest) {
        return false;
      }
      if (_certificate != 'all' && item.certificateStatus != _certificate) {
        return false;
      }
      if (_progress == '0-39' && item.lessonProgress >= 40) return false;
      if (_progress == '40-69' &&
          (item.lessonProgress < 40 || item.lessonProgress >= 70)) {
        return false;
      }
      if (_progress == '70-100' && item.lessonProgress < 70) return false;
      return true;
    }).toList();
  }

  List<_StudentProgressSummary> _studentSummaries(
    List<TeacherStudentProgressModel> records,
  ) {
    final grouped = <String, List<TeacherStudentProgressModel>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.studentId, () => []).add(record);
    }

    final summaries = grouped.entries
        .map((entry) => _StudentProgressSummary(entry.value))
        .toList();
    summaries.sort((a, b) {
      final riskCompare = _riskRank(
        b.riskStatus,
      ).compareTo(_riskRank(a.riskStatus));
      if (riskCompare != 0) return riskCompare;
      return a.studentName.compareTo(b.studentName);
    });
    return summaries;
  }

  double _averageSummary(
    List<_StudentProgressSummary> summaries,
    double Function(_StudentProgressSummary item) selector,
  ) {
    if (summaries.isEmpty) return 0;
    return summaries.fold<double>(0, (sum, item) => sum + selector(item)) /
        summaries.length;
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.totalStudents,
    required this.totalRecords,
    required this.roleTheme,
  });

  final int totalStudents;
  final int totalRecords;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.elevatedSurface
              : AppColors.lightElevatedSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.divider : AppColors.lightDivider,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: roleTheme.primary.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: roleTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: roleTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.query_stats_rounded,
                color: roleTheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Progress Analytics',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalStudents learners across $totalRecords course enrollments. Track risk, progress, scores, certificates, and grand-test outcomes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
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

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.courseId,
    required this.risk,
    required this.progress,
    required this.grandTest,
    required this.certificate,
    required this.courses,
    required this.onCourseChanged,
    required this.onRiskChanged,
    required this.onProgressChanged,
    required this.onGrandTestChanged,
    required this.onCertificateChanged,
  });

  final String courseId;
  final String risk;
  final String progress;
  final String grandTest;
  final String certificate;
  final Map<String, String> courses;
  final ValueChanged<String> onCourseChanged;
  final ValueChanged<String> onRiskChanged;
  final ValueChanged<String> onProgressChanged;
  final ValueChanged<String> onGrandTestChanged;
  final ValueChanged<String> onCertificateChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _FilterDropdown(
          label: 'Course',
          value: courseId,
          items: {'all': 'All Courses', ...courses},
          onChanged: onCourseChanged,
        ),
        _FilterDropdown(
          label: 'Risk',
          value: risk,
          items: const {
            'all': 'All Risk',
            TeacherProgressRisk.atRisk: 'At Risk',
            TeacherProgressRisk.needsAttention: 'Needs Attention',
            TeacherProgressRisk.healthy: 'Healthy',
          },
          onChanged: onRiskChanged,
        ),
        _FilterDropdown(
          label: 'Progress',
          value: progress,
          items: const {
            'all': 'All Progress',
            '0-39': '0-39%',
            '40-69': '40-69%',
            '70-100': '70-100%',
          },
          onChanged: onProgressChanged,
        ),
        _FilterDropdown(
          label: 'Grand Test',
          value: grandTest,
          items: const {
            'all': 'All Tests',
            'passed': 'Passed',
            'failed': 'Failed',
            'not_attempted': 'Not Attempted',
            'not_available': 'No Test',
          },
          onChanged: onGrandTestChanged,
        ),
        _FilterDropdown(
          label: 'Certificate',
          value: certificate,
          items: const {
            'all': 'All Certificates',
            'issued': 'Issued',
            'not_issued': 'Not Issued',
          },
          onChanged: onCertificateChanged,
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          borderRadius: BorderRadius.circular(16),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final entry in items.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _RiskGuide extends StatelessWidget {
  const _RiskGuide();

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 3,
      wideColumns: 3,
      minChildWidth: 280,
      children: const [
        _RiskGuideCard(
          title: 'At Risk',
          color: AppColors.error,
          icon: Icons.warning_amber_rounded,
          meaning:
              'Low progress, low score, missing project work, or a failed grand test.',
          teacherAction:
              'Teacher should intervene: message the student, review blockers, assign catch-up work, or schedule a support call.',
        ),
        _RiskGuideCard(
          title: 'Needs Attention',
          color: AppColors.warning,
          icon: Icons.volunteer_activism_rounded,
          meaning:
              'Student is active but progress or score is below the healthy target.',
          teacherAction:
              'Teacher should nudge early: send reminders, recommend lessons, and watch the next assignment/grand-test result.',
        ),
        _RiskGuideCard(
          title: 'Healthy',
          color: AppColors.success,
          icon: Icons.health_and_safety_rounded,
          meaning:
              'Student has strong progress and score across enrolled course evidence.',
          teacherAction:
              'Teacher should keep momentum: praise progress, suggest advanced practice, and prepare certification readiness.',
        ),
      ],
    );
  }
}

class _RiskGuideCard extends StatelessWidget {
  const _RiskGuideCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.meaning,
    required this.teacherAction,
  });

  final String title;
  final Color color;
  final IconData icon;
  final String meaning;
  final String teacherAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
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
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            meaning,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.divider : AppColors.lightDivider,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.turn_right_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacherAction,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
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

class _StudentProgressGrid extends StatelessWidget {
  const _StudentProgressGrid({
    required this.summaries,
    required this.roleTheme,
  });

  final List<_StudentProgressSummary> summaries;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 3,
      wideColumns: 3,
      minChildWidth: 320,
      children: [
        for (final summary in summaries)
          _StudentProgressCard(summary: summary, roleTheme: roleTheme),
      ],
    );
  }
}

class _StudentProgressCard extends StatelessWidget {
  const _StudentProgressCard({required this.summary, required this.roleTheme});

  final _StudentProgressSummary summary;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final riskColor = _riskColor(summary.riskStatus);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.pushNamed(
        RouteNames.teacherStudentProgressDetail,
        pathParameters: {'studentId': summary.studentId},
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: summary.isAtRisk
                ? AppColors.error.withValues(alpha: 0.4)
                : (isDark ? AppColors.divider : AppColors.lightDivider),
          ),
          boxShadow: [
            if (summary.isAtRisk || summary.needsAttention)
              BoxShadow(
                color: riskColor.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 24,
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: riskColor.withValues(alpha: 0.15),
                    border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    summary.studentName.isEmpty
                        ? '?'
                        : summary.studentName[0].toUpperCase(),
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        summary.studentEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: TeacherProgressRisk.label(summary.riskStatus),
                  color: riskColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                summary.courseSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: roleTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProgressLine(
              label: 'Lessons',
              value: summary.averageProgress,
              helper:
                  '${summary.completedLessons}/${summary.totalLessons} completed across ${summary.courseCount} course${summary.courseCount == 1 ? '' : 's'}',
              roleTheme: roleTheme,
            ),
            const SizedBox(height: 12),
            _ProgressLine(
              label: 'Assignments',
              value: summary.averageAssignmentCompletion,
              helper:
                  '${summary.completedAssignments}/${summary.totalAssignments} complete',
              roleTheme: roleTheme,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniBadge(
                  'Project: ${_title(summary.projectStatus)}',
                  roleTheme: roleTheme,
                ),
                _MiniBadge(
                  'Grand Test: ${_title(summary.grandTestStatus)}',
                  roleTheme: roleTheme,
                ),
                _MiniBadge(
                  'Avg Score: ${summary.averageScore.toStringAsFixed(0)}%',
                  roleTheme: roleTheme,
                ),
                if (summary.certificatesIssued > 0)
                  _MiniBadge(
                    'Certificates: ${summary.certificatesIssued}/${summary.courseCount}',
                    isHighlight: true,
                    roleTheme: roleTheme,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _TeacherActionNote(color: riskColor, text: summary.teacherAction),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String value) {
    return switch (value) {
      TeacherProgressRisk.atRisk => AppColors.error,
      TeacherProgressRisk.needsAttention => AppColors.warning,
      _ => AppColors.success,
    };
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.helper,
    required this.roleTheme,
  });

  final String label;
  final double value;
  final String helper;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 8,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation(roleTheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(
    this.label, {
    this.isHighlight = false,
    required this.roleTheme,
  });

  final String label;
  final bool isHighlight;
  final RoleThemeColors roleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? roleTheme.primary.withValues(alpha: 0.1)
            : (isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isHighlight
              ? roleTheme.primary.withValues(alpha: 0.3)
              : (isDark ? AppColors.divider : AppColors.lightDivider),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isHighlight
              ? roleTheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TeacherActionNote extends StatelessWidget {
  const _TeacherActionNote({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
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

class _StudentProgressSummary {
  _StudentProgressSummary(List<TeacherStudentProgressModel> source)
    : records = source.toList() {
    records.sort((a, b) => a.courseTitle.compareTo(b.courseTitle));
  }

  final List<TeacherStudentProgressModel> records;

  String get studentId => records.first.studentId;
  String get studentName => records.first.studentName;
  String get studentEmail => records.first.studentEmail;
  int get courseCount => records.length;

  String get courseSummary {
    final titles = records.map((item) => item.courseTitle).toSet().toList();
    if (titles.length == 1) return titles.first;
    final preview = titles.take(2).join(', ');
    final remaining = titles.length - 2;
    return remaining > 0
        ? '${titles.length} courses • $preview +$remaining more'
        : '${titles.length} courses • $preview';
  }

  double get averageProgress => _average((item) => item.lessonProgress);
  double get averageAssignmentCompletion {
    return _average((item) => item.assignmentCompletion);
  }

  double get averageScore => _average((item) => item.averageScore);

  int get completedLessons {
    return records.fold<int>(0, (sum, item) => sum + item.completedLessons);
  }

  int get totalLessons {
    return records.fold<int>(0, (sum, item) => sum + item.totalLessons);
  }

  int get completedAssignments {
    return records.fold<int>(0, (sum, item) => sum + item.completedAssignments);
  }

  int get totalAssignments {
    return records.fold<int>(0, (sum, item) => sum + item.totalAssignments);
  }

  int get certificatesIssued {
    return records.where((item) => item.certificateStatus == 'issued').length;
  }

  String get riskStatus {
    if (records.any((item) => item.isAtRisk)) return TeacherProgressRisk.atRisk;
    if (records.any((item) => item.needsAttention)) {
      return TeacherProgressRisk.needsAttention;
    }
    return TeacherProgressRisk.healthy;
  }

  bool get isAtRisk => riskStatus == TeacherProgressRisk.atRisk;
  bool get needsAttention => riskStatus == TeacherProgressRisk.needsAttention;

  String get projectStatus {
    return _priorityStatus(records.map((item) => item.projectStatus), const [
      'missing',
      'rejected',
      'changes_requested',
      'submitted',
      'graded',
    ], fallback: 'not_required');
  }

  String get grandTestStatus {
    return _priorityStatus(records.map((item) => item.grandTestStatus), const [
      'failed',
      'not_attempted',
      'passed',
    ], fallback: 'not_available');
  }

  String get teacherAction {
    return switch (riskStatus) {
      TeacherProgressRisk.atRisk =>
        'Action: intervene now. Open details, check the reasons, and guide the student course-by-course.',
      TeacherProgressRisk.needsAttention =>
        'Action: send a timely nudge. Recommend the next lesson or assignment before this becomes risky.',
      _ =>
        'Action: keep momentum. Suggest advanced practice and prepare this learner for certification.',
    };
  }

  List<String> get riskReasons {
    return records
        .expand((item) => item.riskReasons)
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  double _average(double Function(TeacherStudentProgressModel item) selector) {
    if (records.isEmpty) return 0;
    return records.fold<double>(0, (sum, item) => sum + selector(item)) /
        records.length;
  }

  String _priorityStatus(
    Iterable<String> statuses,
    List<String> priority, {
    required String fallback,
  }) {
    final values = statuses.toSet();
    for (final item in priority) {
      if (values.contains(item)) return item;
    }
    return fallback;
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

int _riskRank(String status) {
  return switch (status) {
    TeacherProgressRisk.atRisk => 3,
    TeacherProgressRisk.needsAttention => 2,
    _ => 1,
  };
}

String _title(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
