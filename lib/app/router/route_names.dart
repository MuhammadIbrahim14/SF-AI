/// SkillForge AI — Named Route Constants
/// Eliminates magic strings across the codebase.
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String home = 'home';
  static const String appOnboarding = 'app-onboarding';
  static const String onboarding = 'onboarding';
  static const String roleSelection = 'role-selection';

  static const String login = 'login';
  static const String signup = 'signup';
  static const String forgotPassword = 'forgot-password';
  static const String accountBlocked = 'account-blocked';
  static const String maintenance = 'maintenance';
  static const String appLock = 'app-lock';
  static const String privacyPolicy = 'privacy-policy';
  static const String termsOfService = 'terms-of-service';
  static const String accountDeletionPolicy = 'account-deletion-policy';
  static const String returnRefundPolicy = 'return-refund-policy';
  static const String shippingServicePolicy = 'shipping-service-policy';
  static const String contactUs = 'contact-us';
  static const String downloads = 'downloads';
  static const String releaseCenter = 'release-center';
  static const String mySupportRequests = 'my-support-requests';
  static const String supportRequestDetail = 'support-request-detail';
  static const String notificationsInbox = 'notifications-inbox';
  static const String freelancerDirectory = 'freelancer-directory';
  static const String servicesMarketplace = 'services-marketplace';
  static const String publicServiceDetail = 'public-service-detail';
  static const String serviceRequests = 'service-requests';
  static const String serviceRequestDetail = 'service-request-detail';
  static const String serviceOrders = 'service-orders';
  static const String serviceOrderDetail = 'service-order-detail';
  static const String invoices = 'invoices';
  static const String invoiceDetail = 'invoice-detail';
  static const String customerResolutions = 'customer-resolutions';
  static const String customerWallet = 'customer-wallet';
  static const String customerAiAssistant = 'customer-ai-assistant';

  static const String studentOnboarding = 'student-onboarding';
  static const String teacherOnboarding = 'teacher-onboarding';
  static const String freelancerOnboarding = 'freelancer-onboarding';
  static const String companyOnboarding = 'company-onboarding';

  static const String dashboard = 'dashboard';
  static const String customerDashboard = 'customer-dashboard';

  static const String studentDashboard = 'student-dashboard';
  static const String studentAiTutor = 'student-ai-tutor';
  static const String studentCourses = 'student-courses';
  static const String studentCourseDetail = 'student-course-detail';
  static const String studentEnrolledCourses = 'student-enrolled-courses';
  static const String studentPaidCourses = 'student-paid-courses';
  static const String studentCourseLearn = 'student-course-learn';
  static const String studentLessonDetail = 'student-lesson-detail';
  static const String studentAssignments = 'student-assignments';
  static const String studentAssignmentAttempt = 'student-assignment-attempt';
  static const String studentAssignmentResult = 'student-assignment-result';
  static const String studentProjectSubmission = 'student-project-submission';
  static const String studentProjectStatus = 'student-project-status';
  static const String studentGrandTestOverview = 'student-grand-test-overview';
  static const String studentGrandTestAttempt = 'student-grand-test-attempt';
  static const String studentGrandTestResult = 'student-grand-test-result';
  static const String studentCertificates = 'student-certificates';
  static const String studentCertificateDetail = 'student-certificate-detail';
  static const String studentSkillScores = 'student-skill-scores';
  static const String studentSkillScoreDetail = 'student-skill-score-detail';
  static const String studentCareerRoadmap = 'student-career-roadmap';
  static const String studentFreelancerBridge = 'student-freelancer-bridge';
  static const String studentResume = 'student-resume';
  static const String studentResumePreview = 'student-resume-preview';
  /// Role-scoped applications path (SIE / deep links); same screen as my-applications.
  static const String studentApplications = 'student-applications';

  /// AI Interview Lab (practice) — student & freelancer; not hiring interviews.
  static const String interviewLab = 'interview-lab';
  /// Alias kept for SIE / deep-link callers (same destination as [interviewLab]).
  static const String interviewLabHome = interviewLab;
  static const String interviewLabStart = 'interview-lab-start';
  static const String interviewLabSession = 'interview-lab-session';
  static const String interviewLabReport = 'interview-lab-report';
  static const String interviewLabHistory = 'interview-lab-history';
  static const String teacherDashboard = 'teacher-dashboard';
  static const String teacherPurchaseHistory = 'teacher-purchase-history';
  static const String teacherPaymentMethods = 'teacher-payment-methods';
  static const String teacherPlans = 'teacher-plans';
  static const String teacherPaidCourses = 'teacher-paid-courses';
  static const String teacherEarnings = 'teacher-earnings';
  static const String teacherWallet = 'teacher-wallet';
  static const String myTransactions = 'my-transactions';
  static const String adminSuperTransactions = 'admin-super-transactions';
  static const String creditPacks = 'credit-packs';
  /// Legacy name for teacher purchase history (path still registered).
  static const String purchaseHistory = 'purchase-history';
  static const String teacherCourses = 'teacher-courses';
  static const String teacherAiCourseBuilder = 'teacher-ai-course-builder';
  static const String teacherCourseCreate = 'teacher-course-create';
  static const String teacherCourseEdit = 'teacher-course-edit';
  static const String teacherCourseDetail = 'teacher-course-detail';
  static const String teacherCourseLessons = 'teacher-course-lessons';
  static const String teacherLessonCreate = 'teacher-lesson-create';
  static const String teacherLessonEdit = 'teacher-lesson-edit';
  static const String teacherAssignments = 'teacher-assignments';
  static const String teacherAssignmentCreate = 'teacher-assignment-create';
  static const String teacherAssignmentEdit = 'teacher-assignment-edit';
  static const String teacherAssignmentResults = 'teacher-assignment-results';
  static const String teacherProjectAssignments = 'teacher-project-assignments';
  static const String teacherProjectAssignmentCreate =
      'teacher-project-assignment-create';
  static const String teacherProjectAssignmentEdit =
      'teacher-project-assignment-edit';
  static const String teacherProjectSubmissions = 'teacher-project-submissions';
  static const String teacherProjectReview = 'teacher-project-review';
  static const String teacherGrandTests = 'teacher-grand-tests';
  static const String teacherGrandTestCreate = 'teacher-grand-test-create';
  static const String teacherGrandTestEdit = 'teacher-grand-test-edit';
  static const String teacherGrandTestEligibility =
      'teacher-grand-test-eligibility';
  static const String teacherGrandTestAttempts = 'teacher-grand-test-attempts';
  static const String teacherCertificates = 'teacher-certificates';
  static const String teacherCertificateEligible =
      'teacher-certificate-eligible';
  static const String teacherStudentProgress = 'teacher-student-progress';
  static const String teacherStudentProgressDetail =
      'teacher-student-progress-detail';
  static const String teacherBatches = 'teacher-batches';
  static const String teacherBatchesCompare = 'teacher-batches-compare';
  static const String teacherBatchDetail = 'teacher-batch-detail';
  static const String studentMyBatches = 'student-my-batches';
  static const String studentBatchDetail = 'student-batch-detail';
  static const String studentJoinBatch = 'student-join-batch';
  static const String studentClassAnnouncements = 'student-class-announcements';
  static const String freelancerDashboard = 'freelancer-dashboard';
  static const String freelancerPortfolioStudio = 'freelancer-portfolio-studio';
  static const String freelancerServices = 'freelancer-services';
  static const String freelancerServiceCreate = 'freelancer-service-create';
  static const String freelancerServiceEdit = 'freelancer-service-edit';
  static const String freelancerServiceRequests = 'freelancer-service-requests';
  static const String freelancerServiceOrders = 'freelancer-service-orders';
  static const String freelancerWallet = 'freelancer-wallet';
  static const String freelancerInvoices = 'freelancer-invoices';
  static const String freelancerInvoiceDetail = 'freelancer-invoice-detail';
  static const String freelancerPayouts = 'freelancer-payouts';
  static const String freelancerResolutions = 'freelancer-resolutions';
  static const String freelancerAiAssistant = 'freelancer-ai-assistant';
  /// Role-scoped applications path (SIE / deep links); same screen as my-applications.
  static const String freelancerApplications = 'freelancer-applications';
  static const String companyDashboard = 'company-dashboard';
  static const String adminDashboard = 'admin-dashboard';
  static const String adminInbox = 'admin-inbox';
  static const String superAdminDashboard = 'super-admin-dashboard';
  static const String studentProfile = 'student-profile';
  static const String studentEditProfile = 'student-edit-profile';
  static const String teacherProfile = 'teacher-profile';
  static const String teacherEditProfile = 'teacher-edit-profile';
  static const String freelancerProfile = 'freelancer-profile';
  static const String freelancerEditProfile = 'freelancer-edit-profile';
  static const String companyProfile = 'company-profile';
  static const String companyEditProfile = 'company-edit-profile';
  static const String securitySettings = 'security-settings';
  static const String setupPin = 'setup-pin';
  static const String changePin = 'change-pin';
  static const String disablePin = 'disable-pin';
  static const String profilePersonal = 'profile-personal';
  static const String profileProfessional = 'profile-professional';
  static const String profilePortfolio = 'profile-portfolio';
  static const String profilePreferences = 'profile-preferences';
  static const String profileNotifications = 'profile-notifications';
  static const String profileAccountSettings = 'profile-account-settings';
  static const String portfolioBuilder = 'portfolio-builder';

  static const String adminUserManagement = 'admin-user-management';
  static const String adminManagement = 'admin-management';
  static const String adminRecovery = 'admin-recovery';
  static const String adminVerification = 'admin-verification';
  static const String adminSettings = 'admin-settings';
  static const String adminThemeSettings = 'admin-theme-settings';
  static const String adminMotionSettings = 'admin-motion-settings';
  static const String adminSieControl = 'admin-sie-control';
  static const String adminLanguageSettings = 'admin-language-settings';
  static const String adminInterviewLab = 'admin-interview-lab';
  static const String adminAuditLogs = 'admin-audit-logs';
  static const String adminLegalEditor = 'admin-legal-editor';
  static const String adminReleaseCenter = 'admin-release-center';
  static const String adminCommerceOrders = 'admin-commerce-orders';
  static const String adminFinanceCenter = 'admin-finance-center';
  static const String adminFinanceDetail = 'admin-finance-detail';
  static const String adminInvoices = 'admin-invoices';
  static const String adminInvoiceDetail = 'admin-invoice-detail';
  static const String adminPayouts = 'admin-payouts';
  static const String adminResolutionDesk = 'admin-resolution-desk';
  static const String adminResolutionAiAnalyst = 'admin-resolution-ai-analyst';
  static const String adminAiUsageControl = 'admin-ai-usage-control';
  static const String adminAiCredits = 'admin-ai-credits';
  static const String adminEmailSettings = 'admin-email-settings';
    static const String adminMonetization = 'admin-monetization';

  static const String jobList = 'job-list';
  static const String jobDetail = 'job-detail';
  static const String createJob = 'create-job';
  static const String editJob = 'edit-job';
  static const String companyJobs = 'company-jobs';
  static const String companyAiHiringAssistant = 'company-ai-hiring-assistant';
  static const String hiringPipeline = 'hiring-pipeline';
  static const String jobHiringPipeline = 'job-hiring-pipeline';
  static const String companyCandidateIntelligence =
      'company-candidate-intelligence';
  static const String companyCandidateCompare = 'company-candidate-compare';
  static const String companyInterviewLabReport =
      'company-interview-lab-report';
  static const String companyEmployees = 'company-employees';
  static const String companyEmployeeDetail = 'company-employee-detail';
  static const String companyHiringAnalytics = 'company-hiring-analytics';
  static const String careerIntelligence = 'career-intelligence';
  static const String scheduleInterview = 'schedule-interview';
  static const String interviewDetail = 'interview-detail';
  static const String evaluateInterview = 'evaluate-interview';

  static const String myApplications = 'my-applications';
  static const String myEmployment = 'my-employment';
  static const String myEmploymentDetail = 'my-employment-detail';
  static const String jobApplicants = 'job-applicants';
  static const String myInterviews = 'my-interviews';
  static const String myInterviewDetail = 'my-interview-detail';
}

