import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../payment/services/demo_payment_notification_helper.dart';
import '../data/models/enrollment_model.dart';
import '../data/repositories/course_purchase_repository.dart';
import '../data/repositories/enrollment_repository.dart';
import '../data/services/course_progress_service.dart';
import 'course_provider.dart';

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  return FirestoreEnrollmentRepository(ref.watch(firestoreProvider));
});

final studentEnrollmentsProvider = StreamProvider<List<EnrollmentModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <EnrollmentModel>[]);
  return ref
      .watch(enrollmentRepositoryProvider)
      .watchStudentEnrollments(user.uid);
});

final courseEnrollmentProvider =
    StreamProvider.family<EnrollmentModel?, String>((ref, courseId) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(null);
      return ref
          .watch(enrollmentRepositoryProvider)
          .watchEnrollment(courseId: courseId, studentId: user.uid);
    });

final courseEnrollmentsProvider =
    StreamProvider.family<List<EnrollmentModel>, String>((ref, courseId) {
      return ref
          .watch(enrollmentRepositoryProvider)
          .watchCourseEnrollments(courseId);
    });

/// Recomputes overall course progress from live course content whenever the
/// student opens a course, so lessons/quizzes/projects published after they
/// finished are counted instead of leaving a stale 100%.
final courseProgressSyncProvider = FutureProvider.autoDispose
    .family<CourseProgressSnapshot?, String>((ref, courseId) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return null;
      try {
        return await ref
            .read(enrollmentRepositoryProvider)
            .syncCourseProgress(courseId: courseId, studentId: user.uid);
      } catch (_) {
        // Progress display falls back to the stored enrollment values.
        return null;
      }
    });

/// Study time already recorded for a lesson, so the read timer resumes instead
/// of restarting from zero on every visit.
final lessonReadProgressProvider = FutureProvider.autoDispose
    .family<LessonReadProgress, ({String courseId, String lessonId})>((
      ref,
      args,
    ) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const LessonReadProgress();
      try {
        return await ref
            .read(enrollmentRepositoryProvider)
            .getLessonReadProgress(
              courseId: args.courseId,
              lessonId: args.lessonId,
              studentId: user.uid,
            );
      } catch (_) {
        return const LessonReadProgress();
      }
    });

final enrollmentActionProvider =
    AsyncNotifierProvider<EnrollmentActionNotifier, void>(
      EnrollmentActionNotifier.new,
    );

class EnrollmentActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> enroll(String courseId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in student is required.');
      final course = await ref
          .read(courseRepositoryProvider)
          .getCourse(courseId);
      if (course == null) throw StateError('Course not found.');

      final purchaseRepo = CoursePurchaseRepository(ref.read(firestoreProvider));
      final paidConfig = await purchaseRepo.getPaidCourseConfig(courseId);
      if (paidConfig.isPaid && paidConfig.price > 0) {
        final purchased = await purchaseRepo.hasPurchased(user.uid, courseId);
        if (!purchased) {
          throw StateError(
            'This is a paid course. Complete purchase to enroll.',
          );
        }
        // Gateway finalize creates the enrollment; client must not forge it.
        final existing = await ref
            .read(enrollmentRepositoryProvider)
            .getEnrollmentByStudentAndCourse(
              studentId: user.uid,
              courseId: courseId,
            );
        if (existing != null) return;
        throw StateError(
          'Purchase recorded. Refresh this page if enrollment is not visible yet.',
        );
      }

      // Free enroll only (paid courses finalize via demo gateway — no double notify).
      final existingFree = await ref
          .read(enrollmentRepositoryProvider)
          .getEnrollmentByStudentAndCourse(
            studentId: user.uid,
            courseId: courseId,
          );
      if (existingFree != null) return;

      await ref
          .read(enrollmentRepositoryProvider)
          .enroll(course: course, studentId: user.uid);

      try {
        final studentName =
            (ref.read(currentUserProvider).value?.fullName ?? '').trim();
        await DemoPaymentNotificationHelper(
          ref.read(notificationServiceProvider),
        ).notifyFreeEnrollment(
          studentId: user.uid,
          teacherId: course.teacherId,
          courseId: course.id,
          courseTitle: course.title,
          studentName: studentName.isEmpty ? null : studentName,
        );
      } catch (_) {
        // Never fail enroll because of inbox write.
      }
    });
    return !state.hasError;
  }

  Future<bool> markLessonComplete({
    required String courseId,
    required String lessonId,
    bool verifiedCompleted = true,
    String completionMode = 'simple',
    Map<String, dynamic> completionEvidence = const <String, dynamic>{},
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in student is required.');
      await ref
          .read(enrollmentRepositoryProvider)
          .markLessonComplete(
            courseId: courseId,
            lessonId: lessonId,
            studentId: user.uid,
            verifiedCompleted: verifiedCompleted,
            completionMode: completionMode,
            completionEvidence: completionEvidence,
          );
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}
