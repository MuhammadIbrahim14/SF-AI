import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../payment/providers/payment_providers.dart';
import '../data/models/mcq_assignment_model.dart';
import '../data/models/mcq_attempt_model.dart';
import '../data/models/project_assignment_model.dart';
import '../data/models/project_submission_model.dart';
import '../data/repositories/assignment_repository.dart';
import '../services/course_update_mailer.dart';
import 'enrollment_provider.dart';

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return FirestoreAssignmentRepository(ref.watch(firestoreProvider));
});

final teacherAssignmentsProvider =
    StreamProvider.family<List<McqAssignmentModel>, String>((ref, courseId) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchTeacherAssignments(courseId);
    });

final publishedAssignmentsProvider =
    StreamProvider.family<List<McqAssignmentModel>, String>((ref, courseId) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchPublishedAssignments(courseId);
    });

final assignmentDetailProvider =
    FutureProvider.family<
      McqAssignmentModel?,
      ({String courseId, String assignmentId})
    >((ref, args) {
      return ref
          .watch(assignmentRepositoryProvider)
          .getAssignment(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
          );
    });

final studentAssignmentAttemptProvider =
    StreamProvider.family<
      McqAttemptModel?,
      ({String courseId, String assignmentId})
    >((ref, args) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(null);
      return ref
          .watch(assignmentRepositoryProvider)
          .watchAttempt(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
            studentId: user.uid,
          );
    });

final assignmentAttemptsProvider =
    StreamProvider.family<
      List<McqAttemptModel>,
      ({String courseId, String assignmentId})
    >((ref, args) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchAttempts(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
          );
    });

final teacherProjectAssignmentsProvider =
    StreamProvider.family<List<ProjectAssignmentModel>, String>((
      ref,
      courseId,
    ) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchTeacherProjectAssignments(courseId);
    });

final publishedProjectAssignmentsProvider =
    StreamProvider.family<List<ProjectAssignmentModel>, String>((
      ref,
      courseId,
    ) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchPublishedProjectAssignments(courseId);
    });

final projectAssignmentDetailProvider =
    FutureProvider.family<
      ProjectAssignmentModel?,
      ({String courseId, String assignmentId})
    >((ref, args) {
      return ref
          .watch(assignmentRepositoryProvider)
          .getProjectAssignment(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
          );
    });

final studentProjectSubmissionProvider =
    StreamProvider.family<
      ProjectSubmissionModel?,
      ({String courseId, String assignmentId})
    >((ref, args) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(null);
      return ref
          .watch(assignmentRepositoryProvider)
          .watchProjectSubmission(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
            studentId: user.uid,
          );
    });

final projectSubmissionProviderForStudent =
    StreamProvider.family<
      ProjectSubmissionModel?,
      ({String courseId, String assignmentId, String studentId})
    >((ref, args) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchProjectSubmission(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
            studentId: args.studentId,
          );
    });

final projectSubmissionsProvider =
    StreamProvider.family<
      List<ProjectSubmissionModel>,
      ({String courseId, String assignmentId})
    >((ref, args) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchProjectSubmissions(
            courseId: args.courseId,
            assignmentId: args.assignmentId,
          );
    });

final assignmentActionProvider =
    AsyncNotifierProvider<AssignmentActionNotifier, void>(
      AssignmentActionNotifier.new,
    );

class AssignmentActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createAssignment(McqAssignmentModel assignment) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateAssignmentPublish(
        teacherId: teacherId,
        currentAssignmentCount: await ref
            .read(assignmentRepositoryProvider)
            .countPublishedAssignmentsInCourse(assignment.courseId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      await ref
          .read(assignmentRepositoryProvider)
          .createAssignment(assignment.copyWith(teacherId: teacherId));
      if (assignment.isPublished) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: assignment.courseId,
          itemId: assignment.assignmentId.isEmpty
              ? assignment.title.trim()
              : assignment.assignmentId,
          itemType: 'assignment',
          itemTitle: assignment.title,
          teacherId: teacherId,
          dueDateLabel: assignment.dueDate == null
              ? ''
              : assignment.dueDate!.toIso8601String().split('T').first,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> updateAssignment(McqAssignmentModel assignment) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(assignmentRepositoryProvider).updateAssignment(assignment);
    });
    return !state.hasError;
  }

  Future<bool> publishAssignment({
    required String courseId,
    required String assignmentId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateAssignmentPublish(
        teacherId: teacherId,
        currentAssignmentCount: await ref
            .read(assignmentRepositoryProvider)
            .countPublishedAssignmentsInCourse(courseId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      await ref
          .read(assignmentRepositoryProvider)
          .publishAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
            teacherId: _requireUserId(),
          );
      final assignment = await ref
          .read(assignmentRepositoryProvider)
          .getAssignment(courseId: courseId, assignmentId: assignmentId);
      if (assignment != null) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: courseId,
          itemId: assignmentId,
          itemType: 'assignment',
          itemTitle: assignment.title,
          teacherId: assignment.teacherId,
          dueDateLabel: assignment.dueDate == null
              ? ''
              : assignment.dueDate!.toIso8601String().split('T').first,
        );
        await _notifyEnrolledStudentsPublished(
          courseId: courseId,
          teacherId: assignment.teacherId,
          title: 'New assignment published',
          body: '"${assignment.title}" is now available.',
          event: NotificationEvents.learningAssignmentPublished,
          relatedPath: 'courses/$courseId/assignments/$assignmentId',
          routeName: RouteNames.studentAssignments,
          routeParams: {
            'courseId': courseId,
          },
          meta: {
            'courseId': courseId,
            'assignmentId': assignmentId,
            'itemTitle': assignment.title,
          },
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> archiveAssignment({
    required String courseId,
    required String assignmentId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(assignmentRepositoryProvider)
          .archiveAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
            teacherId: _requireUserId(),
          );
    });
    return !state.hasError;
  }

  Future<bool> startAttempt({
    required String courseId,
    required String assignmentId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(assignmentRepositoryProvider)
          .startAttempt(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: _requireUserId(),
          );
    });
    return !state.hasError;
  }

  Future<bool> submitAttempt({
    required String courseId,
    required String assignmentId,
    required Map<String, String> answers,
    required int warningsCount,
    required bool autoSubmitted,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final studentId = _requireUserId();
      final priorAttempt = await ref
          .read(assignmentRepositoryProvider)
          .watchAttempt(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
          )
          .first;
      final wasSubmitted = priorAttempt?.isSubmitted == true;

      await ref
          .read(assignmentRepositoryProvider)
          .submitAttempt(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
            answers: answers,
            warningsCount: warningsCount,
            autoSubmitted: autoSubmitted,
          );

      if (wasSubmitted) return;

      final assignment = await ref
          .read(assignmentRepositoryProvider)
          .getAssignment(courseId: courseId, assignmentId: assignmentId);
      final attempt = await ref
          .read(assignmentRepositoryProvider)
          .watchAttempt(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
          )
          .first;

      await _notifySubmissionReceived(
        courseId: courseId,
        assignmentId: assignmentId,
        studentId: studentId,
        teacherId: assignment?.teacherId ?? attempt?.teacherId ?? '',
        itemTitle: assignment?.title ?? '',
        kind: 'assignment',
        relatedPath:
            'courses/$courseId/assignments/$assignmentId/attempts/$studentId',
        routeName: RouteNames.teacherAssignmentResults,
      );

      if (attempt != null && attempt.isSubmitted) {
        await _notifyMcqSubmissionGraded(
          courseId: courseId,
          assignmentId: assignmentId,
          studentId: studentId,
          teacherId: attempt.teacherId,
          itemTitle: assignment?.title ?? '',
          score: attempt.score,
          totalMarks: attempt.totalMarks,
          percentage: attempt.percentage,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> createProjectAssignment(
    ProjectAssignmentModel assignment,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      await ref
          .read(assignmentRepositoryProvider)
          .createProjectAssignment(assignment.copyWith(teacherId: teacherId));
      if (assignment.isPublished) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: assignment.courseId,
          itemId: assignment.assignmentId.isEmpty
              ? assignment.title.trim()
              : assignment.assignmentId,
          itemType: 'project',
          itemTitle: assignment.title,
          teacherId: teacherId,
          dueDateLabel: assignment.dueDate == null
              ? ''
              : assignment.dueDate!.toIso8601String().split('T').first,
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> updateProjectAssignment(
    ProjectAssignmentModel assignment,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(assignmentRepositoryProvider)
          .updateProjectAssignment(assignment);
    });
    return !state.hasError;
  }

  Future<bool> publishProjectAssignment({
    required String courseId,
    required String assignmentId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      final service = ref.read(teacherSubscriptionServiceProvider);
      final result = await service.validateProjectPublish(
        teacherId: teacherId,
        currentProjectCount: await ref
            .read(assignmentRepositoryProvider)
            .countPublishedProjectAssignmentsInCourse(courseId),
      );
      if (!result.allowed) {
        throw StateError(result.message);
      }
      await ref
          .read(assignmentRepositoryProvider)
          .publishProjectAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
            teacherId: _requireUserId(),
          );
      final assignment = await ref
          .read(assignmentRepositoryProvider)
          .getProjectAssignment(courseId: courseId, assignmentId: assignmentId);
      if (assignment != null) {
        await CourseUpdateMailer(ref).sendCourseUpdate(
          courseId: courseId,
          itemId: assignmentId,
          itemType: 'project',
          itemTitle: assignment.title,
          teacherId: assignment.teacherId,
          dueDateLabel: assignment.dueDate == null
              ? ''
              : assignment.dueDate!.toIso8601String().split('T').first,
        );
        await _notifyEnrolledStudentsPublished(
          courseId: courseId,
          teacherId: assignment.teacherId,
          title: 'New project published',
          body: '"${assignment.title}" is now available.',
          event: NotificationEvents.learningProjectPublished,
          relatedPath: 'courses/$courseId/assignments/$assignmentId',
          routeName: RouteNames.studentProjectSubmission,
          routeParams: {
            'courseId': courseId,
            'assignmentId': assignmentId,
          },
          meta: {
            'courseId': courseId,
            'assignmentId': assignmentId,
            'itemTitle': assignment.title,
          },
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> archiveProjectAssignment({
    required String courseId,
    required String assignmentId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(assignmentRepositoryProvider)
          .archiveProjectAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
            teacherId: _requireUserId(),
          );
    });
    return !state.hasError;
  }

  Future<bool> submitProject({
    required String courseId,
    required String assignmentId,
    required String projectDescription,
    required String githubLink,
    required String liveDemoLink,
    required String additionalNotes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final studentId = _requireUserId();
      await ref
          .read(assignmentRepositoryProvider)
          .submitProject(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
            projectDescription: projectDescription,
            githubLink: githubLink,
            liveDemoLink: liveDemoLink,
            additionalNotes: additionalNotes,
          );
      final assignment = await ref
          .read(assignmentRepositoryProvider)
          .getProjectAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
          );
      await _notifySubmissionReceived(
        courseId: courseId,
        assignmentId: assignmentId,
        studentId: studentId,
        teacherId: assignment?.teacherId ?? '',
        itemTitle: assignment?.title ?? '',
        kind: 'project',
        relatedPath:
            'courses/$courseId/assignments/$assignmentId/submissions/$studentId',
        routeName: RouteNames.teacherProjectSubmissions,
      );
    });
    return !state.hasError;
  }

  Future<bool> reviewProjectSubmission({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String status,
    required int marks,
    required String feedback,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = _requireUserId();
      await ref
          .read(assignmentRepositoryProvider)
          .reviewProjectSubmission(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
            teacherId: teacherId,
            status: status,
            marks: marks,
            feedback: feedback,
          );
      final reviewed =
          status == ProjectSubmissionStatus.graded ||
          status == ProjectSubmissionStatus.rejected;
      if (reviewed) {
        await _notifySubmissionGraded(
          courseId: courseId,
          assignmentId: assignmentId,
          studentId: studentId,
          teacherId: teacherId,
          status: status,
          marks: marks,
        );
      }
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();

  String _requireUserId() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw StateError('A signed-in user is required.');
    return user.uid;
  }

  String get _actorName {
    final name = (ref.read(currentUserProvider).value?.fullName ?? '').trim();
    return name;
  }

  Future<void> _notifyEnrolledStudentsPublished({
    required String courseId,
    required String teacherId,
    required String title,
    required String body,
    required String event,
    required String relatedPath,
    required String routeName,
    required Map<String, String> routeParams,
    required Map<String, dynamic> meta,
  }) async {
    try {
      final enrollments = await ref
          .read(enrollmentRepositoryProvider)
          .getCourseEnrollments(courseId);
      final recipientIds = enrollments
          .map((e) => e.studentId.trim())
          .where((id) => id.isNotEmpty && id != teacherId);
      if (recipientIds.isEmpty) return;

      final actorName = _actorName;
      await ref.read(notificationServiceProvider).notifyMany(
        recipientIds: recipientIds,
        title: title,
        body: body,
        category: NotificationCategories.learning,
        event: event,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: relatedPath,
        routeName: routeName,
        routeParams: routeParams,
        meta: meta,
      );
    } catch (_) {
      AppLogger.warn('Assignment publication notification could not be sent.');
    }
  }

  Future<void> _notifySubmissionReceived({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String teacherId,
    required String itemTitle,
    required String kind,
    required String relatedPath,
    required String routeName,
  }) async {
    try {
      final tid = teacherId.trim();
      if (tid.isEmpty || tid == studentId) return;

      final label = itemTitle.trim().isEmpty
          ? (kind == 'project' ? 'a project' : 'an assignment')
          : '"${itemTitle.trim()}"';
      final actorName = _actorName;
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: tid,
        title: kind == 'project' ? 'Project submitted' : 'Assignment submitted',
        body: '${actorName.isEmpty ? 'A student' : actorName} submitted $label.',
        category: NotificationCategories.learning,
        event: NotificationEvents.learningSubmissionReceived,
        actorId: studentId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'student',
        relatedPath: relatedPath,
        routeName: routeName,
        routeParams: {
          'courseId': courseId,
          'assignmentId': assignmentId,
        },
        meta: {
          'courseId': courseId,
          'assignmentId': assignmentId,
          'studentId': studentId,
          'kind': kind,
          if (itemTitle.trim().isNotEmpty) 'itemTitle': itemTitle.trim(),
        },
      );
    } catch (_) {
      AppLogger.warn('Assignment submission notification could not be sent.');
    }
  }

  Future<void> _notifyMcqSubmissionGraded({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String teacherId,
    required String itemTitle,
    required int score,
    required int totalMarks,
    required double percentage,
  }) async {
    try {
      final label = itemTitle.trim().isEmpty
          ? 'your assignment'
          : '"${itemTitle.trim()}"';
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: 'Assignment scored',
        body:
            '$label scored $score/$totalMarks (${percentage.toStringAsFixed(0)}%).',
        category: NotificationCategories.learning,
        event: NotificationEvents.learningSubmissionGraded,
        actorId: teacherId.trim().isEmpty ? null : teacherId.trim(),
        actorRole: 'system',
        relatedPath:
            'courses/$courseId/assignments/$assignmentId/attempts/$studentId',
        routeName: RouteNames.studentAssignmentResult,
        routeParams: {
          'courseId': courseId,
          'assignmentId': assignmentId,
        },
        meta: {
          'courseId': courseId,
          'assignmentId': assignmentId,
          'studentId': studentId,
          'score': score,
          'totalMarks': totalMarks,
          'percentage': percentage,
          'kind': 'mcq',
          if (itemTitle.trim().isNotEmpty) 'itemTitle': itemTitle.trim(),
        },
      );
    } catch (_) {
      AppLogger.warn('Assignment grading notification could not be sent.');
    }
  }

  Future<void> _notifySubmissionGraded({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String teacherId,
    required String status,
    required int marks,
  }) async {
    try {
      final assignment = await ref
          .read(assignmentRepositoryProvider)
          .getProjectAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
          );
      final itemTitle = (assignment?.title ?? '').trim();
      final label = itemTitle.isEmpty ? 'your project' : '"$itemTitle"';
      final isGraded = status == ProjectSubmissionStatus.graded;
      final actorName = _actorName;
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: isGraded ? 'Project graded' : 'Project review update',
        body: isGraded
            ? '$label was graded ($marks marks).'
            : '$label needs changes after review.',
        category: NotificationCategories.learning,
        event: NotificationEvents.learningSubmissionGraded,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath:
            'courses/$courseId/assignments/$assignmentId/submissions/$studentId',
        routeName: RouteNames.studentProjectStatus,
        routeParams: {
          'courseId': courseId,
          'assignmentId': assignmentId,
        },
        meta: {
          'courseId': courseId,
          'assignmentId': assignmentId,
          'studentId': studentId,
          'status': status,
          'marks': marks,
          if (itemTitle.isNotEmpty) 'itemTitle': itemTitle,
        },
      );
    } catch (_) {
      AppLogger.warn('Assignment review notification could not be sent.');
    }
  }
}
