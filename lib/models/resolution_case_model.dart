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

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

class ResolutionCaseType {
  const ResolutionCaseType._();

  static const revision = 'revision';
  static const dispute = 'dispute';
  static const refund = 'refund';

  static const values = {revision, dispute, refund};

  static String normalize(String? value) {
    final normalized = (value ?? dispute).trim();
    return values.contains(normalized) ? normalized : dispute;
  }
}

class ResolutionCaseStatus {
  const ResolutionCaseStatus._();

  static const draft = 'draft';
  static const open = 'open';
  static const revisionRequested = 'revisionRequested';
  static const revisionAccepted = 'revisionAccepted';
  static const revisionSubmitted = 'revisionSubmitted';
  static const revisionCompleted = 'revisionCompleted';
  static const evidenceRequested = 'evidenceRequested';
  static const underReview = 'underReview';
  static const resolved = 'resolved';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';

  static const values = {
    draft,
    open,
    revisionRequested,
    revisionAccepted,
    revisionSubmitted,
    revisionCompleted,
    evidenceRequested,
    underReview,
    resolved,
    rejected,
    cancelled,
  };

  static String normalize(String? value) {
    final normalized = (value ?? open).trim();
    return values.contains(normalized) ? normalized : open;
  }
}

class ResolutionDecision {
  const ResolutionDecision._();

  static const none = 'none';
  static const releaseToFreelancer = 'releaseToFreelancer';
  static const refundToClient = 'refundToClient';
  static const splitRelease = 'splitRelease';
  static const rejectRequest = 'rejectRequest';
}

class ResolutionSettlementStatus {
  const ResolutionSettlementStatus._();

  static const none = 'none';
  static const pending = 'pending';
  static const rejected = 'rejected';
  static const recorded = 'recorded';
  static const completed = 'completed';
  static const failed = 'failed';
}

class ResolutionEvidenceRequestStatus {
  const ResolutionEvidenceRequestStatus._();

  static const none = 'none';
  static const requestedFromClient = 'requestedFromClient';
  static const requestedFromFreelancer = 'requestedFromFreelancer';
  static const requestedFromBoth = 'requestedFromBoth';
  static const submitted = 'submitted';
}

class ResolutionAiRecommendationStatus {
  const ResolutionAiRecommendationStatus._();

  static const notGenerated = 'notGenerated';
  static const generated = 'generated';
  static const reviewed = 'reviewed';
}

class ResolutionPriority {
  const ResolutionPriority._();

  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
  static const urgent = 'urgent';
}

class ResolutionEventType {
  const ResolutionEventType._();

  static const caseCreated = 'caseCreated';
  static const revisionAccepted = 'revisionAccepted';
  static const revisionSubmitted = 'revisionSubmitted';
  static const revisionCompleted = 'revisionCompleted';
  static const evidenceAdded = 'evidenceAdded';
  static const adminComment = 'adminComment';
  static const statusChanged = 'statusChanged';
  static const decisionMade = 'decisionMade';
  static const settlementRecorded = 'settlementRecorded';
  static const caseClosed = 'caseClosed';
}

class ResolutionCaseModel {
  const ResolutionCaseModel({
    required this.caseId,
    required this.orderId,
    required this.serviceRequestId,
    required this.serviceId,
    required this.serviceTitle,
    required this.clientId,
    required this.clientName,
    required this.freelancerId,
    required this.freelancerName,
    required this.type,
    required this.status,
    required this.requestedBy,
    required this.requestedByRole,
    required this.openedBy,
    required this.openedByRole,
    required this.againstUserId,
    required this.againstRole,
    required this.relatedRefundCaseId,
    required this.relatedDisputeCaseId,
    required this.latestDeliveryId,
    required this.relatedDeliveryIds,
    required this.evidenceRequired,
    required this.clientEvidenceCount,
    required this.freelancerEvidenceCount,
    required this.adminEvidenceRequestedFrom,
    required this.evidenceRequestStatus,
    required this.clientEvidence,
    required this.freelancerEvidence,
    required this.lawId,
    required this.lawTitle,
    required this.aiRecommendationStatus,
    required this.aiSummary,
    required this.aiRecommendedAction,
    required this.adminFindings,
    required this.orderSnapshot,
    required this.assignedAdminId,
    required this.reason,
    required this.description,
    required this.clientNotes,
    required this.freelancerNotes,
    required this.adminNotes,
    required this.evidenceUrls,
    required this.resolutionDecision,
    required this.requestedRefundAmount,
    required this.releaseAmount,
    required this.refundAmount,
    required this.currency,
    required this.priority,
    required this.isFinancialSettlementRequired,
    required this.settlementStatus,
    required this.legacyDisputeId,
    required this.legacyRevisionId,
    required this.legacyRefundId,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.closedAt,
  });

