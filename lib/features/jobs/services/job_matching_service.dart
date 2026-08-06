import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/application_model.dart';
import '../../../models/freelancer_model.dart';
import '../../../models/job_match_model.dart';
import '../../../models/job_model.dart';
import '../../../models/student_model.dart';
import '../../../models/user_model.dart';

class JobMatchingService {
  const JobMatchingService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<JobMatchModel> calculateMatch({
    required JobModel job,
    required String candidateId,
    required String candidateRole,
  }) async {
    final normalizedRole = _normalizeRole(candidateRole);
    final candidate = await _loadCandidate(candidateId, normalizedRole);
    return _scoreMatch(
      job: job,
      candidateId: candidateId,
      candidateRole: candidateRole,
      candidate: candidate,
    );
  }

  JobMatchModel _scoreMatch({
    required JobModel job,
    required String candidateId,
    required String candidateRole,
    required _CandidateEvidence candidate,
  }) {
    if (!job.matchingEnabled) {
      return JobMatchModel.empty(
        job: job,
        candidateId: candidateId,
        candidateRole: candidateRole,
        reason: 'Matching is disabled for this job.',
      );
    }

    final normalizedRole = _normalizeRole(candidateRole);
    final targetRoles = job.targetRoles.map(_normalizeRole).toSet();
    if (targetRoles.isNotEmpty &&
        !targetRoles.contains('both') &&
        !targetRoles.contains(normalizedRole)) {
      return JobMatchModel.empty(
        job: job,
        candidateId: candidateId,
        candidateRole: candidateRole,
        reason: 'This job is targeted to ${job.targetRoles.join(', ')}.',
      );
    }

    final requiredSkills = job.requiredSkills.isNotEmpty
        ? job.requiredSkills
        : job.requirements;
    final preferredSkills = job.preferredSkills;
    final requiredNormalized = requiredSkills.map(normalizeSkill).toSet();
    final preferredNormalized = preferredSkills.map(normalizeSkill).toSet();
    final candidateSkillNames = candidate.skillScores.keys.toSet()
      ..addAll(candidate.profileSkills.map(normalizeSkill));

    final matchedNormalized = requiredNormalized
        .where(candidateSkillNames.contains)
        .toSet();
    final matchedPreferred = preferredNormalized
        .where(candidateSkillNames.contains)
        .toSet();
    final missingNormalized = requiredNormalized
        .where((skill) => !candidateSkillNames.contains(skill))
        .toSet();

    final requiredSkillScore = requiredNormalized.isEmpty
        ? 100.0
        : (matchedNormalized.length / requiredNormalized.length) * 100;
    final relevantSkills = <String>{...matchedNormalized, ...matchedPreferred};
    final skillScoreAverage = relevantSkills.isEmpty
        ? _average(candidate.skillScores.values)
        : _average(
            relevantSkills
                .map((skill) => candidate.skillScores[skill] ?? 0)
                .where((score) => score > 0),
          );
    final resumeScore = candidate.resumeScore;
    final certificateScore = (candidate.certificateCount / 2).clamp(0, 1) * 100;
    final projectScore = candidate.projectCount > 0
        ? (candidate.projectAverage > 0 ? candidate.projectAverage : 75.0)
        : 0.0;
    final careerGoalMatch = _careerGoalMatches(job, candidate);

    var score =
        requiredSkillScore * 0.40 +
        skillScoreAverage * 0.25 +
        resumeScore * 0.15 +
        certificateScore * 0.10 +
        projectScore * 0.05 +
        (careerGoalMatch ? 100 : 0) * 0.05;

    if (job.minimumSkillScore > 0 &&
        skillScoreAverage < job.minimumSkillScore) {
      score -= 10;
    }
    if (requiredNormalized.isNotEmpty && matchedNormalized.isEmpty) {
      score = score.clamp(0, 45).toDouble();
    }

    final matchedSkills = _displaySkills(
      [...matchedNormalized, ...matchedPreferred],
      [...requiredSkills, ...preferredSkills],
    );
    final missingSkills = _displaySkills(missingNormalized, requiredSkills);
    final finalScore = score.clamp(0, 100).toDouble();

    return JobMatchModel(
      matchId: '${job.id}_$candidateId',
      jobId: job.id,
      candidateId: candidateId,
      candidateRole: normalizedRole,
      matchScore: finalScore,
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      skillScoreAverage: skillScoreAverage.clamp(0, 100).toDouble(),
      resumeScore: resumeScore.clamp(0, 100).toDouble(),
      certificateScore: certificateScore.clamp(0, 100).toDouble(),
      projectScore: projectScore.clamp(0, 100).toDouble(),
      careerGoalMatch: careerGoalMatch,
      recommendationReason: _reason(
        score: finalScore,
        matchedSkills: matchedSkills,
        missingSkills: missingSkills,
        careerGoalMatch: careerGoalMatch,
      ),
      calculatedAt: DateTime.now(),
    );
  }

