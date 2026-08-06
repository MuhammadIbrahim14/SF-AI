import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../models/teacher_batch_join_request_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';
import '../../courses/data/models/enrollment_model.dart';
import '../../courses/providers/enrollment_provider.dart';
import '../data/models/teacher_student_progress_model.dart';
import 'teacher_student_progress_provider.dart';

const _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateTeacherBatchInviteCode({int length = 7}) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => _inviteAlphabet[random.nextInt(_inviteAlphabet.length)],
  ).join();
}

String teacherBatchCourseIdsKey(Iterable<String> courseIds) {
  final normalized = courseIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return normalized.join('|');
}

final teacherBatchesProvider = StreamProvider<List<TeacherBatchModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <TeacherBatchModel>[]);
  return ref
      .watch(firestoreProvider)
      .collection('teacherBatches')
      .where('teacherId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
        final batches = snapshot.docs
            .map((doc) => TeacherBatchModel.fromFirestore(doc))
            .toList();
        batches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return batches;
      });
});

final teacherBatchByIdProvider = Provider.family<TeacherBatchModel?, String>((
  ref,
  batchId,
) {
  final batches = ref.watch(teacherBatchesProvider).value;
  if (batches == null || batchId.trim().isEmpty) return null;
  for (final batch in batches) {
    if (batch.batchId == batchId) return batch;
  }
  return null;
});

/// Active enrollments across the given course IDs (teacher-owned only).
/// Family key should be [teacherBatchCourseIdsKey].
final teacherBatchActiveEnrollmentsProvider =
    FutureProvider.family<List<EnrollmentModel>, String>((ref, courseIdsKey) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null || courseIdsKey.isEmpty) {
        return const <EnrollmentModel>[];
      }
      final courseIds = courseIdsKey.split('|');
      final repo = ref.watch(enrollmentRepositoryProvider);
      final batches = await Future.wait(
        courseIds.map(repo.getCourseEnrollments),
      );
      final enrollments = <EnrollmentModel>[];
      final seen = <String>{};
      for (final list in batches) {
        for (final enrollment in list) {
          if (enrollment.teacherId != user.uid || !enrollment.isActive) {
            continue;
          }
          if (!seen.add(enrollment.enrollmentId)) continue;
          enrollments.add(enrollment);
        }
      }
      return enrollments;
    });

final teacherBatchProgressProvider =
    Provider.family<TeacherBatchProgressSummary, TeacherBatchModel>((
      ref,
      batch,
    ) {
      final records =
          ref.watch(teacherStudentProgressProvider).value ??
          const <TeacherStudentProgressModel>[];

      // Empty courseIds AND empty studentIds → empty summary (not "all").
      if (batch.courseIds.isEmpty && batch.studentIds.isEmpty) {
        return TeacherBatchProgressSummary.fromRecords(
          const <TeacherStudentProgressModel>[],
        );
      }

      final filtered = records.where((record) {
        final courseMatches =
            batch.courseIds.isEmpty ||
            batch.courseIds.contains(record.courseId);
        final studentMatches =
            batch.studentIds.isEmpty ||
            batch.studentIds.contains(record.studentId);
        return courseMatches && studentMatches;
      }).toList();
      return TeacherBatchProgressSummary.fromRecords(filtered);
    });

final teacherBatchActionProvider =
    AsyncNotifierProvider<TeacherBatchActionNotifier, void>(
      TeacherBatchActionNotifier.new,
    );

class TeacherBatchActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<List<String>> resolveActiveEnrollmentStudentIds(
    List<String> courseIds,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) throw StateError('Teacher sign-in required.');
    final normalized = courseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return const <String>[];

    final key = teacherBatchCourseIdsKey(normalized);
    final enrollments = await ref.read(
      teacherBatchActiveEnrollmentsProvider(key).future,
    );
    final studentIds = enrollments
        .map((item) => item.studentId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return studentIds;
  }

  Future<bool> saveBatch({
    String? batchId,
    required String title,
    required String description,
    required List<String> courseIds,
    required List<String> studentIds,
    DateTime? startDate,
    DateTime? endDate,
    String status = TeacherBatchStatus.active,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      if (title.trim().isEmpty) {
        throw StateError('Batch title is required.');
      }
      if (startDate != null &&
          endDate != null &&
          endDate.isBefore(startDate)) {
        throw StateError('End date must be on or after start date.');
      }
      final now = DateTime.now();
      final collection = ref
          .read(firestoreProvider)
          .collection('teacherBatches');
      final doc = batchId == null || batchId.isEmpty
          ? collection.doc()
          : collection.doc(batchId);
      final existing = batchId == null || batchId.isEmpty
          ? null
          : await doc.get();
      final createdAt = existing?.data()?['createdAt'] is Timestamp
          ? (existing!.data()!['createdAt'] as Timestamp).toDate()
          : now;
      final model = TeacherBatchModel(
        batchId: doc.id,
        teacherId: user.uid,
        title: title.trim(),
        description: description.trim(),
        courseIds: courseIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(),
        studentIds: studentIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(),
        startDate: startDate,
        endDate: endDate,
        status: TeacherBatchStatus.normalize(status),
        createdAt: createdAt,
        updatedAt: now,
      );
      final payload = model.toJson();
      // Ensure clearing dates works with merge writes.
      payload['startDate'] = startDate == null
          ? FieldValue.delete()
          : Timestamp.fromDate(startDate);
      payload['endDate'] = endDate == null
          ? FieldValue.delete()
          : Timestamp.fromDate(endDate);
      await doc.set(payload, SetOptions(merge: true));
    });
    return !state.hasError;
  }

  Future<bool> archiveBatch(TeacherBatchModel batch) {
    return saveBatch(
      batchId: batch.batchId,
      title: batch.title,
      description: batch.description,
      courseIds: batch.courseIds,
      studentIds: batch.studentIds,
      startDate: batch.startDate,
      endDate: batch.endDate,
      status: TeacherBatchStatus.archived,
    );
  }

  Future<bool> unarchiveBatch(TeacherBatchModel batch) {
    return saveBatch(
      batchId: batch.batchId,
      title: batch.title,
      description: batch.description,
      courseIds: batch.courseIds,
      studentIds: batch.studentIds,
      startDate: batch.startDate,
      endDate: batch.endDate,
      status: TeacherBatchStatus.active,
    );
  }

  /// Replaces [batch.studentIds] with the union of active enrollments
  /// across the batch's selected courses. Does not write enrollments.
  Future<bool> syncRosterFromEnrollments(TeacherBatchModel batch) async {
    state = const AsyncLoading();
    try {
      final studentIds = await resolveActiveEnrollmentStudentIds(
        batch.courseIds,
      );
      return saveBatch(
        batchId: batch.batchId,
        title: batch.title,
        description: batch.description,
        courseIds: batch.courseIds,
        studentIds: studentIds,
        startDate: batch.startDate,
        endDate: batch.endDate,
        status: batch.status,
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Regenerates invite code and optionally enables it. Updates parent batch
  /// fields and the `batchInviteCodes/{code}` lookup index.
  Future<bool> regenerateInvite(
    TeacherBatchModel batch, {
    bool enable = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      final id = batch.batchId.trim();
      if (id.isEmpty) throw StateError('Batch is required.');

      final firestore = ref.read(firestoreProvider);
      final batchRef = firestore.collection('teacherBatches').doc(id);
      final index = firestore.collection('batchInviteCodes');
      final now = DateTime.now();
      final newCode = generateTeacherBatchInviteCode();

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(batchRef);
        if (!snap.exists) throw StateError('Batch not found.');
        final data = snap.data() ?? const <String, dynamic>{};
        if (data['teacherId'] != user.uid) {
          throw StateError('Not your batch.');
        }
        final oldCode = (data['inviteCode']?.toString() ?? '')
            .trim()
            .toUpperCase();
        if (oldCode.isNotEmpty && oldCode != newCode) {
          tx.delete(index.doc(oldCode));
        }
        tx.set(batchRef, {
          'inviteCode': newCode,
          'inviteEnabled': enable,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        tx.set(index.doc(newCode), {
          'batchId': id,
          'teacherId': user.uid,
          'enabled': enable,
          'updatedAt': Timestamp.fromDate(now),
        });
      });
    });
    return !state.hasError;
  }

  Future<bool> setInviteEnabled(TeacherBatchModel batch, bool enabled) async {
    var code = batch.inviteCode.trim().toUpperCase();
    if (enabled && code.isEmpty) {
      return regenerateInvite(batch, enable: true);
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      final id = batch.batchId.trim();
      if (id.isEmpty) throw StateError('Batch is required.');

      final firestore = ref.read(firestoreProvider);
      final batchRef = firestore.collection('teacherBatches').doc(id);
      final index = firestore.collection('batchInviteCodes');
      final now = DateTime.now();

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(batchRef);
        if (!snap.exists) throw StateError('Batch not found.');
        final data = snap.data() ?? const <String, dynamic>{};
        if (data['teacherId'] != user.uid) {
          throw StateError('Not your batch.');
        }
        code = (data['inviteCode']?.toString() ?? code).trim().toUpperCase();
        if (code.isEmpty) {
          throw StateError('Generate an invite code first.');
        }
        tx.set(batchRef, {
          'inviteEnabled': enabled,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        tx.set(index.doc(code), {
          'batchId': id,
          'teacherId': user.uid,
          'enabled': enabled,
          'updatedAt': Timestamp.fromDate(now),
        });
      });
    });
    return !state.hasError;
  }

  /// Approves a pending join request: adds student to [batch.studentIds] only
  /// (does not write LMS enrollments) and marks the request approved.
  Future<bool> approveJoinRequest({
    required TeacherBatchModel batch,
    required TeacherBatchJoinRequestModel request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      if (!request.isPending) {
        throw StateError('Request is no longer pending.');
      }
      final studentId = request.studentId.trim();
      if (studentId.isEmpty) throw StateError('Invalid student.');

      final firestore = ref.read(firestoreProvider);
      final batchRef = firestore.collection('teacherBatches').doc(batch.batchId);
      final requestRef = batchRef.collection('joinRequests').doc(request.requestId);
      final now = DateTime.now();

      await firestore.runTransaction((tx) async {
        final batchSnap = await tx.get(batchRef);
        if (!batchSnap.exists) throw StateError('Batch not found.');
        final batchData = batchSnap.data() ?? const <String, dynamic>{};
        if (batchData['teacherId'] != user.uid) {
          throw StateError('Not your batch.');
        }
        final reqSnap = await tx.get(requestRef);
        if (!reqSnap.exists) throw StateError('Request not found.');
        final reqData = reqSnap.data() ?? const <String, dynamic>{};
        if (reqData['status'] != TeacherBatchJoinRequestStatus.pending) {
          throw StateError('Request is no longer pending.');
        }
        final existing = <String>{
          for (final id in (batchData['studentIds'] as List<dynamic>? ?? const [])
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty))
            id,
        };
        existing.add(studentId);
        tx.update(batchRef, {
          'studentIds': existing.toList()..sort(),
          'updatedAt': Timestamp.fromDate(now),
        });
        tx.update(requestRef, {
          'status': TeacherBatchJoinRequestStatus.approved,
          'updatedAt': Timestamp.fromDate(now),
        });
      });

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final batchTitle = batch.title.trim().isEmpty
          ? 'your batch'
          : batch.title.trim();
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: 'Join request approved',
        body: 'You were approved to join $batchTitle.',
        category: NotificationCategories.batch,
        event: NotificationEvents.batchJoinApproved,
        actorId: user.uid,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'teacherBatches/${batch.batchId}',
        routeName: RouteNames.studentBatchDetail,
        routeParams: {'batchId': batch.batchId},
        meta: {
          'batchId': batch.batchId,
          'batchTitle': batch.title,
        },
      );
    });
    return !state.hasError;
  }

  Future<bool> denyJoinRequest({
    required TeacherBatchModel batch,
    required TeacherBatchJoinRequestModel request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Teacher sign-in required.');
      if (!request.isPending) {
        throw StateError('Request is no longer pending.');
      }
      final studentId = request.studentId.trim();
      if (studentId.isEmpty) throw StateError('Invalid student.');
      final firestore = ref.read(firestoreProvider);
      final requestRef = firestore
          .collection('teacherBatches')
          .doc(batch.batchId)
          .collection('joinRequests')
          .doc(request.requestId);
      await requestRef.update({
        'status': TeacherBatchJoinRequestStatus.denied,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final batchTitle = batch.title.trim().isEmpty
          ? 'a batch'
          : batch.title.trim();
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: 'Join request declined',
        body: 'Your request to join $batchTitle was declined.',
        category: NotificationCategories.batch,
        event: NotificationEvents.batchJoinDenied,
        actorId: user.uid,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'teacherBatches/${batch.batchId}',
        routeName: RouteNames.studentMyBatches,
        meta: {
          'batchId': batch.batchId,
          'batchTitle': batch.title,
        },
      );
    });
    return !state.hasError;
  }
}

