import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/grand_test_attempt_model.dart';
import '../models/grand_test_eligibility_model.dart';
import '../models/grand_test_model.dart';
import '../models/mcq_assignment_model.dart';
import '../models/mcq_attempt_model.dart';
import '../models/project_submission_model.dart';
import '../services/course_progress_service.dart';

GrandTestEligibilityModel buildGrandTestEligibilityFallback({
  required String courseId,
  required String grandTestId,
  required String studentId,
  required String reason,
}) {
  final calculatedAt = DateTime.now();
  return GrandTestEligibilityModel(
    courseId: courseId,
    grandTestId: grandTestId,
    studentId: studentId,
    readinessPercent: 0,
    isEligible: false,
    reasons: [reason],
    lessonProgress: 0,
    requiredLessonProgressPercent: 0,
    assignmentCompletion: 0,
    requiredAssignmentCompletionPercent: 0,
    averageScore: 0,
    requiredAverageScorePercent: 0,
    projectSubmitted: false,
    requireProjectSubmission: false,
    attemptsUsed: 0,
    maxAttempts: 1,
    missingRequirements: [reason],
    recommendations: const [
      'Try again in a moment or contact your teacher if the issue continues.',
    ],
    calculatedAt: calculatedAt,
  );
}

abstract class GrandTestRepository {
  Future<String> createGrandTest(GrandTestModel test);
  Future<void> updateGrandTest(GrandTestModel test);
  Future<void> publishGrandTest({
    required String courseId,
    required String grandTestId,
    required String teacherId,
  });
  Future<void> archiveGrandTest({
    required String courseId,
    required String grandTestId,
    required String teacherId,
  });
  Future<GrandTestModel?> getGrandTest({
    required String courseId,
    required String grandTestId,
  });
  Stream<List<GrandTestModel>> watchTeacherGrandTests(String courseId);
  Stream<List<GrandTestModel>> watchPublishedGrandTests(String courseId);
  Future<int> countPublishedGrandTestsInCourse(String courseId);
  Future<int> countGrandTestsInCourse(String courseId);
  Stream<List<GrandTestAttemptModel>> watchGrandTestAttempts({
    required String courseId,
    required String grandTestId,
  });
  Stream<List<GrandTestAttemptModel>> watchStudentAttempts({
    required String courseId,
    required String grandTestId,
    required String studentId,
  });
  Future<GrandTestAttemptModel> startAttempt({
    required String courseId,
    required String grandTestId,
    required String studentId,
  });
  Future<void> submitAttempt({
    required String courseId,
    required String grandTestId,
    required String attemptId,
    required Map<String, String> answers,
    required int warningsCount,
    required bool autoSubmitted,
  });
  Future<GrandTestEligibilityModel> checkEligibility({
    required String courseId,
    required String grandTestId,
    required String studentId,
  });
}

class FirestoreGrandTestRepository implements GrandTestRepository {
  const FirestoreGrandTestRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _grandTests(String courseId) =>
      _firestore.collection('courses').doc(courseId).collection('grandTests');

  CollectionReference<Map<String, dynamic>> _attempts({
    required String courseId,
    required String grandTestId,
  }) {
    return _grandTests(courseId).doc(grandTestId).collection('attempts');
  }

  DocumentReference<Map<String, dynamic>> _enrollmentRef({
    required String courseId,
    required String studentId,
  }) {
    return _firestore.collection('enrollments').doc('${studentId}_$courseId');
  }

  @override
  Future<String> createGrandTest(GrandTestModel test) async {
    try {
      final docRef = test.grandTestId.isEmpty
          ? _grandTests(test.courseId).doc()
          : _grandTests(test.courseId).doc(test.grandTestId);
      final now = DateTime.now();
      await docRef.set(
        test
            .copyWith(
              grandTestId: docRef.id,
              status: AssignmentStatus.draft,
              createdAt: now,
              updatedAt: now,
              totalMarks: _calculateTotalMarks(test),
            )
            .toJson(),
      );
      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create grand test: ${e.toString()}');
    }
  }

