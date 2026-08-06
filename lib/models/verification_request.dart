import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationRequest {
  const VerificationRequest({
    required this.userId,
    required this.role,
    required this.displayName,
    required this.subtitle,
    required this.status,
    required this.updatedAt,
    required this.details,
  });

  final String userId;
  final String role;
  final String displayName;
  final String subtitle;
  final String status;
  final DateTime? updatedAt;
  final Map<String, dynamic> details;

  factory VerificationRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document, {
    required String role,
  }) {
    final data = document.data() ?? const <String, dynamic>{};
    final timestamp = data['verificationUpdatedAt'] ?? data['updatedAt'];
    final displayName = role == 'company'
        ? _text(data['companyName'], 'Company account')
        : _text(data['professionalTitle'], 'Teacher account');
    final subtitle = role == 'company'
        ? _text(data['industry'], 'Industry not provided')
        : _teacherSubtitle(data);

    return VerificationRequest(
      userId: document.id,
      role: role,
      displayName: displayName,
      subtitle: subtitle,
      status: _normalizeStatus(data['verificationStatus']),
      updatedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : timestamp is DateTime
          ? timestamp
          : null,
      details: Map.unmodifiable(data),
    );
  }
}

String _normalizeStatus(Object? value) {
  final status = _text(value, 'pending').toLowerCase();
  return status == 'verified' ? 'approved' : status;
}

String _teacherSubtitle(Map<String, dynamic> data) {
  final subjects = data['subjects'];
  if (subjects is Iterable) {
    final values = subjects
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isNotEmpty) return values.take(3).join(', ');
  }
  return _text(data['industry'], 'Specialization not provided');
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
