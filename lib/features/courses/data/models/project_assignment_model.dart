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

class ProjectAssignmentModel {
  const ProjectAssignmentModel({
    required this.assignmentId,
    required this.courseId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.requirements,
    required this.instructions,
    required this.maxMarks,
    required this.dueDate,
    required this.skillsCovered,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.archivedAt,
    this.projectGoal = '',
    this.realWorldScenario = '',
    this.learningObjectives = const <String>[],
    this.skillsDemonstrated = const <String>[],
    this.deliverables = const <String>[],
    this.milestones = const <String>[],
    this.acceptanceCriteria = const <String>[],
    this.submissionChecklist = const <String>[],
    this.estimatedCompletionHours = 0,
    this.difficultyLevel = 'Beginner',
    this.rubricCriteria = const <String>[],
    this.starterGuidance = const <String>[],
    this.resources = const <String>[],
  });

  final String assignmentId;
  final String courseId;
  final String teacherId;
  final String title;
  final String description;
  final List<String> requirements;
  final String instructions;
  final int maxMarks;
  final DateTime? dueDate;
  final List<String> skillsCovered;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final String projectGoal;
  final String realWorldScenario;
  final List<String> learningObjectives;
  final List<String> skillsDemonstrated;
  final List<String> deliverables;
  final List<String> milestones;
  final List<String> acceptanceCriteria;
  final List<String> submissionChecklist;
  final int estimatedCompletionHours;
  final String difficultyLevel;
  final List<String> rubricCriteria;
  final List<String> starterGuidance;
  final List<String> resources;

  bool get isDraft => status == AssignmentStatus.draft;
  bool get isPublished => status == AssignmentStatus.published;
  bool get isArchived => status == AssignmentStatus.archived;

  factory ProjectAssignmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProjectAssignmentModel(
      assignmentId: doc.id,
      courseId: _stringValue(data['courseId']),
      teacherId: _stringValue(data['teacherId']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      requirements: _stringList(data['requirements']),
      instructions: _stringValue(data['instructions']),
      maxMarks: _intValue(data['maxMarks']),
      dueDate: _nullableDate(data['dueDate']),
      skillsCovered: _stringList(data['skillsCovered']),
      status: AssignmentStatus.normalize(data['status']?.toString()),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      publishedAt: _nullableDate(data['publishedAt']),
      archivedAt: _nullableDate(data['archivedAt']),
      projectGoal: _stringValue(data['projectGoal']),
      realWorldScenario: _stringValue(data['realWorldScenario']),
      learningObjectives: _stringList(data['learningObjectives']),
      skillsDemonstrated: _stringList(data['skillsDemonstrated']),
      deliverables: _stringList(data['deliverables']),
      milestones: _stringList(data['milestones']),
      acceptanceCriteria: _stringList(data['acceptanceCriteria']),
      submissionChecklist: _stringList(data['submissionChecklist']),
      estimatedCompletionHours: _intValue(data['estimatedCompletionHours']),
      difficultyLevel: _stringValue(data['difficultyLevel'], 'Beginner'),
      rubricCriteria: _stringList(data['rubricCriteria']),
      starterGuidance: _stringList(data['starterGuidance']),
      resources: _stringList(data['resources']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'project',
      'courseId': courseId,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'requirements': requirements,
      'instructions': instructions,
      'maxMarks': maxMarks,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'skillsCovered': skillsCovered,
      'status': AssignmentStatus.normalize(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
      'projectGoal': projectGoal,
      'realWorldScenario': realWorldScenario,
      'learningObjectives': learningObjectives,
      'skillsDemonstrated': skillsDemonstrated,
      'deliverables': deliverables,
      'milestones': milestones,
      'acceptanceCriteria': acceptanceCriteria,
      'submissionChecklist': submissionChecklist,
      'estimatedCompletionHours': estimatedCompletionHours,
      'difficultyLevel': difficultyLevel,
      'rubricCriteria': rubricCriteria,
      'starterGuidance': starterGuidance,
      'resources': resources,
    };
  }

  ProjectAssignmentModel copyWith({
    String? assignmentId,
    String? courseId,
    String? teacherId,
    String? title,
    String? description,
    List<String>? requirements,
    String? instructions,
    int? maxMarks,
    DateTime? dueDate,
    List<String>? skillsCovered,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? archivedAt,
    bool clearDueDate = false,
    bool clearPublishedAt = false,
    bool clearArchivedAt = false,
    String? projectGoal,
    String? realWorldScenario,
    List<String>? learningObjectives,
    List<String>? skillsDemonstrated,
    List<String>? deliverables,
    List<String>? milestones,
    List<String>? acceptanceCriteria,
    List<String>? submissionChecklist,
    int? estimatedCompletionHours,
    String? difficultyLevel,
    List<String>? rubricCriteria,
    List<String>? starterGuidance,
    List<String>? resources,
  }) {
    return ProjectAssignmentModel(
      assignmentId: assignmentId ?? this.assignmentId,
      courseId: courseId ?? this.courseId,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      instructions: instructions ?? this.instructions,
      maxMarks: maxMarks ?? this.maxMarks,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      skillsCovered: skillsCovered ?? this.skillsCovered,
      status: AssignmentStatus.normalize(status ?? this.status),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: clearPublishedAt ? null : publishedAt ?? this.publishedAt,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
      projectGoal: projectGoal ?? this.projectGoal,
      realWorldScenario: realWorldScenario ?? this.realWorldScenario,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      skillsDemonstrated: skillsDemonstrated ?? this.skillsDemonstrated,
      deliverables: deliverables ?? this.deliverables,
      milestones: milestones ?? this.milestones,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      submissionChecklist: submissionChecklist ?? this.submissionChecklist,
      estimatedCompletionHours:
          estimatedCompletionHours ?? this.estimatedCompletionHours,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      rubricCriteria: rubricCriteria ?? this.rubricCriteria,
      starterGuidance: starterGuidance ?? this.starterGuidance,
      resources: resources ?? this.resources,
    );
  }
}
