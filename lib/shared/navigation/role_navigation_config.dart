import 'package:flutter/material.dart';

import '../../app/router/route_names.dart';
import '../../models/user_role.dart';

enum RoleNavigationDestinationType {
  primary,
  secondary,
  quickAction,
  profile,
  settings,
}

enum RoleNavigationActionGroup { learning, teaching, jobs, hiring, profile }

class RoleNavigationDestination {
  const RoleNavigationDestination({
    required this.label,
    required this.path,
    required this.routeName,
    required this.role,
    required this.type,
    required this.icon,
    required this.selectedIcon,
    this.description,
    this.actionGroup,
  });

  final String label;
  final String path;
  final String routeName;
  final UserRole role;
  final RoleNavigationDestinationType type;
  final IconData icon;
  final IconData selectedIcon;
  final String? description;
  final RoleNavigationActionGroup? actionGroup;
}

class RoleNavigationMenuSection {
  const RoleNavigationMenuSection({required this.title, required this.items});

  final String title;
  final List<RoleNavigationDestination> items;
}

class RoleNavigationConfig {
  const RoleNavigationConfig._();

  static List<RoleNavigationDestination> destinationsFor(UserRole role) {
    return switch (role) {
      UserRole.student => _studentDestinations,
      UserRole.teacher => _teacherDestinations,
      UserRole.freelancer => _freelancerDestinations,
      UserRole.company => _companyDestinations,
      _ => _fallbackDestinations,
    };
  }

  static List<RoleNavigationDestination> primaryDestinationsFor(UserRole role) {
    return destinationsFor(role)
        .where((item) => item.type == RoleNavigationDestinationType.primary)
        .toList(growable: false);
  }

  static List<RoleNavigationDestination> quickActionsFor(UserRole role) {
    return destinationsFor(role)
        .where((item) => item.type == RoleNavigationDestinationType.quickAction)
        .toList(growable: false);
  }

  static List<RoleNavigationDestination> profileDestinationsFor(UserRole role) {
    return destinationsFor(role)
        .where((item) => item.type == RoleNavigationDestinationType.profile)
        .toList(growable: false);
  }

  /// Mirrors the header app menu (Workspace / More / Account).
  static List<RoleNavigationMenuSection> appMenuSectionsFor(UserRole role) {
    return appMenuSectionsFrom(
      destinationsFor(role),
      excludeDashboard: true,
    );
  }

  static List<RoleNavigationMenuSection> appMenuSectionsFrom(
    List<RoleNavigationDestination> destinations, {
    bool excludeDashboard = false,
  }) {
    final filtered = excludeDashboard
        ? destinations.where((item) => !_isDashboardDestination(item))
        : destinations;

    final mainItems = filtered
        .where(
          (item) =>
              item.type == RoleNavigationDestinationType.primary ||
              item.type == RoleNavigationDestinationType.quickAction,
        )
        .toList(growable: false);
    final moreItems = filtered
        .where((item) => item.type == RoleNavigationDestinationType.secondary)
        .toList(growable: false);
    final accountItems = filtered
        .where((item) => item.type == RoleNavigationDestinationType.profile)
        .toList(growable: false);

    return [
      if (mainItems.isNotEmpty)
        RoleNavigationMenuSection(title: 'Workspace', items: mainItems),
      if (moreItems.isNotEmpty)
        RoleNavigationMenuSection(title: 'More', items: moreItems),
      if (accountItems.isNotEmpty)
        RoleNavigationMenuSection(title: 'Account', items: accountItems),
    ];
  }

  static bool _isDashboardDestination(RoleNavigationDestination item) {
    return item.label == 'Dashboard' &&
        item.type == RoleNavigationDestinationType.primary;
  }

  static String? activePathFor(
    String currentPath,
    List<RoleNavigationDestination> destinations,
  ) {
    for (final item in destinations) {
      if (currentPath == item.path) return item.path;
    }

    final matches =
        destinations
            .where(
              (item) =>
                  item.path != RoutePaths.dashboard &&
                  item.path.split('/').length > 2 &&
                  currentPath.startsWith(item.path),
            )
            .toList()
          ..sort((a, b) => b.path.length.compareTo(a.path.length));

    return matches.isEmpty ? null : matches.first.path;
  }