  @override
  Future<void> updateGrandTest(GrandTestModel test) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _grandTests(test.courseId).doc(test.grandTestId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Grand test not found.');
        }
        if (snapshot.data()?['teacherId']?.toString() != test.teacherId) {
          throw StateError('Only the course teacher can edit this grand test.');
        }
        transaction.update(
          docRef,
          test
              .copyWith(
                updatedAt: DateTime.now(),
                totalMarks: _calculateTotalMarks(test),
              )
              .toJson(),
        );
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update grand test: ${e.toString()}');
    }
  }

  @override
  Future<void> publishGrandTest({
    required String courseId,
    required String grandTestId,
    required String teacherId,
  }) {
    return _updateStatus(
      courseId: courseId,
      grandTestId: grandTestId,
      teacherId: teacherId,
      status: AssignmentStatus.published,
    );
  }

  @override
  Future<void> archiveGrandTest({
    required String courseId,
    required String grandTestId,
    required String teacherId,
  }) {
    return _updateStatus(
      courseId: courseId,
      grandTestId: grandTestId,
      teacherId: teacherId,
      status: AssignmentStatus.archived,
    );
  }

  @override
  Future<GrandTestModel?> getGrandTest({
    required String courseId,
    required String grandTestId,
  }) async {
    try {
      final snapshot = await _grandTests(courseId).doc(grandTestId).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      return GrandTestModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load grand test: ${e.toString()}');
    }
  }

  @override
  Future<int> countPublishedGrandTestsInCourse(String courseId) async {
    try {
      final snapshot = await _grandTests(
        courseId,
      ).where('status', isEqualTo: AssignmentStatus.published).count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to count grand tests: ${e.toString()}');
    }
  }

  @override
  Future<int> countGrandTestsInCourse(String courseId) async {
    try {
      final snapshot = await _grandTests(courseId).count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to count grand tests: ${e.toString()}');
    }
  }

  @override
  Stream<List<GrandTestModel>> watchTeacherGrandTests(String courseId) {
    return _grandTests(courseId).snapshots().map((snapshot) {
      final tests = snapshot.docs
          .map((doc) => GrandTestModel.fromFirestore(doc))
          .toList();
      tests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return tests;
    });
  }

  @override
  Stream<List<GrandTestModel>> watchPublishedGrandTests(String courseId) {
    return _grandTests(courseId)
        .where('status', isEqualTo: AssignmentStatus.published)
        .snapshots()
        .map((snapshot) {
          final tests = snapshot.docs
              .map((doc) => GrandTestModel.fromFirestore(doc))
              .toList();
          tests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return tests;
        });
  }

  @override
  Stream<List<GrandTestAttemptModel>> watchGrandTestAttempts({
    required String courseId,
    required String grandTestId,
  }) {
    return _attempts(
      courseId: courseId,
      grandTestId: grandTestId,
    ).snapshots().map((snapshot) {
      final attempts = snapshot.docs
          .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
          .toList();
      attempts.sort((a, b) {
        final submitted = (b.submittedAt ?? b.startedAt).compareTo(
          a.submittedAt ?? a.startedAt,
        );
        if (submitted != 0) return submitted;
        return b.attemptNumber.compareTo(a.attemptNumber);
      });
      return attempts;
    });
  }

  @override
  Stream<List<GrandTestAttemptModel>> watchStudentAttempts({
    required String courseId,
    required String grandTestId,
    required String studentId,
  }) {
    return _attempts(
      courseId: courseId,
      grandTestId: grandTestId,
    ).where('studentId', isEqualTo: studentId).snapshots().map((snapshot) {
      final attempts = snapshot.docs
          .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
          .toList();
      attempts.sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));
      return attempts;
    });
  }

  @override
  Future<GrandTestAttemptModel> startAttempt({
    required String courseId,
    required String grandTestId,
    required String studentId,
  }) async {
    try {
      final test = await getGrandTest(
        courseId: courseId,
        grandTestId: grandTestId,
      );
      if (test == null || !test.isPublished) {
        throw StateError('Grand test is not available.');
      }

      final attemptsSnapshot = await _attempts(
        courseId: courseId,
        grandTestId: grandTestId,
      ).where('studentId', isEqualTo: studentId).get();
      final existingAttempts = attemptsSnapshot.docs
          .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
          .toList();
      existingAttempts.sort(
        (a, b) => b.attemptNumber.compareTo(a.attemptNumber),
      );

      for (final attempt in existingAttempts) {
        if (attempt.isInProgress) return attempt;
      }

      if (existingAttempts.length >= test.maxAttempts) {
        throw StateError('Maximum grand test attempts used.');
      }

      final eligibility = await checkEligibility(
        courseId: courseId,
        grandTestId: grandTestId,
        studentId: studentId,
      );
      if (!eligibility.isEligible) {
        throw StateError(eligibility.reasons.join(' '));
      }

      final attemptNumber = existingAttempts.length + 1;
      final attemptId = '${studentId}_$attemptNumber';
      final random = Random();
      final questionOrder = test.questions.map((q) => q.questionId).toList()
        ..shuffle(random);
      final optionOrder = <String, List<String>>{};
      for (final question in test.questions) {
        optionOrder[question.questionId] = [...question.options]
          ..shuffle(random);
      }

      final attempt = GrandTestAttemptModel(
        attemptId: attemptId,
        grandTestId: grandTestId,
        courseId: courseId,
        studentId: studentId,
        teacherId: test.teacherId,
        attemptNumber: attemptNumber,
        answers: const {},
        score: 0,
        totalMarks: test.totalMarks,
        passingMarks: test.passingMarks,
        percentage: 0,
        passed: false,
        startedAt: DateTime.now(),
        submittedAt: null,
        timeTakenSeconds: 0,
        warningsCount: 0,
        eligibilitySnapshot: eligibility.toJson(),
        status: GrandTestAttemptStatus.inProgress,
        questionOrder: questionOrder,
        optionOrder: optionOrder,
      );

      await _attempts(
        courseId: courseId,
        grandTestId: grandTestId,
      ).doc(attemptId).set(attempt.toJson());
      return attempt;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to start grand test: ${e.toString()}');
    }
  }

  @override
  Future<void> submitAttempt({
    required String courseId,
    required String grandTestId,
    required String attemptId,
    required Map<String, String> answers,
    required int warningsCount,
    required bool autoSubmitted,
  }) async {
    try {
      final test = await getGrandTest(
        courseId: courseId,
        grandTestId: grandTestId,
      );
      if (test == null) throw StateError('Grand test not found.');

      final attemptRef = _attempts(
        courseId: courseId,
        grandTestId: grandTestId,
      ).doc(attemptId);
      final attemptSnapshot = await attemptRef.get();
      if (!attemptSnapshot.exists || attemptSnapshot.data() == null) {
        throw StateError('Grand test attempt not found.');
      }

      final current = GrandTestAttemptModel.fromFirestore(attemptSnapshot);
      if (current.isSubmitted) return;

      var score = 0;
      for (final question in test.questions) {
        final selected = answers[question.questionId]?.trim().toLowerCase();
        final correct = question.correctAnswer.trim().toLowerCase();
        if (selected != null && selected == correct) {
          score += question.marks;
        }
      }

      final totalMarks = test.totalMarks > 0
          ? test.totalMarks
          : _calculateTotalMarks(test);
      final percentage = totalMarks == 0 ? 0.0 : (score / totalMarks) * 100;
      final now = DateTime.now();

      await attemptRef.update({
        'answers': answers,
        'score': score,
        'totalMarks': totalMarks,
        'passingMarks': test.passingMarks,
        'percentage': percentage,
        'passed': score >= test.passingMarks,
        'submittedAt': Timestamp.fromDate(now),
        'timeTakenSeconds': now.difference(current.startedAt).inSeconds,
        'warningsCount': warningsCount,
        'status': autoSubmitted
            ? GrandTestAttemptStatus.autoSubmitted
            : GrandTestAttemptStatus.submitted,
      });

      // Passing the grand test completes a course requirement. Never fail the
      // submission if the progress refresh fails.
      try {
        await CourseProgressService(_firestore).syncEnrollmentProgress(
          courseId: courseId,
          studentId: current.studentId,
        );
      } catch (error) {
        AppLogger.warn('Grand test progress synchronization failed: $error');
      }
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to submit grand test: ${e.toString()}');
    }
  }

  @override
  Future<GrandTestEligibilityModel> checkEligibility({
    required String courseId,
    required String grandTestId,
    required String studentId,
  }) async {
    final test = await getGrandTest(
      courseId: courseId,
      grandTestId: grandTestId,
    );
    if (test == null) {
      throw const FirestoreException('Grand test not found.');
    }

    final reasons = <String>[];
    final enrollment = await _enrollmentRef(
      courseId: courseId,
      studentId: studentId,
    ).get();

    if (!enrollment.exists || enrollment.data() == null) {
      reasons.add('Enroll in this course first.');
      final calculatedAt = DateTime.now();
      return GrandTestEligibilityModel(
        courseId: courseId,
        grandTestId: grandTestId,
        studentId: studentId,
        readinessPercent: 0,
        isEligible: false,
        reasons: reasons,
        lessonProgress: 0,
        requiredLessonProgressPercent: test.requiredLessonProgressPercent,
        assignmentCompletion: 0,
        requiredAssignmentCompletionPercent:
            test.requiredAssignmentCompletionPercent,
        averageScore: 0,
        requiredAverageScorePercent: test.requiredAverageScorePercent,
        projectSubmitted: false,
        requireProjectSubmission: test.requireProjectSubmission,
        attemptsUsed: 0,
        maxAttempts: test.maxAttempts,
        missingRequirements: reasons,
        recommendations: const [
          'Enroll in this course before preparing for the Grand Test.',
        ],
        calculatedAt: calculatedAt,
      );
    }

    final enrollmentData = enrollment.data()!;
    final lessonProgress = await _lessonProgressPercent(
      courseId: courseId,
      enrollmentRef: enrollment.reference,
      enrollmentData: enrollmentData,
    );
    if (lessonProgress < test.requiredLessonProgressPercent) {
      reasons.add(
        'Complete at least ${test.requiredLessonProgressPercent.toStringAsFixed(0)}% lessons.',
      );
    }

    final assignments = await _firestore
        .collection('courses')
        .doc(courseId)
        .collection('assignments')
        .where('status', isEqualTo: AssignmentStatus.published)
        .where('type', whereIn: ['mcq', 'project'])
        .get();

    var completedAssignments = 0;
    var scoredItems = 0;
    var totalScore = 0.0;
    var projectCount = 0;
    var projectSubmitted = false;

    for (final doc in assignments.docs) {
      final type = _normalizeValue(doc.data()['type']);
      if (type == 'mcq') {
        final attempt = await _studentMcqAttempt(doc.reference, studentId);
        final attemptStatus = _normalizeValue(attempt?['status']);
        if (attemptStatus == McqAttemptStatus.submitted) {
          completedAssignments++;
          scoredItems++;
          totalScore += _doubleValue(attempt?['percentage']);
        }
      } else if (type == 'project') {
        projectCount++;
        final submission = await _studentProjectSubmission(
          doc.reference,
          studentId,
        );
        if (submission != null) {
          final status = ProjectSubmissionStatus.normalize(
            submission['status']?.toString(),
          );
          if (status == ProjectSubmissionStatus.submitted ||
              status == ProjectSubmissionStatus.graded) {
            projectSubmitted = true;
            completedAssignments++;
          }
          if (status == ProjectSubmissionStatus.graded) {
            scoredItems++;
            totalScore += _doubleValue(submission['percentage']);
          }
        }
      }
    }

    final totalAssignments = assignments.docs.length;
    final assignmentCompletion = totalAssignments == 0
        ? 100.0
        : (completedAssignments / totalAssignments) * 100;
    final requiredAssignmentCount = totalAssignments == 0
        ? 0
        : ((totalAssignments * test.requiredAssignmentCompletionPercent) / 100)
              .ceil();
    final pendingAssignments = max(
      0,
      requiredAssignmentCount - completedAssignments,
    );
    if (assignmentCompletion < test.requiredAssignmentCompletionPercent) {
      reasons.add(
        pendingAssignments > 0
            ? 'Complete $pendingAssignments more assignment${pendingAssignments == 1 ? '' : 's'}.'
            : 'Complete at least ${test.requiredAssignmentCompletionPercent.toStringAsFixed(0)}% assignments.',
      );
    }

    final averageScore = totalAssignments == 0
        ? 100.0
        : scoredItems == 0
        ? 100.0 // Give benefit of doubt until graded
        : totalScore / scoredItems;
    if (averageScore < test.requiredAverageScorePercent) {
      reasons.add(
        'Maintain at least ${test.requiredAverageScorePercent.toStringAsFixed(0)}% average assignment score.',
      );
    }

    if (test.requireProjectSubmission &&
        projectCount > 0 &&
        !projectSubmitted) {
      reasons.add('Submit or pass at least one project assignment.');
    }

    final attemptModels = <GrandTestAttemptModel>[];
    try {
      final attempts = await _grandTests(courseId)
          .doc(grandTestId)
          .collection('attempts')
          .where('studentId', isEqualTo: studentId)
          .get();
      attemptModels.addAll(
        attempts.docs.map((doc) => GrandTestAttemptModel.fromFirestore(doc)),
      );
    } on FirebaseException {
      // Attempts are only used for remaining-attempt display here. If rules
      // deny this read, keep readiness based on course completion instead of
      // collapsing the whole report to 0%.
    }
    final attemptsUsed = attemptModels.length;
    final hasInProgressAttempt = attemptModels.any(
      (attempt) => attempt.isInProgress,
    );
    final submittedAttempts = attemptModels
        .where((attempt) => attempt.isSubmitted)
        .length;
    final attemptsExhausted =
        !hasInProgressAttempt &&
        attemptsUsed >= test.maxAttempts &&
        submittedAttempts >= test.maxAttempts;
    if (attemptsExhausted) {
      reasons.add('Maximum grand test attempts used.');
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
        !test.requireProjectSubmission || projectCount == 0 || projectSubmitted
        ? 1.0
        : 0.0;
    final attemptReadiness = attemptsExhausted ? 0.0 : 1.0;
    final readinessPercent =
        ((lessonReadiness * 30) +
                (assignmentReadiness * 25) +
                (scoreReadiness * 25) +
                (projectReadiness * 10) +
                (attemptReadiness * 10))
            .clamp(0, 100)
            .toDouble();
    final recommendations = _buildReadinessRecommendations(
      lessonProgress: lessonProgress,
      requiredLessonProgress: test.requiredLessonProgressPercent,
      assignmentCompletion: assignmentCompletion,
      requiredAssignmentCompletion: test.requiredAssignmentCompletionPercent,
      averageScore: averageScore,
      requiredAverageScore: test.requiredAverageScorePercent,
      requireProjectSubmission: test.requireProjectSubmission,
      projectCount: projectCount,
      projectSubmitted: projectSubmitted,
      attemptsUsed: attemptsUsed,
      maxAttempts: test.maxAttempts,
      isEligible: reasons.isEmpty,
    );

    final result = GrandTestEligibilityModel(
      courseId: courseId,
      grandTestId: grandTestId,
      studentId: studentId,
      readinessPercent: readinessPercent,
      isEligible: reasons.isEmpty,
      reasons: reasons,
      lessonProgress: lessonProgress,
      requiredLessonProgressPercent: test.requiredLessonProgressPercent,
      assignmentCompletion: assignmentCompletion,
      requiredAssignmentCompletionPercent:
          test.requiredAssignmentCompletionPercent,
      averageScore: averageScore,
      requiredAverageScorePercent: test.requiredAverageScorePercent,
      projectSubmitted: projectSubmitted || projectCount == 0,
      requireProjectSubmission: test.requireProjectSubmission,
      attemptsUsed: attemptsUsed,
      maxAttempts: test.maxAttempts,
      missingRequirements: reasons,
      recommendations: recommendations,
      calculatedAt: DateTime.now(),
    );

    try {
      await _grandTests(courseId)
          .doc(grandTestId)
          .collection('eligibility')
          .doc(studentId)
          .set(result.toJson(), SetOptions(merge: true));
    } on FirebaseException {
      // Eligibility cache is a convenience for teachers/admin views. Students
      // should never be blocked from seeing readiness because cache writes are
      // restricted by security rules.
    }

    return result;
  }

  Future<Map<String, dynamic>?> _studentMcqAttempt(
    DocumentReference<Map<String, dynamic>> assignmentRef,
    String studentId,
  ) async {
    final direct = await assignmentRef
        .collection('attempts')
        .doc(studentId)
        .get();
    if (direct.exists && direct.data() != null) return direct.data();

    final attempts = await assignmentRef
        .collection('attempts')
        .where('studentId', isEqualTo: studentId)
        .get();
    if (attempts.docs.isEmpty) return null;

    final submitted = attempts.docs
        .map((doc) => doc.data())
        .where(
          (data) =>
              _normalizeValue(data['status']) == McqAttemptStatus.submitted,
        )
        .toList();
    final candidates = submitted.isNotEmpty
        ? submitted
        : attempts.docs.map((doc) => doc.data()).toList();
    candidates.sort(
      (a, b) => _doubleValue(
        b['percentage'],
      ).compareTo(_doubleValue(a['percentage'])),
    );
    return candidates.first;
  }

  Future<Map<String, dynamic>?> _studentProjectSubmission(
    DocumentReference<Map<String, dynamic>> assignmentRef,
    String studentId,
  ) async {
    final direct = await assignmentRef
        .collection('submissions')
        .doc(studentId)
        .get();
    if (direct.exists && direct.data() != null) return direct.data();

    final submissions = await assignmentRef
        .collection('submissions')
        .where('studentId', isEqualTo: studentId)
        .get();
    if (submissions.docs.isEmpty) return null;

    final candidates = submissions.docs.map((doc) => doc.data()).toList();
    candidates.sort((a, b) {
      final aGraded =
          ProjectSubmissionStatus.normalize(a['status']?.toString()) ==
          ProjectSubmissionStatus.graded;
      final bGraded =
          ProjectSubmissionStatus.normalize(b['status']?.toString()) ==
          ProjectSubmissionStatus.graded;
      if (aGraded != bGraded) return bGraded ? 1 : -1;
      return _doubleValue(
        b['percentage'],
      ).compareTo(_doubleValue(a['percentage']));
    });
    return candidates.first;
  }

  Future<double> _lessonProgressPercent({
    required String courseId,
    required DocumentReference<Map<String, dynamic>> enrollmentRef,
    required Map<String, dynamic> enrollmentData,
  }) async {
    // Eligibility gates on lessons only. `progressPercent` is overall course
    // completion (which includes this grand test), so it must not be used here.
    final storedProgress = _doubleValue(
      enrollmentData['lessonProgressPercent'],
    );
    if (storedProgress > 0) return storedProgress.clamp(0, 100).toDouble();

    final storedCompleted = _intValue(enrollmentData['completedLessons']);
    final storedTotal = _intValue(enrollmentData['totalLessons']);
    if (storedCompleted > 0 && storedTotal > 0) {
      return ((storedCompleted / storedTotal) * 100).clamp(0, 100).toDouble();
    }

    final progressSnapshot = await enrollmentRef
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

  double _readinessRatio(double actual, double required) {
    if (required <= 0) return 1;
    return (actual / required).clamp(0, 1).toDouble();
  }

  List<String> _buildReadinessRecommendations({
    required double lessonProgress,
    required double requiredLessonProgress,
    required double assignmentCompletion,
    required double requiredAssignmentCompletion,
    required double averageScore,
    required double requiredAverageScore,
    required bool requireProjectSubmission,
    required int projectCount,
    required bool projectSubmitted,
    required int attemptsUsed,
    required int maxAttempts,
    required bool isEligible,
  }) {
    if (attemptsUsed >= maxAttempts) {
      return const [
        'You have used all allowed Grand Test attempts. Review your result and contact your teacher if you need help.',
      ];
    }
    if (isEligible) {
      return const [
        'You are ready for the Grand Test. Review the course summary, then start when you feel confident.',
      ];
    }

    final recommendations = <String>[];
    if (lessonProgress < requiredLessonProgress) {
      recommendations.add(
        'Complete your remaining lessons before attempting the Grand Test.',
      );
    }
    if (assignmentCompletion < requiredAssignmentCompletion) {
      recommendations.add(
        'Finish pending assignments to unlock Grand Test access.',
      );
    }
    if (averageScore < requiredAverageScore) {
      recommendations.add(
        'Review low-scoring assignments and improve your average score.',
      );
    }
    if (requireProjectSubmission && projectCount > 0 && !projectSubmitted) {
      recommendations.add(
        'Submit your project assignment to satisfy eligibility.',
      );
    }
    recommendations.add(
      'Contact your teacher if you believe your progress is not updated.',
    );
    return recommendations;
  }

  Future<void> _updateStatus({
    required String courseId,
    required String grandTestId,
    required String teacherId,
    required String status,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _grandTests(courseId).doc(grandTestId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Grand test not found.');
        }
        if (snapshot.data()?['teacherId']?.toString() != teacherId) {
          throw StateError(
            'Only the course teacher can update this grand test.',
          );
        }
        final now = DateTime.now();
        transaction.update(docRef, {
          'status': status,
          'updatedAt': Timestamp.fromDate(now),
          if (status == AssignmentStatus.published)
            'publishedAt': Timestamp.fromDate(now),
          if (status == AssignmentStatus.archived)
            'archivedAt': Timestamp.fromDate(now),
        });
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update grand test status: ${e.toString()}',
      );
    }
  }

  int _calculateTotalMarks(GrandTestModel test) {
    return test.questions.fold<int>(
      0,
      (total, question) => total + question.marks,
    );
  }

  String _normalizeValue(Object? value) {
    if (value is String) return value.trim().toLowerCase();
    if (value is num) return value.toString();
    return '';
  }

  double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
