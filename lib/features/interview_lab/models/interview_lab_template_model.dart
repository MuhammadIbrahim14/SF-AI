import 'package:cloud_firestore/cloud_firestore.dart';

import 'interview_lab_enums.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
}

/// Metadata template for a role track (does NOT store question text banks).
/// Questions are always generated via AI Gateway at session start.
/// Admins create / edit these — students only see active templates.
class InterviewLabTemplateModel {
  const InterviewLabTemplateModel({
    required this.templateId,
    required this.roleTrack,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.defaultDifficulty = InterviewLabDifficulty.medium,
    this.defaultQuestionCount = 8,
    this.suggestedCategories = const ['technical', 'behavioral'],
    this.focusTopics = const [],
    this.promptHint = '',
    this.sortOrder = 100,
    this.isActive = true,
  });

  final String templateId;
  final String roleTrack;
  final String title;
  final String description;
  final String defaultDifficulty;
  final int defaultQuestionCount;
  final List<String> suggestedCategories;

  /// Topics the AI should emphasize (e.g. MongoDB, Express, React, Node).
  final List<String> focusTopics;

  /// Extra instruction for question generation (admin-authored).
  final String promptHint;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : InterviewLabRoleTrack.displayLabel(roleTrack);

  factory InterviewLabTemplateModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabTemplateModel(
      templateId: data['templateId']?.toString() ?? doc.id,
      roleTrack: InterviewLabRoleTrack.slugify(
        data['roleTrack']?.toString() ?? InterviewLabRoleTrack.general,
      ),
      title: data['title']?.toString() ?? 'Interview Lab',
      description: data['description']?.toString() ?? '',
      defaultDifficulty: InterviewLabDifficulty.isValid(
            data['defaultDifficulty']?.toString() ?? '',
          )
          ? data['defaultDifficulty'].toString()
          : InterviewLabDifficulty.medium,
      defaultQuestionCount: _int(data['defaultQuestionCount'], 8).clamp(1, 50),
      suggestedCategories: _stringList(data['suggestedCategories']).isEmpty
          ? const ['technical', 'behavioral']
          : _stringList(data['suggestedCategories']),
      focusTopics: _stringList(data['focusTopics']),
      promptHint: data['promptHint']?.toString() ?? '',
      sortOrder: _int(data['sortOrder'], 100),
      isActive: data['isActive'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'templateId': templateId,
        'roleTrack': InterviewLabRoleTrack.slugify(roleTrack),
        'title': title,
        'description': description,
        'defaultDifficulty': defaultDifficulty,
        'defaultQuestionCount': defaultQuestionCount,
        'suggestedCategories': suggestedCategories,
        'focusTopics': focusTopics,
        'promptHint': promptHint,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'createdAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt),
        'updatedAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(updatedAt),
        'module': 'interview_lab',
      };

  InterviewLabTemplateModel copyWith({
    String? templateId,
    String? roleTrack,
    String? title,
    String? description,
    String? defaultDifficulty,
    int? defaultQuestionCount,
    List<String>? suggestedCategories,
    List<String>? focusTopics,
    String? promptHint,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InterviewLabTemplateModel(
      templateId: templateId ?? this.templateId,
      roleTrack: roleTrack ?? this.roleTrack,
      title: title ?? this.title,
      description: description ?? this.description,
      defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
      defaultQuestionCount: defaultQuestionCount ?? this.defaultQuestionCount,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      focusTopics: focusTopics ?? this.focusTopics,
      promptHint: promptHint ?? this.promptHint,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Append-only history row for candidate timeline.
class InterviewLabHistoryEntryModel {
  const InterviewLabHistoryEntryModel({
    required this.historyId,
    required this.candidateId,
    required this.sessionId,
    required this.eventType,
    required this.message,
    required this.createdAt,
    this.roleTrack,
    this.difficulty,
    this.overallScore,
    this.metadata = const {},
  });

  final String historyId;
  final String candidateId;
  final String sessionId;
  final String eventType;
  final String message;
  final String? roleTrack;
  final String? difficulty;
  final double? overallScore;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory InterviewLabHistoryEntryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabHistoryEntryModel(
      historyId: data['historyId']?.toString() ?? doc.id,
      candidateId: data['candidateId']?.toString() ?? '',
      sessionId: data['sessionId']?.toString() ?? '',
      eventType: data['eventType']?.toString() ?? 'unknown',
      message: data['message']?.toString() ?? '',
      roleTrack: data['roleTrack']?.toString(),
      difficulty: data['difficulty']?.toString(),
      overallScore: (data['overallScore'] as num?)?.toDouble(),
      metadata: Map<String, dynamic>.from(
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt: _date(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'historyId': historyId,
        'candidateId': candidateId,
        'sessionId': sessionId,
        'eventType': eventType,
        'message': message,
        'roleTrack': roleTrack,
        'difficulty': difficulty,
        'overallScore': overallScore,
        'metadata': metadata,
        'createdAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt),
        'module': 'interview_lab',
      };
}
