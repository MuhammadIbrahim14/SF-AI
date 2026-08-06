import '../models/teacher_ai_generation_request_model.dart';
import '../models/teacher_ai_generation_result_model.dart';

class TeacherAiValidationService {
  const TeacherAiValidationService();

  TeacherAiGenerationResultModel validateAndRepair(
    TeacherAiGenerationResultModel result,
    TeacherAiGenerationRequestModel request,
  ) {
    final data = Map<String, dynamic>.from(result.data);
    final warnings = [...result.warnings];
    final errors = [...result.errors];

    if ((data['title']?.toString().trim() ?? '').isEmpty) {
      data['title'] = _defaultTitle(request);
      warnings.add('Missing title was repaired.');
    }

    if (request.taskType == TeacherAiTaskType.lessonBuilder) {
      _ensure(data, 'summary', 'Review this lesson draft before saving.');
      _ensureList(data, 'contentOutline', ['Introduce the topic', 'Practice']);
      data['durationMinutes'] = _positiveInt(data['durationMinutes'], 35);
    }

    if (request.taskType == TeacherAiTaskType.projectAssignmentBuilder) {
      _ensure(data, 'description', data['scenario']?.toString() ?? '');
      _ensure(data, 'scenario', 'Complete a practical project for this topic.');
      _ensure(
        data,
        'instructions',
        'Review the brief and submit all required deliverables.',
      );
      _ensureList(
        data,
        'deliverables',
        _numberedList(
          'Deliverable',
          _contextInt(request, 'deliverableCount', 4),
        ),
      );
      _ensureList(
        data,
        'milestones',
        _numberedList('Milestone', _contextInt(request, 'milestoneCount', 3)),
      );
      _ensureList(
        data,
        'submissionChecklist',
        _numberedList('Checklist item', request.questionCount.clamp(1, 12)),
      );
      if (request.extraContext['includeStarterGuidance'] != false) {
        _ensureList(data, 'starterGuidance', [
          'Start by clarifying the problem and expected output.',
          'Break the work into small milestones before implementation.',
        ]);
      }
      if (request.extraContext['includeRubric'] != false) {
        _ensureList(
          data,
          'rubric',
          _numberedList(
            'Rubric criterion',
            _contextInt(request, 'rubricCriteriaCount', 5),
          ),
        );
      }
      data['totalPoints'] = _positiveInt(
        data['totalPoints'] ?? data['points'],
        _contextInt(request, 'totalPoints', 100),
      );
    }

    if (_needsQuestions(request.taskType)) {
      final desired = request.taskType == TeacherAiTaskType.grandTestBuilder
          ? request.questionCount.clamp(10, 80)
          : request.questionCount.clamp(1, 50);
      final questions = _repairQuestions(data['questions'], desired);
      if (questions.length != (data['questions'] as Iterable?)?.length) {
        warnings.add('Question set was normalized for safe form import.');
      }
      data['questions'] = questions;
      data['passingScore'] = _positiveInt(data['passingScore'], 70);
      data['durationMinutes'] = _positiveInt(data['durationMinutes'], 30);
      data['totalPoints'] = _positiveInt(
        data['totalPoints'] ?? data['points'],
        _contextInt(request, 'totalPoints', desired),
      );
      if (request.extraContext['includeRubric'] == true) {
        _ensureList(data, 'rubric', _numberedList('Rubric criterion', 4));
      }
    }

    if (request.taskType == TeacherAiTaskType.batchAnnouncementDraft) {
      _ensure(
        data,
        'title',
        request.currentTitle?.trim().isNotEmpty == true
            ? request.currentTitle!.trim()
            : 'Batch update',
      );
      final body = (data['body']?.toString().trim() ?? '').isNotEmpty
          ? data['body'].toString().trim()
          : (data['description']?.toString().trim() ?? '').isNotEmpty
          ? data['description'].toString().trim()
          : (data['improvedContent']?.toString().trim() ?? '');
      if (body.isEmpty) {
        data['body'] =
            'Review pending work and support students who need attention this week. '
            'Edit this note before saving.';
        warnings.add('Missing announcement body was repaired.');
      } else {
        data['body'] = body;
      }
    }

    final isValid = errors.isEmpty;
    return result.copyWith(
      data: data,
      qualityStatus: warnings.isEmpty ? 'Ready for Review' : 'Review Required',
      isValid: isValid,
      warnings: warnings,
      errors: errors,
    );
  }

