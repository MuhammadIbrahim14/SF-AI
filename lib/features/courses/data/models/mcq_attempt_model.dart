import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

Map<String, String> _stringMap(Object? value) {
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }
  return const <String, String>{};
}

class McqAttemptStatus {
  const McqAttemptStatus._();

  static const String inProgress = 'inProgress';
  static const String submitted = 'submitted';
}

class McqAttemptModel {
  const McqAttemptModel({
    required this.assignmentId,
    required this.courseId,
    required this.studentId,
    required this.teacherId,
    required this.startedAt,
    required this.submittedAt,
    required this.answers,
    required this.score,
    required this.totalMarks,
    required this.passingMarks,
    required this.percentage,
    required this.passed,
    required this.warningsCount,
    required this.status,
    required this.autoSubmitted,
  });

  final String assignmentId;
  final String courseId;
  final String studentId;
  final String teacherId;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final Map<String, String> answers;
  final int score;
  final int totalMarks;
  final int passingMarks;
  final double percentage;
  final bool passed;
  final int warningsCount;
  final String status;
  final bool autoSubmitted;

  bool get isSubmitted => status == McqAttemptStatus.submitted;

  factory McqAttemptModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return McqAttemptModel(
      assignmentId: _stringValue(data['assignmentId']),
      courseId: _stringValue(data['courseId']),
      studentId: _stringValue(data['studentId'], doc.id),
      teacherId: _stringValue(data['teacherId']),
      startedAt: _dateValue(data['startedAt']),
      submittedAt: _nullableDate(data['submittedAt']),
      answers: _stringMap(data['answers']),
      score: _intValue(data['score']),
      totalMarks: _intValue(data['totalMarks']),
      passingMarks: _intValue(data['passingMarks']),
      percentage: _doubleValue(data['percentage']),
      passed: data['passed'] == true,
      warningsCount: _intValue(data['warningsCount']),
      status: _stringValue(data['status'], McqAttemptStatus.inProgress),
      autoSubmitted: data['autoSubmitted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': assignmentId,
      'courseId': courseId,
      'studentId': studentId,
      'teacherId': teacherId,
      'startedAt': Timestamp.fromDate(startedAt),
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      'answers': answers,
      'score': score,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'percentage': percentage,
      'passed': passed,
      'warningsCount': warningsCount,
      'status': status,
      'autoSubmitted': autoSubmitted,
    };
  }
}
