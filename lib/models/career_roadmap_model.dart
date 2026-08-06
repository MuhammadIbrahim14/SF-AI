import 'package:cloud_firestore/cloud_firestore.dart';

List<String> _list(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class CareerRoadmapModel {
  const CareerRoadmapModel({
    required this.roadmapId,
    required this.studentId,
    required this.targetRole,
    required this.requiredSkills,
    required this.currentSkills,
    required this.missingSkills,
    required this.recommendedCourses,
    required this.recommendedProjects,
    required this.progressPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String roadmapId;
  final String studentId;
  final String targetRole;
  final List<String> requiredSkills;
  final List<String> currentSkills;
  final List<String> missingSkills;
  final List<String> recommendedCourses;
  final List<String> recommendedProjects;
  final double progressPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CareerRoadmapModel.fromFirestore(
    String studentId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CareerRoadmapModel(
      roadmapId: doc.id,
      studentId: studentId,
      targetRole: _string(data['targetRole'], 'Flutter Developer'),
      requiredSkills: _list(data['requiredSkills']),
      currentSkills: _list(data['currentSkills']),
      missingSkills: _list(data['missingSkills']),
      recommendedCourses: _list(data['recommendedCourses']),
      recommendedProjects: _list(data['recommendedProjects']),
      progressPercent: _double(data['progressPercent']).clamp(0, 100),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetRole': targetRole,
      'requiredSkills': requiredSkills,
      'currentSkills': currentSkills,
      'missingSkills': missingSkills,
      'recommendedCourses': recommendedCourses,
      'recommendedProjects': recommendedProjects,
      'progressPercent': progressPercent.clamp(0, 100),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class SkillGapAnalysisModel {
  const SkillGapAnalysisModel({
    required this.targetRole,
    required this.requiredSkills,
    required this.masteredSkills,
    required this.weakSkills,
    required this.missingSkills,
    required this.recommendedCourses,
    required this.recommendedProjects,
    required this.progressPercent,
  });

  final String targetRole;
  final List<String> requiredSkills;
  final List<String> masteredSkills;
  final List<String> weakSkills;
  final List<String> missingSkills;
  final List<String> recommendedCourses;
  final List<String> recommendedProjects;
  final double progressPercent;
}
