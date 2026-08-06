import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../models/certificate_model.dart';
import '../models/course_model.dart';
import '../models/grand_test_attempt_model.dart';
import '../models/grand_test_model.dart';
import '../models/mcq_assignment_model.dart';
import '../models/mcq_attempt_model.dart';
import '../models/project_submission_model.dart';
import '../models/skill_score_model.dart';

const double _mcqWeight = 0.30;
const double _projectWeight = 0.30;
const double _grandTestWeight = 0.30;
const double _certificateWeight = 0.10;

class SkillScoreService {
  const SkillScoreService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection('courses');

  CollectionReference<Map<String, dynamic>> get _enrollments =>
      _firestore.collection('enrollments');

  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection('certificates');

  CollectionReference<Map<String, dynamic>> _studentScores(String studentId) {
    return _firestore
        .collection('skillScores')
        .doc(studentId)
        .collection('skills');
  }

  Stream<List<SkillScoreModel>> watchStudentSkillScores(String studentId) {
    return _studentScores(studentId).snapshots().map((snapshot) {
      final scores = snapshot.docs
          .map((doc) => SkillScoreModel.fromFirestore(doc))
          .toList();
      scores.sort((a, b) => b.score.compareTo(a.score));
      return scores;
    });
  }

  Stream<SkillScoreModel?> watchSkillScore({
    required String studentId,
    required String skillName,
  }) {
    return _studentScores(
      studentId,
    ).doc(normalizeSkillId(skillName)).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return SkillScoreModel.fromFirestore(snapshot);
    });
  }

  Future<List<SkillScoreModel>> recalculateStudentSkillScores(
    String studentId,
  ) async {
    try {
      final buckets = <String, _SkillEvidenceBucket>{};
      final enrolledCourses = await _loadEnrolledCourses(studentId);

      for (final course in enrolledCourses) {
        await _collectMcqEvidence(
          studentId: studentId,
          course: course,
          buckets: buckets,
        );
        await _collectProjectEvidence(
          studentId: studentId,
          course: course,
          buckets: buckets,
        );
        await _collectGrandTestEvidence(
          studentId: studentId,
          course: course,
          buckets: buckets,
        );
      }

      await _collectCertificateEvidence(studentId: studentId, buckets: buckets);

      final now = DateTime.now();
      final scores =
          buckets.values
              .map((bucket) => bucket.toModel(studentId: studentId, now: now))
              .where((score) => score.score > 0 || score.sourceCourses.isNotEmpty)
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));

      final batch = _firestore.batch();
      final scoreCollection = _studentScores(studentId);
      final existing = await scoreCollection.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
      for (final score in scores) {
        batch.set(scoreCollection.doc(score.skillScoreId), score.toJson());
      }
      await batch.commit();
      return scores;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        'Failed to recalculate skill scores: ${e.toString()}',
      );
    }
  }

  Future<List<CourseModel>> _loadEnrolledCourses(String studentId) async {
    final enrollments = await _enrollments
        .where('studentId', isEqualTo: studentId)
        .get();
    final courseIds = enrollments.docs
        .map((doc) => _stringValue(doc.data()['courseId']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (courseIds.isEmpty) return const <CourseModel>[];

    final snapshots = await Future.wait(
      courseIds.map((id) => _courses.doc(id).get()),
    );
    final courses = <CourseModel>[];
    for (final courseSnapshot in snapshots) {
      if (!courseSnapshot.exists || courseSnapshot.data() == null) continue;
      courses.add(CourseModel.fromFirestore(courseSnapshot));
    }
    return courses;
  }

  Future<void> _collectMcqEvidence({
    required String studentId,
    required CourseModel course,
    required Map<String, _SkillEvidenceBucket> buckets,
  }) async {
    final assignments = await _courses
        .doc(course.id)
        .collection('assignments')
        .where('type', isEqualTo: 'mcq')
        .where('status', isEqualTo: AssignmentStatus.published)
        .get();

    for (final assignmentDoc in assignments.docs) {
      final attempt = await assignmentDoc.reference
          .collection('attempts')
          .doc(studentId)
          .get();
      final data = attempt.data();
      if (!attempt.exists || data?['status'] != McqAttemptStatus.submitted) {
        continue;
      }

      final assignment = McqAssignmentModel.fromFirestore(assignmentDoc);
      final skills = _skillsOrFallback(assignment.skillsCovered, course);
      if (skills.isEmpty) continue;
      final score = _doubleValue(data?['percentage']).clamp(0, 100).toDouble();
      for (final skill in skills) {
        _bucket(buckets, skill).addMcq(
          score: score,
          course: course,
          assignmentId: assignment.assignmentId,
          assignmentTitle: assignment.title.trim().isEmpty
              ? 'MCQ Assignment'
              : assignment.title.trim(),
        );
      }
    }
  }

  Future<void> _collectProjectEvidence({
    required String studentId,
    required CourseModel course,
    required Map<String, _SkillEvidenceBucket> buckets,
  }) async {
    final assignments = await _courses
        .doc(course.id)
        .collection('assignments')
        .where('type', isEqualTo: 'project')
        .where('status', isEqualTo: AssignmentStatus.published)
        .get();

    for (final assignmentDoc in assignments.docs) {
      final submission = await assignmentDoc.reference
          .collection('submissions')
          .doc(studentId)
          .get();
      final data = submission.data();
      if (!submission.exists ||
          ProjectSubmissionStatus.normalize(data?['status']?.toString()) !=
              ProjectSubmissionStatus.graded) {
        continue;
      }

      final assignmentSkills = _stringList(
        assignmentDoc.data()['skillsCovered'],
      );
      final skills = _skillsOrFallback(assignmentSkills, course);
      if (skills.isEmpty) continue;
      final title = _stringValue(assignmentDoc.data()['title'], 'Project');
      final score = _doubleValue(data?['percentage']).clamp(0, 100).toDouble();
      for (final skill in skills) {
        _bucket(buckets, skill).addProject(
          score: score,
          course: course,
          assignmentId: assignmentDoc.id,
          assignmentTitle: title,
        );
      }
    }
  }

  Future<void> _collectGrandTestEvidence({
    required String studentId,
    required CourseModel course,
    required Map<String, _SkillEvidenceBucket> buckets,
  }) async {
    final tests = await _courses
        .doc(course.id)
        .collection('grandTests')
        .where('status', isEqualTo: AssignmentStatus.published)
        .get();

    for (final testDoc in tests.docs) {
      final test = GrandTestModel.fromFirestore(testDoc);
      final attempts = await testDoc.reference
          .collection('attempts')
          .where('studentId', isEqualTo: studentId)
          .get();
      final submittedAttempts = attempts.docs
          .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
          .where((attempt) => attempt.isSubmitted)
          .toList();
      if (submittedAttempts.isEmpty) continue;

      final bestAttempt = submittedAttempts.reduce(
        (a, b) => a.percentage >= b.percentage ? a : b,
      );
      final skills = _skillsOrFallback(_grandTestSkills(test), course);
      if (skills.isEmpty) continue;
      for (final skill in skills) {
        _bucket(buckets, skill).addGrandTest(
          score: bestAttempt.percentage.clamp(0, 100).toDouble(),
          course: course,
          grandTestId: test.grandTestId,
          grandTestTitle:
              test.title.trim().isEmpty ? 'Grand Test' : test.title.trim(),
        );
      }
    }
  }

  Future<void> _collectCertificateEvidence({
    required String studentId,
    required Map<String, _SkillEvidenceBucket> buckets,
  }) async {
    final certificates = await _certificates
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: CertificateStatus.active)
        .get();

    for (final certificateDoc in certificates.docs) {
      final certificate = CertificateModel.fromFirestore(certificateDoc);
      final courseSnapshot = await _courses.doc(certificate.courseId).get();
      if (!courseSnapshot.exists || courseSnapshot.data() == null) continue;
      final course = CourseModel.fromFirestore(courseSnapshot);
      final skills = _skillsOrFallback(course.skillsCovered, course);
      if (skills.isEmpty) continue;
      for (final skill in skills) {
        _bucket(buckets, skill).addCertificate(
          course: course,
          certificateId: certificate.certificateId,
          certificateTitle: certificate.title.trim().isNotEmpty
              ? certificate.title.trim()
              : (certificate.courseTitle.trim().isNotEmpty
                  ? certificate.courseTitle.trim()
                  : 'Certificate'),
        );
      }
    }
  }

  List<String> _grandTestSkills(GrandTestModel test) {
    final skills = <String>{...test.skillsCovered};
    for (final question in test.questions) {
      if (question.skillTag.trim().isNotEmpty) skills.add(question.skillTag);
    }
    return skills.toList();
  }

  /// Prefer assignment skills → course.skillsCovered → skip (no fake category skill).
  List<String> _skillsOrFallback(List<String> skills, CourseModel course) {
    final normalized = skills
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();
    if (normalized.isNotEmpty) return normalized;
    return course.skillsCovered
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();
  }

  _SkillEvidenceBucket _bucket(
    Map<String, _SkillEvidenceBucket> buckets,
    String skill,
  ) {
    final displayName = skill.trim();
    final id = normalizeSkillId(displayName);
    return buckets.putIfAbsent(
      id,
      () => _SkillEvidenceBucket(skillScoreId: id, skillName: displayName),
    );
  }
}