/// Route path constants.
class RoutePaths {
  static const String splash = '/';
  static const String home = '/home';
  static const String appOnboarding = '/app-onboarding';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String accountBlocked = '/account-blocked';
  static const String maintenance = '/maintenance';
  static const String appLock = '/app-lock';
  static const String privacyPolicy = '/legal/privacy-policy';
  static const String termsOfService = '/legal/terms-of-service';
  static const String accountDeletionPolicy = '/legal/account-deletion-policy';
  static const String returnRefundPolicy = '/legal/return-refund-policy';
  static const String shippingServicePolicy = '/legal/shipping-service-policy';
  static const String contactUs = '/contact';
  static const String downloads = '/downloads';
  static const String releaseCenter = '/release-center';
  static const String mySupportRequests = '/support/my-requests';
  static const String supportRequestDetail = '/support/my-requests/:messageId';
  static const String notificationsInbox = '/notifications';
  static const String freelancerDirectory = '/freelancers';
  static const String servicesMarketplace = '/services';
  static const String publicServiceDetail = '/services/:serviceId';
  static const String serviceRequests = '/service-requests';
  static const String serviceRequestDetail = '/service-requests/:requestId';
  static const String serviceOrders = '/orders';
  static const String serviceOrderDetail = '/orders/:orderId';
  static const String invoices = '/invoices';
  static const String invoiceDetail = '/invoices/:invoiceId';
  static const String customerResolutions = '/resolutions';
  static const String customerWallet = '/wallet';
  static const String customerAiAssistant = '/customer/ai-assistant';
  static const String roleSelection = '/role-selection';

