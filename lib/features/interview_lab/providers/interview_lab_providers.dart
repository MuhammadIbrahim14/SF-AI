import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../data/interview_lab_repository.dart';
import '../data/interview_lab_repository_impl.dart';
import '../models/interview_lab_models.dart';
import '../services/interview_lab_question_engine.dart';
import '../services/interview_lab_service.dart';
import 'interview_lab_analytics_provider.dart';

export 'interview_lab_analytics_provider.dart';

final interviewLabRepositoryProvider = Provider<InterviewLabRepository>((ref) {
  return InterviewLabRepositoryImpl(ref.watch(firestoreProvider));
});

final interviewLabServiceProvider = Provider<InterviewLabService>((ref) {
  return InterviewLabService(
    repository: ref.watch(interviewLabRepositoryProvider),
  );
});

final interviewLabConfigProvider = StreamProvider<InterviewLabConfigModel>((ref) {
  return ref.watch(interviewLabRepositoryProvider).watchConfig();
});

final interviewLabTemplatesProvider =
    StreamProvider<List<InterviewLabTemplateModel>>((ref) {
  return ref.watch(interviewLabRepositoryProvider).watchActiveTemplates();
});

/// Admin: active + inactive templates.
final interviewLabAllTemplatesProvider =
    StreamProvider<List<InterviewLabTemplateModel>>((ref) {
  return ref.watch(interviewLabRepositoryProvider).watchAllTemplates();
});

final myInterviewLabSessionsProvider =
    StreamProvider<List<InterviewLabSessionModel>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <InterviewLabSessionModel>[]);
      }
      return ref
          .watch(interviewLabRepositoryProvider)
          .watchSessionsForCandidate(user.uid);
    },
    loading: () => Stream.value(const <InterviewLabSessionModel>[]),
    error: (_, _) => Stream.value(const <InterviewLabSessionModel>[]),
  );
});

final myInterviewLabHistoryProvider =
    StreamProvider<List<InterviewLabHistoryEntryModel>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <InterviewLabHistoryEntryModel>[]);
      }
      return ref
          .watch(interviewLabRepositoryProvider)
          .watchHistoryForCandidate(user.uid);
    },
    loading: () => Stream.value(const <InterviewLabHistoryEntryModel>[]),
    error: (_, _) => Stream.value(const <InterviewLabHistoryEntryModel>[]),
  );
});

final interviewLabSessionProvider =
    StreamProvider.family<InterviewLabSessionModel?, String>((ref, sessionId) {
  return ref.watch(interviewLabRepositoryProvider).watchSession(sessionId);
});

final interviewLabQuestionsProvider =
    StreamProvider.family<List<InterviewLabQuestionModel>, String>(
        (ref, sessionId) {
  return ref
      .watch(interviewLabRepositoryProvider)
      .watchQuestionsForSession(sessionId);
});

final interviewLabActionProvider =
    AsyncNotifierProvider<InterviewLabActionNotifier, void>(
  InterviewLabActionNotifier.new,
);

final myInterviewLabBadgesProvider =
    StreamProvider<List<InterviewLabBadgeModel>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <InterviewLabBadgeModel>[]);
      }
      return ref
          .watch(interviewLabRepositoryProvider)
          .watchBadgesForCandidate(user.uid);
    },
    loading: () => Stream.value(const <InterviewLabBadgeModel>[]),
    error: (_, _) => Stream.value(const <InterviewLabBadgeModel>[]),
  );
});

final myInterviewLabProgressProvider =
    StreamProvider<InterviewLabProgressModel?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(interviewLabRepositoryProvider).watchProgress(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

class InterviewLabActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  InterviewLabService get _service => ref.read(interviewLabServiceProvider);

  Future<InterviewLabSessionModel?> createSession({
    required String roleTrack,
    required String candidateRole,
    String? difficulty,
    String? targetJobId,
    String? targetJobTitle,
    String? templateId,
    int? questionCountOverride,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return null;

    InterviewLabSessionModel? created;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.seedDefaultTemplatesIfEmpty();
      created = await _service.createAndPrepareSession(
        candidateId: user.uid,
        candidateRole: candidateRole,
        roleTrack: roleTrack,
        difficulty: difficulty,
        targetJobId: targetJobId,
        targetJobTitle: targetJobTitle,
        templateId: templateId,
        questionCountOverride: questionCountOverride,
      );
    });
    return state.hasError ? null : created;
  }

  Future<bool> beginAnswering(String sessionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.beginAnswering(sessionId));
    return !state.hasError;
  }

  Future<bool> pauseSession(String sessionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.pauseSession(sessionId));
    return !state.hasError;
  }

  Future<bool> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
    int timeSpentSeconds = 0,
    bool allowEmpty = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.submitAnswer(
        sessionId: sessionId,
        questionId: questionId,
        answer: answer,
        timeSpentSeconds: timeSpentSeconds,
        allowEmpty: allowEmpty,
      ),
    );
    return !state.hasError;
  }

  Future<bool> skipQuestion({
    required String sessionId,
    required String questionId,
    int timeSpentSeconds = 0,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.skipQuestion(
        sessionId: sessionId,
        questionId: questionId,
        timeSpentSeconds: timeSpentSeconds,
      ),
    );
    return !state.hasError;
  }

  Future<bool> goToQuestion({
    required String sessionId,
    required int questionIndex,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.goToQuestion(
        sessionId: sessionId,
        questionIndex: questionIndex,
      ),
    );
    return !state.hasError;
  }

  Future<void> autosaveDraft({
    required String sessionId,
    required String questionId,
    required String answer,
  }) {
    return _service.autosaveDraft(
      sessionId: sessionId,
      questionId: questionId,
      answer: answer,
    );
  }

  Future<bool> completeSession(String sessionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.completeSession(sessionId));
    if (!state.hasError) {
      ref.invalidate(interviewLabReportForSessionProvider(sessionId));
      ref.invalidate(myInterviewLabBadgesProvider);
      ref.invalidate(myInterviewLabProgressProvider);
    }
    return !state.hasError;
  }

  Future<bool> abandonSession(String sessionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.abandonSession(sessionId));
    return !state.hasError;
  }

  Future<bool> deleteSession(String sessionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.deleteSession(sessionId));
    return !state.hasError;
  }

  Future<bool> seedTemplates({bool force = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.seedDefaultTemplates(force: force),
    );
    return !state.hasError;
  }

  Future<bool> saveConfig(InterviewLabConfigModel config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.upsertConfig(config));
    return !state.hasError;
  }

  Future<bool> saveTemplate(InterviewLabTemplateModel template) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.upsertTemplate(template));
    return !state.hasError;
  }

  Object? get lastError => state.hasError ? state.error : null;

  String? get lastErrorMessage {
    final err = lastError;
    if (err is InterviewLabException) return err.message;
    if (err is FirebaseException) {
      if (err.code == 'permission-denied') {
        return 'Permission denied while starting Interview Lab. '
            'Confirm you are signed in as student/freelancer and Firestore rules are deployed.';
      }
      return err.message ?? err.code;
    }
    return err?.toString();
  }

  String? get activeSessionConflictId {
    final err = lastError;
    if (err is InterviewLabException && err.code == 'active-session-exists') {
      return err.sessionId;
    }
    return null;
  }
}
