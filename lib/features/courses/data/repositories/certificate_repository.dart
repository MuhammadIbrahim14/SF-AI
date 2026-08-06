import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../models/certificate_model.dart';
import '../models/course_model.dart';
import '../models/grand_test_attempt_model.dart';
import '../models/grand_test_model.dart';
import '../models/mcq_assignment_model.dart';
import '../models/mcq_attempt_model.dart';
import '../models/project_submission_model.dart';

abstract class CertificateRepository {
  Stream<List<CertificateModel>> watchStudentCertificates(String studentId);
  Stream<List<CertificateModel>> watchCourseCertificates(String courseId);
  Stream<CertificateModel?> watchCertificate(String certificateId);
  Future<CertificateEligibilityResult> checkEligibility({
    required String courseId,
    required String studentId,
  });
  Future<CertificateModel> issueCertificate({
    required String courseId,
    required String studentId,
    required String certificateType,
    required String issuedBy,
  });
  Future<void> revokeCertificate({
    required String certificateId,
    required String reason,
  });
}

class FirestoreCertificateRepository implements CertificateRepository {
  const FirestoreCertificateRepository(this._firestore);

  static const double excellenceGrandTestThreshold = 85;
  static const double excellenceAssignmentThreshold = 80;
  static const double defaultLessonProgressRequirement = 80;
  static const double defaultAssignmentCompletionRequirement = 70;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection('certificates');

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection('courses');

  CollectionReference<Map<String, dynamic>> get _enrollments =>
      _firestore.collection('enrollments');

  String _enrollmentId(String studentId, String courseId) =>
      '${studentId}_$courseId';

  String _certificateId({
    required String courseId,
    required String studentId,
    required String certificateType,
  }) {
    return '${courseId}_${studentId}_${CertificateType.normalize(certificateType)}';
  }

