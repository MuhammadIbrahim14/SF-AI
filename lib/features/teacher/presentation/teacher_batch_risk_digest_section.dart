import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/teacher_batch_provider.dart';
import '../utils/teacher_batch_intelligence.dart';

class TeacherBatchRiskDigestSection extends StatelessWidget {
  const TeacherBatchRiskDigestSection({super.key, required this.summary});

  final TeacherBatchProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digest = TeacherBatchRiskDigest.fromSummary(summary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Needs attention this week',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Derived from live progress — no new data writes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DigestMetric(
                label: 'At Risk',
                value: digest.atRiskStudents.toString(),
                emphasize: digest.atRiskStudents > 0,
                color: AppColors.error,
              ),
              _DigestMetric(
                label: 'Needs Attention',
                value: digest.needsAttentionStudents.toString(),
                emphasize: digest.needsAttentionStudents > 0,
                color: AppColors.warning,
              ),
              _DigestMetric(
                label: 'Pending Work',
                value: digest.pendingAssignments.toString(),
                emphasize: digest.pendingAssignments > 0,
                color: AppColors.teacherPrimary,
              ),
              _DigestMetric(
                label: 'GT Failed',
                value: digest.grandTestsFailed.toString(),
                emphasize: digest.grandTestsFailed > 0,
                color: AppColors.error,
              ),
              _DigestMetric(
                label: 'GT Passed',
                value: digest.grandTestsPassed.toString(),
                emphasize: false,
                color: AppColors.success,
              ),
            ],
          ),
          if (digest.weakAreas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Top weak areas',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final area in digest.weakAreas)
                  Chip(
                    label: Text(area),
                    backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Recommended interventions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < digest.interventions.length; i++) ...[
            _InterventionTile(item: digest.interventions[i]),
            if (i != digest.interventions.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _DigestMetric extends StatelessWidget {
  const _DigestMetric({
    required this.label,
    required this.value,
    required this.emphasize,
    required this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (emphasize ? color : AppColors.teacherPrimary).withValues(
          alpha: emphasize ? 0.14 : 0.1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: emphasize ? color : null,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _InterventionTile extends StatelessWidget {
  const _InterventionTile({required this.item});

  final TeacherBatchIntervention item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(item.iconName), size: 20, color: AppColors.teacherPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'priority' => Icons.priority_high_rounded,
      'assignment' => Icons.assignment_late_outlined,
      'quiz' => Icons.quiz_outlined,
      'group' => Icons.group_outlined,
      _ => Icons.tips_and_updates_outlined,
    };
  }
}
