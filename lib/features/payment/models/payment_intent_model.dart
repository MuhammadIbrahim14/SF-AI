import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentIntentStatus {
  const PaymentIntentStatus._();

  static const pending = 'pending';
  static const paid = 'paid';
  static const failed = 'failed';
}

class PaymentIntentModel {
  const PaymentIntentModel({
    required this.intentId,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    required this.description,
    required this.paymentMethod,
    required this.platformFee,
    required this.sellerNet,
    required this.platformFeeRate,
    required this.gateway,
    required this.createdAt,
    required this.updatedAt,
    this.basketId,
    this.paymentId,
    this.transactionId,
    this.planId,
    this.creditPackId,
    this.teacherId,
    this.orderId,
    this.role,
    this.checkoutPageUrl,
    this.errorMessage,
    this.metadata = const {},
  });

  final String intentId;
  final String userId;
  final String type;
  final String status;
  final double amount;
  final String currency;
  final String description;
  final String paymentMethod;
  final double platformFee;
  final double sellerNet;
  final double platformFeeRate;
  final String gateway;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? basketId;
  final String? paymentId;
  final String? transactionId;
  final String? planId;
  final String? creditPackId;
  final String? teacherId;
  final String? orderId;
  final String? role;
  final String? checkoutPageUrl;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  bool get isPending => status == PaymentIntentStatus.pending;
  bool get isPaid =>
      status == PaymentIntentStatus.paid ||
      status.toLowerCase() == 'success';
  bool get isFailed => status == PaymentIntentStatus.failed;

  factory PaymentIntentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PaymentIntentModel(
      intentId: data['intentId']?.toString() ?? doc.id,
      userId: data['userId']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      status: data['status']?.toString() ?? PaymentIntentStatus.pending,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'PKR',
      description: data['description']?.toString() ?? '',
      paymentMethod: data['paymentMethod']?.toString() ?? 'card',
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
      sellerNet: (data['sellerNet'] as num?)?.toDouble() ?? 0,
      platformFeeRate: (data['platformFeeRate'] as num?)?.toDouble() ?? 0,
      gateway: data['gateway']?.toString() ?? 'skillforge_demo',
      basketId: data['basketId']?.toString(),
      paymentId: data['paymentId']?.toString(),
      transactionId: data['transactionId']?.toString(),
      planId: data['planId']?.toString(),
      creditPackId: data['creditPackId']?.toString(),
      teacherId: data['teacherId']?.toString(),
      orderId: data['orderId']?.toString(),
      role: data['role']?.toString(),
      checkoutPageUrl: data['checkoutPageUrl']?.toString(),
      errorMessage: data['errorMessage']?.toString(),
      metadata:
          (data['metadata'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

class PayFastCheckoutSession {
  const PayFastCheckoutSession({
    required this.intentId,
    required this.basketId,
    required this.paymentId,
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.platformFee,
    required this.sellerNet,
    required this.platformFeeRate,
    required this.checkoutPageUrl,
  });

  final String intentId;
  final String basketId;
  final String paymentId;
  final String transactionId;
  final String status;
  final double amount;
  final String currency;
  final double platformFee;
  final double sellerNet;
  final double platformFeeRate;
  final String checkoutPageUrl;

  factory PayFastCheckoutSession.fromMap(Map<String, dynamic> data) {
    return PayFastCheckoutSession(
      intentId: data['intentId']?.toString() ?? '',
      basketId: data['basketId']?.toString() ?? '',
      paymentId: data['paymentId']?.toString() ?? '',
      transactionId: data['transactionId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'PKR',
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
      sellerNet: (data['sellerNet'] as num?)?.toDouble() ?? 0,
      platformFeeRate: (data['platformFeeRate'] as num?)?.toDouble() ?? 0,
      checkoutPageUrl: data['checkoutPageUrl']?.toString() ?? '',
    );
  }
}
