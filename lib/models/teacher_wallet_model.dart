import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
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

class TeacherWalletModel {
  const TeacherWalletModel({
    required this.walletId,
    required this.teacherId,
    required this.availableBalance,
    required this.pendingBalance,
    required this.lifetimeEarnings,
    required this.lifetimeWithdrawn,
    required this.currency,
    required this.totalSalesCount,
    required this.uniqueStudentCount,
    required this.monthSalesCount,
    required this.monthRevenue,
    required this.updatedAt,
    required this.createdAt,
    this.lastSyncAt,
  });

  final String walletId;
  final String teacherId;
  final double availableBalance;
  final double pendingBalance;
  final double lifetimeEarnings;
  final double lifetimeWithdrawn;
  final String currency;
  final int totalSalesCount;
  final int uniqueStudentCount;
  final int monthSalesCount;
  final double monthRevenue;
  final DateTime updatedAt;
  final DateTime createdAt;
  final DateTime? lastSyncAt;

  double get withdrawableBalance => availableBalance;

  factory TeacherWalletModel.empty({
    required String teacherId,
    String currency = 'USD',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return TeacherWalletModel(
      walletId: teacherId,
      teacherId: teacherId,
      availableBalance: 0,
      pendingBalance: 0,
      lifetimeEarnings: 0,
      lifetimeWithdrawn: 0,
      currency: currency,
      totalSalesCount: 0,
      uniqueStudentCount: 0,
      monthSalesCount: 0,
      monthRevenue: 0,
      updatedAt: timestamp,
      createdAt: timestamp,
    );
  }

  factory TeacherWalletModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherWalletModel.fromMap(data, fallbackId: doc.id);
  }

  factory TeacherWalletModel.fromMap(
    Map<String, dynamic> data, {
    String fallbackId = '',
  }) {
    return TeacherWalletModel(
      walletId: _stringValue(data['walletId'], fallbackId),
      teacherId: _stringValue(data['teacherId'], fallbackId),
      availableBalance: _doubleValue(data['availableBalance']),
      pendingBalance: _doubleValue(data['pendingBalance']),
      lifetimeEarnings: _doubleValue(data['lifetimeEarnings']),
      lifetimeWithdrawn: _doubleValue(data['lifetimeWithdrawn']),
      currency: _stringValue(data['currency'], 'USD'),
      totalSalesCount: _intValue(data['totalSalesCount']),
      uniqueStudentCount: _intValue(data['uniqueStudentCount']),
      monthSalesCount: _intValue(data['monthSalesCount']),
      monthRevenue: _doubleValue(data['monthRevenue']),
      updatedAt: _dateValue(data['updatedAt']),
      createdAt: _dateValue(data['createdAt']),
      lastSyncAt: _nullableDate(data['lastSyncAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'teacherId': teacherId,
      'availableBalance': availableBalance,
      'pendingBalance': pendingBalance,
      'lifetimeEarnings': lifetimeEarnings,
      'lifetimeWithdrawn': lifetimeWithdrawn,
      'currency': currency,
      'totalSalesCount': totalSalesCount,
      'uniqueStudentCount': uniqueStudentCount,
      'monthSalesCount': monthSalesCount,
      'monthRevenue': monthRevenue,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastSyncAt != null) 'lastSyncAt': Timestamp.fromDate(lastSyncAt!),
    };
  }
}

class TeacherWalletTransactionType {
  const TeacherWalletTransactionType._();

  static const saleSync = 'sale_sync';
  static const release = 'release';
  static const withdraw = 'withdraw';
}

class TeacherWalletTransactionModel {
  const TeacherWalletTransactionModel({
    required this.transactionId,
    required this.teacherId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    required this.createdAt,
    this.courseId,
    this.purchaseId,
    this.referenceId,
  });

  final String transactionId;
  final String teacherId;
  final String type;
  final double amount;
  final String currency;
  final String description;
  final DateTime createdAt;
  final String? courseId;
  final String? purchaseId;
  final String? referenceId;

  factory TeacherWalletTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherWalletTransactionModel.fromMap(data, fallbackId: doc.id);
  }

  factory TeacherWalletTransactionModel.fromMap(
    Map<String, dynamic> data, {
    String fallbackId = '',
  }) {
    return TeacherWalletTransactionModel(
      transactionId: _stringValue(data['transactionId'], fallbackId),
      teacherId: _stringValue(data['teacherId']),
      type: _stringValue(data['type']),
      amount: _doubleValue(data['amount']),
      currency: _stringValue(data['currency'], 'USD'),
      description: _stringValue(data['description']),
      createdAt: _dateValue(data['createdAt']),
      courseId: _stringValue(data['courseId']).isEmpty
          ? null
          : _stringValue(data['courseId']),
      purchaseId: _stringValue(data['purchaseId']).isEmpty
          ? null
          : _stringValue(data['purchaseId']),
      referenceId: _stringValue(data['referenceId']).isEmpty
          ? null
          : _stringValue(data['referenceId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'teacherId': teacherId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      if (courseId != null) 'courseId': courseId,
      if (purchaseId != null) 'purchaseId': purchaseId,
      if (referenceId != null) 'referenceId': referenceId,
    };
  }
}
