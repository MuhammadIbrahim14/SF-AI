import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/teacher_student_progress_model.dart';
import 'teacher_assessment_analytics_provider.dart';
import 'teacher_grand_certificate_analytics_provider.dart';
import 'teacher_student_progress_provider.dart';

final teacherAiIntelligenceProvider = FutureProvider<TeacherAiIntelligence>((
  ref,
) async {
  final progress = await ref.watch(teacherStudentProgressProvider.future);
  final assessments = await ref.watch(
    teacherAssessmentAnalyticsProvider.future,
  );
  final grandCertificates = await ref.watch(
    teacherGrandCertificateAnalyticsProvider.future,
  );

  return TeacherAiIntelligenceService().build(
    progress: progress,
    assessments: assessments,
    grandCertificates: grandCertificates,
  );
});

class TeacherAiIntelligenceService {
  TeacherAiIntelligence build({
    required List<TeacherStudentProgressModel> progress,
    required TeacherAssessmentAnalytics assessments,
    required TeacherGrandCertificateAnalytics grandCertificates,
  }) {
    final students = _studentSummaries(progress);
    final courses = _courseHealth(
      progress: progress,
      assessments: assessments,
      grandCertificates: grandCertificates,
    );
    final topPerformers =
        students.where((student) => student.overallScore > 0).toList()
          ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    final atRisk = students.where((student) => student.isAtRisk).toList()
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final needsAttention =
        students
            .where((student) => student.needsAttention && !student.isAtRisk)
            .toList()
          ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final inbox = _inbox(
      assessments: assessments,
      grandCertificates: grandCertificates,
      atRisk: atRisk,
      needsAttention: needsAttention,
      courses: courses,
    );
    final recommendations = _recommendations(
      assessments: assessments,
      grandCertificates: grandCertificates,
      atRisk: atRisk,
      needsAttention: needsAttention,
      courses: courses,
    );

    return TeacherAiIntelligence(
      topPerformers: topPerformers.take(5).toList(),
      atRiskStudents: atRisk.take(5).toList(),
      needsAttentionStudents: needsAttention.take(5).toList(),
      inboxItems: inbox,
      courseHealth: courses,
      recommendations: recommendations,
      pendingProjectReviews: assessments.pendingProjectReviews,
      pendingAssignmentAttempts: assessments.pendingAttempts,
      pendingCertificates: grandCertificates.pendingCertificateIssuance,
      pendingGrandTestSignals:
          grandCertificates.noAttemptStudents +
          grandCertificates.warningAttempts,
    );
  }

