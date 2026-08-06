class TeacherAiGenerationResultModel {
  const TeacherAiGenerationResultModel({
    required this.taskType,
    required this.title,
    required this.message,
    required this.data,
    required this.sourceProvider,
    required this.contentSource,
    required this.qualityStatus,
    required this.isValid,
    this.model,
    this.totalTokens,
    this.creditCost = 0,
    this.warnings = const <String>[],
    this.errors = const <String>[],
  });

  final String taskType;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final String sourceProvider;
  final String contentSource;
  final String qualityStatus;
  final bool isValid;
  final String? model;
  final int? totalTokens;
  final int creditCost;
  final List<String> warnings;
  final List<String> errors;

  bool get isFallback => false;
  bool get isUnavailable =>
      !isValid ||
      contentSource == 'aiUnavailable' ||
      contentSource == 'gatewayUnreachable' ||
      contentSource == 'providerError';

  String get sourceLabel {
    if (sourceProvider == 'openai') return 'Generated with OpenAI';
    if (sourceProvider == 'openaiBackup') return 'Generated with OpenAI Backup';
    if (sourceProvider == 'openaiWithRepair') return 'OpenAI + Repair';
    if (sourceProvider == 'gemini') return 'Generated with Gemini';
    if (sourceProvider == 'geminiBackup') return 'Generated with Gemini Backup';
    if (sourceProvider == 'geminiWithRepair') return 'Gemini + Repair';
    if (isUnavailable) return 'AI Unavailable';
    return contentSource;
  }

  String stringValue(String key, {String fallback = ''}) {
    final value = data[key];
    return value == null ? fallback : value.toString();
  }

  int intValue(String key, {int fallback = 0}) {
    final value = data[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  List<String> stringList(String key) {
    final value = data[key];
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  List<Map<String, dynamic>> mapList(String key) {
    final value = data[key];
    if (value is! Iterable) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  TeacherAiGenerationResultModel copyWith({
    Map<String, dynamic>? data,
    String? qualityStatus,
    bool? isValid,
    List<String>? warnings,
    List<String>? errors,
  }) {
    return TeacherAiGenerationResultModel(
      taskType: taskType,
      title: title,
      message: message,
      data: data ?? this.data,
      sourceProvider: sourceProvider,
      contentSource: contentSource,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      isValid: isValid ?? this.isValid,
      model: model,
      totalTokens: totalTokens,
      creditCost: creditCost,
      warnings: warnings ?? this.warnings,
      errors: errors ?? this.errors,
    );
  }
}
