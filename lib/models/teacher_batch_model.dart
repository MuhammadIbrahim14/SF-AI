import 'package:cloud_firestore/cloud_firestore.dart';

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(RegExp(r'[\n,]'))
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

DateTime _date(Object? value) => _nullableDate(value) ?? DateTime.now();

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class TeacherBatchStatus {
  const TeacherBatchStatus._();

  static const active = 'active';
  static const archived = 'archived';

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == archived ? archived : active;
  }
}

class TeacherBatchModel {
  const TeacherBatchModel({
    required this.batchId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.courseIds,
    required this.studentIds,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.inviteCode = '',
    this.inviteEnabled = false,
  });

  final String batchId;
  final String teacherId;
  final String title;
  final String description;
  final List<String> courseIds;
  final List<String> studentIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String inviteCode;
  final bool inviteEnabled;

  bool get isArchived => status == TeacherBatchStatus.archived;

  bool get hasActiveInvite =>
      inviteEnabled && inviteCode.trim().isNotEmpty;

  factory TeacherBatchModel.empty(String teacherId) {
    final now = DateTime.now();
    return TeacherBatchModel(
      batchId: '',
      teacherId: teacherId,
      title: '',
      description: '',
      courseIds: const <String>[],
      studentIds: const <String>[],
      startDate: null,
      endDate: null,
      status: TeacherBatchStatus.active,
      createdAt: now,
      updatedAt: now,
      inviteCode: '',
      inviteEnabled: false,
    );
  }

  factory TeacherBatchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherBatchModel(
      batchId: doc.id,
      teacherId: _string(data['teacherId']),
      title: _string(data['title'], 'Untitled batch'),
      description: _string(data['description']),
      courseIds: _stringList(data['courseIds']),
      studentIds: _stringList(data['studentIds']),
      startDate: _nullableDate(data['startDate']),
      endDate: _nullableDate(data['endDate']),
      status: TeacherBatchStatus.normalize(_string(data['status'])),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      inviteCode: _string(data['inviteCode']).toUpperCase(),
      inviteEnabled: data['inviteEnabled'] == true,
    );
  }

  /// Core batch fields for create/update. Invite fields are written separately
  /// via [TeacherBatchActionNotifier.updateInvite] so editor saves preserve them
  /// under merge writes when omitted.
  Map<String, dynamic> toJson({bool includeInvite = false}) {
    return {
      'teacherId': teacherId,
      'title': title.trim(),
      'description': description.trim(),
      'courseIds': courseIds,
      'studentIds': studentIds,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'status': TeacherBatchStatus.normalize(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (includeInvite) ...{
        'inviteCode': inviteCode.trim().toUpperCase(),
        'inviteEnabled': inviteEnabled,
      },
    };
  }

  TeacherBatchModel copyWith({
    String? batchId,
    String? teacherId,
    String? title,
    String? description,
    List<String>? courseIds,
    List<String>? studentIds,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? inviteCode,
    bool? inviteEnabled,
  }) {
    return TeacherBatchModel(
      batchId: batchId ?? this.batchId,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      courseIds: courseIds ?? this.courseIds,
      studentIds: studentIds ?? this.studentIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteEnabled: inviteEnabled ?? this.inviteEnabled,
    );
  }
}
