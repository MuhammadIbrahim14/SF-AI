import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAiMessageRole {
  const StudentAiMessageRole._();

  static const user = 'user';
  static const assistant = 'assistant';
  static const system = 'system';
}

class StudentAiMessageStatus {
  const StudentAiMessageStatus._();

  static const sending = 'sending';
  static const sent = 'sent';
  static const failed = 'failed';
}

class StudentAiMessageModel {
  const StudentAiMessageModel({
    required this.id,
    required this.threadId,
    required this.studentId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.status,
    this.courseId,
    this.lessonId,
    this.taskType,
    this.provider,
    this.model,
    this.source,
    this.creditsCharged = 0,
    this.errorCode,
    this.structuredData = const <String, dynamic>{},
    this.safetyNotes = const <String>[],
  });

  factory StudentAiMessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StudentAiMessageModel(
      id: doc.id,
      threadId: data['threadId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      courseId: _text(data['courseId']),
      lessonId: _text(data['lessonId']),
      role: _text(data['role']) ?? StudentAiMessageRole.assistant,
      content: _text(data['content']) ?? '',
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      status: _text(data['status']) ?? StudentAiMessageStatus.sent,
      taskType: _text(data['taskType']),
      provider: _text(data['provider']),
      model: _text(data['model']),
      source: _text(data['source']),
      creditsCharged: _int(data['creditsCharged']),
      errorCode: _text(data['errorCode']),
      structuredData: data['structuredData'] is Map
          ? Map<String, dynamic>.from(data['structuredData'] as Map)
          : const <String, dynamic>{},
      safetyNotes: _stringList(data['safetyNotes']),
    );
  }

  final String id;
  final String threadId;
  final String studentId;
  final String? courseId;
  final String? lessonId;
  final String role;
  final String content;
  final DateTime createdAt;
  final String status;
  final String? taskType;
  final String? provider;
  final String? model;
  final String? source;
  final int creditsCharged;
  final String? errorCode;
  final Map<String, dynamic> structuredData;
  final List<String> safetyNotes;

  bool get isUser => role == StudentAiMessageRole.user;
  bool get isAssistant => role == StudentAiMessageRole.assistant;
  bool get isFailed => status == StudentAiMessageStatus.failed;

  Map<String, dynamic> toMap({Object? createdAtValue}) {
    return {
      'id': id,
      'threadId': threadId,
      'studentId': studentId,
      if ((courseId ?? '').trim().isNotEmpty) 'courseId': courseId,
      if ((lessonId ?? '').trim().isNotEmpty) 'lessonId': lessonId,
      'role': role,
      'content': content,
      'createdAt': createdAtValue ?? Timestamp.fromDate(createdAt),
      'status': status,
      if ((taskType ?? '').trim().isNotEmpty) 'taskType': taskType,
      if ((provider ?? '').trim().isNotEmpty) 'provider': provider,
      if ((model ?? '').trim().isNotEmpty) 'model': model,
      if ((source ?? '').trim().isNotEmpty) 'source': source,
      'creditsCharged': creditsCharged,
      if ((errorCode ?? '').trim().isNotEmpty) 'errorCode': errorCode,
      if (structuredData.isNotEmpty) 'structuredData': structuredData,
      if (safetyNotes.isNotEmpty) 'safetyNotes': safetyNotes,
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

  static List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const <String>[];
  }
}
