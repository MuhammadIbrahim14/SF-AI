import 'copilot_intent_model.dart';

class CopilotGuidedActionModel {
  const CopilotGuidedActionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.intentType,
    required this.role,
    required this.actionLevel,
    required this.requiresManualSubmit,
    required this.requiresConfirmation,
    required this.canPrefill,
    required this.safetyMessage,
    required this.nextSteps,
    this.targetRouteId,
    this.targetRoutePath,
    this.targetDialogKey,
    this.prefillData = const <String, String>{},
    this.blockedReason,
  });

  final String id;
  final String title;
  final String description;
  final String intentType;
  final String role;
  final String? targetRouteId;
  final String? targetRoutePath;
  final String? targetDialogKey;
  final String actionLevel;
  final bool requiresManualSubmit;
  final bool requiresConfirmation;
  final bool canPrefill;
  final Map<String, String> prefillData;
  final String? blockedReason;
  final String safetyMessage;
  final List<String> nextSteps;

  bool get isAvailable =>
      blockedReason == null && (targetRoutePath ?? '').trim().isNotEmpty;

  bool get isSensitive => actionLevel == CopilotActionLevel.sensitive;

  String get responseText {
    final buffer = StringBuffer()
      ..writeln('$title: $description')
      ..writeln()
      ..writeln(safetyMessage);
    if ((blockedReason ?? '').trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(blockedReason);
    }
    if (prefillData.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Copyable note: ${prefillData.values.first}');
    }
    if (nextSteps.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Next steps:')
        ..write(
          nextSteps
              .asMap()
              .entries
              .map((entry) => '${entry.key + 1}. ${entry.value}')
              .join('\n'),
        );
    }
    return buffer.toString().trim();
  }

  Map<String, dynamic> toMessageMetadata({required bool navigated}) {
    return {
      'guidedAction': true,
      'guidedActionId': id,
      'title': title,
      'description': description,
      'intentType': intentType,
      'role': role,
      'targetRouteId': targetRouteId,
      'targetRoutePath': targetRoutePath,
      'targetDialogKey': targetDialogKey,
      'actionLevel': actionLevel,
      'requiresManualSubmit': requiresManualSubmit,
      'requiresConfirmation': requiresConfirmation,
      'canPrefill': canPrefill,
      'prefillData': prefillData,
      'blockedReason': blockedReason,
      'safetyMessage': safetyMessage,
      'nextSteps': nextSteps,
      'navigated': navigated,
    };
  }
}
