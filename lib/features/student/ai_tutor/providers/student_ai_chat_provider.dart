import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/firebase_providers.dart';
import '../data/student_ai_chat_repository.dart';
import '../models/student_ai_message_model.dart';
import '../models/student_ai_thread_model.dart';
import '../models/student_ai_thread_scope.dart';
import '../models/student_ai_tutor_models.dart';

final studentAiChatRepositoryProvider = Provider<StudentAiChatRepository>((
  ref,
) {
  return StudentAiChatRepository(ref.watch(firestoreProvider));
});

final studentAiThreadProvider =
    StreamProvider.family<StudentAiThreadModel?, String>((ref, threadId) {
      return ref.watch(studentAiChatRepositoryProvider).watchThread(threadId);
    });

final studentAiMessagesProvider =
    StreamProvider.family<List<StudentAiMessageModel>, String>((ref, threadId) {
      return ref.watch(studentAiChatRepositoryProvider).watchMessages(threadId);
    });

final studentCourseAiThreadProvider =
    FutureProvider.family<StudentAiThreadModel, StudentAiTutorContextModel>((
      ref,
      context,
    ) {
      return ref
          .watch(studentAiChatRepositoryProvider)
          .getOrCreateThread(
            context: context,
            scope: StudentAiThreadScope.course,
          );
    });

final studentLessonAiThreadProvider =
    FutureProvider.family<StudentAiThreadModel, StudentAiTutorContextModel>((
      ref,
      context,
    ) {
      return ref
          .watch(studentAiChatRepositoryProvider)
          .getOrCreateThread(
            context: context,
            scope: StudentAiThreadScope.lesson,
          );
    });