  static const List<RoleNavigationDestination> _studentDestinations = [
    RoleNavigationDestination(
      label: 'Dashboard',
      path: RoutePaths.studentDashboard,
      routeName: RouteNames.studentDashboard,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      description: 'Student command center',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'Find Courses',
      path: RoutePaths.studentCourses,
      routeName: RouteNames.studentCourses,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.search_rounded,
      selectedIcon: Icons.manage_search_rounded,
      description: 'Discover published courses',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'My Courses',
      path: RoutePaths.studentEnrolledCourses,
      routeName: RouteNames.studentEnrolledCourses,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.play_circle_outline_rounded,
      selectedIcon: Icons.play_circle_fill_rounded,
      description: 'Continue enrolled courses',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'Paid Courses',
      path: RoutePaths.studentPaidCourses,
      routeName: RouteNames.studentPaidCourses,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag_rounded,
      description: 'Purchases, receipts, and paid access',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'My Classes',
      path: RoutePaths.studentMyBatches,
      routeName: RouteNames.studentMyBatches,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2_rounded,
      description: 'Class batches, join requests, and announcements',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'Jobs',
      path: RoutePaths.jobList,
      routeName: RouteNames.jobList,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.work_outline_rounded,
      selectedIcon: Icons.work_rounded,
      description: 'Explore eligible opportunities',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Applications',
      path: RoutePaths.myApplications,
      routeName: RouteNames.myApplications,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_turned_in_rounded,
      description: 'Track applications and respond to offers',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Employment',
      path: RoutePaths.myEmployment,
      routeName: RouteNames.myEmployment,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      description: 'Onboarding, welcome pack, and active roles',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Interviews',
      path: RoutePaths.myInterviews,
      routeName: RouteNames.myInterviews,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available_rounded,
      description: 'View scheduled hiring interviews',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Certificates',
      path: RoutePaths.studentCertificates,
      routeName: RouteNames.studentCertificates,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      description: 'View earned certificates',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'Skill Scores',
      path: RoutePaths.studentSkillScores,
      routeName: RouteNames.studentSkillScores,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology_rounded,
      description: 'Track verified skill strength',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'Career Roadmap',
      path: RoutePaths.studentCareerRoadmap,
      routeName: RouteNames.studentCareerRoadmap,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.route_outlined,
      selectedIcon: Icons.route_rounded,
      description: 'Verified skill gap and target role plan',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'AI Interview Lab',
      path: RoutePaths.interviewLab,
      routeName: RouteNames.interviewLab,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.record_voice_over_outlined,
      selectedIcon: Icons.record_voice_over_rounded,
      description: 'Practice AI interviews privately (not hiring)',
      actionGroup: RoleNavigationActionGroup.learning,
    ),
    RoleNavigationDestination(
      label: 'Freelancer Bridge',
      path: RoutePaths.studentFreelancerBridge,
      routeName: RouteNames.studentFreelancerBridge,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.rocket_launch_outlined,
      selectedIcon: Icons.rocket_launch_rounded,
      description: 'Activate public showcase from verified skills',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Resume',
      path: RoutePaths.studentResume,
      routeName: RouteNames.studentResume,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
      description: 'Build and review resume intelligence',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Profile',
      path: RoutePaths.studentProfile,
      routeName: RouteNames.studentProfile,
      role: UserRole.student,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      description: 'Manage student profile',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Portfolio Builder',
      path: RoutePaths.portfolioBuilder,
      routeName: RouteNames.portfolioBuilder,
      role: UserRole.student,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.web_outlined,
      selectedIcon: Icons.web_rounded,
      description: 'Publish a public portfolio link',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Contact Support',
      path: RoutePaths.contactUs,
      routeName: RouteNames.contactUs,
      role: UserRole.student,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      description: 'Get help or report an issue',
    ),
  ];