  bool _needsQuestions(String taskType) {
    return taskType == TeacherAiTaskType.assignmentBuilder ||
        taskType == TeacherAiTaskType.quizBuilder ||
        taskType == TeacherAiTaskType.grandTestBuilder;
  }

  List<Map<String, dynamic>> _repairQuestions(Object? raw, int desired) {
    final source = raw is Iterable ? raw : const <Object?>[];
    final repaired = <Map<String, dynamic>>[];
    final usedIds = <String>{};
    for (final item in source) {
      if (item is! Map) continue;
      final question = item['question']?.toString().trim() ?? '';
      if (question.isEmpty) continue;
      final options = item['options'] is Iterable
          ? (item['options'] as Iterable)
                .map((option) => option?.toString().trim() ?? '')
                .where((option) => option.isNotEmpty)
                .toList()
          : <String>[];
      while (options.length < 4) {
        options.add('Option ${options.length + 1}');
      }
      final correct = item['correctAnswer']?.toString().trim() ?? options.first;
      final safeCorrect =
          options.any((option) => option.toLowerCase() == correct.toLowerCase())
          ? correct
          : options.first;
      var questionId = item['questionId']?.toString().trim() ?? '';
      if (questionId.isEmpty || usedIds.contains(questionId)) {
        questionId = 'q_${repaired.length + 1}';
        var n = 2;
        while (usedIds.contains(questionId)) {
          questionId = 'q_${repaired.length + 1}_$n';
          n++;
        }
      }
      usedIds.add(questionId);
      repaired.add({
        'questionId': questionId,
        'type': item['type']?.toString().trim() ?? 'mcq',
        'question': question,
        'options': options.take(4).toList(),
        'correctAnswer': safeCorrect,
        'explanation': item['explanation']?.toString().trim() ?? '',
        'marks': _positiveInt(item['marks'] ?? item['points'], 1),
        'points': _positiveInt(item['points'] ?? item['marks'], 1),
        'difficulty': item['difficulty']?.toString().trim() ?? 'Medium',
        'skillTag':
            item['skillTag']?.toString().trim() ??
            item['topicTag']?.toString().trim() ??
            '',
        'topicTag':
            item['topicTag']?.toString().trim() ??
            item['skillTag']?.toString().trim() ??
            '',
      });
      if (repaired.length == desired) break;
    }
    while (repaired.length < desired) {
      // Do not invent dummy MCQs — return only AI-validated items.
      break;
    }
    return repaired;
  }

  void _ensure(Map<String, dynamic> data, String key, String fallback) {
    if ((data[key]?.toString().trim() ?? '').isEmpty) data[key] = fallback;
  }

  void _ensureList(
    Map<String, dynamic> data,
    String key,
    List<String> fallback,
  ) {
    if (data[key] is! Iterable || (data[key] as Iterable).isEmpty) {
      data[key] = fallback;
    }
  }

  static int _positiveInt(Object? value, int fallback) {
    if (value is num && value > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }
    return fallback;
  }

  String _defaultTitle(TeacherAiGenerationRequestModel request) {
    return switch (request.taskType) {
      TeacherAiTaskType.lessonBuilder => 'AI Lesson Draft',
      TeacherAiTaskType.assignmentBuilder => 'AI Assignment Draft',
      TeacherAiTaskType.projectAssignmentBuilder =>
        'AI Project Assignment Draft',
      TeacherAiTaskType.quizBuilder => 'AI Quiz Draft',
      TeacherAiTaskType.grandTestBuilder => 'AI Grand Test Draft',
      TeacherAiTaskType.batchAnnouncementDraft => 'Batch Announcement Draft',
      TeacherAiTaskType.improveContent => 'Improved Content Draft',
      _ => 'AI Content Draft',
    };
  }

  List<String> _numberedList(String label, int count) {
    return List.generate(count.clamp(1, 20), (index) => '$label ${index + 1}');
  }

  int _contextInt(
    TeacherAiGenerationRequestModel request,
    String key,
    int fallback,
  ) {
    final value = request.extraContext[key];
    return _positiveInt(value, fallback);
  }
}
