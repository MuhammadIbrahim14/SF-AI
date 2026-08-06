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

class PayoutDestinationType {
  const PayoutDestinationType._();

  static const sandboxBank = 'Sandbox Bank';
  static const sandboxStripe = 'Sandbox Stripe';
  static const sandboxPayPal = 'Sandbox PayPal';
  static const futureCustom = 'Future Custom';

  static const values = {
    sandboxBank,
    sandboxStripe,
    sandboxPayPal,
    futureCustom,
  };

  static String normalize(String? value) {
    final normalized = (value ?? sandboxBank).trim();
    return values.contains(normalized) ? normalized : sandboxBank;
  }
}

class PayoutStatus {
  const PayoutStatus._();

  static const pendingApproval = 'pendingApproval';
  static const pending = 'pending';
  static const approved = 'approved';
  static const processing = 'processing';
  static const paid = 'paid';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';

  static const values = {
    pendingApproval,
    pending,
    approved,
    processing,
    paid,
    rejected,
    cancelled,
  };

  static const activeStatuses = {
    pendingApproval,
    pending,
    approved,
    processing,
  };

  static String normalize(String? value) {
    final normalized = (value ?? pendingApproval).trim();
    if (normalized == pending) return pendingApproval;
    return values.contains(normalized) ? normalized : pendingApproval;
  }

  static bool isActive(String status) => activeStatuses.contains(status);
}

class PayoutModel {
  const PayoutModel({
    required this.payoutId,
    required this.freelancerId,
    required this.walletId,
    required this.amount,
    required this.currency,
    required this.destinationType,
    required this.destinationName,
    required this.destinationMasked,
    required this.status,
    required this.requestedAt,
    required this.approvedAt,
    required this.processedAt,
    required this.completedAt,
    required this.notes,
  });

  final String payoutId;
  final String freelancerId;
  final String walletId;
  final double amount;
  final String currency;
  final String destinationType;
  final String destinationName;
  final String destinationMasked;
  final String status;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? processedAt;
  final DateTime? completedAt;
  final String notes;

  bool get isActive => PayoutStatus.isActive(status);

  factory PayoutModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PayoutModel(
      payoutId: _stringValue(data['payoutId'], doc.id),
      freelancerId: _stringValue(data['freelancerId']),
      walletId: _stringValue(data['walletId']),
      amount: _doubleValue(data['amount']),
      currency: _stringValue(data['currency'], 'USD'),
      destinationType: PayoutDestinationType.normalize(
        data['destinationType']?.toString(),
      ),
      destinationName: _stringValue(data['destinationName']),
      destinationMasked: _stringValue(data['destinationMasked']),
      status: PayoutStatus.normalize(data['status']?.toString()),
      requestedAt: _dateValue(data['requestedAt']),
      approvedAt: _nullableDate(data['approvedAt']),
      processedAt: _nullableDate(data['processedAt']),
      completedAt: _nullableDate(data['completedAt']),
      notes: _stringValue(data['notes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payoutId': payoutId,
      'freelancerId': freelancerId,
      'walletId': walletId,
      'amount': amount,
      'currency': currency,
      'destinationType': PayoutDestinationType.normalize(destinationType),
      'destinationName': destinationName,
      'destinationMasked': destinationMasked,
      'status': PayoutStatus.normalize(status),
      'requestedAt': Timestamp.fromDate(requestedAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'notes': notes,
    };
  }
}
