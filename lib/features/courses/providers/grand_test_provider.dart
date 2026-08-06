import 'package:flutter/foundation.dart';
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
import '../data/models/grand_test_attempt_model.dart';
import '../data/models/grand_test_eligibility_model.dart';
import '../data/models/grand_test_model.dart';
import '../data/repositories/grand_test_repository.dart';
import 'certificate_provider.dart';
import 'enrollment_provider.dart';
import '../services/course_update_mailer.dart';

final grandTestRepositoryProvider = Provider<GrandTestRepository>((ref) {
  return FirestoreGrandTestRepository(ref.watch(firestoreProvider));
});

final teacherGrandTestsProvider =
    StreamProvider.family<List<GrandTestModel>, String>((ref, courseId) {
      return ref
          .watch(grandTestRepositoryProvider)
          .watchTeacherGrandTests(courseId);
    });

final publishedGrandTestsProvider =
    StreamProvider.family<List<GrandTestModel>, String>((ref, courseId) {
      return ref
          .watch(grandTestRepositoryProvider)
          .watchPublishedGrandTests(courseId);
    });

final grandTestDetailProvider =
    FutureProvider.family<
      GrandTestModel?,
      ({String courseId, String grandTestId})
    >((ref, args) {
      return ref
          .watch(grandTestRepositoryProvider)
          .getGrandTest(courseId: args.courseId, grandTestId: args.grandTestId);
    });

final grandTestEligibilityProvider =
    FutureProvider.family<
      GrandTestEligibilityModel,
      ({String courseId, String grandTestId})
    >((ref, args) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) {
        return Future.value(
          buildGrandTestEligibilityFallback(
            courseId: args.courseId,
            grandTestId: args.grandTestId,
            studentId: '',
            reason: 'Please sign in again to view your readiness report.',
          ),
        );
      }
      return () async {
        try {
          return await ref
              .watch(grandTestRepositoryProvider)
              .checkEligibility(
                courseId: args.courseId,
                grandTestId: args.grandTestId,
                studentId: user.uid,
              );
        } catch (e) {
          return _hydratedEligibilityFallback(
            ref,
            courseId: args.courseId,
            grandTestId: args.grandTestId,
            studentId: user.uid,
          );
        }
      }();
    });

final grandTestStudentEligibilityProvider =
    FutureProvider.family<
      GrandTestEligibilityModel,
      ({String courseId, String grandTestId, String studentId})
    >((ref, args) {
      return () async {
        try {
          return await ref
              .watch(grandTestRepositoryProvider)
              .checkEligibility(
                courseId: args.courseId,
                grandTestId: args.grandTestId,
                studentId: args.studentId,
              );
        } catch (e) {
          return _hydratedEligibilityFallback(
            ref,
            courseId: args.courseId,
            grandTestId: args.grandTestId,
            studentId: args.studentId,
          );
        }
      }();
    });

