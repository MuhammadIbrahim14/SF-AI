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

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.trim().toLowerCase() == 'true';
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

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

class SandboxCommerceConfig {
  const SandboxCommerceConfig._();

  static const double platformCommissionPercent = 0.10;
  static const int escrowHoldingDays = 5;
}

class ServiceOrderPaymentStatus {
  const ServiceOrderPaymentStatus._();

  static const unpaid = 'unpaid';
  static const demoPaid = 'demoPaid';
  static const paid = 'paid';
  static const held = 'held';
  static const released = 'released';
  static const refunded = 'refunded';
  static const partiallyRefunded = 'partiallyRefunded';

  static const values = {
    unpaid,
    demoPaid,
    paid,
    held,
    released,
    refunded,
    partiallyRefunded,
  };

  static bool isFunded(String? status) =>
      status == demoPaid || status == paid || status == held;

  static String normalize(String? value) {
    final normalized = (value ?? unpaid).trim();
    return values.contains(normalized) ? normalized : unpaid;
  }
}

class ServiceOrderEscrowStatus {
  const ServiceOrderEscrowStatus._();

  static const notFunded = 'notFunded';
  static const none = 'none';
  static const held = 'held';
  static const released = 'released';
  static const refunded = 'refunded';
  static const split = 'split';
  static const disputed = 'disputed';

  static const values = {
    notFunded,
    none,
    held,
    released,
    refunded,
    split,
    disputed,
  };

  static String normalize(String? value) {
    final normalized = (value ?? notFunded).trim();
    if (normalized == none) return notFunded;
    return values.contains(normalized) ? normalized : notFunded;
  }
}

class ServiceOrderStatus {
  const ServiceOrderStatus._();

  static const pending = 'pending';
  static const requested = 'requested';
  static const accepted = 'accepted';
  static const active = 'active';
  static const inProgress = 'inProgress';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const disputed = 'disputed';
  static const splitSettled = 'splitSettled';

  static const values = {
    pending,
    requested,
    accepted,
    active,
    inProgress,
    delivered,
    completed,
    cancelled,
    disputed,
    splitSettled,
  };

  static String normalize(String? value) {
    final normalized = (value ?? pending).trim();
    if (normalized == requested) return pending;
    if (normalized == accepted) return active;
    return values.contains(normalized) ? normalized : pending;
  }
}

class ServiceOrderDeliveryStatus {
  const ServiceOrderDeliveryStatus._();

  static const none = 'none';
  static const pending = 'pending';
  static const submitted = 'submitted';
  static const revisionRequested = 'revisionRequested';
  static const revisionSubmitted = 'revisionSubmitted';
  static const accepted = 'accepted';
  static const disputed = 'disputed';

  static const values = {
    none,
    pending,
    submitted,
    revisionRequested,
    revisionSubmitted,
    accepted,
    disputed,
  };

  static String normalize(String? value) {
    final normalized = (value ?? none).trim();
    return values.contains(normalized) ? normalized : none;
  }
}

class ServiceOrderModel {
  const ServiceOrderModel({
    required this.orderId,
    required this.orderNumber,
    required this.serviceRequestId,
    required this.serviceId,
    required this.serviceTitle,
    required this.serviceCategory,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.freelancerId,
    required this.freelancerName,
    required this.subtotal,
    required this.platformFee,
    required this.taxTotal,
    required this.taxBreakdown,
    required this.totalAmount,
    required this.freelancerEarnings,
    required this.currency,
    required this.selectedPackageId,
    required this.selectedPackageTitle,
    required this.selectedPackagePrice,
    required this.selectedDeliveryDays,
    required this.selectedRevisionsIncluded,
    required this.paymentStatus,
    required this.escrowStatus,
    required this.orderStatus,
    required this.deliveryStatus,
    required this.revisionCount,
    required this.revisionLimit,
    required this.revisionStatus,
    required this.revisionNotes,
    required this.isMilestoneBased,
    required this.milestoneIds,
    required this.createdAt,
    required this.updatedAt,
    required this.acceptedAt,
    required this.workStartedAt,
    required this.dueDate,
    required this.paidAt,
    required this.escrowHeldAt,
    required this.expectedReleaseAt,
    required this.escrowReleasedAt,
    required this.fundsClearedAt,
    required this.sandboxPaymentMethod,
    required this.transactionReference,
    required this.lastDeliveryId,
    required this.deliveredAt,
    required this.reviewDueAt,
    required this.completedAt,
    required this.cancelledAt,
  });