String normalizeSkillId(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'general' : normalized;
}

class _SkillEvidenceBucket {
  _SkillEvidenceBucket({required this.skillScoreId, required this.skillName});

  final String skillScoreId;
  final String skillName;
  final List<double> mcqScores = <double>[];
  final List<double> projectScores = <double>[];
  final List<double> grandTestScores = <double>[];
  final Map<String, SkillSourceRef> courses = <String, SkillSourceRef>{};
  final Map<String, SkillSourceRef> assignments = <String, SkillSourceRef>{};
  final Map<String, SkillSourceRef> grandTests = <String, SkillSourceRef>{};
  final Map<String, SkillSourceRef> certificates = <String, SkillSourceRef>{};

  void _rememberCourse(CourseModel course) {
    final title = course.title.trim().isEmpty ? 'Untitled Course' : course.title.trim();
    courses[course.id] = SkillSourceRef(
      id: course.id,
      title: title,
      subtitle: course.category.trim(),
      courseId: course.id,
      courseTitle: title,
    );
  }

  void addMcq({
    required double score,
    required CourseModel course,
    required String assignmentId,
    required String assignmentTitle,
  }) {
    mcqScores.add(score);
    _rememberCourse(course);
    assignments[assignmentId] = SkillSourceRef(
      id: assignmentId,
      title: assignmentTitle,
      subtitle: 'MCQ · ${course.title}',
      courseId: course.id,
      courseTitle: course.title,
    );
  }

