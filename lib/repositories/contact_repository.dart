import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_message_model.dart';

class ContactRepository {
  final FirebaseFirestore _firestore;

  ContactRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> sendMessage(ContactMessage message) async {
    try {
      await _firestore
          .collection('contactMessages')
          .doc(message.messageId)
          .set(message.toMap());
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  Stream<List<ContactMessage>> streamMessages({
    String? statusFilter,
    String? categoryFilter,
  }) {
    Query query = _firestore
        .collection('contactMessages')
        .orderBy('createdAt', descending: true);

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }

    if (categoryFilter != null &&
        categoryFilter.isNotEmpty &&
        categoryFilter != 'All') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ContactMessage.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  Stream<List<ContactMessage>> streamUserMessages(String userId) {
    return _firestore
        .collection('contactMessages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data())
              ..remove('adminNote');
            return ContactMessage.fromMap(data, doc.id);
          }).toList();

          // Sort in memory to avoid requiring a composite index in Firestore
          messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return messages;
        });
  }

  Future<void> updateMessageStatus({
    required String messageId,
    required String status,
    String? adminNote,
    String? adminResponse,
    String? respondedBy,
    String? resolvedBy,
    String? priority,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (adminNote != null) updates['adminNote'] = adminNote;
      if (adminResponse != null) updates['adminResponse'] = adminResponse;
      if (respondedBy != null) updates['respondedBy'] = respondedBy;
      if (resolvedBy != null) updates['resolvedBy'] = resolvedBy;
      if (priority != null) updates['priority'] = priority;

      if (status == 'responded' && adminResponse != null) {
        updates['respondedAt'] = FieldValue.serverTimestamp();
      }
      if (status == 'resolved' || status == 'closed') {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('contactMessages')
          .doc(messageId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update message: ${e.toString()}');
    }
  }
}
