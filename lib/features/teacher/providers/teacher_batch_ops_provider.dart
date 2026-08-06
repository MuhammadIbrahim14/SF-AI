import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../models/teacher_batch_announcement_model.dart';
import '../../../models/teacher_batch_attendance_model.dart';
import '../../../models/teacher_batch_join_request_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/teacher_batch_session_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';

DocumentReference<Map<String, dynamic>> _batchDoc(
  FirebaseFirestore firestore,
  String batchId,
) {
  return firestore.collection('teacherBatches').doc(batchId);
}

/// Live attendance session for one batch date (doc id YYYY-MM-DD).
final teacherBatchAttendanceProvider = StreamProvider.family<
  TeacherBatchAttendanceModel?,
  ({String batchId, String dateId})
>((ref, args) {
  final user = ref.watch(authStateProvider).value;
  final batchId = args.batchId.trim();
  final dateId = args.dateId.trim();
  if (user == null || batchId.isEmpty || dateId.isEmpty) {
    return Stream.value(null);
  }
  return _batchDoc(ref.watch(firestoreProvider), batchId)
      .collection('attendance')
      .doc(dateId)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return null;
        return TeacherBatchAttendanceModel.fromFirestore(snap);
      });
});

/// Announcements for a batch, newest first (roster students may also read).
final teacherBatchAnnouncementsProvider =
    StreamProvider.family<List<TeacherBatchAnnouncementModel>, String>((
      ref,
      batchId,
    ) {
      final user = ref.watch(authStateProvider).value;
      final id = batchId.trim();
      if (user == null || id.isEmpty) {
        return Stream.value(const <TeacherBatchAnnouncementModel>[]);
      }
      return _batchDoc(ref.watch(firestoreProvider), id)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(TeacherBatchAnnouncementModel.fromFirestore)
                .toList(),
          );
    });

/// Sessions for a batch, soonest-first by startsAt.
final teacherBatchSessionsProvider =
    StreamProvider.family<List<TeacherBatchSessionModel>, String>((
      ref,
      batchId,
    ) {
      final user = ref.watch(authStateProvider).value;
      final id = batchId.trim();
      if (user == null || id.isEmpty) {
        return Stream.value(const <TeacherBatchSessionModel>[]);
      }
      return _batchDoc(ref.watch(firestoreProvider), id)
          .collection('sessions')
          .orderBy('startsAt', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(TeacherBatchSessionModel.fromFirestore)
                .toList(),
          );
    });

/// Pending join requests for a batch, oldest first.
final teacherBatchJoinRequestsProvider =
    StreamProvider.family<List<TeacherBatchJoinRequestModel>, String>((
      ref,
      batchId,
    ) {
      final user = ref.watch(authStateProvider).value;
      final id = batchId.trim();
      if (user == null || id.isEmpty) {
        return Stream.value(const <TeacherBatchJoinRequestModel>[]);
      }
      return _batchDoc(ref.watch(firestoreProvider), id)
          .collection('joinRequests')
          .where('status', isEqualTo: TeacherBatchJoinRequestStatus.pending)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs
                .map(TeacherBatchJoinRequestModel.fromFirestore)
                .toList();
            items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return items;
          });
    });

final teacherBatchOpsProvider =
    AsyncNotifierProvider<TeacherBatchOpsNotifier, void>(
      TeacherBatchOpsNotifier.new,
    );

class TeacherBatchOpsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveAttendance({
    required String batchId,
    required String dateId,
    required Map<String, String> records,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      final id = batchId.trim();
      final date = dateId.trim();
      if (id.isEmpty || date.isEmpty) {
        throw StateError('Batch and date are required.');
      }
      final normalized = <String, String>{};
      for (final entry in records.entries) {
        final studentId = entry.key.trim();
        if (studentId.isEmpty) continue;
        normalized[studentId] = TeacherBatchAttendanceStatus.normalize(
          entry.value,
        );
      }
      final model = TeacherBatchAttendanceModel(
        dateId: date,
        date: date,
        records: normalized,
        teacherId: user.uid,
        updatedAt: DateTime.now(),
      );
      await _batchDoc(ref.read(firestoreProvider), id)
          .collection('attendance')
          .doc(date)
          .set(model.toJson(), SetOptions(merge: true));
    });
    return !state.hasError;
  }

  Future<bool> createAnnouncement({
    required String batchId,
    required String title,
    required String body,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      final id = batchId.trim();
      if (id.isEmpty) throw StateError('Batch is required.');
      if (title.trim().isEmpty) {
        throw StateError('Announcement title is required.');
      }
      final firestore = ref.read(firestoreProvider);
      final batchRef = _batchDoc(firestore, id);
      final batchSnap = await batchRef.get();
      if (!batchSnap.exists) throw StateError('Batch not found.');
      final batch = TeacherBatchModel.fromFirestore(batchSnap);

      final doc = batchRef.collection('announcements').doc();
      final model = TeacherBatchAnnouncementModel(
        id: doc.id,
        title: title.trim(),
        body: body.trim(),
        teacherId: user.uid,
        createdAt: DateTime.now(),
      );
      await doc.set(model.toJson());

      final roster = batch.studentIds
          .map((sid) => sid.trim())
          .where((sid) => sid.isNotEmpty && sid != user.uid);
      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final batchTitle = batch.title.trim().isEmpty
          ? 'your class'
          : batch.title.trim();
      await ref.read(notificationServiceProvider).notifyMany(
        recipientIds: roster,
        title: 'New class announcement',
        body: '${model.title} — $batchTitle',
        category: NotificationCategories.batch,
        event: NotificationEvents.batchAnnouncementPosted,
        actorId: user.uid,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'teacherBatches/$id/announcements/${doc.id}',
        routeName: RouteNames.studentClassAnnouncements,
        meta: {
          'batchId': id,
          'batchTitle': batch.title,
          'announcementId': doc.id,
        },
      );
    });
    return !state.hasError;
  }

  Future<bool> saveSession({
    required String batchId,
    String? sessionId,
    required String title,
    String notes = '',
    required DateTime startsAt,
    DateTime? endsAt,
    String status = TeacherBatchSessionStatus.scheduled,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      final id = batchId.trim();
      if (id.isEmpty) throw StateError('Batch is required.');
      if (title.trim().isEmpty) throw StateError('Session title is required.');
      if (endsAt != null && endsAt.isBefore(startsAt)) {
        throw StateError('End time must be on or after start time.');
      }
      final now = DateTime.now();
      final firestore = ref.read(firestoreProvider);
      final batchRef = _batchDoc(firestore, id);
      final isCreate = sessionId == null || sessionId.isEmpty;
      final col = batchRef.collection('sessions');
      final doc = isCreate ? col.doc() : col.doc(sessionId);
      final existing = isCreate ? null : await doc.get();
      final createdAt = existing?.data()?['createdAt'] is Timestamp
          ? (existing!.data()!['createdAt'] as Timestamp).toDate()
          : now;
      final model = TeacherBatchSessionModel(
        sessionId: doc.id,
        title: title.trim(),
        notes: notes.trim(),
        startsAt: startsAt,
        endsAt: endsAt,
        status: TeacherBatchSessionStatus.normalize(status),
        teacherId: user.uid,
        createdAt: createdAt,
        updatedAt: now,
      );
      final payload = model.toJson();
      if (endsAt == null) {
        if (existing != null && existing.exists) {
          payload['endsAt'] = FieldValue.delete();
        } else {
          payload.remove('endsAt');
        }
      } else {
        payload['endsAt'] = Timestamp.fromDate(endsAt);
      }
      await doc.set(payload, SetOptions(merge: true));

      final batchSnap = await batchRef.get();
      if (batchSnap.exists) {
        final batch = TeacherBatchModel.fromFirestore(batchSnap);
        final normalizedStatus = TeacherBatchSessionStatus.normalize(status);
        final isCancelled =
            normalizedStatus == TeacherBatchSessionStatus.cancelled;
        if (isCreate) {
          await _notifySessionRoster(
            batch: batch,
            batchId: id,
            sessionId: doc.id,
            sessionTitle: model.title,
            teacherId: user.uid,
            event: NotificationEvents.batchSessionScheduled,
            title: 'Session scheduled',
            bodyPrefix: model.title,
          );
        } else if (isCancelled) {
          await _notifySessionRoster(
            batch: batch,
            batchId: id,
            sessionId: doc.id,
            sessionTitle: model.title,
            teacherId: user.uid,
            event: NotificationEvents.batchSessionCancelled,
            title: 'Session cancelled',
            bodyPrefix: model.title,
          );
        } else {
          await _notifySessionRoster(
            batch: batch,
            batchId: id,
            sessionId: doc.id,
            sessionTitle: model.title,
            teacherId: user.uid,
            event: NotificationEvents.batchSessionUpdated,
            title: 'Session updated',
            bodyPrefix: model.title,
          );
        }
      }
    });
    return !state.hasError;
  }

  Future<bool> updateSessionStatus({
    required String batchId,
    required String sessionId,
    required String status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      final id = batchId.trim();
      final sid = sessionId.trim();
      if (id.isEmpty || sid.isEmpty) {
        throw StateError('Batch and session are required.');
      }
      final normalized = TeacherBatchSessionStatus.normalize(status);
      final firestore = ref.read(firestoreProvider);
      final batchRef = _batchDoc(firestore, id);
      final sessionRef = batchRef.collection('sessions').doc(sid);
      final sessionSnap = await sessionRef.get();
      await sessionRef.set({
        'status': normalized,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'teacherId': user.uid,
      }, SetOptions(merge: true));

      if (normalized == TeacherBatchSessionStatus.cancelled) {
        final batchSnap = await batchRef.get();
        if (batchSnap.exists) {
          final batch = TeacherBatchModel.fromFirestore(batchSnap);
          final sessionTitle =
              (sessionSnap.data()?['title'] as String?)?.trim() ?? 'Session';
          await _notifySessionRoster(
            batch: batch,
            batchId: id,
            sessionId: sid,
            sessionTitle: sessionTitle.isEmpty ? 'Session' : sessionTitle,
            teacherId: user.uid,
            event: NotificationEvents.batchSessionCancelled,
            title: 'Session cancelled',
            bodyPrefix: sessionTitle.isEmpty ? 'Session' : sessionTitle,
          );
        }
      }
    });
    return !state.hasError;
  }

  Future<void> _notifySessionRoster({
    required TeacherBatchModel batch,
    required String batchId,
    required String sessionId,
    required String sessionTitle,
    required String teacherId,
    required String event,
    required String title,
    required String bodyPrefix,
  }) async {
    try {
      final roster = batch.studentIds
          .map((sid) => sid.trim())
          .where((sid) => sid.isNotEmpty && sid != teacherId);
      if (roster.isEmpty) return;

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final batchTitle = batch.title.trim().isEmpty
          ? 'your class'
          : batch.title.trim();
      await ref.read(notificationServiceProvider).notifyMany(
        recipientIds: roster,
        title: title,
        body: '$bodyPrefix — $batchTitle',
        category: NotificationCategories.batch,
        event: event,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'teacherBatches/$batchId/sessions/$sessionId',
        routeName: RouteNames.studentBatchDetail,
        routeParams: {'batchId': batchId},
        meta: {
          'batchId': batchId,
          'batchTitle': batch.title,
          'sessionId': sessionId,
          'sessionTitle': sessionTitle,
        },
      );
    } catch (_) {
      // Never fail session save because of inbox write.
    }
  }
}
