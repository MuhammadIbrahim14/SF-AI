import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_ai_message_model.dart';
import '../models/student_ai_thread_model.dart';
import '../models/student_ai_thread_scope.dart';
import '../models/student_ai_tutor_models.dart';

class StudentAiChatRepository {
  const StudentAiChatRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection('studentAiTutorThreads');

  static String threadIdFor({
    required String studentId,
    String? courseId,
    String? lessonId,
    required StudentAiThreadScope scope,
  }) {
    final course = _safePart(courseId, fallback: 'general');
    final lesson = scope == StudentAiThreadScope.lesson
        ? _safePart(lessonId, fallback: 'lesson')
        : 'root';
    return _safePart('${studentId}_${course}_${scope.name}_$lesson');
  }

  Future<StudentAiThreadModel> getOrCreateThread({
    required StudentAiTutorContextModel context,
    required StudentAiThreadScope scope,
  }) async {
    final threadId = threadIdFor(
      studentId: context.studentId,
      courseId: context.courseId,
      lessonId: context.lessonId,
      scope: scope,
    );
    final ref = _threads.doc(threadId);
    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        return StudentAiThreadModel.fromFirestore(snapshot);
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      // Older rules denied missing-doc reads. Continue to create the
      // deterministic thread; ownership is still enforced by create rules.
    }

    final title = _threadTitle(context, scope);
    final data = StudentAiThreadModel(
      id: threadId,
      studentId: context.studentId,
      courseId: context.courseId,
      lessonId: scope == StudentAiThreadScope.lesson ? context.lessonId : null,
      scope: scope,
      title: title,
      courseTitle: context.courseTitle,
      lessonTitle: context.lessonTitle,
      lastMessagePreview: 'New AI tutor chat',
      messageCount: 0,
    ).toMap();
    await ref.set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    final created = await ref.get();
    return StudentAiThreadModel.fromFirestore(created);
  }

  Stream<StudentAiThreadModel?> watchThread(String threadId) {
    return _threads.doc(threadId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return StudentAiThreadModel.fromFirestore(snapshot);
    });
  }

  Stream<List<StudentAiMessageModel>> watchMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(StudentAiMessageModel.fromFirestore).toList(),
        );
  }

  Future<List<StudentAiMessageModel>> getRecentMessages(
    String threadId, {
    int limit = 18,
  }) async {
    final snapshot = await _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map(StudentAiMessageModel.fromFirestore)
        .toList()
        .reversed
        .toList();
  }

  Future<void> saveUserMessage({
    required String threadId,
    required StudentAiTutorContextModel context,
    required String content,
    required String taskType,
  }) async {
    final messageRef = _threads.doc(threadId).collection('messages').doc();
    final message = StudentAiMessageModel(
      id: messageRef.id,
      threadId: threadId,
      studentId: context.studentId,
      courseId: context.courseId,
      lessonId: context.lessonId,
      role: StudentAiMessageRole.user,
      content: content,
      createdAt: DateTime.now(),
      status: StudentAiMessageStatus.sent,
      taskType: taskType,
      source: 'studentAiTutor',
      creditsCharged: 0,
    );
    await _writeMessageAndPreview(
      threadId: threadId,
      messageRef: messageRef,
      message: message,
      preview: content,
    );
  }

  Future<void> saveAssistantMessage({
    required String threadId,
    required StudentAiTutorContextModel context,
    required StudentAiTutorResponseModel response,
    required String taskType,
  }) async {
    final messageRef = _threads.doc(threadId).collection('messages').doc();
    final message = StudentAiMessageModel(
      id: messageRef.id,
      threadId: threadId,
      studentId: context.studentId,
      courseId: context.courseId,
      lessonId: context.lessonId,
      role: StudentAiMessageRole.assistant,
      content: response.answer,
      createdAt: DateTime.now(),
      status: response.isUnavailable
          ? StudentAiMessageStatus.failed
          : StudentAiMessageStatus.sent,
      taskType: taskType,
      provider: response.sourceProvider,
      model: response.model,
      source: response.sourceProvider,
      creditsCharged: response.isUnavailable ? 0 : response.creditCost,
      errorCode: response.isUnavailable
          ? (response.qualityWarnings.isEmpty
                ? 'aiUnavailable'
                : response.qualityWarnings.first)
          : null,
      structuredData: response.toStructuredMap(),
      safetyNotes: response.safetyNotes,
    );
    await _writeMessageAndPreview(
      threadId: threadId,
      messageRef: messageRef,
      message: message,
      preview: response.isUnavailable ? 'AI unavailable' : response.answer,
    );
  }

  Future<void> archiveThread(String threadId) async {
    await _threads.doc(threadId).update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearThreadMessages(String threadId) async {
    final snapshot = await _threads
        .doc(threadId)
        .collection('messages')
        .limit(100)
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.update(_threads.doc(threadId), {
      'lastMessagePreview': 'Chat cleared',
      'messageCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _writeMessageAndPreview({
    required String threadId,
    required DocumentReference<Map<String, dynamic>> messageRef,
    required StudentAiMessageModel message,
    required String preview,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      messageRef,
      message.toMap(createdAtValue: FieldValue.serverTimestamp()),
    );
    batch.set(_threads.doc(threadId), {
      'lastMessagePreview': _preview(preview),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  static String _threadTitle(
    StudentAiTutorContextModel context,
    StudentAiThreadScope scope,
  ) {
    if (scope == StudentAiThreadScope.lesson) {
      final lesson = (context.lessonTitle ?? '').trim();
      if (lesson.isNotEmpty) return '$lesson AI Tutor';
      return 'Lesson AI Tutor';
    }
    final course = (context.courseTitle ?? '').trim();
    if (course.isNotEmpty) return '$course AI Tutor';
    return 'SkillForge AI Tutor';
  }

  static String _preview(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}...';
  }

  static String _safePart(String? value, {String fallback = 'thread'}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return fallback;
    return text.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
