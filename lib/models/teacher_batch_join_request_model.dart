import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class TeacherBatchJoinRequestStatus {
  const TeacherBatchJoinRequestStatus._();

  static const pending = 'pending';
  static const approved = 'approved';
  static const denied = 'denied';

  static const values = <String>[pending, approved, denied];

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return values.contains(normalized) ? normalized : pending;
  }

  static String label(String status) {
    switch (normalize(status)) {
      case approved:
        return 'Approved';
      case denied:
        return 'Denied';
      case pending:
      default:
        return 'Pending';
    }
  }
}

/// `teacherBatches/{batchId}/joinRequests/{requestId}`
class TeacherBatchJoinRequestModel {
  const TeacherBatchJoinRequestModel({
    required this.requestId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String requestId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isPending =>
      TeacherBatchJoinRequestStatus.normalize(status) ==
      TeacherBatchJoinRequestStatus.pending;

  factory TeacherBatchJoinRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherBatchJoinRequestModel(
      requestId: doc.id,
      studentId: _string(data['studentId']),
      studentName: _string(data['studentName']),
      studentEmail: _string(data['studentEmail']),
      status: TeacherBatchJoinRequestStatus.normalize(_string(data['status'])),
      createdAt: _date(data['createdAt']),
      updatedAt: data['updatedAt'] == null ? null : _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName.trim(),
      'studentEmail': studentEmail.trim(),
      'status': TeacherBatchJoinRequestStatus.normalize(status),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
