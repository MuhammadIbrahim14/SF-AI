import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_ai_tutor_models.dart';

class StudentAiContextService {
  const StudentAiContextService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<StudentAiTutorContextModel> buildContext({
    required String studentId,
    String? courseId,
    String? lessonId,
    String? assignmentId,
    String? quizId,
    String? grandTestId,
    String? mode,
  }) async {
    String? courseTitle;
    String? lessonTitle;
    String? lessonSummary;
    final weakTopics = <String>[];
    final pendingAssignments = <String>[];
    final upcomingTests = <String>[];

    final safeCourseId = (courseId ?? '').trim();
    final safeLessonId = (lessonId ?? '').trim();

    if (safeCourseId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('courses')
            .doc(safeCourseId)
            .get();
        final data = doc.data() ?? const <String, dynamic>{};
        courseTitle = _text(data['title'] ?? data['courseTitle']);
        final category = _text(data['category']);
        if (category != null) weakTopics.add(category);
      } catch (_) {
        // Context is helpful, not required for tutor availability.
      }
    }

    if (safeCourseId.isNotEmpty && safeLessonId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('courses')
            .doc(safeCourseId)
            .collection('lessons')
            .doc(safeLessonId)
            .get();
        final data = doc.data() ?? const <String, dynamic>{};
        lessonTitle = _text(data['title'] ?? data['lessonTitle']);
        lessonSummary = _summarize(
          _text(
            data['description'] ??
                data['content'] ??
                data['body'] ??
                data['summary'],
          ),
        );
      } catch (_) {
        // Missing lesson context should not block the tutor.
      }
    }

    if ((assignmentId ?? '').trim().isNotEmpty) {
      pendingAssignments.add('Assignment help requested');
    }
    if ((grandTestId ?? '').trim().isNotEmpty) {
      upcomingTests.add('Grand Test preparation');
    }

    return StudentAiTutorContextModel(
      studentId: studentId,
      courseId: safeCourseId.isEmpty ? null : safeCourseId,
      courseTitle: courseTitle,
      lessonId: safeLessonId.isEmpty ? null : safeLessonId,
      lessonTitle: lessonTitle,
      lessonContentSummary: lessonSummary,
      currentTopic: lessonTitle ?? courseTitle,
      assignmentId: assignmentId,
      quizId: quizId,
      grandTestId: grandTestId,
      weakTopics: weakTopics,
      pendingAssignments: pendingAssignments,
      upcomingTests: upcomingTests,
      languagePreference: 'mixed',
      difficultyLevel: 'beginner',
      mode: mode ?? 'learning',
    );
  }

  String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String? _summarize(String? value) {
    final text = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    return text.length <= 900 ? text : '${text.substring(0, 900)}...';
  }
}
