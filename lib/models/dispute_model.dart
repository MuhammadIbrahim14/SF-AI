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

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

class DisputeStatus {
  const DisputeStatus._();

  static const open = 'open';
  static const underReview = 'underReview';
  static const waitingResponse = 'waitingResponse';
  static const evidenceSubmitted = 'evidenceSubmitted';
  static const resolved = 'resolved';
  static const closed = 'closed';
  static const rejected = 'rejected';

  static const values = {
    open,
    underReview,
    waitingResponse,
    evidenceSubmitted,
    resolved,
    closed,
    rejected,
  };

  static String normalize(String? value) {
    final normalized = (value ?? open).trim();
    return values.contains(normalized) ? normalized : open;
  }
}

class DisputeDecision {
  const DisputeDecision._();

  static const releaseEscrow = 'releaseEscrow';
  static const refundClient = 'refundClient';
  static const splitDecision = 'splitDecision';
  static const rejectDispute = 'rejectDispute';

  static const values = {
    releaseEscrow,
    refundClient,
    splitDecision,
    rejectDispute,
  };

  static String normalize(String? value) {
    final normalized = (value ?? '').trim();
    return values.contains(normalized) ? normalized : '';
  }
}

class DisputeModel {
  const DisputeModel({
    required this.disputeId,
    required this.orderId,
    required this.serviceRequestId,
    required this.clientId,
    required this.freelancerId,
    required this.serviceTitle,
    required this.openedBy,
    required this.reason,
    required this.status,
    required this.evidence,
    required this.decision,
    required this.resolutionNotes,
    required this.refundAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.closedAt,
  });

  final String disputeId;
  final String orderId;
  final String serviceRequestId;
  final String clientId;
  final String freelancerId;
  final String serviceTitle;
  final String openedBy;
  final String reason;
  final String status;
  final List<Map<String, dynamic>> evidence;
  final String? decision;
  final String? resolutionNotes;
  final double refundAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  factory DisputeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DisputeModel(
      disputeId: _stringValue(data['disputeId'], doc.id),
      orderId: _stringValue(data['orderId']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      serviceTitle: _stringValue(data['serviceTitle']),
      openedBy: _stringValue(data['openedBy']),
      reason: _stringValue(data['reason']),
      status: DisputeStatus.normalize(data['status']?.toString()),
      evidence: _mapList(data['evidence']),
      decision: data['decision'] is String ? data['decision'] as String : null,
      resolutionNotes: data['resolutionNotes'] is String
          ? data['resolutionNotes'] as String
          : null,
      refundAmount: _doubleValue(data['refundAmount']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      resolvedAt: _nullableDate(data['resolvedAt']),
      closedAt: _nullableDate(data['closedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'disputeId': disputeId,
      'orderId': orderId,
      'serviceRequestId': serviceRequestId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'serviceTitle': serviceTitle,
      'openedBy': openedBy,
      'reason': reason,
      'status': DisputeStatus.normalize(status),
      'evidence': evidence,
      if ((decision ?? '').trim().isNotEmpty)
        'decision': DisputeDecision.normalize(decision),
      if ((resolutionNotes ?? '').trim().isNotEmpty)
        'resolutionNotes': resolutionNotes,
      'refundAmount': refundAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
    };
  }
}
