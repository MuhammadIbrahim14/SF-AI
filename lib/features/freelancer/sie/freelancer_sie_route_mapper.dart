import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Maps SkillForge Freelancer GoRouter locations → SIE route policy ids.
///
/// Mirrors [TeacherSieRouteMapper] — pure / deterministic.
abstract final class FreelancerSieRouteMapper {
  /// Resolve SIE route id from location + optional GoRouter name.
  static String resolve({
    required String location,
    String? routeName,
  }) {
    final path = _normalize(location);
    final byName = routeName == null ? null : _byRouteName[routeName];
    if (byName != null) return byName;

    if (path.startsWith('/freelancer/invoices/') &&
        path.length > '/freelancer/invoices/'.length) {
      return SieFreelancerRouteCatalog.invoiceDetail.routeId;
    }
    if (path.startsWith('/freelancer/services/') &&
        path.contains('/edit')) {
      return SieFreelancerRouteCatalog.serviceEdit.routeId;
    }
    if (path.startsWith('/orders/') &&
        path.length > '/orders/'.length) {
      return SieFreelancerRouteCatalog.orderDetail.routeId;
    }

    final entries = _byPathPrefix.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      if (path == e.key || path.startsWith('${e.key}/')) {
        return e.value;
      }
    }

    if (path.startsWith('/dashboard/freelancer')) {
      return SieSkillForgeRouteCatalog.freelancerDashboard.routeId;
    }
    if (path.startsWith('/freelancer/')) {
      if (path.contains('wallet') || path.contains('earning')) {
        return SieFreelancerRouteCatalog.wallet.routeId;
      }
      if (path.contains('payout') || path.contains('withdraw')) {
        return SieFreelancerRouteCatalog.payouts.routeId;
      }
      if (path.contains('invoice')) {
        return SieFreelancerRouteCatalog.invoices.routeId;
      }
      return SieSkillForgeRouteCatalog.freelancerDashboard.routeId;
    }
    if (path.startsWith('/profile/freelancer')) {
      return SieFreelancerRouteCatalog.profile.routeId;
    }
    if (path.contains('account-deletion')) {
      return SieFreelancerRouteCatalog.accountDeletion.routeId;
    }
    if (path.contains('/settings/security') || path.contains('app-lock')) {
      return SieFreelancerRouteCatalog.accountSecurity.routeId;
    }

    return SieSkillForgeRouteCatalog.freelancerDashboard.routeId;
  }

  /// Whether this location is a Freelancer Module SIE surface.
  static bool isFreelancerLocation(String location) {
    final path = _normalize(location);
    return path.startsWith('/dashboard/freelancer') ||
        path.startsWith('/freelancer/') ||
        path.startsWith('/onboarding/freelancer') ||
        path.startsWith('/profile/freelancer');
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
    RouteNames.freelancerOnboarding: 'freelancer.onboarding',
    RouteNames.freelancerDashboard: 'freelancer.dashboard',
    RouteNames.freelancerDirectory: 'freelancer.directory',
    RouteNames.freelancerPortfolioStudio: 'freelancer.portfolio_studio',
    RouteNames.freelancerServices: 'freelancer.services',
    RouteNames.freelancerServiceCreate: 'freelancer.services.create',
    RouteNames.freelancerServiceEdit: 'freelancer.services.edit',
    RouteNames.freelancerServiceRequests: 'freelancer.service_requests',
    RouteNames.freelancerServiceOrders: 'freelancer.orders',
    RouteNames.freelancerWallet: 'freelancer.wallet',
    RouteNames.freelancerInvoices: 'freelancer.invoices',
    RouteNames.freelancerInvoiceDetail: 'freelancer.invoices.detail',
    RouteNames.freelancerPayouts: 'freelancer.payouts',
    RouteNames.freelancerResolutions: 'freelancer.resolutions',
    RouteNames.freelancerAiAssistant: 'freelancer.ai_assistant',
    RouteNames.freelancerApplications: 'freelancer.applications',
    RouteNames.freelancerProfile: 'freelancer.profile',
    RouteNames.freelancerEditProfile: 'freelancer.profile.edit',
    RouteNames.accountDeletionPolicy: 'freelancer.account_deletion',
    RouteNames.securitySettings: 'freelancer.account_security',
  };

  static const Map<String, String> _byPathPrefix = {
    '/onboarding/freelancer': 'freelancer.onboarding',
    '/dashboard/freelancer': 'freelancer.dashboard',
    '/freelancers': 'freelancer.directory',
    '/freelancer/portfolio-studio': 'freelancer.portfolio_studio',
    '/freelancer/services/new': 'freelancer.services.create',
    '/freelancer/services': 'freelancer.services',
    '/freelancer/service-requests': 'freelancer.service_requests',
    '/freelancer/orders': 'freelancer.orders',
    '/freelancer/wallet': 'freelancer.wallet',
    '/freelancer/invoices': 'freelancer.invoices',
    '/freelancer/payouts': 'freelancer.payouts',
    '/freelancer/resolutions': 'freelancer.resolutions',
    '/freelancer/ai-assistant': 'freelancer.ai_assistant',
    '/freelancer/applications': 'freelancer.applications',
    '/profile/freelancer/edit': 'freelancer.profile.edit',
    '/profile/freelancer': 'freelancer.profile',
  };
}
