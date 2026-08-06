import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enrollment_model.dart';
import '../models/grand_test_attempt_model.dart';
import '../models/mcq_assignment_model.dart';
import '../models/mcq_attempt_model.dart';
import '../models/project_submission_model.dart';

/// Result of recomputing a student's course progress from live course content.
class CourseProgressSnapshot {
  const CourseProgressSnapshot({
    required this.lessons,
    required this.quizzes,
    required this.projects,
    required this.grandTest,
  });

  final CourseRequirementCount lessons;
  final CourseRequirementCount quizzes;
  final CourseRequirementCount projects;
  final CourseRequirementCount grandTest;

  int get totalRequirements =>
      lessons.total + quizzes.total + projects.total + grandTest.total;

  int get completedRequirements =>
      lessons.completed +
      quizzes.completed +
      projects.completed +
      grandTest.completed;

  /// Overall completion: completed required items / all published required
  /// items. Modules the course does not use add 0 to both sides, so a course
  /// without projects or a grand test can still reach 100%.
  double get progressPercent {
    if (totalRequirements == 0) return 0;
    return ((completedRequirements / totalRequirements) * 100)
        .clamp(0, 100)
        .toDouble();
  }

  /// Lessons-only progress, used by certificate and grand test eligibility.
  double get lessonProgressPercent {
    if (lessons.total == 0) return 0;
    return ((lessons.completed / lessons.total) * 100).clamp(0, 100).toDouble();
  }

  bool get isCourseComplete =>
      totalRequirements > 0 && completedRequirements >= totalRequirements;

  Map<String, CourseRequirementCount> get breakdown => {
    CourseRequirementKind.lessons: lessons,
    CourseRequirementKind.quizzes: quizzes,
    CourseRequirementKind.projects: projects,
    CourseRequirementKind.grandTest: grandTest,
  };