  // Role Onboarding
  static const String studentOnboarding = '/onboarding/student';
  static const String teacherOnboarding = '/onboarding/teacher';
  static const String freelancerOnboarding = '/onboarding/freelancer';
  static const String companyOnboarding = '/onboarding/company';

  // Dashboards
  static const String dashboard = '/dashboard';
  static const String customerDashboard = '/dashboard/customer';
  static const String studentDashboard = '/dashboard/student';
  static const String studentAiTutor = '/student/ai-tutor';
  static const String studentCourses = '/student/courses';
  static const String studentCourseDetail = '/student/courses/detail/:courseId';
  static const String studentEnrolledCourses = '/student/courses/enrolled';
  static const String studentPaidCourses = '/student/courses/paid';
  static const String studentCourseLearn = '/student/courses/learn/:courseId';
  static const String studentLessonDetail =
      '/student/courses/lesson/:courseId/:lessonId';
  static const String studentAssignments =
      '/student/courses/assignments/:courseId';
  static const String studentAssignmentAttempt =
      '/student/courses/assignments/mcq/:courseId/:assignmentId';
  static const String studentAssignmentResult =
      '/student/courses/assignments/result/:courseId/:assignmentId';
  static const String studentProjectSubmission =
      '/student/courses/project/submit/:courseId/:assignmentId';
  static const String studentProjectStatus =
      '/student/courses/project/status/:courseId/:assignmentId';
  static const String studentGrandTestOverview =
      '/student/courses/grand-test/:courseId';
  static const String studentGrandTestAttempt =
      '/student/courses/grand-test/attempt/:courseId/:grandTestId';
  static const String studentGrandTestResult =
      '/student/courses/grand-test/result/:courseId/:grandTestId';
  static const String studentCertificates = '/student/certificates';
  static const String studentCertificateDetail =
      '/student/certificates/detail/:certificateId';
  static const String studentSkillScores = '/student/skill-scores';
  static const String studentSkillScoreDetail =
      '/student/skill-scores/detail/:skillName';
  static const String studentCareerRoadmap = '/student/career-roadmap';
  static const String studentFreelancerBridge = '/student/freelancer-bridge';
  static const String studentResume = '/student/resume';
  static const String studentResumePreview = '/student/resume/preview';
  static const String studentApplications = '/student/applications';