  final String caseId;
  final String orderId;
  final String serviceRequestId;
  final String serviceId;
  final String serviceTitle;
  final String clientId;
  final String clientName;
  final String freelancerId;
  final String freelancerName;
  final String type;
  final String status;
  final String requestedBy;
  final String requestedByRole;
  final String openedBy;
  final String openedByRole;
  final String? againstUserId;
  final String? againstRole;
  final String? relatedRefundCaseId;
  final String? relatedDisputeCaseId;
  final String? latestDeliveryId;
  final List<String> relatedDeliveryIds;
  final bool evidenceRequired;
  final int clientEvidenceCount;
  final int freelancerEvidenceCount;
  final String? adminEvidenceRequestedFrom;
  final String evidenceRequestStatus;
  final List<Map<String, dynamic>> clientEvidence;
  final List<Map<String, dynamic>> freelancerEvidence;
  final String? lawId;
  final String? lawTitle;
  final String aiRecommendationStatus;
  final String aiSummary;
  final String aiRecommendedAction;
  final String adminFindings;
  final Map<String, dynamic> orderSnapshot;
  final String? assignedAdminId;
  final String reason;
  final String description;
  final String clientNotes;
  final String freelancerNotes;
  final String adminNotes;
  final List<String> evidenceUrls;
  final String resolutionDecision;
  final double requestedRefundAmount;
  final double releaseAmount;
  final double refundAmount;
  final String currency;
  final String priority;
  final bool isFinancialSettlementRequired;
  final String settlementStatus;
  final String? legacyDisputeId;
  final String? legacyRevisionId;
  final String? legacyRefundId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  bool get isOpen => !{
    ResolutionCaseStatus.resolved,
    ResolutionCaseStatus.rejected,
    ResolutionCaseStatus.cancelled,
  }.contains(status);

