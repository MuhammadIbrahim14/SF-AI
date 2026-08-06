class AiCoursePublishResultModel {
  const AiCoursePublishResultModel({
    required this.success,
    required this.courseId,
    required this.message,
    required this.published,
  });

  final bool success;
  final String? courseId;
  final String message;
  final bool published;
}
