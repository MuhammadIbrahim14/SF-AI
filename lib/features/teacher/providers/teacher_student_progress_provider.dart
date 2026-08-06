import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../data/models/teacher_student_progress_model.dart';

final teacherStudentProgressProvider =
    FutureProvider<List<TeacherStudentProgressModel>>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const <TeacherStudentProgressModel>[];

      return TeacherStudentProgressService(
        ref.watch(firestoreProvider),
      ).loadProgress(user.uid);
    });

final teacherStudentProgressDetailProvider =
    FutureProvider.family<TeacherStudentProgressDetailModel?, String>((
      ref,
      studentId,
    ) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return null;

      final service = TeacherStudentProgressService(
        ref.watch(firestoreProvider),
      );
      final records = await ref.watch(teacherStudentProgressProvider.future);
      final studentRecords = records
          .where((item) => item.studentId == studentId)
          .toList();
      if (studentRecords.isEmpty) return null;

      final skills = await service.loadSkillScores(studentId);
      return TeacherStudentProgressDetailModel(
        studentId: studentId,
        studentName: studentRecords.first.studentName,
        studentEmail: studentRecords.first.studentEmail,
        records: studentRecords,
        skillScores: skills,
      );
    });

class TeacherStudentProgressService {
  const TeacherStudentProgressService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<TeacherStudentProgressModel>> loadProgress(
    String teacherId,
  ) async {
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
            .collectionGroup('submissions')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('attempts')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collectionGroup('grandTests')
            .where('teacherId', isEqualTo: teacherId),
      ),
      _safeGet(
        _firestore
            .collection('certificates')
            .where('teacherId', isEqualTo: teacherId),
      ),
    ]);

    final courses = {for (final doc in _docs(results[0])) doc.id: doc.data()};
    final enrollments = _docs(results[1]);
    final assignments = _docs(results[2]);
    final submissions = _docs(results[3]);
    final attempts = _docs(results[4]);
    final grandTests = _docs(results[5]);
    final certificates = _docs(results[6]);

    final studentIds = enrollments
        .map((doc) => _string(doc.data()['studentId']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final users = await _loadUsers(studentIds);

    final publishedAssignmentsByCourse =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final assignment in assignments) {
      final data = assignment.data();
      if (_status(data['status']) != 'published') continue;
      final courseId = _string(data['courseId']);
      if (courseId.isEmpty) continue;
      publishedAssignmentsByCourse
          .putIfAbsent(courseId, () => [])
          .add(assignment);
    }

    final publishedGrandTestsByCourse =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final test in grandTests) {
      final data = test.data();
      if (_status(data['status']) != 'published') continue;
      final courseId = _string(data['courseId']);
      if (courseId.isEmpty) continue;
      publishedGrandTestsByCourse.putIfAbsent(courseId, () => []).add(test);
    }

    final records = <TeacherStudentProgressModel>[];
    for (final enrollment in enrollments) {
      final data = enrollment.data();
      final studentId = _string(data['studentId']);
      final courseId = _string(data['courseId']);
      if (studentId.isEmpty || courseId.isEmpty) continue;

      final course = courses[courseId] ?? const <String, dynamic>{};
      final user = users[studentId] ?? const <String, dynamic>{};
      final studentName = _label(
        user['fullName'],
        _label(user['name'], 'Student'),
      );
      final studentEmail = _string(user['email'], 'No email');
      final courseTitle = _label(course['title'], 'Untitled course');

      final courseAssignments =
          publishedAssignmentsByCourse[courseId] ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final courseGrandTests =
          publishedGrandTestsByCourse[courseId] ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final studentMcqAttempts = attempts.where((doc) {
        final attempt = doc.data();
        return _string(attempt['courseId']) == courseId &&
            _string(attempt['studentId']) == studentId &&
            _string(attempt['assignmentId']).isNotEmpty &&
            _status(attempt['status']) == 'submitted';
      }).toList();

      final studentGrandAttempts = attempts.where((doc) {
        final attempt = doc.data();
        final status = _status(attempt['status']);
        return _string(attempt['courseId']) == courseId &&
            _string(attempt['studentId']) == studentId &&
            _string(attempt['grandTestId']).isNotEmpty &&
            (status == 'submitted' || status == 'auto_submitted');
      }).toList();

      final studentProjectSubmissions = submissions.where((doc) {
        final submission = doc.data();
        return _string(submission['courseId']) == courseId &&
            _string(submission['studentId']) == studentId;
      }).toList();

      final publishedProjectIds = courseAssignments
          .where((doc) => _status(doc.data()['type']) == 'project')
          .map((doc) => doc.id)
          .toSet();
      final completedProjectIds = studentProjectSubmissions
          .where((doc) {
            final status = _status(doc.data()['status']);
            return status == 'submitted' || status == 'graded';
          })
          .map((doc) => _string(doc.data()['assignmentId'], doc.id))
          .toSet();
      final completedMcqIds = studentMcqAttempts
          .map((doc) => _string(doc.data()['assignmentId']))
          .where((id) => id.isNotEmpty)
          .toSet();

      final completedAssignments = {
        ...completedMcqIds,
        ...completedProjectIds,
      }.intersection(courseAssignments.map((doc) => doc.id).toSet()).length;
      final totalAssignments = courseAssignments.length;
      final assignmentCompletion = totalAssignments == 0
          ? 0.0
          : (completedAssignments / totalAssignments * 100)
                .clamp(0, 100)
                .toDouble();

      final projectStatus = _projectStatus(
        hasProjects: publishedProjectIds.isNotEmpty,
        submissions: studentProjectSubmissions,
      );
      final grandTestStatus = _grandTestStatus(
        hasGrandTests: courseGrandTests.isNotEmpty,
        attempts: studentGrandAttempts,
      );
      final certificateStatus =
          certificates.any((doc) {
            final certificate = doc.data();
            return _string(certificate['courseId']) == courseId &&
                _string(certificate['studentId']) == studentId &&
                _status(certificate['status'], 'active') == 'active';
          })
          ? 'issued'
          : 'not_issued';

      final scores = <double>[
        ...studentMcqAttempts.map((doc) => _percent(doc.data()['percentage'])),
        ...studentProjectSubmissions
            .where((doc) => _status(doc.data()['status']) == 'graded')
            .map((doc) => _percent(doc.data()['percentage'])),
        ...studentGrandAttempts.map(
          (doc) => _percent(doc.data()['percentage']),
        ),
      ].where((score) => score > 0).toList();
      final averageScore = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      // This column tracks lesson progress, not overall course completion.
      final lessonProgress = data.containsKey('lessonProgressPercent')
          ? _percent(data['lessonProgressPercent'])
          : _percent(data['progressPercent']);
      final hasMissingProject =
          publishedProjectIds.isNotEmpty &&
          publishedProjectIds.difference(completedProjectIds).isNotEmpty;
      final hasFailedGrandTest =
          studentGrandAttempts.any((doc) => doc.data()['passed'] == false) &&
          !studentGrandAttempts.any((doc) => doc.data()['passed'] == true);
      final risk = _riskStatus(
        progress: lessonProgress,
        averageScore: averageScore,
        hasMissingProject: hasMissingProject,
        hasFailedGrandTest: hasFailedGrandTest,
      );

      records.add(
        TeacherStudentProgressModel(
          studentId: studentId,
          studentName: studentName,
          studentEmail: studentEmail,
          courseId: courseId,
          courseTitle: courseTitle,
          lessonProgress: lessonProgress,
          completedLessons: _int(data['completedLessons']),
          totalLessons: _int(data['totalLessons']),
          assignmentCompletion: assignmentCompletion,
          completedAssignments: completedAssignments,
          totalAssignments: totalAssignments,
          projectStatus: projectStatus,
          grandTestStatus: grandTestStatus,
          certificateStatus: certificateStatus,
          averageScore: averageScore.clamp(0, 100).toDouble(),
          riskStatus: risk.status,
          riskReasons: risk.reasons,
        ),
      );
    }

    records.sort((a, b) {
      final riskCompare = _riskRank(
        b.riskStatus,
      ).compareTo(_riskRank(a.riskStatus));
      if (riskCompare != 0) return riskCompare;
      return a.studentName.compareTo(b.studentName);
    });
    return records;
  }

  Future<List<TeacherStudentSkillSnapshot>> loadSkillScores(
    String studentId,
  ) async {
    final snapshot = await _safeGet(
      _firestore.collection('skillScores').doc(studentId).collection('skills'),
    );
    final skills = _docs(snapshot).map((doc) {
      final data = doc.data();
      return TeacherStudentSkillSnapshot(
        skillName: _label(data['skillName'], doc.id),
        score: _percent(data['score']),
        level: _label(data['level'], 'Beginner'),
      );
    }).toList();
    skills.sort((a, b) => b.score.compareTo(a.score));
    return skills;
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsers(
    List<String> studentIds,
  ) async {
    if (studentIds.isEmpty) return const <String, Map<String, dynamic>>{};
    final users = <String, Map<String, dynamic>>{};
    for (var index = 0; index < studentIds.length; index += 10) {
      final chunk = studentIds.skip(index).take(10).toList();
      final snapshot = await _safeGet(
        _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk),
      );
      for (final doc in _docs(snapshot)) {
        users[doc.id] = doc.data();
      }
    }
    return users;
  }

  String _projectStatus({
    required bool hasProjects,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions,
  }) {
    if (!hasProjects) return 'not_required';
    if (submissions.any((doc) => _status(doc.data()['status']) == 'graded')) {
      return 'graded';
    }
    if (submissions.any(
      (doc) => _status(doc.data()['status']) == 'submitted',
    )) {
      return 'submitted';
    }
    if (submissions.any(
      (doc) => _status(doc.data()['status']) == 'changes_requested',
    )) {
      return 'changes_requested';
    }
    if (submissions.any((doc) => _status(doc.data()['status']) == 'rejected')) {
      return 'rejected';
    }
    return 'missing';
  }

  String _grandTestStatus({
    required bool hasGrandTests,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  }) {
    if (!hasGrandTests) return 'not_available';
    if (attempts.any((doc) => doc.data()['passed'] == true)) return 'passed';
    if (attempts.any((doc) => doc.data()['passed'] == false)) return 'failed';
    return 'not_attempted';
  }

  _RiskResult _riskStatus({
    required double progress,
    required double averageScore,
    required bool hasMissingProject,
    required bool hasFailedGrandTest,
  }) {
    final reasons = <String>[];
    if (progress < 40) reasons.add('Lesson progress is below 40%.');
    if (averageScore < 50) reasons.add('Average score is below 50%.');
    if (hasMissingProject) reasons.add('Project submission is missing.');
    if (hasFailedGrandTest) reasons.add('Grand test is failed.');
    if (reasons.isNotEmpty) {
      return _RiskResult(TeacherProgressRisk.atRisk, reasons);
    }

    if (progress < 70 || averageScore < 70) {
      if (progress < 70) reasons.add('Lesson progress needs a push.');
      if (averageScore < 70) reasons.add('Average score needs attention.');
      return _RiskResult(TeacherProgressRisk.needsAttention, reasons);
    }

    return const _RiskResult(TeacherProgressRisk.healthy, ['On track.']);
  }

  int _riskRank(String status) {
    return switch (status) {
      TeacherProgressRisk.atRisk => 3,
      TeacherProgressRisk.needsAttention => 2,
      _ => 1,
    };
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs(Object? value) {
    final snapshot = value as QuerySnapshot<Map<String, dynamic>>?;
    return snapshot?.docs.toList() ??
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

class _RiskResult {
  const _RiskResult(this.status, this.reasons);

  final String status;
  final List<String> reasons;
}

String _string(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

String _label(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _status(Object? value, [String fallback = '']) {
  return (value?.toString() ?? fallback).trim().toLowerCase();
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _percent(Object? value) {
  if (value is num) return value.toDouble().clamp(0, 100).toDouble();
  if (value is String) {
    return (double.tryParse(value) ?? 0).clamp(0, 100).toDouble();
  }
  return 0;
}
