import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase().trim() == 'true';
  return false;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

class LessonCompletionMode {
  const LessonCompletionMode._();

  static const simple = 'simple';
  static const timeBased = 'timeBased';
  static const checkpoint = 'checkpoint';
  static const miniQuiz = 'miniQuiz';
  static const practical = 'practical';
  static const strict = 'strict';

  static const values = <String>[
    simple,
    timeBased,
    checkpoint,
    miniQuiz,
    practical,
    strict,
  ];

  static String normalize(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return simple;
    return values.contains(text) ? text : simple;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      timeBased => 'Time-based',
      checkpoint => 'Checkpoint',
      miniQuiz => 'Mini quiz',
      practical => 'Practical reflection',
      strict => 'Strict validation',
      _ => 'Simple',
    };
  }
}

class LessonCheckpointModel {
  const LessonCheckpointModel({
    required this.id,
    required this.question,
    required this.type,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.points,
    required this.required,
    required this.order,
  });

  final String id;
  final String question;
  final String type;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final int points;
  final bool required;
  final int order;

  bool get isQuizLike => type == 'mcq' || type == 'trueFalse';

  factory LessonCheckpointModel.fromJson(Map<String, dynamic> json, int index) {
    return LessonCheckpointModel(
      id: _stringValue(json['id'], 'checkpoint_${index + 1}'),
      question: _stringValue(json['question']),
      type: _stringValue(json['type'], 'reflection'),
      options: _stringList(json['options']),
      correctAnswer: _stringValue(json['correctAnswer']),
      explanation: _stringValue(json['explanation']),
      points: _intValue(json['points']),
      required: json.containsKey('required')
          ? _boolValue(json['required'])
          : true,
      order: _intValue(json['order']) == 0
          ? index + 1
          : _intValue(json['order']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'points': points,
      'required': required,
      'order': order,
    };
  }
}

class LessonModel {
  const LessonModel({
    required this.lessonId,
    required this.courseId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.videoUrl,
    required this.pdfLinks,
    required this.externalLinks,
    required this.durationMinutes,
    required this.isPreview,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.learningObjectives = const <String>[],
    this.skillsCovered = const <String>[],
    this.prerequisites = const <String>[],
    this.estimatedMinutes = 0,
    this.keyTakeaways = const <String>[],
    this.lessonDifficulty = 'Beginner',
    this.completionMode = LessonCompletionMode.simple,
    this.minimumReadSeconds = 0,
    this.minimumScrollPercent = 0,
    this.requireCheckpoints = false,
    this.requireMiniQuizPass = false,
    this.requirePracticalReflection = false,
    this.passingScorePercent = 70,
    this.allowRetry = true,
    this.maxAttempts = 0,
    this.completionCriteriaSummary = '',
    this.checkpoints = const <LessonCheckpointModel>[],
  });

  final String lessonId;
  final String courseId;
  final String teacherId;
  final String title;
  final String description;
  final int orderIndex;
  final String videoUrl;
  final List<String> pdfLinks;
  final List<String> externalLinks;
  final int durationMinutes;
  final bool isPreview;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> learningObjectives;
  final List<String> skillsCovered;
  final List<String> prerequisites;
  final int estimatedMinutes;
  final List<String> keyTakeaways;
  final String lessonDifficulty;
  final String completionMode;
  final int minimumReadSeconds;
  final int minimumScrollPercent;
  final bool requireCheckpoints;
  final bool requireMiniQuizPass;
  final bool requirePracticalReflection;
  final int passingScorePercent;
  final bool allowRetry;
  final int maxAttempts;
  final String completionCriteriaSummary;
  final List<LessonCheckpointModel> checkpoints;

  bool get hasStrictCompletion =>
      completionMode != LessonCompletionMode.simple ||
      minimumReadSeconds > 0 ||
      minimumScrollPercent > 0 ||
      requireCheckpoints ||
      requireMiniQuizPass ||
      requirePracticalReflection ||
      checkpoints.isNotEmpty;