Future<GrandTestEligibilityModel> _hydratedEligibilityFallback(
  Ref ref, {
  required String courseId,
  required String grandTestId,
  required String studentId,
}) async {
  final test = await ref
      .read(grandTestRepositoryProvider)
      .getGrandTest(courseId: courseId, grandTestId: grandTestId);
  if (test == null) {
    return buildGrandTestEligibilityFallback(
      courseId: courseId,
      grandTestId: grandTestId,
      studentId: studentId,
      reason: 'Grand test not found.',
    );
  }

  var lessonProgress = 0.0;
  var assignmentCompletion = 0.0;
  var averageScore = 0.0;
  var projectSubmitted = false;

  final enrollment = ref.read(courseEnrollmentProvider(courseId)).value;
  if (enrollment != null) {
    lessonProgress = enrollment.lessonProgressPercent;
  }

  try {
    final cert = await ref.read(
      certificateEligibilityProvider((
        courseId: courseId,
        studentId: studentId,
      )).future,
    );
    lessonProgress = cert.lessonProgress > 0
        ? cert.lessonProgress
        : lessonProgress;
    assignmentCompletion = cert.assignmentCompletion;
    averageScore = cert.assignmentAverage;
    projectSubmitted = cert.projectSubmitted;
  } catch (error) {
    AppLogger.warn('Grand test certificate eligibility lookup failed: $error');
  }

  final reasons = <String>[];
  if (lessonProgress < test.requiredLessonProgressPercent) {
    reasons.add(
      'Complete at least ${test.requiredLessonProgressPercent.toStringAsFixed(0)}% lessons.',
    );
  }
  if (assignmentCompletion < test.requiredAssignmentCompletionPercent) {
    reasons.add(
      'Complete at least ${test.requiredAssignmentCompletionPercent.toStringAsFixed(0)}% assignments.',
    );
  }
  if (averageScore < test.requiredAverageScorePercent) {
    reasons.add(
      'Maintain at least ${test.requiredAverageScorePercent.toStringAsFixed(0)}% average assignment score.',
    );
  }
  if (test.requireProjectSubmission && !projectSubmitted) {
    reasons.add('Submit or pass at least one project assignment.');
  }

  final lessonReadiness = _readinessRatio(
    lessonProgress,
    test.requiredLessonProgressPercent,
  );
  final assignmentReadiness = _readinessRatio(
    assignmentCompletion,
    test.requiredAssignmentCompletionPercent,
  );
  final scoreReadiness = _readinessRatio(
    averageScore,
    test.requiredAverageScorePercent,
  );
  final projectReadiness =
      !test.requireProjectSubmission || projectSubmitted ? 1.0 : 0.0;
  final readinessPercent =
      ((lessonReadiness * 30) +
              (assignmentReadiness * 25) +
              (scoreReadiness * 25) +
              (projectReadiness * 10) +
              10)
          .clamp(0, 100)
          .toDouble();

  return GrandTestEligibilityModel(
    courseId: courseId,
    grandTestId: grandTestId,
    studentId: studentId,
    readinessPercent: readinessPercent,
    isEligible: reasons.isEmpty,
    reasons: reasons,
    lessonProgress: lessonProgress,
    requiredLessonProgressPercent: test.requiredLessonProgressPercent,
    assignmentCompletion: assignmentCompletion,
    requiredAssignmentCompletionPercent: test.requiredAssignmentCompletionPercent,
    averageScore: averageScore,
    requiredAverageScorePercent: test.requiredAverageScorePercent,
    projectSubmitted: projectSubmitted,
    requireProjectSubmission: test.requireProjectSubmission,
    attemptsUsed: 0,
    maxAttempts: test.maxAttempts,
    missingRequirements: reasons,
    recommendations: reasons.isEmpty
        ? const ['You are ready for the Grand Test.']
        : const [
            'Your progress data was recovered from certificate readiness. Refresh after completing any missing item.',
          ],
    calculatedAt: DateTime.now(),
  );
}

double _readinessRatio(double actual, double required) {
  if (required <= 0) return 1;
  return (actual / required).clamp(0, 1).toDouble();
}

final studentGrandTestAttemptsProvider =
    StreamProvider.family<
      List<GrandTestAttemptModel>,
      ({String courseId, String grandTestId})
    >((ref, args) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <GrandTestAttemptModel>[]);
      return ref
          .watch(grandTestRepositoryProvider)
          .watchStudentAttempts(
            courseId: args.courseId,
            grandTestId: args.grandTestId,
            studentId: user.uid,
          );
    });

final latestStudentGrandTestAttemptProvider =
    StreamProvider.family<
      GrandTestAttemptModel?,
      ({String courseId, String grandTestId})
    >((ref, args) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(null);
      return ref
          .watch(grandTestRepositoryProvider)
          .watchStudentAttempts(
            courseId: args.courseId,
            grandTestId: args.grandTestId,
            studentId: user.uid,
          )
          .map((attempts) {
            if (attempts.isEmpty) return null;
            final submittedAttempts = attempts
                .where((attempt) => attempt.isSubmitted)
                .toList();
            return submittedAttempts.isNotEmpty
                ? submittedAttempts.first
                : attempts.first;
          });
    });

