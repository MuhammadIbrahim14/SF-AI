import '../../../models/user_model.dart';
import '../config/copilot_ai_config.dart';
import '../models/copilot_ai_request_model.dart';
import '../models/copilot_ai_response_model.dart';
import '../models/copilot_intent_model.dart';
import 'ai_gateway_client.dart';

/// Maps legacy Copilot intent names to gateway allowlisted taskTypes.
class CopilotGatewayTaskType {
  const CopilotGatewayTaskType._();

  static const remaps = <String, String>{
    'freelancerDeliveryMessageDraft': 'freelancerDeliveryNoteBuilder',
    'freelancerProfileImprove': 'freelancerProfileImprover',
    'freelancerServicePackageImprove': 'freelancerServiceListingImprover',
    'customerRefundReasonDraft': 'customerRefundRequestDraft',
    'customerDisputeSummaryDraft': 'customerDisputeExplanationDraft',
    'customerSupportMessageDraft': 'customerMessageDraft',
  };

  static String resolve(String taskType) => remaps[taskType] ?? taskType;
}

class CopilotAiOrchestratorService {
  CopilotAiOrchestratorService({AiGatewayClient? gatewayClient})
    : _gatewayClient = gatewayClient ?? AiGatewayClient();

  final AiGatewayClient _gatewayClient;

  Future<CopilotAiResponseModel> generate({
    required CopilotIntentModel intent,
    required UserModel? user,
    String? conversationSummary,
  }) async {
    final request = _request(intent, user, conversationSummary);
    if (!CopilotAiConfig.aiEnabled ||
        CopilotAiConfig.aiMode == CopilotAiMode.disabled) {
      return CopilotAiResponseModel(
        requestId: request.requestId,
        status: CopilotAiResponseStatus.unavailable,
        taskType: request.taskType,
        role: request.role,
        title: 'AI Disabled',
        message: 'Copilot AI is currently disabled.',
        requiresManualReview: true,
        blockedReason: 'AI mode is disabled in config.',
        safetyNotes: const ['No action was applied.'],
        provider: CopilotAiProvider.mock,
      );
    }

    return _gatewayClient.send(request);
  }

  CopilotAiRequestModel _request(
    CopilotIntentModel intent,
    UserModel? user,
    String? conversationSummary,
  ) {
    final role = _roleFor(user);
    final safeMessage = _truncate(
      intent.rawText,
      CopilotAiConfig.maxPromptChars,
    );
    return CopilotAiRequestModel(
      requestId: 'ai-${DateTime.now().microsecondsSinceEpoch}',
      userId: user?.uid ?? 'anonymous',
      role: role,
      accountType: user?.accountType ?? 'anonymous',
      taskType: CopilotGatewayTaskType.resolve(intent.type),
      userMessage: safeMessage,
      languageHint: _languageHint(safeMessage),
      conversationSummary: conversationSummary,
      safeAppContext: {
        'role': role,
        'accountType': user?.accountType ?? 'anonymous',
        'manualReviewRequired': true,
        'noFirestoreWrites': true,
        'noMoneyMovement': true,
      },
      constraints: const [
        'Return structured JSON-friendly content.',
        'Do not claim actions were performed.',
        'Do not request secrets or API keys.',
        'Do not approve payments, refunds, settlements, payouts, or user enforcement.',
        'All suggestions require manual review before applying.',
      ],
      timestamp: DateTime.now(),
    );
  }
}

String _roleFor(UserModel? user) {
  if (user == null) return 'guest';
  if (user.isCustomerAccount) return 'customer';
  final role = (user.primaryRole ?? '').trim();
  return role.isEmpty ? 'unknown' : role;
}

String _truncate(String value, int maxChars) {
  if (value.length <= maxChars) return value;
  return value.substring(0, maxChars);
}

String _languageHint(String value) {
  final lower = value.toLowerCase();
  if (RegExp(r'\b(karo|banao|samjhao|chahiye|mujhe|kaise)\b').hasMatch(lower)) {
    return 'roman_urdu_or_mixed';
  }
  return 'english_or_mixed';
}
