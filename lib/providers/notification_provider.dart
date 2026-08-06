import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../models/user_notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

final myNotificationsProvider =
    StreamProvider<List<UserNotificationModel>>((ref) {
      // Prefer asData so auth loading flicker does not tear down the stream
      // (empty → data flash) and wipe the inbox / badge.
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) {
        return Stream.value(const <UserNotificationModel>[]);
      }
      return ref
          .watch(notificationRepositoryProvider)
          .streamUserNotifications(uid);
    });

final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(myNotificationsProvider);
  // Prefer asData; fall back to .value when available during reload.
  final notifications = async.asData?.value ?? async.value;
  if (notifications == null) return 0;
  return notifications.where((n) => !n.read).length;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(notificationRepositoryProvider));
});

final notificationActionProvider =
    AsyncNotifierProvider<NotificationActionNotifier, void>(
      NotificationActionNotifier.new,
    );

class NotificationActionNotifier extends AsyncNotifier<void> {
  NotificationRepository get _repo =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<void> build() async {}

  String? get lastErrorMessage {
    final err = state.error;
    if (err == null) return null;
    if (err is AppException) return err.message;
    return err.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<bool> markRead(String notificationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.markNotificationRead(notificationId);
    });
    return !state.hasError;
  }

  Future<bool> markAllRead() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) return;
      await _repo.markAllNotificationsRead(user.uid);
    });
    return !state.hasError;
  }
}
