class TeacherProgressRisk {
  const TeacherProgressRisk._();

  static const String healthy = 'healthy';
  static const String needsAttention = 'needs_attention';
  static const String atRisk = 'at_risk';

  static String label(String value) {
    return switch (value) {
      atRisk => 'At Risk',
      needsAttention => 'Needs Attention',
      _ => 'Healthy',
    };
  }
}

class TeacherStudentProgressModel {
  const TeacherStudentProgressModel({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseId,
    required this.courseTitle,
    required this.lessonProgress,
    required this.completedLessons,
    required this.totalLessons,
    required this.assignmentCompletion,
    required this.completedAssignments,
    required this.totalAssignments,
    required this.projectStatus,
    required this.grandTestStatus,
    required this.certificateStatus,
    required this.averageScore,
    required this.riskStatus,
    required this.riskReasons,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courseId;
  final String courseTitle;
  final double lessonProgress;
  final int completedLessons;
  final int totalLessons;
  final double assignmentCompletion;
  final int completedAssignments;
  final int totalAssignments;
  final String projectStatus;
  final String grandTestStatus;
  final String certificateStatus;
  final double averageScore;
  final String riskStatus;
  final List<String> riskReasons;

  bool get isAtRisk => riskStatus == TeacherProgressRisk.atRisk;
  bool get needsAttention => riskStatus == TeacherProgressRisk.needsAttention;
}

class TeacherStudentSkillSnapshot {
  const TeacherStudentSkillSnapshot({
    required this.skillName,
    required this.score,
    required this.level,
  });

  final String skillName;
  final double score;
  final String level;
}

class TeacherStudentProgressDetailModel {
  const TeacherStudentProgressDetailModel({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.records,
    required this.skillScores,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final List<TeacherStudentProgressModel> records;
  final List<TeacherStudentSkillSnapshot> skillScores;

  double get averageProgress {
    if (records.isEmpty) return 0;
    final total = records.fold<double>(
      0,
      (sum, item) => sum + item.lessonProgress,
    );
    return total / records.length;
  }

  double get averageScore {
    if (records.isEmpty) return 0;
    final total = records.fold<double>(
      0,
      (sum, item) => sum + item.averageScore,
    );
    return total / records.length;
  }

  int get completedLessons {
    return records.fold<int>(0, (sum, item) => sum + item.completedLessons);
  }

  int get totalLessons {
    return records.fold<int>(0, (sum, item) => sum + item.totalLessons);
  }

  int get completedAssignments {
    return records.fold<int>(0, (sum, item) => sum + item.completedAssignments);
  }

  int get totalAssignments {
    return records.fold<int>(0, (sum, item) => sum + item.totalAssignments);
  }

  int get certificatesEarned {
    return records.where((item) => item.certificateStatus == 'issued').length;
  }
}