  static const List<RoleNavigationDestination> _teacherDestinations = [
    RoleNavigationDestination(
      label: 'Dashboard',
      path: RoutePaths.teacherDashboard,
      routeName: RouteNames.teacherDashboard,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      description: 'Teacher command center',
      actionGroup: RoleNavigationActionGroup.teaching,
    ),
    RoleNavigationDestination(
      label: 'My Courses',
      path: RoutePaths.teacherCourses,
      routeName: RouteNames.teacherCourses,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
      description: 'Manage created courses',
      actionGroup: RoleNavigationActionGroup.teaching,
    ),
    RoleNavigationDestination(
      label: 'Create Course',
      path: RoutePaths.teacherCourseCreate,
      routeName: RouteNames.teacherCourseCreate,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.add_circle_outline_rounded,
      selectedIcon: Icons.add_circle_rounded,
      description: 'Create a new course',
      actionGroup: RoleNavigationActionGroup.teaching,
    ),
    RoleNavigationDestination(
      label: 'Student Progress',
      path: RoutePaths.teacherStudentProgress,
      routeName: RouteNames.teacherStudentProgress,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.query_stats_outlined,
      selectedIcon: Icons.query_stats_rounded,
      description: 'Review learner progress and risk',
      actionGroup: RoleNavigationActionGroup.teaching,
    ),
    RoleNavigationDestination(
      label: 'Batches',
      path: RoutePaths.teacherBatches,
      routeName: RouteNames.teacherBatches,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2_rounded,
      description: 'Manage batches, courses, and class risk',
      actionGroup: RoleNavigationActionGroup.teaching,
    ),
    RoleNavigationDestination(
      label: 'Profile',
      path: RoutePaths.teacherProfile,
      routeName: RouteNames.teacherProfile,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      description: 'Manage teacher profile',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Portfolio Builder',
      path: RoutePaths.portfolioBuilder,
      routeName: RouteNames.portfolioBuilder,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.web_outlined,
      selectedIcon: Icons.web_rounded,
      description: 'Publish courses and teaching proof',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Plan Management',
      path: RoutePaths.teacherPlans,
      routeName: RouteNames.teacherPlans,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      description: 'Manage teaching plan, billing, and upgrades',
    ),
    RoleNavigationDestination(
      label: 'Teacher Wallet',
      path: RoutePaths.teacherWallet,
      routeName: RouteNames.teacherWallet,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      description: 'Course sales, balances, and demo withdrawals',
    ),
    RoleNavigationDestination(
      label: 'Contact Support',
      path: RoutePaths.contactUs,
      routeName: RouteNames.contactUs,
      role: UserRole.teacher,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      description: 'Get help or report an issue',
    ),
  ];

  static const List<RoleNavigationDestination> _freelancerDestinations = [
    RoleNavigationDestination(
      label: 'Dashboard',
      path: RoutePaths.freelancerDashboard,
      routeName: RouteNames.freelancerDashboard,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      description: 'Freelancer command center',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Browse Jobs',
      path: RoutePaths.jobList,
      routeName: RouteNames.jobList,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.search_rounded,
      selectedIcon: Icons.manage_search_rounded,
      description: 'Find matching work',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Applications',
      path: RoutePaths.myApplications,
      routeName: RouteNames.myApplications,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_turned_in_rounded,
      description: 'Track job applications',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Employment',
      path: RoutePaths.myEmployment,
      routeName: RouteNames.myEmployment,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      description: 'Onboarding, welcome pack, and active roles',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Wallet',
      path: RoutePaths.freelancerWallet,
      routeName: RouteNames.freelancerWallet,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      description: 'Sandbox earnings and escrow balances',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Payouts',
      path: RoutePaths.freelancerPayouts,
      routeName: RouteNames.freelancerPayouts,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.outbound_outlined,
      selectedIcon: Icons.outbound_rounded,
      description: 'Request and track sandbox withdrawals',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Resolution Center',
      path: RoutePaths.freelancerResolutions,
      routeName: RouteNames.freelancerResolutions,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      description: 'Manage revisions, disputes, and refunds',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'AI Assistant',
      path: RoutePaths.freelancerAiAssistant,
      routeName: RouteNames.freelancerAiAssistant,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      description: 'Draft proposals, services, updates, and evidence summaries',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'AI Interview Lab',
      path: RoutePaths.interviewLab,
      routeName: RouteNames.interviewLab,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.record_voice_over_outlined,
      selectedIcon: Icons.record_voice_over_rounded,
      description: 'Practice AI interviews privately (not hiring)',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Interviews',
      path: RoutePaths.myInterviews,
      routeName: RouteNames.myInterviews,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.event_outlined,
      selectedIcon: Icons.event_available_rounded,
      description: 'View scheduled interviews',
      actionGroup: RoleNavigationActionGroup.jobs,
    ),
    RoleNavigationDestination(
      label: 'Profile',
      path: RoutePaths.freelancerProfile,
      routeName: RouteNames.freelancerProfile,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      description: 'Manage freelancer profile',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Portfolio Builder',
      path: RoutePaths.portfolioBuilder,
      routeName: RouteNames.portfolioBuilder,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.web_outlined,
      selectedIcon: Icons.web_rounded,
      description: 'Publish services and portfolio proof',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Contact Support',
      path: RoutePaths.contactUs,
      routeName: RouteNames.contactUs,
      role: UserRole.freelancer,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      description: 'Get help or report an issue',
    ),
  ];

