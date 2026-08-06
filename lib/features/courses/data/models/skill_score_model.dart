import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

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

class SkillLevel {
  const SkillLevel._();

  static const String beginner = 'Beginner';
  static const String intermediate = 'Intermediate';
  static const String advanced = 'Advanced';
  static const String expert = 'Expert';

  static String fromScore(double score) {
    final value = score.clamp(0, 100);
    if (value >= 85) return expert;
    if (value >= 70) return advanced;
    if (value >= 40) return intermediate;
    return beginner;
  }
}

/// Named evidence item (course / assignment / test / certificate).
class SkillSourceRef {
  const SkillSourceRef({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.courseId = '',
    this.courseTitle = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String courseId;
  final String courseTitle;

  factory SkillSourceRef.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final id = _stringValue(map['id']);
    return SkillSourceRef(
      id: id,
      title: _stringValue(map['title'], id),
      subtitle: _stringValue(map['subtitle']),
      courseId: _stringValue(map['courseId']),
      courseTitle: _stringValue(map['courseTitle']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'courseId': courseId,
        'courseTitle': courseTitle,
      };

  static List<SkillSourceRef> listFrom(Object? value) {
    if (value is! Iterable) return const <SkillSourceRef>[];
    return value
        .whereType<Map>()
        .map((e) => SkillSourceRef.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  static List<SkillSourceRef> fromIds(List<String> ids) {
    return ids
        .map((id) => SkillSourceRef(id: id, title: id))
        .toList();
  }
}

class SkillScoreModel {
  const SkillScoreModel({
    required this.skillScoreId,
    required this.studentId,
    required this.skillName,
    required this.score,
    required this.level,
    required this.sourceCourses,
    required this.sourceAssignments,
    required this.sourceGrandTests,
    required this.sourceCertificates,
    required this.mcqAverage,
    required this.projectAverage,
    required this.grandTestAverage,
    required this.certificateBonusApplied,
    required this.lastCalculatedAt,
    required this.updatedAt,
  });

  final String skillScoreId;
  final String studentId;
  final String skillName;
  final double score;
  final String level;
  final List<SkillSourceRef> sourceCourses;
  final List<SkillSourceRef> sourceAssignments;
  final List<SkillSourceRef> sourceGrandTests;
  final List<SkillSourceRef> sourceCertificates;
  final double mcqAverage;
  final double projectAverage;
  final double grandTestAverage;
  final bool certificateBonusApplied;
  final DateTime lastCalculatedAt;
  final DateTime updatedAt;

  List<String> get sourceCourseIds =>
      sourceCourses.map((e) => e.id).where((id) => id.isNotEmpty).toList();

  List<String> get sourceAssignmentIds =>
      sourceAssignments.map((e) => e.id).where((id) => id.isNotEmpty).toList();

  List<String> get sourceGrandTestIds =>
      sourceGrandTests.map((e) => e.id).where((id) => id.isNotEmpty).toList();

  List<String> get sourceCertificateIds => sourceCertificates
      .map((e) => e.id)
      .where((id) => id.isNotEmpty)
      .toList();

  factory SkillScoreModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final courses = SkillSourceRef.listFrom(data['sourceCourses']);
    final assignments = SkillSourceRef.listFrom(data['sourceAssignments']);
    final grandTests = SkillSourceRef.listFrom(data['sourceGrandTests']);
    final certificates = SkillSourceRef.listFrom(data['sourceCertificates']);

    // Backward compat: older docs only stored id lists.
    final legacyCourseIds = _stringList(data['sourceCourseIds']);
    final legacyAssignmentIds = _stringList(data['sourceAssignmentIds']);
    final legacyGrandTestIds = _stringList(data['sourceGrandTestIds']);
    final legacyCertificateIds = _stringList(data['sourceCertificateIds']);

    return SkillScoreModel(
      skillScoreId: _stringValue(data['skillScoreId'], doc.id),
      studentId: _stringValue(data['studentId']),
      skillName: _stringValue(data['skillName'], doc.id),
      score: _doubleValue(data['score']).clamp(0, 100).toDouble(),
      level: _stringValue(
        data['level'],
        SkillLevel.fromScore(_doubleValue(data['score'])),
      ),
      sourceCourses: courses.isNotEmpty
          ? courses
          : SkillSourceRef.fromIds(legacyCourseIds),
      sourceAssignments: assignments.isNotEmpty
          ? assignments
          : SkillSourceRef.fromIds(legacyAssignmentIds),
      sourceGrandTests: grandTests.isNotEmpty
          ? grandTests
          : SkillSourceRef.fromIds(legacyGrandTestIds),
      sourceCertificates: certificates.isNotEmpty
          ? certificates
          : SkillSourceRef.fromIds(legacyCertificateIds),
      mcqAverage: _doubleValue(data['mcqAverage']).clamp(0, 100).toDouble(),
      projectAverage: _doubleValue(
        data['projectAverage'],
      ).clamp(0, 100).toDouble(),
      grandTestAverage: _doubleValue(
        data['grandTestAverage'],
      ).clamp(0, 100).toDouble(),
      certificateBonusApplied: data['certificateBonusApplied'] == true,
      lastCalculatedAt: _dateValue(data['lastCalculatedAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skillScoreId': skillScoreId,
      'studentId': studentId,
      'skillName': skillName,
      'score': score.clamp(0, 100),
      'level': level,
      'sourceCourses': sourceCourses.map((e) => e.toMap()).toList(),
      'sourceAssignments': sourceAssignments.map((e) => e.toMap()).toList(),
      'sourceGrandTests': sourceGrandTests.map((e) => e.toMap()).toList(),
      'sourceCertificates': sourceCertificates.map((e) => e.toMap()).toList(),
      // Keep id arrays for older readers / Career Intelligence evidence.
      'sourceCourseIds': sourceCourseIds,
      'sourceAssignmentIds': sourceAssignmentIds,
      'sourceGrandTestIds': sourceGrandTestIds,
      'sourceCertificateIds': sourceCertificateIds,
      'mcqAverage': mcqAverage.clamp(0, 100),
      'projectAverage': projectAverage.clamp(0, 100),
      'grandTestAverage': grandTestAverage.clamp(0, 100),
      'certificateBonusApplied': certificateBonusApplied,
      'lastCalculatedAt': Timestamp.fromDate(lastCalculatedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SkillScoreModel copyWith({
    String? skillScoreId,
    String? studentId,
    String? skillName,
    double? score,
    String? level,
    List<SkillSourceRef>? sourceCourses,
    List<SkillSourceRef>? sourceAssignments,
    List<SkillSourceRef>? sourceGrandTests,
    List<SkillSourceRef>? sourceCertificates,
    double? mcqAverage,
    double? projectAverage,
    double? grandTestAverage,
    bool? certificateBonusApplied,
    DateTime? lastCalculatedAt,
    DateTime? updatedAt,
  }) {
    final resolvedScore = score ?? this.score;
    return SkillScoreModel(
      skillScoreId: skillScoreId ?? this.skillScoreId,
      studentId: studentId ?? this.studentId,
      skillName: skillName ?? this.skillName,
      score: resolvedScore.clamp(0, 100).toDouble(),
      level: level ?? SkillLevel.fromScore(resolvedScore),
      sourceCourses: sourceCourses ?? this.sourceCourses,
      sourceAssignments: sourceAssignments ?? this.sourceAssignments,
      sourceGrandTests: sourceGrandTests ?? this.sourceGrandTests,
      sourceCertificates: sourceCertificates ?? this.sourceCertificates,
      mcqAverage: mcqAverage ?? this.mcqAverage,
      projectAverage: projectAverage ?? this.projectAverage,
      grandTestAverage: grandTestAverage ?? this.grandTestAverage,
      certificateBonusApplied:
          certificateBonusApplied ?? this.certificateBonusApplied,
      lastCalculatedAt: lastCalculatedAt ?? this.lastCalculatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