  Future<List<MatchedJobModel>> matchJobsForCandidate({
    required List<JobModel> jobs,
    required String candidateId,
    required String candidateRole,
  }) async {
    final normalizedRole = _normalizeRole(candidateRole);
    final candidate = await _loadCandidate(candidateId, normalizedRole);
    final matches = <MatchedJobModel>[];
    for (final job in jobs) {
      if (!job.isActive) continue;
      final match = _scoreMatch(
        job: job,
        candidateId: candidateId,
        candidateRole: candidateRole,
        candidate: candidate,
      );
      matches.add(MatchedJobModel(job: job, match: match));
    }
    matches.sort((a, b) => b.match.matchScore.compareTo(a.match.matchScore));
    return matches;
  }

  Future<List<RankedCandidateModel>> rankCandidatesForJob(JobModel job) async {
    final applications = await _firestore
        .collection('applications')
        .where('jobId', isEqualTo: job.id)
        .limit(100)
        .get();

    if (applications.docs.isEmpty) return const <RankedCandidateModel>[];

    final parsed = applications.docs
        .map(ApplicationModel.fromFirestore)
        .toList();
    final userSnapshots = await Future.wait(
      parsed.map(
        (application) =>
            _firestore.collection('users').doc(application.applicantId).get(),
      ),
    );

    final candidates = <({ApplicationModel application, UserModel applicant})>[];
    for (var i = 0; i < parsed.length; i++) {
      final userSnapshot = userSnapshots[i];
      if (!userSnapshot.exists || userSnapshot.data() == null) continue;
      candidates.add((
        application: parsed[i],
        applicant: UserModel.fromFirestore(userSnapshot),
      ));
    }

    final matches = await Future.wait(
      candidates.map(
        (entry) => calculateMatch(
          job: job,
          candidateId: entry.application.applicantId,
          candidateRole: entry.applicant.primaryRole ?? 'student',
        ),
      ),
    );

    final ranked = <RankedCandidateModel>[];
    for (var i = 0; i < candidates.length; i++) {
      ranked.add(
        RankedCandidateModel(
          application: candidates[i].application,
          applicant: candidates[i].applicant,
          match: matches[i],
        ),
      );
    }
    ranked.sort((a, b) => b.match.matchScore.compareTo(a.match.matchScore));
    return ranked;
  }

  Future<_CandidateEvidence> _loadCandidate(
    String candidateId,
    String candidateRole,
  ) async {
    final skillScores = <String, double>{};
    final skillFuture = _firestore
        .collection('skillScores')
        .doc(candidateId)
        .collection('skills')
        .get();
    final resumeFuture =
        _firestore.collection('smartResumes').doc(candidateId).get();
    final certificateFuture = _firestore
        .collection('certificates')
        .where('studentId', isEqualTo: candidateId)
        .where('status', isEqualTo: 'active')
        .get();
    final profileFuture = candidateRole == 'freelancer'
        ? _firestore.collection('freelancers').doc(candidateId).get()
        : _firestore.collection('students').doc(candidateId).get();

    final results = await Future.wait([
      skillFuture,
      resumeFuture,
      certificateFuture,
      profileFuture,
    ]);
    final skillSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final resumeSnapshot = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final certificateSnapshot =
        results[2] as QuerySnapshot<Map<String, dynamic>>;
    final profileSnapshot =
        results[3] as DocumentSnapshot<Map<String, dynamic>>;

    for (final doc in skillSnapshot.docs) {
      final data = doc.data();
      skillScores[normalizeSkill(_stringValue(data['skillName'], doc.id))] =
          _doubleValue(data['score']).clamp(0, 100).toDouble();
    }

    final resume = resumeSnapshot.data();
    final resumeScore = _doubleValue(resume?['resumeScore']).clamp(0, 100);
    final resumeProjects = _listValue(resume?['projects']);
    final projectAverage = resumeProjects.isEmpty
        ? 0.0
        : _average(
            resumeProjects.map((project) {
              if (project is Map) return _doubleValue(project['score']);
              return 0.0;
            }),
          );

    final profileSkills = <String>[];
    var careerGoal = '';
    var category = '';
    if (profileSnapshot.exists && profileSnapshot.data() != null) {
      if (candidateRole == 'freelancer') {
        final model = FreelancerModel.fromFirestore(profileSnapshot);
        profileSkills.addAll(model.skills);
        profileSkills.addAll(model.services);
        careerGoal = model.professionalTitle;
        category = model.category;
      } else {
        final model = StudentModel.fromFirestore(profileSnapshot);
        profileSkills.addAll(model.skills);
        profileSkills.addAll(model.interestedSkills);
        careerGoal = model.careerGoal;
        category = model.fieldOfStudy;
      }
    }

    return _CandidateEvidence(
      skillScores: skillScores,
      resumeScore: resumeScore.toDouble(),
      projectCount: resumeProjects.length,
      projectAverage: projectAverage,
      certificateCount: certificateSnapshot.size,
      profileSkills: profileSkills,
      careerGoal: careerGoal,
      category: category,
    );
  }