  List<TeacherStudentIntelligence> _studentSummaries(
    List<TeacherStudentProgressModel> records,
  ) {
    final grouped = <String, List<TeacherStudentProgressModel>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.studentId, () => []).add(record);
    }

    return grouped.entries.map((entry) {
      final studentRecords = entry.value;
      final averageScore = _average(
        studentRecords.map((item) => item.averageScore).toList(),
      );
      final progress = _average(
        studentRecords.map((item) => item.lessonProgress).toList(),
      );
      final assignmentCompletion = _average(
        studentRecords.map((item) => item.assignmentCompletion).toList(),
      );
      final certificates = studentRecords
          .where((item) => item.certificateStatus == 'issued')
          .length;
      final failedGrandTests = studentRecords
          .where((item) => item.grandTestStatus == 'failed')
          .length;
      final missingProjects = studentRecords
          .where((item) => item.projectStatus == 'missing')
          .length;
      final riskRecords = studentRecords
          .where((item) => item.riskStatus == TeacherProgressRisk.atRisk)
          .length;
      final needsAttentionRecords = studentRecords
          .where(
            (item) => item.riskStatus == TeacherProgressRisk.needsAttention,
          )
          .length;
      final reasons = <String>{
        for (final item in studentRecords) ...item.riskReasons,
        if (failedGrandTests > 0) 'Failed Grand Test needs revision.',
        if (missingProjects > 0) 'Missing project submission.',
      }.where((item) => item.trim().isNotEmpty && item != 'On track.').toList();

      final strongestArea = _strongestArea(
        averageScore: averageScore,
        progress: progress,
        assignmentCompletion: assignmentCompletion,
        certificates: certificates,
      );
      final overallScore =
          (averageScore * 0.45) +
          (progress * 0.25) +
          (assignmentCompletion * 0.2) +
          ((certificates > 0 ? 100 : 0) * 0.1);
      final priorityScore =
          ((100 - progress) * 0.35) +
          ((100 - averageScore) * 0.35) +
          (missingProjects * 12) +
          (failedGrandTests * 16) +
          (riskRecords * 10) +
          (needsAttentionRecords * 5);

      return TeacherStudentIntelligence(
        studentId: entry.key,
        studentName: studentRecords.first.studentName,
        studentEmail: studentRecords.first.studentEmail,
        courseLabel: _courseLabel(studentRecords),
        overallScore: overallScore.clamp(0, 100).toDouble(),
        strongestArea: strongestArea,
        certificateCount: certificates,
        riskReasons: reasons.take(3).toList(),
        priority: _priority(priorityScore),
        priorityScore: priorityScore,
        isAtRisk:
            riskRecords > 0 || failedGrandTests > 0 || missingProjects > 0,
        needsAttention:
            needsAttentionRecords > 0 || progress < 70 || averageScore < 70,
      );
    }).toList();
  }

  List<TeacherCourseHealth> _courseHealth({
    required List<TeacherStudentProgressModel> progress,
    required TeacherAssessmentAnalytics assessments,
    required TeacherGrandCertificateAnalytics grandCertificates,
  }) {
    final grouped = <String, List<TeacherStudentProgressModel>>{};
    for (final record in progress) {
      grouped.putIfAbsent(record.courseId, () => []).add(record);
    }

    final courses = grouped.entries.map((entry) {
      final records = entry.value;
      final completionRate = _average(
        records.map((item) => item.lessonProgress).toList(),
      );
      final assignmentCompletion = _average(
        records.map((item) => item.assignmentCompletion).toList(),
      );
      final assignmentAverages = assessments.assignmentBreakdowns
          .where((item) => item.courseId == entry.key)
          .map((item) => item.averageScore)
          .where((score) => score > 0)
          .toList();
      final projectItems = assessments.projectBreakdowns
          .where((item) => item.courseId == entry.key)
          .toList();
      final grandItems = grandCertificates.grandTestBreakdowns
          .where((item) => item.courseId == entry.key)
          .toList();
      final certificateItems = grandCertificates.certificateBreakdowns
          .where((item) => item.courseId == entry.key)
          .toList();
      final studentCount = records.map((item) => item.studentId).toSet().length;
      final activeLearners = records
          .where((item) => item.lessonProgress > 0 || item.averageScore > 0)
          .map((item) => item.studentId)
          .toSet()
          .length;
      final assignmentAverage = _average(assignmentAverages);
      final projectCompletion = projectItems.isEmpty
          ? 0.0
          : _average(
              projectItems.map((item) {
                final total = item.totalAttempts + item.pendingCount;
                return total == 0 ? 0.0 : item.totalAttempts / total * 100;
              }).toList(),
            );
      final grandPassRate = _average(
        grandItems.map((item) => item.passRate).toList(),
      );
      final certificateCompletion = certificateItems.isEmpty
          ? 0.0
          : _average(
              certificateItems.map((item) {
                final eligible = item.eligibleStudents;
                return eligible == 0
                    ? 0.0
                    : item.issuedCertificates / eligible * 100;
              }).toList(),
            );
      final healthScore = _healthScore(
        completionRate: completionRate,
        assignmentAverage: assignmentAverage,
        assignmentCompletion: assignmentCompletion,
        projectCompletion: projectCompletion,
        grandPassRate: grandPassRate,
        certificateCompletion: certificateCompletion,
      );

      return TeacherCourseHealth(
        courseId: entry.key,
        courseTitle: records.first.courseTitle,
        completionRate: completionRate,
        assignmentAverage: assignmentAverage,
        projectCompletion: projectCompletion,
        grandTestPassRate: grandPassRate,
        certificateCompletion: certificateCompletion,
        studentCount: studentCount,
        activeLearners: activeLearners,
        healthScore: healthScore,
        healthLabel: _healthLabel(healthScore),
      );
    }).toList();

    courses.sort((a, b) => a.healthScore.compareTo(b.healthScore));
    return courses.take(6).toList();
  }

  List<TeacherInboxItem> _inbox({
    required TeacherAssessmentAnalytics assessments,
    required TeacherGrandCertificateAnalytics grandCertificates,
    required List<TeacherStudentIntelligence> atRisk,
    required List<TeacherStudentIntelligence> needsAttention,
    required List<TeacherCourseHealth> courses,
  }) {
    final items = <TeacherInboxItem>[];
    if (assessments.pendingProjectReviews > 0) {
      items.add(
        TeacherInboxItem(
          title: 'Project reviews pending',
          detail:
              '${assessments.pendingProjectReviews} submissions are waiting for feedback.',
          priority: TeacherInsightPriority.high,
          iconName: 'project',
        ),
      );
    }
    if (assessments.pendingAttempts > 0) {
      items.add(
        TeacherInboxItem(
          title: 'Missing assignment attempts',
          detail:
              '${assessments.pendingAttempts} expected assignment attempts are still missing.',
          priority: TeacherInsightPriority.medium,
          iconName: 'assignment',
        ),
      );
    }
    if (grandCertificates.failedGrandAttempts > 0) {
      items.add(
        TeacherInboxItem(
          title: 'Grand Test revision needed',
          detail:
              '${grandCertificates.failedGrandAttempts} failed attempts need follow-up.',
          priority: TeacherInsightPriority.high,
          iconName: 'grandTest',
        ),
      );
    }
    if (grandCertificates.pendingCertificateIssuance > 0) {
      items.add(
        TeacherInboxItem(
          title: 'Certificates pending',
          detail:
              '${grandCertificates.pendingCertificateIssuance} students appear ready for certificates.',
          priority: TeacherInsightPriority.medium,
          iconName: 'certificate',
        ),
      );
    }
    if (atRisk.isNotEmpty) {
      items.add(
        TeacherInboxItem(
          title: 'At-risk students',
          detail: '${atRisk.length} students need direct intervention.',
          priority: TeacherInsightPriority.high,
          iconName: 'risk',
        ),
      );
    }
    if (needsAttention.isNotEmpty) {
      items.add(
        TeacherInboxItem(
          title: 'Students need attention',
          detail: '${needsAttention.length} students should be nudged soon.',
          priority: TeacherInsightPriority.medium,
          iconName: 'attention',
        ),
      );
    }
    final criticalCourses = courses
        .where(
          (course) => course.healthLabel == TeacherCourseHealthLabel.critical,
        )
        .length;
    if (criticalCourses > 0) {
      items.add(
        TeacherInboxItem(
          title: 'Critical course health',
          detail: '$criticalCourses courses need content or learner support.',
          priority: TeacherInsightPriority.high,
          iconName: 'course',
        ),
      );
    }

    items.sort((a, b) => b.priorityRank.compareTo(a.priorityRank));
    return items.take(6).toList();
  }

  List<String> _recommendations({
    required TeacherAssessmentAnalytics assessments,
    required TeacherGrandCertificateAnalytics grandCertificates,
    required List<TeacherStudentIntelligence> atRisk,
    required List<TeacherStudentIntelligence> needsAttention,
    required List<TeacherCourseHealth> courses,
  }) {
    final items = <String>[];
    final lowAssignment =
        assessments.assignmentBreakdowns
            .where((item) => item.averageScore > 0 && item.averageScore < 55)
            .toList()
          ..sort((a, b) => a.averageScore.compareTo(b.averageScore));
    if (lowAssignment.isNotEmpty) {
      items.add(
        '${lowAssignment.first.title} average score is ${lowAssignment.first.averageScore.toStringAsFixed(0)}%. Consider reviewing prerequisite lessons.',
      );
    }
    final heavyProjectCourse = assessments.pendingReviewsByCourse.isEmpty
        ? null
        : assessments.pendingReviewsByCourse.first;
    if (heavyProjectCourse != null && heavyProjectCourse.count > 0) {
      items.add(
        '${heavyProjectCourse.courseTitle} has ${heavyProjectCourse.count} pending project reviews.',
      );
    }
    if (grandCertificates.noAttemptStudents > 0) {
      items.add(
        '${grandCertificates.noAttemptStudents} students have not attempted a published Grand Test yet.',
      );
    }
    if (grandCertificates.pendingCertificateIssuance > 0) {
      items.add(
        'Certificate issuance appears pending for ${grandCertificates.pendingCertificateIssuance} students.',
      );
    }
    if (atRisk.isNotEmpty) {
      items.add(
        '${atRisk.first.studentName} is high priority: ${atRisk.first.riskReasons.isEmpty ? 'performance risk detected.' : atRisk.first.riskReasons.first}',
      );
    }
    final weakCourse = courses
        .where(
          (course) =>
              course.healthLabel == TeacherCourseHealthLabel.critical ||
              course.healthLabel == TeacherCourseHealthLabel.needsAttention,
        )
        .toList();
    if (weakCourse.isNotEmpty) {
      items.add(
        '${weakCourse.first.courseTitle} course health is ${TeacherCourseHealthLabel.label(weakCourse.first.healthLabel)}. Review progress and assessment outcomes.',
      );
    }
    if (needsAttention.isNotEmpty) {
      items.add(
        '${needsAttention.length} students are close to slipping. Send reminders before they become at-risk.',
      );
    }
    if (items.isEmpty) {
      items.add(
        'No urgent intelligence signals yet. Keep publishing assessments and reviewing projects to enrich recommendations.',
      );
    }
    return items.take(6).toList();
  }

  String _courseLabel(List<TeacherStudentProgressModel> records) {
    final titles = records.map((item) => item.courseTitle).toSet().toList()
      ..sort();
    if (titles.isEmpty) return 'No course';
    if (titles.length == 1) return titles.first;
    return '${titles.first} +${titles.length - 1} more';
  }

  String _strongestArea({
    required double averageScore,
    required double progress,
    required double assignmentCompletion,
    required int certificates,
  }) {
    final areas = <String, double>{
      'Assessment': averageScore,
      'Course Progress': progress,
      'Consistency': assignmentCompletion,
      if (certificates > 0) 'Certification': 100,
    };
    final entries = areas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _priority(double score) {
    if (score >= 80) return 'High';
    if (score >= 45) return 'Medium';
    return 'Low';
  }

  double _healthScore({
    required double completionRate,
    required double assignmentAverage,
    required double assignmentCompletion,
    required double projectCompletion,
    required double grandPassRate,
    required double certificateCompletion,
  }) {
    final available = <double>[
      completionRate,
      assignmentCompletion,
      if (assignmentAverage > 0) assignmentAverage,
      if (projectCompletion > 0) projectCompletion,
      if (grandPassRate > 0) grandPassRate,
      if (certificateCompletion > 0) certificateCompletion,
    ];
    return _average(available).clamp(0, 100).toDouble();
  }

  String _healthLabel(double score) {
    if (score >= 85) return TeacherCourseHealthLabel.excellent;
    if (score >= 70) return TeacherCourseHealthLabel.healthy;
    if (score >= 45) return TeacherCourseHealthLabel.needsAttention;
    return TeacherCourseHealthLabel.critical;
  }

  double _average(List<num> values) {
    if (values.isEmpty) return 0;
    return values.fold<double>(0, (total, value) => total + value.toDouble()) /
        values.length;
  }
}

