import 'package:cloud_firestore/cloud_firestore.dart';

import 'email_template_model.dart';

class EmailEventLogger {
  const EmailEventLogger(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('emailEvents');

  Future<bool> hasSent(String dedupeKey, {required String triggeredBy}) async {
    if (dedupeKey.trim().isEmpty) return false;
    final snapshot = await _events
        .where('dedupeKey', isEqualTo: dedupeKey.trim())
        .where('triggeredBy', isEqualTo: triggeredBy)
        .where('status', isEqualTo: 'sent')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> log({
    required SkillForgeEmailTemplate template,
    required String status,
    required String triggeredBy,
    String errorMessage = '',
  }) async {
    final now = FieldValue.serverTimestamp();
    await _events.doc().set({
      'toEmail': template.toEmail,
      'toName': template.toName,
      'type': template.type.key,
      'relatedDocPath': template.relatedDocPath,
      'status': status,
      'errorMessage': errorMessage,
      'createdAt': now,
      if (status == 'sent') 'sentAt': now,
      'triggeredBy': triggeredBy,
      'dedupeKey': template.dedupeKey,
    });
  }
}
