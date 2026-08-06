import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/teacher_dashboard_stats_model.dart';
import 'teacher_ai_intelligence_provider.dart';
import 'teacher_dashboard_provider.dart';

final teacherProductivityHubProvider = FutureProvider<TeacherProductivityHub>((
  ref,
) async {
  final stats = await ref.watch(teacherDashboardStatsProvider.future);
  final intelligence = await ref.watch(teacherAiIntelligenceProvider.future);

  return TeacherProductivityHubService().build(
    stats: stats,
    intelligence: intelligence,
  );
});

class TeacherProductivityHubService {
  TeacherProductivityHub build({
    required TeacherDashboardStatsModel stats,
    required TeacherAiIntelligence intelligence,
  }) {
    final workspace = _workspace(stats: stats, intelligence: intelligence);
    final workload = _workload(stats: stats, intelligence: intelligence);
    final insights = _insights(stats: stats, intelligence: intelligence);

    return TeacherProductivityHub(
      workspaceItems: workspace,
      workloadCards: workload,
      courseSnapshots: intelligence.courseHealth,
      teachingInsights: insights,
      recentActivities: stats.activities,
      hasActionableWork:
          workspace.isNotEmpty || workload.any((item) => item.count > 0),
    );
  }

  List<TeacherWorkspaceItem> _workspace({
    required TeacherDashboardStatsModel stats,
    required TeacherAiIntelligence intelligence,
  }) {
    final items = <TeacherWorkspaceItem>[];

    for (final work in stats.pendingWorks) {
      items.add(
        TeacherWorkspaceItem(
          title: work.title,
          detail: work.subtitle,
          count: work.count,
          priority: _priorityFor(work.iconName, work.count),
          iconName: work.iconName,
          courseId: work.courseId,
          assignmentId: work.assignmentId,
          grandTestId: work.grandTestId,
        ),
      );
    }

    for (final inbox in intelligence.inboxItems) {
      final duplicate = items.any((item) => item.title == inbox.title);
      if (duplicate) continue;
      items.add(
        TeacherWorkspaceItem(
          title: inbox.title,
          detail: inbox.detail,
          count: _countFromDetail(inbox.detail),
          priority: inbox.priority,
          iconName: inbox.iconName,
        ),
      );
    }

    items.sort((a, b) {
      final priority = b.priorityRank.compareTo(a.priorityRank);
      if (priority != 0) return priority;
      return b.count.compareTo(a.count);
    });
    return items.take(8).toList();
  }

  List<TeacherWorkloadCard> _workload({
    required TeacherDashboardStatsModel stats,
    required TeacherAiIntelligence intelligence,
  }) {
    return [
      TeacherWorkloadCard(
        title: 'Pending Reviews',
        count: intelligence.pendingProjectReviews,
        detail: 'Project submissions waiting for feedback',
        iconName: 'project',
        priority: TeacherInsightPriority.high,
      ),
      TeacherWorkloadCard(
        title: 'Assignment Gaps',
        count: intelligence.pendingAssignmentAttempts,
        detail: 'Expected assignment attempts still missing',
        iconName: 'assignment',
        priority: TeacherInsightPriority.medium,
      ),
      TeacherWorkloadCard(
        title: 'Certificates Pending',
        count: intelligence.pendingCertificates,
        detail: 'Students appear ready for certificate issuance',
        iconName: 'certificate',
        priority: TeacherInsightPriority.medium,
      ),
      TeacherWorkloadCard(
        title: 'Grand Test Signals',
        count: intelligence.pendingGrandTestSignals,
        detail: 'No-attempt or warning Grand Test signals',
        iconName: 'grandTest',
        priority: TeacherInsightPriority.high,
      ),
      TeacherWorkloadCard(
        title: 'Students Awaiting Feedback',
        count:
            intelligence.atRiskStudents.length +
            intelligence.needsAttentionStudents.length,
        detail: 'Students flagged by progress and assessment signals',
        iconName: 'attention',
        priority: TeacherInsightPriority.high,
      ),
      TeacherWorkloadCard(
        title: 'Recent Activity',
        count: stats.activities.length,
        detail: 'Latest learner and course events',
        iconName: 'activity',
        priority: TeacherInsightPriority.low,
      ),
    ];
  }