  factory ResolutionCaseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ResolutionCaseModel(
      caseId: _stringValue(data['caseId'], doc.id),
      orderId: _stringValue(data['orderId']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      serviceId: _stringValue(data['serviceId']),
      serviceTitle: _stringValue(data['serviceTitle'], 'Service Order'),
      clientId: _stringValue(data['clientId']),
      clientName: _stringValue(data['clientName'], 'Client'),
      freelancerId: _stringValue(data['freelancerId']),
      freelancerName: _stringValue(data['freelancerName'], 'Freelancer'),
      type: ResolutionCaseType.normalize(data['type']?.toString()),
      status: ResolutionCaseStatus.normalize(data['status']?.toString()),
      requestedBy: _stringValue(data['requestedBy']),
      requestedByRole: _stringValue(data['requestedByRole']),
      openedBy: _stringValue(
        data['openedBy'],
        _stringValue(data['requestedBy']),
      ),
      openedByRole: _stringValue(
        data['openedByRole'],
        _stringValue(data['requestedByRole']),
      ),
      againstUserId: data['againstUserId'] is String
          ? data['againstUserId'] as String
          : null,
      againstRole: data['againstRole'] is String
          ? data['againstRole'] as String
          : null,
      relatedRefundCaseId: data['relatedRefundCaseId'] is String
          ? data['relatedRefundCaseId'] as String
          : null,
      relatedDisputeCaseId: data['relatedDisputeCaseId'] is String
          ? data['relatedDisputeCaseId'] as String
          : null,
      latestDeliveryId: data['latestDeliveryId'] is String
          ? data['latestDeliveryId'] as String
          : null,
      relatedDeliveryIds: _stringList(data['relatedDeliveryIds']),
      evidenceRequired: data['evidenceRequired'] == true,
      clientEvidenceCount: _intValue(data['clientEvidenceCount']),
      freelancerEvidenceCount: _intValue(data['freelancerEvidenceCount']),
      adminEvidenceRequestedFrom: data['adminEvidenceRequestedFrom'] is String
          ? data['adminEvidenceRequestedFrom'] as String
          : null,
      evidenceRequestStatus: _stringValue(
        data['evidenceRequestStatus'],
        ResolutionEvidenceRequestStatus.none,
      ),
      clientEvidence: _mapList(data['clientEvidence']),
      freelancerEvidence: _mapList(data['freelancerEvidence']),
      lawId: data['lawId'] is String ? data['lawId'] as String : null,
      lawTitle: data['lawTitle'] is String ? data['lawTitle'] as String : null,
      aiRecommendationStatus: _stringValue(
        data['aiRecommendationStatus'],
        ResolutionAiRecommendationStatus.notGenerated,
      ),
      aiSummary: _stringValue(data['aiSummary']),
      aiRecommendedAction: _stringValue(data['aiRecommendedAction']),
      adminFindings: _stringValue(data['adminFindings']),
      orderSnapshot: data['orderSnapshot'] is Map
          ? Map<String, dynamic>.from(data['orderSnapshot'] as Map)
          : const <String, dynamic>{},
      assignedAdminId: data['assignedAdminId'] is String
          ? data['assignedAdminId'] as String
          : null,
      reason: _stringValue(data['reason']),
      description: _stringValue(data['description']),
      clientNotes: _stringValue(data['clientNotes']),
      freelancerNotes: _stringValue(data['freelancerNotes']),
      adminNotes: _stringValue(data['adminNotes']),
      evidenceUrls: _stringList(data['evidenceUrls']),
      resolutionDecision: _stringValue(
        data['resolutionDecision'],
        ResolutionDecision.none,
      ),
      requestedRefundAmount: _doubleValue(data['requestedRefundAmount']),
      releaseAmount: _doubleValue(data['releaseAmount']),
      refundAmount: _doubleValue(data['refundAmount']),
      currency: _stringValue(data['currency'], 'USD'),
      priority: _stringValue(data['priority'], ResolutionPriority.normal),
      isFinancialSettlementRequired:
          data['isFinancialSettlementRequired'] == true,
      settlementStatus: _stringValue(
        data['settlementStatus'],
        ResolutionSettlementStatus.none,
      ),
      legacyDisputeId: data['legacyDisputeId'] is String
          ? data['legacyDisputeId'] as String
          : null,
      legacyRevisionId: data['legacyRevisionId'] is String
          ? data['legacyRevisionId'] as String
          : null,
      legacyRefundId: data['legacyRefundId'] is String
          ? data['legacyRefundId'] as String
          : null,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      resolvedAt: _nullableDate(data['resolvedAt']),
      closedAt: _nullableDate(data['closedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caseId': caseId,
      'orderId': orderId,
      'serviceRequestId': serviceRequestId,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'clientId': clientId,
      'clientName': clientName,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'type': type,
      'status': status,
      'requestedBy': requestedBy,
      'requestedByRole': requestedByRole,
      'openedBy': openedBy,
      'openedByRole': openedByRole,
      if ((againstUserId ?? '').trim().isNotEmpty)
        'againstUserId': againstUserId,
      if ((againstRole ?? '').trim().isNotEmpty) 'againstRole': againstRole,
      if ((relatedRefundCaseId ?? '').trim().isNotEmpty)
        'relatedRefundCaseId': relatedRefundCaseId,
      if ((relatedDisputeCaseId ?? '').trim().isNotEmpty)
        'relatedDisputeCaseId': relatedDisputeCaseId,
      if ((latestDeliveryId ?? '').trim().isNotEmpty)
        'latestDeliveryId': latestDeliveryId,
      'relatedDeliveryIds': relatedDeliveryIds,
      'evidenceRequired': evidenceRequired,
      'clientEvidenceCount': clientEvidenceCount,
      'freelancerEvidenceCount': freelancerEvidenceCount,
      if ((adminEvidenceRequestedFrom ?? '').trim().isNotEmpty)
        'adminEvidenceRequestedFrom': adminEvidenceRequestedFrom,
      'evidenceRequestStatus': evidenceRequestStatus,
      'clientEvidence': clientEvidence,
      'freelancerEvidence': freelancerEvidence,
      if ((lawId ?? '').trim().isNotEmpty) 'lawId': lawId,
      if ((lawTitle ?? '').trim().isNotEmpty) 'lawTitle': lawTitle,
      'aiRecommendationStatus': aiRecommendationStatus,
      'aiSummary': aiSummary,
      'aiRecommendedAction': aiRecommendedAction,
      'adminFindings': adminFindings,
      'orderSnapshot': orderSnapshot,
      if ((assignedAdminId ?? '').trim().isNotEmpty)
        'assignedAdminId': assignedAdminId,
      'reason': reason,
      'description': description,
      'clientNotes': clientNotes,
      'freelancerNotes': freelancerNotes,
      'adminNotes': adminNotes,
      'evidenceUrls': evidenceUrls,
      'resolutionDecision': resolutionDecision,
      'requestedRefundAmount': requestedRefundAmount,
      'releaseAmount': releaseAmount,
      'refundAmount': refundAmount,
      'currency': currency,
      'priority': priority,
      'isFinancialSettlementRequired': isFinancialSettlementRequired,
      'settlementStatus': settlementStatus,
      if ((legacyDisputeId ?? '').trim().isNotEmpty)
        'legacyDisputeId': legacyDisputeId,
      if ((legacyRevisionId ?? '').trim().isNotEmpty)
        'legacyRevisionId': legacyRevisionId,
      if ((legacyRefundId ?? '').trim().isNotEmpty)
        'legacyRefundId': legacyRefundId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
    };
  }
}

class ResolutionCaseEventModel {
  const ResolutionCaseEventModel({
    required this.eventId,
    required this.caseId,
    required this.actorId,
    required this.actorRole,
    required this.eventType,
    required this.message,
    required this.metadata,
    required this.createdAt,
  });

  final String eventId;
  final String caseId;
  final String actorId;
  final String actorRole;
  final String eventType;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory ResolutionCaseEventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ResolutionCaseEventModel(
      eventId: _stringValue(data['eventId'], doc.id),
      caseId: _stringValue(data['caseId']),
      actorId: _stringValue(data['actorId']),
      actorRole: _stringValue(data['actorRole']),
      eventType: _stringValue(data['eventType']),
      message: _stringValue(data['message']),
      metadata: _mapValue(data['metadata']),
      createdAt: _dateValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'caseId': caseId,
      'actorId': actorId,
      'actorRole': actorRole,
      'eventType': eventType,
      'message': message,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ResolutionCaseEvidenceModel {
  const ResolutionCaseEvidenceModel({
    required this.evidenceId,
    required this.caseId,
    required this.actorId,
    required this.actorRole,
    required this.title,
    required this.description,
    required this.attachments,
    required this.relatedDeliveryId,
    required this.createdAt,
  });

  final String evidenceId;
  final String caseId;
  final String actorId;
  final String actorRole;
  final String title;
  final String description;
  final List<Map<String, dynamic>> attachments;
  final String? relatedDeliveryId;
  final DateTime createdAt;

  factory ResolutionCaseEvidenceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ResolutionCaseEvidenceModel(
      evidenceId: _stringValue(data['evidenceId'], doc.id),
      caseId: _stringValue(data['caseId']),
      actorId: _stringValue(data['actorId']),
      actorRole: _stringValue(data['actorRole']),
      title: _stringValue(data['title'], 'Evidence'),
      description: _stringValue(data['description']),
      attachments: _mapList(data['attachments']),
      relatedDeliveryId: data['relatedDeliveryId'] is String
          ? data['relatedDeliveryId'] as String
          : null,
      createdAt: _dateValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'evidenceId': evidenceId,
      'caseId': caseId,
      'actorId': actorId,
      'actorRole': actorRole,
      'title': title,
      'description': description,
      'attachments': attachments,
      if ((relatedDeliveryId ?? '').trim().isNotEmpty)
        'relatedDeliveryId': relatedDeliveryId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
