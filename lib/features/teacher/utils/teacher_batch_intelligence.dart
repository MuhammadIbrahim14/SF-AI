import '../providers/teacher_batch_provider.dart';

/// Rule-based risk digest + interventions from existing batch progress data.
/// No Firestore writes; no invented student facts beyond summary aggregates.
class TeacherBatchRiskDigest {
  const TeacherBatchRiskDigest({
    required this.atRiskStudents,
    required this.needsAttentionStudents,
    required this.pendingAssignments,
    required this.grandTestsFailed,
    required this.grandTestsPassed,
    required this.weakAreas,
    required this.interventions,
    required this.hasSignals,
  });

  final int atRiskStudents;
  final int needsAttentionStudents;
  final int pendingAssignments;
  final int grandTestsFailed;
  final int grandTestsPassed;
  final List<String> weakAreas;
  final List<TeacherBatchIntervention> interventions;
  final bool hasSignals;

  factory TeacherBatchRiskDigest.fromSummary(
    TeacherBatchProgressSummary summary,
  ) {
    final weakAreas = summary.commonWeakAreas.take(5).toList(growable: false);
    final interventions = buildTeacherBatchInterventions(summary);
    final hasSignals =
        summary.atRiskStudents > 0 ||
        summary.needsAttentionStudents > 0 ||
        summary.pendingAssignments > 0 ||
        summary.grandTestsFailed > 0 ||
        weakAreas.isNotEmpty;
    return TeacherBatchRiskDigest(
      atRiskStudents: summary.atRiskStudents,
      needsAttentionStudents: summary.needsAttentionStudents,
      pendingAssignments: summary.pendingAssignments,
      grandTestsFailed: summary.grandTestsFailed,
      grandTestsPassed: summary.grandTestsPassed,
      weakAreas: weakAreas,
      interventions: interventions,
      hasSignals: hasSignals,
    );
  }

  /// Compact, non-PII summary for AI announcement drafts.
  String toAiContextSummary({
    required String batchTitle,
    required List<String> courseTitles,
    required int studentCount,
  }) {
    final buffer = StringBuffer()
      ..writeln('Batch: $batchTitle')
      ..writeln('Students: $studentCount')
      ..writeln(
        'Courses: ${courseTitles.isEmpty ? 'none assigned' : courseTitles.join(', ')}',
      )
      ..writeln('At risk: $atRiskStudents')
      ..writeln('Needs attention: $needsAttentionStudents')
      ..writeln('Pending assignments: $pendingAssignments')
      ..writeln('Grand tests failed: $grandTestsFailed')
      ..writeln('Grand tests passed: $grandTestsPassed');
    if (weakAreas.isNotEmpty) {
      buffer.writeln('Top weak areas: ${weakAreas.join('; ')}');
    }
    if (interventions.isNotEmpty) {
      buffer.writeln(
        'Suggested interventions: ${interventions.map((i) => i.title).join('; ')}',
      );
    }
    return buffer.toString().trim();
  }
}

class TeacherBatchIntervention {
  const TeacherBatchIntervention({
    required this.title,
    required this.detail,
    required this.iconName,
  });

  final String title;
  final String detail;

  /// Material icon hint for UI (`priority`, `assignment`, `quiz`, `group`, `tips`).
  final String iconName;
}

/// Concise teacher tips derived only from progress summary signals.
List<TeacherBatchIntervention> buildTeacherBatchInterventions(
  TeacherBatchProgressSummary summary,
) {
  final items = <TeacherBatchIntervention>[];

  if (summary.atRiskStudents > 0) {
    items.add(
      TeacherBatchIntervention(
        title: 'Reach out to at-risk students',
        detail:
            '${summary.atRiskStudents} student${summary.atRiskStudents == 1 ? '' : 's'} '
            'flagged at risk. Schedule short check-ins and clarify blockers.',
        iconName: 'priority',
      ),
    );
  }

  if (summary.needsAttentionStudents > 0) {
    items.add(
      TeacherBatchIntervention(
        title: 'Nudge students needing attention',
        detail:
            '${summary.needsAttentionStudents} student'
            '${summary.needsAttentionStudents == 1 ? '' : 's'} '
            'are slipping. Send a reminder before they become at-risk.',
        iconName: 'group',
      ),
    );
  }

  if (summary.pendingAssignments > 0) {
    items.add(
      TeacherBatchIntervention(
        title: 'Clear pending assignment work',
        detail:
            '${summary.pendingAssignments} incomplete assignment'
            '${summary.pendingAssignments == 1 ? '' : 's'} across the roster. '
            'Set a soft deadline and offer office hours.',
        iconName: 'assignment',
      ),
    );
  }

  if (summary.grandTestsFailed > 0) {
    items.add(
      TeacherBatchIntervention(
        title: 'Remediate grand test failures',
        detail:
            '${summary.grandTestsFailed} failed grand test attempt'
            '${summary.grandTestsFailed == 1 ? '' : 's'}. '
            'Review weak topics and offer a guided retake plan.',
        iconName: 'quiz',
      ),
    );
  }

  for (final area in summary.commonWeakAreas.take(3)) {
    items.add(
      TeacherBatchIntervention(
        title: 'Coach on: $area',
        detail:
            'This signal appears often in batch risk reasons. '
            'Add a short review lesson or practice set focused on it.',
        iconName: 'tips',
      ),
    );
  }

  if (items.isEmpty) {
    items.add(
      const TeacherBatchIntervention(
        title: 'Keep steady momentum',
        detail:
            'No urgent risk signals this week. Keep publishing assessments '
            'and reviewing progress to catch early slips.',
        iconName: 'tips',
      ),
    );
  }

  return items.take(6).toList(growable: false);
}
