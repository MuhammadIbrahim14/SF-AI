import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../data/models/teacher_dashboard_stats_model.dart';

final teacherDashboardStatsProvider =
    FutureProvider<TeacherDashboardStatsModel>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return TeacherDashboardStatsModel.empty;

      return TeacherDashboardStatsService(
        ref.watch(firestoreProvider),
      ).load(user.uid);
    });

class TeacherDashboardStatsService {
  const TeacherDashboardStatsService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<TeacherDashboardStatsModel> load(String teacherId) async {
    final results = await Future.wait([
      _safeGet(
        _firestore
            .collection('courses')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collection('enrollments')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collection('certificates')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('assignments')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('grandTests')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('submissions')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('attempts')
            .where('teacherId', isEqualTo: teacherId),
      ),
    ]);

    final courses = _docs(results[0]);
    final enrollments = _docs(results[1]);
    final certificates = _docs(results[2]);
    final assignments = _docs(results[3]);
    final grandTests = _docs(results[4]);
    final submissions = _docs(results[5]);
    final attempts = _docs(results[6]);

    final publishedCourses = courses
        .where((doc) => _isPublishedCourse(doc.data()))
        .length;
    final draftCourses = courses
        .where((doc) => _status(doc.data()['status'], 'draft') == 'draft')
        .length;

    courses.sort((a, b) {
      return _date(
        b.data()['updatedAt'],
      ).compareTo(_date(a.data()['updatedAt']));
    });
    final primaryCourse = courses.isEmpty ? null : courses.first;

    final studentIds = <String>{};
    final activeStudentIds = <String>{};
    var totalProgress = 0.0;
    var progressCount = 0;
    final completedEnrollmentPairs = <String>{};
    final completedEnrollmentCourses = <String, String>{};
    for (final enrollment in enrollments) {
      final data = enrollment.data();
      final courseId = _string(data['courseId']);
      final studentId = _string(data['studentId']);
      if (studentId.isNotEmpty) studentIds.add(studentId);
      if (_status(data['status'], 'active') == 'active' &&
          studentId.isNotEmpty) {
        activeStudentIds.add(studentId);
      }
      totalProgress += _double(data['progressPercent']).clamp(0, 100);
      progressCount++;
      final completed =
          _status(data['status']) == 'completed' ||
          _double(data['progressPercent']) >= 100;
      if (completed && courseId.isNotEmpty && studentId.isNotEmpty) {
        final pair = '${courseId}_$studentId';
        completedEnrollmentPairs.add(pair);
        completedEnrollmentCourses[pair] = courseId;
      }
    }

    final averageCourseCompletion = progressCount == 0
        ? 0.0
        : totalProgress / progressCount;

    final activeCertificates = certificates.where((doc) {
      return _status(doc.data()['status'], 'active') == 'active';
    }).toList();
    final courseCompletionCertificatePairs = certificates
        .where(
          (doc) =>
              _status(doc.data()['certificateType']) == 'course_completion',
        )
        .map((doc) {
          final data = doc.data();
          return '${_string(data['courseId'])}_${_string(data['studentId'])}';
        })
        .toSet();

    final pendingSubmissions =
        submissions.where((doc) {
          final status = _status(doc.data()['status']);
          return status == 'submitted';
        }).toList()..sort(
          (a, b) => _date(
            b.data()['updatedAt'],
          ).compareTo(_date(a.data()['updatedAt'])),
        );

    final submittedGrandAttempts =
        attempts.where((doc) {
          final data = doc.data();
          final hasGrandTest = _string(data['grandTestId']).isNotEmpty;
          final status = _status(data['status']);
          return hasGrandTest &&
              (status == 'submitted' || status == 'auto_submitted');
        }).toList()..sort(
          (a, b) =>
              _date(
                b.data()['submittedAt'],
                fallback: _date(b.data()['startedAt']),
              ).compareTo(
                _date(
                  a.data()['submittedAt'],
                  fallback: _date(a.data()['startedAt']),
                ),
              ),
        );

    final grandScores = submittedGrandAttempts
        .map((doc) => _double(doc.data()['percentage']).clamp(0, 100))
        .where((score) => score > 0)
        .toList();
    final averageGrandTestScore = grandScores.isEmpty
        ? 0.0
        : grandScores.reduce((a, b) => a + b) / grandScores.length;

    grandTests.sort((a, b) {
      return _date(
        b.data()['updatedAt'],
      ).compareTo(_date(a.data()['updatedAt']));
    });
    final firstGrandTest = grandTests.isEmpty ? null : grandTests.first;

    final pendingCertificatePairs = completedEnrollmentPairs
        .difference(courseCompletionCertificatePairs)
        .toList();
    final pendingCertificateCandidates = pendingCertificatePairs.length;
    final pendingCertificateCourseId = pendingCertificatePairs.isEmpty
        ? primaryCourse?.id
        : completedEnrollmentCourses[pendingCertificatePairs.first];

    final pendingWorks = <TeacherPendingWorkItem>[
      if (pendingSubmissions.isNotEmpty)
        TeacherPendingWorkItem(
          title: 'Project reviews pending',
          subtitle: 'Grade submitted projects and send feedback.',
          iconName: 'project',
          count: pendingSubmissions.length,
          courseId: _string(pendingSubmissions.first.data()['courseId']),
          assignmentId: _string(
            pendingSubmissions.first.data()['assignmentId'],
          ),
        ),
      if (submittedGrandAttempts.isNotEmpty)
        TeacherPendingWorkItem(
          title: 'Grand test attempts to review',
          subtitle: 'Open submitted attempts and inspect student outcomes.',
          iconName: 'grandTest',
          count: submittedGrandAttempts.length,
          courseId: _string(submittedGrandAttempts.first.data()['courseId']),
          grandTestId: _string(
            submittedGrandAttempts.first.data()['grandTestId'],
          ),
        ),
      if (pendingCertificateCandidates > 0)
        TeacherPendingWorkItem(
          title: 'Certificate candidates',
          subtitle: 'Students may be ready for course completion certificates.',
          iconName: 'certificate',
          count: pendingCertificateCandidates,
          courseId: pendingCertificateCourseId,
        ),
    ];

    final activities = _buildActivities(
      courses: courses,
      enrollments: enrollments,
      submissions: submissions,
      attempts: attempts,
      certificates: activeCertificates,
    );

    return TeacherDashboardStatsModel(
      totalCourses: courses.length,
      publishedCourses: publishedCourses,
      draftCourses: draftCourses,
      totalEnrolledStudents: studentIds.length,
      activeStudents: activeStudentIds.length,
      totalAssignments: assignments.length,
      pendingProjectReviews: pendingSubmissions.length,
      grandTestsCreated: grandTests.length,
      certificatesIssued: activeCertificates.length,
      averageGrandTestScore: averageGrandTestScore,
      averageCourseCompletion: averageCourseCompletion,
      teachingImpactScore: _impactScore(
        publishedCourses: publishedCourses,
        enrolledStudents: studentIds.length,
        assignmentsCreated: assignments.length,
        certificatesIssued: activeCertificates.length,
        grandTestsCreated: grandTests.length,
      ),
      primaryCourseId: primaryCourse?.id,
      primaryCourseTitle: primaryCourse == null
          ? ''
          : _label(primaryCourse.data()['title'], 'Course'),
      firstPendingProject: pendingSubmissions.isEmpty
          ? null
          : TeacherPendingProjectReview(
              courseId: _string(pendingSubmissions.first.data()['courseId']),
              assignmentId: _string(
                pendingSubmissions.first.data()['assignmentId'],
              ),
              studentId: _string(pendingSubmissions.first.data()['studentId']),
            ),
      firstGrandTestId: firstGrandTest?.id,
      pendingWorks: pendingWorks,
      activities: activities,
    );
  }

