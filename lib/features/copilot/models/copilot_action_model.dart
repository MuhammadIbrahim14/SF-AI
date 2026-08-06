class CopilotActionModel {
  const CopilotActionModel({
    required this.actionId,
    required this.label,
    required this.actionLevel,
    this.targetRoute,
    this.requiredRole,
    this.requiresConfirmation = false,
    this.isAvailable = true,
    this.unavailableReason,
    this.message,
  });

  final String actionId;
  final String label;
  final String actionLevel;
  final String? targetRoute;
  final String? requiredRole;
  final bool requiresConfirmation;
  final bool isAvailable;
  final String? unavailableReason;
  final String? message;

  CopilotActionModel copyWith({
    String? actionId,
    String? label,
    String? actionLevel,
    String? targetRoute,
    String? requiredRole,
    bool? requiresConfirmation,
    bool? isAvailable,
    String? unavailableReason,
    String? message,
  }) {
    return CopilotActionModel(
      actionId: actionId ?? this.actionId,
      label: label ?? this.label,
      actionLevel: actionLevel ?? this.actionLevel,
      targetRoute: targetRoute ?? this.targetRoute,
      requiredRole: requiredRole ?? this.requiredRole,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      message: message ?? this.message,
    );
  }
}
