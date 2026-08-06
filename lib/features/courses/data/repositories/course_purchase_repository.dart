import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/marketplace_models.dart';

class CoursePurchaseRepository {
  CoursePurchaseRepository(this._firestore);

  final FirebaseFirestore _firestore;

  late final CollectionReference<Map<String, dynamic>> _paidCoursesRef =
      _firestore.collection('paid_courses');
  late final CollectionReference<Map<String, dynamic>> _purchasesRef =
      _firestore.collection('course_purchases');
  late final DocumentReference<Map<String, dynamic>> _marketplaceConfigRef =
      _firestore.collection('settings').doc('marketplace');

  // ==================== PAID COURSE CONFIG ====================
  Future<PaidCourseConfig> getPaidCourseConfig(String courseId) async {
    final doc = await _paidCoursesRef.doc(courseId).get();
    if (!doc.exists) {
      return PaidCourseConfig.free(courseId);
    }
    return PaidCourseConfig.fromFirestore(doc);
  }

  Future<List<PaidCourseConfig>> getPaidCourses() async {
    final query = await _paidCoursesRef
        .where('isPaid', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs
        .map((doc) => PaidCourseConfig.fromFirestore(doc))
        .toList();
  }

  Future<List<PaidCourseConfig>> getTeacherPaidCourses(String teacherId) async {
    // Get all paid courses for a teacher through their course enrollment docs
    // This requires a relationship through the courses collection
    // Implementation: get teacher's courses that have paid config
    final purchasesQuery = await _purchasesRef
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('purchasedAt', descending: true)
        .get();

    final courseIds = purchasesQuery.docs
        .map((doc) => doc.data()['courseId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (courseIds.isEmpty) return [];

    final configs = <PaidCourseConfig>[];
    for (final courseId in courseIds) {
      final config = await getPaidCourseConfig(courseId);
      if (config.isPaid) configs.add(config);
    }
    return configs;
  }

  Future<void> createOrUpdatePaidCourseConfig(PaidCourseConfig config) async {
    await _paidCoursesRef.doc(config.courseId).set(
      config.toJson(),
      SetOptions(merge: true),
    );
  }

  Future<void> deletePaidCourseConfig(String courseId) async {
    await _paidCoursesRef.doc(courseId).delete();
  }

  // ==================== COURSE PURCHASES ====================
  Future<CoursePurchase?> getPurchase(String purchaseId) async {
    final doc = await _purchasesRef.doc(purchaseId).get();
    if (!doc.exists) return null;
    return CoursePurchase.fromFirestore(doc);
  }

  Future<bool> hasPurchased(String studentId, String courseId) async {
    final query = await _purchasesRef
        .where('studentId', isEqualTo: studentId)
        .where('courseId', isEqualTo: courseId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<List<CoursePurchase>> getStudentPurchaseHistory(String studentId) async {
    final query = await _purchasesRef
        .where('studentId', isEqualTo: studentId)
        .orderBy('purchasedAt', descending: true)
        .get();

    return query.docs
        .map((doc) => CoursePurchase.fromFirestore(doc))
        .toList();
  }

  Future<List<CoursePurchase>> getTeacherSalesHistory(String teacherId) async {
    final query = await _purchasesRef
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('purchasedAt', descending: true)
        .get();

    return query.docs
        .map((doc) => CoursePurchase.fromFirestore(doc))
        .toList();
  }

  Future<List<CoursePurchase>> getCoursePurchases(String courseId) async {
    final query = await _purchasesRef
        .where('courseId', isEqualTo: courseId)
        .orderBy('purchasedAt', descending: true)
        .get();

    return query.docs
        .map((doc) => CoursePurchase.fromFirestore(doc))
        .toList();
  }

  Future<void> recordPurchase(CoursePurchase purchase) async {
    await _purchasesRef.doc(purchase.purchaseId).set(
      purchase.toJson(),
      SetOptions(merge: false),
    );
  }

  /// Return all purchases, optionally filtered by since date.
  Future<List<CoursePurchase>> getAllPurchases({DateTime? since}) async {
    Query<Map<String, dynamic>> q = _purchasesRef;
    if (since != null) q = q.where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    final snapshot = await q.orderBy('purchasedAt', descending: true).get();
    return snapshot.docs.map((d) => CoursePurchase.fromFirestore(d)).toList();
  }

  // ==================== MARKETPLACE CONFIG ====================
  Future<MarketplaceConfig> getMarketplaceConfig() async {
    final doc = await _marketplaceConfigRef.get();
    if (!doc.exists) {
      // Do not auto-write from clients (settings write = admin only).
      return MarketplaceConfig.defaults();
    }
    return MarketplaceConfig.fromFirestore(doc);
  }

  Future<void> updateMarketplaceConfig(MarketplaceConfig config) async {
    await _marketplaceConfigRef.set(
      config.toJson(),
      SetOptions(merge: true),
    );
  }

  // ==================== STATISTICS ====================
  Future<double> getTeacherRevenue(String teacherId) async {
    final query = await _purchasesRef
        .where('teacherId', isEqualTo: teacherId)
        .get();

    double totalRevenue = 0;
    for (final doc in query.docs) {
      totalRevenue += (doc.data()['finalAmount'] as num?)?.toDouble() ?? 0;
    }
    return totalRevenue;
  }

  Future<int> getCoursePurchaseCount(String courseId) async {
    final query = await _purchasesRef
        .where('courseId', isEqualTo: courseId)
        .count()
        .get();
    return query.count ?? 0;
  }

  Future<double> getCourseTotalRevenue(String courseId) async {
    final query = await _purchasesRef
        .where('courseId', isEqualTo: courseId)
        .get();

    double totalRevenue = 0;
    for (final doc in query.docs) {
      totalRevenue += (doc.data()['finalAmount'] as num?)?.toDouble() ?? 0;
    }
    return totalRevenue;
  }
}
