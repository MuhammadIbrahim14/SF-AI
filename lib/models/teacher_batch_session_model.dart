import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _date(Object? value) => _nullableDate(value) ?? DateTime.now();

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class TeacherBatchSessionStatus {
  const TeacherBatchSessionStatus._();

  static const scheduled = 'scheduled';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const values = <String>[scheduled, completed, cancelled];

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return values.contains(normalized) ? normalized : scheduled;
  }

  static String label(String status) {
    switch (normalize(status)) {
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      case scheduled:
      default:
        return 'Scheduled';
    }
  }
}

/// `teacherBatches/{batchId}/sessions/{sessionId}`
class TeacherBatchSessionModel {
  const TeacherBatchSessionModel({
    required this.sessionId,
    required this.title,
    required this.notes,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.teacherId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sessionId;
  final String title;
  final String notes;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String status;
  final String teacherId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isScheduled =>
      TeacherBatchSessionStatus.normalize(status) ==
      TeacherBatchSessionStatus.scheduled;

  factory TeacherBatchSessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherBatchSessionModel(
      sessionId: doc.id,
      title: _string(data['title'], 'Untitled session'),
      notes: _string(data['notes']),
      startsAt: _date(data['startsAt']),
      endsAt: _nullableDate(data['endsAt']),
      status: TeacherBatchSessionStatus.normalize(_string(data['status'])),
      teacherId: _string(data['teacherId']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'notes': notes.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
      'status': TeacherBatchSessionStatus.normalize(status),
      'teacherId': teacherId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
