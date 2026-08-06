import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified in-app notification document (`user_notifications/{id}`).
class UserNotificationModel {
  const UserNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.relatedPath,
    required this.createdAt,
    this.read = false,
    this.category = '',
    this.event = '',
    this.actorId,
    this.actorName,
    this.actorRole,
    this.routeName,
    this.routeParams = const <String, String>{},
    this.priority = 'normal',
    this.meta = const <String, dynamic>{},
    this.applicationId,
  });

  final String id;
  final String userId;
  final String title;
  final String body;

  /// Legacy type field (= [category] for new writes). Kept for hiring docs.
  final String type;
  final String relatedPath;
  final DateTime createdAt;
  final bool read;

  /// `batch` | `learning` | `hiring` | `commerce` | `support` | `admin` | `system`
  final String category;
  final String event;
  final String? actorId;
  final String? actorName;
  final String? actorRole;
  final String? routeName;
  final Map<String, String> routeParams;
  final String priority;
  final Map<String, dynamic> meta;
  final String? applicationId;

  String get effectiveCategory =>
      category.trim().isNotEmpty ? category.trim() : type.trim();

  factory UserNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final type = (data['type'] as String?) ?? 'hiring';
    final category = (data['category'] as String?)?.trim();
    final related = (data['relatedPath'] as String?) ?? '';
    final appIdRaw = (data['applicationId'] as String?)?.trim();
    final applicationId = (appIdRaw != null && appIdRaw.isNotEmpty)
        ? appIdRaw
        : (related.startsWith('applications/')
              ? related.substring('applications/'.length).trim()
              : null);

    Map<String, String> routeParams = const {};
    final rawParams = data['routeParams'];
    if (rawParams is Map) {
      routeParams = {
        for (final entry in rawParams.entries)
          if (entry.key != null)
            entry.key.toString(): entry.value?.toString() ?? '',
      };
    }

    Map<String, dynamic> meta = const {};
    final rawMeta = data['meta'];
    if (rawMeta is Map) {
      meta = Map<String, dynamic>.from(rawMeta);
    }

    return UserNotificationModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      type: type,
      relatedPath: related,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      read: data['read'] == true,
      category: (category != null && category.isNotEmpty) ? category : type,
      event: (data['event'] as String?) ?? '',
      actorId: data['actorId'] as String?,
      actorName: data['actorName'] as String?,
      actorRole: data['actorRole'] as String?,
      routeName: data['routeName'] as String?,
      routeParams: routeParams,
      priority: (data['priority'] as String?) ?? 'normal',
      meta: meta,
      applicationId: (applicationId != null && applicationId.isNotEmpty)
          ? applicationId
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final related = relatedPath;
    final resolvedAppId =
        (applicationId != null && applicationId!.trim().isNotEmpty)
        ? applicationId!.trim()
        : (related.startsWith('applications/')
              ? related.substring('applications/'.length).trim()
              : '');
    final resolvedCategory = effectiveCategory.isNotEmpty
        ? effectiveCategory
        : 'system';
    final resolvedType = type.trim().isNotEmpty ? type.trim() : resolvedCategory;

    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': resolvedType,
      'category': resolvedCategory,
      'event': event,
      'relatedPath': relatedPath,
      if (resolvedAppId.isNotEmpty) 'applicationId': resolvedAppId,
      if (actorId != null && actorId!.isNotEmpty) 'actorId': actorId,
      if (actorName != null && actorName!.isNotEmpty) 'actorName': actorName,
      if (actorRole != null && actorRole!.isNotEmpty) 'actorRole': actorRole,
      if (routeName != null && routeName!.isNotEmpty) 'routeName': routeName,
      if (routeParams.isNotEmpty) 'routeParams': routeParams,
      'priority': priority,
      if (meta.isNotEmpty) 'meta': meta,
      // Top-level ids help Firestore rules for batch / learning / commerce writers.
      if (meta['batchId'] is String &&
          (meta['batchId'] as String).trim().isNotEmpty)
        'batchId': (meta['batchId'] as String).trim(),
      if (meta['courseId'] is String &&
          (meta['courseId'] as String).trim().isNotEmpty)
        'courseId': (meta['courseId'] as String).trim(),
      if (meta['serviceRequestId'] is String &&
          (meta['serviceRequestId'] as String).trim().isNotEmpty)
        'serviceRequestId': (meta['serviceRequestId'] as String).trim(),
      if (meta['orderId'] is String &&
          (meta['orderId'] as String).trim().isNotEmpty)
        'orderId': (meta['orderId'] as String).trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }

  UserNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? relatedPath,
    DateTime? createdAt,
    bool? read,
    String? category,
    String? event,
    String? actorId,
    String? actorName,
    String? actorRole,
    String? routeName,
    Map<String, String>? routeParams,
    String? priority,
    Map<String, dynamic>? meta,
    String? applicationId,
  }) {
    return UserNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      relatedPath: relatedPath ?? this.relatedPath,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      category: category ?? this.category,
      event: event ?? this.event,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorRole: actorRole ?? this.actorRole,
      routeName: routeName ?? this.routeName,
      routeParams: routeParams ?? this.routeParams,
      priority: priority ?? this.priority,
      meta: meta ?? this.meta,
      applicationId: applicationId ?? this.applicationId,
    );
  }
}
