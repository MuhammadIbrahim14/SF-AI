import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

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
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value) ?? fallback;
  return fallback;
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}

class JobModel {
  const JobModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.requirements,
    required this.location,
    required this.type, // e.g. Full-time, Part-time, Contract
    required this.salaryRange,
    required this.isActive,
    required this.createdAt,
    this.applicantCount = 0,
    this.requiredSkills = const [],
    this.preferredSkills = const [],
    this.minimumSkillScore = 0,
    this.targetRoles = const ['student'],
    this.experienceLevel = '',
    this.category = '',
    this.remoteAllowed = false,
    this.matchingEnabled = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String companyId;
  final String title;
  final String description;
  final List<String> requirements;
  final String location;
  final String type;
  final String salaryRange;
  final bool isActive;
  final DateTime createdAt;
  final int applicantCount;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final int minimumSkillScore;
  final List<String> targetRoles;
  final String experienceLevel;
  final String category;
  final bool remoteAllowed;
  final bool matchingEnabled;
  final DateTime updatedAt;

  factory JobModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return JobModel(
      id: doc.id,
      companyId: _stringValue(data['companyId']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      requirements: _stringList(data['requirements']),
      location: _stringValue(data['location']),
      type: _stringValue(data['type']),
      salaryRange: _stringValue(data['salaryRange']),
      isActive: _boolValue(data['isActive'], true),
      createdAt: _dateValue(data['createdAt']),
      applicantCount: _intValue(data['applicantCount']),
      requiredSkills: _stringList(data['requiredSkills']).isNotEmpty
          ? _stringList(data['requiredSkills'])
          : _stringList(data['requirements']),
      preferredSkills: _stringList(data['preferredSkills']),
      minimumSkillScore: _intValue(
        data['minimumSkillScore'] ?? data['minSkillScore'],
      ),
      targetRoles: _stringList(data['targetRoles']).isNotEmpty
          ? _stringList(data['targetRoles'])
          : const ['student'],
      experienceLevel: _stringValue(data['experienceLevel']),
      category: _stringValue(data['category']),
      remoteAllowed: _boolValue(data['remoteAllowed']),
      matchingEnabled: _boolValue(data['matchingEnabled'], true),
      updatedAt: _dateValue(data['updatedAt'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'title': title,
      'description': description,
      'requirements': requirements,
      'location': location,
      'type': type,
      'salaryRange': salaryRange,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'applicantCount': applicantCount,
      'requiredSkills': requiredSkills,
      'preferredSkills': preferredSkills,
      'minimumSkillScore': minimumSkillScore,
      'targetRoles': targetRoles,
      'experienceLevel': experienceLevel,
      'category': category,
      'remoteAllowed': remoteAllowed,
      'matchingEnabled': matchingEnabled,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  JobModel copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    List<String>? requirements,
    String? location,
    String? type,
    String? salaryRange,
    bool? isActive,
    DateTime? createdAt,
    int? applicantCount,
    List<String>? requiredSkills,
    List<String>? preferredSkills,
    int? minimumSkillScore,
    List<String>? targetRoles,
    String? experienceLevel,
    String? category,
    bool? remoteAllowed,
    bool? matchingEnabled,
    DateTime? updatedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      location: location ?? this.location,
      type: type ?? this.type,
      salaryRange: salaryRange ?? this.salaryRange,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      applicantCount: applicantCount ?? this.applicantCount,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      preferredSkills: preferredSkills ?? this.preferredSkills,
      minimumSkillScore: minimumSkillScore ?? this.minimumSkillScore,
      targetRoles: targetRoles ?? this.targetRoles,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      category: category ?? this.category,
      remoteAllowed: remoteAllowed ?? this.remoteAllowed,
      matchingEnabled: matchingEnabled ?? this.matchingEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