  static const List<RoleNavigationDestination> _companyDestinations = [
    RoleNavigationDestination(
      label: 'Dashboard',
      path: RoutePaths.companyDashboard,
      routeName: RouteNames.companyDashboard,
      role: UserRole.company,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      description: 'Company command center',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'Manage Jobs',
      path: RoutePaths.companyJobs,
      routeName: RouteNames.companyJobs,
      role: UserRole.company,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.business_center_outlined,
      selectedIcon: Icons.business_center_rounded,
      description: 'Manage active job posts',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'Post a Job',
      path: RoutePaths.createJob,
      routeName: RouteNames.createJob,
      role: UserRole.company,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.post_add_outlined,
      selectedIcon: Icons.post_add_rounded,
      description: 'Create a new job post',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'AI Hiring Assistant',
      path: RoutePaths.companyAiHiringAssistant,
      routeName: RouteNames.companyAiHiringAssistant,
      role: UserRole.company,
      type: RoleNavigationDestinationType.quickAction,
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      description: 'Generate job posts, interview kits, and hiring insights',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'Hiring Pipeline',
      path: RoutePaths.hiringPipeline,
      routeName: RouteNames.hiringPipeline,
      role: UserRole.company,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      description: 'Review candidates and hiring stages',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'Employees',
      path: RoutePaths.companyEmployees,
      routeName: RouteNames.companyEmployees,
      role: UserRole.company,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      description: 'Active employees and pending joins',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'Interviews',
      path: RoutePaths.myInterviews,
      routeName: RouteNames.myInterviews,
      role: UserRole.company,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.event_outlined,
      selectedIcon: Icons.event_available_rounded,
      description: 'View scheduled interviews',
      actionGroup: RoleNavigationActionGroup.hiring,
    ),
    RoleNavigationDestination(
      label: 'Profile',
      path: RoutePaths.companyProfile,
      routeName: RouteNames.companyProfile,
      role: UserRole.company,
      type: RoleNavigationDestinationType.profile,
      icon: Icons.business_outlined,
      selectedIcon: Icons.business_rounded,
      description: 'Manage company profile',
      actionGroup: RoleNavigationActionGroup.profile,
    ),
    RoleNavigationDestination(
      label: 'Contact Support',
      path: RoutePaths.contactUs,
      routeName: RouteNames.contactUs,
      role: UserRole.company,
      type: RoleNavigationDestinationType.secondary,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      description: 'Get help or report an issue',
    ),
  ];

  static const List<RoleNavigationDestination> _fallbackDestinations = [
    RoleNavigationDestination(
      label: 'Dashboard',
      path: RoutePaths.dashboard,
      routeName: RouteNames.dashboard,
      role: UserRole.student,
      type: RoleNavigationDestinationType.primary,
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      description: 'Dashboard',
    ),
  ];
}
