import '../models/user_notification_model.dart';

/// Persistence for `user_notifications`.
abstract class NotificationRepository {
  Future<void> createNotification(UserNotificationModel notification);

  /// Creates many notifications (caller should chunk if needed).
  Future<void> createNotifications(List<UserNotificationModel> notifications);

  Stream<List<UserNotificationModel>> streamUserNotifications(String userId);

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead(String userId);

  /// Reads `users/{uid}.notificationPrefs` when present.
  Future<Map<String, dynamic>?> getNotificationPrefs(String userId);
}
