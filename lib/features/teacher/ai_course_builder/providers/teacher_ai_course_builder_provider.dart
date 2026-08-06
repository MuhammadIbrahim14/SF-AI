import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/copilot/services/ai_gateway_client.dart';
import '../../../../features/courses/providers/assignment_provider.dart';
import '../../../../features/courses/providers/course_provider.dart';
import '../../../../features/courses/providers/grand_test_provider.dart';
import '../../../../features/courses/providers/lesson_provider.dart';
import '../../../../features/payment/providers/payment_providers.dart';
import '../models/ai_course_blueprint_model.dart';
import '../models/ai_course_materialization_result_model.dart';
import '../models/ai_course_requirement_model.dart';
import '../services/ai_course_materialization_service.dart';
import '../services/ai_course_blueprint_validator.dart';
import '../services/teacher_ai_course_builder_service.dart';

final teacherAiCourseBuilderServiceProvider =
    Provider<TeacherAiCourseBuilderService>((ref) {
      return TeacherAiCourseBuilderService(
        gatewayClient: AiGatewayClient(),
        auth: FirebaseAuth.instance,
      );
    });

final aiCourseMaterializationServiceProvider =
    Provider<AiCourseMaterializationService>((ref) {
      return AiCourseMaterializationService(
        courseRepository: ref.watch(courseRepositoryProvider),
        lessonRepository: ref.watch(lessonRepositoryProvider),
        assignmentRepository: ref.watch(assignmentRepositoryProvider),
        grandTestRepository: ref.watch(grandTestRepositoryProvider),
        teacherSubscriptionService: ref.watch(teacherSubscriptionServiceProvider),
        auth: FirebaseAuth.instance,
      );
    });

final teacherAiCourseBuilderProvider =
    NotifierProvider<
      TeacherAiCourseBuilderNotifier,
      TeacherAiCourseBuilderState
    >(TeacherAiCourseBuilderNotifier.new);

class TeacherAiCourseBuilderState {
  const TeacherAiCourseBuilderState({
    this.requirements,
    this.currentStep = 0,
    this.isGenerating = false,
    this.isSavingDraft = false,
    this.isPublishing = false,
    this.blueprint,
    this.validationErrors = const <String>[],
    this.errorMessage,
    this.needsUpgrade = false,
    this.source,
    this.rateLimited = false,
    this.retryAfterSeconds,
    this.lastCourseId,
    this.materializationResult,
  });

  final AiCourseRequirementModel? requirements;
  final int currentStep;
  final bool isGenerating;
  final bool isSavingDraft;
  final bool isPublishing;
  final AiCourseBlueprintModel? blueprint;
  final List<String> validationErrors;
  final String? errorMessage;
  final bool needsUpgrade;
  final String? source;
  final bool rateLimited;
  final int? retryAfterSeconds;
  final String? lastCourseId;
  final AiCourseMaterializationResultModel? materializationResult;

  TeacherAiCourseBuilderState copyWith({
    AiCourseRequirementModel? requirements,
    int? currentStep,
    bool? isGenerating,
    bool? isSavingDraft,
    bool? isPublishing,
    AiCourseBlueprintModel? blueprint,
    List<String>? validationErrors,
    String? errorMessage,
    bool? needsUpgrade,
    String? source,
    bool? rateLimited,
    int? retryAfterSeconds,
    String? lastCourseId,
    AiCourseMaterializationResultModel? materializationResult,
    bool clearError = false,
    bool clearMaterializationResult = false,
  }) {
    return TeacherAiCourseBuilderState(
      requirements: requirements ?? this.requirements,
      currentStep: currentStep ?? this.currentStep,
      isGenerating: isGenerating ?? this.isGenerating,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isPublishing: isPublishing ?? this.isPublishing,
      blueprint: blueprint ?? this.blueprint,
      validationErrors: validationErrors ?? this.validationErrors,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      needsUpgrade: needsUpgrade ?? this.needsUpgrade,
      source: source ?? this.source,
      rateLimited: rateLimited ?? this.rateLimited,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
      lastCourseId: lastCourseId ?? this.lastCourseId,
      materializationResult: clearMaterializationResult
          ? null
          : materializationResult ?? this.materializationResult,
    );
  }
}

