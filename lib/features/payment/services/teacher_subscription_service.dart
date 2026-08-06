import '../data/payment_repository.dart';
import '../models/payment_models.dart';
import '../services/demo_payment_finalize_service.dart';
import '../services/payment_service.dart';

class TeacherSubscriptionService {
  TeacherSubscriptionService(
    this._repo,
    this._paymentService, {
    DemoPaymentFinalizeService? demoGateway,
  }) : _demoGateway = demoGateway ?? DemoPaymentFinalizeService();

  final PaymentRepository _repo;
  final PaymentService _paymentService;
  final DemoPaymentFinalizeService _demoGateway;

  Future<TeacherSubscriptionAccess> getAccessForTeacher(String teacherId) async {
    await finalizeExpiredCancellationIfNeeded(teacherId);
    final entitlement = await _repo.getLatestTeacherEntitlement(teacherId);
    final planId = entitlement?.planId ?? 'free_plan';
    final plan = await _repo.getPlan(planId);
    if (plan == null) {
      return TeacherSubscriptionAccess.free();
    }
    return TeacherSubscriptionAccess.fromPlan(plan, entitlement);
  }

  /// When a cancel-at-period-end subscription reaches month end, revoke access
  /// and mark the subscription cancelled (no further card charges).
  Future<void> finalizeExpiredCancellationIfNeeded(String teacherId) async {
    final subscription = await _repo.getSubscriptionForUser(teacherId);
    if (subscription == null) return;
    if (!subscription.cancelAtPeriodEnd) return;
    if (PaymentStatus.isCancelled(subscription.status)) return;
    if (subscription.currentPeriodEnd.isAfter(DateTime.now())) return;

    try {
      await _demoGateway.finalizeSubscriptionExpiry();
    } catch (_) {
      // Access read must stay resilient if gateway is temporarily down.
    }
  }

  Future<TeacherSubscriptionCheckResult> validateCoursePublish({
    required String teacherId,
    required int publishedCourseCount,
  }) async {
    final access = await getAccessForTeacher(teacherId);
    return _validateLimit(
      access: access,
      currentCount: publishedCourseCount,
      limit: access.maxPublishedCourses,
      featureLabel: 'published courses',
      upgradeHint: 'Upgrade to publish more courses and unlock expanded teaching tools.',
    );
  }

  Future<TeacherSubscriptionCheckResult> validateLessonCreate({
    required String teacherId,
    required int currentLessonCount,
  }) async {
    final access = await getAccessForTeacher(teacherId);
    return _validateLimit(
      access: access,
      currentCount: currentLessonCount,
      limit: access.maxLessonsPerCourse,
      featureLabel: 'lessons per course',
      upgradeHint: 'Upgrade to add more structured lessons to each course.',
    );
  }

  Future<TeacherSubscriptionCheckResult> validateAssignmentPublish({
    required String teacherId,
    required int currentAssignmentCount,
  }) async {
    final access = await getAccessForTeacher(teacherId);
    return _validateLimit(
      access: access,
      currentCount: currentAssignmentCount,
      limit: access.maxAssignmentsPerCourse,
      featureLabel: 'assignments per course',
      upgradeHint: 'Upgrade to publish more assessments and project-based learning.',
    );
  }

  Future<TeacherSubscriptionCheckResult> validateProjectPublish({
    required String teacherId,
    required int currentProjectCount,
  }) async {
    final access = await getAccessForTeacher(teacherId);
    return _validateLimit(
      access: access,
      currentCount: currentProjectCount,
      limit: access.maxProjectsPerCourse,
      featureLabel: 'project assignments per course',
      upgradeHint: 'Upgrade to unlock richer project-based curriculum options.',
    );
  }

  Future<TeacherSubscriptionCheckResult> validateGrandTestPublish({
    required String teacherId,
    required int currentGrandTestCount,
  }) async {
    final access = await getAccessForTeacher(teacherId);
    return _validateLimit(
      access: access,
      currentCount: currentGrandTestCount,
      limit: access.maxGrandTestsPerCourse,
      featureLabel: 'grand tests per course',
      upgradeHint: 'Upgrade to publish more comprehensive course exams.',
    );
  }

