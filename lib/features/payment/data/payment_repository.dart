import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _plansRef =>
      _firestore.collection('plans');

  CollectionReference<Map<String, dynamic>> get _subscriptionsRef =>
      _firestore.collection('subscriptions');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _paymentsRef =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _creditPacksRef =>
      _firestore.collection('credit_packs');

  CollectionReference<Map<String, dynamic>> get _teacherEntitlementsRef =>
      _firestore.collection('teacher_entitlements');

  Future<void> seedDefaultConfiguration() async {
    final plansSnap = await _plansRef.limit(1).get();
    final packsSnap = await _creditPacksRef.limit(1).get();
    final now = DateTime.now();

    if (plansSnap.docs.isEmpty) {
      final freePlan = PaymentPlanModel(
        planId: 'free_plan',
        name: 'Free Plan',
        description: 'Starter teaching workspace with limited publishing capacity.',
        price: 0,
        currency: 'USD',
        interval: 'monthly',
        features: const ['basic_courses'],
        isActive: true,
        maxPublishedCourses: 3,
        maxLessonsPerCourse: 5,
        maxAssignmentsPerCourse: 2,
        maxProjectsPerCourse: 0,
        maxGrandTestsPerCourse: 1,
        maxAiCreditsPerMonth: 100,
        allowPaidCourses: false,
        allowAnalytics: false,
        createdAt: now,
        updatedAt: now,
      );
      final proPlan = PaymentPlanModel(
        planId: 'pro_plan',
        name: 'SkillForge Pro',
        description:
            'Premium teaching plan with paid courses, analytics, and monthly AI credits.',
        price: 49,
        currency: 'USD',
        interval: 'monthly',
        features: const [
          'priority_support',
          'analytics',
          'ai_assistant',
          'paid_courses',
        ],
        isActive: true,
        maxPublishedCourses: 50,
        maxLessonsPerCourse: 200,
        maxAssignmentsPerCourse: 200,
        maxProjectsPerCourse: 50,
        maxGrandTestsPerCourse: 20,
        maxAiCreditsPerMonth: 5000,
        allowPaidCourses: true,
        allowAnalytics: true,
        createdAt: now,
        updatedAt: now,
      );
      await upsertPlan(freePlan);
      await upsertPlan(proPlan);
    }

    if (packsSnap.docs.isEmpty) {
      await upsertCreditPack(
        CreditPackModel(
          packId: 'pack_starter',
          name: 'Starter Credits',
          description: '100 AI credits for quick experiments.',
          credits: 100,
          bonusCredits: 0,
          price: 4.99,
          currency: 'USD',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await upsertCreditPack(
        CreditPackModel(
          packId: 'pack_growth',
          name: 'Growth Credits',
          description: '500 AI credits plus a bonus for power users.',
          credits: 500,
          bonusCredits: 50,
          price: 19.99,
          currency: 'USD',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await upsertCreditPack(
        CreditPackModel(
          packId: 'pack_pro',
          name: 'Pro Credits',
          description: '2000 AI credits for heavy AI course building.',
          credits: 2000,
          bonusCredits: 300,
          price: 49.99,
          currency: 'USD',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<List<PaymentPlanModel>> getPlans({bool includeInactive = false}) async {
    if (includeInactive) {
      final snapshot = await _plansRef.get();
      return snapshot.docs
          .map((doc) => PaymentPlanModel.fromFirestore(doc))
          .toList();
    }
    final snapshot = await _plansRef.where('isActive', isEqualTo: true).get();
    return snapshot.docs
        .map((doc) => PaymentPlanModel.fromFirestore(doc))
        .toList();
  }

  Future<List<CreditPackModel>> getCreditPacks({
    bool includeInactive = false,
  }) async {
    if (includeInactive) {
      final snapshot = await _creditPacksRef.get();
      return snapshot.docs
          .map((doc) => CreditPackModel.fromFirestore(doc))
          .toList();
    }
    final snapshot = await _creditPacksRef
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => CreditPackModel.fromFirestore(doc))
        .toList();
  }

  Future<PaymentPlanModel?> getPlan(String planId) async {
    final snapshot = await _plansRef.doc(planId).get();
    if (!snapshot.exists) {
      return null;
    }
    return PaymentPlanModel.fromFirestore(snapshot);
  }

  Future<void> upsertPlan(PaymentPlanModel plan) async {
    await _plansRef
        .doc(plan.planId)
        .set(plan.toJson(), SetOptions(merge: true));
  }

  Future<void> upsertSubscription(PaymentSubscriptionModel subscription) async {
    await _subscriptionsRef
        .doc(subscription.subscriptionId)
        .set(subscription.toJson(), SetOptions(merge: true));
  }

  Future<PaymentSubscriptionModel?> getSubscriptionForUser(
    String userId,
  ) async {
    final snapshot = await _subscriptionsRef
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final subscriptions = snapshot.docs
        .map((doc) => PaymentSubscriptionModel.fromFirestore(doc))
        .toList();
    subscriptions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final active = subscriptions.where(
      (s) =>
          !PaymentStatus.isCancelled(s.status) &&
          PaymentStatus.isSuccess(s.status),
    );
    if (active.isNotEmpty) return active.first;
    return subscriptions.first;
  }

  Future<void> upsertTransaction(PaymentTransactionModel transaction) async {
    await _transactionsRef
        .doc(transaction.transactionId)
        .set(transaction.toJson(), SetOptions(merge: true));
  }

  Future<void> upsertPayment(PaymentRecordModel payment) async {
    await _paymentsRef
        .doc(payment.paymentId)
        .set(payment.toJson(), SetOptions(merge: true));
  }

  Future<void> upsertCreditPack(CreditPackModel pack) async {
    await _creditPacksRef
        .doc(pack.packId)
        .set(pack.toJson(), SetOptions(merge: true));
  }

  Future<List<TeacherEntitlementModel>> getTeacherEntitlements(
    String teacherId,
  ) async {
    final snapshot = await _teacherEntitlementsRef
        .where('teacherId', isEqualTo: teacherId)
        .get();
    return snapshot.docs
        .map((doc) => TeacherEntitlementModel.fromFirestore(doc))
        .toList();
  }

  Future<TeacherEntitlementModel?> getLatestTeacherEntitlement(
    String teacherId,
  ) async {
    final entitlements = await getTeacherEntitlements(teacherId);
    // Ignore credit-pack entitlements — they are not subscription plans.
    final planEntitlements = entitlements
        .where((e) => e.planId != 'credit_pack' && e.planId.isNotEmpty)
        .toList();
    if (planEntitlements.isEmpty) {
      return null;
    }
    planEntitlements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return planEntitlements.first;
  }

  Future<void> upsertTeacherEntitlement(
    TeacherEntitlementModel entitlement,
  ) async {
    await _teacherEntitlementsRef
        .doc(entitlement.entitlementId)
        .set(entitlement.toJson(), SetOptions(merge: true));
  }

  Future<void> revokeTeacherEntitlement(String entitlementId) async {
    await _teacherEntitlementsRef.doc(entitlementId).delete();
  }

  // Admin / reporting queries
  Future<List<PaymentTransactionModel>> getTransactions({
    String? status,
    DateTime? since,
  }) async {
    Query<Map<String, dynamic>> q = _transactionsRef;
    if (status != null) q = q.where('status', isEqualTo: status);
    if (since != null) q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    final snapshot = await q.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((d) => PaymentTransactionModel.fromFirestore(d)).toList();
  }

  Future<List<PaymentRecordModel>> getPayments({
    String? status,
    String? type,
    String? teacherId,
    String? userId,
  }) async {
    Query<Map<String, dynamic>> q = _paymentsRef;
    if (status != null) q = q.where('status', isEqualTo: status);
    if (type != null) q = q.where('type', isEqualTo: type);
    if (teacherId != null) q = q.where('teacherId', isEqualTo: teacherId);
    if (userId != null) q = q.where('userId', isEqualTo: userId);
    // Avoid composite-index requirement: filter then sort client-side.
    final snapshot = await q.get();
    final payments = snapshot.docs
        .map((d) => PaymentRecordModel.fromFirestore(d))
        .toList();
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payments;
  }

  /// Syncs plan/pack AI credits into `aiUserCredits` (what the AI builder UI reads).
  Future<void> syncAiUserCredits({
    required String userId,
    required String role,
    int? monthlyFreeCredits,
    int bonusCreditsDelta = 0,
  }) async {
    final ref = _firestore.collection('aiUserCredits').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      final data = doc.data() ?? <String, dynamic>{};
      final currentMonth =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      final storedMonth = data['currentMonthKey']?.toString() ?? currentMonth;
      final used = storedMonth == currentMonth
          ? (data['usedCreditsThisMonth'] as num?)?.toInt() ?? 0
          : 0;
      final currentMonthly =
          (data['monthlyFreeCredits'] as num?)?.toInt() ?? 200;
      final currentBonus = (data['bonusCredits'] as num?)?.toInt() ?? 0;
      final monthly = monthlyFreeCredits ?? currentMonthly;
      final bonus = (currentBonus + bonusCreditsDelta).clamp(0, 1000000);
      final remaining = (monthly + bonus - used).clamp(0, 1000000);
      transaction.set(ref, {
        'userId': userId,
        'role': role,
        'monthlyFreeCredits': monthly,
        'bonusCredits': bonus,
        'usedCreditsThisMonth': used,
        'remainingCredits': remaining,
        'currentMonthKey': currentMonth,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<List<PaymentSubscriptionModel>> getActiveSubscriptions() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _subscriptionsRef
        .where('status', isEqualTo: PaymentStatus.success)
        .where('currentPeriodEnd', isGreaterThan: now)
        .orderBy('currentPeriodEnd', descending: true)
        .get();
    return snapshot.docs.map((d) => PaymentSubscriptionModel.fromFirestore(d)).toList();
  }

  Future<List<PaymentSubscriptionModel>> getExpiredSubscriptions() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _subscriptionsRef
        .where('currentPeriodEnd', isLessThan: now)
        .orderBy('currentPeriodEnd', descending: true)
        .get();
    return snapshot.docs.map((d) => PaymentSubscriptionModel.fromFirestore(d)).toList();
  }
}
