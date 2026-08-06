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

class FreelancerWalletModel {
  const FreelancerWalletModel({
    required this.walletId,
    required this.freelancerId,
    required this.availableBalance,
    required this.pendingBalance,
    required this.escrowBalance,
    required this.pendingPayoutBalance,
    required this.lifetimeEarnings,
    required this.lifetimeWithdrawn,
    required this.currency,
    required this.monthlyEarnings,
    required this.weeklyEarnings,
    required this.ordersThisMonth,
    required this.activePayoutId,
    required this.updatedAt,
    required this.createdAt,
  });

  final String walletId;
  final String freelancerId;
  final double availableBalance;
  final double pendingBalance;
  final double escrowBalance;
  final double pendingPayoutBalance;
  final double lifetimeEarnings;
  final double lifetimeWithdrawn;
  final String currency;
  final double monthlyEarnings;
  final double weeklyEarnings;
  final int ordersThisMonth;
  final String? activePayoutId;
  final DateTime updatedAt;
  final DateTime createdAt;

  factory FreelancerWalletModel.empty({
    required String freelancerId,
    String currency = 'USD',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return FreelancerWalletModel(
      walletId: freelancerId,
      freelancerId: freelancerId,
      availableBalance: 0,
      pendingBalance: 0,
      escrowBalance: 0,
      pendingPayoutBalance: 0,
      lifetimeEarnings: 0,
      lifetimeWithdrawn: 0,
      currency: currency,
      monthlyEarnings: 0,
      weeklyEarnings: 0,
      ordersThisMonth: 0,
      activePayoutId: null,
      updatedAt: timestamp,
      createdAt: timestamp,
    );
  }

  factory FreelancerWalletModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FreelancerWalletModel(
      walletId: _stringValue(data['walletId'], doc.id),
      freelancerId: _stringValue(data['freelancerId'], doc.id),
      availableBalance: _doubleValue(data['availableBalance']),
      pendingBalance: _doubleValue(data['pendingBalance']),
      escrowBalance: _doubleValue(data['escrowBalance']),
      pendingPayoutBalance: _doubleValue(data['pendingPayoutBalance']),
      lifetimeEarnings: _doubleValue(data['lifetimeEarnings']),
      lifetimeWithdrawn: _doubleValue(data['lifetimeWithdrawn']),
      currency: _stringValue(data['currency'], 'USD'),
      monthlyEarnings: _doubleValue(data['monthlyEarnings']),
      weeklyEarnings: _doubleValue(data['weeklyEarnings']),
      ordersThisMonth: _intValue(data['ordersThisMonth']),
      activePayoutId: data['activePayoutId'] is String
          ? data['activePayoutId'] as String
          : null,
      updatedAt: _dateValue(data['updatedAt']),
      createdAt: _dateValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'freelancerId': freelancerId,
      'availableBalance': availableBalance,
      'pendingBalance': pendingBalance,
      'escrowBalance': escrowBalance,
      'pendingPayoutBalance': pendingPayoutBalance,
      'lifetimeEarnings': lifetimeEarnings,
      'lifetimeWithdrawn': lifetimeWithdrawn,
      'currency': currency,
      'monthlyEarnings': monthlyEarnings,
      'weeklyEarnings': weeklyEarnings,
      'ordersThisMonth': ordersThisMonth,
      if ((activePayoutId ?? '').trim().isNotEmpty)
        'activePayoutId': activePayoutId,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
