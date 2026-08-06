import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/interview_lab_models.dart';
import 'interview_lab_providers.dart';

class InterviewLabAnalytics {
  const InterviewLabAnalytics({
    required this.completedCount,
    required this.averageScore,
    required this.latestScore,
    required this.highestScore,
    required this.mostPracticedTrack,
    required this.weakSkills,
    required this.recommendedCourses,
    required this.scoreTrend,
    this.resumable,
    this.latestReport,
  });

  final int completedCount;
  final double averageScore;
  final double latestScore;
  final double highestScore;
  final String mostPracticedTrack;
  final List<String> weakSkills;
  final List<String> recommendedCourses;
  final List<double> scoreTrend;
  final InterviewLabSessionModel? resumable;
  final InterviewLabReportModel? latestReport;

  static const empty = InterviewLabAnalytics(
    completedCount: 0,
    averageScore: 0,
    latestScore: 0,
    highestScore: 0,
    mostPracticedTrack: InterviewLabRoleTrack.general,
    weakSkills: [],
    recommendedCourses: [],
    scoreTrend: [],
  );
}

final interviewLabAnalyticsProvider =
    Provider<AsyncValue<InterviewLabAnalytics>>((ref) {
  final sessionsAsync = ref.watch(myInterviewLabSessionsProvider);
  return sessionsAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (sessions) {
      final completed = sessions
          .where((s) => s.status == InterviewLabSessionStatus.completed)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      InterviewLabSessionModel? resumable;
      for (final s in sessions) {
        if (s.status == InterviewLabSessionStatus.inProgress ||
            s.status == InterviewLabSessionStatus.paused ||
            s.status == InterviewLabSessionStatus.ready) {
          resumable = s;
          break;
        }
      }

      if (completed.isEmpty) {
        return AsyncData(
          InterviewLabAnalytics(
            completedCount: 0,
            averageScore: 0,
            latestScore: 0,
            highestScore: 0,
            mostPracticedTrack: InterviewLabRoleTrack.general,
            weakSkills: const [],
            recommendedCourses: const [],
            scoreTrend: const [],
            resumable: resumable,
          ),
        );
      }

      final scores = completed.map((s) => s.overallScore).toList();
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      final highest = scores.reduce((a, b) => a > b ? a : b);
      final trackCounts = <String, int>{};
      for (final s in completed) {
        trackCounts[s.roleTrack] = (trackCounts[s.roleTrack] ?? 0) + 1;
      }
      final mostPracticed = trackCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      // Weak skills heuristic from lowest dimension on latest session.
      final latest = completed.first;
      final dims = <String, double>{
        'Technical': latest.technicalScore,
        'Communication': latest.communicationScore,
        'Confidence': latest.confidenceScore,
        'Problem Solving': latest.problemSolvingScore,
      };
      final weak = dims.entries.where((e) => e.value > 0 && e.value < 60).map((e) => e.key).toList();

      final courses = weak.isEmpty
          ? <String>['Keep practicing timed ${InterviewLabRoleTrack.displayLabel(mostPracticed)} interviews']
          : weak.map((w) => 'Improve $w · ${InterviewLabRoleTrack.displayLabel(mostPracticed)}').toList();

      final trend = completed.reversed.take(8).map((s) => s.overallScore).toList();

      return AsyncData(
        InterviewLabAnalytics(
          completedCount: completed.length,
          averageScore: (avg * 10).round() / 10,
          latestScore: latest.overallScore,
          highestScore: highest,
          mostPracticedTrack: mostPracticed,
          weakSkills: weak,
          recommendedCourses: courses,
          scoreTrend: trend,
          resumable: resumable,
        ),
      );
    },
  );
});

final interviewLabReportForSessionProvider =
    FutureProvider.family<InterviewLabReportModel?, String>((ref, sessionId) {
  return ref
      .watch(interviewLabRepositoryProvider)
      .getReportForSession(sessionId);
});
