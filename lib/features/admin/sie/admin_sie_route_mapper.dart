import 'package:skillforge_ai/app/router/route_names.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Maps SkillForge Admin GoRouter locations → SIE route policy ids.
///
/// Mirrors [CompanySieRouteMapper] — pure / deterministic.
/// Prefer security-safe defaults for unmatched `/admin/` paths.
abstract final class AdminSieRouteMapper {
  /// Resolve SIE route id from location + optional GoRouter name.
  static String resolve({
    required String location,
    String? routeName,
  }) {
    final path = _normalize(location);
    final byName = routeName == null ? null : _byRouteName[routeName];
    if (byName != null) return byName;

    if (path.startsWith('/admin/commerce/finance/') &&
        path.length > '/admin/commerce/finance/'.length) {
      return SieAdminRouteCatalog.billing.routeId;
    }
    if (path.startsWith('/admin/commerce/invoices/') &&
        path.length > '/admin/commerce/invoices/'.length) {
      return SieAdminRouteCatalog.billing.routeId;
    }

    final entries = _byPathPrefix.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      if (path == e.key || path.startsWith('${e.key}/')) {
        return e.value;
      }
    }

    if (path.startsWith('/dashboard/super-admin')) {
      return SieAdminRouteCatalog.superDashboard.routeId;
    }
    if (path.startsWith('/dashboard/admin')) {
      return SieSkillForgeRouteCatalog.adminDashboard.routeId;
    }
    if (path.startsWith('/admin/')) {
      // Unknown admin surface — prefer restricted org settings over open SIE.
      return SieAdminRouteCatalog.orgSettings.routeId;
    }
    if (path.contains('account-deletion')) {
      return SieAdminRouteCatalog.accountDeletion.routeId;
    }

    return SieSkillForgeRouteCatalog.adminDashboard.routeId;
  }

  /// Whether this location is an Admin Module SIE surface.
  static bool isAdminLocation(String location) {
    final path = _normalize(location);
    return path.startsWith('/dashboard/admin') ||
        path.startsWith('/dashboard/super-admin') ||
        path.startsWith('/admin/');
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
    RouteNames.adminDashboard: 'admin.dashboard',
    RouteNames.superAdminDashboard: 'admin.super_dashboard',
    RouteNames.adminInbox: 'admin.notifications',
    RouteNames.adminUserManagement: 'admin.users',
    RouteNames.adminManagement: 'admin.roles',
    RouteNames.adminVerification: 'admin.verification',
    RouteNames.adminAuditLogs: 'admin.audit_logs',
    RouteNames.adminSettings: 'admin.org_settings',
    RouteNames.adminThemeSettings: 'admin.theme',
    RouteNames.adminMotionSettings: 'admin.motion',
    RouteNames.adminSieControl: 'admin.feature_flags',
    RouteNames.adminLanguageSettings: 'admin.language',
    RouteNames.adminLegalEditor: 'admin.cms',
    RouteNames.adminReleaseCenter: 'admin.progressive_rollout',
    RouteNames.adminRecovery: 'admin.emergency',
    RouteNames.adminCommerceOrders: 'admin.billing',
    RouteNames.adminFinanceCenter: 'admin.billing',
    RouteNames.adminFinanceDetail: 'admin.billing',
    RouteNames.adminInvoices: 'admin.billing',
    RouteNames.adminInvoiceDetail: 'admin.billing',
    RouteNames.adminPayouts: 'admin.billing',
    RouteNames.adminMonetization: 'admin.billing',
    RouteNames.adminSuperTransactions: 'admin.billing',
    RouteNames.adminAiCredits: 'admin.billing',
    RouteNames.adminResolutionDesk: 'admin.resolutions',
    RouteNames.adminResolutionAiAnalyst: 'admin.ai_assistant',
    RouteNames.adminAiUsageControl: 'admin.ai_usage_control',
    RouteNames.adminEmailSettings: 'admin.auth_settings',
    RouteNames.accountDeletionPolicy: 'admin.account_deletion',
  };

  static const Map<String, String> _byPathPrefix = {
    '/dashboard/super-admin': 'admin.super_dashboard',
    '/dashboard/admin': 'admin.dashboard',
    '/admin/inbox': 'admin.notifications',
    '/admin/users': 'admin.users',
    '/admin/admins': 'admin.roles',
    '/admin/verification': 'admin.verification',
    '/admin/audit-logs': 'admin.audit_logs',
    '/admin/settings/theme': 'admin.theme',
    '/admin/settings/motion': 'admin.motion',
    '/admin/settings/sie': 'admin.feature_flags',
    '/admin/settings/language': 'admin.language',
    '/admin/settings/legal': 'admin.cms',
    '/admin/settings/release-center': 'admin.progressive_rollout',
    '/admin/settings': 'admin.org_settings',
    '/admin/recovery': 'admin.emergency',
    '/admin/commerce/orders': 'admin.billing',
    '/admin/commerce/finance': 'admin.billing',
    '/admin/commerce/invoices': 'admin.billing',
    '/admin/commerce/payouts': 'admin.billing',
    '/admin/commerce/resolutions': 'admin.resolutions',
    '/admin/resolution-ai-analyst': 'admin.ai_assistant',
    '/admin/ai-usage': 'admin.ai_usage_control',
    '/admin/ai-credits': 'admin.billing',
    '/admin/email-settings': 'admin.auth_settings',
    '/admin/monetization': 'admin.billing',
    '/admin/super-transactions': 'admin.billing',
  };
}