class TeacherAiCourseBuilderNotifier
    extends Notifier<TeacherAiCourseBuilderState> {
  @override
  TeacherAiCourseBuilderState build() {
    return const TeacherAiCourseBuilderState();
  }

  Future<void> generateCourse(AiCourseRequirementModel requirements) async {
    state = state.copyWith(
      requirements: requirements,
      currentStep: 1,
      isGenerating: true,
      validationErrors: const [],
      clearMaterializationResult: true,
      clearError: true,
      needsUpgrade: false,
    );
    try {
      // IMPORTANT: Credits are typically charged during AI blueprint generation.
      // So we must validate teacher plan limits BEFORE calling generateBlueprint(),
      // otherwise credits get burned even if the later publish/save fails.
      final teacherId = FirebaseAuth.instance.currentUser?.uid;
      if (teacherId == null || teacherId.trim().isEmpty) {
        throw StateError('A signed-in teacher is required.');
      }

      final subscriptionService = ref.read(teacherSubscriptionServiceProvider);
      final courseRepo = ref.read(courseRepositoryProvider);

      final publishCheck = await subscriptionService.validateCoursePublish(
        teacherId: teacherId,
        publishedCourseCount:
            await courseRepo.countPublishedCoursesByTeacher(teacherId),
      );
      if (!publishCheck.allowed) {
        state = state.copyWith(
          currentStep: 0,
          isGenerating: false,
          errorMessage: publishCheck.message,
          needsUpgrade: publishCheck.needsUpgrade,
        );
        return;
      }

      // Also prevent generation if the request would exceed the plan's per-course
      // grand test limit when publishing (credits would be wasted otherwise).
      final access = await subscriptionService.getAccessForTeacher(teacherId);
      final requestedGrandTests = requirements.effectiveGrandTestCount;
      if (requirements.includeGrandTest &&
          requestedGrandTests > access.maxGrandTestsPerCourse) {
        state = state.copyWith(
          currentStep: 0,
          isGenerating: false,
          errorMessage:
              'Your grand tests limit for ${access.planName} has been reached. Upgrade to unlock more grand tests per course.',
          needsUpgrade: true,
        );
        return;
      }

      final service = ref.read(teacherAiCourseBuilderServiceProvider);
      final blueprint = await service.generateBlueprint(requirements);
      state = state.copyWith(
        currentStep: 2,
        isGenerating: false,
        blueprint: blueprint,
        source: blueprint.source,
        rateLimited: blueprint.isFallback,
        validationErrors: service.validateBlueprint(
          blueprint,
          requirements: requirements,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        currentStep: 0,
        isGenerating: false,
        errorMessage: error.toString(),
        needsUpgrade: false,
      );
    }
  }

  void updateBlueprintText({String? title, String? description}) {
    final blueprint = state.blueprint;
    if (blueprint == null) return;
    if ((title != null && containsGatewayStatusText(title)) ||
        (description != null && containsGatewayStatusText(description))) {
      state = state.copyWith(
        errorMessage:
            'AI edit failed. Your existing title/description were not changed.',
      );
      return;
    }
    state = state.copyWith(
      blueprint: blueprint.copyWith(title: title, description: description),
      clearMaterializationResult: true,
      clearError: true,
    );
  }

  Future<bool> saveDraft() async {
    final blueprint = state.blueprint;
    if (blueprint == null) return false;
    state = state.copyWith(isSavingDraft: true, clearError: true);
    try {
      final result = await ref
          .read(aiCourseMaterializationServiceProvider)
          .materialize(
            blueprint: blueprint,
            publish: false,
            requirements: state.requirements,
          );
      state = state.copyWith(
        isSavingDraft: false,
        currentStep: 3,
        lastCourseId: result.courseId,
        materializationResult: result,
        errorMessage: result.errors.isEmpty ? null : result.errors.join('\n'),
      );
      return result.success;
    } catch (error) {
      state = state.copyWith(
        isSavingDraft: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> publishAfterConfirmation() async {
    final blueprint = state.blueprint;
    if (blueprint == null) return false;
    if (blueprint.isFallback) {
      state = state.copyWith(
        isPublishing: false,
        errorMessage:
            'Cannot publish template-repaired content. Regenerate with a live AI provider, then publish.',
      );
      return false;
    }
    state = state.copyWith(isPublishing: true, clearError: true);
    try {
      final result = await ref
          .read(aiCourseMaterializationServiceProvider)
          .materialize(
            blueprint: blueprint,
            publish: true,
            requirements: state.requirements,
          );
      if (result.success &&
          (result.warnings.any((w) => w.toLowerCase().contains('template')) ||
              blueprint.isFallback)) {
        state = state.copyWith(
          isPublishing: false,
          materializationResult: result,
          errorMessage:
              'Publish blocked: content was repaired from templates. Regenerate with AI.',
        );
        return false;
      }
      state = state.copyWith(
        isPublishing: false,
        currentStep: 3,
        lastCourseId: result.courseId,
        materializationResult: result,
        errorMessage: result.errors.isEmpty ? null : result.errors.join('\n'),
      );
      return result.success;
    } catch (error) {
      state = state.copyWith(
        isPublishing: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const TeacherAiCourseBuilderState();
  }
}
