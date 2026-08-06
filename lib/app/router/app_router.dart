import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/account_blocked_screen.dart';
import '../../features/system/presentation/maintenance_screen.dart';
import 'package:skillforge_ai/core/theme/app_colors.dart';
import '../../features/admin/presentation/admin_dashboard.dart';
import '../../features/admin/presentation/admin_inbox_screen.dart';
import '../../features/admin/presentation/admin_email_settings_screen.dart';
import '../../features/admin/presentation/admin_ai_usage_control_screen.dart';
import '../../features/admin/presentation/monetization_center.dart';
import '../../features/support/presentation/my_support_requests_screen.dart';
import '../../features/support/presentation/my_support_request_detail_screen.dart';
import '../../features/admin/presentation/admin_management_screen.dart';
import '../../features/admin/presentation/admin_platform_settings_screen.dart';
import '../../features/admin/presentation/admin_recovery_screen.dart';
import '../../features/admin/presentation/admin_theme_settings_screen.dart';
import '../../features/admin/presentation/admin_motion_settings_screen.dart';
import '../../features/admin/presentation/admin_sie_global_control_screen.dart';
import '../../features/admin/presentation/admin_language_settings_screen.dart';
import '../../features/admin/presentation/admin_interview_lab_screen.dart';
import '../../features/admin/presentation/admin_user_management_screen.dart';
import '../../features/admin/presentation/audit_logs_screen.dart';
import '../../features/admin/presentation/admin_legal_editor_screen.dart';
import '../../features/admin/presentation/super_admin_dashboard.dart';
import '../../features/admin/presentation/verification_center_screen.dart';
import '../../features/company/presentation/company_dashboard.dart';
import '../../features/company/ai_hiring/presentation/company_ai_hiring_assistant_screen.dart';
import '../../features/company/candidate_intelligence/presentation/company_candidate_compare_screen.dart';
import '../../features/company/candidate_intelligence/presentation/company_candidate_intelligence_screen.dart';
import '../../features/company/candidate_intelligence/presentation/company_interview_lab_report_viewer_screen.dart';
import '../../features/company/hiring_lifecycle/presentation/company_employee_detail_screen.dart';
import '../../features/company/hiring_lifecycle/presentation/company_employees_screen.dart';
import '../../features/company/hiring_lifecycle/presentation/company_hiring_analytics_screen.dart';
import '../../features/career_intelligence/presentation/career_intelligence_dashboard_screen.dart';
import '../../features/company/presentation/company_edit_profile_screen.dart';
import '../../features/company/presentation/company_onboarding_screen.dart';
import '../../features/support/presentation/contact_screen.dart';
import '../../features/company/presentation/company_profile_screen.dart';
import '../../features/freelancer/presentation/freelancer_dashboard.dart';
import '../../features/freelancer/presentation/freelancer_directory_screen.dart';
import '../../features/freelancer/presentation/freelancer_edit_profile_screen.dart';
import '../../features/freelancer/presentation/freelancer_onboarding_screen.dart';
import '../../features/freelancer/presentation/freelancer_portfolio_studio_screen.dart';
import '../../features/freelancer/presentation/freelancer_profile_screen.dart';
import '../../features/freelancer/presentation/freelancer_service_detail_screen.dart';
import '../../features/freelancer/presentation/freelancer_service_editor_screen.dart';
import '../../features/freelancer/presentation/freelancer_service_requests_screen.dart';
import '../../features/freelancer/presentation/freelancer_service_studio_screen.dart';
import '../../features/freelancer/presentation/freelancer_services_marketplace_screen.dart';
import '../../features/freelancer/presentation/my_service_requests_screen.dart';
import '../../features/freelancer/presentation/service_request_detail_screen.dart';
import '../../features/commerce/presentation/admin_commerce_orders_screen.dart';
import '../../features/commerce/presentation/admin_finance_center_screen.dart';
import '../../features/commerce/presentation/admin_finance_detail_screen.dart';
import '../../features/commerce/presentation/admin_payout_queue_screen.dart';
import '../../features/commerce/presentation/admin_resolution_desk_screen.dart';
import '../../features/commerce/presentation/customer_resolution_center_screen.dart';
import '../../features/commerce/presentation/customer_wallet_screen.dart';
import '../../features/commerce/presentation/freelancer_resolution_center_screen.dart';
import '../../features/commerce/presentation/freelancer_wallet_screen.dart';
import '../../features/commerce/presentation/freelancer_payout_center_screen.dart';
import '../../features/commerce/presentation/invoice_detail_screen.dart';
import '../../features/commerce/presentation/invoice_list_screen.dart';
import '../../features/commerce/presentation/my_service_orders_screen.dart';
import '../../features/commerce/presentation/service_order_detail_screen.dart';
import '../../features/profile/presentation/account_settings_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/notifications/presentation/notifications_inbox_screen.dart';
import '../../features/profile/presentation/personal_information_screen.dart';
import '../../features/profile/presentation/preference_settings_screen.dart';
import '../../features/profile/presentation/portfolio_builder_screen.dart';
import '../../features/profile/presentation/professional_information_screen.dart';
import '../../features/profile/presentation/security_settings_screen.dart';
import '../../features/profile/presentation/skills_portfolio_screen.dart';
import '../../features/security/presentation/app_lock_screen.dart';
import '../../features/security/presentation/pin_management_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/marketplace_ai/presentation/marketplace_ai_assistant_screen.dart';
import '../../features/onboarding/presentation/role_selection_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/app_onboarding_screen.dart';
import '../../features/customer/presentation/customer_dashboard.dart';
import '../../features/student/presentation/student_dashboard.dart';
import '../../features/student/presentation/student_my_batches_screen.dart';
import '../../features/student/presentation/student_batch_detail_screen.dart';
import '../../features/student/presentation/student_join_batch_screen.dart';
import '../../features/student/presentation/student_class_announcements_screen.dart';
import '../../features/student/ai_tutor/presentation/student_ai_tutor_screen.dart';
import '../../features/student/presentation/student_career_roadmap_screen.dart';
import '../../features/student/presentation/student_edit_profile_screen.dart';
import '../../features/student/presentation/student_freelancer_bridge_screen.dart';
import '../../features/student/presentation/student_onboarding_screen.dart';
import '../../features/student/presentation/student_profile_screen.dart';
import '../../features/interview_lab/interview_lab.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/assignment_results_screen.dart';
import '../../features/courses/presentation/certificate_detail_screen.dart';
import '../../features/courses/presentation/certificate_management_screen.dart';
import '../../features/courses/presentation/create_edit_mcq_assignment_screen.dart';
import '../../features/courses/presentation/create_edit_grand_test_screen.dart';
import '../../features/courses/presentation/eligible_students_screen.dart';
import '../../features/courses/presentation/grand_test_attempt_screen.dart';
import '../../features/courses/presentation/grand_test_attempts_screen.dart';
import '../../features/courses/presentation/grand_test_eligibility_screen.dart';
import '../../features/courses/presentation/grand_test_result_screen.dart';
import '../../features/courses/presentation/lesson_detail_screen.dart';
import '../../features/courses/presentation/lesson_editor_screen.dart';
import '../../features/courses/presentation/mcq_attempt_screen.dart';
import '../../features/courses/presentation/mcq_result_screen.dart';
import '../../features/courses/presentation/my_certificates_screen.dart';
import '../../features/courses/presentation/my_skill_scores_screen.dart';
import '../../features/courses/presentation/project_assignment_editor_screen.dart';
import '../../features/courses/presentation/project_assignments_screen.dart';
import '../../features/courses/presentation/project_review_screen.dart';
import '../../features/courses/presentation/project_submission_screen.dart';
import '../../features/courses/presentation/project_submission_status_screen.dart';
import '../../features/courses/presentation/project_submissions_screen.dart';
import '../../features/courses/presentation/resume_preview_screen.dart';
import '../../features/courses/presentation/smart_resume_screen.dart';
import '../../features/courses/presentation/student_assignments_screen.dart';
import '../../features/courses/presentation/student_course_learning_screen.dart';
import '../../features/courses/presentation/student_courses_screen.dart';
import '../../features/courses/presentation/student_enrolled_courses_screen.dart';
import '../../features/courses/presentation/student_paid_courses_screen.dart';
import '../../features/courses/presentation/student_grand_test_overview_screen.dart';
import '../../features/courses/presentation/skill_score_detail_screen.dart';
import '../../features/teacher/presentation/teacher_dashboard.dart';
import '../../features/payment/presentation/teacher_purchase_history_screen.dart';
import '../../features/payment/presentation/payment_methods_screen.dart';
import '../../features/payment/presentation/credit_packs_screen.dart';
import '../../features/payment/presentation/teacher_plans_screen.dart';
import '../../features/payment/presentation/teacher_paid_courses_screen.dart';
import '../../features/payment/presentation/teacher_wallet_screen.dart';
import '../../features/payment/presentation/teacher_earnings_screen.dart';
import '../../features/payment/presentation/transactions/my_transactions_screen.dart';
import '../../features/payment/presentation/transactions/admin_super_transactions_screen.dart';
import '../../features/teacher/presentation/teacher_batches_screen.dart';
import '../../features/teacher/presentation/teacher_batches_compare_screen.dart';
import '../../features/teacher/presentation/teacher_batch_detail_screen.dart';
import '../../features/teacher/presentation/teacher_edit_profile_screen.dart';
import '../../features/teacher/presentation/teacher_onboarding_screen.dart';
import '../../features/teacher/presentation/teacher_profile_screen.dart';
import '../../features/teacher/presentation/teacher_student_progress_detail_screen.dart';
import '../../features/teacher/presentation/teacher_student_progress_screen.dart';
import '../../features/teacher/ai_course_builder/presentation/teacher_ai_course_builder_screen.dart';
import '../../features/courses/presentation/teacher_course_screen.dart';
import '../../features/courses/presentation/teacher_assignments_screen.dart';
import '../../features/courses/presentation/teacher_grand_tests_screen.dart';
import '../../features/courses/presentation/teacher_lessons_screen.dart';
import '../../features/jobs/presentation/job_list_screen.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/jobs/presentation/create_edit_job_screen.dart';
import '../../features/jobs/presentation/company_jobs_screen.dart';
import '../../features/applications/presentation/my_applications_screen.dart';
import '../../features/applications/presentation/my_employment_detail_screen.dart';
import '../../features/applications/presentation/my_employment_screen.dart';
import '../../features/applications/presentation/job_applicants_screen.dart';
import '../../features/interviews/presentation/candidate_evaluation_screen.dart';
import '../../features/interviews/presentation/hiring_pipeline_screen.dart';
import '../../features/interviews/presentation/interview_detail_screen.dart';
import '../../features/interviews/presentation/my_interviews_screen.dart';
import '../../features/interviews/presentation/schedule_interview_screen.dart';
import '../../features/legal/presentation/account_deletion_policy_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/legal/presentation/return_refund_policy_screen.dart';
import '../../features/legal/presentation/terms_of_service_screen.dart';
import '../../features/release_center/presentation/admin_release_center_config_screen.dart';
import '../../features/release_center/presentation/release_center_screen.dart';
import '../../models/user_model.dart';
import '../../models/platform_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_lock_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/user_provider.dart';
import 'route_names.dart';