  void addProject({
    required double score,
    required CourseModel course,
    required String assignmentId,
    required String assignmentTitle,
  }) {
    projectScores.add(score);
    _rememberCourse(course);
    assignments[assignmentId] = SkillSourceRef(
      id: assignmentId,
      title: assignmentTitle,
      subtitle: 'Project · ${course.title}',
      courseId: course.id,
      courseTitle: course.title,
    );
  }

  void addGrandTest({
    required double score,
    required CourseModel course,
    required String grandTestId,
    required String grandTestTitle,
  }) {
    grandTestScores.add(score);
    _rememberCourse(course);
    grandTests[grandTestId] = SkillSourceRef(
      id: grandTestId,
      title: grandTestTitle,
      subtitle: 'Grand Test · ${course.title}',
      courseId: course.id,
      courseTitle: course.title,
    );
  }

  void addCertificate({
    required CourseModel course,
    required String certificateId,
    required String certificateTitle,
  }) {
    _rememberCourse(course);
    certificates[certificateId] = SkillSourceRef(
      id: certificateId,
      title: certificateTitle,
      subtitle: course.title,
      courseId: course.id,
      courseTitle: course.title,
    );
  }

  SkillScoreModel toModel({required String studentId, required DateTime now}) {
    final mcqAverage = _average(mcqScores);
    final projectAverage = _average(projectScores);
    final grandTestAverage = _average(grandTestScores);
    final certificateBonusApplied = certificates.isNotEmpty;

    final sourceScores = <_WeightedSource>[
      if (mcqScores.isNotEmpty) _WeightedSource(mcqAverage, _mcqWeight),
      if (projectScores.isNotEmpty)
        _WeightedSource(projectAverage, _projectWeight),
      if (grandTestScores.isNotEmpty)
        _WeightedSource(grandTestAverage, _grandTestWeight),
      if (certificateBonusApplied)
        const _WeightedSource(100, _certificateWeight),
    ];

    final weightTotal = sourceScores.fold<double>(
      0,
      (total, source) => total + source.weight,
    );
    final score = weightTotal == 0
        ? 0.0
        : sourceScores.fold<double>(
                0,
                (total, source) => total + source.score * source.weight,
              ) /
              weightTotal;

    final courseList = courses.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final assignmentList = assignments.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final grandTestList = grandTests.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final certificateList = certificates.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return SkillScoreModel(
      skillScoreId: skillScoreId,
      studentId: studentId,
      skillName: skillName,
      score: score.clamp(0, 100).toDouble(),
      level: SkillLevel.fromScore(score),
      sourceCourses: courseList,
      sourceAssignments: assignmentList,
      sourceGrandTests: grandTestList,
      sourceCertificates: certificateList,
      mcqAverage: mcqAverage,
      projectAverage: projectAverage,
      grandTestAverage: grandTestAverage,
      certificateBonusApplied: certificateBonusApplied,
      lastCalculatedAt: now,
      updatedAt: now,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return (values.reduce((a, b) => a + b) / values.length)
        .clamp(0, 100)
        .toDouble();
  }
}

class _WeightedSource {
  const _WeightedSource(this.score, this.weight);

  final double score;
  final double weight;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}