  final String orderId;
  final String orderNumber;
  final String serviceRequestId;
  final String serviceId;
  final String serviceTitle;
  final String serviceCategory;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String freelancerId;
  final String freelancerName;
  final double subtotal;
  final double platformFee;
  final double taxTotal;
  final List<Map<String, dynamic>> taxBreakdown;
  final double totalAmount;
  final double freelancerEarnings;
  final String currency;
  final String? selectedPackageId;
  final String? selectedPackageTitle;
  final double selectedPackagePrice;
  final int selectedDeliveryDays;
  final int selectedRevisionsIncluded;
  final String paymentStatus;
  final String escrowStatus;
  final String orderStatus;
  final String deliveryStatus;
  final int revisionCount;
  final int revisionLimit;
  final String? revisionStatus;
  final String? revisionNotes;
  final bool isMilestoneBased;
  final List<String> milestoneIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? workStartedAt;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final DateTime? escrowHeldAt;
  final DateTime? expectedReleaseAt;
  final DateTime? escrowReleasedAt;
  final DateTime? fundsClearedAt;
  final String? sandboxPaymentMethod;
  final String? transactionReference;
  final String? lastDeliveryId;
  final DateTime? deliveredAt;
  final DateTime? reviewDueAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  bool get canCancel =>
      paymentStatus == ServiceOrderPaymentStatus.unpaid &&
      orderStatus == ServiceOrderStatus.pending;

