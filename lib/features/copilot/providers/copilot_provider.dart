import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/user_provider.dart';
import '../models/copilot_action_model.dart';
import '../models/copilot_intent_model.dart';
import '../models/copilot_message_model.dart';
import '../services/copilot_action_registry.dart';
import '../services/copilot_ai_orchestrator_service.dart';
import '../services/copilot_data_service.dart';
import '../services/copilot_guided_action_service.dart';
import '../services/copilot_intent_service.dart';
import '../services/copilot_permission_service.dart';
import '../services/copilot_response_service.dart';

final copilotIntentServiceProvider = Provider<CopilotIntentService>((ref) {
  return const CopilotIntentService();
});

final copilotPermissionServiceProvider = Provider<CopilotPermissionService>((
  ref,
) {
  return const CopilotPermissionService();
});

final copilotActionRegistryProvider = Provider<CopilotActionRegistry>((ref) {
  return const CopilotActionRegistry();
});

final copilotResponseServiceProvider = Provider<CopilotResponseService>((ref) {
  return const CopilotResponseService();
});

final copilotDataServiceProvider = Provider<CopilotDataService>((ref) {
  return CopilotDataService();
});

final copilotGuidedActionServiceProvider = Provider<CopilotGuidedActionService>(
  (ref) {
    return const CopilotGuidedActionService();
  },
);

final copilotAiOrchestratorProvider = Provider<CopilotAiOrchestratorService>((
  ref,
) {
  return CopilotAiOrchestratorService();
});

final copilotProvider =
    NotifierProvider<CopilotNotifier, List<CopilotMessageModel>>(
      CopilotNotifier.new,
    );

final copilotQuickActionsProvider = Provider<List<CopilotActionModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  final registry = ref.watch(copilotActionRegistryProvider);
  return registry.quickActionsFor(
    role: user?.primaryRole,
    accountType: user?.accountType,
  );
});

class CopilotNotifier extends Notifier<List<CopilotMessageModel>> {
  @override
  List<CopilotMessageModel> build() {
    return [
      _copilotMessage(
        'Hi, I am SkillForge Copilot. I can navigate, explain workflows, and answer safe read-only summaries like wallet balance, orders, payouts, courses, jobs, and resolution cases without touching sensitive actions.',
        intentType: CopilotIntentType.unknown,
      ),
    ];
  }

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final intentService = ref.read(copilotIntentServiceProvider);
    final permissionService = ref.read(copilotPermissionServiceProvider);
    final actionRegistry = ref.read(copilotActionRegistryProvider);
    final responseService = ref.read(copilotResponseServiceProvider);
    final user = ref.read(currentUserProvider).value;

    final intent = intentService.detectIntent(
      trimmed,
      role: user?.primaryRole,
      accountType: user?.accountType,
    );
    final permission = permissionService.check(
      intent: intent,
      userId: user?.uid,
      role: user?.primaryRole,
      accountType: user?.accountType,
    );
    final action = actionRegistry.actionFor(
      intent: intent,
      role: user?.primaryRole,
      accountType: user?.accountType,
    );
    final response = responseService.buildResponse(
      intent: intent,
      action: action,
      permission: permission,
    );

