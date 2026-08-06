class PlatformStats {
  const PlatformStats({
    required this.totalUsers,
    required this.students,
    required this.teachers,
    required this.freelancers,
    required this.companies,
    required this.jobs,
    required this.applications,
    required this.bannedUsers,
    required this.pendingVerifications,
  });

  final int totalUsers;
  final int students;
  final int teachers;
  final int freelancers;
  final int companies;
  final int jobs;
  final int applications;
  final int bannedUsers;
  final int pendingVerifications;
}
