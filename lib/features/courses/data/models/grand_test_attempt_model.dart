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

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase().trim() == 'true';
  if (value is num) return value != 0;
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
  return const <String>[];
}

Map<String, String> _stringMap(Object? value) {
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }
  return const <String, String>{};
}

Map<String, List<String>> _optionOrderMap(Object? value) {
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _stringList(item)),
    );
  }
  return const <String, List<String>>{};
}

Map<String, dynamic> _dynamicMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

class GrandTestAttemptStatus {
  const GrandTestAttemptStatus._();

  static const String inProgress = 'in_progress';
  static const String submitted = 'submitted';
  static const String autoSubmitted = 'auto_submitted';
}

class GrandTestAttemptModel {
  const GrandTestAttemptModel({
    required this.attemptId,
    required this.grandTestId,
    required this.courseId,
    required this.studentId,
    required this.teacherId,
    required this.attemptNumber,
    required this.answers,
    required this.score,
    required this.totalMarks,
    required this.passingMarks,
    required this.percentage,
    required this.passed,
    required this.startedAt,
    required this.submittedAt,
    required this.timeTakenSeconds,
    required this.warningsCount,
    required this.eligibilitySnapshot,
    required this.status,
    required this.questionOrder,
    required this.optionOrder,
  });

  final String attemptId;
  final String grandTestId;
  final String courseId;
  final String studentId;
  final String teacherId;
  final int attemptNumber;
  final Map<String, String> answers;
  final int score;
  final int totalMarks;
  final int passingMarks;
  final double percentage;
  final bool passed;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final int timeTakenSeconds;
  final int warningsCount;
  final Map<String, dynamic> eligibilitySnapshot;
  final String status;
  final List<String> questionOrder;
  final Map<String, List<String>> optionOrder;

  bool get isInProgress => status == GrandTestAttemptStatus.inProgress;
  bool get isSubmitted =>
      status == GrandTestAttemptStatus.submitted ||
      status == GrandTestAttemptStatus.autoSubmitted;

  factory GrandTestAttemptModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GrandTestAttemptModel(
      attemptId: _stringValue(data['attemptId'], doc.id),
      grandTestId: _stringValue(data['grandTestId']),
      courseId: _stringValue(data['courseId']),
      studentId: _stringValue(data['studentId']),
      teacherId: _stringValue(data['teacherId']),
      attemptNumber: _intValue(data['attemptNumber'], 1),
      answers: _stringMap(data['answers']),
      score: _intValue(data['score']),
      totalMarks: _intValue(data['totalMarks']),
      passingMarks: _intValue(data['passingMarks']),
      percentage: _doubleValue(data['percentage']),
      passed: _boolValue(data['passed']),
      startedAt: _dateValue(data['startedAt']),
      submittedAt: _nullableDate(data['submittedAt']),
      timeTakenSeconds: _intValue(data['timeTakenSeconds']),
      warningsCount: _intValue(data['warningsCount']),
      eligibilitySnapshot: _dynamicMap(data['eligibilitySnapshot']),
      status: _stringValue(data['status'], GrandTestAttemptStatus.inProgress),
      questionOrder: _stringList(data['questionOrder']),
      optionOrder: _optionOrderMap(data['optionOrder']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attemptId': attemptId,
      'grandTestId': grandTestId,
      'courseId': courseId,
      'studentId': studentId,
      'teacherId': teacherId,
      'attemptNumber': attemptNumber,
      'answers': answers,
      'score': score,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'percentage': percentage,
      'passed': passed,
      'startedAt': Timestamp.fromDate(startedAt),
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      'timeTakenSeconds': timeTakenSeconds,
      'warningsCount': warningsCount,
      'eligibilitySnapshot': eligibilitySnapshot,
      'status': status,
      'questionOrder': questionOrder,
      'optionOrder': optionOrder,
    };
  }
}