  @override
  Stream<List<CertificateModel>> watchStudentCertificates(String studentId) {
    return _certificates
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final certificates = snapshot.docs
              .map((doc) => CertificateModel.fromFirestore(doc))
              .toList();
          certificates.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
          return certificates;
        });
  }

  @override
  Stream<List<CertificateModel>> watchCourseCertificates(String courseId) {
    return _certificates.where('courseId', isEqualTo: courseId).snapshots().map(
      (snapshot) {
        final certificates = snapshot.docs
            .map((doc) => CertificateModel.fromFirestore(doc))
            .toList();
        certificates.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
        return certificates;
      },
    );
  }

  @override
  Stream<CertificateModel?> watchCertificate(String certificateId) {
    return _certificates.doc(certificateId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CertificateModel.fromFirestore(snapshot);
    });
  }

  @override
  Future<CertificateEligibilityResult> checkEligibility({
    required String courseId,
    required String studentId,
  }) async {
    try {
      final enrollmentSnapshot = await _enrollments
          .doc(_enrollmentId(studentId, courseId))
          .get();
      final enrollmentData = enrollmentSnapshot.data();
      final isEnrolled = enrollmentSnapshot.exists && enrollmentData != null;
      final lessonProgress = await _lessonProgressPercent(
        courseId: courseId,
        enrollmentSnapshot: enrollmentSnapshot,
        enrollmentData: enrollmentData,
      );

      final assignmentStats = await _assignmentStats(
        courseId: courseId,
        studentId: studentId,
      );
      final grandTestStats = await _grandTestStats(
        courseId: courseId,
        studentId: studentId,
      );

      final requiredLessonProgress =
          grandTestStats.requiredLessonProgressPercent ??
          defaultLessonProgressRequirement;
      final requiredAssignmentCompletion =
          grandTestStats.requiredAssignmentCompletionPercent ??
          defaultAssignmentCompletionRequirement;

      final missing = <String>[];
      if (!isEnrolled) {
        missing.add('Student must be enrolled in this course.');
      }
      if (lessonProgress < requiredLessonProgress) {
        missing.add(
          'Complete at least ${requiredLessonProgress.toStringAsFixed(0)}% lessons.',
        );
      }
      if (assignmentStats.completionPercent < requiredAssignmentCompletion) {
        missing.add(
          'Complete at least ${requiredAssignmentCompletion.toStringAsFixed(0)}% assignments.',
        );
      }
      if (!grandTestStats.passed) {
        missing.add('Pass the published Grand Test.');
      }

      final eligibleTypes = <String>[];
      final completionEligible = isEnrolled && missing.isEmpty;
      if (completionEligible) {
        eligibleTypes.add(CertificateType.courseCompletion);
      }
      if (grandTestStats.passed &&
          grandTestStats.bestScore >= excellenceGrandTestThreshold &&
          assignmentStats.averagePercent >= excellenceAssignmentThreshold) {
        eligibleTypes.add(CertificateType.excellence);
      }
      if (assignmentStats.projectSubmitted) {
        eligibleTypes.add(CertificateType.projectExcellence);
      }
      final issuedTypes = await _issuedCertificateTypes(
        courseId: courseId,
        studentId: studentId,
      );
      final availableTypes = eligibleTypes
          .where((type) => !issuedTypes.contains(type))
          .toList();

      return CertificateEligibilityResult(
        studentId: studentId,
        isEligible: availableTypes.isNotEmpty,
        eligibleCertificateTypes: availableTypes,
        issuedCertificateTypes: issuedTypes.toList(),
        missingRequirements: missing,
        performanceSummary: {
          'isEnrolled': isEnrolled,
          'lessonProgress': lessonProgress,
          'requiredLessonProgress': requiredLessonProgress,
          'assignmentCompletion': assignmentStats.completionPercent,
          'requiredAssignmentCompletion': requiredAssignmentCompletion,
          'assignmentAverage': assignmentStats.averagePercent,
          'grandTestPassed': grandTestStats.passed,
          'grandTestScore': grandTestStats.bestScore,
          'projectSubmitted': assignmentStats.projectSubmitted,
          'publishedAssignments': assignmentStats.totalAssignments,
          'completedAssignments': assignmentStats.completedAssignments,
          'publishedGrandTestId': grandTestStats.grandTestId,
          'availableCertificateTypes': availableTypes,
          'issuedCertificateTypes': issuedTypes.toList(),
        },
        lessonProgress: lessonProgress,
        assignmentCompletion: assignmentStats.completionPercent,
        assignmentAverage: assignmentStats.averagePercent,
        projectSubmitted: assignmentStats.projectSubmitted,
        grandTestPassed: grandTestStats.passed,
        grandTestScore: grandTestStats.bestScore,
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        'Failed to check certificate eligibility: ${e.toString()}',
      );
    }
  }

  @override
  Future<CertificateModel> issueCertificate({
    required String courseId,
    required String studentId,
    required String certificateType,
    required String issuedBy,
  }) async {
    final normalizedType = CertificateType.normalize(certificateType);
    try {
      final certificateId = _certificateId(
        courseId: courseId,
        studentId: studentId,
        certificateType: normalizedType,
      );
      final certificateRef = _certificates.doc(certificateId);
      final existing = await certificateRef.get();
      if (existing.exists) {
        throw FirestoreException(
          '${CertificateType.label(normalizedType)} certificate has already been issued for this student.',
        );
      }

      final eligibility = await checkEligibility(
        courseId: courseId,
        studentId: studentId,
      );

      if (!eligibility.eligibleCertificateTypes.contains(normalizedType)) {
        final reason = normalizedType == CertificateType.projectExcellence
            ? 'Project Excellence requires a submitted or graded project.'
            : 'Student does not meet certificate eligibility requirements.';
        throw FirestoreException(reason);
      }

      final course = await _getCourse(courseId);
      if (course == null) throw const FirestoreException('Course not found.');

      final now = DateTime.now();
      final verificationCode = _verificationCode(
        courseId: courseId,
        studentId: studentId,
        certificateType: normalizedType,
        issuedAt: now,
      );

      final studentName = await _userName(studentId, fallback: 'Student');
      final teacherName = course.teacherName.trim().isNotEmpty
          ? course.teacherName.trim()
          : await _userName(course.teacherId, fallback: 'Teacher');

      final certificate = CertificateModel(
        certificateId: certificateId,
        studentId: studentId,
        teacherId: course.teacherId,
        courseId: courseId,
        courseTitle: course.title,
        studentName: studentName,
        teacherName: teacherName,
        certificateType: normalizedType,
        title: _titleFor(normalizedType, course.title),
        description: _descriptionFor(normalizedType, course.title),
        finalScore: _finalScoreFor(normalizedType, eligibility),
        grandTestScore: eligibility.grandTestScore,
        assignmentAverage: eligibility.assignmentAverage,
        issuedAt: now,
        issuedBy: issuedBy,
        verificationCode: verificationCode,
        status: CertificateStatus.active,
      );

      await _firestore.runTransaction((transaction) async {
        final latest = await transaction.get(certificateRef);
        if (latest.exists) {
          throw FirestoreException(
            '${CertificateType.label(normalizedType)} certificate has already been issued for this student.',
          );
        }
        transaction.set(certificateRef, certificate.toJson());
      });
      return certificate;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to issue certificate: ${e.toString()}');
    }
  }

  @override
  Future<void> revokeCertificate({
    required String certificateId,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const FirestoreException('Revocation reason is required.');
    }

    try {
      await _certificates.doc(certificateId).update({
        'status': CertificateStatus.revoked,
        'revokedAt': Timestamp.fromDate(DateTime.now()),
        'revokeReason': trimmedReason,
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to revoke certificate: ${e.toString()}');
    }
  }

  Future<CourseModel?> _getCourse(String courseId) async {
    final snapshot = await _courses.doc(courseId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return CourseModel.fromFirestore(snapshot);
  }

  Future<Set<String>> _issuedCertificateTypes({
    required String courseId,
    required String studentId,
  }) async {
    final snapshots = await Future.wait(
      CertificateType.values.map((type) {
        return _certificates
            .doc(
              _certificateId(
                courseId: courseId,
                studentId: studentId,
                certificateType: type,
              ),
            )
            .get();
      }),
    );

    return snapshots.where((snapshot) => snapshot.exists).map((snapshot) {
      final data = snapshot.data();
      return CertificateType.normalize(data?['certificateType']?.toString());
    }).toSet();
  }

  Future<double> _lessonProgressPercent({
    required String courseId,
    required DocumentSnapshot<Map<String, dynamic>> enrollmentSnapshot,
    required Map<String, dynamic>? enrollmentData,
  }) async {
    // Lessons-only progress. `progressPercent` now tracks overall course
    // completion (lessons + quizzes + projects + grand test), so reading it
    // here would double-count the other requirements.
    final storedProgress = _doubleValue(
      enrollmentData?['lessonProgressPercent'],
    ).clamp(0, 100).toDouble();
    if (storedProgress > 0) return storedProgress;

    final storedCompleted = _intValue(enrollmentData?['completedLessons']);
    final storedTotal = _intValue(enrollmentData?['totalLessons']);
    if (storedCompleted > 0 && storedTotal > 0) {
      return ((storedCompleted / storedTotal) * 100).clamp(0, 100).toDouble();
    }

    if (!enrollmentSnapshot.exists) return 0;
    final progressSnapshot = await enrollmentSnapshot.reference
        .collection('lessonProgress')
        .where('completed', isEqualTo: true)
        .get();
    final completedLessons = progressSnapshot.docs.length;
    if (completedLessons == 0) return 0;

    final lessonsSnapshot = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('lessons')
        .get();
    final totalLessons = lessonsSnapshot.docs
        .where((doc) => doc.data()['isArchived'] != true)
        .length;
    if (totalLessons == 0) return 100;

    return ((completedLessons / totalLessons) * 100).clamp(0, 100).toDouble();
  }

  Future<_AssignmentStats> _assignmentStats({
    required String courseId,
    required String studentId,
  }) async {
    final assignments = await _courses
        .doc(courseId)
        .collection('assignments')
        .where('status', isEqualTo: AssignmentStatus.published)
        .where('type', whereIn: ['mcq', 'project'])
        .get();

    var completedAssignments = 0;
    var projectSubmitted = false;
    final scores = <double>[];

    for (final assignment in assignments.docs) {
      final data = assignment.data();
      final type = _normalizeValue(data['type']);
      if (type == 'mcq') {
        final attempt = await assignment.reference
            .collection('attempts')
            .doc(studentId)
            .get();
        final attemptData = attempt.data();
        final attemptStatus = _normalizeValue(attemptData?['status']);
        if (attempt.exists && attemptStatus == McqAttemptStatus.submitted) {
          completedAssignments++;
          scores.add(_doubleValue(attemptData?['percentage']).clamp(0, 100));
        }
        continue;
      }

      if (type == 'project') {
        final submission = await assignment.reference
            .collection('submissions')
            .doc(studentId)
            .get();
        final submissionData = submission.data();
        final status = ProjectSubmissionStatus.normalize(
          submissionData?['status']?.toString(),
        );
        final submitted =
            submission.exists &&
            {
              ProjectSubmissionStatus.submitted,
              ProjectSubmissionStatus.graded,
            }.contains(status);
        if (submitted) {
          completedAssignments++;
          projectSubmitted = true;
          if (status == ProjectSubmissionStatus.graded) {
            scores.add(
              _doubleValue(submissionData?['percentage']).clamp(0, 100),
            );
          }
        }
      }
    }

    final totalAssignments = assignments.docs.length;
    final completionPercent = totalAssignments == 0
        ? 100.0
        : (completedAssignments / totalAssignments) * 100;
    final averagePercent = scores.isEmpty
        ? (totalAssignments == 0 ? 100.0 : 0.0)
        : scores.reduce((a, b) => a + b) / scores.length;

    return _AssignmentStats(
      totalAssignments: totalAssignments,
      completedAssignments: completedAssignments,
      completionPercent: completionPercent.clamp(0, 100).toDouble(),
      averagePercent: averagePercent.clamp(0, 100).toDouble(),
      projectSubmitted: projectSubmitted,
    );
  }

  Future<_GrandTestStats> _grandTestStats({
    required String courseId,
    required String studentId,
  }) async {
    final testsSnapshot = await _courses
        .doc(courseId)
        .collection('grandTests')
        .where('status', isEqualTo: AssignmentStatus.published)
        .get();

    final tests =
        testsSnapshot.docs
            .map((doc) => GrandTestModel.fromFirestore(doc))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (tests.isEmpty) return const _GrandTestStats();

    final test = tests.first;
    final attemptsSnapshot = await _courses
        .doc(courseId)
        .collection('grandTests')
        .doc(test.grandTestId)
        .collection('attempts')
        .where('studentId', isEqualTo: studentId)
        .get();

    final attempts = attemptsSnapshot.docs
        .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
        .where((attempt) => attempt.isSubmitted)
        .toList();

    if (attempts.isEmpty) {
      return _GrandTestStats(
        grandTestId: test.grandTestId,
        requiredLessonProgressPercent: test.requiredLessonProgressPercent,
        requiredAssignmentCompletionPercent:
            test.requiredAssignmentCompletionPercent,
      );
    }

    final best = attempts.reduce(
      (a, b) => a.percentage >= b.percentage ? a : b,
    );
    return _GrandTestStats(
      grandTestId: test.grandTestId,
      passed: attempts.any((attempt) => attempt.passed),
      bestScore: best.percentage.clamp(0, 100).toDouble(),
      requiredLessonProgressPercent: test.requiredLessonProgressPercent,
      requiredAssignmentCompletionPercent:
          test.requiredAssignmentCompletionPercent,
    );
  }

  Future<String> _userName(String uid, {required String fallback}) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    for (final key in ['fullName', 'name', 'displayName', 'email']) {
      final value = data?[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  String _verificationCode({
    required String courseId,
    required String studentId,
    required String certificateType,
    required DateTime issuedAt,
  }) {
    final coursePart = _codePart(courseId);
    final studentPart = _codePart(studentId);
    final typePart = certificateType
        .split('_')
        .map((part) => part.isEmpty ? '' : part[0])
        .join()
        .toUpperCase();
    return 'SF-$typePart-$coursePart-$studentPart-${issuedAt.millisecondsSinceEpoch}';
  }

  String _codePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.length <= 4) return cleaned.padRight(4, 'X');
    return cleaned.substring(0, 4);
  }

  String _titleFor(String type, String courseTitle) {
    return switch (CertificateType.normalize(type)) {
      CertificateType.excellence => 'Excellence Certificate',
      CertificateType.projectExcellence => 'Project Excellence Certificate',
      _ => 'Course Completion Certificate',
    };
  }

  String _descriptionFor(String type, String courseTitle) {
    return switch (CertificateType.normalize(type)) {
      CertificateType.excellence =>
        'Awarded for outstanding performance in $courseTitle.',
      CertificateType.projectExcellence =>
        'Awarded for excellent project work in $courseTitle.',
      _ => 'Awarded for successfully completing $courseTitle.',
    };
  }

  double _finalScoreFor(String type, CertificateEligibilityResult eligibility) {
    return switch (CertificateType.normalize(type)) {
      CertificateType.projectExcellence => eligibility.assignmentAverage,
      CertificateType.excellence =>
        ((eligibility.grandTestScore + eligibility.assignmentAverage) / 2)
            .clamp(0, 100)
            .toDouble(),
      _ =>
        ([
                  eligibility.lessonProgress,
                  eligibility.assignmentAverage,
                  eligibility.grandTestScore,
                ].reduce((a, b) => a + b) /
                3)
            .clamp(0, 100)
            .toDouble(),
    };
  }
}

class _AssignmentStats {
  const _AssignmentStats({
    required this.totalAssignments,
    required this.completedAssignments,
    required this.completionPercent,
    required this.averagePercent,
    required this.projectSubmitted,
  });

  final int totalAssignments;
  final int completedAssignments;
  final double completionPercent;
  final double averagePercent;
  final bool projectSubmitted;
}

class _GrandTestStats {
  const _GrandTestStats({
    this.grandTestId = '',
    this.passed = false,
    this.bestScore = 0,
    this.requiredLessonProgressPercent,
    this.requiredAssignmentCompletionPercent,
  });

  final String grandTestId;
  final bool passed;
  final double bestScore;
  final double? requiredLessonProgressPercent;
  final double? requiredAssignmentCompletionPercent;
}

String _normalizeValue(Object? value) {
  if (value is String) return value.trim().toLowerCase();
  if (value is num) return value.toString();
  return '';
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