class TeacherBatchRosterEntry {
  const TeacherBatchRosterEntry({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.averageProgress,
    required this.isAtRisk,
    required this.needsAttention,
    required this.riskReasons,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final double averageProgress;
  final bool isAtRisk;
  final bool needsAttention;
  final List<String> riskReasons;
}

final teacherBatchRosterProvider =
    Provider.family<List<TeacherBatchRosterEntry>, TeacherBatchModel>((
      ref,
      batch,
    ) {
      final summary = ref.watch(teacherBatchProgressProvider(batch));
      final byStudent = <String, List<TeacherStudentProgressModel>>{};
      for (final record in summary.records) {
        byStudent.putIfAbsent(record.studentId, () => []).add(record);
      }

      final entries = <TeacherBatchRosterEntry>[];
      final covered = <String>{};

      for (final studentId in batch.studentIds) {
        covered.add(studentId);
        final records = byStudent[studentId] ?? const [];
        if (records.isEmpty) {
          entries.add(
            TeacherBatchRosterEntry(
              studentId: studentId,
              studentName: _shortStudentLabel(studentId),
              studentEmail: '',
              averageProgress: 0,
              isAtRisk: false,
              needsAttention: false,
              riskReasons: const [],
            ),
          );
          continue;
        }
        entries.add(_rosterEntryFromRecords(studentId, records));
      }

      // When only courses are set (no explicit roster), show students from
      // progress filter so the detail table is still useful.
      if (batch.studentIds.isEmpty && batch.courseIds.isNotEmpty) {
        for (final entry in byStudent.entries) {
          if (covered.contains(entry.key)) continue;
          entries.add(_rosterEntryFromRecords(entry.key, entry.value));
        }
      }

      entries.sort(
        (a, b) => a.studentName.toLowerCase().compareTo(
          b.studentName.toLowerCase(),
        ),
      );
      return entries;
    });

TeacherBatchRosterEntry _rosterEntryFromRecords(
  String studentId,
  List<TeacherStudentProgressModel> records,
) {
  final average = records.isEmpty
      ? 0.0
      : records.map((item) => item.lessonProgress).reduce((a, b) => a + b) /
            records.length;
  final reasons = <String>{};
  var isAtRisk = false;
  var needsAttention = false;
  for (final record in records) {
    if (record.isAtRisk) isAtRisk = true;
    if (record.needsAttention) needsAttention = true;
    reasons.addAll(record.riskReasons);
  }
  final name = records.first.studentName.trim();
  final email = records.first.studentEmail.trim();
  return TeacherBatchRosterEntry(
    studentId: studentId,
    studentName: name.isEmpty ? _shortStudentLabel(studentId) : name,
    studentEmail: email,
    averageProgress: average.clamp(0, 100).toDouble(),
    isAtRisk: isAtRisk,
    needsAttention: needsAttention && !isAtRisk,
    riskReasons: reasons.take(4).toList(),
  );
}

String _shortStudentLabel(String studentId) {
  final trimmed = studentId.trim();
  if (trimmed.length <= 8) return trimmed.isEmpty ? 'Student' : trimmed;
  return '${trimmed.substring(0, 6)}…';
}

class TeacherBatchProgressSummary {
  const TeacherBatchProgressSummary({
    required this.records,
    required this.totalStudents,
    required this.assignedCourses,
    required this.averageProgress,
    required this.pendingAssignments,
    required this.grandTestsPassed,
    required this.grandTestsFailed,
    required this.atRiskStudents,
    required this.needsAttentionStudents,
    required this.commonWeakAreas,
  });

  final List<TeacherStudentProgressModel> records;
  final int totalStudents;
  final int assignedCourses;
  final double averageProgress;
  final int pendingAssignments;
  final int grandTestsPassed;
  final int grandTestsFailed;
  final int atRiskStudents;
  final int needsAttentionStudents;
  final List<String> commonWeakAreas;

  factory TeacherBatchProgressSummary.fromRecords(
    List<TeacherStudentProgressModel> records,
  ) {
    final students = records.map((item) => item.studentId).toSet();
    final courses = records.map((item) => item.courseId).toSet();
    final average = records.isEmpty
        ? 0.0
        : records.map((item) => item.lessonProgress).reduce((a, b) => a + b) /
              records.length;
    final pendingAssignments = records.fold<int>(
      0,
      (total, item) =>
          total + (item.totalAssignments - item.completedAssignments),
    );
    final weakAreas = <String, int>{};
    for (final record in records) {
      for (final reason in record.riskReasons) {
        weakAreas[reason] = (weakAreas[reason] ?? 0) + 1;
      }
    }
    final commonWeakAreas = weakAreas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TeacherBatchProgressSummary(
      records: records,
      totalStudents: students.length,
      assignedCourses: courses.length,
      averageProgress: average.clamp(0, 100).toDouble(),
      pendingAssignments: pendingAssignments,
      grandTestsPassed: records
          .where((item) => item.grandTestStatus == 'passed')
          .length,
      grandTestsFailed: records
          .where((item) => item.grandTestStatus == 'failed')
          .length,
      atRiskStudents: records.where((item) => item.isAtRisk).length,
      needsAttentionStudents: records
          .where((item) => item.needsAttention)
          .length,
      commonWeakAreas: commonWeakAreas.map((item) => item.key).take(5).toList(),
    );
  }
}