  factory LessonModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LessonModel(
      lessonId: data['lessonId'] is String
          ? data['lessonId'] as String
          : doc.id,
      courseId: data['courseId'] is String ? data['courseId'] as String : '',
      teacherId: data['teacherId'] is String ? data['teacherId'] as String : '',
      title: data['title'] is String ? data['title'] as String : '',
      description: data['description'] is String
          ? data['description'] as String
          : '',
      orderIndex: _intValue(data['orderIndex']),
      videoUrl: data['videoUrl'] is String ? data['videoUrl'] as String : '',
      pdfLinks: _stringList(data['pdfLinks']),
      externalLinks: _stringList(data['externalLinks']),
      durationMinutes: _intValue(data['durationMinutes']),
      isPreview: _boolValue(data['isPreview']),
      isArchived: _boolValue(data['isArchived']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      learningObjectives: _stringList(data['learningObjectives']),
      skillsCovered: _stringList(data['skillsCovered']),
      prerequisites: _stringList(data['prerequisites']),
      estimatedMinutes: _intValue(data['estimatedMinutes']),
      keyTakeaways: _stringList(data['keyTakeaways']),
      lessonDifficulty: _stringValue(data['lessonDifficulty'], 'Beginner'),
      completionMode: LessonCompletionMode.normalize(data['completionMode']),
      minimumReadSeconds: _intValue(data['minimumReadSeconds']),
      minimumScrollPercent: _intValue(data['minimumScrollPercent']),
      requireCheckpoints: _boolValue(data['requireCheckpoints']),
      requireMiniQuizPass: _boolValue(data['requireMiniQuizPass']),
      requirePracticalReflection: _boolValue(
        data['requirePracticalReflection'],
      ),
      passingScorePercent: _intValue(data['passingScorePercent']) == 0
          ? 70
          : _intValue(data['passingScorePercent']),
      allowRetry: data.containsKey('allowRetry')
          ? _boolValue(data['allowRetry'])
          : true,
      maxAttempts: _intValue(data['maxAttempts']),
      completionCriteriaSummary: _stringValue(
        data['completionCriteriaSummary'],
      ),
      checkpoints:
          (data['checkpoints'] is Iterable
                  ? List<Object?>.from(data['checkpoints'] as Iterable)
                  : const <Object?>[])
              .asMap()
              .entries
              .where((entry) => entry.value is Map)
              .map(
                (entry) => LessonCheckpointModel.fromJson(
                  Map<String, dynamic>.from(entry.value! as Map),
                  entry.key,
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lessonId': lessonId,
      'courseId': courseId,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'orderIndex': orderIndex,
      'videoUrl': videoUrl,
      'pdfLinks': pdfLinks,
      'externalLinks': externalLinks,
      'durationMinutes': durationMinutes,
      'isPreview': isPreview,
      'isArchived': isArchived,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'learningObjectives': learningObjectives,
      'skillsCovered': skillsCovered,
      'prerequisites': prerequisites,
      'estimatedMinutes': estimatedMinutes,
      'keyTakeaways': keyTakeaways,
      'lessonDifficulty': lessonDifficulty,
      'completionMode': LessonCompletionMode.normalize(completionMode),
      'minimumReadSeconds': minimumReadSeconds,
      'minimumScrollPercent': minimumScrollPercent,
      'requireCheckpoints': requireCheckpoints,
      'requireMiniQuizPass': requireMiniQuizPass,
      'requirePracticalReflection': requirePracticalReflection,
      'passingScorePercent': passingScorePercent,
      'allowRetry': allowRetry,
      'maxAttempts': maxAttempts,
      'completionCriteriaSummary': completionCriteriaSummary,
      'checkpoints': checkpoints
          .map((checkpoint) => checkpoint.toJson())
          .toList(),
    };
  }

  LessonModel copyWith({
    String? lessonId,
    String? courseId,
    String? teacherId,
    String? title,
    String? description,
    int? orderIndex,
    String? videoUrl,
    List<String>? pdfLinks,
    List<String>? externalLinks,
    int? durationMinutes,
    bool? isPreview,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? learningObjectives,
    List<String>? skillsCovered,
    List<String>? prerequisites,
    int? estimatedMinutes,
    List<String>? keyTakeaways,
    String? lessonDifficulty,
    String? completionMode,
    int? minimumReadSeconds,
    int? minimumScrollPercent,
    bool? requireCheckpoints,
    bool? requireMiniQuizPass,
    bool? requirePracticalReflection,
    int? passingScorePercent,
    bool? allowRetry,
    int? maxAttempts,
    String? completionCriteriaSummary,
    List<LessonCheckpointModel>? checkpoints,
  }) {
    return LessonModel(
      lessonId: lessonId ?? this.lessonId,
      courseId: courseId ?? this.courseId,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      videoUrl: videoUrl ?? this.videoUrl,
      pdfLinks: pdfLinks ?? this.pdfLinks,
      externalLinks: externalLinks ?? this.externalLinks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isPreview: isPreview ?? this.isPreview,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      skillsCovered: skillsCovered ?? this.skillsCovered,
      prerequisites: prerequisites ?? this.prerequisites,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      lessonDifficulty: lessonDifficulty ?? this.lessonDifficulty,
      completionMode: completionMode ?? this.completionMode,
      minimumReadSeconds: minimumReadSeconds ?? this.minimumReadSeconds,
      minimumScrollPercent: minimumScrollPercent ?? this.minimumScrollPercent,
      requireCheckpoints: requireCheckpoints ?? this.requireCheckpoints,
      requireMiniQuizPass: requireMiniQuizPass ?? this.requireMiniQuizPass,
      requirePracticalReflection:
          requirePracticalReflection ?? this.requirePracticalReflection,
      passingScorePercent: passingScorePercent ?? this.passingScorePercent,
      allowRetry: allowRetry ?? this.allowRetry,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      completionCriteriaSummary:
          completionCriteriaSummary ?? this.completionCriteriaSummary,
      checkpoints: checkpoints ?? this.checkpoints,
    );
  }
}
