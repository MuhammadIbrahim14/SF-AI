import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_order_model.dart';

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

List<Map<String, dynamic>> _attachmentList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

class ServiceOrderDeliveryModel {
  const ServiceOrderDeliveryModel({
    required this.deliveryId,
    required this.orderId,
    required this.clientId,
    required this.freelancerId,
    required this.message,
    required this.attachments,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
  });

  final String deliveryId;
  final String orderId;
  final String clientId;
  final String freelancerId;
  final String message;
  final List<Map<String, dynamic>> attachments;
  final String status;
  final DateTime submittedAt;
  final DateTime updatedAt;

  factory ServiceOrderDeliveryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ServiceOrderDeliveryModel(
      deliveryId: _stringValue(data['deliveryId'], doc.id),
      orderId: _stringValue(data['orderId']),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      message: _stringValue(data['message']),
      attachments: _attachmentList(data['attachments']),
      status: ServiceOrderDeliveryStatus.normalize(data['status']?.toString()),
      submittedAt: _dateValue(data['submittedAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deliveryId': deliveryId,
      'orderId': orderId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'message': message,
      'attachments': attachments,
      'status': ServiceOrderDeliveryStatus.normalize(status),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

Map<String, dynamic> deliveryAttachmentFromUrl(
  String url,
  DateTime uploadedAt,
) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  final rawName = uri == null || uri.pathSegments.isEmpty
      ? 'delivery-link'
      : uri.pathSegments.last;
  final fileName = rawName.trim().isEmpty ? 'delivery-link' : rawName;
  final extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  final resourceType = switch (extension) {
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => 'image',
    'mp4' || 'mov' || 'webm' => 'video',
    _ => 'raw',
  };
  return {
    'url': trimmed,
    'publicId': '',
    'fileName': fileName,
    'fileType': extension,
    'mimeType': '',
    'fileSize': 0,
    'resourceType': resourceType,
    'uploadedAt': Timestamp.fromDate(uploadedAt),
  };
}

int deliveryAttachmentFileSize(Map<String, dynamic> attachment) {
  return _intValue(attachment['fileSize']);
}
