import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../models/student_model.dart';
import '../../../../models/user_model.dart';
import '../models/certificate_model.dart';
import '../models/course_model.dart';
import '../models/grand_test_attempt_model.dart';
import '../models/grand_test_model.dart';
import '../models/mcq_assignment_model.dart';
import '../models/project_submission_model.dart';
import '../models/skill_score_model.dart';
import '../models/smart_resume_model.dart';

class ResumeIntelligenceService {
  const ResumeIntelligenceService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection('students');

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection('courses');

  CollectionReference<Map<String, dynamic>> get _enrollments =>
      _firestore.collection('enrollments');

  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection('certificates');

  DocumentReference<Map<String, dynamic>> _resumeRef(String studentId) {
    return _firestore.collection('smartResumes').doc(studentId);
  }

  CollectionReference<Map<String, dynamic>> _skillScores(String studentId) {
    return _firestore
        .collection('skillScores')
        .doc(studentId)
        .collection('skills');
  }

  Stream<SmartResumeModel?> watchResume(String studentId) {
    return _resumeRef(studentId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return SmartResumeModel.fromFirestore(snapshot);
    });
  }

  Future<SmartResumeModel> generateResume(String studentId) async {
    try {
      final user = await _loadUser(studentId);
      final student = await _loadStudent(studentId);
      final skills = await _loadVerifiedSkills(studentId);
      final certificates = await _loadCertificates(studentId);
      final courses = await _loadEnrolledCourses(studentId);
      final projects = await _loadProjects(studentId, courses);
      final grandTests = await _loadPassedGrandTests(studentId, courses);
      final achievements = _buildAchievements(
        skills: skills,
        certificates: certificates,
        grandTests: grandTests,
      );
      final strengths = _buildStrengths(
        skills: skills,
        certificates: certificates,
        projects: projects,
      );
      final improvementAreas = _buildImprovementAreas(
        user: user,
        skills: skills,
        certificates: certificates,
        projects: projects,
        grandTests: grandTests,
      );
      final now = DateTime.now();

      final resume = SmartResumeModel(
        resumeId: studentId,
        studentId: studentId,
        headline: _headline(student, skills),
        summary: _summary(user, student, skills, certificates, projects),
        careerGoal: student?.careerGoal.trim() ?? '',
        education: _education(student),
        verifiedSkills: skills,
        certificates: certificates,
        projects: projects,
        achievements: achievements,
        strengths: strengths,
        improvementAreas: improvementAreas,
        resumeScore: _resumeScore(
          user: user,
          skills: skills,
          certificates: certificates,
          projects: projects,
          grandTests: grandTests,
        ),
        lastGeneratedAt: now,
        updatedAt: now,
      );

      await _resumeRef(studentId).set(resume.toJson(), SetOptions(merge: true));
      return resume;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        'Failed to generate smart resume: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> _loadUser(String studentId) async {
    final snapshot = await _users.doc(studentId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserModel.fromFirestore(snapshot);
  }

  Future<StudentModel?> _loadStudent(String studentId) async {
    final snapshot = await _students.doc(studentId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return StudentModel.fromFirestore(snapshot);
  }

  Future<List<ResumeSkill>> _loadVerifiedSkills(String studentId) async {
    final snapshot = await _skillScores(studentId).get();
    final skills =
        snapshot.docs
            .map((doc) => SkillScoreModel.fromFirestore(doc))
            .map(
              (score) => ResumeSkill(
                skillName: score.skillName,
                score: score.score,
                level: score.level,
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return skills;
  }

  Future<List<ResumeCertificate>> _loadCertificates(String studentId) async {
    final snapshot = await _certificates
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: CertificateStatus.active)
        .get();
    final certificates =
        snapshot.docs
            .map((doc) => CertificateModel.fromFirestore(doc))
            .map(
              (certificate) => ResumeCertificate(
                certificateId: certificate.certificateId,
                title: certificate.title,
                courseTitle: certificate.courseTitle,
                certificateType: certificate.typeLabel,
                score: certificate.finalScore,
                issuedAt: certificate.issuedAt,
                verificationCode: certificate.verificationCode,
              ),
            )
            .toList()
          ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return certificates;
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

  Future<List<ResumeProject>> _loadProjects(
    String studentId,
    List<CourseModel> courses,
  ) async {
    final projects = <ResumeProject>[];
    for (final course in courses) {
      final assignments = await _courses
          .doc(course.id)
          .collection('assignments')
          .where('type', isEqualTo: 'project')
          .where('status', isEqualTo: AssignmentStatus.published)
          .get();

      for (final assignment in assignments.docs) {
        final submissionSnapshot = await assignment.reference
            .collection('submissions')
            .doc(studentId)
            .get();
        if (!submissionSnapshot.exists || submissionSnapshot.data() == null) {
          continue;
        }
        final submission = ProjectSubmissionModel.fromFirestore(
          submissionSnapshot,
        );
        if (!submission.isGraded) continue;

        final assignmentData = assignment.data();
        final title = _stringValue(
          assignmentData['title'],
          'Project in ${course.title}',
        );
        projects.add(
          ResumeProject(
            assignmentId: assignment.id,
            courseId: course.id,
            title: title,
            description: submission.projectDescription.isNotEmpty
                ? submission.projectDescription
                : _stringValue(assignmentData['description']),
            githubLink: submission.githubLink,
            liveDemoLink: submission.liveDemoLink,
            score: submission.percentage,
            feedback: submission.feedback,
            skills: _stringList(assignmentData['skillsCovered']).isNotEmpty
                ? _stringList(assignmentData['skillsCovered'])
                : course.skillsCovered,
          ),
        );
      }
    }
    projects.sort((a, b) => b.score.compareTo(a.score));
    return projects;
  }

  Future<List<_GrandTestResumeEvidence>> _loadPassedGrandTests(
    String studentId,
    List<CourseModel> courses,
  ) async {
    final grandTests = <_GrandTestResumeEvidence>[];
    for (final course in courses) {
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
        final passed = attempts.docs
            .map((doc) => GrandTestAttemptModel.fromFirestore(doc))
            .where((attempt) => attempt.isSubmitted && attempt.passed)
            .toList();
        if (passed.isEmpty) continue;
        final best = passed.reduce(
          (a, b) => a.percentage >= b.percentage ? a : b,
        );
        grandTests.add(
          _GrandTestResumeEvidence(
            title: test.title,
            courseTitle: course.title,
            score: best.percentage,
            skills: test.skillsCovered,
          ),
        );
      }
    }
    grandTests.sort((a, b) => b.score.compareTo(a.score));
    return grandTests;
  }

  List<ResumeAchievement> _buildAchievements({
    required List<ResumeSkill> skills,
    required List<ResumeCertificate> certificates,
    required List<_GrandTestResumeEvidence> grandTests,
  }) {
    final achievements = <ResumeAchievement>[];
    for (final certificate in certificates.take(4)) {
      achievements.add(
        ResumeAchievement(
          title: certificate.title,
          description:
              '${certificate.courseTitle} • ${certificate.score.toStringAsFixed(0)}% • ${certificate.verificationCode}',
        ),
      );
    }
    for (final skill in skills.where((skill) => skill.score >= 85).take(3)) {
      achievements.add(
        ResumeAchievement(
          title: '${skill.level} in ${skill.skillName}',
          description:
              'Verified skill score of ${skill.score.toStringAsFixed(0)}%.',
        ),
      );
    }
    for (final test in grandTests.take(2)) {
      achievements.add(
        ResumeAchievement(
          title: 'Passed ${test.title}',
          description:
              '${test.courseTitle} Grand Test with ${test.score.toStringAsFixed(0)}%.',
        ),
      );
    }
    return achievements;
  }

  List<String> _buildStrengths({
    required List<ResumeSkill> skills,
    required List<ResumeCertificate> certificates,
    required List<ResumeProject> projects,
  }) {
    final strengths = <String>[];
    for (final skill in skills.take(3)) {
      strengths.add(
        '${skill.level} ${skill.skillName} knowledge verified at ${skill.score.toStringAsFixed(0)}%.',
      );
    }
    if (projects.isNotEmpty) {
      strengths.add(
        'Completed ${projects.length} graded project${projects.length == 1 ? '' : 's'} with verified feedback.',
      );
    }
    if (certificates.isNotEmpty) {
      strengths.add(
        'Earned ${certificates.length} active certificate${certificates.length == 1 ? '' : 's'}.',
      );
    }
    return strengths;
  }

  List<String> _buildImprovementAreas({
    required UserModel? user,
    required List<ResumeSkill> skills,
    required List<ResumeCertificate> certificates,
    required List<ResumeProject> projects,
    required List<_GrandTestResumeEvidence> grandTests,
  }) {
    final areas = <String>[];
    if ((user?.profileCompleted ?? 0) < 100) {
      areas.add('Complete profile information to improve resume trust.');
    }
    if (skills.length < 3) {
      areas.add('Complete more assessments to verify at least three skills.');
    }
    if (projects.isEmpty) {
      areas.add('Submit and get a project graded to add portfolio evidence.');
    }
    if (certificates.isEmpty) {
      areas.add('Earn a certificate by completing a course and Grand Test.');
    }
    if (grandTests.isEmpty) {
      areas.add('Pass a Grand Test to strengthen final assessment evidence.');
    }
    final lowSkill = skills.where((skill) => skill.score < 70).take(1);
    for (final skill in lowSkill) {
      areas.add('Improve ${skill.skillName} score toward Advanced level.');
    }
    return areas;
  }

  String _headline(StudentModel? student, List<ResumeSkill> skills) {
    final careerGoal = student?.careerGoal.trim() ?? '';
    if (careerGoal.isNotEmpty) return careerGoal;
    if (skills.isNotEmpty) {
      return 'Aspiring ${skills.first.skillName} Developer';
    }
    return 'Aspiring Technology Professional';
  }

  String _summary(
    UserModel? user,
    StudentModel? student,
    List<ResumeSkill> skills,
    List<ResumeCertificate> certificates,
    List<ResumeProject> projects,
  ) {
    final parts = <String>[];
    final name = user?.fullName.trim();
    final topSkills = skills.take(3).map((skill) => skill.skillName).toList();
    if (topSkills.isNotEmpty) {
      parts.add('verified skills in ${topSkills.join(', ')}');
    }
    if (certificates.isNotEmpty) {
      parts.add(
        '${certificates.length} active certificate${certificates.length == 1 ? '' : 's'}',
      );
    }
    if (projects.isNotEmpty) {
      parts.add(
        '${projects.length} graded project${projects.length == 1 ? '' : 's'}',
      );
    }
    final education = _education(student);
    final intro = name == null || name.isEmpty ? 'Student' : name;
    if (parts.isEmpty) {
      return '$intro is building verified LMS evidence through courses, assignments, projects, and Grand Tests.';
    }
    return '$intro has ${parts.join(', ')} based on completed LMS assessments. ${education.isNotEmpty ? 'Education: $education.' : ''}';
  }

  String _education(StudentModel? student) {
    if (student == null) return '';
    final parts = [
      student.educationLevel,
      student.degree,
      student.fieldOfStudy,
      student.institute,
      if (student.graduationYear > 0) student.graduationYear.toString(),
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    return parts.join(' • ');
  }

  double _resumeScore({
    required UserModel? user,
    required List<ResumeSkill> skills,
    required List<ResumeCertificate> certificates,
    required List<ResumeProject> projects,
    required List<_GrandTestResumeEvidence> grandTests,
  }) {
    final profileScore =
        ((user?.profileCompleted ?? 0).clamp(0, 100) / 100) * 20;
    final skillAverage = skills.isEmpty
        ? 0.0
        : skills.map((skill) => skill.score).reduce((a, b) => a + b) /
              skills.length;
    final skillScore = (skillAverage / 100) * 30;
    final certificateScore = (certificates.length / 2).clamp(0, 1) * 20;
    final projectAverage = projects.isEmpty
        ? 0.0
        : projects.map((project) => project.score).reduce((a, b) => a + b) /
              projects.length;
    final projectScore = (projectAverage / 100) * 20;
    final grandTestAverage = grandTests.isEmpty
        ? 0.0
        : grandTests.map((test) => test.score).reduce((a, b) => a + b) /
              grandTests.length;
    final grandTestScore = (grandTestAverage / 100) * 10;
    return (profileScore +
            skillScore +
            certificateScore +
            projectScore +
            grandTestScore)
        .clamp(0, 100)
        .toDouble();
  }
}

class _GrandTestResumeEvidence {
  const _GrandTestResumeEvidence({
    required this.title,
    required this.courseTitle,
    required this.score,
    required this.skills,
  });

  final String title;
  final String courseTitle;
  final double score;
  final List<String> skills;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
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