  List<String> _insights({
    required TeacherDashboardStatsModel stats,
    required TeacherAiIntelligence intelligence,
  }) {
    final insights = <String>[];

    if (stats.activities.isNotEmpty) {
      insights.add(
        '${stats.activities.length} recent activities are available in your teaching timeline.',
      );
    }
    final healthiest =
        intelligence.courseHealth
            .where(
              (course) =>
                  course.healthLabel == TeacherCourseHealthLabel.excellent ||
                  course.healthLabel == TeacherCourseHealthLabel.healthy,
            )
            .toList()
          ..sort((a, b) => b.healthScore.compareTo(a.healthScore));
    if (healthiest.isNotEmpty) {
      insights.add(
        '${healthiest.first.courseTitle} has the strongest course health at ${healthiest.first.healthScore.toStringAsFixed(0)}%.',
      );
    }
    final weakest =
        intelligence.courseHealth
            .where(
              (course) =>
                  course.healthLabel == TeacherCourseHealthLabel.critical ||
                  course.healthLabel == TeacherCourseHealthLabel.needsAttention,
            )
            .toList()
          ..sort((a, b) => a.healthScore.compareTo(b.healthScore));
    if (weakest.isNotEmpty) {
      insights.add(
        '${weakest.first.courseTitle} needs attention. Review completion and assessment outcomes.',
      );
    }
    if (intelligence.pendingProjectReviews > 0) {
      insights.add(
        'Project reviews are currently your largest feedback queue.',
      );
    }
    if (intelligence.pendingCertificates > 0) {
      insights.add(
        'Certificate issuance is pending for ${intelligence.pendingCertificates} learners.',
      );
    }
    insights.addAll(intelligence.recommendations);

    final unique = <String>[];
    for (final insight in insights) {
      if (insight.trim().isEmpty || unique.contains(insight)) continue;
      unique.add(insight);
    }
    if (unique.isEmpty) {
      unique.add(
        'No urgent teaching insights yet. Keep learners active to unlock richer productivity signals.',
      );
    }
    return unique.take(7).toList();
  }

  String _priorityFor(String iconName, int count) {
    if (count <= 0) return TeacherInsightPriority.low;
    return switch (iconName) {
      'project' => TeacherInsightPriority.high,
      'grandTest' => TeacherInsightPriority.high,
      'certificate' => TeacherInsightPriority.medium,
      _ =>
        count >= 5
            ? TeacherInsightPriority.high
            : TeacherInsightPriority.medium,
    };
  }

  int _countFromDetail(String detail) {
    final match = RegExp(r'\d+').firstMatch(detail);
    if (match == null) return 1;
    return int.tryParse(match.group(0) ?? '') ?? 1;
  }
}

class TeacherProductivityHub {
  const TeacherProductivityHub({
    required this.workspaceItems,
    required this.workloadCards,
    required this.courseSnapshots,
    required this.teachingInsights,
    required this.recentActivities,
    required this.hasActionableWork,
  });

  final List<TeacherWorkspaceItem> workspaceItems;
  final List<TeacherWorkloadCard> workloadCards;
  final List<TeacherCourseHealth> courseSnapshots;
  final List<String> teachingInsights;
  final List<TeacherDashboardActivityItem> recentActivities;
  final bool hasActionableWork;
}

class TeacherWorkspaceItem {
  const TeacherWorkspaceItem({
    required this.title,
    required this.detail,
    required this.count,
    required this.priority,
    required this.iconName,
    this.courseId,
    this.assignmentId,
    this.grandTestId,
  });

  final String title;
  final String detail;
  final int count;
  final String priority;
  final String iconName;
  final String? courseId;
  final String? assignmentId;
  final String? grandTestId;

  int get priorityRank => switch (priority) {
    TeacherInsightPriority.high => 3,
    TeacherInsightPriority.medium => 2,
    _ => 1,
  };
}

class TeacherWorkloadCard {
  const TeacherWorkloadCard({
    required this.title,
    required this.count,
    required this.detail,
    required this.iconName,
    required this.priority,
  });

  final String title;
  final int count;
  final String detail;
  final String iconName;
  final String priority;
}
