class CopilotAiRequestModel {
  const CopilotAiRequestModel({
    required this.requestId,
    required this.userId,
    required this.role,
    required this.accountType,
    required this.taskType,
    required this.userMessage,
    required this.languageHint,
    required this.constraints,
    required this.timestamp,
    this.pageContext,
    this.safeAppContext,
    this.conversationSummary,
  });

  final String requestId;
  final String userId;
  final String role;
  final String accountType;
  final String taskType;
  final String userMessage;
  final Map<String, dynamic>? pageContext;
  final Map<String, dynamic>? safeAppContext;
  final String languageHint;
  final String? conversationSummary;
  final List<String> constraints;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'userId': userId,
      'role': role,
      'accountType': accountType,
      'taskType': taskType,
      'userMessage': userMessage,
      if (pageContext != null) 'pageContext': pageContext,
      if (safeAppContext != null) 'safeAppContext': safeAppContext,
      'languageHint': languageHint,
      if ((conversationSummary ?? '').trim().isNotEmpty)
        'conversationSummary': conversationSummary,
      'constraints': constraints,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
