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

Map<String, dynamic> _dynamicMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

class CertificateType {
  const CertificateType._();

  static const String courseCompletion = 'course_completion';
  static const String excellence = 'excellence';
  static const String projectExcellence = 'project_excellence';

  static const Set<String> values = {
    courseCompletion,
    excellence,
    projectExcellence,
  };

  static String normalize(String? value) {
    final normalized = (value ?? courseCompletion).trim().toLowerCase();
    return values.contains(normalized) ? normalized : courseCompletion;
  }

  static String label(String type) {
    return switch (normalize(type)) {
      excellence => 'Excellence',
      projectExcellence => 'Project Excellence',
      _ => 'Course Completion',
    };
  }
}

class CertificateStatus {
  const CertificateStatus._();

  static const String active = 'active';
  static const String revoked = 'revoked';

  static String normalize(String? value) {
    final normalized = (value ?? active).trim().toLowerCase();
    return normalized == revoked ? revoked : active;
  }
}

class CertificateModel {
  const CertificateModel({
    required this.certificateId,
    required this.studentId,
    required this.teacherId,
    required this.courseId,
    required this.courseTitle,
    required this.studentName,
    required this.teacherName,
    required this.certificateType,
    required this.title,
    required this.description,
    required this.finalScore,
    required this.grandTestScore,
    required this.assignmentAverage,
    required this.issuedAt,
    required this.issuedBy,
    required this.verificationCode,
    required this.status,
    this.revokedAt,
    this.revokeReason = '',
  });

  final String certificateId;
  final String studentId;
  final String teacherId;
  final String courseId;
  final String courseTitle;
  final String studentName;
  final String teacherName;
  final String certificateType;
  final String title;
  final String description;
  final double finalScore;
  final double grandTestScore;
  final double assignmentAverage;
  final DateTime issuedAt;
  final String issuedBy;
  final String verificationCode;
  final String status;
  final DateTime? revokedAt;
  final String revokeReason;

  bool get isActive => status == CertificateStatus.active;
  String get typeLabel => CertificateType.label(certificateType);

  factory CertificateModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CertificateModel(
      certificateId: _stringValue(data['certificateId'], doc.id),
      studentId: _stringValue(data['studentId']),
      teacherId: _stringValue(data['teacherId']),
      courseId: _stringValue(data['courseId']),
      courseTitle: _stringValue(data['courseTitle']),
      studentName: _stringValue(data['studentName'], 'Student'),
      teacherName: _stringValue(data['teacherName'], 'Teacher'),
      certificateType: CertificateType.normalize(
        data['certificateType']?.toString(),
      ),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      finalScore: _doubleValue(data['finalScore']),
      grandTestScore: _doubleValue(data['grandTestScore']),
      assignmentAverage: _doubleValue(data['assignmentAverage']),
      issuedAt: _dateValue(data['issuedAt']),
      issuedBy: _stringValue(data['issuedBy']),
      verificationCode: _stringValue(data['verificationCode']),
      status: CertificateStatus.normalize(data['status']?.toString()),
      revokedAt: _nullableDate(data['revokedAt']),
      revokeReason: _stringValue(data['revokeReason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certificateId': certificateId,
      'studentId': studentId,
      'teacherId': teacherId,
      'courseId': courseId,
      'courseTitle': courseTitle,
      'studentName': studentName,
      'teacherName': teacherName,
      'certificateType': CertificateType.normalize(certificateType),
      'title': title,
      'description': description,
      'finalScore': finalScore,
      'grandTestScore': grandTestScore,
      'assignmentAverage': assignmentAverage,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'issuedBy': issuedBy,
      'verificationCode': verificationCode,
      'status': CertificateStatus.normalize(status),
      if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
      if (revokeReason.trim().isNotEmpty) 'revokeReason': revokeReason,
    };
  }

  CertificateModel copyWith({
    String? certificateId,
    String? studentId,
    String? teacherId,
    String? courseId,
    String? courseTitle,
    String? studentName,
    String? teacherName,
    String? certificateType,
    String? title,
    String? description,
    double? finalScore,
    double? grandTestScore,
    double? assignmentAverage,
    DateTime? issuedAt,
    String? issuedBy,
    String? verificationCode,
    String? status,
    DateTime? revokedAt,
    String? revokeReason,
    bool clearRevokedAt = false,
    bool clearRevokeReason = false,
  }) {
    return CertificateModel(
      certificateId: certificateId ?? this.certificateId,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      studentName: studentName ?? this.studentName,
      teacherName: teacherName ?? this.teacherName,
      certificateType: CertificateType.normalize(
        certificateType ?? this.certificateType,
      ),
      title: title ?? this.title,
      description: description ?? this.description,
      finalScore: finalScore ?? this.finalScore,
      grandTestScore: grandTestScore ?? this.grandTestScore,
      assignmentAverage: assignmentAverage ?? this.assignmentAverage,
      issuedAt: issuedAt ?? this.issuedAt,
      issuedBy: issuedBy ?? this.issuedBy,
      verificationCode: verificationCode ?? this.verificationCode,
      status: CertificateStatus.normalize(status ?? this.status),
      revokedAt: clearRevokedAt ? null : revokedAt ?? this.revokedAt,
      revokeReason: clearRevokeReason ? '' : revokeReason ?? this.revokeReason,
    );
  }
}

class CertificateEligibilityResult {
  const CertificateEligibilityResult({
    required this.studentId,
    required this.isEligible,
    required this.eligibleCertificateTypes,
    required this.issuedCertificateTypes,
    required this.missingRequirements,
    required this.performanceSummary,
    required this.lessonProgress,
    required this.assignmentCompletion,
    required this.assignmentAverage,
    required this.projectSubmitted,
    required this.grandTestPassed,
    required this.grandTestScore,
  });

