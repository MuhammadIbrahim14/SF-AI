class CopilotAiResponseStatus {
  const CopilotAiResponseStatus._();

  static const success = 'success';
  static const blocked = 'blocked';
  static const unavailable = 'unavailable';
  static const error = 'error';
  static const rateLimited = 'rateLimited';
}

class CopilotAiResponseModel {
  const CopilotAiResponseModel({
    required this.requestId,
    required this.status,
    required this.taskType,
    required this.role,
    required this.title,
    required this.message,
    required this.requiresManualReview,
    required this.provider,
    this.source,
    this.model,
    this.providerAttempts = const <Map<String, dynamic>>[],
    this.safeErrorCode,
    this.structuredData = const <String, dynamic>{},
    this.suggestions = const <String>[],
    this.proposedAction,
    this.blockedReason,
    this.fallbackRecommended = false,
    this.retryAfterSeconds,
    this.safetyNotes = const <String>[],
    this.usage,
  });

  final String requestId;
  final String status;
  final String taskType;
  final String role;
  final String title;
  final String message;
  final Map<String, dynamic> structuredData;
  final List<String> suggestions;
  final bool requiresManualReview;
  final String? proposedAction;
  final String? blockedReason;
  final bool fallbackRecommended;
  final int? retryAfterSeconds;
  final List<String> safetyNotes;
  final String provider;
  final String? source;
  final String? model;
  final List<Map<String, dynamic>> providerAttempts;
  final String? safeErrorCode;
  final Map<String, dynamic>? usage;

  bool get isSuccess => status == CopilotAiResponseStatus.success;
  bool get isAiUnavailable =>
      status == CopilotAiResponseStatus.unavailable ||
      status == CopilotAiResponseStatus.error ||
      blockedReason == 'aiUnavailable' ||
      safeErrorCode == 'aiUnavailable';

  factory CopilotAiResponseModel.fromJson(Map<String, dynamic> json) {
    return CopilotAiResponseModel(
      requestId: json['requestId']?.toString() ?? '',
      status: json['status']?.toString() ?? CopilotAiResponseStatus.error,
      taskType: json['taskType']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      title: json['title']?.toString() ?? 'AI Response',
      message: json['message']?.toString() ?? '',
      structuredData: json['structuredData'] is Map
          ? Map<String, dynamic>.from(json['structuredData'] as Map)
          : const <String, dynamic>{},
      suggestions: json['suggestions'] is Iterable
          ? (json['suggestions'] as Iterable)
                .map((item) => item?.toString() ?? '')
                .where((item) => item.trim().isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      requiresManualReview: json['requiresManualReview'] != false,
      proposedAction: json['proposedAction'] is String
          ? json['proposedAction'] as String
          : null,
      blockedReason: json['blockedReason'] is String
          ? json['blockedReason'] as String
          : null,
      fallbackRecommended: json['fallbackRecommended'] == true,
      retryAfterSeconds: _intOrNull(json['retryAfterSeconds']),
      safetyNotes: json['safetyNotes'] is Iterable
          ? (json['safetyNotes'] as Iterable)
                .map((item) => item?.toString() ?? '')
                .where((item) => item.trim().isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      provider: json['provider']?.toString() ?? 'unknown',
      source: json['source']?.toString(),
      model:
          json['model']?.toString() ??
          (json['usage'] is Map
              ? (json['usage'] as Map)['model']?.toString()
              : null),
      providerAttempts: json['providerAttempts'] is Iterable
          ? (json['providerAttempts'] as Iterable)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
      safeErrorCode: json['safeErrorCode']?.toString(),
      usage: json['usage'] is Map
          ? Map<String, dynamic>.from(json['usage'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'status': status,
      'taskType': taskType,
      'role': role,
      'title': title,
      'message': message,
      'structuredData': structuredData,
      'suggestions': suggestions,
      'requiresManualReview': requiresManualReview,
      if ((proposedAction ?? '').trim().isNotEmpty)
        'proposedAction': proposedAction,
      if ((blockedReason ?? '').trim().isNotEmpty)
        'blockedReason': blockedReason,
      if (fallbackRecommended) 'fallbackRecommended': true,
      if (retryAfterSeconds != null) 'retryAfterSeconds': retryAfterSeconds,
      'safetyNotes': safetyNotes,
      'provider': provider,
      if ((source ?? '').trim().isNotEmpty) 'source': source,
      if ((model ?? '').trim().isNotEmpty) 'model': model,
      if (providerAttempts.isNotEmpty) 'providerAttempts': providerAttempts,
      if ((safeErrorCode ?? '').trim().isNotEmpty)
        'safeErrorCode': safeErrorCode,
      if (usage != null) 'usage': usage,
    };
  }

  CopilotAiResponseModel copyWith({
    String? requestId,
    String? status,
    String? taskType,
    String? role,
    String? title,
    String? message,
    Map<String, dynamic>? structuredData,
    List<String>? suggestions,
    bool? requiresManualReview,
    String? proposedAction,
    String? blockedReason,
    bool? fallbackRecommended,
    int? retryAfterSeconds,
    List<String>? safetyNotes,
    String? provider,
    String? source,
    String? model,
    List<Map<String, dynamic>>? providerAttempts,
    String? safeErrorCode,
    Map<String, dynamic>? usage,
  }) {
    return CopilotAiResponseModel(
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      taskType: taskType ?? this.taskType,
      role: role ?? this.role,
      title: title ?? this.title,
      message: message ?? this.message,
      structuredData: structuredData ?? this.structuredData,
      suggestions: suggestions ?? this.suggestions,
      requiresManualReview: requiresManualReview ?? this.requiresManualReview,
      proposedAction: proposedAction ?? this.proposedAction,
      blockedReason: blockedReason ?? this.blockedReason,
      fallbackRecommended: fallbackRecommended ?? this.fallbackRecommended,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      provider: provider ?? this.provider,
      source: source ?? this.source,
      model: model ?? this.model,
      providerAttempts: providerAttempts ?? this.providerAttempts,
      safeErrorCode: safeErrorCode ?? this.safeErrorCode,
      usage: usage ?? this.usage,
    );
  }
}

int? _intOrNull(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
