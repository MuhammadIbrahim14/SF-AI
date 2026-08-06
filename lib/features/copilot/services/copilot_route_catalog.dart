import '../../../app/router/route_names.dart';
import '../models/copilot_intent_model.dart';

class CopilotRouteCategory {
  const CopilotRouteCategory._();

  static const dashboard = 'dashboard';
  static const wallet = 'wallet';
  static const orders = 'orders';
  static const serviceRequests = 'serviceRequests';
  static const services = 'services';
  static const marketplace = 'marketplace';
  static const delivery = 'delivery';
  static const resolution = 'resolution';
  static const payouts = 'payouts';
  static const profile = 'profile';
  static const support = 'support';
  static const legal = 'legal';
  static const courses = 'courses';
  static const certificates = 'certificates';
  static const smartResume = 'smartResume';
  static const jobs = 'jobs';
  static const companyHiring = 'companyHiring';
  static const admin = 'admin';
  static const settings = 'settings';
}

class CopilotRouteDestination {
  const CopilotRouteDestination({
    required this.id,
    required this.title,
    required this.description,
    required this.path,
    required this.category,
    required this.keywords,
    this.routeName,
    this.allowedRoles = const <String>[],
    this.allowedAccountTypes = const <String>[],
    this.synonyms = const <String>[],
    this.actionLevel = CopilotActionLevel.safeNavigation,
    this.isAvailable = true,
    this.unavailableReason,
  });

  final String id;
  final String title;
  final String description;
  final String? routeName;
  final String path;
  final String category;
  final List<String> allowedRoles;
  final List<String> allowedAccountTypes;
  final List<String> keywords;
  final List<String> synonyms;
  final String actionLevel;
  final bool isAvailable;
  final String? unavailableReason;

  Iterable<String> get searchableTerms => [
    id,
    title,
    description,
    category,
    ...keywords,
    ...synonyms,
  ];
}

class CopilotRouteMatch {
  const CopilotRouteMatch({
    required this.destination,
    required this.score,
    required this.matchedKeyword,
  });

  final CopilotRouteDestination destination;
  final int score;
  final String matchedKeyword;
}

class CopilotRouteCatalog {
  const CopilotRouteCatalog._();

  static const commonRomanUrdu = [
    'open karo',
    'khol do',
    'le chalo',
    'dikhao',
    'kidhar hai',
    'kahan hai',
    'mujhe',
    'meri',
    'mera',
    'page par le jao',
    'screen open karo',
  ];