  factory ServiceOrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ServiceOrderModel(
      orderId: _stringValue(data['orderId'], doc.id),
      orderNumber: _stringValue(data['orderNumber']),
      serviceRequestId: _stringValue(data['serviceRequestId']),
      serviceId: _stringValue(data['serviceId']),
      serviceTitle: _stringValue(data['serviceTitle']),
      serviceCategory: _stringValue(data['serviceCategory']),
      clientId: _stringValue(data['clientId']),
      clientName: _stringValue(data['clientName']),
      clientEmail: _stringValue(data['clientEmail']),
      freelancerId: _stringValue(data['freelancerId']),
      freelancerName: _stringValue(data['freelancerName']),
      subtotal: _doubleValue(data['subtotal']),
      platformFee: _doubleValue(data['platformFee']),
      taxTotal: _doubleValue(data['taxTotal']),
      taxBreakdown: _mapList(data['taxBreakdown']),
      totalAmount: _doubleValue(data['totalAmount']),
      freelancerEarnings: _doubleValue(data['freelancerEarnings']),
      currency: _stringValue(data['currency'], 'USD'),
      selectedPackageId: data['selectedPackageId'] is String
          ? data['selectedPackageId'] as String
          : null,
      selectedPackageTitle: data['selectedPackageTitle'] is String
          ? data['selectedPackageTitle'] as String
          : null,
      selectedPackagePrice: _doubleValue(data['selectedPackagePrice']),
      selectedDeliveryDays: _intValue(data['selectedDeliveryDays']),
      selectedRevisionsIncluded: _intValue(data['selectedRevisionsIncluded']),
      paymentStatus: ServiceOrderPaymentStatus.normalize(
        data['paymentStatus']?.toString(),
      ),
      escrowStatus: ServiceOrderEscrowStatus.normalize(
        data['escrowStatus']?.toString(),
      ),
      orderStatus: ServiceOrderStatus.normalize(
        data['orderStatus']?.toString(),
      ),
      deliveryStatus: ServiceOrderDeliveryStatus.normalize(
        data['deliveryStatus']?.toString(),
      ),
      revisionCount: _intValue(data['revisionCount']),
      revisionLimit: _intValue(data['revisionLimit'], 2),
      revisionStatus: data['revisionStatus'] is String
          ? data['revisionStatus'] as String
          : null,
      revisionNotes: data['revisionNotes'] is String
          ? data['revisionNotes'] as String
          : null,
      isMilestoneBased: _boolValue(data['isMilestoneBased']),
      milestoneIds: _stringList(data['milestoneIds']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      acceptedAt: _nullableDate(data['acceptedAt']),
      workStartedAt: _nullableDate(data['workStartedAt']),
      dueDate: _nullableDate(data['dueDate']),
      paidAt: _nullableDate(data['paidAt']),
      escrowHeldAt: _nullableDate(data['escrowHeldAt']),
      expectedReleaseAt: _nullableDate(data['expectedReleaseAt']),
      escrowReleasedAt: _nullableDate(data['escrowReleasedAt']),
      fundsClearedAt: _nullableDate(data['fundsClearedAt']),
      sandboxPaymentMethod: data['sandboxPaymentMethod'] is String
          ? data['sandboxPaymentMethod'] as String
          : null,
      transactionReference: data['transactionReference'] is String
          ? data['transactionReference'] as String
          : null,
      lastDeliveryId: data['lastDeliveryId'] is String
          ? data['lastDeliveryId'] as String
          : null,
      deliveredAt: _nullableDate(data['deliveredAt']),
      reviewDueAt: _nullableDate(data['reviewDueAt']),
      completedAt: _nullableDate(data['completedAt']),
      cancelledAt: _nullableDate(data['cancelledAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'serviceRequestId': serviceRequestId,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'serviceCategory': serviceCategory,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'subtotal': subtotal,
      'platformFee': platformFee,
      'taxTotal': taxTotal,
      'taxBreakdown': taxBreakdown,
      'totalAmount': totalAmount,
      'freelancerEarnings': freelancerEarnings,
      'currency': currency,
      if ((selectedPackageId ?? '').trim().isNotEmpty)
        'selectedPackageId': selectedPackageId,
      if ((selectedPackageTitle ?? '').trim().isNotEmpty)
        'selectedPackageTitle': selectedPackageTitle,
      if (selectedPackagePrice > 0)
        'selectedPackagePrice': selectedPackagePrice,
      if (selectedDeliveryDays > 0)
        'selectedDeliveryDays': selectedDeliveryDays,
      if (selectedRevisionsIncluded >= 0)
        'selectedRevisionsIncluded': selectedRevisionsIncluded,
      'paymentStatus': ServiceOrderPaymentStatus.normalize(paymentStatus),
      'escrowStatus': ServiceOrderEscrowStatus.normalize(escrowStatus),
      'orderStatus': ServiceOrderStatus.normalize(orderStatus),
      'deliveryStatus': ServiceOrderDeliveryStatus.normalize(deliveryStatus),
      'revisionCount': revisionCount,
      'revisionLimit': revisionLimit,
      if ((revisionStatus ?? '').trim().isNotEmpty)
        'revisionStatus': revisionStatus,
      if ((revisionNotes ?? '').trim().isNotEmpty)
        'revisionNotes': revisionNotes,
      'isMilestoneBased': isMilestoneBased,
      'milestoneIds': milestoneIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (workStartedAt != null)
        'workStartedAt': Timestamp.fromDate(workStartedAt!),
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      if (escrowHeldAt != null)
        'escrowHeldAt': Timestamp.fromDate(escrowHeldAt!),
      if (expectedReleaseAt != null)
        'expectedReleaseAt': Timestamp.fromDate(expectedReleaseAt!),
      if (escrowReleasedAt != null)
        'escrowReleasedAt': Timestamp.fromDate(escrowReleasedAt!),
      if (fundsClearedAt != null)
        'fundsClearedAt': Timestamp.fromDate(fundsClearedAt!),
      if ((sandboxPaymentMethod ?? '').trim().isNotEmpty)
        'sandboxPaymentMethod': sandboxPaymentMethod,
      if ((transactionReference ?? '').trim().isNotEmpty)
        'transactionReference': transactionReference,
      if ((lastDeliveryId ?? '').trim().isNotEmpty)
        'lastDeliveryId': lastDeliveryId,
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (reviewDueAt != null) 'reviewDueAt': Timestamp.fromDate(reviewDueAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
    };
  }

  ServiceOrderModel copyWith({
    String? orderId,
    String? orderNumber,
    String? serviceRequestId,
    String? serviceId,
    String? serviceTitle,
    String? serviceCategory,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? freelancerId,
    String? freelancerName,
    double? subtotal,
    double? platformFee,
    double? taxTotal,
    List<Map<String, dynamic>>? taxBreakdown,
    double? totalAmount,
    double? freelancerEarnings,
    String? currency,
    String? selectedPackageId,
    String? selectedPackageTitle,
    double? selectedPackagePrice,
    int? selectedDeliveryDays,
    int? selectedRevisionsIncluded,
    String? paymentStatus,
    String? escrowStatus,
    String? orderStatus,
    String? deliveryStatus,
    int? revisionCount,
    int? revisionLimit,
    String? revisionStatus,
    String? revisionNotes,
    bool? isMilestoneBased,
    List<String>? milestoneIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? workStartedAt,
    DateTime? dueDate,
    DateTime? paidAt,
    DateTime? escrowHeldAt,
    DateTime? expectedReleaseAt,
    DateTime? escrowReleasedAt,
    DateTime? fundsClearedAt,
    String? sandboxPaymentMethod,
    String? transactionReference,
    String? lastDeliveryId,
    DateTime? deliveredAt,
    DateTime? reviewDueAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) {
    return ServiceOrderModel(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      subtotal: subtotal ?? this.subtotal,
      platformFee: platformFee ?? this.platformFee,
      taxTotal: taxTotal ?? this.taxTotal,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      totalAmount: totalAmount ?? this.totalAmount,
      freelancerEarnings: freelancerEarnings ?? this.freelancerEarnings,
      currency: currency ?? this.currency,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      selectedPackageTitle: selectedPackageTitle ?? this.selectedPackageTitle,
      selectedPackagePrice: selectedPackagePrice ?? this.selectedPackagePrice,
      selectedDeliveryDays: selectedDeliveryDays ?? this.selectedDeliveryDays,
      selectedRevisionsIncluded:
          selectedRevisionsIncluded ?? this.selectedRevisionsIncluded,
      paymentStatus: ServiceOrderPaymentStatus.normalize(
        paymentStatus ?? this.paymentStatus,
      ),
      escrowStatus: ServiceOrderEscrowStatus.normalize(
        escrowStatus ?? this.escrowStatus,
      ),
      orderStatus: ServiceOrderStatus.normalize(
        orderStatus ?? this.orderStatus,
      ),
      deliveryStatus: ServiceOrderDeliveryStatus.normalize(
        deliveryStatus ?? this.deliveryStatus,
      ),
      revisionCount: revisionCount ?? this.revisionCount,
      revisionLimit: revisionLimit ?? this.revisionLimit,
      revisionStatus: revisionStatus ?? this.revisionStatus,
      revisionNotes: revisionNotes ?? this.revisionNotes,
      isMilestoneBased: isMilestoneBased ?? this.isMilestoneBased,
      milestoneIds: milestoneIds ?? this.milestoneIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      workStartedAt: workStartedAt ?? this.workStartedAt,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      escrowHeldAt: escrowHeldAt ?? this.escrowHeldAt,
      expectedReleaseAt: expectedReleaseAt ?? this.expectedReleaseAt,
      escrowReleasedAt: escrowReleasedAt ?? this.escrowReleasedAt,
      fundsClearedAt: fundsClearedAt ?? this.fundsClearedAt,
      sandboxPaymentMethod: sandboxPaymentMethod ?? this.sandboxPaymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      lastDeliveryId: lastDeliveryId ?? this.lastDeliveryId,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      reviewDueAt: reviewDueAt ?? this.reviewDueAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
