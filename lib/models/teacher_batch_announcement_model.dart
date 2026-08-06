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

/// `teacherBatches/{batchId}/announcements/{id}` — visible to roster students.
class TeacherBatchAnnouncementModel {
  const TeacherBatchAnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.teacherId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String teacherId;
  final DateTime createdAt;

  factory TeacherBatchAnnouncementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherBatchAnnouncementModel(
      id: doc.id,
      title: _string(data['title'], 'Untitled'),
      body: _string(data['body']),
      teacherId: _string(data['teacherId']),
      createdAt: _date(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'teacherId': teacherId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
