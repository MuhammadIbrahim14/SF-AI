class TeacherDashboardStatsModel {
  const TeacherDashboardStatsModel({
    required this.totalCourses,
    required this.publishedCourses,
    required this.draftCourses,
    required this.totalEnrolledStudents,
    required this.activeStudents,
    required this.totalAssignments,
    required this.pendingProjectReviews,
    required this.grandTestsCreated,
    required this.certificatesIssued,
    required this.averageGrandTestScore,
    required this.averageCourseCompletion,
    required this.teachingImpactScore,
    required this.primaryCourseId,
    required this.primaryCourseTitle,
    required this.firstPendingProject,
    required this.firstGrandTestId,
    required this.pendingWorks,
    required this.activities,
  });

  final int totalCourses;
  final int publishedCourses;
  final int draftCourses;
  final int totalEnrolledStudents;
  final int activeStudents;
  final int totalAssignments;
  final int pendingProjectReviews;
  final int grandTestsCreated;
  final int certificatesIssued;
  final double averageGrandTestScore;
  final double averageCourseCompletion;
  final int teachingImpactScore;
  final String? primaryCourseId;
  final String primaryCourseTitle;
  final TeacherPendingProjectReview? firstPendingProject;
  final String? firstGrandTestId;
  final List<TeacherPendingWorkItem> pendingWorks;
  final List<TeacherDashboardActivityItem> activities;

  static const empty = TeacherDashboardStatsModel(
    totalCourses: 0,
    publishedCourses: 0,
    draftCourses: 0,
    totalEnrolledStudents: 0,
    activeStudents: 0,
    totalAssignments: 0,
    pendingProjectReviews: 0,
    grandTestsCreated: 0,
    certificatesIssued: 0,
    averageGrandTestScore: 0,
    averageCourseCompletion: 0,
    teachingImpactScore: 0,
    primaryCourseId: null,
    primaryCourseTitle: '',
    firstPendingProject: null,
    firstGrandTestId: null,
    pendingWorks: <TeacherPendingWorkItem>[],
    activities: <TeacherDashboardActivityItem>[],
  );
}

class TeacherPendingProjectReview {
  const TeacherPendingProjectReview({
    required this.courseId,
    required this.assignmentId,
    required this.studentId,
  });

  final String courseId;
  final String assignmentId;
  final String studentId;
}

class TeacherPendingWorkItem {
  const TeacherPendingWorkItem({
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.count,
    this.courseId,
    this.assignmentId,
    this.grandTestId,
  });

  final String title;
  final String subtitle;
  final String iconName;
  final int count;
  final String? courseId;
  final String? assignmentId;
  final String? grandTestId;
}

class TeacherDashboardActivityItem {
  const TeacherDashboardActivityItem({
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.createdAt,
    this.courseId,
  });

  final String title;
  final String subtitle;
  final String iconName;
  final DateTime createdAt;
  final String? courseId;
}
