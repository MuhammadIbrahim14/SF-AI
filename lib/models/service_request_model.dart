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
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

class ServiceRequestStatus {
  const ServiceRequestStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String inProgress = 'inProgress';
  static const String delivered = 'delivered';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const Set<String> values = {
    pending,
    accepted,
    rejected,
    inProgress,
    delivered,
    completed,
    cancelled,
  };

  static String normalize(String? value) {
    final normalized = (value ?? pending).trim();
    return values.contains(normalized) ? normalized : pending;
  }
}

class ServiceRequestPriority {
  const ServiceRequestPriority._();

  static const String low = 'low';
  static const String normal = 'normal';
  static const String high = 'high';

  static const Set<String> values = {low, normal, high};

  static String normalize(String? value) {
    final normalized = (value ?? normal).trim().toLowerCase();
    return values.contains(normalized) ? normalized : normal;
  }
}

class ServiceRequestModel {
  const ServiceRequestModel({
    required this.requestId,
    required this.serviceId,
    required this.serviceTitle,
    required this.serviceCategory,
    required this.freelancerId,
    required this.freelancerName,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.clientRole,
    required this.clientAvatarUrl,
    required this.projectTitle,
    required this.requirements,
    required this.budget,
    required this.currency,
    required this.selectedPackageId,
    required this.selectedPackageTitle,
    required this.selectedPackagePrice,
    required this.selectedDeliveryDays,
    required this.selectedRevisionsIncluded,
    required this.deadline,
    required this.attachments,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.acceptedAt,
    required this.deliveredAt,
    required this.completedAt,
    required this.cancelledAt,
    required this.freelancerNote,
    required this.clientNote,
  });

  final String requestId;
  final String serviceId;
  final String serviceTitle;
  final String serviceCategory;
  final String freelancerId;
  final String freelancerName;
  final String? clientId;
  final String clientName;
  final String clientEmail;
  final String? clientRole;
  final String? clientAvatarUrl;
  final String projectTitle;
  final String requirements;
  final double budget;
  final String currency;
  final String? selectedPackageId;
  final String? selectedPackageTitle;
  final double selectedPackagePrice;
  final int selectedDeliveryDays;
  final int selectedRevisionsIncluded;
  final DateTime? deadline;
  final List<String> attachments;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? freelancerNote;
  final String? clientNote;

  bool get canClientCancel => status == ServiceRequestStatus.pending;
  bool get canClientComplete => status == ServiceRequestStatus.delivered;
  bool get isActive =>
      status == ServiceRequestStatus.accepted ||
      status == ServiceRequestStatus.inProgress;
  bool get isTerminal =>
      status == ServiceRequestStatus.rejected ||
      status == ServiceRequestStatus.completed ||
      status == ServiceRequestStatus.cancelled;

  factory ServiceRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ServiceRequestModel(
      requestId: _stringValue(data['requestId'], doc.id),
      serviceId: _stringValue(data['serviceId']),
      serviceTitle: _stringValue(data['serviceTitle']),
      serviceCategory: _stringValue(data['serviceCategory']),
      freelancerId: _stringValue(data['freelancerId']),
      freelancerName: _stringValue(data['freelancerName']),
      clientId: data['clientId'] is String ? data['clientId'] as String : null,
      clientName: _stringValue(data['clientName']),
      clientEmail: _stringValue(data['clientEmail']),
      clientRole: data['clientRole'] is String
          ? data['clientRole'] as String
          : null,
      clientAvatarUrl: data['clientAvatarUrl'] is String
          ? data['clientAvatarUrl'] as String
          : null,
      projectTitle: _stringValue(data['projectTitle']),
      requirements: _stringValue(data['requirements']),
      budget: _doubleValue(data['budget']),
      currency: _stringValue(data['currency'], 'USD'),
      selectedPackageId: data['selectedPackageId'] is String
          ? data['selectedPackageId'] as String
          : null,
      selectedPackageTitle: data['selectedPackageTitle'] is String
          ? data['selectedPackageTitle'] as String
          : null,
      selectedPackagePrice: _doubleValue(data['selectedPackagePrice']),
      selectedDeliveryDays: _intValue(data['selectedDeliveryDays'], 0),
      selectedRevisionsIncluded: _intValue(
        data['selectedRevisionsIncluded'],
        0,
      ),
      deadline: _nullableDate(data['deadline']),
      attachments: _stringList(data['attachments']),
      priority: ServiceRequestPriority.normalize(data['priority']?.toString()),
      status: ServiceRequestStatus.normalize(data['status']?.toString()),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      acceptedAt: _nullableDate(data['acceptedAt']),
      deliveredAt: _nullableDate(data['deliveredAt']),
      completedAt: _nullableDate(data['completedAt']),
      cancelledAt: _nullableDate(data['cancelledAt']),
      freelancerNote: data['freelancerNote'] is String
          ? data['freelancerNote'] as String
          : null,
      clientNote: data['clientNote'] is String
          ? data['clientNote'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'serviceCategory': serviceCategory,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientRole': clientRole,
      'clientAvatarUrl': clientAvatarUrl,
      'projectTitle': projectTitle,
      'requirements': requirements,
      'budget': budget,
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
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      'attachments': attachments,
      'priority': ServiceRequestPriority.normalize(priority),
      'status': ServiceRequestStatus.normalize(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if ((freelancerNote ?? '').trim().isNotEmpty)
        'freelancerNote': freelancerNote,
      if ((clientNote ?? '').trim().isNotEmpty) 'clientNote': clientNote,
    };
  }

  ServiceRequestModel copyWith({
    String? requestId,
    String? serviceId,
    String? serviceTitle,
    String? serviceCategory,
    String? freelancerId,
    String? freelancerName,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? clientRole,
    String? clientAvatarUrl,
    String? projectTitle,
    String? requirements,
    double? budget,
    String? currency,
    String? selectedPackageId,
    String? selectedPackageTitle,
    double? selectedPackagePrice,
    int? selectedDeliveryDays,
    int? selectedRevisionsIncluded,
    DateTime? deadline,
    bool clearDeadline = false,
    List<String>? attachments,
    String? priority,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? deliveredAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? freelancerNote,
    String? clientNote,
  }) {
    return ServiceRequestModel(
      requestId: requestId ?? this.requestId,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientRole: clientRole ?? this.clientRole,
      clientAvatarUrl: clientAvatarUrl ?? this.clientAvatarUrl,
      projectTitle: projectTitle ?? this.projectTitle,
      requirements: requirements ?? this.requirements,
      budget: budget ?? this.budget,
      currency: currency ?? this.currency,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      selectedPackageTitle: selectedPackageTitle ?? this.selectedPackageTitle,
      selectedPackagePrice: selectedPackagePrice ?? this.selectedPackagePrice,
      selectedDeliveryDays: selectedDeliveryDays ?? this.selectedDeliveryDays,
      selectedRevisionsIncluded:
          selectedRevisionsIncluded ?? this.selectedRevisionsIncluded,
      deadline: clearDeadline ? null : deadline ?? this.deadline,
      attachments: attachments ?? this.attachments,
      priority: ServiceRequestPriority.normalize(priority ?? this.priority),
      status: ServiceRequestStatus.normalize(status ?? this.status),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      freelancerNote: freelancerNote ?? this.freelancerNote,
      clientNote: clientNote ?? this.clientNote,
    );
  }
}
