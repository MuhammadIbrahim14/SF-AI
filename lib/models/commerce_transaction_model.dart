import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

class CommerceTransactionType {
  const CommerceTransactionType._();

  static const escrowHold = 'escrowHold';
  static const escrowRelease = 'escrowRelease';
  static const walletClearance = 'walletClearance';
  static const payoutRequest = 'payoutRequest';
  static const payoutPaid = 'payoutPaid';
  static const payoutRejected = 'payoutRejected';
  static const payoutCancelled = 'payoutCancelled';
  static const commission = 'commission';
  static const refund = 'refund';
  static const withdrawal = 'withdrawal';
  static const adjustment = 'adjustment';
  static const bonus = 'bonus';
  static const penalty = 'penalty';

  static const values = {
    escrowHold,
    escrowRelease,
    walletClearance,
    payoutRequest,
    payoutPaid,
    payoutRejected,
    payoutCancelled,
    commission,
    refund,
    withdrawal,
    adjustment,
    bonus,
    penalty,
  };

  static String normalize(String? value) {
    final normalized = (value ?? adjustment).trim();
    return values.contains(normalized) ? normalized : adjustment;
  }
}

class CommerceTransactionStatus {
  const CommerceTransactionStatus._();

  static const pending = 'pending';
  static const cleared = 'cleared';
  static const failed = 'failed';

  static const values = {pending, cleared, failed};

  static String normalize(String? value) {
    final normalized = (value ?? pending).trim();
    return values.contains(normalized) ? normalized : pending;
  }
}

class CommerceTransactionModel {
  const CommerceTransactionModel({
    required this.transactionId,
    required this.orderId,
    required this.serviceRequestId,
    required this.userId,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.referenceId,
    required this.description,
    required this.createdAt,
  });

  final String transactionId;
  final String orderId;
  final String serviceRequestId;
  final String userId;
  final String? walletId;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final String? referenceId;
  final String description;
  final DateTime createdAt;

  factory CommerceTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CommerceTransactionModel(
      transactionId: _stringValue(data['transactionId'], doc.id),
      orderId: _stringValue(data['orderId']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      userId: _stringValue(data['userId']),
      walletId: data['walletId'] is String ? data['walletId'] as String : null,
      type: CommerceTransactionType.normalize(data['type']?.toString()),
      amount: _doubleValue(data['amount']),
      currency: _stringValue(data['currency'], 'USD'),
      status: CommerceTransactionStatus.normalize(data['status']?.toString()),
      referenceId: data['referenceId'] is String
          ? data['referenceId'] as String
          : null,
      description: _stringValue(data['description']),
      createdAt: _dateValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'orderId': orderId,
      'serviceRequestId': serviceRequestId,
      'userId': userId,
      if ((walletId ?? '').trim().isNotEmpty) 'walletId': walletId,
      'type': CommerceTransactionType.normalize(type),
      'amount': amount,
      'currency': currency,
      'status': CommerceTransactionStatus.normalize(status),
      if ((referenceId ?? '').trim().isNotEmpty) 'referenceId': referenceId,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
