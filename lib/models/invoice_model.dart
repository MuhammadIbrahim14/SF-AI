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

class InvoiceType {
  const InvoiceType._();

  static const clientReceipt = 'clientReceipt';
  static const freelancerInvoice = 'freelancerInvoice';
  static const platformCommissionInvoice = 'platformCommissionInvoice';

  static const values = {
    clientReceipt,
    freelancerInvoice,
    platformCommissionInvoice,
  };

  static String normalize(String? value) {
    final normalized = (value ?? clientReceipt).trim();
    return values.contains(normalized) ? normalized : clientReceipt;
  }

  static String label(String type) {
    return switch (normalize(type)) {
      freelancerInvoice => 'Freelancer Invoice',
      platformCommissionInvoice => 'Platform Commission Invoice',
      _ => 'Client Receipt',
    };
  }
}

class InvoiceStatus {
  const InvoiceStatus._();

  static const issued = 'issued';
  static const paid = 'paid';

  static const values = {issued, paid};

  static String normalize(String? value) {
    final normalized = (value ?? issued).trim();
    return values.contains(normalized) ? normalized : issued;
  }
}

class InvoiceModel {
  const InvoiceModel({
    required this.invoiceId,
    required this.orderId,
    required this.clientId,
    required this.freelancerId,
    required this.invoiceNumber,
    required this.type,
    required this.status,
    required this.currency,
    required this.subtotal,
    required this.platformFee,
    required this.taxAmount,
    required this.totalAmount,
    required this.issuedAt,
    required this.dueAt,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
    required this.platformName,
    required this.platformEmail,
    required this.platformWebsite,
    required this.clientName,
    required this.clientEmail,
    required this.freelancerName,
    required this.freelancerEmail,
    required this.serviceTitle,
    required this.serviceDescription,
    required this.verificationCode,
    this.pdfStoragePath,
    this.pdfDownloadUrl,
  });

  final String invoiceId;
  final String orderId;
  final String clientId;
  final String freelancerId;
  final String invoiceNumber;
  final String type;
  final String status;
  final String currency;
  final double subtotal;
  final double platformFee;
  final double taxAmount;
  final double totalAmount;
  final DateTime issuedAt;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String platformName;
  final String platformEmail;
  final String platformWebsite;
  final String clientName;
  final String clientEmail;
  final String freelancerName;
  final String freelancerEmail;
  final String serviceTitle;
  final String serviceDescription;
  final String verificationCode;
  final String? pdfStoragePath;
  final String? pdfDownloadUrl;

  bool get isClientReceipt => type == InvoiceType.clientReceipt;
  bool get isFreelancerInvoice => type == InvoiceType.freelancerInvoice;
  bool get isPlatformInvoice => type == InvoiceType.platformCommissionInvoice;

  factory InvoiceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InvoiceModel(
      invoiceId: _stringValue(data['invoiceId'], doc.id),
      orderId: _stringValue(data['orderId']),
      clientId: _stringValue(data['clientId']),
      freelancerId: _stringValue(data['freelancerId']),
      invoiceNumber: _stringValue(data['invoiceNumber']),
      type: InvoiceType.normalize(data['type']?.toString()),
      status: InvoiceStatus.normalize(data['status']?.toString()),
      currency: _stringValue(data['currency'], 'USD'),
      subtotal: _doubleValue(data['subtotal']),
      platformFee: _doubleValue(data['platformFee']),
      taxAmount: _doubleValue(data['taxAmount']),
      totalAmount: _doubleValue(data['totalAmount']),
      issuedAt: _dateValue(data['issuedAt']),
      dueAt: _nullableDate(data['dueAt']),
      paidAt: _nullableDate(data['paidAt']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      platformName: _stringValue(data['platformName'], 'SkillForge AI'),
      platformEmail: _stringValue(data['platformEmail']),
      platformWebsite: _stringValue(data['platformWebsite']),
      clientName: _stringValue(data['clientName']),
      clientEmail: _stringValue(data['clientEmail']),
      freelancerName: _stringValue(data['freelancerName']),
      freelancerEmail: _stringValue(data['freelancerEmail']),
      serviceTitle: _stringValue(data['serviceTitle']),
      serviceDescription: _stringValue(data['serviceDescription']),
      verificationCode: _stringValue(data['verificationCode']),
      pdfStoragePath: data['pdfStoragePath'] is String
          ? data['pdfStoragePath'] as String
          : null,
      pdfDownloadUrl: data['pdfDownloadUrl'] is String
          ? data['pdfDownloadUrl'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoiceId': invoiceId,
      'orderId': orderId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'invoiceNumber': invoiceNumber,
      'type': InvoiceType.normalize(type),
      'status': InvoiceStatus.normalize(status),
      'currency': currency,
      'subtotal': subtotal,
      'platformFee': platformFee,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'issuedAt': Timestamp.fromDate(issuedAt),
      if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt!),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'platformName': platformName,
      'platformEmail': platformEmail,
      'platformWebsite': platformWebsite,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'freelancerName': freelancerName,
      'freelancerEmail': freelancerEmail,
      'serviceTitle': serviceTitle,
      'serviceDescription': serviceDescription,
      'verificationCode': verificationCode,
      if ((pdfStoragePath ?? '').trim().isNotEmpty)
        'pdfStoragePath': pdfStoragePath,
      if ((pdfDownloadUrl ?? '').trim().isNotEmpty)
        'pdfDownloadUrl': pdfDownloadUrl,
    };
  }
}
