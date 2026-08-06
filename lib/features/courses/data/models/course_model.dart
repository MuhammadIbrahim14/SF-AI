import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase().trim() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

List<String> _stringListValue(Object? value) {
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

DateTime? _nullableDateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) {
  return _nullableDateValue(value) ?? DateTime.now();
}

class CourseStatus {
  const CourseStatus._();

  static const String draft = 'draft';
  static const String published = 'published';
  static const String archived = 'archived';

  static const Set<String> values = {draft, published, archived};

  static String normalize(String? value) {
    final normalized = (value ?? draft).trim().toLowerCase();
    return values.contains(normalized) ? normalized : draft;
  }
}

class CourseModel {
  const CourseModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.level,
    required this.language,
    required this.skillsCovered,
    required this.tags,
    required this.prerequisites,
    required this.learningOutcomes,
    required this.targetAudience,
    required this.youtubeIntroUrl,
    required this.pdfResourceLinks,
    required this.externalLinks,
    required this.durationMinutes,
    required this.lessonCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailUrl,
    this.publishedAt,
    this.archivedAt,
  });

  final String id;
  final String teacherId;
  final String teacherName;
  final String title;
  final String subtitle;
  final String description;
  final String category;
  final String level;
  final String language;
  final List<String> skillsCovered;
  final List<String> tags;
  final List<String> prerequisites;
  final List<String> learningOutcomes;
  final List<String> targetAudience;
  final String youtubeIntroUrl;
  final List<String> pdfResourceLinks;
  final List<String> externalLinks;
  final int durationMinutes;
  final int lessonCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? thumbnailUrl;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == CourseStatus.draft;
  bool get isPublished => status == CourseStatus.published;
  bool get isArchived => status == CourseStatus.archived;
  DateTime get publishedAtValue => publishedAt ?? updatedAt;

  factory CourseModel.createDraft({
    required String teacherId,
    String teacherName = '',
    required String title,
    String subtitle = '',
    required String description,
    required String category,
    required String level,
    String language = 'English',
    List<String> skillsCovered = const <String>[],
    List<String> tags = const <String>[],
    List<String> prerequisites = const <String>[],
    List<String> learningOutcomes = const <String>[],
    List<String> targetAudience = const <String>[],
    String youtubeIntroUrl = '',
    List<String> pdfResourceLinks = const <String>[],
    List<String> externalLinks = const <String>[],
    int durationMinutes = 0,
    int lessonCount = 0,
    String? thumbnailUrl,
  }) {
    final now = DateTime.now();
    return CourseModel(
      id: '',
      teacherId: teacherId,
      teacherName: teacherName,
      title: title,
      subtitle: subtitle,
      description: description,
      category: category,
      level: level,
      language: language,
      skillsCovered: skillsCovered,
      tags: tags,
      prerequisites: prerequisites,
      learningOutcomes: learningOutcomes,
      targetAudience: targetAudience,
      youtubeIntroUrl: youtubeIntroUrl,
      pdfResourceLinks: pdfResourceLinks,
      externalLinks: externalLinks,
      durationMinutes: durationMinutes,
      lessonCount: lessonCount,
      status: CourseStatus.draft,
      createdAt: now,
      updatedAt: now,
      thumbnailUrl: thumbnailUrl,
    );
  }

  factory CourseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final normalizedStatus = CourseStatus.normalize(data['status']?.toString());
    final status =
        normalizedStatus == CourseStatus.draft &&
            _boolValue(data['isPublished'])
        ? CourseStatus.published
        : normalizedStatus;

    return CourseModel(
      id: doc.id,
      teacherId: _stringValue(data['teacherId']),
      teacherName: _stringValue(data['teacherName'], 'Teacher'),
      title: _stringValue(data['title']),
      subtitle: _stringValue(data['subtitle']),
      description: _stringValue(data['description']),
      category: _stringValue(data['category']),
      level: _stringValue(
        data['difficulty'],
        _stringValue(data['level'], 'Beginner'),
      ),
      language: _stringValue(data['language'], 'English'),
      skillsCovered: _stringListValue(data['skillsCovered']),
      tags: _stringListValue(data['tags']),
      prerequisites: _stringListValue(data['prerequisites']),
      learningOutcomes: _stringListValue(data['learningOutcomes']),
      targetAudience: _stringListValue(data['targetAudience']),
      youtubeIntroUrl: _stringValue(data['youtubeIntroUrl']),
      pdfResourceLinks: _stringListValue(data['pdfResourceLinks']),
      externalLinks: _stringListValue(data['externalLinks']),
      durationMinutes: _intValue(data['durationMinutes']),
      lessonCount: _intValue(data['lessonCount']),
      status: status,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      thumbnailUrl:
          _stringValue(
            data['coverImageUrl'],
            _stringValue(data['thumbnailUrl']),
          ).trim().isEmpty
          ? null
          : _stringValue(
              data['coverImageUrl'],
              _stringValue(data['thumbnailUrl']),
            ),
      publishedAt: _nullableDateValue(data['publishedAt']),
      archivedAt: _nullableDateValue(data['archivedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'category': category,
      'level': level,
      'difficulty': level,
      'language': language,
      'skillsCovered': skillsCovered,
      'tags': tags,
      'prerequisites': prerequisites,
      'learningOutcomes': learningOutcomes,
      'targetAudience': targetAudience,
      'youtubeIntroUrl': youtubeIntroUrl,
      'pdfResourceLinks': pdfResourceLinks,
      'externalLinks': externalLinks,
      'durationMinutes': durationMinutes,
      'lessonCount': lessonCount,
      'status': CourseStatus.normalize(status),
      'isPublished': isPublished,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
        'thumbnailUrl': thumbnailUrl,
      if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
        'coverImageUrl': thumbnailUrl,
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  CourseModel copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? title,
    String? subtitle,
    String? description,
    String? category,
    String? level,
    String? language,
    List<String>? skillsCovered,
    List<String>? tags,
    List<String>? prerequisites,
    List<String>? learningOutcomes,
    List<String>? targetAudience,
    String? youtubeIntroUrl,
    List<String>? pdfResourceLinks,
    List<String>? externalLinks,
    int? durationMinutes,
    int? lessonCount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailUrl,
    DateTime? publishedAt,
    DateTime? archivedAt,
    bool clearThumbnailUrl = false,
    bool clearPublishedAt = false,
    bool clearArchivedAt = false,
  }) {
    return CourseModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
      level: level ?? this.level,
      language: language ?? this.language,
      skillsCovered: skillsCovered ?? this.skillsCovered,
      tags: tags ?? this.tags,
      prerequisites: prerequisites ?? this.prerequisites,
      learningOutcomes: learningOutcomes ?? this.learningOutcomes,
      targetAudience: targetAudience ?? this.targetAudience,
      youtubeIntroUrl: youtubeIntroUrl ?? this.youtubeIntroUrl,
      pdfResourceLinks: pdfResourceLinks ?? this.pdfResourceLinks,
      externalLinks: externalLinks ?? this.externalLinks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      lessonCount: lessonCount ?? this.lessonCount,
      status: CourseStatus.normalize(status ?? this.status),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thumbnailUrl: clearThumbnailUrl
          ? null
          : thumbnailUrl ?? this.thumbnailUrl,
      publishedAt: clearPublishedAt ? null : publishedAt ?? this.publishedAt,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    );
  }
}
