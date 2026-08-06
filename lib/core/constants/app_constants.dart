/// SkillForge AI — Application-wide Constants
abstract final class AppConstants {
  // ─── App Info ──────────────────────────────────────────────────────
  static const String appName = 'SkillForge AI';
  static const String appTagline = 'Forge Your Future with AI';

  // ─── Firestore Collections ─────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String rolesCollection = 'roles';
  static const String settingsCollection = 'settings';

  // ─── User Status Values ────────────────────────────────────────────
  static const String statusActive = 'active';
  static const String statusBanned = 'banned';
  static const String statusInactive = 'inactive';
  static const String statusSuspended = 'suspended';
  static const String statusPending = 'pending';

  // ─── Validation ────────────────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int minNameLength = 2;

  // ─── Storage Paths ─────────────────────────────────────────────────
  static const String profileImagesPath = 'profile_images';
}
