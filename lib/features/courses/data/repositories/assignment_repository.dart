import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/mcq_assignment_model.dart';
import '../models/mcq_attempt_model.dart';
import '../models/project_assignment_model.dart';
import '../models/project_submission_model.dart';
import '../services/course_progress_service.dart';

abstract class AssignmentRepository {
  Future<String> createAssignment(McqAssignmentModel assignment);
  Future<void> updateAssignment(McqAssignmentModel assignment);
  Future<void> publishAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  });
  Future<void> archiveAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  });
  Future<McqAssignmentModel?> getAssignment({
    required String courseId,
    required String assignmentId,
  });
  Stream<List<McqAssignmentModel>> watchTeacherAssignments(String courseId);
  Stream<List<McqAssignmentModel>> watchPublishedAssignments(String courseId);
  Future<int> countPublishedAssignmentsInCourse(String courseId);
  Stream<McqAttemptModel?> watchAttempt({
    required String courseId,
    required String assignmentId,
    required String studentId,
  });
  Stream<List<McqAttemptModel>> watchAttempts({
    required String courseId,
    required String assignmentId,
  });
  Future<void> startAttempt({
    required String courseId,
    required String assignmentId,
    required String studentId,
  });
  Future<void> submitAttempt({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required Map<String, String> answers,
    required int warningsCount,
    required bool autoSubmitted,
  });
  Future<String> createProjectAssignment(ProjectAssignmentModel assignment);
  Future<void> updateProjectAssignment(ProjectAssignmentModel assignment);
  Future<void> publishProjectAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  });
  Future<void> archiveProjectAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  });
  Future<ProjectAssignmentModel?> getProjectAssignment({
    required String courseId,
    required String assignmentId,
  });
  Stream<List<ProjectAssignmentModel>> watchTeacherProjectAssignments(
    String courseId,
  );
  Stream<List<ProjectAssignmentModel>> watchPublishedProjectAssignments(
    String courseId,
  );
  Future<int> countPublishedProjectAssignmentsInCourse(String courseId);
  Stream<ProjectSubmissionModel?> watchProjectSubmission({
    required String courseId,
    required String assignmentId,
    required String studentId,
  });
  Stream<List<ProjectSubmissionModel>> watchProjectSubmissions({
    required String courseId,
    required String assignmentId,
  });
  Future<void> submitProject({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String projectDescription,
    required String githubLink,
    required String liveDemoLink,
    required String additionalNotes,
  });
  Future<void> reviewProjectSubmission({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String teacherId,
    required String status,
    required int marks,
    required String feedback,
  });
}

class FirestoreAssignmentRepository implements AssignmentRepository {
  const FirestoreAssignmentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _assignments(String courseId) =>
      _firestore.collection('courses').doc(courseId).collection('assignments');

  DocumentReference<Map<String, dynamic>> _attemptRef({
    required String courseId,
    required String assignmentId,
    required String studentId,
  }) {
    return _assignments(
      courseId,
    ).doc(assignmentId).collection('attempts').doc(studentId);
  }

  DocumentReference<Map<String, dynamic>> _enrollmentRef({
    required String courseId,
    required String studentId,
  }) {
    return _firestore.collection('enrollments').doc('${studentId}_$courseId');
  }

  DocumentReference<Map<String, dynamic>> _submissionRef({
    required String courseId,
    required String assignmentId,
    required String studentId,
  }) {
    return _assignments(
      courseId,
    ).doc(assignmentId).collection('submissions').doc(studentId);
  }

  @override
  Future<String> createAssignment(McqAssignmentModel assignment) async {
    try {
      final docRef = assignment.assignmentId.isEmpty
          ? _assignments(assignment.courseId).doc()
          : _assignments(assignment.courseId).doc(assignment.assignmentId);
      final now = DateTime.now();
      await docRef.set(
        assignment
            .copyWith(
              assignmentId: docRef.id,
              status: AssignmentStatus.draft,
              createdAt: now,
              updatedAt: now,
              totalMarks: _calculatedTotal(assignment),
            )
            .toJson(),
      );
      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create assignment: ${e.toString()}');
    }
  }

