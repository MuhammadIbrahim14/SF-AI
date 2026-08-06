import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/firebase_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../payment/providers/payment_providers.dart';
import '../data/models/lesson_model.dart';
import '../data/repositories/lesson_repository.dart';
import '../services/course_update_mailer.dart';

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return FirestoreLessonRepository(ref.watch(firestoreProvider));
});

final courseLessonsProvider = StreamProvider.family<List<LessonModel>, String>((
  ref,
  courseId,
) {
  return ref.watch(lessonRepositoryProvider).watchLessons(courseId);
});

final lessonDetailProvider =
    FutureProvider.family<LessonModel?, ({String courseId, String lessonId})>((
      ref,
      args,
    ) {
      return ref
          .watch(lessonRepositoryProvider)
          .getLesson(courseId: args.courseId, lessonId: args.lessonId);
    });

final lessonActionProvider = AsyncNotifierProvider<LessonActionNotifier, void>(
  LessonActionNotifier.new,
);

class LessonActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createLesson({
    required String courseId,
    required String title,
    required String description,
    required int orderIndex,
    required String videoUrl,
    required List<String> pdfLinks,
    required List<String> externalLinks,
    required int durationMinutes,
    required bool isPreview,
    List<String> learningObjectives = const <String>[],
    List<String> skillsCovered = const <String>[],
    List<String> prerequisites = const <String>[],
    int estimatedMinutes = 0,
    List<String> keyTakeaways = const <String>[],
    String lessonDifficulty = 'Beginner',
    String completionMode = LessonCompletionMode.simple,
    int minimumReadSeconds = 0,
    int minimumScrollPercent = 0,
    bool requireCheckpoints = false,
    bool requireMiniQuizPass = false,
    bool requirePracticalReflection = false,
    int passingScorePercent = 70,
    bool allowRetry = true,
    int maxAttempts = 0,
    String completionCriteriaSummary = '',
    List<LessonCheckpointModel> checkpoints = const <LessonCheckpointModel>[],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateLessonCreate(
        teacherId: teacherId,
        currentLessonCount: await ref
            .read(lessonRepositoryProvider)
            .countLessonsInCourse(courseId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      final now = DateTime.now();
      final lesson = LessonModel(
        lessonId: '',
        courseId: courseId,
        teacherId: teacherId,
        title: title,
        description: description,
        orderIndex: orderIndex,
        videoUrl: videoUrl,
        pdfLinks: pdfLinks,
        externalLinks: externalLinks,
        durationMinutes: durationMinutes,
        isPreview: isPreview,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
        learningObjectives: learningObjectives,
        skillsCovered: skillsCovered,
        prerequisites: prerequisites,
        estimatedMinutes: estimatedMinutes,
        keyTakeaways: keyTakeaways,
        lessonDifficulty: lessonDifficulty,
        completionMode: completionMode,
        minimumReadSeconds: minimumReadSeconds,
        minimumScrollPercent: minimumScrollPercent,
        requireCheckpoints: requireCheckpoints,
        requireMiniQuizPass: requireMiniQuizPass,
        requirePracticalReflection: requirePracticalReflection,
        passingScorePercent: passingScorePercent,
        allowRetry: allowRetry,
        maxAttempts: maxAttempts,
        completionCriteriaSummary: completionCriteriaSummary,
        checkpoints: checkpoints,
      );
      await ref.read(lessonRepositoryProvider).createLesson(lesson);
      if (!isPreview) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: courseId,
          itemId: title.trim(),
          itemType: 'lesson',
          itemTitle: title,
          teacherId: teacherId,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> updateLesson(LessonModel lesson) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(lessonRepositoryProvider).updateLesson(lesson);
    });
    return !state.hasError;
  }

  Future<bool> archiveLesson({
    required String courseId,
    required String lessonId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(lessonRepositoryProvider)
          .archiveLesson(
            courseId: courseId,
            lessonId: lessonId,
            teacherId: _requireUserId(),
          );
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();

  String _requireUserId() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw StateError('A signed-in user is required.');
    return user.uid;
  }
}
