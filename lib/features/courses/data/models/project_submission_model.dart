import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

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

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

class ProjectSubmissionStatus {
  const ProjectSubmissionStatus._();

  static const String submitted = 'submitted';
  static const String graded = 'graded';
  static const String rejected = 'rejected';
  static const String changesRequested = 'changes_requested';

  static const Set<String> values = {
    submitted,
    graded,
    rejected,
    changesRequested,
  };

  static String normalize(String? value) {
    final normalized = (value ?? submitted).trim().toLowerCase();
    return values.contains(normalized) ? normalized : submitted;
  }
}

class ProjectSubmissionModel {
  const ProjectSubmissionModel({
    required this.assignmentId,
    required this.courseId,
    required this.studentId,
    required this.teacherId,
    required this.projectDescription,
    required this.githubLink,
    required this.liveDemoLink,
    required this.additionalNotes,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    required this.marks,
    required this.maxMarks,
    required this.percentage,
    required this.feedback,
    this.gradedAt,
  });

  final String assignmentId;
  final String courseId;
  final String studentId;
  final String teacherId;
  final String projectDescription;
  final String githubLink;
  final String liveDemoLink;
  final String additionalNotes;
  final String status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final int marks;
  final int maxMarks;
  final double percentage;
  final String feedback;
  final DateTime? gradedAt;

  bool get isGraded => status == ProjectSubmissionStatus.graded;

  factory ProjectSubmissionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProjectSubmissionModel(
      assignmentId: _stringValue(data['assignmentId']),
      courseId: _stringValue(data['courseId']),
      studentId: _stringValue(data['studentId'], doc.id),
      teacherId: _stringValue(data['teacherId']),
      projectDescription: _stringValue(data['projectDescription']),
      githubLink: _stringValue(data['githubLink']),
      liveDemoLink: _stringValue(data['liveDemoLink']),
      additionalNotes: _stringValue(data['additionalNotes']),
      status: ProjectSubmissionStatus.normalize(data['status']?.toString()),
      submittedAt: _dateValue(data['submittedAt']),
      updatedAt: _dateValue(data['updatedAt']),
      marks: _intValue(data['marks']),
      maxMarks: _intValue(data['maxMarks']),
      percentage: _doubleValue(data['percentage']),
      feedback: _stringValue(data['feedback']),
      gradedAt: _nullableDate(data['gradedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': assignmentId,
      'courseId': courseId,
      'studentId': studentId,
      'teacherId': teacherId,
      'projectDescription': projectDescription,
      'githubLink': githubLink,
      'liveDemoLink': liveDemoLink,
      'additionalNotes': additionalNotes,
      'status': ProjectSubmissionStatus.normalize(status),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'marks': marks,
      'maxMarks': maxMarks,
      'percentage': percentage,
      'feedback': feedback,
      if (gradedAt != null) 'gradedAt': Timestamp.fromDate(gradedAt!),
      'progressReady': status == ProjectSubmissionStatus.graded,
      'skillScoreReady': status == ProjectSubmissionStatus.graded,
      'certificateReady': status == ProjectSubmissionStatus.graded,
      'resumeBuilderReady': status == ProjectSubmissionStatus.graded,
    };
  }
}
