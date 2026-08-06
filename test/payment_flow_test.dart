import 'package:flutter_test/flutter_test.dart';

import 'package:skillforge_ai/features/payment/models/payment_models.dart';
import 'package:skillforge_ai/features/payment/services/teacher_subscription_service.dart';
import 'package:skillforge_ai/features/payment/data/payment_repository.dart';
import 'package:skillforge_ai/features/payment/services/payment_service.dart';
import 'package:skillforge_ai/repositories/user_repository.dart';

class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository()
      : _plans = {},
        _subscriptions = {},
        _teacherEntitlements = {},
        _creditPacks = {};

  final Map<String, PaymentPlanModel> _plans;
  final Map<String, PaymentSubscriptionModel> _subscriptions;
  final Map<String, TeacherEntitlementModel> _teacherEntitlements;
  final Map<String, CreditPackModel> _creditPacks;

  @override
  Future<void> seedDefaultConfiguration() async {}

  @override
  Future<void> upsertPlan(PaymentPlanModel plan) async {
    _plans[plan.planId] = plan;
  }

  @override
  Future<PaymentPlanModel?> getPlan(String planId) async => _plans[planId];

  @override
  Future<void> upsertSubscription(PaymentSubscriptionModel subscription) async {
    _subscriptions[subscription.subscriptionId] = subscription;
  }

  @override
  Future<PaymentSubscriptionModel?> getSubscriptionForUser(String userId) async {
    final matches =
        _subscriptions.values.where((s) => s.userId == userId).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final active = matches.where(
      (s) =>
          !PaymentStatus.isCancelled(s.status) &&
          PaymentStatus.isSuccess(s.status),
    );
    if (active.isNotEmpty) return active.first;
    return matches.first;
  }

  @override
  Future<void> upsertTransaction(PaymentTransactionModel transaction) async {}

  @override
  Future<void> upsertPayment(PaymentRecordModel payment) async {}

  @override
  Future<void> upsertCreditPack(CreditPackModel pack) async {
    _creditPacks[pack.packId] = pack;
  }

  @override
  Future<List<TeacherEntitlementModel>> getTeacherEntitlements(
    String teacherId,
  ) async {
    return _teacherEntitlements.values
        .where((e) => e.teacherId == teacherId)
        .toList();
  }

  @override
  Future<TeacherEntitlementModel?> getLatestTeacherEntitlement(
    String teacherId,
  ) async {
    final ents = (await getTeacherEntitlements(teacherId))
        .where((e) => e.planId != 'credit_pack')
        .toList();
    if (ents.isEmpty) return null;
    ents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ents.first;
  }

  @override
  Future<void> upsertTeacherEntitlement(
    TeacherEntitlementModel entitlement,
  ) async {
    _teacherEntitlements[entitlement.entitlementId] = entitlement;
  }

  @override
  Future<void> revokeTeacherEntitlement(String entitlementId) async {
    _teacherEntitlements.remove(entitlementId);
  }

  @override
  Future<List<PaymentPlanModel>> getPlans({bool includeInactive = false}) async {
    if (includeInactive) return _plans.values.toList();
    return _plans.values.where((p) => p.isActive).toList();
  }

  @override
  Future<List<CreditPackModel>> getCreditPacks({
    bool includeInactive = false,
  }) async {
    if (includeInactive) return _creditPacks.values.toList();
    return _creditPacks.values.where((p) => p.isActive).toList();
  }

  @override
  Future<List<PaymentTransactionModel>> getTransactions({
    String? status,
    DateTime? since,
  }) async =>
      [];

  @override
  Future<List<PaymentRecordModel>> getPayments({
    String? status,
    String? type,
    String? teacherId,
    String? userId,
  }) async =>
      [];

  @override
  Future<void> syncAiUserCredits({
    required String userId,
    required String role,
    int? monthlyFreeCredits,
    int bonusCreditsDelta = 0,
  }) async {}

  @override
  Future<List<PaymentSubscriptionModel>> getActiveSubscriptions() async => [];

  @override
  Future<List<PaymentSubscriptionModel>> getExpiredSubscriptions() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserRepository implements UserRepository {
  final Map<String, Map<String, dynamic>> updates = {};

  @override
  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    updates[uid] = data;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TeacherSubscriptionService cancellation', () {
    test('cancelSubscription schedules cancel at period end and keeps access',
        () async {
      final repo = FakePaymentRepository();
      final userRepo = FakeUserRepository();
      final paymentService = PaymentService(repo);
      final subService = TeacherSubscriptionService(repo, paymentService);

      final now = DateTime.now();
      final periodEnd = now.add(const Duration(days: 20));
      final subscription = PaymentSubscriptionModel(
        subscriptionId: 'sub_1',
        userId: 'teacher_1',
        planId: 'pro_plan',
        status: PaymentStatus.success,
        currentPeriodStart: now.subtract(const Duration(days: 10)),
        currentPeriodEnd: periodEnd,
        autoRenew: true,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      );
      await repo.upsertSubscription(subscription);

      final entitlement = TeacherEntitlementModel(
        entitlementId: 'ent_1',
        teacherId: 'teacher_1',
        planId: 'pro_plan',
        packageName: 'Pro',
        credits: 5000,
        features: {'ai_assistant': true},
        status: PaymentStatus.success,
        createdAt: now.subtract(const Duration(days: 9)),
        updatedAt: now.subtract(const Duration(days: 9)),
      );
      await repo.upsertTeacherEntitlement(entitlement);

      final res = await subService.cancelSubscription('teacher_1');
      expect(res.success, isTrue);
      expect(res.cancelAtPeriodEnd, isTrue);
      expect(res.accessUntil, periodEnd);

      final subAfter = await repo.getSubscriptionForUser('teacher_1');
      expect(subAfter, isNotNull);
      expect(subAfter!.status, PaymentStatus.success);
      expect(subAfter.autoRenew, isFalse);
      expect(subAfter.cancelAtPeriodEnd, isTrue);

      final ents = await repo.getTeacherEntitlements('teacher_1');
      expect(ents.length, 1);
    });

    test(
        'finalizeExpiredCancellationIfNeeded revokes access after period end',
        () async {
      final repo = FakePaymentRepository();
      final userRepo = FakeUserRepository();
      final paymentService = PaymentService(repo);
      final subService = TeacherSubscriptionService(repo, paymentService);

      final now = DateTime.now();
      final subscription = PaymentSubscriptionModel(
        subscriptionId: 'sub_2',
        userId: 'teacher_2',
        planId: 'pro_plan',
        status: PaymentStatus.success,
        currentPeriodStart: now.subtract(const Duration(days: 40)),
        currentPeriodEnd: now.subtract(const Duration(days: 1)),
        autoRenew: false,
        cancelAtPeriodEnd: true,
        cancelledAt: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );
      await repo.upsertSubscription(subscription);
      await repo.upsertTeacherEntitlement(
        TeacherEntitlementModel(
          entitlementId: 'ent_2',
          teacherId: 'teacher_2',
          planId: 'pro_plan',
          packageName: 'Pro',
          credits: 5000,
          features: const {},
          status: PaymentStatus.success,
          createdAt: now.subtract(const Duration(days: 40)),
          updatedAt: now.subtract(const Duration(days: 40)),
        ),
      );

      await subService.finalizeExpiredCancellationIfNeeded('teacher_2');

      final subAfter = await repo.getSubscriptionForUser('teacher_2');
      expect(subAfter!.status, PaymentStatus.cancelled);
      final ents = await repo.getTeacherEntitlements('teacher_2');
      expect(ents.isEmpty, isTrue);
    });
  });

  group('PaymentGateway', () {
    test('uses payfast not dummy sandbox id', () {
      expect(PaymentGateway.payfast, 'payfast');
    });
  });
}