  Future<PaymentProcessResult> upgradeToPremium(String teacherId) async {
    // Try to find an active premium plan. Prefer planId 'pro_plan', else pick highest priced plan.
    final plans = await _repo.getPlans();
    PaymentPlanModel? selected;
    if (plans.isNotEmpty) {
      selected = plans.firstWhere(
        (p) => p.planId == 'pro_plan',
        orElse: () {
          final sorted = List<PaymentPlanModel>.from(plans)
            ..sort((a, b) => b.price.compareTo(a.price));
          return sorted.first;
        },
      );
    } else {
      final now = DateTime.now();
      final defaultPlan = PaymentPlanModel(
        planId: 'pro_plan',
        name: 'SkillForge Pro',
        description: 'Teacher premium subscription',
        price: 49.0,
        currency: 'PKR',
        interval: 'monthly',
        features: const ['priority_support', 'analytics', 'ai_assistant'],
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
      await _repo.upsertPlan(defaultPlan);
      selected = defaultPlan;
    }

    return purchaseSelectedPlan(teacherId: teacherId, plan: selected);
  }

  /// Classifies target plan relative to the teacher's current access.
  Future<PlanChangeEvaluation> evaluatePlanChange({
    required String teacherId,
    required PaymentPlanModel target,
  }) async {
    final access = await getAccessForTeacher(teacherId);
    final subscription = await _repo.getSubscriptionForUser(teacherId);
    final currentPlan =
        await _repo.getPlan(access.planId) ??
        await _repo.getPlan('free_plan');
    final currentPrice = currentPlan?.price ?? 0;
    final cancelScheduled = subscription?.isCancelScheduled == true;
    final samePlan = access.planId == target.planId;

    if (samePlan && !cancelScheduled && access.isPremium) {
      return PlanChangeEvaluation(
        kind: PlanChangeKind.current,
        currentPlanId: access.planId,
        currentPlanName: access.planName,
        target: target,
        subscription: subscription,
        canCheckout: false,
        ctaLabel: 'Current plan',
        message: 'You are already on ${target.name}.',
      );
    }

    if (samePlan && cancelScheduled) {
      return PlanChangeEvaluation(
        kind: PlanChangeKind.reactivate,
        currentPlanId: access.planId,
        currentPlanName: access.planName,
        target: target,
        subscription: subscription,
        canCheckout: true,
        ctaLabel: 'Reactivate ${target.name}',
        message:
            'Cancellation is scheduled. Pay again to keep ${target.name} and resume auto-renew.',
      );
    }

    if (target.price > currentPrice) {
      return PlanChangeEvaluation(
        kind: PlanChangeKind.upgrade,
        currentPlanId: access.planId,
        currentPlanName: access.planName,
        target: target,
        subscription: subscription,
        canCheckout: true,
        ctaLabel: 'Upgrade to ${target.name}',
        message:
            'Upgrade from ${access.planName} to ${target.name} for higher limits and features.',
      );
    }

    if (target.price < currentPrice && target.price > 0) {
      return PlanChangeEvaluation(
        kind: PlanChangeKind.switchPlan,
        currentPlanId: access.planId,
        currentPlanName: access.planName,
        target: target,
        subscription: subscription,
        canCheckout: true,
        ctaLabel: 'Switch to ${target.name}',
        message:
            'Switch from ${access.planName} to ${target.name}. New limits apply after payment.',
      );
    }

    // Free → paid or first purchase
    return PlanChangeEvaluation(
      kind: PlanChangeKind.upgrade,
      currentPlanId: access.planId,
      currentPlanName: access.planName,
      target: target,
      subscription: subscription,
      canCheckout: target.price > 0,
      ctaLabel: target.price > 0
          ? 'Upgrade to ${target.name}'
          : 'Current free plan',
      message: target.price > 0
          ? 'Unlock ${target.name} with SkillForge Demo Gateway checkout.'
          : 'You are on the free teaching plan.',
    );
  }

  Future<PaymentProcessResult> purchaseSelectedPlan({
    required String teacherId,
    required PaymentPlanModel plan,
    String paymentMethod = 'card',
  }) async {
    final evaluation = await evaluatePlanChange(
      teacherId: teacherId,
      target: plan,
    );
    if (!evaluation.canCheckout) {
      return PaymentProcessResult(
        transactionId: '',
        paymentId: '',
        status: PaymentStatus.failed,
        message: evaluation.message,
        amount: plan.price,
        currency: plan.currency,
      );
    }

    return _paymentService.purchasePlan(
      userId: teacherId,
      planId: plan.planId,
      amount: plan.price,
      currency: plan.currency,
      paymentMethod: paymentMethod,
      teacherId: teacherId,
      metadata: {
        'upgrade': evaluation.kind == PlanChangeKind.upgrade ||
            evaluation.kind == PlanChangeKind.reactivate,
        'changeType': evaluation.kind.name,
        'feature': 'teacher_subscription',
        'previousPlanId': evaluation.currentPlanId,
        if (evaluation.subscription != null)
          'previousSubscriptionId': evaluation.subscription!.subscriptionId,
      },
    );
  }

  /// Schedules cancellation at period end. Benefits stay active until
  /// [PaymentSubscriptionModel.currentPeriodEnd]; auto-renew / card charge stops.
  Future<SubscriptionCancellationResult> cancelSubscription(String teacherId) async {
    try {
      final entitlement = await _repo.getLatestTeacherEntitlement(teacherId);

      if (entitlement == null) {
        return const SubscriptionCancellationResult(
          success: false,
          message: 'No active subscription found to cancel.',
        );
      }

      final subscription = await _repo.getSubscriptionForUser(teacherId);

      if (subscription == null) {
        return const SubscriptionCancellationResult(
          success: false,
          message: 'Subscription record not found.',
        );
      }

      if (PaymentStatus.isCancelled(subscription.status) &&
          subscription.currentPeriodEnd.isBefore(DateTime.now())) {
        return SubscriptionCancellationResult(
          success: false,
          message: 'This subscription is already cancelled.',
          subscriptionId: subscription.subscriptionId,
        );
      }

      if (subscription.isCancelScheduled) {
        return SubscriptionCancellationResult(
          success: true,
          message:
              'Cancellation already scheduled. You keep full plan benefits until '
              '${_formatDate(subscription.currentPeriodEnd)}. No further charges.',
          subscriptionId: subscription.subscriptionId,
          accessUntil: subscription.currentPeriodEnd,
          cancelAtPeriodEnd: true,
        );
      }

      final data = await _demoGateway.cancelSubscription();
      final accessUntilRaw = data['accessUntil']?.toString();
      final accessUntil = accessUntilRaw != null && accessUntilRaw.isNotEmpty
          ? DateTime.tryParse(accessUntilRaw) ?? subscription.currentPeriodEnd
          : subscription.currentPeriodEnd;

      return SubscriptionCancellationResult(
        success: true,
        message: data['message']?.toString() ??
            'Cancellation scheduled. You keep plan benefits until '
                '${_formatDate(accessUntil)}. No further charges.',
        subscriptionId:
            data['subscriptionId']?.toString() ?? subscription.subscriptionId,
        accessUntil: accessUntil,
        cancelAtPeriodEnd: true,
      );
    } on DemoPaymentException catch (e) {
      return SubscriptionCancellationResult(
        success: false,
        message: e.message,
      );
    } catch (e) {
      return SubscriptionCancellationResult(
        success: false,
        message: 'Failed to cancel subscription: $e',
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  TeacherSubscriptionCheckResult _validateLimit({
    required TeacherSubscriptionAccess access,
    required int currentCount,
    required int limit,
    required String featureLabel,
    required String upgradeHint,
  }) {
    if (currentCount < limit) {
      return TeacherSubscriptionCheckResult(
        allowed: true,
        title: 'Access available',
        message: 'Your current plan supports this action.',
        planName: access.planName,
      );
    }

    return TeacherSubscriptionCheckResult(
      allowed: false,
      title: 'Upgrade required',
      message:
          'Your $featureLabel limit for ${access.planName} has been reached. $upgradeHint',
      planName: access.planName,
      needsUpgrade: true,
    );
  }
}

class TeacherSubscriptionAccess {
  const TeacherSubscriptionAccess({
    required this.planId,
    required this.planName,
    required this.maxPublishedCourses,
    required this.maxLessonsPerCourse,
    required this.maxAssignmentsPerCourse,
    required this.maxProjectsPerCourse,
    required this.maxGrandTestsPerCourse,
    required this.maxAiCreditsPerMonth,
    required this.allowPaidCourses,
    required this.allowAnalytics,
    required this.isPremium,
  });

  factory TeacherSubscriptionAccess.free() {
    return const TeacherSubscriptionAccess(
      planId: 'free_plan',
      planName: 'Free Plan',
      maxPublishedCourses: 3,
      maxLessonsPerCourse: 5,
      maxAssignmentsPerCourse: 2,
      maxProjectsPerCourse: 0,
      maxGrandTestsPerCourse: 1,
      maxAiCreditsPerMonth: 100,
      allowPaidCourses: false,
      allowAnalytics: false,
      isPremium: false,
    );
  }

  factory TeacherSubscriptionAccess.fromPlan(
    PaymentPlanModel plan,
    TeacherEntitlementModel? entitlement,
  ) {
    return TeacherSubscriptionAccess(
      planId: plan.planId,
      planName: plan.name,
      maxPublishedCourses: plan.maxPublishedCourses,
      maxLessonsPerCourse: plan.maxLessonsPerCourse,
      maxAssignmentsPerCourse: plan.maxAssignmentsPerCourse,
      maxProjectsPerCourse: plan.maxProjectsPerCourse,
      maxGrandTestsPerCourse: plan.maxGrandTestsPerCourse,
      maxAiCreditsPerMonth: plan.maxAiCreditsPerMonth,
      allowPaidCourses: plan.allowPaidCourses,
      allowAnalytics: plan.allowAnalytics,
      isPremium: entitlement != null || plan.planId != 'free_plan',
    );
  }

  final String planId;
  final String planName;
  final int maxPublishedCourses;
  final int maxLessonsPerCourse;
  final int maxAssignmentsPerCourse;
  final int maxProjectsPerCourse;
  final int maxGrandTestsPerCourse;
  final int maxAiCreditsPerMonth;
  final bool allowPaidCourses;
  final bool allowAnalytics;
  final bool isPremium;
}

class TeacherSubscriptionCheckResult {
  const TeacherSubscriptionCheckResult({
    required this.allowed,
    required this.title,
    required this.message,
    required this.planName,
    this.needsUpgrade = false,
  });

  final bool allowed;
  final String title;
  final String message;
  final String planName;
  final bool needsUpgrade;
}

enum PlanChangeKind { current, upgrade, switchPlan, reactivate }

class PlanChangeEvaluation {
  const PlanChangeEvaluation({
    required this.kind,
    required this.currentPlanId,
    required this.currentPlanName,
    required this.target,
    required this.canCheckout,
    required this.ctaLabel,
    required this.message,
    this.subscription,
  });

  final PlanChangeKind kind;
  final String currentPlanId;
  final String currentPlanName;
  final PaymentPlanModel target;
  final PaymentSubscriptionModel? subscription;
  final bool canCheckout;
  final String ctaLabel;
  final String message;
}

class SubscriptionCancellationResult {
  const SubscriptionCancellationResult({
    required this.success,
    required this.message,
    this.subscriptionId,
    this.accessUntil,
    this.cancelAtPeriodEnd = false,
  });

  final bool success;
  final String message;
  final String? subscriptionId;
  final DateTime? accessUntil;
  final bool cancelAtPeriodEnd;
}

