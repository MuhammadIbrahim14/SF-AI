import 'package:cloud_firestore/cloud_firestore.dart';

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

class CustomerWalletStatus {
  const CustomerWalletStatus._();

  static const active = 'active';
  static const frozen = 'frozen';
}

class WalletTransactionOwnerType {
  const WalletTransactionOwnerType._();

  static const customer = 'customer';
  static const freelancer = 'freelancer';
  static const platform = 'platform';
}

class WalletTransactionType {
  const WalletTransactionType._();

  static const demoTopUp = 'demoTopUp';
  static const orderPayment = 'orderPayment';
  static const escrowHold = 'escrowHold';
  static const escrowRelease = 'escrowRelease';
  static const refund = 'refund';
  static const splitRefund = 'splitRefund';
  static const adjustment = 'adjustment';
}

class WalletTransactionDirection {
  const WalletTransactionDirection._();

  static const credit = 'credit';
  static const debit = 'debit';
}

class WalletTransactionStatus {
  const WalletTransactionStatus._();

  static const completed = 'completed';
  static const pending = 'pending';
  static const failed = 'failed';
}

class CustomerWalletModel {
  const CustomerWalletModel({
    required this.walletId,
    required this.customerId,
    required this.currency,
    required this.availableBalance,
    required this.totalAdded,
    required this.totalSpent,
    required this.totalRefunded,
    required this.totalEscrowed,
    required this.createdAt,
    required this.updatedAt,
    required this.lastTopUpAt,
    required this.status,
  });

  final String walletId;
  final String customerId;
  final String currency;
  final double availableBalance;
  final double totalAdded;
  final double totalSpent;
  final double totalRefunded;
  final double totalEscrowed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastTopUpAt;
  final String status;

  factory CustomerWalletModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CustomerWalletModel(
      walletId: _stringValue(data['walletId'], doc.id),
      customerId: _stringValue(data['customerId'], doc.id),
      currency: _stringValue(data['currency'], 'USD'),
      availableBalance: _doubleValue(data['availableBalance']),
      totalAdded: _doubleValue(data['totalAdded']),
      totalSpent: _doubleValue(data['totalSpent']),
      totalRefunded: _doubleValue(data['totalRefunded']),
      totalEscrowed: _doubleValue(data['totalEscrowed']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      lastTopUpAt: _nullableDate(data['lastTopUpAt']),
      status: _stringValue(data['status'], CustomerWalletStatus.active),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'customerId': customerId,
      'currency': currency,
      'availableBalance': availableBalance,
      'totalAdded': totalAdded,
      'totalSpent': totalSpent,
      'totalRefunded': totalRefunded,
      'totalEscrowed': totalEscrowed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastTopUpAt != null) 'lastTopUpAt': Timestamp.fromDate(lastTopUpAt!),
      'status': status,
    };
  }

  static CustomerWalletModel empty(String customerId, DateTime now) {
    return CustomerWalletModel(
      walletId: customerId,
      customerId: customerId,
      currency: 'USD',
      availableBalance: 0,
      totalAdded: 0,
      totalSpent: 0,
      totalRefunded: 0,
      totalEscrowed: 0,
      createdAt: now,
      updatedAt: now,
      lastTopUpAt: null,
      status: CustomerWalletStatus.active,
    );
  }
}

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.transactionId,
    required this.ownerId,
    required this.ownerType,
    required this.walletId,
    required this.type,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.status,
    required this.orderId,
    required this.caseId,
    required this.referenceId,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String transactionId;
  final String ownerId;
  final String ownerType;
  final String walletId;
  final String type;
  final String direction;
  final double amount;
  final String currency;
  final String status;
  final String? orderId;
  final String? caseId;
  final String? referenceId;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WalletTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WalletTransactionModel(
      transactionId: _stringValue(data['transactionId'], doc.id),
      ownerId: _stringValue(data['ownerId']),
      ownerType: _stringValue(data['ownerType']),
      walletId: _stringValue(data['walletId']),
      type: _stringValue(data['type']),
      direction: _stringValue(data['direction']),
      amount: _doubleValue(data['amount']),
      currency: _stringValue(data['currency'], 'USD'),
      status: _stringValue(data['status'], WalletTransactionStatus.completed),
      orderId: data['orderId'] is String ? data['orderId'] as String : null,
      caseId: data['caseId'] is String ? data['caseId'] as String : null,
      referenceId: data['referenceId'] is String
          ? data['referenceId'] as String
          : null,
      description: _stringValue(data['description']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'ownerId': ownerId,
      'ownerType': ownerType,
      'walletId': walletId,
      'type': type,
      'direction': direction,
      'amount': amount,
      'currency': currency,
      'status': status,
      if ((orderId ?? '').trim().isNotEmpty) 'orderId': orderId,
      if ((caseId ?? '').trim().isNotEmpty) 'caseId': caseId,
      if ((referenceId ?? '').trim().isNotEmpty) 'referenceId': referenceId,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
