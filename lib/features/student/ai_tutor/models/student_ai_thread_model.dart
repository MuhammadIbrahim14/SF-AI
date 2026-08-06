import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_ai_thread_scope.dart';

class StudentAiThreadModel {
  const StudentAiThreadModel({
    required this.id,
    required this.studentId,
    required this.scope,
    required this.title,
    this.courseId,
    this.lessonId,
    this.courseTitle,
    this.lessonTitle,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    this.messageCount = 0,
    this.isArchived = false,
    this.contextSummary,
  });

  factory StudentAiThreadModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return StudentAiThreadModel.fromMap(doc.id, doc.data());
  }

  factory StudentAiThreadModel.fromMap(String id, Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return StudentAiThreadModel(
      id: id,
      studentId: data['studentId']?.toString() ?? '',
      courseId: _text(data['courseId']),
      lessonId: _text(data['lessonId']),
      scope: StudentAiThreadScope.fromValue(data['scope']),
      title: _text(data['title']) ?? 'SkillForge AI Tutor',
      courseTitle: _text(data['courseTitle']),
      lessonTitle: _text(data['lessonTitle']),
      lastMessagePreview: _text(data['lastMessagePreview']) ?? '',
      lastMessageAt: _date(data['lastMessageAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      messageCount: _int(data['messageCount']),
      isArchived: data['isArchived'] == true,
      contextSummary: _text(data['contextSummary']),
    );
  }

  final String id;
  final String studentId;
  final String? courseId;
  final String? lessonId;
  final StudentAiThreadScope scope;
  final String title;
  final String? courseTitle;
  final String? lessonTitle;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messageCount;
  final bool isArchived;
  final String? contextSummary;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      if ((courseId ?? '').trim().isNotEmpty) 'courseId': courseId,
      if ((lessonId ?? '').trim().isNotEmpty) 'lessonId': lessonId,
      'scope': scope.name,
      'title': title,
      if ((courseTitle ?? '').trim().isNotEmpty) 'courseTitle': courseTitle,
      if ((lessonTitle ?? '').trim().isNotEmpty) 'lessonTitle': lessonTitle,
      'lastMessagePreview': lastMessagePreview,
      'messageCount': messageCount,
      'isArchived': isArchived,
      if ((contextSummary ?? '').trim().isNotEmpty)
        'contextSummary': contextSummary,
      'source': 'studentAiTutor',
    };
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