  /// Shared practice lab for student & freelancer (not company hiring).
  static const String interviewLab = '/interview-lab';
  static const String interviewLabHome = interviewLab;
  static const String interviewLabStart = '/interview-lab/start';
  static const String interviewLabSession = '/interview-lab/session/:sessionId';
  static const String interviewLabReport = '/interview-lab/report/:sessionId';
  static const String interviewLabHistory = '/interview-lab/history';

  static const String teacherDashboard = '/dashboard/teacher';
  static const String teacherPurchaseHistory = '/teacher/purchase-history';
  static const String teacherPaymentMethods = '/teacher/payment-methods';
  static const String teacherPlans = '/teacher/plans';
  static const String teacherPaidCourses = '/teacher/paid-courses';
  static const String teacherEarnings = '/teacher/earnings';
  static const String teacherWallet = '/teacher/wallet';
  static const String myTransactions = '/billing/transactions';
  static const String adminSuperTransactions = '/admin/super-transactions';
  static const String creditPacks = '/billing/credit-packs';
  static const String purchaseHistory = '/billing/purchase-history';
  static const String teacherCourses = '/teacher/courses';
  static const String teacherAiCourseBuilder = '/teacher/ai-course-builder';
  static const String teacherCourseCreate = '/teacher/courses/create';
  static const String teacherCourseEdit = '/teacher/courses/edit/:courseId';
  static const String teacherCourseDetail = '/teacher/courses/detail/:courseId';
  static const String teacherCourseLessons =
      '/teacher/courses/lessons/:courseId';
  static const String teacherLessonCreate =
      '/teacher/courses/lessons/create/:courseId';
  static const String teacherLessonEdit =
      '/teacher/courses/lessons/edit/:courseId/:lessonId';
  static const String teacherAssignments =
      '/teacher/courses/assignments/:courseId';
  static const String teacherAssignmentCreate =
      '/teacher/courses/assignments/create/:courseId';
  static const String teacherAssignmentEdit =
      '/teacher/courses/assignments/edit/:courseId/:assignmentId';
  static const String teacherAssignmentResults =
      '/teacher/courses/assignments/results/:courseId/:assignmentId';
  static const String teacherProjectAssignments =
      '/teacher/courses/assignments/project/:courseId';
  static const String teacherProjectAssignmentCreate =
      '/teacher/courses/assignments/project/create/:courseId';
  static const String teacherProjectAssignmentEdit =
      '/teacher/courses/assignments/project/edit/:courseId/:assignmentId';
  static const String teacherProjectSubmissions =
      '/teacher/courses/assignments/project/submissions/:courseId/:assignmentId';
  static const String teacherProjectReview =
      '/teacher/courses/assignments/project/review/:courseId/:assignmentId/:studentId';
  static const String teacherGrandTests =
      '/teacher/courses/grand-tests/:courseId';
  static const String teacherGrandTestCreate =
      '/teacher/courses/grand-tests/create/:courseId';
  static const String teacherGrandTestEdit =
      '/teacher/courses/grand-tests/edit/:courseId/:grandTestId';
  static const String teacherGrandTestEligibility =
      '/teacher/courses/grand-tests/eligibility/:courseId/:grandTestId';
  static const String teacherGrandTestAttempts =
      '/teacher/courses/grand-tests/attempts/:courseId/:grandTestId';
  static const String teacherCertificates = '/teacher/certificates/:courseId';
  static const String teacherCertificateEligible =
      '/teacher/certificates/eligible/:courseId';
  static const String teacherStudentProgress = '/teacher/analytics/students';
  static const String teacherStudentProgressDetail =
      '/teacher/analytics/students/:studentId';
  static const String teacherBatches = '/teacher/batches';
  static const String teacherBatchesCompare = '/teacher/batches/compare';
  static const String teacherBatchDetail = '/teacher/batches/:batchId';
  static const String studentMyBatches = '/student/class-batches';
  static const String studentBatchDetail = '/student/class-batches/:batchId';
  static const String studentJoinBatch = '/student/class-batches/join';
  static const String studentClassAnnouncements =
      '/student/class-batches/announcements';
  static const String freelancerDashboard = '/dashboard/freelancer';
  static const String freelancerPortfolioStudio =
      '/freelancer/portfolio-studio';
  static const String freelancerServices = '/freelancer/services';
  static const String freelancerServiceCreate = '/freelancer/services/new';
  static const String freelancerServiceEdit =
      '/freelancer/services/:serviceId/edit';
  static const String freelancerServiceRequests =
      '/freelancer/service-requests';
  static const String freelancerServiceOrders = '/freelancer/orders';
  static const String freelancerWallet = '/freelancer/wallet';
  static const String freelancerInvoices = '/freelancer/invoices';
  static const String freelancerInvoiceDetail =
      '/freelancer/invoices/:invoiceId';
  static const String freelancerPayouts = '/freelancer/payouts';
  static const String freelancerResolutions = '/freelancer/resolutions';
  static const String freelancerAiAssistant = '/freelancer/ai-assistant';
  static const String freelancerApplications = '/freelancer/applications';
  static const String companyDashboard = '/dashboard/company';
  static const String adminDashboard = '/dashboard/admin';
  static const String adminInbox = '/admin/inbox';
  static const String superAdminDashboard = '/dashboard/super-admin';
  static const String studentProfile = '/profile/student';
  static const String studentEditProfile = '/profile/student/edit';
  static const String teacherProfile = '/profile/teacher';
  static const String teacherEditProfile = '/profile/teacher/edit';
  static const String freelancerProfile = '/profile/freelancer';
  static const String freelancerEditProfile = '/profile/freelancer/edit';
  static const String companyProfile = '/profile/company';
  static const String companyEditProfile = '/profile/company/edit';
  static const String securitySettings = '/settings/security';
  static const String setupPin = '/profile/security/setup-pin';
  static const String changePin = '/profile/security/change-pin';
  static const String disablePin = '/profile/security/disable-pin';
  static const String profilePersonal = '/settings/profile/personal';
  static const String profileProfessional = '/settings/profile/professional';
  static const String profilePortfolio = '/settings/profile/portfolio';
  static const String profilePreferences = '/settings/profile/preferences';
  static const String profileNotifications = '/settings/profile/notifications';
  static const String profileAccountSettings = '/settings/profile/account';
  static const String portfolioBuilder = '/settings/profile/portfolio-builder';

