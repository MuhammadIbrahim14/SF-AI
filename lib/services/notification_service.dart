import '../core/notifications/notification_events.dart';
import '../core/utils/app_logger.dart';
import '../models/user_notification_model.dart';
import '../repositories/notification_repository.dart';

/// Shared write path for in-app notifications.
///
/// Never throws to callers — primary domain actions must not roll back
/// because a notification failed. Preferences are honored when present.
class NotificationService {
  const NotificationService(this._repo);

  final NotificationRepository _repo;

  /// Fan-out chunk size for parallel creates when not using a single batch.
  static const int fanOutChunkSize = 40;

  /// Creates one notification for [recipientId].
  ///
  /// Swallows errors after logging. Skips when the recipient disabled
  /// [category] under `users/{uid}.notificationPrefs.categories`.
  Future<void> notifyOne({
    required String recipientId,
    required String title,
    required String body,
    required String category,
    required String event,
    String? actorId,
    String? actorName,
    String? actorRole,
    String relatedPath = '',
    String? routeName,
    Map<String, String>? routeParams,
    String priority = 'normal',
    Map<String, dynamic>? meta,
    String? applicationId,
    String? type,
  }) async {
    try {
      final uid = recipientId.trim();
      if (uid.isEmpty) return;

      final allowed = await _isCategoryAllowed(uid, category);
      if (!allowed) return;

      final resolvedCategory = category.trim().isNotEmpty
          ? category.trim()
          : NotificationEventDefaults.categoryForEvent(event);
      final resolvedType = (type != null && type.trim().isNotEmpty)
          ? type.trim()
          : resolvedCategory;

      await _repo.createNotification(
        UserNotificationModel(
          id: '',
          userId: uid,
          title: title,
          body: body,
          type: resolvedType,
          category: resolvedCategory,
          event: event,
          relatedPath: relatedPath,
          createdAt: DateTime.now(),
          read: false,
          actorId: actorId,
          actorName: actorName,
          actorRole: actorRole,
          routeName: routeName,
          routeParams: routeParams ?? const {},
          priority: priority,
          meta: meta ?? const {},
          applicationId: applicationId,
        ),
      );
    } catch (_) {
      AppLogger.warn('A notification could not be sent.');
    }
  }

  /// Fan-out to many recipients (unique IDs). Chunks writes.
  Future<void> notifyMany({
    required Iterable<String> recipientIds,
    required String title,
    required String body,
    required String category,
    required String event,
    String? actorId,
    String? actorName,
    String? actorRole,
    String relatedPath = '',
    String? routeName,
    Map<String, String>? routeParams,
    String priority = 'normal',
    Map<String, dynamic>? meta,
    String? applicationId,
    String? type,
  }) async {
    try {
      final unique = recipientIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (unique.isEmpty) return;

      final resolvedCategory = category.trim().isNotEmpty
          ? category.trim()
          : NotificationEventDefaults.categoryForEvent(event);
      final resolvedType = (type != null && type.trim().isNotEmpty)
          ? type.trim()
          : resolvedCategory;

      final allowedRecipients = <String>[];
      for (var i = 0; i < unique.length; i += fanOutChunkSize) {
        final chunk = unique.skip(i).take(fanOutChunkSize);
        final checks = await Future.wait(
          chunk.map((uid) async {
            final ok = await _isCategoryAllowed(uid, resolvedCategory);
            return ok ? uid : null;
          }),
        );
        for (final uid in checks) {
          if (uid != null) allowedRecipients.add(uid);
        }
      }
      if (allowedRecipients.isEmpty) return;

      final now = DateTime.now();
      final models = allowedRecipients
          .map(
            (uid) => UserNotificationModel(
              id: '',
              userId: uid,
              title: title,
              body: body,
              type: resolvedType,
              category: resolvedCategory,
              event: event,
              relatedPath: relatedPath,
              createdAt: now,
              read: false,
              actorId: actorId,
              actorName: actorName,
              actorRole: actorRole,
              routeName: routeName,
              routeParams: routeParams ?? const {},
              priority: priority,
              meta: meta ?? const {},
              applicationId: applicationId,
            ),
          )
          .toList();

      await _repo.createNotifications(models);
    } catch (_) {
      AppLogger.warn('Notification delivery could not be completed.');
    }
  }

  Future<bool> _isCategoryAllowed(String userId, String category) async {
    try {
      final key = category.trim();
      // System alerts (payments, subscription) always deliver — not user-toggleable.
      if (key == NotificationCategories.system || key.isEmpty) return true;

      final prefs = await _repo.getNotificationPrefs(userId);
      if (prefs == null) return true;
      final categories = prefs['categories'];
      if (categories is! Map) return true;
      if (!categories.containsKey(key)) return true;
      final value = categories[key];
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() != 'false' && value != '0';
      }
      return true;
    } catch (_) {
      // Prefer delivering over blocking when prefs read fails.
      return true;
    }
  }
}
