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

class CommissionLedgerSource {
  const CommissionLedgerSource._();

  static const freelancerService = 'freelancerService';
}

class CommissionLedgerStatus {
  const CommissionLedgerStatus._();

  static const pending = 'pending';
  static const released = 'released';
  static const reversed = 'reversed';

  static const values = {pending, released, reversed};

  static String normalize(String? value) {
    final normalized = (value ?? pending).trim();
    return values.contains(normalized) ? normalized : pending;
  }
}

class CommissionLedgerModel {
  const CommissionLedgerModel({
    required this.commissionId,
    required this.orderId,
    required this.serviceRequestId,
    required this.amount,
    required this.percentage,
    required this.currency,
    required this.source,
    required this.status,
    required this.createdAt,
  });

  final String commissionId;
  final String orderId;
  final String serviceRequestId;
  final double amount;
  final double percentage;
  final String currency;
  final String source;
  final String status;
  final DateTime createdAt;

  factory CommissionLedgerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CommissionLedgerModel(
      commissionId: _stringValue(data['commissionId'], doc.id),
      orderId: _stringValue(data['orderId']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      amount: _doubleValue(data['amount']),
      percentage: _doubleValue(data['percentage']),
      currency: _stringValue(data['currency'], 'USD'),
      source: _stringValue(
        data['source'],
        CommissionLedgerSource.freelancerService,
      ),
      status: CommissionLedgerStatus.normalize(data['status']?.toString()),
      createdAt: _dateValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commissionId': commissionId,
      'orderId': orderId,
      'serviceRequestId': serviceRequestId,
      'amount': amount,
      'percentage': percentage,
      'currency': currency,
      'source': source,
      'status': CommissionLedgerStatus.normalize(status),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
