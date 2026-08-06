class AiCourseMaterializationResultModel {
  const AiCourseMaterializationResultModel({
    required this.courseId,
    required this.createdLessonIds,
    required this.createdAssignmentIds,
    required this.createdQuizIds,
    required this.createdQuestionIds,
    required this.savedAsDraft,
    required this.published,
    required this.warnings,
    required this.errors,
    required this.previewOnlyItems,
    required this.success,
    this.createdGrandTestId,
  });

  final String? courseId;
  final List<String> createdLessonIds;
  final List<String> createdAssignmentIds;
  final List<String> createdQuizIds;
  final List<String> createdQuestionIds;
  final String? createdGrandTestId;
  final bool savedAsDraft;
  final bool published;
  final List<String> warnings;
  final List<String> errors;
  final List<String> previewOnlyItems;
  final bool success;

  String summaryMessage() {
    final parts = <String>[
      if (courseId != null) 'course saved',
      '${createdLessonIds.length} lessons saved',
      '${createdAssignmentIds.length} assignments saved',
      '${createdQuizIds.length} quizzes saved',
      '${createdQuestionIds.length} questions saved',
      createdGrandTestId == null
          ? 'grand test not created'
          : 'grand test saved',
    ];
    if (warnings.isNotEmpty) {
      parts.add('${warnings.length} warning${warnings.length == 1 ? '' : 's'}');
    }
    return parts.join(', ');
  }
}
