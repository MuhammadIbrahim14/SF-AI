import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

int _questionIdCounter = 0;

/// Unique id for new MCQ / grand-test draft questions.
///
/// Do not rely on [DateTime.now] alone — on Windows the clock often only
/// advances in milliseconds, so a tight AI-import loop would mint duplicates
/// and student answers would collide in a single map key.
String createMcqQuestionId() {
  _questionIdCounter += 1;
  return 'q_${DateTime.now().microsecondsSinceEpoch}_$_questionIdCounter';
}

String normalizeQuestionId(String? raw, int index) {
  final trimmed = (raw ?? '').trim();
  return trimmed.isEmpty ? 'q_${index + 1}' : trimmed;
}

/// Ensures each question has a non-empty, unique [McqQuestionModel.questionId].
List<McqQuestionModel> uniquifyMcqQuestionIds(
  List<McqQuestionModel> questions,
) {
  final used = <String>{};
  final result = <McqQuestionModel>[];
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

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
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

class AssignmentStatus {
  const AssignmentStatus._();

  static const String draft = 'draft';
  static const String published = 'published';
  static const String archived = 'archived';
  static const Set<String> values = {draft, published, archived};

  static String normalize(String? value) {
    final normalized = (value ?? draft).trim().toLowerCase();
    return values.contains(normalized) ? normalized : draft;
  }
}

class McqQuestionModel {
  const McqQuestionModel({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.marksPerQuestion,
    this.explanation = '',
  });

  final String questionId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final int marksPerQuestion;
  final String explanation;

  factory McqQuestionModel.fromJson(Map<String, dynamic> json, int index) {
    return McqQuestionModel(
      questionId: normalizeQuestionId(
        _stringValue(json['questionId']),
        index,
      ),
      question: _stringValue(json['question']),
      options: _stringList(json['options']),
      correctAnswer: _stringValue(json['correctAnswer']),
      marksPerQuestion: _intValue(json['marksPerQuestion'], 1),
      explanation: _stringValue(json['explanation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'marksPerQuestion': marksPerQuestion,
      'explanation': explanation,
    };
  }

  McqQuestionModel copyWith({
    String? questionId,
    String? question,
    List<String>? options,
    String? correctAnswer,
    int? marksPerQuestion,
    String? explanation,
  }) {
    return McqQuestionModel(
      questionId: questionId ?? this.questionId,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
      explanation: explanation ?? this.explanation,
    );
  }
}

class McqAssignmentModel {
  const McqAssignmentModel({
    required this.assignmentId,
    required this.courseId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.skillsCovered,
    required this.passingMarks,
    required this.totalMarks,
    required this.timeLimitMinutes,
    required this.dueDate,
    required this.questions,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.archivedAt,
  });

  final String assignmentId;
  final String courseId;
  final String teacherId;
  final String title;
  final String description;
  final List<String> skillsCovered;
  final int passingMarks;
  final int totalMarks;
  final int timeLimitMinutes;
  final DateTime? dueDate;
  final List<McqQuestionModel> questions;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == AssignmentStatus.draft;
  bool get isPublished => status == AssignmentStatus.published;
  bool get isArchived => status == AssignmentStatus.archived;

  factory McqAssignmentModel.fromFirestore(
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

    return McqAssignmentModel(
      assignmentId: doc.id,
      courseId: _stringValue(data['courseId']),
      teacherId: _stringValue(data['teacherId']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      skillsCovered: _stringList(data['skillsCovered']),
      passingMarks: _intValue(data['passingMarks']),
      totalMarks: _intValue(data['totalMarks']),
      timeLimitMinutes: _intValue(data['timeLimitMinutes'], 30),
      dueDate: _nullableDate(data['dueDate']),
      questions: uniquifyMcqQuestionIds([
        for (var index = 0; index < questions.length; index++)
          McqQuestionModel.fromJson(questions[index], index),
      ]),
      status: AssignmentStatus.normalize(data['status']?.toString()),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      publishedAt: _nullableDate(data['publishedAt']),
      archivedAt: _nullableDate(data['archivedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'mcq',
      'courseId': courseId,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'skillsCovered': skillsCovered,
      'passingMarks': passingMarks,
      'totalMarks': totalMarks,
      'timeLimitMinutes': timeLimitMinutes,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'questions': questions.map((question) => question.toJson()).toList(),
      'status': AssignmentStatus.normalize(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  McqAssignmentModel copyWith({
    String? assignmentId,
    String? courseId,
    String? teacherId,
    String? title,
    String? description,
    List<String>? skillsCovered,
    int? passingMarks,
    int? totalMarks,
    int? timeLimitMinutes,
    DateTime? dueDate,
    List<McqQuestionModel>? questions,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? archivedAt,
    bool clearDueDate = false,
    bool clearPublishedAt = false,
    bool clearArchivedAt = false,
  }) {
    return McqAssignmentModel(
      assignmentId: assignmentId ?? this.assignmentId,
      courseId: courseId ?? this.courseId,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      skillsCovered: skillsCovered ?? this.skillsCovered,
      passingMarks: passingMarks ?? this.passingMarks,
      totalMarks: totalMarks ?? this.totalMarks,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      questions: questions ?? this.questions,
      status: AssignmentStatus.normalize(status ?? this.status),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: clearPublishedAt ? null : publishedAt ?? this.publishedAt,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    );
  }
}
