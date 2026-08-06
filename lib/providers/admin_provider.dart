import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router/route_names.dart';
import '../core/notifications/notification_events.dart';
import '../models/admin_model.dart';
import '../models/audit_log.dart';
import '../models/platform_settings.dart';
import '../models/platform_stats.dart';
import '../models/user_model.dart';
import '../models/verification_request.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';

/// Fetches the profile data for the currently authenticated admin.
final adminProfileProvider = FutureProvider<AdminModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(adminRepositoryProvider).getAdminProfile(user.uid);
});

/// Fetches platform-wide statistics for the admin dashboard.
final platformStatsProvider = FutureProvider<PlatformStats>((ref) async {
  return ref.watch(adminRepositoryProvider).getPlatformStats();
});

/// Streams all users on the platform for management.
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAllUsers();
});

final adminUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAdminUsers();
});

final teacherVerificationsProvider = StreamProvider<List<VerificationRequest>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).streamTeacherVerifications();
});

final companyVerificationsProvider = StreamProvider<List<VerificationRequest>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).streamCompanyVerifications();
});

final platformSettingsProvider = StreamProvider<PlatformSettings>((ref) {
  return ref.watch(adminRepositoryProvider).streamPlatformSettings();
});

final auditLogsProvider = StreamProvider<List<AuditLog>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAuditLogs();
});

/// Notifier to handle user management actions by admins.
final adminActionProvider = AsyncNotifierProvider<AdminActionNotifier, void>(
  AdminActionNotifier.new,
);

class AdminActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateAccountStatus(String userId, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .updateUserStatus(userId, status, adminId: adminId);

      final normalized = status.trim().toLowerCase();
      if (normalized == 'banned' ||
          normalized == 'suspended' ||
          normalized == 'disabled') {
        final label = switch (normalized) {
          'banned' => 'banned',
          'suspended' => 'suspended',
          _ => 'disabled',
        };
        await ref.read(notificationServiceProvider).notifyOne(
          recipientId: userId,
          title: 'Account $label',
          body: 'Your account has been $label by an administrator.',
          category: NotificationCategories.admin,
          event: NotificationEvents.adminAccountStatusChanged,
          actorId: adminId,
          actorRole: 'admin',
          relatedPath: 'users/$userId',
          priority: 'high',
          meta: {'status': normalized},
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> updateVerification(
    VerificationRequest request,
    String status,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .updateVerificationStatus(request, status, adminId: adminId);

      if (status == 'approved' || status == 'rejected') {
        final decision = status == 'approved' ? 'approved' : 'rejected';
        final routeName = request.role == 'company'
            ? RouteNames.companyProfile
            : RouteNames.teacherProfile;
        await ref.read(notificationServiceProvider).notifyOne(
          recipientId: request.userId,
          title: 'Verification $decision',
          body:
              'Your ${request.role} verification request was $decision.',
          category: NotificationCategories.admin,
          event: NotificationEvents.adminVerificationDecided,
          actorId: adminId,
          actorRole: 'admin',
          relatedPath:
              '${request.role == 'company' ? 'companies' : 'teachers'}/${request.userId}',
          routeName: routeName,
          priority: 'high',
          meta: {
            'role': request.role,
            'status': status,
          },
        );
      }
    });
    return !state.hasError;
  }

  Future<bool> updateRole(String userId, String role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .updateUserRole(userId, role, adminId: adminId);
    });
    return !state.hasError;
  }

  Future<bool> revokeFreelancerUnlock(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .revokeFreelancerUnlock(userId, adminId: adminId);
    });
    return !state.hasError;
  }

  Future<bool> createAdmin(String identifier) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .promoteUserToAdmin(identifier, adminId: adminId);
    });
    return !state.hasError;
  }

  Future<bool> removeAdmin(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .demoteAdmin(userId, adminId: adminId);
    });
    return !state.hasError;
  }

  Future<bool> promoteToSuperAdmin(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .promoteAdminToSuperAdmin(userId, adminId: adminId);
    });
    return !state.hasError;
  }

  Future<bool> savePlatformSettings(PlatformSettings settings) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .updatePlatformSettings(settings, adminId: adminId);
    });
    return !state.hasError;
  }

  Future<bool> setMaintenanceMode(bool enabled) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = _requireAdminId();
      await ref
          .read(adminRepositoryProvider)
          .setMaintenanceMode(enabled, adminId: adminId);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();

  String _requireAdminId() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      throw StateError('An authenticated administrator is required.');
    }
    return user.uid;
  }
}
