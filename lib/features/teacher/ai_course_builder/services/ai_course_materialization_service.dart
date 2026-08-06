import 'package:firebase_auth/firebase_auth.dart';

import '../../../../features/courses/data/models/course_model.dart';
import '../../../../features/courses/data/models/grand_test_model.dart';
import '../../../../features/courses/data/models/lesson_model.dart';
import '../../../../features/courses/data/models/mcq_assignment_model.dart';
import '../../../../features/courses/data/models/project_assignment_model.dart';
import '../../../../features/courses/data/repositories/assignment_repository.dart';
import '../../../../features/courses/data/repositories/course_repository.dart';
import '../../../../features/courses/data/repositories/grand_test_repository.dart';
import '../../../../features/courses/data/repositories/lesson_repository.dart';
import '../../../../features/payment/services/teacher_subscription_service.dart';
import '../models/ai_course_blueprint_model.dart';
import '../models/ai_course_materialization_result_model.dart';
import '../models/ai_course_requirement_model.dart';
import 'ai_course_blueprint_repair_service.dart';
import 'ai_course_blueprint_validator.dart';

class AiCourseMaterializationService {
  const AiCourseMaterializationService({
    required CourseRepository courseRepository,
    required LessonRepository lessonRepository,
    required AssignmentRepository assignmentRepository,
    required GrandTestRepository grandTestRepository,
    required TeacherSubscriptionService teacherSubscriptionService,
    required FirebaseAuth auth,
  }) : _courseRepository = courseRepository,
       _lessonRepository = lessonRepository,
       _assignmentRepository = assignmentRepository,
       _grandTestRepository = grandTestRepository,
       _teacherSubscriptionService = teacherSubscriptionService,
       _auth = auth;

  final CourseRepository _courseRepository;
  final LessonRepository _lessonRepository;
  final AssignmentRepository _assignmentRepository;
  final GrandTestRepository _grandTestRepository;
  final TeacherSubscriptionService _teacherSubscriptionService;
  final FirebaseAuth _auth;

