class CopilotDataStatus {
  const CopilotDataStatus._();

  static const ready = 'ready';
  static const unavailable = 'unavailable';
  static const unauthorized = 'unauthorized';
  static const error = 'error';
}

class CopilotDataSummaryModel {
  const CopilotDataSummaryModel({
    required this.title,
    required this.summaryText,
    required this.status,
    this.facts = const <String, Object?>{},
    this.suggestedRouteId,
    this.suggestedRoutePath,
  });

  final String title;
  final String summaryText;
  final String status;
  final Map<String, Object?> facts;
  final String? suggestedRouteId;
  final String? suggestedRoutePath;

  bool get isReady => status == CopilotDataStatus.ready;

  Map<String, dynamic> toMessageMetadata() {
    return {
      'dataStatus': status,
      'title': title,
      'facts': facts,
      if ((suggestedRouteId ?? '').trim().isNotEmpty)
        'suggestedRouteId': suggestedRouteId,
      if ((suggestedRoutePath ?? '').trim().isNotEmpty)
        'suggestedRoutePath': suggestedRoutePath,
    };
  }
}
