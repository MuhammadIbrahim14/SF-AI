import '../models/admin_model.dart';
import '../models/audit_log.dart';
import '../models/platform_settings.dart';
import '../models/platform_stats.dart';
import '../models/user_model.dart';
import '../models/verification_request.dart';

abstract class AdminRepository {
  Future<AdminModel?> getAdminProfile(String userId);
  Future<void> updateAdminProfile(AdminModel admin);

  Stream<List<UserModel>> streamAllUsers();
  Stream<List<UserModel>> streamAdminUsers();

  /// One-shot admin UIDs from `admins/{uid}` for support ticket fan-out.
  Future<List<String>> listAdminRecipientIds({int limit = 50});

  Future<void> updateUserStatus(
    String userId,
    String status, {
    required String adminId,
  });
  Future<void> promoteUserToAdmin(String identifier, {required String adminId});
  Future<void> promoteAdminToSuperAdmin(
    String userId, {
    required String adminId,
  });
  Future<void> demoteAdmin(String userId, {required String adminId});
  Future<void> updateUserRole(
    String userId,
    String role, {
    required String adminId,
  });
  /// Revokes Freelancer Bridge unlock only. Keeps student role and LMS data.
  Future<void> revokeFreelancerUnlock(
    String userId, {
    required String adminId,
  });
  Future<PlatformStats> getPlatformStats();

  Stream<List<VerificationRequest>> streamTeacherVerifications();
  Stream<List<VerificationRequest>> streamCompanyVerifications();
  Future<void> updateVerificationStatus(
    VerificationRequest request,
    String status, {
    required String adminId,
  });

  Stream<PlatformSettings> streamPlatformSettings();
  Future<void> updatePlatformSettings(
    PlatformSettings settings, {
    required String adminId,
  });
  Future<void> setMaintenanceMode(bool enabled, {required String adminId});

  Stream<List<AuditLog>> streamAuditLogs({int limit = 100});
}
