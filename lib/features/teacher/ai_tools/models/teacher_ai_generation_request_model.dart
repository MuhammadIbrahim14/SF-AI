class TeacherAiTaskType {
  const TeacherAiTaskType._();

  static const lessonBuilder = 'teacherLessonBuilder';
  static const assignmentBuilder = 'teacherAssignmentBuilder';
  static const projectAssignmentBuilder = 'teacherProjectAssignmentBuilder';
  static const quizBuilder = 'teacherQuizBuilder';
  static const grandTestBuilder = 'teacherGrandTestBuilder';
  static const improveContent = 'teacherImproveContent';
  static const batchAnnouncementDraft = 'teacherBatchAnnouncementDraft';
}

class TeacherAiGenerationRequestModel {
  const TeacherAiGenerationRequestModel({
    required this.taskType,
    required this.prompt,
    required this.courseId,
    this.courseTitle,
    this.currentTitle,
    this.currentDescription,
    this.skills = const <String>[],
    this.questionCount = 5,
    this.durationMinutes,
    this.difficulty,
    this.extraContext = const <String, dynamic>{},
  });

  final String taskType;
  final String prompt;
  final String courseId;
  final String? courseTitle;
  final String? currentTitle;
  final String? currentDescription;
  final List<String> skills;
  final int questionCount;
  final int? durationMinutes;
  final String? difficulty;
  final Map<String, dynamic> extraContext;

  Map<String, dynamic> toSafeContext() {
    return {
      'courseId': courseId,
      if ((courseTitle ?? '').trim().isNotEmpty) 'courseTitle': courseTitle,
      if ((currentTitle ?? '').trim().isNotEmpty) 'currentTitle': currentTitle,
      if ((currentDescription ?? '').trim().isNotEmpty)
        'currentDescription': currentDescription,
      'skills': skills,
      'questionCount': questionCount,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if ((difficulty ?? '').trim().isNotEmpty) 'difficulty': difficulty,
      ...extraContext,
    };
  }
}
