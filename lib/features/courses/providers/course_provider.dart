import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../core/utils/app_logger.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../payment/providers/payment_providers.dart';
import '../data/models/course_model.dart';
import '../data/repositories/course_repository.dart';
import 'enrollment_provider.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return FirestoreCourseRepository(ref.watch(firestoreProvider));
});

final teacherCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const <CourseModel>[]);
      return ref.watch(courseRepositoryProvider).streamTeacherCourses(user.uid);
    },
    loading: () => Stream.value(const <CourseModel>[]),
    error: (_, _) => Stream.value(const <CourseModel>[]),
  );
});

final publishedCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  return ref.watch(courseRepositoryProvider).streamPublishedCourses();
});

final courseDetailProvider = FutureProvider.family<CourseModel?, String>((
  ref,
  courseId,
) {
  return ref.watch(courseRepositoryProvider).getCourse(courseId);
});

final courseActionProvider = AsyncNotifierProvider<CourseActionNotifier, void>(
  CourseActionNotifier.new,
);

class CourseActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createCourse({
    required String title,
    required String subtitle,
    required String description,
    required String category,
    required String level,
    required String language,
    required String? thumbnailUrl,
    required List<String> skillsCovered,
    required List<String> tags,
    required List<String> prerequisites,
    required List<String> learningOutcomes,
    required List<String> targetAudience,
    required int durationMinutes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireTeacherId();
      final course = CourseModel.createDraft(
        teacherId: teacherId,
        teacherName: await _teacherName(teacherId),
        title: title,
        subtitle: subtitle,
        description: description,
        category: category,
        level: level,
        language: language,
        skillsCovered: skillsCovered,
        tags: tags,
        prerequisites: prerequisites,
        learningOutcomes: learningOutcomes,
        targetAudience: targetAudience,
        durationMinutes: durationMinutes,
        thumbnailUrl: thumbnailUrl,
      );
      await ref.read(courseRepositoryProvider).createCourse(course);
    });
    return !state.hasError;
  }

  Future<bool> updateCourse(CourseModel course) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(courseRepositoryProvider).updateCourse(course);
    });
    return !state.hasError;
  }

  Future<bool> publishCourse(String courseId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireTeacherId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateCoursePublish(
        teacherId: teacherId,
        publishedCourseCount: await ref
            .read(courseRepositoryProvider)
            .countPublishedCoursesByTeacher(teacherId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      await ref
          .read(courseRepositoryProvider)
          .publishCourse(courseId: courseId, teacherId: teacherId);
      await _notifyEnrolledStudentsCoursePublished(
        courseId: courseId,
        teacherId: teacherId,
      );
    });
    return !state.hasError;
  }

  Future<void> _notifyEnrolledStudentsCoursePublished({
    required String courseId,
    required String teacherId,
  }) async {
    try {
      final enrollments = await ref
          .read(enrollmentRepositoryProvider)
          .getCourseEnrollments(courseId);
      final recipientIds = enrollments
          .map((e) => e.studentId.trim())
          .where((id) => id.isNotEmpty && id != teacherId);
      if (recipientIds.isEmpty) return;

      final course = await ref
          .read(courseRepositoryProvider)
          .getCourse(courseId);
      final courseTitle = (course?.title ?? '').trim();
      final label = courseTitle.isEmpty ? 'a course' : '"$courseTitle"';
      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();

      await ref.read(notificationServiceProvider).notifyMany(
        recipientIds: recipientIds,
        title: 'Course published',
        body: '$label is now available.',
        category: NotificationCategories.learning,
        event: NotificationEvents.learningCoursePublished,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'courses/$courseId',
        routeName: RouteNames.studentCourseDetail,
        routeParams: {'courseId': courseId},
        meta: {
          'courseId': courseId,
          if (courseTitle.isNotEmpty) 'courseTitle': courseTitle,
        },
      );
    } catch (_) {
      AppLogger.warn('Course publication notification could not be sent.');
    }
  }

  Future<bool> archiveCourse(String courseId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(courseRepositoryProvider)
          .archiveCourse(courseId: courseId, teacherId: _requireTeacherId());
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();

  String _requireTeacherId() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      throw StateError('A signed-in teacher is required.');
    }
    return user.uid;
  }

  Future<String> _teacherName(String teacherId) async {
    final snapshot = await ref
        .read(firestoreProvider)
        .collection('users')
        .doc(teacherId)
        .get();
    final data = snapshot.data();
    final fullName = data?['fullName'];
    final displayName = ref
        .read(authRepositoryProvider)
        .currentUser
        ?.displayName;
    final name = fullName is String && fullName.trim().isNotEmpty
        ? fullName.trim()
        : displayName?.trim() ?? '';
    return name.isEmpty ? 'Teacher' : name;
  }
}
