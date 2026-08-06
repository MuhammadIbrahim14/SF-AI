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

class RefundStatus {
  const RefundStatus._();

  static const requested = 'requested';
  static const pendingReview = 'pendingReview';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const processed = 'processed';
  static const cancelled = 'cancelled';

  static const values = {
    requested,
    pendingReview,
    approved,
    rejected,
    processed,
    cancelled,
  };

  static String normalize(String? value) {
    final normalized = (value ?? requested).trim();
    return values.contains(normalized) ? normalized : requested;
  }
}

class RefundModel {
  const RefundModel({
    required this.refundId,
    required this.orderId,
    required this.serviceRequestId,
    required this.clientId,
    required this.freelancerId,
    required this.serviceTitle,
    required this.requestedBy,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.approvedAt,
    required this.processedAt,
    required this.rejectedAt,
    required this.cancelledAt,
  });

  final String refundId;
  final String orderId;
  final String serviceRequestId;
  final String clientId;
  final String freelancerId;
  final String serviceTitle;
  final String requestedBy;
  final double amount;
  final String currency;
  final String reason;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final DateTime? processedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;

  factory RefundModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RefundModel(
      refundId: _stringValue(data['refundId'], doc.id),
      orderId: _stringValue(data['orderId']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      serviceTitle: _stringValue(data['serviceTitle']),
      requestedBy: _stringValue(data['requestedBy']),
      amount: _doubleValue(data['amount']),
      currency: _stringValue(data['currency'], 'USD'),
      reason: _stringValue(data['reason']),
      status: RefundStatus.normalize(data['status']?.toString()),
      adminNotes: data['adminNotes'] is String
          ? data['adminNotes'] as String
          : null,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      approvedAt: _nullableDate(data['approvedAt']),
      processedAt: _nullableDate(data['processedAt']),
      rejectedAt: _nullableDate(data['rejectedAt']),
      cancelledAt: _nullableDate(data['cancelledAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'refundId': refundId,
      'orderId': orderId,
      'serviceRequestId': serviceRequestId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'serviceTitle': serviceTitle,
      'requestedBy': requestedBy,
      'amount': amount,
      'currency': currency,
      'reason': reason,
      'status': RefundStatus.normalize(status),
      if ((adminNotes ?? '').trim().isNotEmpty) 'adminNotes': adminNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
      if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
    };
  }
}