  Future<AiCourseMaterializationResultModel> materialize({
    required AiCourseBlueprintModel blueprint,
    required bool publish,
    AiCourseRequirementModel? requirements,
  }) async {
    final teacherId = _teacherId();
    final warnings = <String>[];
    final errors = <String>[];
    final previewOnlyItems = <String>[];
    final createdLessonIds = <String>[];
    final createdAssignmentIds = <String>[];
    final createdQuizIds = <String>[];
    final createdQuestionIds = <String>[];
    String? grandTestId;
    String? courseId;
    var materializedBlueprint = blueprint;

    if (requirements != null) {
      final validation = const AiCourseBlueprintValidator().validate(
        blueprint: materializedBlueprint,
        requirements: requirements,
      );
      if (!validation.isValid) {
        if (publish) {
          return AiCourseMaterializationResultModel(
            courseId: null,
            createdLessonIds: const [],
            createdAssignmentIds: const [],
            createdQuizIds: const [],
            createdQuestionIds: const [],
            createdGrandTestId: null,
            savedAsDraft: false,
            published: false,
            warnings: warnings,
            errors: [
              ...validation.errors,
              'Publish blocked: blueprint failed validation. Fix with live AI and retry.',
            ],
            previewOnlyItems: const [],
            success: false,
          );
        }
        final repaired = const AiCourseBlueprintRepairService().repair(
          blueprint: materializedBlueprint,
          requirements: requirements,
          source: 'templateRepair',
        );
        materializedBlueprint = repaired.blueprint;
        warnings.addAll(repaired.warnings);
      }
      final finalValidation = const AiCourseBlueprintValidator().validate(
        blueprint: materializedBlueprint,
        requirements: requirements,
      );
      if (!finalValidation.isValid) {
        return AiCourseMaterializationResultModel(
          courseId: null,
          createdLessonIds: const [],
          createdAssignmentIds: const [],
          createdQuizIds: const [],
          createdQuestionIds: const [],
          createdGrandTestId: null,
          savedAsDraft: !publish,
          published: false,
          warnings: warnings,
          errors: finalValidation.errors,
          previewOnlyItems: const [],
          success: false,
        );
      }
    }

    if (publish && materializedBlueprint.isFallback) {
      return AiCourseMaterializationResultModel(
        courseId: null,
        createdLessonIds: const [],
        createdAssignmentIds: const [],
        createdQuizIds: const [],
        createdQuestionIds: const [],
        createdGrandTestId: null,
        savedAsDraft: false,
        published: false,
        warnings: warnings,
        errors: const [
          'Cannot publish template-repaired / fallback content. Regenerate with AI.',
        ],
        previewOnlyItems: const [],
        success: false,
      );
    }

    try {
      if (publish) {
        final publishCheck = await _teacherSubscriptionService.validateCoursePublish(
          teacherId: teacherId,
          publishedCourseCount: await _courseRepository.countPublishedCoursesByTeacher(
            teacherId,
          ),
        );
        if (!publishCheck.allowed) {
          throw StateError(publishCheck.message);
        }
      }

      courseId = await _courseRepository.createCourse(
        _course(materializedBlueprint),
      );

      var lessonOrder = 0;
      final modules = [...materializedBlueprint.modules]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final module in modules) {
        final lessons = [...module.lessons]
          ..sort((a, b) => a.order.compareTo(b.order));
        for (final lesson in lessons) {
          lessonOrder++;
          if (publish) {
            final lessonCheck = await _teacherSubscriptionService.validateLessonCreate(
              teacherId: teacherId,
              currentLessonCount: await _lessonRepository.countLessonsInCourse(
                courseId,
              ),
            );
            if (!lessonCheck.allowed) {
              throw StateError(lessonCheck.message);
            }
          }
          final lessonId = await _lessonRepository.createLesson(
            LessonModel(
              lessonId: '',
              courseId: courseId,
              teacherId: teacherId,
              title: lesson.title,
              description: _cleanEducationalField(
                _lessonDescription(module, lesson),
                'Teacher-reviewed lesson content for ${lesson.title}.',
              ),
              orderIndex: lessonOrder,
              videoUrl: '',
              pdfLinks: const [],
              externalLinks: const [],
              durationMinutes: lesson.durationMinutes,
              isPreview: false,
              isArchived: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              learningObjectives: [
                lesson.objective,
              ].where((item) => item.trim().isNotEmpty).toList(),
              skillsCovered: _skillsFor(materializedBlueprint, module),
              prerequisites: materializedBlueprint.prerequisites,
              estimatedMinutes: lesson.durationMinutes,
              keyTakeaways: lesson.practiceTasks.isEmpty
                  ? lesson.contentOutline.take(3).toList()
                  : lesson.practiceTasks.take(3).toList(),
              lessonDifficulty: materializedBlueprint.level,
              completionMode: LessonCompletionMode.checkpoint,
              minimumReadSeconds: 60,
              minimumScrollPercent: 70,
              requireCheckpoints: true,
              requireMiniQuizPass: false,
              requirePracticalReflection: false,
              passingScorePercent: 70,
              completionCriteriaSummary:
                  'Review the lesson and answer the checkpoint before completion.',
              checkpoints: [
                LessonCheckpointModel(
                  id: 'checkpoint_1',
                  question: 'What is the most important idea from this lesson?',
                  type: 'reflection',
                  options: const [],
                  correctAnswer: '',
                  explanation:
                      'This reflection helps verify that the learner reviewed the lesson.',
                  points: 0,
                  required: true,
                  order: 1,
                ),
              ],
            ),
          );
          createdLessonIds.add(lessonId);
        }

        for (final assignment in module.assignments) {
          final assignmentQuestions = _mcqQuestions(assignment.questions);
          if (assignment.submissionType == 'mcq' &&
              assignmentQuestions.isNotEmpty) {
            final totalMarks = assignmentQuestions.fold<int>(
              0,
              (total, question) => total + question.marksPerQuestion,
            );
            if (publish) {
              final assignmentCheck = await _teacherSubscriptionService.validateAssignmentPublish(
                teacherId: teacherId,
                currentAssignmentCount: await _assignmentRepository
                    .countPublishedAssignmentsInCourse(courseId),
              );
              if (!assignmentCheck.allowed) {
                throw StateError(assignmentCheck.message);
              }
            }
            final assignmentId = await _assignmentRepository.createAssignment(
              McqAssignmentModel(
                assignmentId: '',
                courseId: courseId,
                teacherId: teacherId,
                title: assignment.title,
                description: _cleanEducationalField(
                  assignment.instructions,
                  'Teacher-reviewed assignment instructions.',
                ),
                skillsCovered: _skillsFor(materializedBlueprint, module),
                passingMarks: _passingMarks(totalMarks, 70),
                totalMarks: totalMarks,
                timeLimitMinutes: 30,
                dueDate: DateTime.now().add(
                  Duration(
                    days: assignment.dueOffsetDays <= 0
                        ? 7
                        : assignment.dueOffsetDays,
                  ),
                ),
                questions: assignmentQuestions,
                status: AssignmentStatus.draft,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
            createdAssignmentIds.add(assignmentId);
            createdQuestionIds.addAll(
              assignmentQuestions.map((q) => q.questionId),
            );
            if (publish) {
              await _assignmentRepository.publishAssignment(
                courseId: courseId,
                assignmentId: assignmentId,
                teacherId: teacherId,
              );
            }
          } else {
            if (publish) {
              final projectCheck = await _teacherSubscriptionService.validateProjectPublish(
                teacherId: teacherId,
                currentProjectCount: await _assignmentRepository
                    .countPublishedProjectAssignmentsInCourse(courseId),
              );
              if (!projectCheck.allowed) {
                throw StateError(projectCheck.message);
              }
            }
            final assignmentId = await _assignmentRepository
                .createProjectAssignment(
                  ProjectAssignmentModel(
                    assignmentId: '',
                    courseId: courseId,
                    teacherId: teacherId,
                    title: assignment.title,
                    description: _cleanEducationalField(
                      module.description,
                      'Teacher-reviewed project assignment.',
                    ),
                    requirements: assignment.rubric.isEmpty
                        ? const ['Submit a complete working project.']
                        : assignment.rubric,
                    instructions: _cleanEducationalField(
                      assignment.instructions,
                      'Complete the assignment according to the rubric.',
                    ),
                    maxMarks: assignment.points <= 0 ? 100 : assignment.points,
                    dueDate: DateTime.now().add(
                      Duration(
                        days: assignment.dueOffsetDays <= 0
                            ? 7
                            : assignment.dueOffsetDays,
                      ),
                    ),
                    skillsCovered: _skillsFor(materializedBlueprint, module),
                    status: AssignmentStatus.draft,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    projectGoal:
                        'Build a practical project for ${module.title}.',
                    realWorldScenario: module.description,
                    learningObjectives: [
                      'Apply the core concepts from ${module.title}.',
                      'Produce a reviewable project with clear evidence.',
                    ],
                    skillsDemonstrated: _skillsFor(
                      materializedBlueprint,
                      module,
                    ),
                    deliverables: const [
                      'Working project link or repository',
                      'Short implementation explanation',
                    ],
                    milestones: const [
                      'Plan the solution',
                      'Build the core functionality',
                      'Test and submit evidence',
                    ],
                    acceptanceCriteria: assignment.rubric.isEmpty
                        ? const ['Submission matches the project brief.']
                        : assignment.rubric,
                    submissionChecklist: const [
                      'Project description is complete',
                      'Repository or demo link is included',
                      'Important decisions are explained',
                    ],
                    estimatedCompletionHours: 4,
                    difficultyLevel: materializedBlueprint.level,
                    rubricCriteria: assignment.rubric,
                    starterGuidance: const [
                      'Break the project into milestones before coding.',
                      'Keep the submission focused on working evidence.',
                    ],
                  ),
                );
            createdAssignmentIds.add(assignmentId);
            if (publish) {
              await _assignmentRepository.publishProjectAssignment(
                courseId: courseId,
                assignmentId: assignmentId,
                teacherId: teacherId,
              );
            }
          }
        }

        final quizQuestions = _mcqQuestions(module.quiz.questions);
        if (quizQuestions.isNotEmpty) {
          final quizTotalMarks = quizQuestions.fold<int>(
            0,
            (total, question) => total + question.marksPerQuestion,
          );
          if (publish) {
            final quizCheck = await _teacherSubscriptionService.validateAssignmentPublish(
              teacherId: teacherId,
              currentAssignmentCount: await _assignmentRepository
                  .countPublishedAssignmentsInCourse(courseId),
            );
            if (!quizCheck.allowed) {
              throw StateError(quizCheck.message);
            }
          }
          final quiz = McqAssignmentModel(
            assignmentId: '',
            courseId: courseId,
            teacherId: teacherId,
            title: module.quiz.title,
            description: 'Module ${module.order}: ${module.title}',
            skillsCovered: _skillsFor(materializedBlueprint, module),
            passingMarks: _passingMarks(
              quizTotalMarks,
              module.quiz.passingScore,
            ),
            totalMarks: quizTotalMarks,
            timeLimitMinutes: 30,
            dueDate: null,
            questions: quizQuestions,
            status: AssignmentStatus.draft,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final quizId = await _assignmentRepository.createAssignment(quiz);
          createdQuizIds.add(quizId);
          createdQuestionIds.addAll(quizQuestions.map((q) => q.questionId));
          if (publish) {
            await _assignmentRepository.publishAssignment(
              courseId: courseId,
              assignmentId: quizId,
              teacherId: teacherId,
            );
          }
        }
      }

      final grandTests = materializedBlueprint.effectiveGrandTests;
      for (var testIndex = 0; testIndex < grandTests.length; testIndex++) {
        final grandTest = grandTests[testIndex];
        final grandQuestions = _grandTestQuestions(
          materializedBlueprint,
          grandTest,
          testIndex,
        );
        if (grandTest.totalPoints <= 0 && grandQuestions.isEmpty) continue;
        if (grandQuestions.isEmpty) {
          warnings.add(
            '${grandTest.title} had no valid MCQ questions, so it was not created.',
          );
        } else {
          if (publish) {
            final grandTestCheck = await _teacherSubscriptionService.validateGrandTestPublish(
              teacherId: teacherId,
              currentGrandTestCount: await _grandTestRepository
                  .countPublishedGrandTestsInCourse(courseId),
            );
            if (!grandTestCheck.allowed) {
              throw StateError(grandTestCheck.message);
            }
          }
          final totalMarks = grandQuestions.fold<int>(
            0,
            (total, question) => total + question.marks,
          );
          final createdGrandTestId = await _grandTestRepository.createGrandTest(
            GrandTestModel(
              grandTestId: '',
              courseId: courseId,
              teacherId: teacherId,
              title: grandTest.title,
              description: _cleanEducationalField(
                grandTest.description,
                'Teacher-reviewed grand test.',
              ),
              instructions: _grandTestInstructions(
                materializedBlueprint,
                grandTest,
              ),
              skillsCovered: materializedBlueprint.learningOutcomes
                  .take(8)
                  .toList(),
              totalMarks: totalMarks,
              passingMarks: _passingMarks(totalMarks, grandTest.passingScore),
              durationMinutes: 60,
              difficulty: materializedBlueprint.level,
              status: AssignmentStatus.draft,
              questions: grandQuestions,
              requiredLessonProgressPercent: 80,
              requiredAssignmentCompletionPercent: 70,
              requiredAverageScorePercent: 60,
              requireProjectSubmission: createdAssignmentIds.isNotEmpty,
              maxAttempts: 1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          grandTestId ??= createdGrandTestId;
          createdQuestionIds.addAll(grandQuestions.map((q) => q.questionId));
          if (publish) {
            await _grandTestRepository.publishGrandTest(
              courseId: courseId,
              grandTestId: createdGrandTestId,
              teacherId: teacherId,
            );
          }
        }
      }

      if (publish) {
        await _courseRepository.publishCourse(
          courseId: courseId,
          teacherId: teacherId,
        );
      }
    } catch (error) {
      errors.add(error.toString());
      if (courseId != null) {
        warnings.add(
          'Some items may need manual review. The course was left as a draft where possible.',
        );
      }
    }

    return AiCourseMaterializationResultModel(
      courseId: courseId,
      createdLessonIds: createdLessonIds,
      createdAssignmentIds: createdAssignmentIds,
      createdQuizIds: createdQuizIds,
      createdQuestionIds: createdQuestionIds,
      createdGrandTestId: grandTestId,
      savedAsDraft: !publish,
      published: publish && errors.isEmpty,
      warnings: warnings,
      errors: errors,
      previewOnlyItems: previewOnlyItems,
      success: courseId != null && errors.isEmpty,
    );
  }

  CourseModel _course(AiCourseBlueprintModel blueprint) {
    return CourseModel.createDraft(
      teacherId: _teacherId(),
      teacherName: _teacherName(),
      title: blueprint.title,
      subtitle: blueprint.subtitle ?? 'AI-assisted course blueprint',
      description: _cleanEducationalField(
        blueprint.description,
        'A teacher-reviewed course blueprint for ${blueprint.title}.',
      ),
      category: 'AI Generated',
      level: blueprint.level,
      language: blueprint.languageStyle,
      skillsCovered: blueprint.learningOutcomes.take(8).toList(),
      tags: ['ai-generated', blueprint.level.toLowerCase()],
      prerequisites: blueprint.prerequisites,
      learningOutcomes: blueprint.learningOutcomes,
      targetAudience: [blueprint.targetAudience],
      durationMinutes: blueprint.totalDurationMinutes,
      lessonCount: 0,
    );
  }

  String _lessonDescription(
    AiCourseModuleBlueprintModel module,
    AiLessonBlueprintModel lesson,
  ) {
    final lines = <String>[
      'Module: ${module.title}',
      if (lesson.objective.trim().isNotEmpty) 'Objective: ${lesson.objective}',
      if (lesson.summary.trim().isNotEmpty) lesson.summary,
      if (lesson.contentOutline.isNotEmpty) 'Outline:',
      ...lesson.contentOutline.map((item) => '- $item'),
      if (lesson.examples.isNotEmpty) 'Examples:',
      ...lesson.examples.map((item) => '- $item'),
      if (lesson.practiceTasks.isNotEmpty) 'Practice tasks:',
      ...lesson.practiceTasks.map((item) => '- $item'),
    ];
    return lines.join('\n');
  }

  List<McqQuestionModel> _mcqQuestions(
    List<AiQuizQuestionBlueprintModel> questions,
  ) {
    final result = <McqQuestionModel>[];
    for (var index = 0; index < questions.length; index++) {
      final source = questions[index];
      if (source.question.trim().isEmpty) continue;
      final options = _normalizedOptions(source);
      result.add(
        McqQuestionModel(
          questionId: 'q_${index + 1}',
          question: source.question,
          options: options,
          correctAnswer: _correctAnswer(source, options),
          marksPerQuestion: source.points <= 0 ? 5 : source.points,
          explanation: source.explanation,
        ),
      );
    }
    return result;
  }

  List<GrandTestQuestionModel> _grandTestQuestions(
    AiCourseBlueprintModel blueprint,
    AiGrandTestBlueprintModel grandTest,
    int testIndex,
  ) {
    final sourceQuestions = grandTest.questions.isNotEmpty
        ? grandTest.questions
        : blueprint.modules
              .expand((module) => module.quiz.questions)
              .take(12)
              .toList();
    final result = <GrandTestQuestionModel>[];
    for (var index = 0; index < sourceQuestions.length; index++) {
      final source = sourceQuestions[index];
      if (source.question.trim().isEmpty) continue;
      final options = _normalizedOptions(source);
      result.add(
        GrandTestQuestionModel(
          questionId: 'gt_${testIndex + 1}_q_${index + 1}',
          question: source.question,
          options: options,
          correctAnswer: _correctAnswer(source, options),
          marks: source.points <= 0 ? 5 : source.points,
          difficulty: blueprint.level,
          skillTag: blueprint.learningOutcomes.isEmpty
              ? blueprint.title
              : blueprint.learningOutcomes.first,
          explanation: source.explanation,
        ),
      );
    }
    return result;
  }

  List<String> _normalizedOptions(AiQuizQuestionBlueprintModel source) {
    final options = source.options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    final correct = source.correctAnswer.trim();
    if (correct.isNotEmpty &&
        !options.any(
          (option) => option.toLowerCase() == correct.toLowerCase(),
        )) {
      options.insert(0, correct);
    }
    while (options.length < 4) {
      options.add('Option ${options.length + 1}');
    }
    return options.take(4).toList();
  }

  String _correctAnswer(
    AiQuizQuestionBlueprintModel source,
    List<String> options,
  ) {
    final correct = source.correctAnswer.trim();
    if (correct.isEmpty) return options.first;
    return options.firstWhere(
      (option) => option.toLowerCase() == correct.toLowerCase(),
      orElse: () => options.first,
    );
  }

  List<String> _skillsFor(
    AiCourseBlueprintModel blueprint,
    AiCourseModuleBlueprintModel module,
  ) {
    final skills = <String>[
      ...blueprint.learningOutcomes.take(3),
      module.title,
    ].where((item) => item.trim().isNotEmpty).toList();
    return skills.isEmpty ? [blueprint.title] : skills;
  }

  String _grandTestInstructions(
    AiCourseBlueprintModel blueprint,
    AiGrandTestBlueprintModel grandTest,
  ) {
    final lines = <String>[
      'Answer all MCQ questions.',
      if ((grandTest.practicalTask ?? '').trim().isNotEmpty)
        'Practical task: ${grandTest.practicalTask}',
      if (blueprint.gradingRubric.isNotEmpty) 'Rubric:',
      ...blueprint.gradingRubric.map((item) => '- $item'),
    ];
    return lines.join('\n');
  }

  int _passingMarks(int totalMarks, int passingScore) {
    if (totalMarks <= 0) return 0;
    final normalized = passingScore <= 0 ? 70 : passingScore;
    return ((totalMarks * normalized) / 100).ceil();
  }

  String _teacherId() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in teacher is required.');
    return user.uid;
  }

  String _teacherName() {
    final displayName = _auth.currentUser?.displayName?.trim() ?? '';
    return displayName.isEmpty ? 'Teacher' : displayName;
  }
}

String _cleanEducationalField(String value, String fallback) {
  final text = value.trim();
  if (text.isEmpty || containsGatewayStatusText(text)) return fallback;
  return text;
}
