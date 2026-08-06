import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';

final teacherAssessmentAnalyticsProvider =
    FutureProvider<TeacherAssessmentAnalytics>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return TeacherAssessmentAnalytics.empty;

      return TeacherAssessmentAnalyticsService(
        ref.watch(firestoreProvider),
      ).load(user.uid);
    });

class TeacherAssessmentAnalyticsService {
  const TeacherAssessmentAnalyticsService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<TeacherAssessmentAnalytics> load(String teacherId) async {
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
            .collectionGroup('assignments')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('attempts')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('submissions')
            .where('teacherId', isEqualTo: teacherId),
      ),
    ]);

    final courses = _docs(results[0]);
    final enrollments = _docs(results[1]);
    final assignments = _docs(results[2]);
    final attempts = _docs(results[3]);
    final submissions = _docs(results[4]);

    final courseTitles = <String, String>{
      for (final course in courses)
        course.id: _label(course.data()['title'], 'Untitled course'),
    };
    final enrolledStudentsByCourse = _enrolledStudentsByCourse(enrollments);

    final mcqAssignments = assignments.where((doc) {
      return _status(doc.data()['type'], 'mcq') == 'mcq';
    }).toList();
    final projectAssignments = assignments.where((doc) {
      return _status(doc.data()['type']) == 'project';
    }).toList();

    final submittedAttempts = attempts.where((doc) {
      final data = doc.data();
      return _string(data['assignmentId']).isNotEmpty &&
          _status(data['status']) == 'submitted';
    }).toList();

    final attemptsByAssignment =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final attempt in submittedAttempts) {
      final assignmentId = _string(attempt.data()['assignmentId']);
      if (assignmentId.isEmpty) continue;
      attemptsByAssignment.putIfAbsent(assignmentId, () => []).add(attempt);
    }

    final assignmentBreakdowns = <TeacherAssignmentBreakdown>[];
    var totalPendingAttempts = 0;
    for (final assignment in mcqAssignments) {
      final data = assignment.data();
      final courseId = _string(data['courseId']);
      final assignmentAttempts =
          attemptsByAssignment[assignment.id] ?? const [];
      final enrolledCount = enrolledStudentsByCourse[courseId]?.length ?? 0;
      final pending = _status(data['status']) == 'published'
          ? (enrolledCount - assignmentAttempts.length).clamp(0, enrolledCount)
          : 0;
      totalPendingAttempts += pending;

      assignmentBreakdowns.add(
        _assignmentBreakdown(
          assignmentId: assignment.id,
          courseId: courseId,
          title: _label(data['title'], 'Untitled assignment'),
          courseTitle: courseTitles[courseId] ?? 'Course',
          type: 'MCQ',
          status: _status(data['status'], 'draft'),
          attempts: assignmentAttempts,
          pendingCount: pending,
        ),
      );
    }
    assignmentBreakdowns.sort((a, b) {
      final pendingCompare = b.pendingCount.compareTo(a.pendingCount);
      if (pendingCompare != 0) return pendingCompare;
      return b.averageScore.compareTo(a.averageScore);
    });

    final projectSubmissionsByAssignment =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final submission in submissions) {
      final assignmentId = _string(submission.data()['assignmentId']);
      if (assignmentId.isEmpty) continue;
      projectSubmissionsByAssignment
          .putIfAbsent(assignmentId, () => [])
          .add(submission);
    }

    final projectBreakdowns = <TeacherAssignmentBreakdown>[];
    var totalMissingProjectSubmissions = 0;
    for (final assignment in projectAssignments) {
      final data = assignment.data();
      final courseId = _string(data['courseId']);
      final assignmentSubmissions =
          projectSubmissionsByAssignment[assignment.id] ?? const [];
      final enrolledCount = enrolledStudentsByCourse[courseId]?.length ?? 0;
      final missing = _status(data['status']) == 'published'
          ? (enrolledCount - assignmentSubmissions.length).clamp(
              0,
              enrolledCount,
            )
          : 0;
      totalMissingProjectSubmissions += missing;

      projectBreakdowns.add(
        _projectBreakdown(
          assignmentId: assignment.id,
          courseId: courseId,
          title: _label(data['title'], 'Untitled project'),
          courseTitle: courseTitles[courseId] ?? 'Course',
          status: _status(data['status'], 'draft'),
          submissions: assignmentSubmissions,
          pendingCount: missing,
        ),
      );
    }
    projectBreakdowns.sort((a, b) {
      final pendingCompare = b.pendingCount.compareTo(a.pendingCount);
      if (pendingCompare != 0) return pendingCompare;
      return b.gradedCount.compareTo(a.gradedCount);
    });

    final assignmentScores = submittedAttempts
        .map((doc) => _double(doc.data()['percentage']).clamp(0, 100))
        .toList();
    final averageAssignmentScore = _average(assignmentScores);
    final passedAttempts = submittedAttempts
        .where((doc) => doc.data()['passed'] == true)
        .length;
    final assignmentPassRate = submittedAttempts.isEmpty
        ? 0.0
        : (passedAttempts / submittedAttempts.length) * 100;
    final lowScoreCount = submittedAttempts
        .where((doc) => _double(doc.data()['percentage']) < 50)
        .length;

    final pendingProjectSubmissions =
        submissions.where((doc) {
          return _status(doc.data()['status']) == 'submitted';
        }).toList()..sort(
          (a, b) => _date(
            a.data()['submittedAt'],
          ).compareTo(_date(b.data()['submittedAt'])),
        );
    final gradedProjectSubmissions = submissions.where((doc) {
      return _status(doc.data()['status']) == 'graded';
    }).toList();
    final rejectedProjectSubmissions = submissions.where((doc) {
      return _status(doc.data()['status']) == 'rejected';
    }).length;
    final changesRequestedSubmissions = submissions.where((doc) {
      return _status(doc.data()['status']) == 'changes_requested';
    }).length;
    final projectScores = gradedProjectSubmissions
        .map((doc) => _double(doc.data()['percentage']).clamp(0, 100))
        .toList();

    final reviewDurations = gradedProjectSubmissions
        .map((doc) {
          final data = doc.data();
          final gradedAt = _nullableDate(data['gradedAt']);
          if (gradedAt == null) return null;
          final submittedAt = _date(data['submittedAt']);
          return gradedAt.difference(submittedAt);
        })
        .whereType<Duration>()
        .toList();

    final pendingByCourse = <TeacherCoursePendingReview>[];
    final pendingCourseCounts = <String, int>{};
    for (final submission in pendingProjectSubmissions) {
      final courseId = _string(submission.data()['courseId']);
      pendingCourseCounts[courseId] = (pendingCourseCounts[courseId] ?? 0) + 1;
    }
    for (final entry in pendingCourseCounts.entries) {
      pendingByCourse.add(
        TeacherCoursePendingReview(
          courseId: entry.key,
          courseTitle: courseTitles[entry.key] ?? 'Course',
          count: entry.value,
        ),
      );
    }
    pendingByCourse.sort((a, b) => b.count.compareTo(a.count));

    final reviewPriorityList = pendingProjectSubmissions.take(5).map((doc) {
      final data = doc.data();
      final courseId = _string(data['courseId']);
      return TeacherReviewPriority(
        courseId: courseId,
        assignmentId: _string(data['assignmentId']),
        studentId: _string(data['studentId']),
        courseTitle: courseTitles[courseId] ?? 'Course',
        submittedAt: _date(data['submittedAt']),
      );
    }).toList();

    final studentSignals = _studentSignals(
      attempts: submittedAttempts,
      submissions: gradedProjectSubmissions,
    );

    final recommendations = _recommendations(
      lowScoreCount: lowScoreCount,
      pendingAttempts: totalPendingAttempts,
      averageAssignmentScore: averageAssignmentScore,
      pendingProjectReviews: pendingProjectSubmissions.length,
      missingProjectSubmissions: totalMissingProjectSubmissions,
      pendingByCourse: pendingByCourse,
      topPerformers: studentSignals.topPerformers,
    );

    return TeacherAssessmentAnalytics(
      totalAssignments: mcqAssignments.length,
      activeAssignments: mcqAssignments
          .where((doc) => _status(doc.data()['status']) == 'published')
          .length,
      completedAttempts: submittedAttempts.length,
      pendingAttempts: totalPendingAttempts,
      averageScore: averageAssignmentScore,
      passRate: assignmentPassRate,
      lowScoreCount: lowScoreCount,
      assignmentBreakdowns: assignmentBreakdowns,
      topPerformers: studentSignals.topPerformers,
      strugglingStudents: studentSignals.strugglingStudents,
      studentsNotAttemptedCount: totalPendingAttempts,
      studentsNeedingFeedback: pendingProjectSubmissions.length,
      totalProjectAssignments: projectAssignments.length,
      totalProjectSubmissions: submissions.length,
      pendingProjectReviews: pendingProjectSubmissions.length,
      gradedProjectSubmissions: gradedProjectSubmissions.length,
      rejectedProjectSubmissions: rejectedProjectSubmissions,
      changesRequestedSubmissions: changesRequestedSubmissions,
      averageProjectScore: _average(projectScores),
      averageReviewTimeHours: _averageDurationHours(reviewDurations),
      missingProjectSubmissions: totalMissingProjectSubmissions,
      projectBreakdowns: projectBreakdowns,
      pendingReviewsByCourse: pendingByCourse,
      reviewPriorityList: reviewPriorityList,
      recommendations: recommendations,
      firstAssignmentCourseId: assignmentBreakdowns.isEmpty
          ? null
          : assignmentBreakdowns.first.courseId,
      firstAssignmentId: assignmentBreakdowns.isEmpty
          ? null
          : assignmentBreakdowns.first.assignmentId,
      firstProjectCourseId: projectBreakdowns.isEmpty
          ? null
          : projectBreakdowns.first.courseId,
      firstProjectId: projectBreakdowns.isEmpty
          ? null
          : projectBreakdowns.first.assignmentId,
    );
  }

  TeacherAssignmentBreakdown _assignmentBreakdown({
    required String assignmentId,
    required String courseId,
    required String title,
    required String courseTitle,
    required String type,
    required String status,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    required int pendingCount,
  }) {
    final scores = attempts
        .map(
          (doc) => _double(doc.data()['percentage']).clamp(0, 100).toDouble(),
        )
        .toList();
    final passed = attempts.where((doc) => doc.data()['passed'] == true).length;
    return TeacherAssignmentBreakdown(
      assignmentId: assignmentId,
      courseId: courseId,
      title: title,
      courseTitle: courseTitle,
      type: type,
      status: status,
      totalAttempts: attempts.length,
      averageScore: _average(scores),
      highestScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b),
      lowestScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b),
      passRate: attempts.isEmpty ? 0 : (passed / attempts.length) * 100,
      pendingCount: pendingCount,
      gradedCount: attempts.length,
    );
  }

  TeacherAssignmentBreakdown _projectBreakdown({
    required String assignmentId,
    required String courseId,
    required String title,
    required String courseTitle,
    required String status,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions,
    required int pendingCount,
  }) {
    final graded = submissions.where((doc) {
      return _status(doc.data()['status']) == 'graded';
    }).toList();
    final scores = graded
        .map(
          (doc) => _double(doc.data()['percentage']).clamp(0, 100).toDouble(),
        )
        .toList();
    final passed = scores.where((score) => score >= 60).length;
    return TeacherAssignmentBreakdown(
      assignmentId: assignmentId,
      courseId: courseId,
      title: title,
      courseTitle: courseTitle,
      type: 'Project',
      status: status,
      totalAttempts: submissions.length,
      averageScore: _average(scores),
      highestScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b),
      lowestScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b),
      passRate: graded.isEmpty ? 0 : (passed / graded.length) * 100,
      pendingCount: pendingCount,
      gradedCount: graded.length,
    );
  }

  _StudentSignalResult _studentSignals({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions,
  }) {
    final scoresByStudent = <String, List<double>>{};
    for (final attempt in attempts) {
      final studentId = _string(attempt.data()['studentId']);
      if (studentId.isEmpty) continue;
      scoresByStudent
          .putIfAbsent(studentId, () => [])
          .add(_double(attempt.data()['percentage']).clamp(0, 100));
    }
    for (final submission in submissions) {
      final studentId = _string(submission.data()['studentId']);
      if (studentId.isEmpty) continue;
      scoresByStudent
          .putIfAbsent(studentId, () => [])
          .add(_double(submission.data()['percentage']).clamp(0, 100));
    }

    final signals = scoresByStudent.entries.map((entry) {
      final average = _average(entry.value);
      return TeacherStudentPerformanceSignal(
        studentId: entry.key,
        label: 'Student ${_shortId(entry.key)}',
        averageScore: average,
        evidenceCount: entry.value.length,
      );
    }).toList()..sort((a, b) => b.averageScore.compareTo(a.averageScore));

    return _StudentSignalResult(
      topPerformers: signals
          .where((item) => item.averageScore >= 80)
          .take(5)
          .toList(),
      strugglingStudents:
          signals
              .where((item) => item.averageScore > 0 && item.averageScore < 50)
              .toList()
            ..sort((a, b) => a.averageScore.compareTo(b.averageScore)),
    );
  }

  List<String> _recommendations({
    required int lowScoreCount,
    required int pendingAttempts,
    required double averageAssignmentScore,
    required int pendingProjectReviews,
    required int missingProjectSubmissions,
    required List<TeacherCoursePendingReview> pendingByCourse,
    required List<TeacherStudentPerformanceSignal> topPerformers,
  }) {
    final items = <String>[];
    if (lowScoreCount > 0) {
      items.add(
        '$lowScoreCount students scored below 50%. Review the assignment and add a revision lesson.',
      );
    }
    if (averageAssignmentScore > 0 && averageAssignmentScore < 60) {
      items.add(
        'Average MCQ score is ${averageAssignmentScore.toStringAsFixed(0)}%. Consider a focused recap before the next test.',
      );
    }
    if (pendingAttempts > 0) {
      items.add(
        '$pendingAttempts expected assignment attempts are still missing. Send a course reminder.',
      );
    }
    if (pendingProjectReviews > 0) {
      items.add(
        '$pendingProjectReviews project submissions are waiting for feedback.',
      );
    }
    if (pendingByCourse.isNotEmpty) {
      items.add(
        '${pendingByCourse.first.courseTitle} has the highest pending review count.',
      );
    }
    if (missingProjectSubmissions > 0) {
      items.add(
        '$missingProjectSubmissions project submissions are missing across published projects.',
      );
    }
    if (topPerformers.isNotEmpty) {
      items.add(
        '${topPerformers.first.label} is showing strong assessment performance. Consider advanced practice.',
      );
    }
    if (items.isEmpty) {
      items.add(
        'Not enough assessment data yet. Publish assignments and review submissions to unlock insights.',
      );
    }
    return items.take(5).toList();
  }

  Map<String, Set<String>> _enrolledStudentsByCourse(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> enrollments,
  ) {
    final map = <String, Set<String>>{};
    for (final enrollment in enrollments) {
      final data = enrollment.data();
      if (_status(data['status'], 'active') == 'dropped') continue;
      final courseId = _string(data['courseId']);
      final studentId = _string(data['studentId']);
      if (courseId.isEmpty || studentId.isEmpty) continue;
      map.putIfAbsent(courseId, () => <String>{}).add(studentId);
    }
    return map;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs(Object? value) {
    final snapshot = value as QuerySnapshot<Map<String, dynamic>>?;
    return snapshot?.docs.toList() ??
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _safeGet(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get().timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }
}

class TeacherAssessmentAnalytics {
  const TeacherAssessmentAnalytics({
    required this.totalAssignments,
    required this.activeAssignments,
    required this.completedAttempts,
    required this.pendingAttempts,
    required this.averageScore,
    required this.passRate,
    required this.lowScoreCount,
    required this.assignmentBreakdowns,
    required this.topPerformers,
    required this.strugglingStudents,
    required this.studentsNotAttemptedCount,
    required this.studentsNeedingFeedback,
    required this.totalProjectAssignments,
    required this.totalProjectSubmissions,
    required this.pendingProjectReviews,
    required this.gradedProjectSubmissions,
    required this.rejectedProjectSubmissions,
    required this.changesRequestedSubmissions,
    required this.averageProjectScore,
    required this.averageReviewTimeHours,
    required this.missingProjectSubmissions,
    required this.projectBreakdowns,
    required this.pendingReviewsByCourse,
    required this.reviewPriorityList,
    required this.recommendations,
    required this.firstAssignmentCourseId,
    required this.firstAssignmentId,
    required this.firstProjectCourseId,
    required this.firstProjectId,
  });

  final int totalAssignments;
  final int activeAssignments;
  final int completedAttempts;
  final int pendingAttempts;
  final double averageScore;
  final double passRate;
  final int lowScoreCount;
  final List<TeacherAssignmentBreakdown> assignmentBreakdowns;
  final List<TeacherStudentPerformanceSignal> topPerformers;
  final List<TeacherStudentPerformanceSignal> strugglingStudents;
  final int studentsNotAttemptedCount;
  final int studentsNeedingFeedback;
  final int totalProjectAssignments;
  final int totalProjectSubmissions;
  final int pendingProjectReviews;
  final int gradedProjectSubmissions;
  final int rejectedProjectSubmissions;
  final int changesRequestedSubmissions;
  final double averageProjectScore;
  final double averageReviewTimeHours;
  final int missingProjectSubmissions;
  final List<TeacherAssignmentBreakdown> projectBreakdowns;
  final List<TeacherCoursePendingReview> pendingReviewsByCourse;
  final List<TeacherReviewPriority> reviewPriorityList;
  final List<String> recommendations;
  final String? firstAssignmentCourseId;
  final String? firstAssignmentId;
  final String? firstProjectCourseId;
  final String? firstProjectId;

  bool get hasAnyData =>
      totalAssignments > 0 ||
      totalProjectAssignments > 0 ||
      completedAttempts > 0 ||
      totalProjectSubmissions > 0;

  static const empty = TeacherAssessmentAnalytics(
    totalAssignments: 0,
    activeAssignments: 0,
    completedAttempts: 0,
    pendingAttempts: 0,
    averageScore: 0,
    passRate: 0,
    lowScoreCount: 0,
    assignmentBreakdowns: <TeacherAssignmentBreakdown>[],
    topPerformers: <TeacherStudentPerformanceSignal>[],
    strugglingStudents: <TeacherStudentPerformanceSignal>[],
    studentsNotAttemptedCount: 0,
    studentsNeedingFeedback: 0,
    totalProjectAssignments: 0,
    totalProjectSubmissions: 0,
    pendingProjectReviews: 0,
    gradedProjectSubmissions: 0,
    rejectedProjectSubmissions: 0,
    changesRequestedSubmissions: 0,
    averageProjectScore: 0,
    averageReviewTimeHours: 0,
    missingProjectSubmissions: 0,
    projectBreakdowns: <TeacherAssignmentBreakdown>[],
    pendingReviewsByCourse: <TeacherCoursePendingReview>[],
    reviewPriorityList: <TeacherReviewPriority>[],
    recommendations: <String>[
      'Not enough assessment data yet. Publish assignments and review submissions to unlock insights.',
    ],
    firstAssignmentCourseId: null,
    firstAssignmentId: null,
    firstProjectCourseId: null,
    firstProjectId: null,
  );
}

class TeacherAssignmentBreakdown {
  const TeacherAssignmentBreakdown({
    required this.assignmentId,
    required this.courseId,
    required this.title,
    required this.courseTitle,
    required this.type,
    required this.status,
    required this.totalAttempts,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.passRate,
    required this.pendingCount,
    required this.gradedCount,
  });

  final String assignmentId;
  final String courseId;
  final String title;
  final String courseTitle;
  final String type;
  final String status;
  final int totalAttempts;
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final double passRate;
  final int pendingCount;
  final int gradedCount;
}

class TeacherStudentPerformanceSignal {
  const TeacherStudentPerformanceSignal({
    required this.studentId,
    required this.label,
    required this.averageScore,
    required this.evidenceCount,
  });

  final String studentId;
  final String label;
  final double averageScore;
  final int evidenceCount;
}

class TeacherCoursePendingReview {
  const TeacherCoursePendingReview({
    required this.courseId,
    required this.courseTitle,
    required this.count,
  });

  final String courseId;
  final String courseTitle;
  final int count;
}

class TeacherReviewPriority {
  const TeacherReviewPriority({
    required this.courseId,
    required this.assignmentId,
    required this.studentId,
    required this.courseTitle,
    required this.submittedAt,
  });

  final String courseId;
  final String assignmentId;
  final String studentId;
  final String courseTitle;
  final DateTime submittedAt;
}

class _StudentSignalResult {
  const _StudentSignalResult({
    required this.topPerformers,
    required this.strugglingStudents,
  });

  final List<TeacherStudentPerformanceSignal> topPerformers;
  final List<TeacherStudentPerformanceSignal> strugglingStudents;
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

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _date(Object? value, {DateTime? fallback}) {
  return _nullableDate(value) ?? fallback ?? DateTime.now();
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double _average(List<num> values) {
  if (values.isEmpty) return 0;
  return values.fold<double>(0, (total, value) => total + value.toDouble()) /
      values.length;
}

double _averageDurationHours(List<Duration> durations) {
  if (durations.isEmpty) return 0;
  final totalMinutes = durations.fold<int>(
    0,
    (total, duration) => total + duration.inMinutes,
  );
  return totalMinutes / durations.length / 60;
}

String _shortId(String id) {
  if (id.length <= 6) return id;
  return id.substring(0, 6).toUpperCase();
}