  @override
  Future<void> updateAssignment(McqAssignmentModel assignment) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _assignments(
          assignment.courseId,
        ).doc(assignment.assignmentId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Assignment not found.');
        }
        if (snapshot.data()?['teacherId']?.toString() != assignment.teacherId) {
          throw StateError('Only the assignment teacher can edit it.');
        }
        transaction.update(
          docRef,
          assignment
              .copyWith(
                updatedAt: DateTime.now(),
                totalMarks: _calculatedTotal(assignment),
              )
              .toJson(),
        );
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update assignment: ${e.toString()}');
    }
  }

  @override
  Future<void> publishAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  }) {
    return _updateStatus(
      courseId: courseId,
      assignmentId: assignmentId,
      teacherId: teacherId,
      status: AssignmentStatus.published,
    );
  }

  @override
  Future<void> archiveAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  }) {
    return _updateStatus(
      courseId: courseId,
      assignmentId: assignmentId,
      teacherId: teacherId,
      status: AssignmentStatus.archived,
    );
  }

  @override
  Future<McqAssignmentModel?> getAssignment({
    required String courseId,
    required String assignmentId,
  }) async {
    try {
      final snapshot = await _assignments(courseId).doc(assignmentId).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      return McqAssignmentModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load assignment: ${e.toString()}');
    }
  }

  @override
  Stream<List<McqAssignmentModel>> watchTeacherAssignments(String courseId) {
    return _assignments(
      courseId,
    ).where('type', isEqualTo: 'mcq').snapshots().map((snapshot) {
      final assignments = snapshot.docs
          .map((doc) => McqAssignmentModel.fromFirestore(doc))
          .toList();
      assignments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return assignments;
    });
  }

  @override
  Future<int> countPublishedAssignmentsInCourse(String courseId) async {
    try {
      final snapshot = await _assignments(
        courseId,
      ).where('status', isEqualTo: AssignmentStatus.published).count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to count assignments: ${e.toString()}');
    }
  }

  @override
  Stream<List<McqAssignmentModel>> watchPublishedAssignments(String courseId) {
    return _assignments(courseId)
        .where('type', isEqualTo: 'mcq')
        .where('status', isEqualTo: AssignmentStatus.published)
        .snapshots()
        .map((snapshot) {
          final assignments = snapshot.docs
              .map((doc) => McqAssignmentModel.fromFirestore(doc))
              .toList();
          assignments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return assignments;
        });
  }

  @override
  Stream<McqAttemptModel?> watchAttempt({
    required String courseId,
    required String assignmentId,
    required String studentId,
  }) {
    return _attemptRef(
      courseId: courseId,
      assignmentId: assignmentId,
      studentId: studentId,
    ).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return McqAttemptModel.fromFirestore(snapshot);
    });
  }

  @override
  Stream<List<McqAttemptModel>> watchAttempts({
    required String courseId,
    required String assignmentId,
  }) {
    return _assignments(courseId)
        .doc(assignmentId)
        .collection('attempts')
        .where('status', isEqualTo: McqAttemptStatus.submitted)
        .snapshots()
        .map((snapshot) {
          final attempts = snapshot.docs
              .map((doc) => McqAttemptModel.fromFirestore(doc))
              .toList();
          attempts.sort((a, b) {
            final aDate = a.submittedAt ?? a.startedAt;
            final bDate = b.submittedAt ?? b.startedAt;
            return bDate.compareTo(aDate);
          });
          return attempts;
        });
  }

  @override
  Future<void> startAttempt({
    required String courseId,
    required String assignmentId,
    required String studentId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final enrollment = await transaction.get(
          _enrollmentRef(courseId: courseId, studentId: studentId),
        );
        if (!enrollment.exists) {
          throw StateError('Enroll in this course before attempting.');
        }

        final assignmentRef = _assignments(courseId).doc(assignmentId);
        final assignmentSnapshot = await transaction.get(assignmentRef);
        if (!assignmentSnapshot.exists || assignmentSnapshot.data() == null) {
          throw StateError('Assignment not found.');
        }
        final assignment = McqAssignmentModel.fromFirestore(assignmentSnapshot);
        if (!assignment.isPublished) {
          throw StateError('Assignment is not published.');
        }

        final attemptRef = _attemptRef(
          courseId: courseId,
          assignmentId: assignmentId,
          studentId: studentId,
        );
        final attemptSnapshot = await transaction.get(attemptRef);
        if (attemptSnapshot.exists &&
            attemptSnapshot.data()?['status'] == McqAttemptStatus.submitted) {
          return;
        }
        if (!attemptSnapshot.exists) {
          transaction.set(attemptRef, {
            'assignmentId': assignmentId,
            'courseId': courseId,
            'studentId': studentId,
            'teacherId': assignment.teacherId,
            'startedAt': Timestamp.fromDate(DateTime.now()),
            'answers': <String, String>{},
            'score': 0,
            'totalMarks': assignment.totalMarks,
            'passingMarks': assignment.passingMarks,
            'percentage': 0,
            'passed': false,
            'warningsCount': 0,
            'status': McqAttemptStatus.inProgress,
            'autoSubmitted': false,
          });
        }
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to start attempt: ${e.toString()}');
    }
  }

  @override
  Future<void> submitAttempt({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required Map<String, String> answers,
    required int warningsCount,
    required bool autoSubmitted,
  }) async {
    final cleanedAnswers = Map<String, String>.fromEntries(
      answers.entries.where((entry) => entry.value.trim().isNotEmpty),
    );
    if (cleanedAnswers.isEmpty && !autoSubmitted) {
      throw const FirestoreException('Answer at least one question to submit.');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final enrollment = await transaction.get(
          _enrollmentRef(courseId: courseId, studentId: studentId),
        );
        if (!enrollment.exists) {
          throw StateError('Enroll in this course before submitting.');
        }

        final assignmentSnapshot = await transaction.get(
          _assignments(courseId).doc(assignmentId),
        );
        if (!assignmentSnapshot.exists || assignmentSnapshot.data() == null) {
          throw StateError('Assignment not found.');
        }
        final assignment = McqAssignmentModel.fromFirestore(assignmentSnapshot);
        if (!assignment.isPublished) {
          throw StateError('Assignment is not published.');
        }

        var score = 0;
        for (final question in assignment.questions) {
          final selected = cleanedAnswers[question.questionId]?.trim();
          if (selected != null &&
              selected.toLowerCase() ==
                  question.correctAnswer.trim().toLowerCase()) {
            score += question.marksPerQuestion;
          }
        }

        final totalMarks = assignment.totalMarks <= 0
            ? _calculatedTotal(assignment)
            : assignment.totalMarks;
        final percentage = totalMarks == 0 ? 0.0 : (score / totalMarks) * 100;
        final now = DateTime.now();
        final attemptRef = _attemptRef(
          courseId: courseId,
          assignmentId: assignmentId,
          studentId: studentId,
        );
        final attemptSnapshot = await transaction.get(attemptRef);
        if (attemptSnapshot.exists &&
            attemptSnapshot.data()?['status'] == McqAttemptStatus.submitted) {
          return;
        }

        transaction.set(attemptRef, {
          'assignmentId': assignmentId,
          'courseId': courseId,
          'studentId': studentId,
          'teacherId': assignment.teacherId,
          if (!attemptSnapshot.exists) 'startedAt': Timestamp.fromDate(now),
          'submittedAt': Timestamp.fromDate(now),
          'answers': cleanedAnswers,
          'score': score,
          'totalMarks': totalMarks,
          'passingMarks': assignment.passingMarks,
          'percentage': percentage.clamp(0, 100),
          'passed': score >= assignment.passingMarks,
          'warningsCount': warningsCount,
          'status': McqAttemptStatus.submitted,
          'autoSubmitted': autoSubmitted,
        }, SetOptions(merge: true));
      });
      await _syncCourseProgress(courseId: courseId, studentId: studentId);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to submit attempt: ${e.toString()}');
    }
  }

  /// A quiz/project counts towards overall course completion, so refresh the
  /// enrollment progress. Never fail the submission if the refresh fails.
  Future<void> _syncCourseProgress({
    required String courseId,
    required String studentId,
  }) async {
    try {
      await CourseProgressService(
        _firestore,
      ).syncEnrollmentProgress(courseId: courseId, studentId: studentId);
    } catch (error) {
      AppLogger.warn('Assignment progress synchronization failed: $error');
    }
  }

  Future<void> _updateStatus({
    required String courseId,
    required String assignmentId,
    required String teacherId,
    required String status,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _assignments(courseId).doc(assignmentId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Assignment not found.');
        }
        if (snapshot.data()?['teacherId']?.toString() != teacherId) {
          throw StateError('Only the assignment teacher can update it.');
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
        'Failed to update assignment status: ${e.toString()}',
      );
    }
  }

  int _calculatedTotal(McqAssignmentModel assignment) {
    return assignment.questions.fold<int>(
      0,
      (total, question) => total + question.marksPerQuestion,
    );
  }

  @override
  Future<String> createProjectAssignment(
    ProjectAssignmentModel assignment,
  ) async {
    try {
      final docRef = assignment.assignmentId.isEmpty
          ? _assignments(assignment.courseId).doc()
          : _assignments(assignment.courseId).doc(assignment.assignmentId);
      final now = DateTime.now();
      await docRef.set(
        assignment
            .copyWith(
              assignmentId: docRef.id,
              status: AssignmentStatus.draft,
              createdAt: now,
              updatedAt: now,
            )
            .toJson(),
      );
      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to create project assignment: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> updateProjectAssignment(
    ProjectAssignmentModel assignment,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _assignments(
          assignment.courseId,
        ).doc(assignment.assignmentId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Project assignment not found.');
        }
        if (snapshot.data()?['teacherId']?.toString() != assignment.teacherId) {
          throw StateError('Only the assignment teacher can edit it.');
        }
        transaction.update(
          docRef,
          assignment.copyWith(updatedAt: DateTime.now()).toJson(),
        );
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update project assignment: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> publishProjectAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  }) {
    return _updateStatus(
      courseId: courseId,
      assignmentId: assignmentId,
      teacherId: teacherId,
      status: AssignmentStatus.published,
    );
  }

  @override
  Future<void> archiveProjectAssignment({
    required String courseId,
    required String assignmentId,
    required String teacherId,
  }) {
    return _updateStatus(
      courseId: courseId,
      assignmentId: assignmentId,
      teacherId: teacherId,
      status: AssignmentStatus.archived,
    );
  }

  @override
  Future<ProjectAssignmentModel?> getProjectAssignment({
    required String courseId,
    required String assignmentId,
  }) async {
    try {
      final snapshot = await _assignments(courseId).doc(assignmentId).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      if (snapshot.data()?['type'] != 'project') return null;
      return ProjectAssignmentModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to load project assignment: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<ProjectAssignmentModel>> watchTeacherProjectAssignments(
    String courseId,
  ) {
    return _assignments(
      courseId,
    ).where('type', isEqualTo: 'project').snapshots().map((snapshot) {
      final assignments = snapshot.docs
          .map((doc) => ProjectAssignmentModel.fromFirestore(doc))
          .toList();
      assignments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return assignments;
    });
  }

  @override
  @override
  Future<int> countPublishedProjectAssignmentsInCourse(String courseId) async {
    try {
      final snapshot = await _assignments(courseId)
          .where('type', isEqualTo: 'project')
          .where('status', isEqualTo: AssignmentStatus.published)
          .count()
          .get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to count project assignments: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<ProjectAssignmentModel>> watchPublishedProjectAssignments(
    String courseId,
  ) {
    return _assignments(courseId)
        .where('type', isEqualTo: 'project')
        .where('status', isEqualTo: AssignmentStatus.published)
        .snapshots()
        .map((snapshot) {
          final assignments = snapshot.docs
              .map((doc) => ProjectAssignmentModel.fromFirestore(doc))
              .toList();
          assignments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return assignments;
        });
  }

  @override
  Stream<ProjectSubmissionModel?> watchProjectSubmission({
    required String courseId,
    required String assignmentId,
    required String studentId,
  }) {
    return _submissionRef(
      courseId: courseId,
      assignmentId: assignmentId,
      studentId: studentId,
    ).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ProjectSubmissionModel.fromFirestore(snapshot);
    });
  }

  @override
  Stream<List<ProjectSubmissionModel>> watchProjectSubmissions({
    required String courseId,
    required String assignmentId,
  }) {
    return _assignments(
      courseId,
    ).doc(assignmentId).collection('submissions').snapshots().map((snapshot) {
      final submissions = snapshot.docs
          .map((doc) => ProjectSubmissionModel.fromFirestore(doc))
          .toList();
      submissions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return submissions;
    });
  }

  @override
  Future<void> submitProject({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String projectDescription,
    required String githubLink,
    required String liveDemoLink,
    required String additionalNotes,
  }) async {
    if (projectDescription.trim().isEmpty ||
        (githubLink.trim().isEmpty && liveDemoLink.trim().isEmpty)) {
      throw const FirestoreException(
        'Add a project description and at least one project link.',
      );
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final enrollment = await transaction.get(
          _enrollmentRef(courseId: courseId, studentId: studentId),
        );
        if (!enrollment.exists) {
          throw StateError('Enroll in this course before submitting.');
        }

        final assignmentSnapshot = await transaction.get(
          _assignments(courseId).doc(assignmentId),
        );
        if (!assignmentSnapshot.exists || assignmentSnapshot.data() == null) {
          throw StateError('Project assignment not found.');
        }
        final assignment = ProjectAssignmentModel.fromFirestore(
          assignmentSnapshot,
        );
        if (!assignment.isPublished) {
          throw StateError('Project assignment is not published.');
        }

        final now = DateTime.now();
        transaction.set(
          _submissionRef(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
          ),
          ProjectSubmissionModel(
            assignmentId: assignmentId,
            courseId: courseId,
            studentId: studentId,
            teacherId: assignment.teacherId,
            projectDescription: projectDescription.trim(),
            githubLink: githubLink.trim(),
            liveDemoLink: liveDemoLink.trim(),
            additionalNotes: additionalNotes.trim(),
            status: ProjectSubmissionStatus.submitted,
            submittedAt: now,
            updatedAt: now,
            marks: 0,
            maxMarks: assignment.maxMarks,
            percentage: 0,
            feedback: '',
          ).toJson(),
          SetOptions(merge: true),
        );
      });
      await _syncCourseProgress(courseId: courseId, studentId: studentId);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to submit project: ${e.toString()}');
    }
  }

  @override
  Future<void> reviewProjectSubmission({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String teacherId,
    required String status,
    required int marks,
    required String feedback,
  }) async {
    if (!ProjectSubmissionStatus.values.contains(status)) {
      throw const FirestoreException('Invalid project review status.');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final assignmentSnapshot = await transaction.get(
          _assignments(courseId).doc(assignmentId),
        );
        if (!assignmentSnapshot.exists || assignmentSnapshot.data() == null) {
          throw StateError('Project assignment not found.');
        }
        final assignment = ProjectAssignmentModel.fromFirestore(
          assignmentSnapshot,
        );
        if (assignment.teacherId != teacherId) {
          throw StateError('Only the assignment teacher can review projects.');
        }

        final submissionRef = _submissionRef(
          courseId: courseId,
          assignmentId: assignmentId,
          studentId: studentId,
        );
        final submissionSnapshot = await transaction.get(submissionRef);
        if (!submissionSnapshot.exists || submissionSnapshot.data() == null) {
          throw StateError('Submission not found.');
        }

        final safeMarks = marks.clamp(0, assignment.maxMarks).toInt();
        final percentage = assignment.maxMarks == 0
            ? 0.0
            : (safeMarks / assignment.maxMarks) * 100;
        final now = DateTime.now();
        transaction.update(submissionRef, {
          'status': status,
          'marks': safeMarks,
          'maxMarks': assignment.maxMarks,
          'percentage': percentage.clamp(0, 100),
          'feedback': feedback.trim(),
          'updatedAt': Timestamp.fromDate(now),
          if (status == ProjectSubmissionStatus.graded)
            'gradedAt': Timestamp.fromDate(now),
          'progressReady': status == ProjectSubmissionStatus.graded,
          'skillScoreReady': status == ProjectSubmissionStatus.graded,
          'certificateReady': status == ProjectSubmissionStatus.graded,
          'resumeBuilderReady': status == ProjectSubmissionStatus.graded,
        });
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to review project: ${e.toString()}');
    }
  }
}
