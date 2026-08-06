import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

List<String> _list(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class VerifiedSkillModel {
  const VerifiedSkillModel({
    required this.skillId,
    required this.skillName,
    required this.sourceCourseIds,
    required this.sourceProjectIds,
    required this.evidenceType,
    required this.verificationLevel,
    required this.completedAt,
    required this.score,
    required this.publicVisible,
  });

  final String skillId;
  final String skillName;
  final List<String> sourceCourseIds;
  final List<String> sourceProjectIds;
  final String evidenceType;
  final String verificationLevel;
  final DateTime completedAt;
  final double score;
  final bool publicVisible;

  factory VerifiedSkillModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return VerifiedSkillModel(
      skillId: doc.id,
      skillName: _string(data['skillName'], doc.id),
      sourceCourseIds: _list(data['sourceCourseIds']),
      sourceProjectIds: _list(data['sourceProjectIds']),
      evidenceType: _string(data['evidenceType'], 'verified_assessment'),
      verificationLevel: _string(data['verificationLevel'], 'verified'),
      completedAt: _date(data['completedAt']),
      score: _double(data['score']).clamp(0, 100),
      publicVisible: data['publicVisible'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skillName': skillName,
      'sourceCourseIds': sourceCourseIds,
      'sourceProjectIds': sourceProjectIds,
      'evidenceType': evidenceType,
      'verificationLevel': verificationLevel,
      'completedAt': Timestamp.fromDate(completedAt),
      'score': score.clamp(0, 100),
      'publicVisible': publicVisible,
    };
  }
}

class FreelancerEligibilityCheckItem {
  const FreelancerEligibilityCheckItem({
    required this.id,
    required this.label,
    required this.passed,
    required this.detail,
  });

  final String id;
  final String label;
  final bool passed;
  final String detail;
}

class FreelancerReadinessModel {
  const FreelancerReadinessModel({
    required this.score,
    required this.verifiedSkillCount,
    required this.completedProjectCount,
    required this.profileCompletion,
    required this.portfolioReady,
    required this.serviceReady,
    required this.recommendations,
    this.isEligible = false,
    this.checks = const <FreelancerEligibilityCheckItem>[],
  });

  final double score;
  final int verifiedSkillCount;
  final int completedProjectCount;
  final double profileCompletion;
  final bool portfolioReady;
  final bool serviceReady;
  final List<String> recommendations;
  final bool isEligible;
  final List<FreelancerEligibilityCheckItem> checks;
}