  bool _careerGoalMatches(JobModel job, _CandidateEvidence candidate) {
    final haystack = [
      candidate.careerGoal,
      candidate.category,
    ].map((value) => value.toLowerCase()).join(' ');
    final needles = [
      job.category,
      job.title,
      ...job.requiredSkills,
      ...job.preferredSkills,
    ].map((value) => normalizeSkill(value));
    return needles.any(
      (needle) => needle.isNotEmpty && haystack.contains(needle),
    );
  }

  List<String> _displaySkills(
    Iterable<String> normalized,
    List<String> source,
  ) {
    final result = <String>[];
    for (final skill in normalized) {
      final label = source.firstWhere(
        (item) => normalizeSkill(item) == skill,
        orElse: () => skill,
      );
      if (!result.any((item) => normalizeSkill(item) == skill)) {
        result.add(label);
      }
    }
    return result;
  }

  String _reason({
    required double score,
    required List<String> matchedSkills,
    required List<String> missingSkills,
    required bool careerGoalMatch,
  }) {
    if (matchedSkills.isEmpty) {
      return 'Not a strong match yet. Build verified skills for this role.';
    }
    final base = 'Matches ${matchedSkills.take(3).join(', ')}';
    final career = careerGoalMatch
        ? ' and aligns with your career direction'
        : '';
    final missing = missingSkills.isNotEmpty
        ? '. Improve ${missingSkills.take(2).join(', ')} to rank higher.'
        : '.';
    return '$base$career$missing';
  }
}

String normalizeSkill(String value) {
  final cleaned = value.trim().toLowerCase();
  final compact = cleaned.replaceAll(RegExp(r'[^a-z0-9+#]+'), '');
  return switch (compact) {
    'csharp' || 'c#' || 'cs' => 'c#',
    'js' || 'javascript' || 'ecmascript' => 'javascript',
    'reactjs' || 'react.js' || 'react' => 'react',
    'nodejs' || 'node.js' || 'node' => 'nodejs',
    'flutter' || 'flutterdev' => 'flutter',
    'dart' => 'dart',
    'firebase' || 'firestore' || 'cloudfirestore' => 'firebase',
    _ => compact,
  };
}

String _normalizeRole(String role) {
  final normalized = role.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  return normalized == 'freelancer' ? 'freelancer' : 'student';
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<Object?> _listValue(Object? value) {
  if (value is Iterable) return value.toList();
  return const <Object?>[];
}

double _average(Iterable<double> values) {
  final list = values.where((value) => value > 0).toList();
  if (list.isEmpty) return 0;
  return (list.reduce((a, b) => a + b) / list.length).clamp(0, 100).toDouble();
}

class _CandidateEvidence {
  const _CandidateEvidence({
    required this.skillScores,
    required this.profileSkills,
    required this.resumeScore,
    required this.certificateCount,
    required this.projectCount,
    required this.projectAverage,
    required this.careerGoal,
    required this.category,
  });

  final Map<String, double> skillScores;
  final List<String> profileSkills;
  final double resumeScore;
  final int certificateCount;
  final int projectCount;
  final double projectAverage;
  final String careerGoal;
  final String category;
}