  static const destinations = <CopilotRouteDestination>[
    CopilotRouteDestination(
      id: 'customerDashboard',
      title: 'Customer Dashboard',
      description: 'Customer workspace home.',
      routeName: RouteNames.customerDashboard,
      path: RoutePaths.customerDashboard,
      category: CopilotRouteCategory.dashboard,
      allowedAccountTypes: ['customer'],
      keywords: ['dashboard', 'customer dashboard', 'home', 'main screen'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'studentDashboard',
      title: 'Student Dashboard',
      description: 'Student learning dashboard.',
      routeName: RouteNames.studentDashboard,
      path: RoutePaths.studentDashboard,
      category: CopilotRouteCategory.dashboard,
      allowedRoles: ['student'],
      keywords: ['student dashboard', 'learning dashboard', 'dashboard'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'studentAiTutor',
      title: 'SkillForge AI Tutor',
      description:
          'Student AI tutor for explanations, practice, quiz review, and revision plans.',
      routeName: RouteNames.studentAiTutor,
      path: RoutePaths.studentAiTutor,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['student'],
      keywords: [
        'ai tutor',
        'ask skillforge ai',
        'skillforge ai',
        'student ai tutor',
        'ask tutor',
        'ask ai',
        'lesson explain',
        'practice questions',
        'quiz mistakes',
        'revision plan',
      ],
      synonyms: [
        'ai tutor kholo',
        'ask skillforge ai kholo',
        'ai se poochna hai',
        'lesson explain karo',
        'lesson samjhao',
        'practice questions banao',
        'quiz mistakes samjhao',
        'revision plan banao',
      ],
    ),
    CopilotRouteDestination(
      id: 'teacherDashboard',
      title: 'Teacher Dashboard',
      description: 'Teacher command center.',
      routeName: RouteNames.teacherDashboard,
      path: RoutePaths.teacherDashboard,
      category: CopilotRouteCategory.dashboard,
      allowedRoles: ['teacher'],
      keywords: ['teacher dashboard', 'teacher home', 'dashboard'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerDashboard',
      title: 'Freelancer Dashboard',
      description: 'Freelancer command center.',
      routeName: RouteNames.freelancerDashboard,
      path: RoutePaths.freelancerDashboard,
      category: CopilotRouteCategory.dashboard,
      allowedRoles: ['freelancer'],
      keywords: ['freelancer dashboard', 'freelancer home', 'dashboard'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'companyDashboard',
      title: 'Company Dashboard',
      description: 'Company hiring dashboard.',
      routeName: RouteNames.companyDashboard,
      path: RoutePaths.companyDashboard,
      category: CopilotRouteCategory.dashboard,
      allowedRoles: ['company'],
      keywords: ['company dashboard', 'company home', 'dashboard'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminDashboard',
      title: 'Admin Dashboard',
      description: 'Admin control dashboard.',
      routeName: RouteNames.adminDashboard,
      path: RoutePaths.adminDashboard,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin'],
      keywords: ['admin dashboard', 'admin home', 'dashboard'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'superAdminDashboard',
      title: 'Super Admin Dashboard',
      description: 'Super admin platform control.',
      routeName: RouteNames.superAdminDashboard,
      path: RoutePaths.superAdminDashboard,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['superadmin'],
      keywords: ['super admin dashboard', 'superadmin dashboard'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'customerWallet',
      title: 'Wallet',
      description: 'Customer sandbox wallet and balance.',
      routeName: RouteNames.customerWallet,
      path: RoutePaths.customerWallet,
      category: CopilotRouteCategory.wallet,
      allowedAccountTypes: ['customer'],
      keywords: [
        'wallet',
        'balance',
        'demo balance',
        'paisay',
        'paise',
        'wallet open karo',
        'balance dikhao',
        'mera balance',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerWallet',
      title: 'Freelancer Wallet',
      description: 'Freelancer wallet, escrow, and balances.',
      routeName: RouteNames.freelancerWallet,
      path: RoutePaths.freelancerWallet,
      category: CopilotRouteCategory.wallet,
      allowedRoles: ['freelancer'],
      keywords: ['wallet', 'freelancer wallet', 'balance', 'earnings'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'customerOrders',
      title: 'My Orders',
      description: 'Customer service orders.',
      routeName: RouteNames.serviceOrders,
      path: RoutePaths.serviceOrders,
      category: CopilotRouteCategory.orders,
      allowedAccountTypes: ['customer'],
      keywords: [
        'orders',
        'my orders',
        'meri orders',
        'active orders',
        'pending orders',
        'order open karo',
        'order list',
        'service orders',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerOrders',
      title: 'Freelancer Orders',
      description: 'Freelancer service orders and delivery work.',
      routeName: RouteNames.freelancerServiceOrders,
      path: RoutePaths.freelancerServiceOrders,
      category: CopilotRouteCategory.orders,
      allowedRoles: ['freelancer'],
      keywords: [
        'orders',
        'my orders',
        'freelancer orders',
        'service orders',
        'delivery',
        'submit delivery',
        'deliver work',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'customerServiceRequests',
      title: 'Service Requests',
      description: 'Customer service requests.',
      routeName: RouteNames.serviceRequests,
      path: RoutePaths.serviceRequests,
      category: CopilotRouteCategory.serviceRequests,
      allowedAccountTypes: ['customer'],
      keywords: _serviceRequestKeywords,
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerServiceRequests',
      title: 'Service Requests',
      description: 'Freelancer client requests and project requests.',
      routeName: RouteNames.freelancerServiceRequests,
      path: RoutePaths.freelancerServiceRequests,
      category: CopilotRouteCategory.serviceRequests,
      allowedRoles: ['freelancer'],
      keywords: _serviceRequestKeywords,
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerServices',
      title: 'My Services',
      description: 'Freelancer service studio.',
      routeName: RouteNames.freelancerServices,
      path: RoutePaths.freelancerServices,
      category: CopilotRouteCategory.services,
      allowedRoles: ['freelancer'],
      keywords: ['my services', 'service studio', 'services', 'gig', 'gigs'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerAiAssistant',
      title: 'Freelancer AI Work Assistant',
      description:
          'Draft proposals, delivery notes, service improvements, and evidence summaries.',
      routeName: RouteNames.freelancerAiAssistant,
      path: RoutePaths.freelancerAiAssistant,
      category: CopilotRouteCategory.marketplace,
      allowedRoles: ['freelancer'],
      keywords: [
        'freelancer ai',
        'proposal draft karo',
        'delivery note banao',
        'dispute evidence summarize karo',
        'service improve karo',
        'ai work assistant',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'servicesMarketplace',
      title: 'Services Marketplace',
      description: 'Browse published freelancer services.',
      routeName: RouteNames.servicesMarketplace,
      path: RoutePaths.servicesMarketplace,
      category: CopilotRouteCategory.marketplace,
      keywords: ['services', 'marketplace', 'hire freelancer', 'hire talent'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerDirectory',
      title: 'Freelancer Directory',
      description: 'Hire SkillForge verified freelancers.',
      routeName: RouteNames.freelancerDirectory,
      path: RoutePaths.freelancerDirectory,
      category: CopilotRouteCategory.marketplace,
      keywords: ['freelancers', 'freelancer directory', 'verified talent'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'customerResolution',
      title: 'Resolution Center',
      description: 'Customer dispute, refund, and revision cases.',
      routeName: RouteNames.customerResolutions,
      path: RoutePaths.customerResolutions,
      category: CopilotRouteCategory.resolution,
      allowedAccountTypes: ['customer'],
      keywords: _resolutionKeywords,
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'customerAiAssistant',
      title: 'Customer AI Project Assistant',
      description:
          'Draft service requests, delivery checklists, refund drafts, and freelancer comparisons.',
      routeName: RouteNames.customerAiAssistant,
      path: RoutePaths.customerAiAssistant,
      category: CopilotRouteCategory.marketplace,
      allowedAccountTypes: ['customer'],
      keywords: [
        'customer ai',
        'service request ai se banao',
        'delivery checklist banao',
        'refund draft banao',
        'freelancer compare karo',
        'project assistant',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerResolution',
      title: 'Resolution Center',
      description: 'Freelancer dispute, refund, and revision cases.',
      routeName: RouteNames.freelancerResolutions,
      path: RoutePaths.freelancerResolutions,
      category: CopilotRouteCategory.resolution,
      allowedRoles: ['freelancer'],
      keywords: _resolutionKeywords,
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminResolutionDesk',
      title: 'Resolution Desk',
      description: 'Admin commerce resolution desk.',
      routeName: RouteNames.adminResolutionDesk,
      path: RoutePaths.adminResolutionDesk,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: ['resolution desk', 'admin resolution', 'cases', 'disputes'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminResolutionAiAnalyst',
      title: 'Resolution AI Analyst',
      description: 'Read-only AI analysis for admin resolution cases.',
      routeName: RouteNames.adminResolutionAiAnalyst,
      path: RoutePaths.adminResolutionAiAnalyst,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: [
        'resolution ai analysis karo',
        'case timeline banao',
        'evidence summarize karo',
        'resolution ai analyst',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminAiCredits',
      title: 'AI Credits Center',
      description:
          'Manage AI credits, quotas, costs, requests, and usage logs.',
      routeName: RouteNames.adminAiCredits,
      path: RoutePaths.adminAiCredits,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: [
        'ai credits manage karo',
        'ai usage',
        'ai quota',
        'credit requests',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'freelancerPayouts',
      title: 'Payouts',
      description: 'Freelancer payout requests.',
      routeName: RouteNames.freelancerPayouts,
      path: RoutePaths.freelancerPayouts,
      category: CopilotRouteCategory.payouts,
      allowedRoles: ['freelancer'],
      keywords: _payoutKeywords,
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminPayouts',
      title: 'Payout Review',
      description: 'Admin payout queue.',
      routeName: RouteNames.adminPayouts,
      path: RoutePaths.adminPayouts,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: [
        'payout review',
        'payout queue',
        'admin payouts',
        ..._payoutKeywords,
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'teacherCourses',
      title: 'Teacher Courses',
      description: 'Teacher course management.',
      routeName: RouteNames.teacherCourses,
      path: RoutePaths.teacherCourses,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['teacher'],
      keywords: [
        'courses',
        'my courses',
        'teacher courses',
        'class',
        'learning',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'teacherCourseCreate',
      title: 'Create Course',
      description: 'Create a new course.',
      routeName: RouteNames.teacherCourseCreate,
      path: RoutePaths.teacherCourseCreate,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['teacher'],
      keywords: ['create course', 'add course', 'new course'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'teacherAiCourseBuilder',
      title: 'Create Course with SkillForge AI',
      description: 'Generate a teacher-reviewed AI course blueprint.',
      routeName: RouteNames.teacherAiCourseBuilder,
      path: RoutePaths.teacherAiCourseBuilder,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['teacher'],
      keywords: [
        'create course with ai',
        'ai course builder',
        'skillforge ai course',
        'generate course',
        'course generate karo',
        'ai se course generate karo',
        'course banao',
        'course ai',
      ],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'teacherStudentProgress',
      title: 'Student Progress',
      description: 'Teacher student analytics.',
      routeName: RouteNames.teacherStudentProgress,
      path: RoutePaths.teacherStudentProgress,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['teacher'],
      keywords: ['students', 'student progress', 'analytics', 'progress'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'studentCourses',
      title: 'Find Courses',
      description: 'Student course discovery.',
      routeName: RouteNames.studentCourses,
      path: RoutePaths.studentCourses,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['student'],
      keywords: ['courses', 'find courses', 'discover courses', 'learning'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'studentEnrolledCourses',
      title: 'My Courses',
      description: 'Student enrolled courses.',
      routeName: RouteNames.studentEnrolledCourses,
      path: RoutePaths.studentEnrolledCourses,
      category: CopilotRouteCategory.courses,
      allowedRoles: ['student'],
      keywords: ['my courses', 'enrolled courses', 'continue learning'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'studentCertificates',
      title: 'Certificates',
      description: 'Student certificate wallet.',
      routeName: RouteNames.studentCertificates,
      path: RoutePaths.studentCertificates,
      category: CopilotRouteCategory.certificates,
      allowedRoles: ['student'],
      keywords: ['certificates', 'certificate wallet', 'certificate dikhao'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'teacherCertificates',
      title: 'Teacher Certificates',
      description: 'Teacher certificates need a course context.',
      routeName: RouteNames.teacherCertificates,
      path: RoutePaths.teacherCertificates,
      category: CopilotRouteCategory.certificates,
      allowedRoles: ['teacher'],
      keywords: ['certificates', 'issue certificate', 'teacher certificates'],
      synonyms: commonRomanUrdu,
      isAvailable: false,
      unavailableReason:
          'Teacher certificates need a course. Open Teacher Courses first.',
    ),
    CopilotRouteDestination(
      id: 'studentResume',
      title: 'Smart Resume',
      description: 'Student smart resume builder.',
      routeName: RouteNames.studentResume,
      path: RoutePaths.studentResume,
      category: CopilotRouteCategory.smartResume,
      allowedRoles: ['student'],
      keywords: ['smart resume', 'resume', 'cv', 'resume builder'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'studentSkillScores',
      title: 'Skill Scores',
      description: 'Student skill score portfolio.',
      routeName: RouteNames.studentSkillScores,
      path: RoutePaths.studentSkillScores,
      category: CopilotRouteCategory.smartResume,
      allowedRoles: ['student'],
      keywords: ['skill scores', 'skills', 'portfolio', 'skill score'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'jobs',
      title: 'Jobs',
      description: 'Browse jobs.',
      routeName: RouteNames.jobList,
      path: RoutePaths.jobList,
      category: CopilotRouteCategory.jobs,
      allowedRoles: ['student', 'freelancer'],
      keywords: ['jobs', 'job posts', 'browse jobs', 'find job'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'myApplications',
      title: 'Applications',
      description: 'My job applications.',
      routeName: RouteNames.myApplications,
      path: RoutePaths.myApplications,
      category: CopilotRouteCategory.jobs,
      allowedRoles: ['student', 'freelancer'],
      keywords: ['applications', 'my applications', 'job applications'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'companyJobs',
      title: 'Job Posts',
      description: 'Company job management.',
      routeName: RouteNames.companyJobs,
      path: RoutePaths.companyJobs,
      category: CopilotRouteCategory.companyHiring,
      allowedRoles: ['company'],
      keywords: ['jobs', 'job posts', 'manage jobs', 'company jobs'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'createJob',
      title: 'Post a Job',
      description: 'Create a company job post.',
      routeName: RouteNames.createJob,
      path: RoutePaths.createJob,
      category: CopilotRouteCategory.companyHiring,
      allowedRoles: ['company'],
      keywords: ['post a job', 'create job', 'new job', 'add job'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'hiringPipeline',
      title: 'Hiring Pipeline',
      description: 'Company hiring pipeline and candidates.',
      routeName: RouteNames.hiringPipeline,
      path: RoutePaths.hiringPipeline,
      category: CopilotRouteCategory.companyHiring,
      allowedRoles: ['company'],
      keywords: ['hiring', 'hiring pipeline', 'candidates', 'applications'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'companyAiHiringAssistant',
      title: 'AI Hiring Assistant',
      description:
          'Company AI assistant for job posts, candidates, interviews, and pipeline insights.',
      routeName: RouteNames.companyAiHiringAssistant,
      path: RoutePaths.companyAiHiringAssistant,
      category: CopilotRouteCategory.companyHiring,
      allowedRoles: ['company'],
      keywords: [
        'ai hiring assistant',
        'hiring ai',
        'job post ai',
        'candidate summarize',
        'compare applicants',
        'interview questions',
        'pipeline insights',
        'candidate message draft',
      ],
      synonyms: [
        ...commonRomanUrdu,
        'ai hiring assistant kholo',
        'job post ai se banao',
        'candidate summarize karo',
        'interview questions banao',
        'applicants compare karo',
        'pipeline insights dikhao',
        'candidate message draft karo',
      ],
    ),
    CopilotRouteDestination(
      id: 'myInterviews',
      title: 'Interviews',
      description: 'Interview center.',
      routeName: RouteNames.myInterviews,
      path: RoutePaths.myInterviews,
      category: CopilotRouteCategory.companyHiring,
      allowedRoles: ['company', 'freelancer'],
      keywords: ['interviews', 'my interviews', 'interview center'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'profileStudent',
      title: 'Profile',
      description: 'Student profile.',
      routeName: RouteNames.studentProfile,
      path: RoutePaths.studentProfile,
      category: CopilotRouteCategory.profile,
      allowedRoles: ['student'],
      keywords: ['profile', 'my profile', 'student profile'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'profileTeacher',
      title: 'Profile',
      description: 'Teacher profile.',
      routeName: RouteNames.teacherProfile,
      path: RoutePaths.teacherProfile,
      category: CopilotRouteCategory.profile,
      allowedRoles: ['teacher'],
      keywords: ['profile', 'my profile', 'teacher profile'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'profileFreelancer',
      title: 'Profile',
      description: 'Freelancer profile.',
      routeName: RouteNames.freelancerProfile,
      path: RoutePaths.freelancerProfile,
      category: CopilotRouteCategory.profile,
      allowedRoles: ['freelancer'],
      keywords: ['profile', 'my profile', 'freelancer profile'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'profileCompany',
      title: 'Company Profile',
      description: 'Company profile.',
      routeName: RouteNames.companyProfile,
      path: RoutePaths.companyProfile,
      category: CopilotRouteCategory.profile,
      allowedRoles: ['company'],
      keywords: ['profile', 'company profile'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'profileCustomer',
      title: 'Profile',
      description: 'Customer profile settings.',
      routeName: RouteNames.profilePersonal,
      path: RoutePaths.profilePersonal,
      category: CopilotRouteCategory.profile,
      allowedAccountTypes: ['customer'],
      keywords: ['profile', 'my profile', 'personal profile'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'settings',
      title: 'Settings',
      description: 'Account security and settings.',
      routeName: RouteNames.securitySettings,
      path: RoutePaths.securitySettings,
      category: CopilotRouteCategory.settings,
      keywords: ['settings', 'security', 'account settings'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'support',
      title: 'Support',
      description: 'Contact SkillForge support.',
      routeName: RouteNames.contactUs,
      path: RoutePaths.contactUs,
      category: CopilotRouteCategory.support,
      keywords: ['support', 'contact', 'help center', 'ticket', 'help'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'privacy',
      title: 'Privacy Policy',
      description: 'SkillForge privacy policy.',
      routeName: RouteNames.privacyPolicy,
      path: RoutePaths.privacyPolicy,
      category: CopilotRouteCategory.legal,
      keywords: ['privacy', 'privacy policy'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'terms',
      title: 'Terms of Service',
      description: 'SkillForge terms of service.',
      routeName: RouteNames.termsOfService,
      path: RoutePaths.termsOfService,
      category: CopilotRouteCategory.legal,
      keywords: ['terms', 'terms of service', 'legal terms'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminUsers',
      title: 'Users',
      description: 'Admin user management.',
      routeName: RouteNames.adminUserManagement,
      path: RoutePaths.adminUserManagement,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: ['users', 'user management', 'manage users'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminLogs',
      title: 'Audit Logs',
      description: 'Admin audit logs.',
      routeName: RouteNames.adminAuditLogs,
      path: RoutePaths.adminAuditLogs,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: ['logs', 'audit logs', 'activity logs'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminFinance',
      title: 'Finance Center',
      description: 'Admin finance analytics.',
      routeName: RouteNames.adminFinanceCenter,
      path: RoutePaths.adminFinanceCenter,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: ['finance', 'finance center', 'revenue', 'analytics'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminLegal',
      title: 'Legal CMS',
      description: 'Admin legal content editor.',
      routeName: RouteNames.adminLegalEditor,
      path: RoutePaths.adminLegalEditor,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['admin', 'superadmin'],
      keywords: ['legal cms', 'legal editor', 'privacy editor', 'terms editor'],
      synonyms: commonRomanUrdu,
    ),
    CopilotRouteDestination(
      id: 'adminSettings',
      title: 'Admin Settings',
      description: 'Platform settings.',
      routeName: RouteNames.adminSettings,
      path: RoutePaths.adminSettings,
      category: CopilotRouteCategory.admin,
      allowedRoles: ['superadmin'],
      keywords: ['admin settings', 'platform settings'],
      synonyms: commonRomanUrdu,
    ),
  ];

  static CopilotRouteDestination? byId(String? id) {
    if (id == null) return null;
    for (final destination in destinations) {
      if (destination.id == id) return destination;
    }
    return null;
  }

  static List<CopilotRouteDestination> allowedFor({
    required String? role,
    required String? accountType,
    bool onlyAvailable = true,
  }) {
    final normalizedRole = normalizeRole(role);
    final normalizedAccountType = normalizeAccountType(accountType);
    return destinations
        .where((destination) {
          if (onlyAvailable && !destination.isAvailable) return false;
          return isAllowed(
            destination,
            role: normalizedRole,
            accountType: normalizedAccountType,
          );
        })
        .toList(growable: false);
  }

  static bool isAllowed(
    CopilotRouteDestination destination, {
    required String? role,
    required String? accountType,
  }) {
    final normalizedRole = normalizeRole(role);
    final normalizedAccountType = normalizeAccountType(accountType);
    if (destination.allowedRoles.isEmpty &&
        destination.allowedAccountTypes.isEmpty) {
      return true;
    }
    if (destination.allowedAccountTypes.contains(normalizedAccountType)) {
      return true;
    }
    if (destination.allowedRoles.contains(normalizedRole)) return true;
    if (destination.allowedRoles.contains('admin') &&
        normalizedRole == 'superadmin') {
      return true;
    }
    return false;
  }

  static List<String> suggestionsForRole({
    required String? role,
    required String? accountType,
    int limit = 7,
  }) {
    return allowedFor(role: role, accountType: accountType)
        .take(limit)
        .map((destination) => destination.title)
        .toList(growable: false);
  }

  static CopilotRouteMatch? bestMatch({
    required String query,
    required String? role,
    required String? accountType,
  }) {
    final normalizedQuery = normalizeQuery(query);
    if (normalizedQuery.isEmpty) return null;
    final normalizedRole = normalizeRole(role);
    final normalizedAccountType = normalizeAccountType(accountType);

    CopilotRouteMatch? best;
    for (final destination in destinations) {
      final result = _scoreDestination(
        destination,
        normalizedQuery,
        role: normalizedRole,
        accountType: normalizedAccountType,
      );
      if (result == null) continue;
      if (best == null || result.score > best.score) best = result;
    }
    return best;
  }

  static CopilotRouteMatch? _scoreDestination(
    CopilotRouteDestination destination,
    String query, {
    required String role,
    required String accountType,
  }) {
    var bestScore = 0;
    var bestKeyword = '';
    final allowed = isAllowed(
      destination,
      role: role,
      accountType: accountType,
    );

    for (final term in destination.searchableTerms) {
      final keyword = normalizeQuery(term);
      if (keyword.isEmpty) continue;
      var score = 0;
      if (query == keyword) {
        score = 100;
      } else if (query.contains(keyword)) {
        score = keyword.length >= 8 ? 82 : 62;
      } else if (keyword.contains(query) && query.length >= 4) {
        score = 56;
      }
      if (destination.category == query) score = score < 48 ? 48 : score;
      if (allowed) score += 30;
      if (!destination.isAvailable) score -= 10;
      if (score > bestScore) {
        bestScore = score;
        bestKeyword = keyword;
      }
    }

    if (bestScore <= 0) return null;
    return CopilotRouteMatch(
      destination: destination,
      score: bestScore,
      matchedKeyword: bestKeyword,
    );
  }
}

const _serviceRequestKeywords = [
  'service request',
  'service requests',
  'request',
  'requests',
  'meri requests',
  'pending requests',
  'accepted requests',
  'client request',
  'client requests',
  'freelancer request',
  'kaam ki request',
  'project request',
  'request open karo',
  'requests dikhao',
  'service request open karo',
];

const _resolutionKeywords = [
  'resolution',
  'resolution center',
  'my cases',
  'cases',
  'refund case',
  'dispute case',
  'revision case',
  'case open karo',
  'refund',
  'dispute',
  'revision',
];

const _payoutKeywords = [
  'payout',
  'payouts',
  'withdraw',
  'withdrawal',
  'earning',
  'earnings',
  'available balance',
  'payout request',
  'freelancer payout',
];

String normalizeRole(String? value) {
  final normalized = normalizeToken(value);
  if (normalized == 'superadmin' || normalized == 'super_admin') {
    return 'superadmin';
  }
  return normalized;
}

String normalizeAccountType(String? value) {
  final normalized = normalizeToken(value);
  return normalized == 'customer' ? 'customer' : normalized;
}

String normalizeQuery(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizeToken(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '')
      .trim();
}
