import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentStatus {
  const PaymentStatus._();

  static const pending = 'Pending';
  static const success = 'Success';
  static const failed = 'Failed';
  static const refunded = 'Refunded';
  static const cancelled = 'cancelled';
  static const active = 'active';

  static String normalize(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    switch (raw) {
      case 'pending':
        return pending;
      case 'success':
      case 'succeeded':
      case 'paid':
      case 'active':
        return success;
      case 'failed':
      case 'failure':
      case 'declined':
        return failed;
      case 'refunded':
        return refunded;
      case 'cancelled':
      case 'canceled':
        return cancelled;
      default:
        return value?.trim().isNotEmpty == true ? value!.trim() : pending;
    }
  }

  static bool isSuccess(String? value) {
    final n = normalize(value).toLowerCase();
    return n == success.toLowerCase() || n == active.toLowerCase();
  }

  static bool isPending(String? value) =>
      normalize(value).toLowerCase() == pending.toLowerCase();

  static bool isFailed(String? value) =>
      normalize(value).toLowerCase() == failed.toLowerCase();

  static bool isCancelled(String? value) =>
      normalize(value).toLowerCase() == cancelled.toLowerCase();
}

class PaymentType {
  const PaymentType._();

  static const plan = 'plan';
  static const creditPack = 'credit_pack';
  static const subscription = 'subscription';
  static const course = 'course';
  static const subscriptionCancel = 'subscription_cancel';
}

class PaymentGateway {
  const PaymentGateway._();

  static const skillforgeDemo = 'skillforge_demo';
  static const payfast = skillforgeDemo;
  @Deprecated('Use PaymentGateway.skillforgeDemo')
  static const dummy = skillforgeDemo;
}

class PaymentPlanModel {
  const PaymentPlanModel({
    required this.planId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.interval,
    required this.features,
    required this.isActive,
    required this.maxPublishedCourses,
    required this.maxLessonsPerCourse,
    required this.maxAssignmentsPerCourse,
    required this.maxProjectsPerCourse,
    required this.maxGrandTestsPerCourse,
    required this.maxAiCreditsPerMonth,
    required this.allowPaidCourses,
    required this.allowAnalytics,
    required this.createdAt,
    required this.updatedAt,
  });

