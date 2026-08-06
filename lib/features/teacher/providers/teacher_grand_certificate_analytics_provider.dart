import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';

final teacherGrandCertificateAnalyticsProvider =
    FutureProvider<TeacherGrandCertificateAnalytics>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return TeacherGrandCertificateAnalytics.empty;

      return TeacherGrandCertificateAnalyticsService(
        ref.watch(firestoreProvider),
      ).load(user.uid);
    });

class TeacherGrandCertificateAnalyticsService {
  const TeacherGrandCertificateAnalyticsService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<TeacherGrandCertificateAnalytics> load(String teacherId) async {
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
            .collectionGroup('grandTests')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('attempts')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collection('certificates')
            .where('teacherId', isEqualTo: teacherId),
      ),
    ]);

    final courses = _docs(results[0]);
    final enrollments = _docs(results[1]);
    final grandTests = _docs(results[2]);
    final attempts = _docs(results[3]);
    final certificates = _docs(results[4]);

    final courseTitles = <String, String>{
      for (final course in courses)
        course.id: _label(course.data()['title'], 'Untitled course'),
    };
    final enrollmentsByCourse = <String, Set<String>>{};
    for (final enrollment in enrollments) {
      final data = enrollment.data();
      if (_status(data['status'], 'active') == 'dropped') continue;
      final courseId = _string(data['courseId']);
      final studentId = _string(data['studentId']);
      if (courseId.isEmpty || studentId.isEmpty) continue;
      enrollmentsByCourse
          .putIfAbsent(courseId, () => <String>{})
          .add(studentId);
    }

    final submittedGrandAttempts = attempts.where((doc) {
      final data = doc.data();
      final status = _status(data['status']);
      return _string(data['grandTestId']).isNotEmpty &&
          (status == 'submitted' || status == 'auto_submitted');
    }).toList();

    final attemptsByGrandTest =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final attempt in submittedGrandAttempts) {
      final grandTestId = _string(attempt.data()['grandTestId']);
      if (grandTestId.isEmpty) continue;
      attemptsByGrandTest.putIfAbsent(grandTestId, () => []).add(attempt);
    }

    final grandTestBreakdowns = <GrandTestAnalyticsBreakdown>[];
    var noAttemptStudents = 0;
    for (final test in grandTests) {
      final data = test.data();
      final courseId = _string(data['courseId']);
      final testAttempts = attemptsByGrandTest[test.id] ?? const [];
      final attemptedStudentIds = testAttempts
          .map((attempt) => _string(attempt.data()['studentId']))
          .where((id) => id.isNotEmpty)
          .toSet();
      final enrolledStudentIds =
          enrollmentsByCourse[courseId] ?? const <String>{};
      final missingAttempts = _status(data['status']) == 'published'
          ? enrolledStudentIds.difference(attemptedStudentIds).length
          : 0;
      noAttemptStudents += missingAttempts;

      grandTestBreakdowns.add(
        _grandTestBreakdown(
          grandTestId: test.id,
          courseId: courseId,
          title: _label(data['title'], 'Untitled grand test'),
          courseTitle: courseTitles[courseId] ?? 'Course',
          status: _status(data['status'], 'draft'),
          attempts: testAttempts,
          noAttemptCount: missingAttempts,
        ),
      );
    }
    grandTestBreakdowns.sort((a, b) {
      final attemptCompare = b.totalAttempts.compareTo(a.totalAttempts);
      if (attemptCompare != 0) return attemptCompare;
      return b.averageScore.compareTo(a.averageScore);
    });

    final grandScores = submittedGrandAttempts
        .map(
          (doc) => _double(doc.data()['percentage']).clamp(0, 100).toDouble(),
        )
        .toList();
    final passedAttempts = submittedGrandAttempts
        .where((doc) => doc.data()['passed'] == true)
        .length;
    final failedAttempts = submittedGrandAttempts.length - passedAttempts;
    final closeToPassing = submittedGrandAttempts.where((doc) {
      final data = doc.data();
      if (data['passed'] == true) return false;
      final score = _double(data['percentage']);
      final passingMarks = _double(data['passingMarks']);
      final totalMarks = _double(data['totalMarks']);
      final requiredPercent = totalMarks <= 0
          ? 60
          : (passingMarks / totalMarks) * 100;
      return score >= (requiredPercent - 10) && score < requiredPercent;
    }).length;
    final warningAttempts = submittedGrandAttempts
        .where((doc) => _int(doc.data()['warningsCount']) > 0)
        .length;

    final studentScores = _studentGrandSignals(submittedGrandAttempts);

    final activeCertificates = certificates.where((doc) {
      return _status(doc.data()['status'], 'active') == 'active';
    }).toList();
    final revokedCertificates = certificates.length - activeCertificates.length;
    final certificatesByCourse =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final certificate in certificates) {
      final courseId = _string(certificate.data()['courseId']);
      if (courseId.isEmpty) continue;
      certificatesByCourse.putIfAbsent(courseId, () => []).add(certificate);
    }

    final completedEnrollmentPairs = <String>{};
    for (final enrollment in enrollments) {
      final data = enrollment.data();
      final courseId = _string(data['courseId']);
      final studentId = _string(data['studentId']);
      if (courseId.isEmpty || studentId.isEmpty) continue;
      final completed =
          _status(data['status']) == 'completed' ||
          _double(data['progressPercent']) >= 100;
      if (completed) completedEnrollmentPairs.add('${courseId}_$studentId');
    }

    final issuedCompletionPairs = certificates
        .where((doc) {
          return _status(doc.data()['certificateType']) == 'course_completion';
        })
        .map((doc) {
          final data = doc.data();
          return '${_string(data['courseId'])}_${_string(data['studentId'])}';
        })
        .toSet();

    final pendingCertificateIssuance = completedEnrollmentPairs
        .difference(issuedCompletionPairs)
        .length;

    final certificateBreakdowns = <CertificateCourseBreakdown>[];
    for (final course in courses) {
      final courseCertificates = certificatesByCourse[course.id] ?? const [];
      final courseActive = courseCertificates.where((doc) {
        return _status(doc.data()['status'], 'active') == 'active';
      }).toList();
      final courseRevoked = courseCertificates.length - courseActive.length;
      final courseCompletedPairs = completedEnrollmentPairs
          .where((pair) => pair.startsWith('${course.id}_'))
          .length;
      final courseIssuedCompletion = issuedCompletionPairs
          .where((pair) => pair.startsWith('${course.id}_'))
          .length;
      final scores = courseActive
          .map(
            (doc) => _double(doc.data()['finalScore']).clamp(0, 100).toDouble(),
          )
          .toList();

      certificateBreakdowns.add(
        CertificateCourseBreakdown(
          courseId: course.id,
          courseTitle: _label(course.data()['title'], 'Untitled course'),
          eligibleStudents: courseCompletedPairs,
          issuedCertificates: courseActive.length,
          pendingIssuance: (courseCompletedPairs - courseIssuedCompletion)
              .clamp(0, courseCompletedPairs),
          revokedCertificates: courseRevoked,
          averageFinalScore: _average(scores),
        ),
      );
    }
    certificateBreakdowns.sort((a, b) {
      final pendingCompare = b.pendingIssuance.compareTo(a.pendingIssuance);
      if (pendingCompare != 0) return pendingCompare;
      return b.issuedCertificates.compareTo(a.issuedCertificates);
    });

    final recentCertificates = activeCertificates.toList()
      ..sort(
        (a, b) =>
            _date(b.data()['issuedAt']).compareTo(_date(a.data()['issuedAt'])),
      );

    final studentCertificateCounts = <String, int>{};
    for (final certificate in activeCertificates) {
      final studentId = _string(certificate.data()['studentId']);
      if (studentId.isEmpty) continue;
      studentCertificateCounts[studentId] =
          (studentCertificateCounts[studentId] ?? 0) + 1;
    }
    final topCertifiedStudents =
        studentCertificateCounts.entries
            .map(
              (entry) => CertificateStudentSignal(
                studentId: entry.key,
                label: 'Student ${_shortId(entry.key)}',
                certificateCount: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.certificateCount.compareTo(a.certificateCount));

    final recommendations = _recommendations(
      passRate: submittedGrandAttempts.isEmpty
          ? 0
          : (passedAttempts / submittedGrandAttempts.length) * 100,
      averageScore: _average(grandScores),
      noAttemptStudents: noAttemptStudents,
      closeToPassing: closeToPassing,
      failedAttempts: failedAttempts,
      pendingCertificateIssuance: pendingCertificateIssuance,
      revokedCertificates: revokedCertificates,
      warningAttempts: warningAttempts,
      certificateBreakdowns: certificateBreakdowns,
    );

    return TeacherGrandCertificateAnalytics(
      totalGrandTests: grandTests.length,
      activeGrandTests: grandTests
          .where((doc) => _status(doc.data()['status']) == 'published')
          .length,
      totalGrandAttempts: submittedGrandAttempts.length,
      passedGrandAttempts: passedAttempts,
      failedGrandAttempts: failedAttempts,
      averageGrandScore: _average(grandScores),
      grandPassRate: submittedGrandAttempts.isEmpty
          ? 0
          : (passedAttempts / submittedGrandAttempts.length) * 100,
      noAttemptStudents: noAttemptStudents,
      closeToPassingStudents: closeToPassing,
      warningAttempts: warningAttempts,
      grandTestBreakdowns: grandTestBreakdowns,
      topScorers: studentScores.topScorers,
      failedStudents: studentScores.failedStudents,
      eligibilityBreakdownAvailable: false,
      totalCertificatesIssued: certificates.length,
      activeCertificates: activeCertificates.length,
      revokedCertificates: revokedCertificates,
      pendingCertificateIssuance: pendingCertificateIssuance,
      averageCertificateScore: _average(
        activeCertificates
            .map(
              (doc) =>
                  _double(doc.data()['finalScore']).clamp(0, 100).toDouble(),
            )
            .toList(),
      ),
      recentCertificates: recentCertificates.take(5).map((doc) {
        final data = doc.data();
        return RecentCertificateSignal(
          certificateId: doc.id,
          studentId: _string(data['studentId']),
          studentName: _label(
            data['studentName'],
            'Student ${_shortId(_string(data['studentId']))}',
          ),
          courseTitle: _label(
            data['courseTitle'],
            courseTitles[_string(data['courseId'])] ?? 'Course',
          ),
          typeLabel: _certificateTypeLabel(_string(data['certificateType'])),
          issuedAt: _date(data['issuedAt']),
          finalScore: _double(data['finalScore']).clamp(0, 100).toDouble(),
        );
      }).toList(),
      certificateBreakdowns: certificateBreakdowns,
      topCertifiedStudents: topCertifiedStudents.take(5).toList(),
      recommendations: recommendations,
      firstGrandTestCourseId: grandTestBreakdowns.isEmpty
          ? null
          : grandTestBreakdowns.first.courseId,
      firstGrandTestId: grandTestBreakdowns.isEmpty
          ? null
          : grandTestBreakdowns.first.grandTestId,
      firstCertificateCourseId: certificateBreakdowns.isEmpty
          ? null
          : certificateBreakdowns.first.courseId,
    );
  }

  GrandTestAnalyticsBreakdown _grandTestBreakdown({
    required String grandTestId,
    required String courseId,
    required String title,
    required String courseTitle,
    required String status,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    required int noAttemptCount,
  }) {
    final scores = attempts
        .map(
          (doc) => _double(doc.data()['percentage']).clamp(0, 100).toDouble(),
        )
        .toList();
    final passed = attempts.where((doc) => doc.data()['passed'] == true).length;
    final latestAttemptDate = attempts
        .map(
          (doc) =>
              _nullableDate(doc.data()['submittedAt']) ??
              _date(doc.data()['startedAt']),
        )
        .fold<DateTime?>(null, (latest, date) {
          if (latest == null) return date;
          return date.isAfter(latest) ? date : latest;
        });

    return GrandTestAnalyticsBreakdown(
      grandTestId: grandTestId,
      courseId: courseId,
      title: title,
      courseTitle: courseTitle,
      status: status,
      totalAttempts: attempts.length,
      passedCount: passed,
      failedCount: attempts.length - passed,
      averageScore: _average(scores),
      highestScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b),
      lowestScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b),
      passRate: attempts.isEmpty ? 0 : (passed / attempts.length) * 100,
      noAttemptCount: noAttemptCount,
      latestAttemptDate: latestAttemptDate,
    );
  }

  _GrandStudentSignalResult _studentGrandSignals(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  ) {
    final bestScores = <String, GrandStudentSignal>{};
    final failed = <GrandStudentSignal>[];
    for (final attempt in attempts) {
      final data = attempt.data();
      final studentId = _string(data['studentId']);
      if (studentId.isEmpty) continue;
      final signal = GrandStudentSignal(
        studentId: studentId,
        label: 'Student ${_shortId(studentId)}',
        score: _double(data['percentage']).clamp(0, 100).toDouble(),
        passed: data['passed'] == true,
      );
      final current = bestScores[studentId];
      if (current == null || signal.score > current.score) {
        bestScores[studentId] = signal;
      }
      if (!signal.passed) failed.add(signal);
    }
    final top = bestScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    failed.sort((a, b) => a.score.compareTo(b.score));
    return _GrandStudentSignalResult(
      topScorers: top.take(5).toList(),
      failedStudents: failed.take(5).toList(),
    );
  }

  List<String> _recommendations({
    required double passRate,
    required double averageScore,
    required int noAttemptStudents,
    required int closeToPassing,
    required int failedAttempts,
    required int pendingCertificateIssuance,
    required int revokedCertificates,
    required int warningAttempts,
    required List<CertificateCourseBreakdown> certificateBreakdowns,
  }) {
    final items = <String>[];
    if (failedAttempts > 0 && passRate < 60) {
      items.add(
        'Grand Test pass rate is below 60%. Review prerequisite lessons before the next attempt window.',
      );
    }
    if (averageScore > 0 && averageScore < 60) {
      items.add(
        'Average Grand Test score is ${averageScore.toStringAsFixed(0)}%. The test may need targeted revision support.',
      );
    }
    if (noAttemptStudents > 0) {
      items.add(
        '$noAttemptStudents enrolled students have not attempted a published Grand Test yet.',
      );
    }
    if (closeToPassing > 0) {
      items.add(
        '$closeToPassing students failed by less than 10%. Recommend focused revision and practice.',
      );
    }
    if (warningAttempts > 0) {
      items.add(
        '$warningAttempts Grand Test attempts include warning flags. Review these before certification decisions.',
      );
    }
    if (pendingCertificateIssuance > 0) {
      items.add(
        '$pendingCertificateIssuance students appear ready for course completion certificates based on enrollment completion.',
      );
    }
    if (revokedCertificates > 0) {
      items.add(
        'Review $revokedCertificates revoked certificates for audit and learner communication.',
      );
    }
    if (certificateBreakdowns.isNotEmpty) {
      final topCourse = certificateBreakdowns.reduce(
        (a, b) => a.issuedCertificates >= b.issuedCertificates ? a : b,
      );
      if (topCourse.issuedCertificates > 0) {
        items.add(
          '${topCourse.courseTitle} has the strongest certification activity.',
        );
      }
    }
    if (items.isEmpty) {
      items.add(
        'Not enough Grand Test or certificate data yet. Publish tests and issue certificates to unlock insights.',
      );
    }
    return items.take(6).toList();
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

class TeacherGrandCertificateAnalytics {
  const TeacherGrandCertificateAnalytics({
    required this.totalGrandTests,
    required this.activeGrandTests,
    required this.totalGrandAttempts,
    required this.passedGrandAttempts,
    required this.failedGrandAttempts,
    required this.averageGrandScore,
    required this.grandPassRate,
    required this.noAttemptStudents,
    required this.closeToPassingStudents,
    required this.warningAttempts,
    required this.grandTestBreakdowns,
    required this.topScorers,
    required this.failedStudents,
    required this.eligibilityBreakdownAvailable,
    required this.totalCertificatesIssued,
    required this.activeCertificates,
    required this.revokedCertificates,
    required this.pendingCertificateIssuance,
    required this.averageCertificateScore,
    required this.recentCertificates,
    required this.certificateBreakdowns,
    required this.topCertifiedStudents,
    required this.recommendations,
    required this.firstGrandTestCourseId,
    required this.firstGrandTestId,
    required this.firstCertificateCourseId,
  });

  final int totalGrandTests;
  final int activeGrandTests;
  final int totalGrandAttempts;
  final int passedGrandAttempts;
  final int failedGrandAttempts;
  final double averageGrandScore;
  final double grandPassRate;
  final int noAttemptStudents;
  final int closeToPassingStudents;
  final int warningAttempts;
  final List<GrandTestAnalyticsBreakdown> grandTestBreakdowns;
  final List<GrandStudentSignal> topScorers;
  final List<GrandStudentSignal> failedStudents;
  final bool eligibilityBreakdownAvailable;
  final int totalCertificatesIssued;
  final int activeCertificates;
  final int revokedCertificates;
  final int pendingCertificateIssuance;
  final double averageCertificateScore;
  final List<RecentCertificateSignal> recentCertificates;
  final List<CertificateCourseBreakdown> certificateBreakdowns;
  final List<CertificateStudentSignal> topCertifiedStudents;
  final List<String> recommendations;
  final String? firstGrandTestCourseId;
  final String? firstGrandTestId;
  final String? firstCertificateCourseId;

  bool get hasAnyData =>
      totalGrandTests > 0 ||
      totalGrandAttempts > 0 ||
      totalCertificatesIssued > 0 ||
      pendingCertificateIssuance > 0;

  static const empty = TeacherGrandCertificateAnalytics(
    totalGrandTests: 0,
    activeGrandTests: 0,
    totalGrandAttempts: 0,
    passedGrandAttempts: 0,
    failedGrandAttempts: 0,
    averageGrandScore: 0,
    grandPassRate: 0,
    noAttemptStudents: 0,
    closeToPassingStudents: 0,
    warningAttempts: 0,
    grandTestBreakdowns: <GrandTestAnalyticsBreakdown>[],
    topScorers: <GrandStudentSignal>[],
    failedStudents: <GrandStudentSignal>[],
    eligibilityBreakdownAvailable: false,
    totalCertificatesIssued: 0,
    activeCertificates: 0,
    revokedCertificates: 0,
    pendingCertificateIssuance: 0,
    averageCertificateScore: 0,
    recentCertificates: <RecentCertificateSignal>[],
    certificateBreakdowns: <CertificateCourseBreakdown>[],
    topCertifiedStudents: <CertificateStudentSignal>[],
    recommendations: <String>[
      'Not enough Grand Test or certificate data yet. Publish tests and issue certificates to unlock insights.',
    ],
    firstGrandTestCourseId: null,
    firstGrandTestId: null,
    firstCertificateCourseId: null,
  );
}

class GrandTestAnalyticsBreakdown {
  const GrandTestAnalyticsBreakdown({
    required this.grandTestId,
    required this.courseId,
    required this.title,
    required this.courseTitle,
    required this.status,
    required this.totalAttempts,
    required this.passedCount,
    required this.failedCount,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.passRate,
    required this.noAttemptCount,
    required this.latestAttemptDate,
  });

  final String grandTestId;
  final String courseId;
  final String title;
  final String courseTitle;
  final String status;
  final int totalAttempts;
  final int passedCount;
  final int failedCount;
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final double passRate;
  final int noAttemptCount;
  final DateTime? latestAttemptDate;
}

class GrandStudentSignal {
  const GrandStudentSignal({
    required this.studentId,
    required this.label,
    required this.score,
    required this.passed,
  });

  final String studentId;
  final String label;
  final double score;
  final bool passed;
}

class RecentCertificateSignal {
  const RecentCertificateSignal({
    required this.certificateId,
    required this.studentId,
    required this.studentName,
    required this.courseTitle,
    required this.typeLabel,
    required this.issuedAt,
    required this.finalScore,
  });

  final String certificateId;
  final String studentId;
  final String studentName;
  final String courseTitle;
  final String typeLabel;
  final DateTime issuedAt;
  final double finalScore;
}

class CertificateCourseBreakdown {
  const CertificateCourseBreakdown({
    required this.courseId,
    required this.courseTitle,
    required this.eligibleStudents,
    required this.issuedCertificates,
    required this.pendingIssuance,
    required this.revokedCertificates,
    required this.averageFinalScore,
  });

  final String courseId;
  final String courseTitle;
  final int eligibleStudents;
  final int issuedCertificates;
  final int pendingIssuance;
  final int revokedCertificates;
  final double averageFinalScore;
}

class CertificateStudentSignal {
  const CertificateStudentSignal({
    required this.studentId,
    required this.label,
    required this.certificateCount,
  });

  final String studentId;
  final String label;
  final int certificateCount;
}

class _GrandStudentSignalResult {
  const _GrandStudentSignalResult({
    required this.topScorers,
    required this.failedStudents,
  });

  final List<GrandStudentSignal> topScorers;
  final List<GrandStudentSignal> failedStudents;
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

int _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _average(List<num> values) {
  if (values.isEmpty) return 0;
  return values.fold<double>(0, (total, value) => total + value.toDouble()) /
      values.length;
}

String _shortId(String id) {
  if (id.isEmpty) return 'UNKNOWN';
  if (id.length <= 6) return id.toUpperCase();
  return id.substring(0, 6).toUpperCase();
}

String _certificateTypeLabel(String type) {
  return switch (type.trim().toLowerCase()) {
    'excellence' => 'Excellence',
    'project_excellence' => 'Project Excellence',
    _ => 'Course Completion',
  };
}