  List<TeacherDashboardActivityItem> _buildActivities({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> enrollments,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> certificates,
  }) {
    final items = <TeacherDashboardActivityItem>[];

    for (final enrollment in enrollments.take(8)) {
      final data = enrollment.data();
      items.add(
        TeacherDashboardActivityItem(
          title: 'Student enrolled',
          subtitle:
              'A learner joined ${_courseTitle(data['courseId'], courses)}.',
          iconName: 'enrollment',
          createdAt: _date(data['enrolledAt']),
          courseId: _string(data['courseId']),
        ),
      );
    }

    for (final submission in submissions.take(8)) {
      final data = submission.data();
      items.add(
        TeacherDashboardActivityItem(
          title: 'Project submitted',
          subtitle: 'A project submission is ready for review.',
          iconName: 'project',
          createdAt: _date(
            data['updatedAt'],
            fallback: _date(data['submittedAt']),
          ),
          courseId: _string(data['courseId']),
        ),
      );
    }

    for (final attempt in attempts.take(10)) {
      final data = attempt.data();
      final isGrandTest = _string(data['grandTestId']).isNotEmpty;
      final isMcq = _string(data['assignmentId']).isNotEmpty;
      final status = _status(data['status']);
      final submitted = status == 'submitted' || status == 'auto_submitted';
      if (!submitted || (!isGrandTest && !isMcq)) continue;
      items.add(
        TeacherDashboardActivityItem(
          title: isGrandTest ? 'Grand test attempted' : 'MCQ completed',
          subtitle:
              'Score ${_double(data['percentage']).clamp(0, 100).toStringAsFixed(0)}%',
          iconName: isGrandTest ? 'grandTest' : 'assignment',
          createdAt: _date(
            data['submittedAt'],
            fallback: _date(data['startedAt']),
          ),
          courseId: _string(data['courseId']),
        ),
      );
    }

    for (final certificate in certificates.take(8)) {
      final data = certificate.data();
      items.add(
        TeacherDashboardActivityItem(
          title: 'Certificate issued',
          subtitle: _string(data['title'], 'Course certificate issued.'),
          iconName: 'certificate',
          createdAt: _date(data['issuedAt']),
          courseId: _string(data['courseId']),
        ),
      );
    }

    for (final course in courses.take(5)) {
      final data = course.data();
      items.add(
        TeacherDashboardActivityItem(
          title: _isPublishedCourse(data)
              ? 'Course published'
              : 'Course updated',
          subtitle: _label(data['title'], 'Untitled course'),
          iconName: 'course',
          createdAt: _date(data['updatedAt']),
          courseId: course.id,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(8).toList();
  }

  String _courseTitle(
    Object? courseId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
  ) {
    final id = _string(courseId);
    for (final course in courses) {
      if (course.id == id) return _label(course.data()['title'], 'a course');
    }
    return 'a course';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs(Object? value) {
    final snapshot = value as QuerySnapshot<Map<String, dynamic>>?;
    return snapshot?.docs.toList() ??
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }

  bool _isPublishedCourse(Map<String, dynamic> data) {
    return _status(data['status']) == 'published' ||
        data['isPublished'] == true;
  }

  int _impactScore({
    required int publishedCourses,
    required int enrolledStudents,
    required int assignmentsCreated,
    required int certificatesIssued,
    required int grandTestsCreated,
  }) {
    final score =
        (_ratio(publishedCourses, 3) * 25) +
        (_ratio(enrolledStudents, 20) * 25) +
        (_ratio(assignmentsCreated, 10) * 20) +
        (_ratio(certificatesIssued, 10) * 20) +
        (_ratio(grandTestsCreated, 3) * 10);
    return score.clamp(0, 100).round();
  }

  double _ratio(int value, int target) {
    if (target <= 0) return 0;
    return (value / target).clamp(0, 1).toDouble();
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _safeGet(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get().timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }
}

String _string(Object? value, [String fallback = '']) {
  return value is String ? value.trim() : fallback;
}

String _status(Object? value, [String fallback = '']) {
  return _string(value, fallback).toLowerCase();
}

String _label(Object? value, [String fallback = '']) {
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

DateTime _date(Object? value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
  }
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return fallback ?? DateTime.now();
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