  Map<String, dynamic> toEnrollmentUpdate({required String status}) {
    return {
      'totalLessons': lessons.total,
      'completedLessons': lessons.completed,
      'lessonProgressPercent': lessonProgressPercent,
      'progressPercent': progressPercent,
      'totalRequirements': totalRequirements,
      'completedRequirements': completedRequirements,
      'requirementBreakdown': {
        for (final entry in breakdown.entries) entry.key: entry.value.toJson(),
      },
      'status': status,
      'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}

/// Single source of truth for "how far through this course is the student".
///
/// Course completion is measured over every required item that is *currently
/// published*, not lessons alone:
///   denominator = published lessons + published MCQ quizzes + published
///                 project assignments + (1 when the course has a published
///                 grand test)
///   numerator   = completed lessons + submitted quiz attempts + submitted or
///                 graded project submissions + (1 when the grand test is
///                 passed)
///
/// Because both sides are recomputed from live content, publishing new content
/// increases the denominator and the percentage drops instead of staying at a
/// stale 100%.
class CourseProgressService {
  const CourseProgressService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _courseRef(String courseId) =>
      _firestore.collection('courses').doc(courseId);

  DocumentReference<Map<String, dynamic>> _enrollmentRef({
    required String courseId,
    required String studentId,
  }) {
    return _firestore.collection('enrollments').doc('${studentId}_$courseId');
  }

  Future<CourseProgressSnapshot> calculate({
    required String courseId,
    required String studentId,
  }) async {
    final courseRef = _courseRef(courseId);
    final enrollmentRef = _enrollmentRef(
      courseId: courseId,
      studentId: studentId,
    );

    final snapshots = await Future.wait([
      courseRef
          .collection('lessons')
          .where('isArchived', isEqualTo: false)
          .get(),
      enrollmentRef
          .collection('lessonProgress')
          .where('completed', isEqualTo: true)
          .get(),
      courseRef
          .collection('assignments')
          .where('status', isEqualTo: AssignmentStatus.published)
          .get(),
      courseRef
          .collection('grandTests')
          .where('status', isEqualTo: AssignmentStatus.published)
          .get(),
    ]);

    final lessonDocs = snapshots[0].docs;
    final lessonIds = lessonDocs.map((doc) => doc.id).toSet();
    // Progress documents for archived or removed lessons must not inflate the
    // completed count.
    final completedLessons = snapshots[1].docs
        .where((doc) => lessonIds.contains(doc.id))
        .length;

    final quizDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final projectDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snapshots[2].docs) {
      switch (_normalized(doc.data()['type'])) {
        case 'mcq':
          quizDocs.add(doc);
        case 'project':
          projectDocs.add(doc);
      }
    }

    final (completedQuizzes, completedProjects, grandTest) = await (
      _completedQuizCount(quizDocs: quizDocs, studentId: studentId),
      _completedProjectCount(projectDocs: projectDocs, studentId: studentId),
      _grandTestRequirement(
        grandTestDocs: snapshots[3].docs,
        studentId: studentId,
      ),
    ).wait;

    return CourseProgressSnapshot(
      lessons: CourseRequirementCount(
        total: lessonDocs.length,
        completed: completedLessons,
      ),
      quizzes: CourseRequirementCount(
        total: quizDocs.length,
        completed: completedQuizzes,
      ),
      projects: CourseRequirementCount(
        total: projectDocs.length,
        completed: completedProjects,
      ),
      grandTest: grandTest,
    );
  }

  /// Recomputes progress and writes it to the enrollment when anything changed.
  /// Returns null when the student is not enrolled.
  Future<CourseProgressSnapshot?> syncEnrollmentProgress({
    required String courseId,
    required String studentId,
  }) async {
    final enrollmentRef = _enrollmentRef(
      courseId: courseId,
      studentId: studentId,
    );
    final enrollmentSnapshot = await enrollmentRef.get();
    final enrollmentData = enrollmentSnapshot.data();
    if (!enrollmentSnapshot.exists || enrollmentData == null) return null;

    final snapshot = await calculate(courseId: courseId, studentId: studentId);
    final currentStatus = EnrollmentStatus.normalize(
      enrollmentData['status']?.toString(),
    );
    // A dropped enrollment stays dropped; only active/completed follow progress.
    final nextStatus = currentStatus == EnrollmentStatus.dropped
        ? EnrollmentStatus.dropped
        : (snapshot.isCourseComplete
              ? EnrollmentStatus.completed
              : EnrollmentStatus.active);

    if (!_needsUpdate(
      enrollmentData: enrollmentData,
      snapshot: snapshot,
      nextStatus: nextStatus,
      currentStatus: currentStatus,
    )) {
      return snapshot;
    }

    await enrollmentRef.update(snapshot.toEnrollmentUpdate(status: nextStatus));
    return snapshot;
  }

  bool _needsUpdate({
    required Map<String, dynamic> enrollmentData,
    required CourseProgressSnapshot snapshot,
    required String nextStatus,
    required String currentStatus,
  }) {
    if (nextStatus != currentStatus) return true;
    if (_intValue(enrollmentData['totalLessons']) != snapshot.lessons.total) {
      return true;
    }
    if (_intValue(enrollmentData['completedLessons']) !=
        snapshot.lessons.completed) {
      return true;
    }
    if (_intValue(enrollmentData['totalRequirements']) !=
        snapshot.totalRequirements) {
      return true;
    }
    if (_intValue(enrollmentData['completedRequirements']) !=
        snapshot.completedRequirements) {
      return true;
    }
    if (!enrollmentData.containsKey('requirementBreakdown')) return true;
    return (_doubleValue(enrollmentData['progressPercent']) -
                    snapshot.progressPercent)
                .abs() >
            0.01 ||
        (_doubleValue(enrollmentData['lessonProgressPercent']) -
                    snapshot.lessonProgressPercent)
                .abs() >
            0.01;
  }

  Future<int> _completedQuizCount({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> quizDocs,
    required String studentId,
  }) async {
    if (quizDocs.isEmpty) return 0;
    final attempts = await Future.wait(
      quizDocs.map(
        (doc) => doc.reference.collection('attempts').doc(studentId).get(),
      ),
    );
    return attempts
        .where(
          (attempt) =>
              _normalized(attempt.data()?['status']) ==
              McqAttemptStatus.submitted,
        )
        .length;
  }

  Future<int> _completedProjectCount({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> projectDocs,
    required String studentId,
  }) async {
    if (projectDocs.isEmpty) return 0;
    final submissions = await Future.wait(
      projectDocs.map(
        (doc) => doc.reference.collection('submissions').doc(studentId).get(),
      ),
    );
    return submissions.where((submission) {
      final data = submission.data();
      if (data == null) return false;
      final status = ProjectSubmissionStatus.normalize(
        data['status']?.toString(),
      );
      return status == ProjectSubmissionStatus.submitted ||
          status == ProjectSubmissionStatus.graded;
    }).length;
  }

  /// Grand tests count as a single requirement: pass the course grand test.
  /// When several are published the most recently updated one is used, matching
  /// how certificate eligibility picks the active grand test.
  Future<CourseRequirementCount> _grandTestRequirement({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> grandTestDocs,
    required String studentId,
  }) async {
    if (grandTestDocs.isEmpty) return const CourseRequirementCount();

    final sorted = [...grandTestDocs]
      ..sort(
        (a, b) => _dateValue(
          b.data()['updatedAt'],
        ).compareTo(_dateValue(a.data()['updatedAt'])),
      );

    final attempts = await sorted.first.reference
        .collection('attempts')
        .where('studentId', isEqualTo: studentId)
        .get();
    final passed = attempts.docs
        .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
        .any((attempt) => attempt.isSubmitted && attempt.passed);
    return CourseRequirementCount(total: 1, completed: passed ? 1 : 0);
  }

  String _normalized(Object? value) =>
      value is String ? value.trim().toLowerCase() : '';

  DateTime _dateValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
