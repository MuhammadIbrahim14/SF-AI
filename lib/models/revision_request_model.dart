import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
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

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

class RevisionRequestStatus {
  const RevisionRequestStatus._();

  static const requested = 'revisionRequested';
  static const accepted = 'revisionAccepted';
  static const submitted = 'revisionSubmitted';
  static const completed = 'revisionCompleted';
  static const rejected = 'revisionRejected';
  static const cancelled = 'revisionCancelled';

  static const values = {
    requested,
    accepted,
    submitted,
    completed,
    rejected,
    cancelled,
  };

  static String normalize(String? value) {
    final normalized = (value ?? requested).trim();
    return values.contains(normalized) ? normalized : requested;
  }
}

class RevisionRequestModel {
  const RevisionRequestModel({
    required this.revisionId,
    required this.orderId,
    required this.serviceRequestId,
    required this.clientId,
    required this.freelancerId,
    required this.serviceTitle,
    required this.revisionNumber,
    required this.revisionLimit,
    required this.requestedBy,
    required this.submittedBy,
    required this.status,
    required this.notes,
    required this.freelancerResponse,
    required this.submissionNotes,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    required this.acceptedAt,
    required this.submittedAt,
    required this.completedAt,
    required this.cancelledAt,
  });

  final String revisionId;
  final String orderId;
  final String serviceRequestId;
  final String clientId;
  final String freelancerId;
  final String serviceTitle;
  final int revisionNumber;
  final int revisionLimit;
  final String requestedBy;
  final String? submittedBy;
  final String status;
  final String notes;
  final String? freelancerResponse;
  final String? submissionNotes;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  factory RevisionRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RevisionRequestModel(
      revisionId: _stringValue(data['revisionId'], doc.id),
      orderId: _stringValue(data['orderId']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      serviceTitle: _stringValue(data['serviceTitle']),
      revisionNumber: _intValue(data['revisionNumber']),
      revisionLimit: _intValue(data['revisionLimit'], 2),
      requestedBy: _stringValue(data['requestedBy']),
      submittedBy: data['submittedBy'] is String
          ? data['submittedBy'] as String
          : null,
      status: RevisionRequestStatus.normalize(data['status']?.toString()),
      notes: _stringValue(data['notes']),
      freelancerResponse: data['freelancerResponse'] is String
          ? data['freelancerResponse'] as String
          : null,
      submissionNotes: data['submissionNotes'] is String
          ? data['submissionNotes'] as String
          : null,
      attachments: _stringList(data['attachments']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      acceptedAt: _nullableDate(data['acceptedAt']),
      submittedAt: _nullableDate(data['submittedAt']),
      completedAt: _nullableDate(data['completedAt']),
      cancelledAt: _nullableDate(data['cancelledAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'revisionId': revisionId,
      'orderId': orderId,
      'serviceRequestId': serviceRequestId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'serviceTitle': serviceTitle,
      'revisionNumber': revisionNumber,
      'revisionLimit': revisionLimit,
      'requestedBy': requestedBy,
      if ((submittedBy ?? '').trim().isNotEmpty) 'submittedBy': submittedBy,
      'status': RevisionRequestStatus.normalize(status),
      'notes': notes,
      if ((freelancerResponse ?? '').trim().isNotEmpty)
        'freelancerResponse': freelancerResponse,
      if ((submissionNotes ?? '').trim().isNotEmpty)
        'submissionNotes': submissionNotes,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
    };
  }
}
