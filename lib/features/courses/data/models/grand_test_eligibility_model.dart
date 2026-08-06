class GrandTestEligibilityModel {
  const GrandTestEligibilityModel({
    required this.courseId,
    required this.grandTestId,
    required this.studentId,
    required this.readinessPercent,
    required this.isEligible,
    required this.reasons,
    required this.lessonProgress,
    required this.requiredLessonProgressPercent,
    required this.assignmentCompletion,
    required this.requiredAssignmentCompletionPercent,
    required this.averageScore,
    required this.requiredAverageScorePercent,
    required this.projectSubmitted,
    required this.requireProjectSubmission,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.missingRequirements,
    required this.recommendations,
    required this.calculatedAt,
  });

  final String courseId;
  final String grandTestId;
  final String studentId;
  final double readinessPercent;
  final bool isEligible;
  final List<String> reasons;
  final double lessonProgress;
  final double requiredLessonProgressPercent;
  final double assignmentCompletion;
  final double requiredAssignmentCompletionPercent;
  final double averageScore;
  final double requiredAverageScorePercent;
  final bool projectSubmitted;
  final bool requireProjectSubmission;
  final int attemptsUsed;
  final int maxAttempts;
  final List<String> missingRequirements;
  final List<String> recommendations;
  final DateTime calculatedAt;

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'grandTestId': grandTestId,
      'studentId': studentId,
      'readinessPercent': readinessPercent,
      'isEligible': isEligible,
      'reasons': reasons,
      'lessonProgress': lessonProgress,
      'requiredLessonProgressPercent': requiredLessonProgressPercent,
      'assignmentCompletion': assignmentCompletion,
      'requiredAssignmentCompletionPercent':
          requiredAssignmentCompletionPercent,
      'averageScore': averageScore,
      'requiredAverageScorePercent': requiredAverageScorePercent,
      'projectSubmitted': projectSubmitted,
      'requireProjectSubmission': requireProjectSubmission,
      'attemptsUsed': attemptsUsed,
      'maxAttempts': maxAttempts,
      'missingRequirements': missingRequirements,
      'recommendations': recommendations,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }
}