  static const String adminUserManagement = '/admin/users';
  static const String adminManagement = '/admin/admins';
  static const String adminRecovery = '/admin/recovery';
  static const String adminVerification = '/admin/verification';
  static const String adminSettings = '/admin/settings';
  static const String adminThemeSettings = '/admin/settings/theme';
  static const String adminMotionSettings = '/admin/settings/motion';
  static const String adminSieControl = '/admin/settings/sie';
  static const String adminLanguageSettings = '/admin/settings/language';
  static const String adminInterviewLab = '/admin/settings/interview-lab';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminLegalEditor = '/admin/settings/legal';
  static const String adminReleaseCenter = '/admin/settings/release-center';
  static const String adminCommerceOrders = '/admin/commerce/orders';
  static const String adminFinanceCenter = '/admin/commerce/finance';
  static const String adminFinanceDetail = '/admin/commerce/finance/:type/:id';
  static const String adminInvoices = '/admin/commerce/invoices';
  static const String adminInvoiceDetail =
      '/admin/commerce/invoices/:invoiceId';
  static const String adminPayouts = '/admin/commerce/payouts';
  static const String adminResolutionDesk = '/admin/commerce/resolutions';
  static const String adminResolutionAiAnalyst = '/admin/resolution-ai-analyst';
  static const String adminAiUsageControl = '/admin/ai-usage';
  static const String adminAiCredits = '/admin/ai-credits';
  static const String adminEmailSettings = '/admin/email-settings';
    static const String adminMonetization = '/admin/monetization';