  final String planId;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String interval;
  final List<String> features;
  final bool isActive;
  final int maxPublishedCourses;
  final int maxLessonsPerCourse;
  final int maxAssignmentsPerCourse;
  final int maxProjectsPerCourse;
  final int maxGrandTestsPerCourse;
  final int maxAiCreditsPerMonth;
  final bool allowPaidCourses;
  final bool allowAnalytics;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PaymentPlanModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PaymentPlanModel(
      planId: data['planId']?.toString() ?? doc.id,
      name: data['name']?.toString() ?? 'Plan',
      description: data['description']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'USD',
      interval: data['interval']?.toString() ?? 'monthly',
      features:
          (data['features'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const <String>[],
      isActive: data['isActive'] as bool? ?? true,
      maxPublishedCourses: (data['maxPublishedCourses'] as num?)?.toInt() ?? 0,
      maxLessonsPerCourse: (data['maxLessonsPerCourse'] as num?)?.toInt() ?? 0,
      maxAssignmentsPerCourse:
          (data['maxAssignmentsPerCourse'] as num?)?.toInt() ?? 0,
      maxProjectsPerCourse: (data['maxProjectsPerCourse'] as num?)?.toInt() ?? 0,
      maxGrandTestsPerCourse:
          (data['maxGrandTestsPerCourse'] as num?)?.toInt() ?? 0,
      maxAiCreditsPerMonth: (data['maxAiCreditsPerMonth'] as num?)?.toInt() ?? 0,
      allowPaidCourses: data['allowPaidCourses'] as bool? ?? false,
      allowAnalytics: data['allowAnalytics'] as bool? ?? false,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'interval': interval,
      'features': features,
      'isActive': isActive,
      'maxPublishedCourses': maxPublishedCourses,
      'maxLessonsPerCourse': maxLessonsPerCourse,
      'maxAssignmentsPerCourse': maxAssignmentsPerCourse,
      'maxProjectsPerCourse': maxProjectsPerCourse,
      'maxGrandTestsPerCourse': maxGrandTestsPerCourse,
      'maxAiCreditsPerMonth': maxAiCreditsPerMonth,
      'allowPaidCourses': allowPaidCourses,
      'allowAnalytics': allowAnalytics,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class PaymentSubscriptionModel {
  const PaymentSubscriptionModel({
    required this.subscriptionId,
    required this.userId,
    required this.planId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.autoRenew,
    this.cancelAtPeriodEnd = false,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String subscriptionId;
  final String userId;
  final String planId;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool autoRenew;
  /// When true, benefits continue until [currentPeriodEnd], then access ends
  /// and no further card charges occur.
  final bool cancelAtPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCancelScheduled =>
      cancelAtPeriodEnd && !PaymentStatus.isCancelled(status);

  factory PaymentSubscriptionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PaymentSubscriptionModel(
      subscriptionId: data['subscriptionId']?.toString() ?? doc.id,
      userId: data['userId']?.toString() ?? '',
      planId: data['planId']?.toString() ?? '',
      status: data['status']?.toString() ?? PaymentStatus.pending,
      currentPeriodStart: _dateValue(data['currentPeriodStart']),
      currentPeriodEnd: _dateValue(data['currentPeriodEnd']),
      autoRenew: data['autoRenew'] as bool? ?? true,
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
      cancelledAt: data['cancelledAt'] == null
          ? null
          : _dateValue(data['cancelledAt']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscriptionId': subscriptionId,
      'userId': userId,
      'planId': planId,
      'status': status,
      'currentPeriodStart': Timestamp.fromDate(currentPeriodStart),
      'currentPeriodEnd': Timestamp.fromDate(currentPeriodEnd),
      'autoRenew': autoRenew,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'cancelledAt':
          cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PaymentSubscriptionModel copyWith({
    String? subscriptionId,
    String? userId,
    String? planId,
    String? status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool? autoRenew,
    bool? cancelAtPeriodEnd,
    DateTime? cancelledAt,
    bool clearCancelledAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentSubscriptionModel(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      autoRenew: autoRenew ?? this.autoRenew,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      cancelledAt:
          clearCancelledAt ? null : (cancelledAt ?? this.cancelledAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PaymentTransactionModel {
  const PaymentTransactionModel({
    required this.transactionId,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    required this.gateway,
    required this.cardLast4,
    required this.paymentId,
    required this.description,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String transactionId;
  final String userId;
  final String type;
  final String status;
  final double amount;
  final String currency;
  final String gateway;
  final String cardLast4;
  final String paymentId;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PaymentTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PaymentTransactionModel(
      transactionId: data['transactionId']?.toString() ?? doc.id,
      userId: data['userId']?.toString() ?? '',
      type: data['type']?.toString() ?? PaymentType.plan,
      status: data['status']?.toString() ?? PaymentStatus.pending,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'USD',
      gateway: data['gateway']?.toString() ?? PaymentGateway.payfast,
      cardLast4: data['cardLast4']?.toString() ?? '',
      paymentId: data['paymentId']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      metadata:
          (data['metadata'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'userId': userId,
      'type': type,
      'status': status,
      'amount': amount,
      'currency': currency,
      'gateway': gateway,
      'cardLast4': cardLast4,
      'paymentId': paymentId,
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class PaymentRecordModel {
  const PaymentRecordModel({
    required this.paymentId,
    required this.transactionId,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    required this.gateway,
    required this.cardLast4,
    required this.planId,
    required this.creditPackId,
    required this.teacherId,
    required this.description,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
  });

  final String paymentId;
  final String transactionId;
  final String userId;
  final String type;
  final String status;
  final double amount;
  final String currency;
  final String gateway;
  final String cardLast4;
  final String? planId;
  final String? creditPackId;
  final String? teacherId;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PaymentRecordModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PaymentRecordModel(
      paymentId: data['paymentId']?.toString() ?? doc.id,
      transactionId: data['transactionId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      type: data['type']?.toString() ?? PaymentType.plan,
      status: data['status']?.toString() ?? PaymentStatus.pending,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'USD',
      gateway: data['gateway']?.toString() ?? PaymentGateway.payfast,
      cardLast4: data['cardLast4']?.toString() ?? '',
      planId: data['planId']?.toString(),
      creditPackId: data['creditPackId']?.toString(),
      teacherId: data['teacherId']?.toString(),
      description: data['description']?.toString() ?? '',
      metadata:
          (data['metadata'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'transactionId': transactionId,
      'userId': userId,
      'type': type,
      'status': status,
      'amount': amount,
      'currency': currency,
      'gateway': gateway,
      'cardLast4': cardLast4,
      'planId': planId,
      'creditPackId': creditPackId,
      'teacherId': teacherId,
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class CreditPackModel {
  const CreditPackModel({
    required this.packId,
    required this.name,
    required this.description,
    required this.credits,
    this.bonusCredits = 0,
    required this.price,
    required this.currency,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String packId;
  final String name;
  final String description;
  final int credits;
  final int bonusCredits;
  final double price;
  final String currency;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CreditPackModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CreditPackModel(
      packId: data['packId']?.toString() ?? doc.id,
      name: data['name']?.toString() ?? 'Credit Pack',
      description: data['description']?.toString() ?? '',
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      bonusCredits: (data['bonusCredits'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'USD',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packId': packId,
      'name': name,
      'description': description,
      'credits': credits,
      'bonusCredits': bonusCredits,
      'price': price,
      'currency': currency,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class TeacherEntitlementModel {
  const TeacherEntitlementModel({
    required this.entitlementId,
    required this.teacherId,
    required this.planId,
    required this.packageName,
    required this.credits,
    required this.features,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String entitlementId;
  final String teacherId;
  final String planId;
  final String packageName;
  final int credits;
  final Map<String, dynamic> features;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TeacherEntitlementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherEntitlementModel(
      entitlementId: data['entitlementId']?.toString() ?? doc.id,
      teacherId: data['teacherId']?.toString() ?? '',
      planId: data['planId']?.toString() ?? '',
      packageName: data['packageName']?.toString() ?? 'Premium',
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      features:
          (data['features'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      status: data['status']?.toString() ?? PaymentStatus.success,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entitlementId': entitlementId,
      'teacherId': teacherId,
      'planId': planId,
      'packageName': packageName,
      'credits': credits,
      'features': features,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class PaymentCardValidationResult {
  const PaymentCardValidationResult({
    required this.isValid,
    required this.message,
    required this.cardBrand,
    required this.cardLast4,
  });

  final bool isValid;
  final String message;
  final String cardBrand;
  final String cardLast4;
}

class PaymentProcessResult {
  const PaymentProcessResult({
    required this.transactionId,
    required this.paymentId,
    required this.status,
    required this.message,
    required this.amount,
    required this.currency,
    this.intentId,
    this.platformFee = 0,
    this.sellerNet = 0,
  });

  final String transactionId;
  final String paymentId;
  final String status;
  final String message;
  final double amount;
  final String currency;
  final String? intentId;
  final double platformFee;
  final double sellerNet;

  bool get isSuccess => PaymentStatus.isSuccess(status);
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
