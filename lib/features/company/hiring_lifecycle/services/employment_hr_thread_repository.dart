import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../models/hiring_lifecycle_models.dart';

/// Thin Firestore access for `employmentHrThreads/{id}/messages`.
class EmploymentHrThreadRepository {
  EmploymentHrThreadRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection('employmentHrThreads');

  Map<String, dynamic> _threadPayload({
    required String threadId,
    required String applicationId,
    required String companyId,
    required String applicantId,
  }) {
    return {
      'threadId': threadId,
      'applicationId': applicationId,
      'companyId': companyId,
      'applicantId': applicantId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> ensureThread({
    required String threadId,
    required String applicationId,
    required String companyId,
    required String applicantId,
  }) async {
    final ref = _threads.doc(threadId);
    await ref.set({
      ..._threadPayload(
        threadId: threadId,
        applicationId: applicationId,
        companyId: companyId,
        applicantId: applicantId,
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': '',
      'messageCount': 0,
    }, SetOptions(merge: true));
  }

  Stream<List<EmploymentHrMessage>> streamMessages(String threadId) {
    final trimmed = threadId.trim();
    if (trimmed.isEmpty) {
      return Stream.value(const <EmploymentHrMessage>[]);
    }
    // Client-side sort avoids orderBy index stalls; empty threads resolve immediately.
    return _threads.doc(trimmed).collection('messages').snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map(EmploymentHrMessage.fromFirestore)
          .toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    });
  }

  Future<EmploymentHrMessage> sendMessage({
    required String threadId,
    required String applicationId,
    required String companyId,
    required String applicantId,
    required String senderId,
    required String senderRole,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message body is empty.');
    }
    final threadRef = _threads.doc(threadId);
    final messageRef = threadRef.collection('messages').doc();
    final message = EmploymentHrMessage(
      id: messageRef.id,
      threadId: threadId,
      applicationId: applicationId,
      senderId: senderId,
      senderRole: senderRole,
      body: trimmed,
      createdAt: DateTime.now(),
    );

    // Ensure parent thread exists in the same batch so message create rules pass.
    final batch = _firestore.batch();
    batch.set(threadRef, {
      ..._threadPayload(
        threadId: threadId,
        applicationId: applicationId,
        companyId: companyId,
        applicantId: applicantId,
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': trimmed.length > 120
          ? '${trimmed.substring(0, 117)}...'
          : trimmed,
      'messageCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    batch.set(messageRef, message.toMap());
    await batch.commit();
    return message;
  }
}
