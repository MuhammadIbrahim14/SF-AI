import 'package:cloud_firestore/cloud_firestore.dart';

import 'application_model.dart';
import 'job_model.dart';
import 'user_model.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

class JobMatchModel {
  const JobMatchModel({
    required this.matchId,
    required this.jobId,
    required this.candidateId,
    required this.candidateRole,
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.skillScoreAverage,
    required this.resumeScore,
    required this.certificateScore,
    required this.projectScore,
    required this.careerGoalMatch,
    required this.recommendationReason,
    required this.calculatedAt,
  });

  final String matchId;
  final String jobId;
  final String candidateId;
  final String candidateRole;
  final double matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final double skillScoreAverage;
  final double resumeScore;
  final double certificateScore;
  final double projectScore;
  final bool careerGoalMatch;
  final String recommendationReason;
  final DateTime calculatedAt;

  bool get isStrongMatch => matchScore >= 60;

  factory JobMatchModel.empty({
    required JobModel job,
    required String candidateId,
    required String candidateRole,
    String reason = 'Complete more verified skills to improve recommendations.',
  }) {
    return JobMatchModel(
      matchId: '${job.id}_$candidateId',
      jobId: job.id,
      candidateId: candidateId,
      candidateRole: candidateRole,
      matchScore: 0,
      matchedSkills: const [],
      missingSkills: job.requiredSkills,
      skillScoreAverage: 0,
      resumeScore: 0,
      certificateScore: 0,
      projectScore: 0,
      careerGoalMatch: false,
      recommendationReason: reason,
      calculatedAt: DateTime.now(),
    );
  }

  factory JobMatchModel.fromJson(Map<String, dynamic> json) {
    return JobMatchModel(
      matchId: _stringValue(json['matchId']),
      jobId: _stringValue(json['jobId']),
      candidateId: _stringValue(json['candidateId']),
      candidateRole: _stringValue(json['candidateRole']),
      matchScore: _doubleValue(json['matchScore']).clamp(0, 100).toDouble(),
      matchedSkills: _stringList(json['matchedSkills']),
      missingSkills: _stringList(json['missingSkills']),
      skillScoreAverage: _doubleValue(
        json['skillScoreAverage'],
      ).clamp(0, 100).toDouble(),
      resumeScore: _doubleValue(json['resumeScore']).clamp(0, 100).toDouble(),
      certificateScore: _doubleValue(
        json['certificateScore'],
      ).clamp(0, 100).toDouble(),
      projectScore: _doubleValue(json['projectScore']).clamp(0, 100).toDouble(),
      careerGoalMatch: json['careerGoalMatch'] == true,
      recommendationReason: _stringValue(json['recommendationReason']),
      calculatedAt: _dateValue(json['calculatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'jobId': jobId,
      'candidateId': candidateId,
      'candidateRole': candidateRole,
      'matchScore': matchScore,
      'matchedSkills': matchedSkills,
      'missingSkills': missingSkills,
      'skillScoreAverage': skillScoreAverage,
      'resumeScore': resumeScore,
      'certificateScore': certificateScore,
      'projectScore': projectScore,
      'careerGoalMatch': careerGoalMatch,
      'recommendationReason': recommendationReason,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  JobMatchModel copyWith({
    String? matchId,
    String? jobId,
    String? candidateId,
    String? candidateRole,
    double? matchScore,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    double? skillScoreAverage,
    double? resumeScore,
    double? certificateScore,
    double? projectScore,
    bool? careerGoalMatch,
    String? recommendationReason,
    DateTime? calculatedAt,
  }) {
    return JobMatchModel(
      matchId: matchId ?? this.matchId,
      jobId: jobId ?? this.jobId,
      candidateId: candidateId ?? this.candidateId,
      candidateRole: candidateRole ?? this.candidateRole,
      matchScore: matchScore ?? this.matchScore,
      matchedSkills: matchedSkills ?? this.matchedSkills,
      missingSkills: missingSkills ?? this.missingSkills,
      skillScoreAverage: skillScoreAverage ?? this.skillScoreAverage,
      resumeScore: resumeScore ?? this.resumeScore,
      certificateScore: certificateScore ?? this.certificateScore,
      projectScore: projectScore ?? this.projectScore,
      careerGoalMatch: careerGoalMatch ?? this.careerGoalMatch,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }
}

class MatchedJobModel {
  const MatchedJobModel({required this.job, required this.match});

  final JobModel job;
  final JobMatchModel match;
}

bool isJobRelevantForCandidate({
  required JobModel job,
  required JobMatchModel? match,
}) {
  if (!job.isActive) return false;
  final candidateRole = match?.candidateRole.toLowerCase();
  final targetRoles = job.targetRoles.map((role) => role.toLowerCase()).toSet();
  if (candidateRole != null &&
      candidateRole.isNotEmpty &&
      targetRoles.isNotEmpty &&
      !targetRoles.contains('both') &&
      !targetRoles.contains(candidateRole)) {
    return false;
  }

  if (!job.matchingEnabled) return true;

  final requiredSignals = job.requiredSkills.isNotEmpty
      ? job.requiredSkills
      : job.requirements;

  if (requiredSignals.isEmpty && job.minimumSkillScore <= 0) {
    return true;
  }

  if (match == null) return false;

  if (job.minimumSkillScore > 0 &&
      match.skillScoreAverage < job.minimumSkillScore) {
    return false;
  }

  if (requiredSignals.isNotEmpty) {
    if (match.matchedSkills.isEmpty) return false;
    // Allow jobs to show if student has matched skills with reasonable score
    // even if some skills are missing - the match score already accounts for this
    if (match.matchScore < 50) return false;
  }

  return true;
}

class RankedCandidateModel {
  const RankedCandidateModel({
    required this.application,
    required this.applicant,
    required this.match,
  });

  final ApplicationModel application;
  final UserModel applicant;
  final JobMatchModel match;
}