final grandTestAttemptsProvider =
    StreamProvider.family<
      List<GrandTestAttemptModel>,
      ({String courseId, String grandTestId})
    >((ref, args) {
      return ref
          .watch(grandTestRepositoryProvider)
          .watchGrandTestAttempts(
            courseId: args.courseId,
            grandTestId: args.grandTestId,
          );
    });

final grandTestActionProvider =
    AsyncNotifierProvider<GrandTestActionNotifier, void>(
      GrandTestActionNotifier.new,
    );

class GrandTestActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createGrandTest(GrandTestModel test) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateGrandTestPublish(
        teacherId: teacherId,
        currentGrandTestCount: await ref
            .read(grandTestRepositoryProvider)
            .countGrandTestsInCourse(test.courseId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      await ref
          .read(grandTestRepositoryProvider)
          .createGrandTest(test.copyWith(teacherId: teacherId));
      if (test.isPublished) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: test.courseId,
          itemId: test.grandTestId.isEmpty
              ? test.title.trim()
              : test.grandTestId,
          itemType: 'grand test',
          itemTitle: test.title,
          teacherId: teacherId,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> updateGrandTest(GrandTestModel test) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(grandTestRepositoryProvider).updateGrandTest(test);
    });
    return !state.hasError;
  }

  Future<bool> publishGrandTest({
    required String courseId,
    required String grandTestId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateGrandTestPublish(
        teacherId: teacherId,
        currentGrandTestCount: await ref
            .read(grandTestRepositoryProvider)
            .countPublishedGrandTestsInCourse(courseId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      await ref
          .read(grandTestRepositoryProvider)
          .publishGrandTest(
            courseId: courseId,
            grandTestId: grandTestId,
            teacherId: _requireUserId(),
          );
      final test = await ref
          .read(grandTestRepositoryProvider)
          .getGrandTest(courseId: courseId, grandTestId: grandTestId);
      if (test != null) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: courseId,
          itemId: grandTestId,
          itemType: 'grand test',
          itemTitle: test.title,
          teacherId: test.teacherId,
        );
        await _notifyEnrolledStudentsPublished(
          courseId: courseId,
          teacherId: test.teacherId,
          title: 'Grand test published',
          body: '"${test.title}" is now available.',
          grandTestId: grandTestId,
          itemTitle: test.title,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> archiveGrandTest({
    required String courseId,
    required String grandTestId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(grandTestRepositoryProvider)
          .archiveGrandTest(
            courseId: courseId,
            grandTestId: grandTestId,
            teacherId: _requireUserId(),
          );
    });
    return !state.hasError;
  }

  Future<GrandTestAttemptModel?> startAttempt({
    required String courseId,
    required String grandTestId,
  }) async {
    state = const AsyncLoading();
    GrandTestAttemptModel? attempt;
    state = await AsyncValue.guard(() async {
      attempt = await ref
          .read(grandTestRepositoryProvider)
          .startAttempt(
            courseId: courseId,
            grandTestId: grandTestId,
            studentId: _requireUserId(),
          );
    });
    return state.hasError ? null : attempt;
  }

  Future<bool> submitAttempt({
    required String courseId,
    required String grandTestId,
    required String attemptId,
    required Map<String, String> answers,
    required int warningsCount,
    required bool autoSubmitted,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final studentId = _requireUserId();
      final attemptRef = ref
          .read(firestoreProvider)
          .collection('courses')
          .doc(courseId)
          .collection('grandTests')
          .doc(grandTestId)
          .collection('attempts')
          .doc(attemptId);
      final priorSnap = await attemptRef.get();
      final prior = priorSnap.exists && priorSnap.data() != null
          ? GrandTestAttemptModel.fromFirestore(priorSnap)
          : null;
      final wasSubmitted = prior?.isSubmitted == true;

      await ref
          .read(grandTestRepositoryProvider)
          .submitAttempt(
            courseId: courseId,
            grandTestId: grandTestId,
            attemptId: attemptId,
            answers: answers,
            warningsCount: warningsCount,
            autoSubmitted: autoSubmitted,
          );

      if (wasSubmitted) return;

      final afterSnap = await attemptRef.get();
      if (!afterSnap.exists || afterSnap.data() == null) return;
      final attempt = GrandTestAttemptModel.fromFirestore(afterSnap);
      if (!attempt.isSubmitted) return;

      final test = await ref
          .read(grandTestRepositoryProvider)
          .getGrandTest(courseId: courseId, grandTestId: grandTestId);
      await _notifyGrandTestGraded(
        courseId: courseId,
        grandTestId: grandTestId,
        attemptId: attemptId,
        studentId: studentId,
        teacherId: test?.teacherId ?? '',
        itemTitle: test?.title ?? '',
        score: attempt.score,
        totalMarks: attempt.totalMarks,
        percentage: attempt.percentage,
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

  Future<void> _notifyGrandTestGraded({
    required String courseId,
    required String grandTestId,
    required String attemptId,
    required String studentId,
    required String teacherId,
    required String itemTitle,
    required int score,
    required int totalMarks,
    required double percentage,
  }) async {
    try {
      final label = itemTitle.trim().isEmpty
          ? 'your grand test'
          : '"${itemTitle.trim()}"';
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: 'Grand test scored',
        body:
            '$label scored $score/$totalMarks (${percentage.toStringAsFixed(0)}%).',
        category: NotificationCategories.learning,
        event: NotificationEvents.learningSubmissionGraded,
        actorId: teacherId.trim().isEmpty ? null : teacherId.trim(),
        actorRole: 'system',
        relatedPath:
            'courses/$courseId/grandTests/$grandTestId/attempts/$attemptId',
        routeName: RouteNames.studentGrandTestResult,
        routeParams: {
          'courseId': courseId,
          'grandTestId': grandTestId,
        },
        meta: {
          'courseId': courseId,
          'grandTestId': grandTestId,
          'attemptId': attemptId,
          'studentId': studentId,
          'score': score,
          'totalMarks': totalMarks,
          'percentage': percentage,
          'kind': 'grand_test',
          if (itemTitle.trim().isNotEmpty) 'itemTitle': itemTitle.trim(),
        },
      );
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint(
        '[GrandTestActionNotifier] grand test graded notify failed '
        'courseId=$courseId grandTestId=$grandTestId: $error\n$stackTrace',
      );
    }
  }

  Future<void> _notifyEnrolledStudentsPublished({
    required String courseId,
    required String teacherId,
    required String title,
    required String body,
    required String grandTestId,
    required String itemTitle,
  }) async {
    try {
      final enrollments = await ref
          .read(enrollmentRepositoryProvider)
          .getCourseEnrollments(courseId);
      final recipientIds = enrollments
          .map((e) => e.studentId.trim())
          .where((id) => id.isNotEmpty && id != teacherId);
      if (recipientIds.isEmpty) return;

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      await ref.read(notificationServiceProvider).notifyMany(
        recipientIds: recipientIds,
        title: title,
        body: body,
        category: NotificationCategories.learning,
        event: NotificationEvents.learningGrandTestPublished,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'courses/$courseId/grandTests/$grandTestId',
        routeName: RouteNames.studentGrandTestAttempt,
        routeParams: {
          'courseId': courseId,
          'grandTestId': grandTestId,
        },
        meta: {
          'courseId': courseId,
          'grandTestId': grandTestId,
          'itemTitle': itemTitle,
        },
      );
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint(
        '[GrandTestActionNotifier] grand test publish notify failed '
        'courseId=$courseId grandTestId=$grandTestId: $error\n$stackTrace',
      );
    }
  }
}
