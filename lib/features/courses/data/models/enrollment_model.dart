import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// Keys used inside `enrollments/{id}.requirementBreakdown`. Each key maps to
/// one course module that can be required for completion.
class CourseRequirementKind {
  const CourseRequirementKind._();

  static const String lessons = 'lessons';
  static const String quizzes = 'quizzes';
  static const String projects = 'projects';
  static const String grandTest = 'grandTest';

  static const List<String> values = <String>[
    lessons,
    quizzes,
    projects,
    grandTest,
  ];

  static String label(String kind) {
    return switch (kind) {
      quizzes => 'Quizzes',
      projects => 'Projects',
      grandTest => 'Grand test',
      _ => 'Lessons',
    };
  }
}

/// Completed vs published item counts for a single course module.
class CourseRequirementCount {
  const CourseRequirementCount({this.total = 0, this.completed = 0});

  final int total;
  final int completed;

  /// A module the course does not use at all (no published items).
  bool get isConfigured => total > 0;
  bool get isComplete => total > 0 && completed >= total;

  factory CourseRequirementCount.fromJson(Object? value) {
    if (value is Map) {
      return CourseRequirementCount(
        total: _intValue(value['total']),
        completed: _intValue(value['completed']),
      );
    }
    return const CourseRequirementCount();
  }

  Map<String, dynamic> toJson() => {'total': total, 'completed': completed};
}

class EnrollmentStatus {
  const EnrollmentStatus._();

  static const String active = 'active';
  static const String completed = 'completed';
  static const String dropped = 'dropped';

  static String normalize(String? value) {
    final normalized = (value ?? active).trim().toLowerCase();
    return {active, completed, dropped}.contains(normalized)
        ? normalized
        : active;
  }
}

class EnrollmentModel {
  const EnrollmentModel({
    required this.enrollmentId,
    required this.courseId,
    required this.studentId,
    required this.teacherId,
    required this.enrolledAt,
    required this.progressPercent,
    required this.completedLessons,
    required this.totalLessons,
    required this.status,
    this.lessonProgressPercent = 0,
    this.completedRequirements = 0,
    this.totalRequirements = 0,
    this.requirementBreakdown = const <String, CourseRequirementCount>{},
  });

  final String enrollmentId;
  final String courseId;
  final String studentId;
  final String teacherId;
  final DateTime enrolledAt;

  /// Overall course completion across every required module (lessons, quizzes,
  /// projects, grand test). Reaches 100 only when the whole course is done.
  final double progressPercent;
  final int completedLessons;
  final int totalLessons;
  final String status;

  /// Lessons-only progress, kept separate because certificate and grand test
  /// eligibility gate on lesson progress, not on overall completion.
  final double lessonProgressPercent;
  final int completedRequirements;
  final int totalRequirements;
  final Map<String, CourseRequirementCount> requirementBreakdown;

  bool get isActive => status == EnrollmentStatus.active;
  bool get isCompleted => status == EnrollmentStatus.completed;

  CourseRequirementCount requirement(String kind) =>
      requirementBreakdown[kind] ?? const CourseRequirementCount();

  factory EnrollmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final completedLessons = _intValue(data['completedLessons']);
    final totalLessons = _intValue(data['totalLessons']);
    final breakdown = data['requirementBreakdown'];
    return EnrollmentModel(
      enrollmentId: data['enrollmentId'] is String
          ? data['enrollmentId'] as String
          : doc.id,
      courseId: data['courseId'] is String ? data['courseId'] as String : '',
      studentId: data['studentId'] is String ? data['studentId'] as String : '',
      teacherId: data['teacherId'] is String ? data['teacherId'] as String : '',
      enrolledAt: _dateValue(data['enrolledAt']),
      progressPercent: _doubleValue(data['progressPercent']),
      completedLessons: completedLessons,
      totalLessons: totalLessons,
      status: EnrollmentStatus.normalize(data['status']?.toString()),
      // Enrollments written before overall progress tracking only stored
      // lesson counters, so derive lesson progress from them.
      lessonProgressPercent: data.containsKey('lessonProgressPercent')
          ? _doubleValue(data['lessonProgressPercent'])
          : (totalLessons == 0
                ? 0
                : ((completedLessons / totalLessons) * 100).clamp(0, 100)),
      completedRequirements: _intValue(data['completedRequirements']),
      totalRequirements: _intValue(data['totalRequirements']),
      requirementBreakdown: breakdown is Map
          ? {
              for (final kind in CourseRequirementKind.values)
                if (breakdown[kind] != null)
                  kind: CourseRequirementCount.fromJson(breakdown[kind]),
            }
          : const <String, CourseRequirementCount>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enrollmentId': enrollmentId,
      'courseId': courseId,
      'studentId': studentId,
      'teacherId': teacherId,
      'enrolledAt': Timestamp.fromDate(enrolledAt),
      'progressPercent': progressPercent,
      'completedLessons': completedLessons,
      'totalLessons': totalLessons,
      'status': EnrollmentStatus.normalize(status),
      'lessonProgressPercent': lessonProgressPercent,
      'completedRequirements': completedRequirements,
      'totalRequirements': totalRequirements,
      'requirementBreakdown': {
        for (final entry in requirementBreakdown.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }
}
