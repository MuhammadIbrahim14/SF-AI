import 'package:cloud_firestore/cloud_firestore.dart';

import 'resolution_case_model.dart';

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

class ResolutionSettlementRequestStatus {
  const ResolutionSettlementRequestStatus._();

  static const pending = 'pending';
  static const processing = 'processing';
  static const completed = 'completed';
  static const failed = 'failed';
  static const rejected = 'rejected';
}

class ResolutionSettlementRequestModel {
  const ResolutionSettlementRequestModel({
    required this.requestId,
    required this.caseId,
    required this.orderId,
    required this.requestedByAdminId,
    required this.decision,
    required this.releaseAmount,
    required this.refundAmount,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.clientId,
    required this.freelancerId,
    required this.caseType,
    required this.openedBy,
    required this.openedByRole,
    required this.paymentStatus,
    required this.escrowStatus,
    required this.orderStatus,
    required this.adminNote,
    required this.createdAt,
    required this.updatedAt,
    required this.errorCode,
    required this.errorMessage,
    required this.resultSettlementId,
    required this.processedAt,
  });

  final String requestId;
  final String caseId;
  final String orderId;
  final String requestedByAdminId;
  final String decision;
  final double releaseAmount;
  final double refundAmount;
  final double totalAmount;
  final String currency;
  final String status;
  final String clientId;
  final String freelancerId;
  final String caseType;
  final String openedBy;
  final String openedByRole;
  final String paymentStatus;
  final String escrowStatus;
  final String orderStatus;
  final String adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorCode;
  final String? errorMessage;
  final String? resultSettlementId;
  final DateTime? processedAt;

  bool get isTerminal =>
      status == ResolutionSettlementRequestStatus.completed ||
      status == ResolutionSettlementRequestStatus.failed ||
      status == ResolutionSettlementRequestStatus.rejected;

  factory ResolutionSettlementRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ResolutionSettlementRequestModel(
      requestId: _stringValue(data['requestId'], doc.id),
      caseId: _stringValue(data['caseId']),
      orderId: _stringValue(data['orderId']),
      requestedByAdminId: _stringValue(data['requestedByAdminId']),
      decision: _stringValue(data['decision'], ResolutionDecision.none),
      releaseAmount: _doubleValue(data['releaseAmount']),
      refundAmount: _doubleValue(data['refundAmount']),
      totalAmount: _doubleValue(data['totalAmount']),
      currency: _stringValue(data['currency'], 'USD'),
      status: _stringValue(
        data['status'],
        ResolutionSettlementRequestStatus.pending,
      ),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      caseType: _stringValue(data['caseType']),
      openedBy: _stringValue(data['openedBy']),
      openedByRole: _stringValue(data['openedByRole']),
      paymentStatus: _stringValue(data['paymentStatus']),
      escrowStatus: _stringValue(data['escrowStatus']),
      orderStatus: _stringValue(data['orderStatus']),
      adminNote: _stringValue(data['adminNote']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      errorCode: data['errorCode'] is String
          ? data['errorCode'] as String
          : null,
      errorMessage: data['errorMessage'] is String
          ? data['errorMessage'] as String
          : null,
      resultSettlementId: data['resultSettlementId'] is String
          ? data['resultSettlementId'] as String
          : null,
      processedAt: _nullableDate(data['processedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'caseId': caseId,
      'orderId': orderId,
      'requestedByAdminId': requestedByAdminId,
      'decision': decision,
      'releaseAmount': releaseAmount,
      'refundAmount': refundAmount,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'caseType': caseType,
      'openedBy': openedBy,
      'openedByRole': openedByRole,
      'paymentStatus': paymentStatus,
      'escrowStatus': escrowStatus,
      'orderStatus': orderStatus,
      'adminNote': adminNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if ((errorCode ?? '').trim().isNotEmpty) 'errorCode': errorCode,
      if ((errorMessage ?? '').trim().isNotEmpty) 'errorMessage': errorMessage,
      if ((resultSettlementId ?? '').trim().isNotEmpty)
        'resultSettlementId': resultSettlementId,
      if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
    };
  }
}
