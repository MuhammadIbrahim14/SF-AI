import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../models/teacher_batch_announcement_model.dart';
import '../../../models/teacher_batch_join_request_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';

/// Batches where the signed-in student is on the roster.
final studentRosterBatchesProvider =
    StreamProvider<List<TeacherBatchModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <TeacherBatchModel>[]);
      return ref
          .watch(firestoreProvider)
          .collection('teacherBatches')
          .where('studentIds', arrayContains: user.uid)
          .snapshots()
          .map((snapshot) {
            final batches = snapshot.docs
                .map(TeacherBatchModel.fromFirestore)
                .toList();
            batches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return batches;
          });
    });

/// Roster batch by id (null when not found / not a member).
final studentBatchByIdProvider =
    Provider.family<TeacherBatchModel?, String>((ref, batchId) {
      final id = batchId.trim();
      if (id.isEmpty) return null;
      final batches = ref.watch(studentRosterBatchesProvider).value;
      if (batches == null) return null;
      for (final batch in batches) {
        if (batch.batchId == id) return batch;
      }
      return null;
    });

/// Own join request with parent batch id (from document path).
class StudentJoinRequestItem {
  const StudentJoinRequestItem({
    required this.batchId,
    required this.request,
  });

  final String batchId;
  final TeacherBatchJoinRequestModel request;
}

String _batchIdFromJoinRequestPath(String path) {
  // teacherBatches/{batchId}/joinRequests/{requestId}
  final parts = path.split('/');
  if (parts.length >= 2 && parts.first == 'teacherBatches') {
    return parts[1];
  }
  return '';
}

/// Student's own join requests across batches (collection group).
final studentJoinRequestsProvider =
    StreamProvider<List<StudentJoinRequestItem>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <StudentJoinRequestItem>[]);
      return ref
          .watch(firestoreProvider)
          .collectionGroup('joinRequests')
          .where('studentId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs.map((doc) {
              return StudentJoinRequestItem(
                batchId: _batchIdFromJoinRequestPath(doc.reference.path),
                request: TeacherBatchJoinRequestModel.fromFirestore(doc),
              );
            }).toList();
            items.sort(
              (a, b) => b.request.createdAt.compareTo(a.request.createdAt),
            );
            return items;
          });
    });

class StudentBatchAnnouncementItem {
  const StudentBatchAnnouncementItem({
    required this.batch,
    required this.announcement,
  });

  final TeacherBatchModel batch;
  final TeacherBatchAnnouncementModel announcement;
}

/// Announcements from all batches on the student's roster, newest first.
final studentClassAnnouncementsProvider =
    FutureProvider<List<StudentBatchAnnouncementItem>>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const <StudentBatchAnnouncementItem>[];

      // Rebuild when roster membership changes.
      final batches = await ref.watch(studentRosterBatchesProvider.future);
      if (batches.isEmpty) return const <StudentBatchAnnouncementItem>[];

      final firestore = ref.read(firestoreProvider);
      final results = await Future.wait(
        batches.map((batch) async {
          final snap = await firestore
              .collection('teacherBatches')
              .doc(batch.batchId)
              .collection('announcements')
              .orderBy('createdAt', descending: true)
              .limit(40)
              .get();
          return snap.docs
              .map(TeacherBatchAnnouncementModel.fromFirestore)
              .map(
                (announcement) => StudentBatchAnnouncementItem(
                  batch: batch,
                  announcement: announcement,
                ),
              )
              .toList();
        }),
      );

      final flat = results.expand((items) => items).toList();
      flat.sort(
        (a, b) =>
            b.announcement.createdAt.compareTo(a.announcement.createdAt),
      );
      return flat;
    });

final studentBatchActionProvider =
    AsyncNotifierProvider<StudentBatchActionNotifier, void>(
      StudentBatchActionNotifier.new,
    );

class StudentBatchActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Looks up invite code via `batchInviteCodes/{code}` and creates a pending
  /// join request. Does not write enrollments.
  Future<bool> requestJoinByInviteCode(String rawCode) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authUser = ref.read(authStateProvider).value;
      if (authUser == null) throw StateError('Student sign-in required.');
      final code = rawCode.trim().toUpperCase();
      if (code.length < 4) {
        throw StateError('Enter a valid invite code.');
      }

      final profile = ref.read(currentUserProvider).value;
      final firestore = ref.read(firestoreProvider);
      final inviteSnap =
          await firestore.collection('batchInviteCodes').doc(code).get();
      if (!inviteSnap.exists) {
        throw StateError('Invite code not found.');
      }
      final invite = inviteSnap.data() ?? const <String, dynamic>{};
      if (invite['enabled'] != true) {
        throw StateError('This invite code is disabled.');
      }
      final batchId = (invite['batchId']?.toString() ?? '').trim();
      if (batchId.isEmpty) throw StateError('Invalid invite.');

      // Do not read parent batch here — non-members lack parent read until
      // approved. Roster/duplicate checks are enforced by Firestore rules and
      // a student-scoped pending-request query.

      final existing = await firestore
          .collection('teacherBatches')
          .doc(batchId)
          .collection('joinRequests')
          .where('studentId', isEqualTo: authUser.uid)
          .limit(5)
          .get();
      final hasPending = existing.docs.any((doc) {
        final status = (doc.data()['status']?.toString() ?? '').trim();
        return status == TeacherBatchJoinRequestStatus.pending;
      });
      if (hasPending) {
        throw StateError('You already have a pending request for this batch.');
      }

      final doc = firestore
          .collection('teacherBatches')
          .doc(batchId)
          .collection('joinRequests')
          .doc();
      final model = TeacherBatchJoinRequestModel(
        requestId: doc.id,
        studentId: authUser.uid,
        studentName: (profile?.fullName ?? '').trim(),
        studentEmail: (profile?.email ?? authUser.email ?? '').trim(),
        status: TeacherBatchJoinRequestStatus.pending,
        createdAt: DateTime.now(),
      );
      // Create payload must match rules hasOnly (no updatedAt).
      await doc.set({
        'studentId': model.studentId,
        'studentName': model.studentName,
        'studentEmail': model.studentEmail,
        'status': TeacherBatchJoinRequestStatus.pending,
        'createdAt': Timestamp.fromDate(model.createdAt),
      });

      final teacherId = (invite['teacherId']?.toString() ?? '').trim();
      if (teacherId.isNotEmpty) {
        final studentLabel = model.studentName.isNotEmpty
            ? model.studentName
            : 'A student';
        await ref.read(notificationServiceProvider).notifyOne(
          recipientId: teacherId,
          title: 'New join request',
          body: '$studentLabel requested to join your batch.',
          category: NotificationCategories.batch,
          event: NotificationEvents.batchJoinRequested,
          actorId: authUser.uid,
          actorName: model.studentName.isEmpty ? null : model.studentName,
          actorRole: 'student',
          relatedPath: 'teacherBatches/$batchId/joinRequests/${doc.id}',
          routeName: RouteNames.teacherBatchDetail,
          routeParams: {'batchId': batchId},
          meta: {'batchId': batchId},
        );
      }
    });
    return !state.hasError;
  }
}
