import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Maps SkillForge Company GoRouter locations → SIE route policy ids.
///
/// Mirrors [FreelancerSieRouteMapper] — pure / deterministic.
abstract final class CompanySieRouteMapper {
  /// Resolve SIE route id from location + optional GoRouter name.
  static String resolve({
    required String location,
    String? routeName,
  }) {
    final path = _normalize(location);
    final byName = routeName == null ? null : _byRouteName[routeName];
    if (byName != null) return byName;

    if (path.startsWith('/company/jobs/') && path.contains('/pipeline')) {
      return SieCompanyRouteCatalog.pipelineJob.routeId;
    }
    if (path.startsWith('/company/interviews/schedule')) {
      return SieCompanyRouteCatalog.interviewSchedule.routeId;
    }
    if (path.startsWith('/company/interviews/evaluate')) {
      return SieCompanyRouteCatalog.interviewEvaluate.routeId;
    }
    if (path.startsWith('/company/interviews/detail')) {
      return SieCompanyRouteCatalog.interviewDetail.routeId;
    }
    if (path.startsWith('/jobs/edit/')) {
      return SieCompanyRouteCatalog.jobEdit.routeId;
    }
    if (path.startsWith('/jobs/detail/')) {
      return SieCompanyRouteCatalog.jobDetail.routeId;
    }
    if (path.startsWith('/job-applicants/')) {
      return SieCompanyRouteCatalog.pipelineJob.routeId;
    }

    final entries = _byPathPrefix.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      if (path == e.key || path.startsWith('${e.key}/')) {
        return e.value;
      }
    }

    if (path.startsWith('/dashboard/company')) {
      return SieSkillForgeRouteCatalog.companyDashboard.routeId;
    }
    if (path.startsWith('/company/')) {
      return SieSkillForgeRouteCatalog.companyDashboard.routeId;
    }
    if (path.startsWith('/profile/company')) {
      return SieCompanyRouteCatalog.profile.routeId;
    }
    if (path.contains('account-deletion')) {
      return SieCompanyRouteCatalog.accountDeletion.routeId;
    }
    if (path.contains('/settings/security') || path.contains('app-lock')) {
      return SieCompanyRouteCatalog.accountSecurity.routeId;
    }

    return SieSkillForgeRouteCatalog.companyDashboard.routeId;
  }

  /// Whether this location is a Company Module SIE surface.
  static bool isCompanyLocation(String location) {
    final path = _normalize(location);
    return path.startsWith('/dashboard/company') ||
        path.startsWith('/onboarding/company') ||
        path.startsWith('/profile/company') ||
        path == '/company-jobs' ||
        path.startsWith('/company/') ||
        path == '/jobs/create' ||
        path.startsWith('/jobs/edit/') ||
        path.startsWith('/job-applicants/');
  }

  static String _normalize(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  static const Map<String, String> _byRouteName = {
    RouteNames.companyOnboarding: 'company.onboarding',
    RouteNames.companyDashboard: 'company.dashboard',
    RouteNames.companyJobs: 'company.jobs',
    RouteNames.createJob: 'company.jobs.create',
    RouteNames.editJob: 'company.jobs.edit',
    RouteNames.jobDetail: 'company.jobs.detail',
    RouteNames.hiringPipeline: 'company.pipeline',
    RouteNames.jobHiringPipeline: 'company.pipeline.job',
    RouteNames.jobApplicants: 'company.pipeline.job',
    RouteNames.myInterviews: 'company.interviews',
    RouteNames.scheduleInterview: 'company.interviews.schedule',
    RouteNames.interviewDetail: 'company.interviews.detail',
    RouteNames.evaluateInterview: 'company.interviews.evaluate',
    RouteNames.companyAiHiringAssistant: 'company.ai_hiring',
    RouteNames.companyProfile: 'company.profile',
    RouteNames.companyEditProfile: 'company.profile.edit',
    RouteNames.accountDeletionPolicy: 'company.account_deletion',
    RouteNames.securitySettings: 'company.account_security',
    RouteNames.profileAccountSettings: 'company.org_settings',
  };

  static const Map<String, String> _byPathPrefix = {
    '/onboarding/company': 'company.onboarding',
    '/dashboard/company': 'company.dashboard',
    '/company-jobs': 'company.jobs',
    '/jobs/create': 'company.jobs.create',
    '/company/hiring': 'company.pipeline',
    '/company/ai-hiring-assistant': 'company.ai_hiring',
    '/profile/company/edit': 'company.profile.edit',
    '/profile/company': 'company.profile',
    '/settings/profile/account': 'company.org_settings',
  };
}
