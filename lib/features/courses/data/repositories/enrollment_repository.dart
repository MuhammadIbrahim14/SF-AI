import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../models/course_model.dart';
import '../models/enrollment_model.dart';
import '../services/course_progress_service.dart';

abstract class EnrollmentRepository {
  Future<String> enroll({
    required CourseModel course,
    required String studentId,
  });
  Stream<EnrollmentModel?> watchEnrollment({
    required String courseId,
    required String studentId,
  });
  Stream<List<EnrollmentModel>> watchStudentEnrollments(String studentId);
  Stream<List<EnrollmentModel>> watchCourseEnrollments(String courseId);
  Future<List<EnrollmentModel>> getCourseEnrollments(String courseId);
  Future<EnrollmentModel?> getEnrollmentByStudentAndCourse({
    required String studentId,
    required String courseId,
  });
  Future<void> createEnrollment(EnrollmentModel enrollment);
  Future<void> markLessonComplete({
    required String courseId,
    required String lessonId,
    required String studentId,
    bool verifiedCompleted = true,
    String completionMode = 'simple',
    Map<String, dynamic> completionEvidence = const <String, dynamic>{},
  });

  /// Recomputes overall course progress from live course content so newly
  /// published lessons/quizzes/projects/grand tests are reflected immediately.
  Future<CourseProgressSnapshot?> syncCourseProgress({
    required String courseId,
    required String studentId,
  });
  Future<LessonReadProgress> getLessonReadProgress({
    required String courseId,
    required String lessonId,
    required String studentId,
  });
  Future<void> recordLessonReadSeconds({
    required String courseId,
    required String lessonId,
    required String studentId,
    required int readSeconds,
  });
}

/// Study time already banked for a lesson across previous visits.
class LessonReadProgress {
  const LessonReadProgress({this.readSeconds = 0});

  final int readSeconds;
}

class FirestoreEnrollmentRepository implements EnrollmentRepository {
  const FirestoreEnrollmentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _enrollments =>
      _firestore.collection('enrollments');

  String _enrollmentId(String studentId, String courseId) =>
      '${studentId}_$courseId';

  @override
  Future<String> enroll({
    required CourseModel course,
    required String studentId,
  }) async {
    if (!course.isPublished) {
      throw const FirestoreException('Only published courses can be enrolled.');
    }

    final enrollmentId = _enrollmentId(studentId, course.id);
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _enrollments.doc(enrollmentId);
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) return;

        final lessonsSnapshot = await _firestore
            .collection('courses')
            .doc(course.id)
            .collection('lessons')
            .where('isArchived', isEqualTo: false)
            .get();

        final enrollment = EnrollmentModel(
          enrollmentId: enrollmentId,
          courseId: course.id,
          studentId: studentId,
          teacherId: course.teacherId,
          enrolledAt: DateTime.now(),
          progressPercent: 0,
          completedLessons: 0,
          totalLessons: lessonsSnapshot.docs.length,
          status: EnrollmentStatus.active,
        );
        transaction.set(docRef, enrollment.toJson());
      });
      return enrollmentId;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to enroll: ${e.toString()}');
    }
  }

  @override
  Stream<EnrollmentModel?> watchEnrollment({
    required String courseId,
    required String studentId,
  }) {
    return _enrollments.doc(_enrollmentId(studentId, courseId)).snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return EnrollmentModel.fromFirestore(snapshot);
      },
    );
  }

  @override
  Stream<List<EnrollmentModel>> watchStudentEnrollments(String studentId) {
    return _enrollments
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final enrollments = snapshot.docs
              .map((doc) => EnrollmentModel.fromFirestore(doc))
              .toList();
          enrollments.sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
          return enrollments;
        });
  }

  @override
  Stream<List<EnrollmentModel>> watchCourseEnrollments(String courseId) {
    return _enrollments
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EnrollmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<List<EnrollmentModel>> getCourseEnrollments(String courseId) async {
    try {
      final snapshot = await _enrollments
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: EnrollmentStatus.active)
          .get();
      return snapshot.docs
          .map((doc) => EnrollmentModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to load course enrollments: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markLessonComplete({
    required String courseId,
    required String lessonId,
    required String studentId,
    bool verifiedCompleted = true,
    String completionMode = 'simple',
    Map<String, dynamic> completionEvidence = const <String, dynamic>{},
  }) async {
    final enrollmentId = _enrollmentId(studentId, courseId);
    final enrollmentRef = _enrollments.doc(enrollmentId);
    final progressRef = enrollmentRef
        .collection('lessonProgress')
        .doc(lessonId);

    try {
      final now = DateTime.now();
      final readSeconds = _readSecondsFrom(completionEvidence);
      await progressRef.set({
        'lessonId': lessonId,
        'studentId': studentId,
        'courseId': courseId,
        'viewed': true,
        'completed': true,
        'verifiedCompleted': verifiedCompleted,
        'completionMode': completionMode,
        'completionEvidence': completionEvidence,
        if (readSeconds > 0) 'readSeconds': readSeconds,
        'completedAt': Timestamp.fromDate(now),
        'viewedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      await CourseProgressService(
        _firestore,
      ).syncEnrollmentProgress(courseId: courseId, studentId: studentId);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update progress: ${e.toString()}');
    }
  }

  @override
  Future<CourseProgressSnapshot?> syncCourseProgress({
    required String courseId,
    required String studentId,
  }) async {
    try {
      return await CourseProgressService(
        _firestore,
      ).syncEnrollmentProgress(courseId: courseId, studentId: studentId);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to refresh course progress: ${e.toString()}',
      );
    }
  }

  @override
  Future<LessonReadProgress> getLessonReadProgress({
    required String courseId,
    required String lessonId,
    required String studentId,
  }) async {
    try {
      final snapshot = await _enrollments
          .doc(_enrollmentId(studentId, courseId))
          .collection('lessonProgress')
          .doc(lessonId)
          .get();
      final data = snapshot.data();
      if (data == null) return const LessonReadProgress();
      return LessonReadProgress(readSeconds: _readSecondsFrom(data));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to load lesson read time: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> recordLessonReadSeconds({
    required String courseId,
    required String lessonId,
    required String studentId,
    required int readSeconds,
  }) async {
    if (readSeconds <= 0) return;
    try {
      final now = DateTime.now();
      await _enrollments
          .doc(_enrollmentId(studentId, courseId))
          .collection('lessonProgress')
          .doc(lessonId)
          .set({
            'lessonId': lessonId,
            'studentId': studentId,
            'courseId': courseId,
            'viewed': true,
            'readSeconds': readSeconds,
            'viewedAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to save lesson read time: ${e.toString()}',
      );
    }
  }

  int _readSecondsFrom(Map<String, dynamic> data) {
    final direct = data['readSeconds'];
    if (direct is num) return direct.toInt();
    final evidence = data['completionEvidence'];
    if (evidence is Map) {
      final nested = evidence['readSeconds'];
      if (nested is num) return nested.toInt();
    }
    return 0;
  }

  @override
  Future<EnrollmentModel?> getEnrollmentByStudentAndCourse({
    required String studentId,
    required String courseId,
  }) async {
    try {
      final snapshot = await _enrollments
          .doc(_enrollmentId(studentId, courseId))
          .get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      return EnrollmentModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to load enrollment: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> createEnrollment(EnrollmentModel enrollment) async {
    try {
      await _enrollments.doc(enrollment.enrollmentId).set(
        enrollment.toJson(),
        SetOptions(merge: false),
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to create enrollment: ${e.toString()}',
      );
    }
  }
}
