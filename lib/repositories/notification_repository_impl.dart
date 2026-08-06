import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/user_notification_model.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('user_notifications');

  @override
  Future<void> createNotification(UserNotificationModel notification) async {
    try {
      final ref = _notificationsRef.doc();
      await ref.set(notification.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to create notification: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> createNotifications(
    List<UserNotificationModel> notifications,
  ) async {
    if (notifications.isEmpty) return;
    try {
      // Firestore batch limit is 500; keep headroom.
      const chunkSize = 400;
      for (var i = 0; i < notifications.length; i += chunkSize) {
        final chunk = notifications.skip(i).take(chunkSize).toList();
        final batch = _firestore.batch();
        for (final notification in chunk) {
          final ref = _notificationsRef.doc();
          batch.set(ref, notification.toJson());
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to create notifications: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<UserNotificationModel>> streamUserNotifications(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(UserNotificationModel.fromFirestore)
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'read': true});
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to mark notification read: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    try {
      // Avoid composite index (userId + read): filter unread client-side.
      final snapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();
      final unread = snapshot.docs
          .where((doc) => doc.data()['read'] != true)
          .toList();
      if (unread.isEmpty) return;

      const chunkSize = 400;
      for (var i = 0; i < unread.length; i += chunkSize) {
        final chunk = unread.skip(i).take(chunkSize).toList();
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to mark all notifications read: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getNotificationPrefs(String userId) async {
    try {
      final snap = await _firestore.collection('users').doc(userId).get();
      final data = snap.data();
      if (data == null) return null;
      final prefs = data['notificationPrefs'];
      if (prefs is Map) {
        return Map<String, dynamic>.from(prefs);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
