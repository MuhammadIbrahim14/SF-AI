import 'package:cloud_firestore/cloud_firestore.dart';

import 'mcq_assignment_model.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase().trim() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

class GrandTestQuestionModel {
  const GrandTestQuestionModel({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.marks,
    required this.difficulty,
    required this.skillTag,
    this.explanation = '',
  });

  final String questionId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final int marks;
  final String difficulty;
  final String skillTag;
  final String explanation;

  factory GrandTestQuestionModel.fromJson(
    Map<String, dynamic> json,
    int index,
  ) {
    return GrandTestQuestionModel(
      questionId: normalizeQuestionId(
        _stringValue(json['questionId']),
        index,
      ),
      question: _stringValue(json['question']),
      options: _stringList(json['options']),
      correctAnswer: _stringValue(json['correctAnswer']),
      marks: _intValue(json['marks'], 1),
      difficulty: _stringValue(json['difficulty'], 'Medium'),
      skillTag: _stringValue(json['skillTag']),
      explanation: _stringValue(json['explanation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'marks': marks,
      'difficulty': difficulty,
      'skillTag': skillTag,
      'explanation': explanation,
    };
  }

  GrandTestQuestionModel copyWith({
    String? questionId,
    String? question,
    List<String>? options,
    String? correctAnswer,
    int? marks,
    String? difficulty,
    String? skillTag,
    String? explanation,
  }) {
    return GrandTestQuestionModel(
      questionId: questionId ?? this.questionId,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      marks: marks ?? this.marks,
      difficulty: difficulty ?? this.difficulty,
      skillTag: skillTag ?? this.skillTag,
      explanation: explanation ?? this.explanation,
    );
  }
}

/// Ensures each grand-test question has a non-empty, unique [questionId].
List<GrandTestQuestionModel> uniquifyGrandTestQuestionIds(
  List<GrandTestQuestionModel> questions,
) {
  final used = <String>{};
  final result = <GrandTestQuestionModel>[];
  for (var i = 0; i < questions.length; i++) {
    var id = questions[i].questionId.trim();
    if (id.isEmpty || used.contains(id)) {
      id = 'q_${i + 1}';
      var n = 2;
      while (used.contains(id)) {
        id = 'q_${i + 1}_$n';
        n++;
      }
    }
    used.add(id);
    result.add(
      id == questions[i].questionId
          ? questions[i]
          : questions[i].copyWith(questionId: id),
    );
  }
  return result;
}

class GrandTestModel {
  const GrandTestModel({
    required this.grandTestId,
    required this.courseId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.instructions,
    required this.skillsCovered,
    required this.totalMarks,
    required this.passingMarks,
    required this.durationMinutes,
    required this.difficulty,
    required this.status,
    required this.questions,
    required this.requiredLessonProgressPercent,
    required this.requiredAssignmentCompletionPercent,
    required this.requiredAverageScorePercent,
    required this.requireProjectSubmission,
    required this.maxAttempts,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.archivedAt,
  });

  final String grandTestId;
  final String courseId;
  final String teacherId;
  final String title;
  final String description;
  final String instructions;
  final List<String> skillsCovered;
  final int totalMarks;
  final int passingMarks;
  final int durationMinutes;
  final String difficulty;
  final String status;
  final List<GrandTestQuestionModel> questions;
  final double requiredLessonProgressPercent;
  final double requiredAssignmentCompletionPercent;
  final double requiredAverageScorePercent;
  final bool requireProjectSubmission;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  bool get isPublished => status == AssignmentStatus.published;
  bool get isArchived => status == AssignmentStatus.archived;

  factory GrandTestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawQuestions = data['questions'];
    final questions = rawQuestions is Iterable
        ? rawQuestions
              .whereType<Map>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList()
        : const <Map<String, dynamic>>[];

    return GrandTestModel(
      grandTestId: doc.id,
      courseId: _stringValue(data['courseId']),
      teacherId: _stringValue(data['teacherId']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      instructions: _stringValue(data['instructions']),
      skillsCovered: _stringList(data['skillsCovered']),
      totalMarks: _intValue(data['totalMarks']),
      passingMarks: _intValue(data['passingMarks']),
      durationMinutes: _intValue(data['durationMinutes'], 60),
      difficulty: _stringValue(data['difficulty'], 'Medium'),
      status: AssignmentStatus.normalize(data['status']?.toString()),
      questions: uniquifyGrandTestQuestionIds([
        for (var index = 0; index < questions.length; index++)
          GrandTestQuestionModel.fromJson(questions[index], index),
      ]),
      requiredLessonProgressPercent: _doubleValue(
        data['requiredLessonProgressPercent'],
        80,
      ),
      requiredAssignmentCompletionPercent: _doubleValue(
        data['requiredAssignmentCompletionPercent'],
        70,
      ),
      requiredAverageScorePercent: _doubleValue(
        data['requiredAverageScorePercent'],
        60,
      ),
      requireProjectSubmission: _boolValue(
        data['requireProjectSubmission'],
        true,
      ),
      maxAttempts: _intValue(data['maxAttempts'], 1),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      publishedAt: _nullableDate(data['publishedAt']),
      archivedAt: _nullableDate(data['archivedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'instructions': instructions,
      'skillsCovered': skillsCovered,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'status': AssignmentStatus.normalize(status),
      'questions': questions.map((question) => question.toJson()).toList(),
      'requiredLessonProgressPercent': requiredLessonProgressPercent,
      'requiredAssignmentCompletionPercent':
          requiredAssignmentCompletionPercent,
      'requiredAverageScorePercent': requiredAverageScorePercent,
      'requireProjectSubmission': requireProjectSubmission,
      'maxAttempts': maxAttempts,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  GrandTestModel copyWith({
    String? grandTestId,
    String? courseId,
    String? teacherId,
    String? title,
    String? description,
    String? instructions,
    List<String>? skillsCovered,
    int? totalMarks,
    int? passingMarks,
    int? durationMinutes,
    String? difficulty,
    String? status,
    List<GrandTestQuestionModel>? questions,
    double? requiredLessonProgressPercent,
    double? requiredAssignmentCompletionPercent,
    double? requiredAverageScorePercent,
    bool? requireProjectSubmission,
    int? maxAttempts,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) {
    return GrandTestModel(
      grandTestId: grandTestId ?? this.grandTestId,
      courseId: courseId ?? this.courseId,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      skillsCovered: skillsCovered ?? this.skillsCovered,
      totalMarks: totalMarks ?? this.totalMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      difficulty: difficulty ?? this.difficulty,
      status: AssignmentStatus.normalize(status ?? this.status),
      questions: questions ?? this.questions,
      requiredLessonProgressPercent:
          requiredLessonProgressPercent ?? this.requiredLessonProgressPercent,
      requiredAssignmentCompletionPercent:
          requiredAssignmentCompletionPercent ??
          this.requiredAssignmentCompletionPercent,
      requiredAverageScorePercent:
          requiredAverageScorePercent ?? this.requiredAverageScorePercent,
      requireProjectSubmission:
          requireProjectSubmission ?? this.requireProjectSubmission,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
