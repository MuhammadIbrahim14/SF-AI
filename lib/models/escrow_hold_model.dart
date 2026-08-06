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

class EscrowHoldStatus {
  const EscrowHoldStatus._();

  static const held = 'held';
  static const released = 'released';
  static const refunded = 'refunded';
  static const disputed = 'disputed';
  static const split = 'split';

  static const values = {held, released, refunded, disputed, split};

  static String normalize(String? value) {
    final normalized = (value ?? held).trim();
    return values.contains(normalized) ? normalized : held;
  }
}

class EscrowHoldModel {
  const EscrowHoldModel({
    required this.escrowId,
    required this.orderId,
    required this.clientId,
    required this.freelancerId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.holdStartedAt,
    required this.expectedReleaseAt,
    required this.holdReason,
    required this.createdAt,
  });

  final String escrowId;
  final String orderId;
  final String clientId;
  final String freelancerId;
  final double amount;
  final String currency;
  final String status;
  final DateTime holdStartedAt;
  final DateTime expectedReleaseAt;
  final String holdReason;
  final DateTime createdAt;

  factory EscrowHoldModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EscrowHoldModel(
      escrowId: _stringValue(data['escrowId'], doc.id),
      orderId: _stringValue(data['orderId']),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      amount: _doubleValue(data['amount']),
      currency: _stringValue(data['currency'], 'USD'),
      status: EscrowHoldStatus.normalize(data['status']?.toString()),
      holdStartedAt: _dateValue(data['holdStartedAt']),
      expectedReleaseAt: _dateValue(data['expectedReleaseAt']),
      holdReason: _stringValue(data['holdReason']),
      createdAt: _dateValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'escrowId': escrowId,
      'orderId': orderId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'amount': amount,
      'currency': currency,
      'status': EscrowHoldStatus.normalize(status),
      'holdStartedAt': Timestamp.fromDate(holdStartedAt),
      'expectedReleaseAt': Timestamp.fromDate(expectedReleaseAt),
      'holdReason': holdReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