    state = [
      ...state,
      _userMessage(trimmed),
      _copilotMessage(
        response,
        intentType: intent.type,
        actionTarget: action.targetRoute,
        actionStatus: _statusFor(permission, action),
        metadata: {
          'confidence': intent.confidence,
          'actionId': action.actionId,
          'actionLevel': action.actionLevel,
          'requiresConfirmation': action.requiresConfirmation,
          'isAvailable': action.isAvailable,
          if (action.unavailableReason != null)
            'unavailableReason': action.unavailableReason,
        },
      ),
    ];
  }

  Future<void> sendMessageAndMaybeNavigate(
    BuildContext context,
    String text,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final intentService = ref.read(copilotIntentServiceProvider);
    final permissionService = ref.read(copilotPermissionServiceProvider);
    final actionRegistry = ref.read(copilotActionRegistryProvider);
    final responseService = ref.read(copilotResponseServiceProvider);
    final dataService = ref.read(copilotDataServiceProvider);
    final guidedService = ref.read(copilotGuidedActionServiceProvider);
    final aiService = ref.read(copilotAiOrchestratorProvider);
    final user = ref.read(currentUserProvider).value;

    final intent = intentService.detectIntent(
      trimmed,
      role: user?.primaryRole,
      accountType: user?.accountType,
    );
    final permission = permissionService.check(
      intent: intent,
      userId: user?.uid,
      role: user?.primaryRole,
      accountType: user?.accountType,
    );
    final action = actionRegistry.actionFor(
      intent: intent,
      role: user?.primaryRole,
      accountType: user?.accountType,
    );

    _log(
      'operation=parseIntent text=${_safeText(trimmed)} intent=${intent.type} role=${user?.primaryRole ?? 'none'}',
    );
    if (intent.destinationId != null) {
      _log(
        'operation=routeMatch query=${_safeText(trimmed)} matchedDestination=${intent.destinationId} matchedKeyword=${intent.matchedKeyword ?? 'none'} role=${user?.primaryRole ?? 'none'} allowed=${permission.allowed} route=${action.targetRoute ?? 'none'}',
      );
    } else if (intent.type == CopilotIntentType.unknown) {
      _log(
        'operation=noMatch query=${_safeText(trimmed)} role=${user?.primaryRole ?? 'none'} suggestions=${intent.suggestions.join(', ')}',
      );
    }
    _log(
      'operation=executeAction intent=${intent.type} targetRoute=${action.targetRoute ?? 'none'} allowed=${permission.allowed} reason=${permission.reason ?? action.unavailableReason ?? 'none'}',
    );

    if (intent.actionLevel == CopilotActionLevel.dataRead) {
      if (!permission.allowed) {
        state = [
          ...state,
          _userMessage(trimmed),
          _copilotMessage(
            permission.reason ??
                'I cannot safely read that data from this workspace.',
            intentType: intent.type,
            actionStatus: CopilotActionStatus.blocked,
            metadata: {
              'confidence': intent.confidence,
              'actionLevel': intent.actionLevel,
            },
          ),
        ];
        _log(
          'operation=dataBlocked intent=${intent.type} reason=${permission.reason ?? 'not_allowed'}',
        );
        return;
      }

      final loadingId = _messageId('copilot-loading');
      state = [
        ...state,
        _userMessage(trimmed),
        _copilotMessage(
          'Checking your safe workspace data...',
          id: loadingId,
          intentType: intent.type,
          metadata: const {'loading': true},
        ),
      ];

      _log('operation=dataReadStart intent=${intent.type}');
      final summary = await dataService.resolve(intent: intent, user: user);
      _log(
        'operation=dataReadDone intent=${intent.type} status=${summary.status}',
      );
      state = [
        for (final message in state)
          if (message.id != loadingId) message,
        _copilotMessage(
          summary.summaryText,
          intentType: intent.type,
          actionTarget: summary.suggestedRoutePath,
          actionStatus: summary.isReady
              ? CopilotActionStatus.suggested
              : CopilotActionStatus.unsupported,
          metadata: {
            'confidence': intent.confidence,
            'actionLevel': intent.actionLevel,
            ...summary.toMessageMetadata(),
          },
        ),
      ];
      return;
    }

    if (intent.isAi) {
      if (!permission.allowed) {
        state = [
          ...state,
          _userMessage(trimmed),
          _copilotMessage(
            permission.reason ??
                'You do not have access to this AI feature with your current role.',
            intentType: intent.type,
            actionStatus: CopilotActionStatus.blocked,
            metadata: {
              'confidence': intent.confidence,
              'actionLevel': intent.actionLevel,
            },
          ),
        ];
        _log(
          'operation=aiBlocked intent=${intent.type} role=${user?.primaryRole ?? user?.accountType ?? 'none'} reason=${permission.reason ?? 'not_allowed'}',
        );
        return;
      }

      final loadingId = _messageId('copilot-ai-loading');
      state = [
        ...state,
        _userMessage(trimmed),
        _copilotMessage(
          'Drafting a safe AI response...',
          id: loadingId,
          intentType: intent.type,
          metadata: const {'loading': true},
        ),
      ];

      _log(
        'operation=aiStart intent=${intent.type} role=${user?.primaryRole ?? user?.accountType ?? 'none'}',
      );
      final response = await aiService.generate(intent: intent, user: user);
      _log(
        'operation=aiDone intent=${intent.type} status=${response.status} provider=${response.provider}',
      );
      state = [
        for (final message in state)
          if (message.id != loadingId) message,
        _copilotMessage(
          response.message,
          intentType: intent.type,
          actionStatus: response.isSuccess
              ? CopilotActionStatus.suggested
              : CopilotActionStatus.unsupported,
          metadata: {
            'confidence': intent.confidence,
            'actionLevel': intent.actionLevel,
            'aiResponse': true,
            'aiStatus': response.status,
            'title': response.title,
            'taskType': response.taskType,
            'provider': response.provider,
            'structuredData': response.structuredData,
            'suggestions': response.suggestions,
            'requiresManualReview': response.requiresManualReview,
            'proposedAction': response.proposedAction,
            'blockedReason': response.blockedReason,
            'safetyNotes': response.safetyNotes,
          },
        ),
      ];
      return;
    }

    if (intent.actionLevel == CopilotActionLevel.guidedAction) {
      if (!permission.allowed) {
        state = [
          ...state,
          _userMessage(trimmed),
          _copilotMessage(
            permission.reason ??
                'I cannot safely start that workflow from this workspace.',
            intentType: intent.type,
            actionStatus: CopilotActionStatus.blocked,
            metadata: {
              'confidence': intent.confidence,
              'actionLevel': intent.actionLevel,
            },
          ),
        ];
        _log(
          'operation=guidedAction intent=${intent.type} role=${user?.primaryRole ?? 'none'} targetRoute=none allowed=false requiresManualSubmit=true',
        );
        return;
      }

      final guided = guidedService.buildGuidedAction(
        intent: intent,
        user: user,
      );
      final shouldNavigate =
          guided.isAvailable && (guided.targetRoutePath ?? '').isNotEmpty;
      _log(
        'operation=guidedAction intent=${intent.type} role=${user?.primaryRole ?? user?.accountType ?? 'none'} targetRoute=${guided.targetRoutePath ?? 'none'} allowed=${guided.isAvailable} requiresManualSubmit=${guided.requiresManualSubmit}',
      );
      _log(
        'operation=prefillExtracted intent=${intent.type} hasPrefill=${guided.prefillData.isNotEmpty}',
      );
      state = [
        ...state,
        _userMessage(trimmed),
        _copilotMessage(
          guided.responseText,
          intentType: intent.type,
          actionTarget: guided.targetRoutePath,
          actionStatus: guided.isAvailable
              ? CopilotActionStatus.suggested
              : CopilotActionStatus.unsupported,
          metadata: {
            'confidence': intent.confidence,
            ...guided.toMessageMetadata(navigated: shouldNavigate),
          },
        ),
      ];

      if (shouldNavigate && context.mounted) {
        try {
          context.go(guided.targetRoutePath!);
        } catch (error) {
          _log('operation=navigationError intent=${intent.type} error=$error');
          state = [
            ...state,
            _copilotMessage(
              'This workflow page is not available in the current build.',
              intentType: intent.type,
              actionTarget: guided.targetRoutePath,
              actionStatus: CopilotActionStatus.unsupported,
            ),
          ];
        }
      }
      return;
    }

    if (intent.actionLevel == CopilotActionLevel.sensitive) {
      final warning = guidedService.buildGuidedAction(
        intent: intent,
        user: user,
      );
      _log(
        'operation=sensitiveBlocked intent=${intent.type} role=${user?.primaryRole ?? user?.accountType ?? 'none'} reason=${warning.blockedReason ?? 'sensitive_action'}',
      );
      state = [
        ...state,
        _userMessage(trimmed),
        _copilotMessage(
          warning.responseText,
          intentType: intent.type,
          actionStatus: CopilotActionStatus.blocked,
          metadata: {
            'confidence': intent.confidence,
            ...warning.toMessageMetadata(navigated: false),
          },
        ),
      ];
      return;
    }

    final response = responseService.buildResponse(
      intent: intent,
      action: action,
      permission: permission,
    );
    final shouldNavigate =
        permission.allowed &&
        action.isAvailable &&
        action.targetRoute != null &&
        (intent.actionLevel == CopilotActionLevel.safeNavigation ||
            intent.actionLevel == CopilotActionLevel.guidedAction);

    state = [
      ...state,
      _userMessage(trimmed),
      _copilotMessage(
        response,
        intentType: intent.type,
        actionTarget: action.targetRoute,
        actionStatus: _statusFor(permission, action),
        metadata: {
          'confidence': intent.confidence,
          'actionId': action.actionId,
          'actionLevel': action.actionLevel,
          'requiresConfirmation': action.requiresConfirmation,
          'isAvailable': action.isAvailable,
          'navigated': shouldNavigate,
          if (action.unavailableReason != null)
            'unavailableReason': action.unavailableReason,
        },
      ),
    ];

    if (!permission.allowed) {
      _log(
        'operation=blocked intent=${intent.type} reason=${permission.reason ?? 'not_allowed'}',
      );
      return;
    }

    if (shouldNavigate && context.mounted) {
      try {
        context.go(action.targetRoute!);
      } catch (error) {
        _log('operation=navigationError intent=${intent.type} error=$error');
        state = [
          ...state,
          _copilotMessage(
            'This section is not available in the current build.',
            intentType: intent.type,
            actionTarget: action.targetRoute,
            actionStatus: CopilotActionStatus.unsupported,
          ),
        ];
      }
    }
  }

  void executeQuickAction(BuildContext context, CopilotActionModel action) {
    sendMessageAndMaybeNavigate(context, action.label);
  }

  void runQuickAction(CopilotActionModel action) {
    sendMessage(action.label);
  }

  void addSystemMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    state = [
      ...state,
      CopilotMessageModel(
        id: _messageId('system'),
        text: trimmed,
        sender: CopilotMessageSender.system,
        createdAt: DateTime.now(),
      ),
    ];
  }

  void clearChat() {
    state = build();
  }
}