  final String studentId;
  final bool isEligible;
  final List<String> eligibleCertificateTypes;
  final List<String> issuedCertificateTypes;
  final List<String> missingRequirements;
  final Map<String, dynamic> performanceSummary;
  final double lessonProgress;
  final double assignmentCompletion;
  final double assignmentAverage;
  final bool projectSubmitted;
  final bool grandTestPassed;
  final double grandTestScore;

  bool get hasIssuedCertificates => issuedCertificateTypes.isNotEmpty;
  bool get allEligibleTypesIssued =>
      !isEligible && issuedCertificateTypes.isNotEmpty;

  factory CertificateEligibilityResult.fromJson(Map<String, dynamic> json) {
    return CertificateEligibilityResult(
      studentId: _stringValue(json['studentId']),
      isEligible: json['isEligible'] == true,
      eligibleCertificateTypes: _stringList(json['eligibleCertificateTypes']),
      issuedCertificateTypes: _stringList(json['issuedCertificateTypes']),
      missingRequirements: _stringList(json['missingRequirements']),
      performanceSummary: _dynamicMap(json['performanceSummary']),
      lessonProgress: _doubleValue(json['lessonProgress']),
      assignmentCompletion: _doubleValue(json['assignmentCompletion']),
      assignmentAverage: _doubleValue(json['assignmentAverage']),
      projectSubmitted: json['projectSubmitted'] == true,
      grandTestPassed: json['grandTestPassed'] == true,
      grandTestScore: _doubleValue(json['grandTestScore']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'isEligible': isEligible,
      'eligibleCertificateTypes': eligibleCertificateTypes,
      'issuedCertificateTypes': issuedCertificateTypes,
      'missingRequirements': missingRequirements,
      'performanceSummary': performanceSummary,
      'lessonProgress': lessonProgress,
      'assignmentCompletion': assignmentCompletion,
      'assignmentAverage': assignmentAverage,
      'projectSubmitted': projectSubmitted,
      'grandTestPassed': grandTestPassed,
      'grandTestScore': grandTestScore,
    };
  }
}
