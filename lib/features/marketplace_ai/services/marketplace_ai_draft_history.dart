import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// User-scoped recent marketplace AI drafts (not source of truth for published).
class MarketplaceAiDraftHistoryStore {
  MarketplaceAiDraftHistoryStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _maxItems = 20;

  CollectionReference<Map<String, dynamic>>? _collectionFor(String uid) {
    if (uid.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('marketplaceAiDrafts');
  }

  Future<void> saveDraft({
    required String taskType,
    required String title,
    required Map<String, dynamic> applyPayload,
    String? summary,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final col = _collectionFor(uid);
    if (col == null) return;
    try {
      await col.add({
        'taskType': taskType,
        'title': title,
        'summary': summary ?? '',
        'applyPayload': applyPayload,
        'createdAt': FieldValue.serverTimestamp(),
        'requiresManualReview': true,
      });
      await _trim(col);
    } catch (_) {
      // Draft history is best-effort; never block Apply.
    }
  }

  Future<List<MarketplaceAiHistoryItem>> listRecent({int limit = 10}) async {
    final uid = _auth.currentUser?.uid ?? '';
    final col = _collectionFor(uid);
    if (col == null) return const [];
    try {
      final snap = await col
          .orderBy('createdAt', descending: true)
          .limit(limit.clamp(1, _maxItems))
          .get();
      return snap.docs.map(MarketplaceAiHistoryItem.fromDoc).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _trim(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final snap = await col
        .orderBy('createdAt', descending: true)
        .limit(_maxItems + 10)
        .get();
    if (snap.docs.length <= _maxItems) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs.skip(_maxItems)) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class MarketplaceAiHistoryItem {
  const MarketplaceAiHistoryItem({
    required this.id,
    required this.taskType,
    required this.title,
    required this.summary,
    required this.applyPayload,
    required this.createdAt,
  });

  final String id;
  final String taskType;
  final String title;
  final String summary;
  final Map<String, dynamic> applyPayload;
  final DateTime createdAt;

  factory MarketplaceAiHistoryItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return MarketplaceAiHistoryItem(
      id: doc.id,
      taskType: (data['taskType'] ?? '').toString(),
      title: (data['title'] ?? 'AI Draft').toString(),
      summary: (data['summary'] ?? '').toString(),
      applyPayload: data['applyPayload'] is Map
          ? Map<String, dynamic>.from(data['applyPayload'] as Map)
          : <String, dynamic>{},
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