  static const String jobList = '/jobs';
  static const String jobDetail = '/jobs/detail/:id';
  static const String createJob = '/jobs/create';
  static const String editJob = '/jobs/edit/:id';
  static const String companyJobs = '/company-jobs';
  static const String companyAiHiringAssistant = '/company/ai-hiring-assistant';
  static const String hiringPipeline = '/company/hiring';
  static const String jobHiringPipeline = '/company/jobs/:jobId/pipeline';
  static const String companyCandidateIntelligence =
      '/company/candidates/:applicationId';
  static const String companyCandidateCompare = '/company/candidates-compare';
  static const String companyInterviewLabReport =
      '/company/interview-lab/report/:sessionId';
  static const String companyEmployees = '/company/employees';
  static const String companyEmployeeDetail =
      '/company/employees/:applicationId';
  static const String companyHiringAnalytics = '/company/hiring-analytics';
  static const String careerIntelligence = '/career-intelligence';
  static const String scheduleInterview =
      '/company/interviews/schedule/:applicationId';
  static const String interviewDetail =
      '/company/interviews/detail/:interviewId';
  static const String evaluateInterview =
      '/company/interviews/evaluate/:interviewId';

  static const String myApplications = '/my-applications';
  static const String myEmployment = '/my-employment';
  static const String myEmploymentDetail = '/my-employment/:applicationId';
  static const String jobApplicants = '/job-applicants/:id';
  static const String myInterviews = '/my-interviews';
  static const String myInterviewDetail = '/my-interviews/detail/:interviewId';
}