class TeacherAiIntelligence {
  const TeacherAiIntelligence({
    required this.topPerformers,
    required this.atRiskStudents,
    required this.needsAttentionStudents,
    required this.inboxItems,
    required this.courseHealth,
    required this.recommendations,
    required this.pendingProjectReviews,
    required this.pendingAssignmentAttempts,
    required this.pendingCertificates,
    required this.pendingGrandTestSignals,
  });

  final List<TeacherStudentIntelligence> topPerformers;
  final List<TeacherStudentIntelligence> atRiskStudents;
  final List<TeacherStudentIntelligence> needsAttentionStudents;
  final List<TeacherInboxItem> inboxItems;
  final List<TeacherCourseHealth> courseHealth;
  final List<String> recommendations;
  final int pendingProjectReviews;
  final int pendingAssignmentAttempts;
  final int pendingCertificates;
  final int pendingGrandTestSignals;

  int get totalWorkload =>
      pendingProjectReviews +
      pendingAssignmentAttempts +
      pendingCertificates +
      pendingGrandTestSignals;
}

class TeacherStudentIntelligence {
  const TeacherStudentIntelligence({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseLabel,
    required this.overallScore,
    required this.strongestArea,
    required this.certificateCount,
    required this.riskReasons,
    required this.priority,
    required this.priorityScore,
    required this.isAtRisk,
    required this.needsAttention,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courseLabel;
  final double overallScore;
  final String strongestArea;
  final int certificateCount;
  final List<String> riskReasons;
  final String priority;
  final double priorityScore;
  final bool isAtRisk;
  final bool needsAttention;
}

class TeacherInboxItem {
  const TeacherInboxItem({
    required this.title,
    required this.detail,
    required this.priority,
    required this.iconName,
  });

  final String title;
  final String detail;
  final String priority;
  final String iconName;

  int get priorityRank => switch (priority) {
    TeacherInsightPriority.high => 3,
    TeacherInsightPriority.medium => 2,
    _ => 1,
  };
}

class TeacherCourseHealth {
  const TeacherCourseHealth({
    required this.courseId,
    required this.courseTitle,
    required this.completionRate,
    required this.assignmentAverage,
    required this.projectCompletion,
    required this.grandTestPassRate,
    required this.certificateCompletion,
    required this.studentCount,
    required this.activeLearners,
    required this.healthScore,
    required this.healthLabel,
  });

  final String courseId;
  final String courseTitle;
  final double completionRate;
  final double assignmentAverage;
  final double projectCompletion;
  final double grandTestPassRate;
  final double certificateCompletion;
  final int studentCount;
  final int activeLearners;
  final double healthScore;
  final String healthLabel;
}

class TeacherInsightPriority {
  const TeacherInsightPriority._();

  static const String high = 'high';
  static const String medium = 'medium';
  static const String low = 'low';

  static String label(String value) {
    return switch (value) {
      high => 'High',
      medium => 'Medium',
      _ => 'Low',
    };
  }
}

class TeacherCourseHealthLabel {
  const TeacherCourseHealthLabel._();

  static const String excellent = 'excellent';
  static const String healthy = 'healthy';
  static const String needsAttention = 'needs_attention';
  static const String critical = 'critical';

  static String label(String value) {
    return switch (value) {
      excellent => 'Excellent',
      healthy => 'Healthy',
      needsAttention => 'Needs Attention',
      critical => 'Critical',
      _ => 'Unknown',
    };
  }
}