CopilotMessageModel _userMessage(String text) {
  return CopilotMessageModel(
    id: _messageId('user'),
    text: text,
    sender: CopilotMessageSender.user,
    createdAt: DateTime.now(),
  );
}

CopilotMessageModel _copilotMessage(
  String text, {
  String? id,
  String? intentType,
  String? actionTarget,
  String actionStatus = CopilotActionStatus.none,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) {
  return CopilotMessageModel(
    id: id ?? _messageId('copilot'),
    text: text,
    sender: CopilotMessageSender.copilot,
    createdAt: DateTime.now(),
    intentType: intentType,
    actionTarget: actionTarget,
    actionStatus: actionStatus,
    metadata: metadata,
  );
}

String _statusFor(
  CopilotPermissionResult permission,
  CopilotActionModel action,
) {
  if (!permission.allowed) return CopilotActionStatus.blocked;
  if (!action.isAvailable) return CopilotActionStatus.unsupported;
  if (action.requiresConfirmation) return CopilotActionStatus.needsConfirmation;
  if (action.targetRoute != null) return CopilotActionStatus.suggested;
  return CopilotActionStatus.none;
}

String _messageId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

void _log(String message) {
  debugPrint('[CopilotV1] $message');
}

String _safeText(String text) {
  final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= 80) return collapsed;
  return '${collapsed.substring(0, 80)}...';
}