/// SkillForge AI — GoRouter Configuration
/// Provides route definitions with auth-aware redirect guards.
/// Uses GoRouterRefreshStream to properly trigger redirects on state changes.
final routerProvider = Provider<GoRouter>((ref) {
  // Create a refresh notifier that fires when auth or user state changes
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,

    // ─── Global Redirect Guard ─────────────────────────────────────
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);
      final appLockState = ref.read(appLockProvider);
      final platformSettings = ref.read(platformSettingsProvider).value;

      // Still loading auth state — don't redirect yet
      if (authState.isLoading || authState.hasError) return null;

      final isLoggedIn = authState.asData?.value != null;
      final currentPath = state.matchedLocation;

      // Define route groups
      final isSplash = currentPath == RoutePaths.splash;
      final isHome = currentPath == RoutePaths.home;
      final isAuthRoute =
          currentPath == RoutePaths.login ||
          currentPath == RoutePaths.signup ||
          currentPath == RoutePaths.forgotPassword;
      final isAppOnboarding = currentPath == RoutePaths.appOnboarding;
      final isAccountBlockedRoute = currentPath == RoutePaths.accountBlocked;
      final isMaintenanceRoute = currentPath == RoutePaths.maintenance;
      final isAdminRecoveryRoute = currentPath == RoutePaths.adminRecovery;
      final isAppLockRoute = currentPath == RoutePaths.appLock;
      final isLegalRoute =
          currentPath == RoutePaths.privacyPolicy ||
          currentPath == RoutePaths.termsOfService ||
          currentPath == RoutePaths.accountDeletionPolicy ||
          currentPath == RoutePaths.returnRefundPolicy ||
          currentPath == RoutePaths.shippingServicePolicy;
      final isFreelancerDirectoryRoute =
          currentPath == RoutePaths.freelancerDirectory;
      final isServicesMarketplaceRoute =
          currentPath == RoutePaths.servicesMarketplace ||
          currentPath.startsWith('/services/');
      final isCustomerRoute = _isCustomerRoute(currentPath);
      final isContactRoute = currentPath == RoutePaths.contactUs;
      final isReleaseCenterRoute =
          currentPath == RoutePaths.downloads ||
          currentPath == RoutePaths.releaseCenter;
      final isSupportTicketsRoute = currentPath.startsWith('/support/');
      final isPinManagementRoute =
          currentPath == RoutePaths.setupPin ||
          currentPath == RoutePaths.changePin ||
          currentPath == RoutePaths.disablePin;
      final isAppLockManagementRoute =
          isAppLockRoute ||
          isPinManagementRoute ||
          currentPath == RoutePaths.securitySettings ||
          currentPath == '/profile' ||
          currentPath.startsWith('/profile/') ||
          currentPath.startsWith('/settings/profile/');
      final isPublicRoute =
          isSplash ||
          isHome ||
          isAuthRoute ||
          isAppOnboarding ||
          isMaintenanceRoute ||
          isLegalRoute ||
          isReleaseCenterRoute ||
          isFreelancerDirectoryRoute ||
          isServicesMarketplaceRoute ||
          isContactRoute;
      final isMaintenanceAccessRoute =
          currentPath == RoutePaths.login ||
          currentPath == RoutePaths.forgotPassword ||
          isMaintenanceRoute;

      // Allow splash to run its course
      if (isSplash) return null;

      // ─── Not Logged In ─────────────────────────────────────────
      if (!isLoggedIn) {
        if (platformSettings?.maintenanceMode == true) {
          if (isMaintenanceAccessRoute) return null;
          if (isAdminRecoveryRoute) return RoutePaths.login;
          return RoutePaths.maintenance;
        }
        if (isMaintenanceRoute) return RoutePaths.home;
        // Allow public routes
        if (isPublicRoute) return null;
        // Redirect to home for unauthenticated users
        return RoutePaths.home;
      }

      // ─── Logged In ────────────────────────────────────────────
      final user = currentUser.asData?.value;

      // User data still loading — stay put
      if (currentUser.isLoading) return null;

      // The auth session can become available before the Firestore user
      // document/role stream has emitted. Do not treat that short resolving
      // window as a missing role, otherwise returning users briefly land on
      // role selection after every fresh app start.
      if (user == null) return null;

      final canBypassMaintenance = user.canBypassMaintenance;
      if (platformSettings?.maintenanceMode == true && !canBypassMaintenance) {
        return isMaintenanceRoute ? null : RoutePaths.maintenance;
      }
      if (isMaintenanceRoute) {
        return _landingPathForUser(user);
      }

      final isBlocked =
          user.status.toLowerCase() == 'banned' ||
          user.status.toLowerCase() == 'suspended';
      if (isBlocked && !user.isSystemOwner) {
        return isAccountBlockedRoute ? null : RoutePaths.accountBlocked;
      }
      if (isAccountBlockedRoute) {
        return _landingPathForUser(user);
      }

      if (isLegalRoute) return null;
      if (isReleaseCenterRoute) return null;
      if (isFreelancerDirectoryRoute) return null;
      if (isServicesMarketplaceRoute) return null;
      if (isContactRoute || isSupportTicketsRoute) return null;

      final skipsOnboarding = user.isAdmin || user.isSystemOwner;

      // App Lock is evaluated only after auth and user data are ready.
      if (appLockState.isLoading) return null;
      final lock = appLockState.asData?.value;
      assert(() {
        debugPrint(
          '[AppLockRouter] route=$currentPath '
          'appLockEnabled=${lock?.isEnabled} '
          'isUnlocked=${lock?.isUnlocked} '
          'excluded=$isAppLockManagementRoute',
        );
        return true;
      }());

      if (isAppLockRoute) {
        if (lock?.isEnabled == true && lock?.isUnlocked == false) return null;
        if (user.isCustomerAccount) return _customerLandingPath(state);
        if (!user.hasRole) return RoutePaths.roleSelection;
        if (!user.onboardingCompleted && !skipsOnboarding) {
          return _onboardingPathForRole(user.primaryRole);
        }
        return _dashboardPathForUser(user);
      }

      if (!isPublicRoute &&
          !isAppLockManagementRoute &&
          lock?.isEnabled == true &&
          lock?.isUnlocked == false) {
        return RoutePaths.appLock;
      }

      // If user is on public/auth routes, redirect to appropriate screen
      if (isPublicRoute) {
        if (user.isCustomerAccount) {
          if (isAuthRoute || isHome || isAppOnboarding) {
            return _customerLandingPath(state);
          }
          return null;
        }
        if (!user.hasRole) return RoutePaths.roleSelection;
        if (!user.onboardingCompleted && !skipsOnboarding) {
          return _onboardingPathForRole(user.primaryRole);
        }
        return _dashboardPathForUser(user);
      }

      // ─── Role Selection ────────────────────────────────────────
      if (currentPath == RoutePaths.roleSelection) {
        if (user.isCustomerAccount) {
          return _customerLandingPath(state);
        }
        if (user.hasRole) {
          if (!user.onboardingCompleted && !skipsOnboarding) {
            return _onboardingPathForRole(user.primaryRole);
          }
          return _dashboardPathForUser(user);
        }
        return null; // Let them pick a role
      }

      if (user.isCustomerAccount) {
        if (isCustomerRoute) return null;
        // Block customer from professional routes
        if (currentPath.startsWith('/student/') ||
            currentPath.startsWith('/teacher/') ||
            currentPath.startsWith('/freelancer/') ||
            currentPath.startsWith('/company/') ||
            currentPath.startsWith('/dashboard/') &&
                currentPath != RoutePaths.customerDashboard) {
          return RoutePaths.customerDashboard;
        }
        return _customerLandingPath(state);
      }

      if (!user.hasRole) return RoutePaths.roleSelection;
      if (!user.onboardingCompleted &&
          !skipsOnboarding &&
          !currentPath.startsWith('/onboarding/')) {
        return _onboardingPathForRole(user.primaryRole);
      }

      final authorizationRedirect = _roleAuthorizationRedirect(
        currentPath: currentPath,
        user: user,
      );
      if (authorizationRedirect != null) return authorizationRedirect;

      if (currentPath.startsWith('/profile/') && !isPinManagementRoute) {
        final correctPath = currentPath.endsWith('/edit')
            ? _editProfilePathForRole(user.primaryRole)
            : _profilePathForRole(user.primaryRole);
        if (currentPath != correctPath) return correctPath;
      }

      // ─── Role Onboarding ───────────────────────────────────────
      if (currentPath.startsWith('/onboarding/')) {
        if (!user.hasRole) return RoutePaths.roleSelection;
        if (user.onboardingCompleted || skipsOnboarding) {
          return _dashboardPathForUser(user);
        }
        // Ensure they're on the correct onboarding path
        final correctPath = _onboardingPathForRole(user.primaryRole);
        if (currentPath != correctPath) return correctPath;
        return null;
      }

      // ─── Dashboard ────────────────────────────────────────────
      if (currentPath.startsWith('/dashboard')) {
        if (user.isCustomerAccount) return _customerLandingPath(state);
        if (!user.hasRole) return RoutePaths.roleSelection;
        if (!user.onboardingCompleted && !skipsOnboarding) {
          return _onboardingPathForRole(user.primaryRole);
        }
        final correctPath = _dashboardPathForUser(user);
        if (currentPath == RoutePaths.dashboard || currentPath != correctPath) {
          return correctPath;
        }
      }

      return null; // No redirect needed
    },

    // ─── Route Definitions ─────────────────────────────────────────
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.contactUs,
        name: RouteNames.contactUs,
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: RoutePaths.downloads,
        name: RouteNames.downloads,
        builder: (context, state) => const ReleaseCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.releaseCenter,
        name: RouteNames.releaseCenter,
        builder: (context, state) => const ReleaseCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.mySupportRequests,
        name: RouteNames.mySupportRequests,
        builder: (context, state) => const MySupportRequestsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notificationsInbox,
        name: RouteNames.notificationsInbox,
        builder: (context, state) => const NotificationsInboxScreen(),
      ),
      GoRoute(
        path: RoutePaths.supportRequestDetail,
        name: RouteNames.supportRequestDetail,
        builder: (context, state) {
          final messageId = state.pathParameters['messageId']!;
          return MySupportRequestDetailScreen(messageId: messageId);
        },
      ),
      GoRoute(
        path: RoutePaths.appOnboarding,
        name: RouteNames.appOnboarding,
        builder: (context, state) => const AppOnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        redirect: (context, state) => RoutePaths.roleSelection,
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: RouteNames.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.termsOfService,
        name: RouteNames.termsOfService,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: RoutePaths.accountDeletionPolicy,
        name: RouteNames.accountDeletionPolicy,
        builder: (context, state) => const AccountDeletionPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.returnRefundPolicy,
        name: RouteNames.returnRefundPolicy,
        builder: (context, state) => const ReturnRefundPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.shippingServicePolicy,
        name: RouteNames.shippingServicePolicy,
        builder: (context, state) => const ShippingServicePolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerDirectory,
        name: RouteNames.freelancerDirectory,
        builder: (context, state) => const FreelancerDirectoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.servicesMarketplace,
        name: RouteNames.servicesMarketplace,
        builder: (context, state) =>
            const FreelancerServicesMarketplaceScreen(),
      ),
      GoRoute(
        path: RoutePaths.publicServiceDetail,
        name: RouteNames.publicServiceDetail,
        builder: (context, state) {
          final serviceId = state.pathParameters['serviceId']!;
          return FreelancerServiceDetailScreen(serviceId: serviceId);
        },
      ),
      GoRoute(
        path: RoutePaths.serviceRequests,
        name: RouteNames.serviceRequests,
        builder: (context, state) => const MyServiceRequestsScreen(),
      ),
      GoRoute(
        path: RoutePaths.serviceRequestDetail,
        name: RouteNames.serviceRequestDetail,
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return ServiceRequestDetailScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: RoutePaths.serviceOrders,
        name: RouteNames.serviceOrders,
        builder: (context, state) => const MyServiceOrdersScreen(),
      ),
      GoRoute(
        path: RoutePaths.serviceOrderDetail,
        name: RouteNames.serviceOrderDetail,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return ServiceOrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: RoutePaths.invoices,
        name: RouteNames.invoices,
        builder: (context, state) =>
            const InvoiceListScreen(scope: InvoiceListScope.client),
      ),
      GoRoute(
        path: RoutePaths.invoiceDetail,
        name: RouteNames.invoiceDetail,
        builder: (context, state) {
          final invoiceId = state.pathParameters['invoiceId']!;
          return InvoiceDetailScreen(
            invoiceId: invoiceId,
            scope: InvoiceListScope.client,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.customerResolutions,
        name: RouteNames.customerResolutions,
        builder: (context, state) => const CustomerResolutionCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.customerWallet,
        name: RouteNames.customerWallet,
        builder: (context, state) => const CustomerWalletScreen(),
      ),
      GoRoute(
        path: RoutePaths.accountBlocked,
        name: RouteNames.accountBlocked,
        builder: (context, state) => const AccountBlockedScreen(),
      ),
      GoRoute(
        path: RoutePaths.maintenance,
        name: RouteNames.maintenance,
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: RoutePaths.appLock,
        name: RouteNames.appLock,
        builder: (context, state) => const AppLockScreen(),
      ),
      GoRoute(
        path: RoutePaths.roleSelection,
        name: RouteNames.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // Role Onboarding Routes
      GoRoute(
        path: RoutePaths.studentOnboarding,
        name: RouteNames.studentOnboarding,
        builder: (context, state) => const StudentOnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherOnboarding,
        name: RouteNames.teacherOnboarding,
        builder: (context, state) => const TeacherOnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerOnboarding,
        name: RouteNames.freelancerOnboarding,
        builder: (context, state) => const FreelancerOnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyOnboarding,
        name: RouteNames.companyOnboarding,
        builder: (context, state) => const CompanyOnboardingScreen(),
      ),

      // Dashboards
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: RoutePaths.customerDashboard,
        name: RouteNames.customerDashboard,
        builder: (context, state) => const CustomerDashboard(),
      ),
      GoRoute(
        path: RoutePaths.customerAiAssistant,
        name: RouteNames.customerAiAssistant,
        builder: (context, state) => const CustomerAiAssistantScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentDashboard,
        name: RouteNames.studentDashboard,
        builder: (context, state) => const StudentDashboard(),
      ),
      GoRoute(
        path: RoutePaths.studentAiTutor,
        name: RouteNames.studentAiTutor,
        builder: (context, state) => StudentAiTutorScreen(
          courseId: state.uri.queryParameters['courseId'],
          lessonId: state.uri.queryParameters['lessonId'],
          assignmentId: state.uri.queryParameters['assignmentId'],
          quizId: state.uri.queryParameters['quizId'],
          grandTestId: state.uri.queryParameters['grandTestId'],
          mode: state.uri.queryParameters['mode'],
          source: state.uri.queryParameters['source'],
          action: state.uri.queryParameters['action'],
        ),
      ),
      GoRoute(
        path: RoutePaths.studentCourses,
        name: RouteNames.studentCourses,
        builder: (context, state) => const StudentCoursesScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentEnrolledCourses,
        name: RouteNames.studentEnrolledCourses,
        builder: (context, state) => const StudentEnrolledCoursesScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentPaidCourses,
        name: RouteNames.studentPaidCourses,
        builder: (context, state) => const StudentPaidCoursesScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentCertificates,
        name: RouteNames.studentCertificates,
        builder: (context, state) => const MyCertificatesScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentSkillScores,
        name: RouteNames.studentSkillScores,
        builder: (context, state) => const MySkillScoresScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentCareerRoadmap,
        name: RouteNames.studentCareerRoadmap,
        builder: (context, state) => const StudentCareerRoadmapScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentFreelancerBridge,
        name: RouteNames.studentFreelancerBridge,
        builder: (context, state) => const StudentFreelancerBridgeScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentResume,
        name: RouteNames.studentResume,
        builder: (context, state) => const SmartResumeScreen(),
      ),
      GoRoute(
        path: RoutePaths.interviewLab,
        name: RouteNames.interviewLab,
        builder: (context, state) => const InterviewLabHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.interviewLabStart,
        name: RouteNames.interviewLabStart,
        builder: (context, state) => const InterviewLabStartScreen(),
      ),
      GoRoute(
        path: RoutePaths.interviewLabSession,
        name: RouteNames.interviewLabSession,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return InterviewLabSessionScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: RoutePaths.interviewLabReport,
        name: RouteNames.interviewLabReport,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return InterviewLabReportScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: RoutePaths.interviewLabHistory,
        name: RouteNames.interviewLabHistory,
        builder: (context, state) => const InterviewLabHistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherDashboard,
        name: RouteNames.teacherDashboard,
        builder: (context, state) => const TeacherDashboard(),
      ),
      GoRoute(
        path: RoutePaths.teacherPurchaseHistory,
        name: RouteNames.teacherPurchaseHistory,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'];
          return TeacherPurchaseHistoryScreen(
            teacherId: userId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherPaymentMethods,
        name: RouteNames.teacherPaymentMethods,
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherPlans,
        name: RouteNames.teacherPlans,
        builder: (context, state) => const TeacherPlansScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherPaidCourses,
        name: RouteNames.teacherPaidCourses,
        builder: (context, state) => const TeacherPaidCoursesScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherEarnings,
        name: RouteNames.teacherEarnings,
        builder: (context, state) => const TeacherEarningsScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherWallet,
        name: RouteNames.teacherWallet,
        builder: (context, state) => const TeacherWalletScreen(),
      ),
      GoRoute(
        path: RoutePaths.myTransactions,
        name: RouteNames.myTransactions,
        builder: (context, state) {
          final role = state.uri.queryParameters['role'];
          return MyTransactionsScreen(roleHint: role);
        },
      ),
      GoRoute(
        path: RoutePaths.adminSuperTransactions,
        name: RouteNames.adminSuperTransactions,
        builder: (context, state) => const AdminSuperTransactionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.creditPacks,
        name: RouteNames.creditPacks,
        builder: (context, state) => const CreditPacksScreen(),
      ),
      GoRoute(
        path: RoutePaths.purchaseHistory,
        name: RouteNames.purchaseHistory,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return TeacherPurchaseHistoryScreen(teacherId: userId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherCourses,
        name: RouteNames.teacherCourses,
        builder: (context, state) => const TeacherCourseScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherAiCourseBuilder,
        name: RouteNames.teacherAiCourseBuilder,
        builder: (context, state) => TeacherAiCourseBuilderScreen(
          initialPrompt: state.uri.queryParameters['prompt'],
        ),
      ),
      GoRoute(
        path: RoutePaths.teacherCourseCreate,
        name: RouteNames.teacherCourseCreate,
        builder: (context, state) => const CourseEditorScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherStudentProgress,
        name: RouteNames.teacherStudentProgress,
        builder: (context, state) => const TeacherStudentProgressScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherBatches,
        name: RouteNames.teacherBatches,
        builder: (context, state) => const TeacherBatchesScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherBatchesCompare,
        name: RouteNames.teacherBatchesCompare,
        builder: (context, state) => const TeacherBatchesCompareScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherBatchDetail,
        name: RouteNames.teacherBatchDetail,
        builder: (context, state) {
          final batchId = state.pathParameters['batchId']!;
          return TeacherBatchDetailScreen(batchId: batchId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentMyBatches,
        name: RouteNames.studentMyBatches,
        builder: (context, state) => const StudentMyBatchesScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentJoinBatch,
        name: RouteNames.studentJoinBatch,
        builder: (context, state) => const StudentJoinBatchScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentClassAnnouncements,
        name: RouteNames.studentClassAnnouncements,
        builder: (context, state) => const StudentClassAnnouncementsScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentBatchDetail,
        name: RouteNames.studentBatchDetail,
        builder: (context, state) {
          final batchId = state.pathParameters['batchId']!;
          return StudentBatchDetailScreen(batchId: batchId);
        },
      ),
      GoRoute(
        path: RoutePaths.freelancerDashboard,
        name: RouteNames.freelancerDashboard,
        builder: (context, state) => const FreelancerDashboard(),
      ),
      GoRoute(
        path: RoutePaths.freelancerAiAssistant,
        name: RouteNames.freelancerAiAssistant,
        builder: (context, state) => const FreelancerAiAssistantScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerPortfolioStudio,
        name: RouteNames.freelancerPortfolioStudio,
        builder: (context, state) => const FreelancerPortfolioStudioScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerServices,
        name: RouteNames.freelancerServices,
        builder: (context, state) => const FreelancerServiceStudioScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerServiceCreate,
        name: RouteNames.freelancerServiceCreate,
        builder: (context, state) {
          final aiDraft = _aiServiceListingExtra(state.extra);
          return FreelancerServiceEditorScreen(aiDraft: aiDraft);
        },
      ),
      GoRoute(
        path: RoutePaths.freelancerServiceEdit,
        name: RouteNames.freelancerServiceEdit,
        builder: (context, state) {
          final serviceId = state.pathParameters['serviceId']!;
          final aiDraft = _aiServiceListingExtra(state.extra);
          return FreelancerServiceEditorScreen(
            serviceId: serviceId,
            aiDraft: aiDraft,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.freelancerServiceRequests,
        name: RouteNames.freelancerServiceRequests,
        builder: (context, state) => const FreelancerServiceRequestsScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerServiceOrders,
        name: RouteNames.freelancerServiceOrders,
        builder: (context, state) => const FreelancerServiceOrdersScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerWallet,
        name: RouteNames.freelancerWallet,
        builder: (context, state) => const FreelancerWalletScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerInvoices,
        name: RouteNames.freelancerInvoices,
        builder: (context, state) =>
            const InvoiceListScreen(scope: InvoiceListScope.freelancer),
      ),
      GoRoute(
        path: RoutePaths.freelancerInvoiceDetail,
        name: RouteNames.freelancerInvoiceDetail,
        builder: (context, state) {
          final invoiceId = state.pathParameters['invoiceId']!;
          return InvoiceDetailScreen(
            invoiceId: invoiceId,
            scope: InvoiceListScope.freelancer,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.freelancerPayouts,
        name: RouteNames.freelancerPayouts,
        builder: (context, state) => const FreelancerPayoutCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerResolutions,
        name: RouteNames.freelancerResolutions,
        builder: (context, state) => const FreelancerResolutionCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyDashboard,
        name: RouteNames.companyDashboard,
        builder: (context, state) => const CompanyDashboard(),
      ),
      GoRoute(
        path: RoutePaths.studentProfile,
        name: RouteNames.studentProfile,
        builder: (context, state) => const StudentProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherProfile,
        name: RouteNames.teacherProfile,
        builder: (context, state) => const TeacherProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerProfile,
        name: RouteNames.freelancerProfile,
        builder: (context, state) => const FreelancerProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyProfile,
        name: RouteNames.companyProfile,
        builder: (context, state) => const CompanyProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.jobList,
        name: RouteNames.jobList,
        builder: (context, state) => const JobListScreen(),
      ),
      GoRoute(
        path: RoutePaths.createJob,
        name: RouteNames.createJob,
        builder: (context, state) => const CreateEditJobScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyJobs,
        name: RouteNames.companyJobs,
        builder: (context, state) => const CompanyJobsScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyAiHiringAssistant,
        name: RouteNames.companyAiHiringAssistant,
        builder: (context, state) => CompanyAiHiringAssistantScreen(
          jobId: state.uri.queryParameters['jobId'],
          applicationId: state.uri.queryParameters['applicationId'],
        ),
      ),
      GoRoute(
        path: RoutePaths.hiringPipeline,
        name: RouteNames.hiringPipeline,
        builder: (context, state) => const HiringPipelineScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyCandidateIntelligence,
        name: RouteNames.companyCandidateIntelligence,
        builder: (context, state) {
          final applicationId = state.pathParameters['applicationId']!;
          return CompanyCandidateIntelligenceScreen(
            applicationId: applicationId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.companyCandidateCompare,
        name: RouteNames.companyCandidateCompare,
        builder: (context, state) {
          final jobId = state.uri.queryParameters['jobId'] ?? '';
          final ids = (state.uri.queryParameters['ids'] ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          return CompanyCandidateCompareScreen(
            jobId: jobId,
            initialApplicationIds: ids,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.companyInterviewLabReport,
        name: RouteNames.companyInterviewLabReport,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return CompanyInterviewLabReportViewerScreen(
            sessionId: sessionId,
            applicationId: state.uri.queryParameters['applicationId'],
          );
        },
      ),
      GoRoute(
        path: RoutePaths.companyEmployees,
        name: RouteNames.companyEmployees,
        builder: (context, state) => const CompanyEmployeesScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyEmployeeDetail,
        name: RouteNames.companyEmployeeDetail,
        builder: (context, state) {
          final applicationId = state.pathParameters['applicationId']!;
          return CompanyEmployeeDetailScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: RoutePaths.companyHiringAnalytics,
        name: RouteNames.companyHiringAnalytics,
        builder: (context, state) => const CompanyHiringAnalyticsScreen(),
      ),
      GoRoute(
        path: RoutePaths.careerIntelligence,
        name: RouteNames.careerIntelligence,
        builder: (context, state) => const CareerIntelligenceDashboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.myApplications,
        name: RouteNames.myApplications,
        builder: (context, state) => const MyApplicationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.myEmployment,
        name: RouteNames.myEmployment,
        builder: (context, state) => const MyEmploymentScreen(),
      ),
      GoRoute(
        path: RoutePaths.myEmploymentDetail,
        name: RouteNames.myEmploymentDetail,
        builder: (context, state) {
          final applicationId = state.pathParameters['applicationId']!;
          return MyEmploymentDetailScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentApplications,
        name: RouteNames.studentApplications,
        builder: (context, state) => const MyApplicationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerApplications,
        name: RouteNames.freelancerApplications,
        builder: (context, state) => const MyApplicationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.myInterviews,
        name: RouteNames.myInterviews,
        builder: (context, state) => const MyInterviewsScreen(),
      ),
      GoRoute(
        path: RoutePaths.studentCourseDetail,
        name: RouteNames.studentCourseDetail,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CourseDetailScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentCourseLearn,
        name: RouteNames.studentCourseLearn,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return StudentCourseLearningScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentLessonDetail,
        name: RouteNames.studentLessonDetail,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final lessonId = state.pathParameters['lessonId']!;
          return LessonDetailScreen(courseId: courseId, lessonId: lessonId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentAssignments,
        name: RouteNames.studentAssignments,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return StudentAssignmentsScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentAssignmentAttempt,
        name: RouteNames.studentAssignmentAttempt,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return McqAttemptScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.studentAssignmentResult,
        name: RouteNames.studentAssignmentResult,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return McqResultScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.studentProjectSubmission,
        name: RouteNames.studentProjectSubmission,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return ProjectSubmissionScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.studentProjectStatus,
        name: RouteNames.studentProjectStatus,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return ProjectSubmissionStatusScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.studentGrandTestAttempt,
        name: RouteNames.studentGrandTestAttempt,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final grandTestId = state.pathParameters['grandTestId']!;
          return GrandTestAttemptScreen(
            courseId: courseId,
            grandTestId: grandTestId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.studentGrandTestResult,
        name: RouteNames.studentGrandTestResult,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final grandTestId = state.pathParameters['grandTestId']!;
          return GrandTestResultScreen(
            courseId: courseId,
            grandTestId: grandTestId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.studentGrandTestOverview,
        name: RouteNames.studentGrandTestOverview,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return StudentGrandTestOverviewScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentCertificateDetail,
        name: RouteNames.studentCertificateDetail,
        builder: (context, state) {
          final certificateId = state.pathParameters['certificateId']!;
          return CertificateDetailScreen(certificateId: certificateId);
        },
      ),
      GoRoute(
        path: RoutePaths.studentSkillScoreDetail,
        name: RouteNames.studentSkillScoreDetail,
        builder: (context, state) {
          final skillName = state.pathParameters['skillName']!;
          return SkillScoreDetailScreen(skillName: skillName);
        },
      ),
      GoRoute(
        path: RoutePaths.studentResumePreview,
        name: RouteNames.studentResumePreview,
        builder: (context, state) => const ResumePreviewScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherCourseEdit,
        name: RouteNames.teacherCourseEdit,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CourseEditorScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherCourseDetail,
        name: RouteNames.teacherCourseDetail,
        redirect: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return RoutePaths.teacherCourseEdit.replaceFirst(
            ':courseId',
            courseId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherCourseLessons,
        name: RouteNames.teacherCourseLessons,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return TeacherLessonsScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherLessonCreate,
        name: RouteNames.teacherLessonCreate,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return LessonEditorScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherLessonEdit,
        name: RouteNames.teacherLessonEdit,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final lessonId = state.pathParameters['lessonId']!;
          return LessonEditorScreen(courseId: courseId, lessonId: lessonId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherAssignments,
        name: RouteNames.teacherAssignments,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return TeacherAssignmentsScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherAssignmentCreate,
        name: RouteNames.teacherAssignmentCreate,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CreateEditMcqAssignmentScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherAssignmentEdit,
        name: RouteNames.teacherAssignmentEdit,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return CreateEditMcqAssignmentScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherAssignmentResults,
        name: RouteNames.teacherAssignmentResults,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return AssignmentResultsScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherProjectAssignments,
        name: RouteNames.teacherProjectAssignments,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return ProjectAssignmentsScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherProjectAssignmentCreate,
        name: RouteNames.teacherProjectAssignmentCreate,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return ProjectAssignmentEditorScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherProjectAssignmentEdit,
        name: RouteNames.teacherProjectAssignmentEdit,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return ProjectAssignmentEditorScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherProjectSubmissions,
        name: RouteNames.teacherProjectSubmissions,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          return ProjectSubmissionsScreen(
            courseId: courseId,
            assignmentId: assignmentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherProjectReview,
        name: RouteNames.teacherProjectReview,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final assignmentId = state.pathParameters['assignmentId']!;
          final studentId = state.pathParameters['studentId']!;
          return ProjectReviewScreen(
            courseId: courseId,
            assignmentId: assignmentId,
            studentId: studentId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherGrandTestCreate,
        name: RouteNames.teacherGrandTestCreate,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CreateEditGrandTestScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherGrandTestEdit,
        name: RouteNames.teacherGrandTestEdit,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final grandTestId = state.pathParameters['grandTestId']!;
          return CreateEditGrandTestScreen(
            courseId: courseId,
            grandTestId: grandTestId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherGrandTestEligibility,
        name: RouteNames.teacherGrandTestEligibility,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final grandTestId = state.pathParameters['grandTestId']!;
          return GrandTestEligibilityScreen(
            courseId: courseId,
            grandTestId: grandTestId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherGrandTestAttempts,
        name: RouteNames.teacherGrandTestAttempts,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          final grandTestId = state.pathParameters['grandTestId']!;
          return GrandTestAttemptsScreen(
            courseId: courseId,
            grandTestId: grandTestId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.teacherGrandTests,
        name: RouteNames.teacherGrandTests,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return TeacherGrandTestsScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherCertificates,
        name: RouteNames.teacherCertificates,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CertificateManagementScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherCertificateEligible,
        name: RouteNames.teacherCertificateEligible,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return EligibleStudentsScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: RoutePaths.teacherStudentProgressDetail,
        name: RouteNames.teacherStudentProgressDetail,
        builder: (context, state) {
          final studentId = state.pathParameters['studentId']!;
          return TeacherStudentProgressDetailScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminDashboard,
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: RoutePaths.adminInbox,
        name: RouteNames.adminInbox,
        builder: (context, state) => const AdminInboxScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminAiUsageControl,
        name: RouteNames.adminAiUsageControl,
        builder: (context, state) => const AdminAiUsageControlScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminAiCredits,
        name: RouteNames.adminAiCredits,
        builder: (context, state) => const AdminAiUsageControlScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminMonetization,
        name: RouteNames.adminMonetization,
        builder: (context, state) => const MonetizationCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminEmailSettings,
        name: RouteNames.adminEmailSettings,
        builder: (context, state) => const AdminEmailSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminResolutionAiAnalyst,
        name: RouteNames.adminResolutionAiAnalyst,
        builder: (context, state) => const AdminResolutionAiAnalystScreen(),
      ),
      GoRoute(
        path: RoutePaths.superAdminDashboard,
        name: RouteNames.superAdminDashboard,
        builder: (context, state) => const SuperAdminDashboard(),
      ),
      GoRoute(
        path: RoutePaths.studentEditProfile,
        name: RouteNames.studentEditProfile,
        builder: (context, state) => const StudentEditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.teacherEditProfile,
        name: RouteNames.teacherEditProfile,
        builder: (context, state) => const TeacherEditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.freelancerEditProfile,
        name: RouteNames.freelancerEditProfile,
        builder: (context, state) => const FreelancerEditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.companyEditProfile,
        name: RouteNames.companyEditProfile,
        builder: (context, state) => const CompanyEditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.securitySettings,
        name: RouteNames.securitySettings,
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.setupPin,
        name: RouteNames.setupPin,
        builder: (context, state) => const PinManagementScreen.setup(),
      ),
      GoRoute(
        path: RoutePaths.changePin,
        name: RouteNames.changePin,
        builder: (context, state) => const PinManagementScreen.change(),
      ),
      GoRoute(
        path: RoutePaths.disablePin,
        name: RouteNames.disablePin,
        builder: (context, state) => const PinManagementScreen.disable(),
      ),
      GoRoute(
        path: RoutePaths.profilePersonal,
        name: RouteNames.profilePersonal,
        builder: (context, state) => const PersonalInformationScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileProfessional,
        name: RouteNames.profileProfessional,
        builder: (context, state) => const ProfessionalInformationScreen(),
      ),
      GoRoute(
        path: RoutePaths.profilePortfolio,
        name: RouteNames.profilePortfolio,
        builder: (context, state) => const SkillsPortfolioScreen(),
      ),
      GoRoute(
        path: RoutePaths.portfolioBuilder,
        name: RouteNames.portfolioBuilder,
        builder: (context, state) => const PortfolioBuilderScreen(),
      ),
      GoRoute(
        path: RoutePaths.profilePreferences,
        name: RouteNames.profilePreferences,
        builder: (context, state) => const PreferenceSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileNotifications,
        name: RouteNames.profileNotifications,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileAccountSettings,
        name: RouteNames.profileAccountSettings,
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminUserManagement,
        name: RouteNames.adminUserManagement,
        builder: (context, state) => const AdminUserManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminManagement,
        name: RouteNames.adminManagement,
        builder: (context, state) => const AdminManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminRecovery,
        name: RouteNames.adminRecovery,
        builder: (context, state) => const AdminRecoveryScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminVerification,
        name: RouteNames.adminVerification,
        builder: (context, state) => const VerificationCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminSettings,
        name: RouteNames.adminSettings,
        builder: (context, state) => const AdminPlatformSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminAuditLogs,
        name: RouteNames.adminAuditLogs,
        builder: (context, state) => const AuditLogsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminLegalEditor,
        name: RouteNames.adminLegalEditor,
        builder: (context, state) => const AdminLegalEditorScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminReleaseCenter,
        name: RouteNames.adminReleaseCenter,
        builder: (context, state) => const AdminReleaseCenterConfigScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminThemeSettings,
        name: RouteNames.adminThemeSettings,
        builder: (context, state) => const AdminThemeSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminMotionSettings,
        name: RouteNames.adminMotionSettings,
        builder: (context, state) => const AdminMotionSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminSieControl,
        name: RouteNames.adminSieControl,
        builder: (context, state) => const AdminSieGlobalControlScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminLanguageSettings,
        name: RouteNames.adminLanguageSettings,
        builder: (context, state) => const AdminLanguageSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminInterviewLab,
        name: RouteNames.adminInterviewLab,
        builder: (context, state) => const AdminInterviewLabScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminCommerceOrders,
        name: RouteNames.adminCommerceOrders,
        builder: (context, state) => const AdminCommerceOrdersScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminFinanceCenter,
        name: RouteNames.adminFinanceCenter,
        builder: (context, state) => const AdminFinanceCenterScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminFinanceDetail,
        name: RouteNames.adminFinanceDetail,
        builder: (context, state) {
          final type = state.pathParameters['type']!;
          final id = state.pathParameters['id']!;
          return AdminFinanceDetailScreen(type: type, id: id);
        },
      ),
      GoRoute(
        path: RoutePaths.adminInvoices,
        name: RouteNames.adminInvoices,
        builder: (context, state) =>
            const InvoiceListScreen(scope: InvoiceListScope.admin),
      ),
      GoRoute(
        path: RoutePaths.adminInvoiceDetail,
        name: RouteNames.adminInvoiceDetail,
        builder: (context, state) {
          final invoiceId = state.pathParameters['invoiceId']!;
          return InvoiceDetailScreen(
            invoiceId: invoiceId,
            scope: InvoiceListScope.admin,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminPayouts,
        name: RouteNames.adminPayouts,
        builder: (context, state) => const AdminPayoutQueueScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminResolutionDesk,
        name: RouteNames.adminResolutionDesk,
        builder: (context, state) => const AdminResolutionDeskScreen(),
      ),

      // --- Jobs Module Routes ---
      GoRoute(
        path: RoutePaths.jobDetail,
        name: RouteNames.jobDetail,
        builder: (context, state) {
          final jobId = state.pathParameters['id']!;
          return JobDetailScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: RoutePaths.editJob,
        name: RouteNames.editJob,
        builder: (context, state) {
          final jobId = state.pathParameters['id']!;
          return CreateEditJobScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: RoutePaths.jobHiringPipeline,
        name: RouteNames.jobHiringPipeline,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return JobApplicantsScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: RoutePaths.scheduleInterview,
        name: RouteNames.scheduleInterview,
        builder: (context, state) {
          final applicationId = state.pathParameters['applicationId']!;
          return ScheduleInterviewScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: RoutePaths.interviewDetail,
        name: RouteNames.interviewDetail,
        builder: (context, state) {
          final interviewId = state.pathParameters['interviewId']!;
          return InterviewDetailScreen(interviewId: interviewId);
        },
      ),
      GoRoute(
        path: RoutePaths.evaluateInterview,
        name: RouteNames.evaluateInterview,
        builder: (context, state) {
          final interviewId = state.pathParameters['interviewId']!;
          return CandidateEvaluationScreen(interviewId: interviewId);
        },
      ),

      // --- Applications Module Routes ---
      GoRoute(
        path: RoutePaths.jobApplicants,
        name: RouteNames.jobApplicants,
        builder: (context, state) {
          final jobId = state.pathParameters['id']!;
          return JobApplicantsScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: RoutePaths.myInterviewDetail,
        name: RouteNames.myInterviewDetail,
        builder: (context, state) {
          final interviewId = state.pathParameters['interviewId']!;
          return InterviewDetailScreen(interviewId: interviewId);
        },
      ),
    ],

    // ─── Error Page ────────────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
});

/// Extracts optional Marketplace AI `serviceListing` draft from GoRouter extra.
Map<String, dynamic>? _aiServiceListingExtra(Object? extra) {
  if (extra is Map) {
    final listing = extra['aiServiceListing'] ?? extra['serviceListing'];
    if (listing is Map) {
      return Map<String, dynamic>.from(listing);
    }
    if (extra['title'] != null || extra['shortDescription'] != null) {
      return Map<String, dynamic>.from(extra);
    }
  }
  return null;
}

/// Maps a primaryRole string to its corresponding dashboard path.
String _dashboardPathForRole(String? role) {
  return switch (_normalizeRole(role)) {
    'student' => RoutePaths.studentDashboard,
    'teacher' => RoutePaths.teacherDashboard,
    'freelancer' => RoutePaths.freelancerDashboard,
    'company' => RoutePaths.companyDashboard,
    'admin' => RoutePaths.adminDashboard,
    'superadmin' => RoutePaths.superAdminDashboard,
    _ => RoutePaths.roleSelection,
  };
}

String _dashboardPathForUser(UserModel user) {
  if (user.isSystemOwner && !_isAdminRole(user.primaryRole)) {
    return RoutePaths.superAdminDashboard;
  }
  return _dashboardPathForRole(user.primaryRole);
}

String _landingPathForUser(UserModel user) {
  if (user.isCustomerAccount) return RoutePaths.servicesMarketplace;
  return _dashboardPathForUser(user);
}

String _customerLandingPath(GoRouterState state) {
  final returnUrl = state.uri.queryParameters['returnUrl']?.trim();
  if (returnUrl != null && _isSafeCustomerReturnPath(returnUrl)) {
    return returnUrl;
  }
  return RoutePaths.customerDashboard;
}

bool _isSafeCustomerReturnPath(String path) {
  if (!path.startsWith('/') || path.startsWith('//')) return false;
  return _isCustomerRoute(path);
}

bool _isCustomerRoute(String path) {
  return path == RoutePaths.servicesMarketplace ||
      path.startsWith('/services/') ||
      path == RoutePaths.freelancerDirectory ||
      path == RoutePaths.serviceRequests ||
      path.startsWith('/service-requests/') ||
      path == RoutePaths.serviceOrders ||
      path.startsWith('/orders/') ||
      path == RoutePaths.invoices ||
      path.startsWith('/invoices/') ||
      path == RoutePaths.customerResolutions ||
      path == RoutePaths.customerWallet ||
      path == RoutePaths.customerAiAssistant ||
      path.startsWith('/support/') ||
      path == RoutePaths.contactUs ||
      path == RoutePaths.profileAccountSettings ||
      path == RoutePaths.customerDashboard;
}

/// Maps a primaryRole string to its corresponding onboarding path.
String _onboardingPathForRole(String? role) {
  return switch (_normalizeRole(role)) {
    'student' => RoutePaths.studentOnboarding,
    'teacher' => RoutePaths.teacherOnboarding,
    'freelancer' => RoutePaths.freelancerOnboarding,
    'company' => RoutePaths.companyOnboarding,
    'admin' => RoutePaths.adminDashboard, // Skip onboarding for admin
    'superadmin' => RoutePaths.superAdminDashboard,
    _ => RoutePaths.roleSelection,
  };
}

String _profilePathForRole(String? role) {
  return switch (_normalizeRole(role)) {
    'student' => RoutePaths.studentProfile,
    'teacher' => RoutePaths.teacherProfile,
    'freelancer' => RoutePaths.freelancerProfile,
    'company' => RoutePaths.companyProfile,
    _ => _dashboardPathForRole(role),
  };
}

String _editProfilePathForRole(String? role) {
  return switch (_normalizeRole(role)) {
    'student' => RoutePaths.studentEditProfile,
    'teacher' => RoutePaths.teacherEditProfile,
    'freelancer' => RoutePaths.freelancerEditProfile,
    'company' => RoutePaths.companyEditProfile,
    _ => _dashboardPathForRole(role),
  };
}

bool _isAdminRole(String? role) {
  final normalized = _normalizeRole(role);
  return normalized == 'admin' || normalized == 'superadmin';
}

String? _roleAuthorizationRedirect({
  required String currentPath,
  required UserModel user,
}) {
  final role = user.primaryRole;
  final normalizedRole = _normalizeRole(role);
  final hasAdminAccess = user.isAdmin || user.isSystemOwner;
  final hasRecoveryAccess = user.hasAdminRecoveryAccess;
  final isAdminRoute =
      currentPath == RoutePaths.adminDashboard ||
      currentPath == RoutePaths.adminUserManagement ||
      currentPath == RoutePaths.adminSettings ||
      currentPath.startsWith('/admin/');
  if (isAdminRoute && !hasAdminAccess) {
    return _dashboardPathForUser(user);
  }

  final isSuperAdminRoute =
      currentPath == RoutePaths.superAdminDashboard ||
      currentPath == RoutePaths.adminManagement ||
      currentPath == RoutePaths.adminRecovery ||
      currentPath == RoutePaths.adminSettings ||
      currentPath == RoutePaths.adminThemeSettings ||
      currentPath == RoutePaths.adminMotionSettings ||
      currentPath == RoutePaths.adminSieControl ||
      currentPath == RoutePaths.adminLanguageSettings ||
      currentPath == RoutePaths.adminInterviewLab;
  if (isSuperAdminRoute && !hasRecoveryAccess) {
    return _dashboardPathForUser(user);
  }

  final isCompanyRoute =
      currentPath == RoutePaths.createJob ||
      currentPath == RoutePaths.companyJobs ||
      currentPath == RoutePaths.hiringPipeline ||
      currentPath.startsWith('/company/jobs/') ||
      currentPath.startsWith('/company/interviews/') ||
      currentPath.startsWith('/company/candidates') ||
      currentPath.startsWith('/company/interview-lab/') ||
      currentPath.startsWith('/jobs/edit/') ||
      currentPath.startsWith('/job-applicants/');
  if (isCompanyRoute && normalizedRole != 'company') {
    return _dashboardPathForUser(user);
  }

  if (currentPath == RoutePaths.myApplications &&
      normalizedRole != 'student' &&
      normalizedRole != 'freelancer') {
    return _dashboardPathForUser(user);
  }

  if (currentPath.startsWith('/my-employment') &&
      normalizedRole != 'student' &&
      normalizedRole != 'freelancer') {
    return _dashboardPathForUser(user);
  }

  if (currentPath.startsWith('/my-interviews') &&
      normalizedRole != 'student' &&
      normalizedRole != 'freelancer') {
    return _dashboardPathForUser(user);
  }

  if ((currentPath.startsWith('/freelancer/services') ||
          currentPath.startsWith('/freelancer/service-requests') ||
          currentPath.startsWith('/freelancer/orders') ||
          currentPath.startsWith('/freelancer/wallet') ||
          currentPath.startsWith('/freelancer/invoices') ||
          currentPath.startsWith('/freelancer/payouts') ||
          currentPath.startsWith('/freelancer/resolutions') ||
          currentPath.startsWith('/freelancer/applications') ||
          currentPath.startsWith('/freelancer/ai-assistant')) &&
      normalizedRole != 'freelancer') {
    return _dashboardPathForUser(user);
  }

  if (currentPath.startsWith('/interview-lab') &&
      normalizedRole != 'student' &&
      normalizedRole != 'freelancer') {
    return _dashboardPathForUser(user);
  }

  if ((currentPath.startsWith('/student/courses') ||
          currentPath.startsWith('/student/certificates') ||
          currentPath.startsWith('/student/skill-scores') ||
          currentPath.startsWith('/student/career-roadmap') ||
          currentPath.startsWith('/student/freelancer-bridge') ||
          currentPath.startsWith('/student/applications') ||
          currentPath.startsWith('/student/resume')) &&
      normalizedRole != 'student') {
    return _dashboardPathForUser(user);
  }

  if ((currentPath.startsWith('/teacher/courses') ||
          currentPath.startsWith('/teacher/ai-course-builder') ||
          currentPath.startsWith('/teacher/certificates') ||
          currentPath.startsWith('/teacher/batches') ||
          currentPath.startsWith('/teacher/analytics')) &&
      normalizedRole != 'teacher') {
    return _dashboardPathForUser(user);
  }

  return null;
}

String _normalizeRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

// ─────────────────────────────────────────────────────────────────────────────
// Router Refresh Notifier
// Converts Riverpod provider changes into ChangeNotifier notifications
// so GoRouter properly re-evaluates its redirect logic.
// ─────────────────────────────────────────────────────────────────────────────

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    // Listen to auth state changes
    _ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      _scheduleRefresh();
    });

    // Listen to user document changes
    _ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (prev, next) {
      _scheduleRefresh();
    });

    // Re-evaluate protected routes when the in-memory lock session changes.
    _ref.listen<AsyncValue<AppLockState>>(appLockProvider, (prev, next) {
      _scheduleRefresh();
    });

    _ref.listen<AsyncValue<PlatformSettings>>(
      platformSettingsProvider,
      (prev, next) => _scheduleRefresh(),
    );
  }

  final Ref _ref;
  bool _refreshScheduled = false;

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (hasListeners) notifyListeners();
    });
  }
}
