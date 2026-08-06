import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/app_logger.dart';
import '../../copilot/config/copilot_ai_config.dart';
import '../../copilot/models/copilot_ai_request_model.dart';
import '../../copilot/models/copilot_ai_response_model.dart';
import '../../copilot/services/ai_gateway_client.dart';
import '../models/marketplace_ai_draft_models.dart';
import 'marketplace_ai_draft_history.dart';
import 'marketplace_ai_sanitize.dart';

class MarketplaceAiService {
  MarketplaceAiService({
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
    MarketplaceAiDraftHistoryStore? historyStore,
  }) : _gatewayClient =
           gatewayClient ??
           AiGatewayClient(baseUrl: CopilotAiConfig.gatewayBaseUrl),
       _auth = auth ?? FirebaseAuth.instance,
       _history = historyStore ?? MarketplaceAiDraftHistoryStore();

  final AiGatewayClient _gatewayClient;
  final FirebaseAuth _auth;
  final MarketplaceAiDraftHistoryStore _history;

  Future<MarketplaceAiDraftResponse> generateServiceListing({
    required String taskType,
    required String prompt,
    required Map<String, dynamic> safeAppContext,
    required MarketplaceAiKnownEvidence evidence,
    String role = 'freelancer',
    String accountType = 'professional',
  }) {
    return generate(
      taskType: taskType,
      prompt: prompt,
      safeAppContext: safeAppContext,
      evidence: evidence,
      role: role,
      accountType: accountType,
      structuredHint:
          'Return structuredData.serviceListing only. No markdown. '
          'No writes. Manual review required. Never auto-publish. '
          'Never set verifiedBadge.',
    );
  }

  Future<MarketplaceAiDraftResponse> generate({
    required String taskType,
    required String prompt,
    required Map<String, dynamic> safeAppContext,
    required MarketplaceAiKnownEvidence evidence,
    String role = 'freelancer',
    String accountType = 'professional',
    String? structuredHint,
    String? screen,
  }) async {
    final key = MarketplaceAiTaskType.structuredDataKeyHint(taskType);
    final hint =
        structuredHint ??
        'Return structuredData.$key. No markdown. No writes. '
            'requiresManualReview=true. proposedAction=null. '
            'Never auto-publish, pay, message, refund, release escrow, '
            'or change order/request status.';

    final aiRequest = CopilotAiRequestModel(
      requestId: 'marketplace_ai_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? '',
      role: role,
      accountType: accountType,
      taskType: taskType,
      userMessage: '''
SkillForge Marketplace AI taskType=$taskType.
User prompt: $prompt
Safe marketplace context: $safeAppContext
$hint
''',
      pageContext: {
        'screen': screen ?? 'MarketplaceAi',
        'taskType': taskType,
      },
      safeAppContext: {
        ...safeAppContext,
        'manualReviewRequired': true,
        'noDatabaseWrites': true,
        'noPaymentOrSettlementExecution': true,
        'neverAutoPublish': true,
        'neverSetVerifiedBadgeFromAi': true,
        'applyFillsFormsOnly': true,
      },
      languageHint: 'professional English, simple where useful',
      constraints: const [
        'Return draft/recommendation only.',
        'Do not claim that platform actions were performed.',
        'Do not execute payments, settlements, refunds, hiring, or profile changes.',
        'Do not invent portfolio URLs, gallery URLs, or certificate IDs.',
        'Do not set verifiedBadge from AI.',
        'Human review is required before publish or submit.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await () async {
      try {
        return await _gatewayClient.send(aiRequest);
      } catch (_) {
        AppLogger.warn('Marketplace AI gateway request failed.');
        return CopilotAiResponseModel(
          requestId: aiRequest.requestId,
          status: CopilotAiResponseStatus.error,
          taskType: taskType,
          role: role,
          title: 'SkillForge AI is not reachable',
          message:
              'SkillForge AI is not reachable right now. Please make sure the AI Gateway is running and try again.',
          requiresManualReview: false,
          provider: '',
          source: 'gatewayUnreachable',
          safeErrorCode: 'gatewayUnreachable',
          suggestions: const [
            'Start the AI Gateway.',
            'Retry the request.',
            'Try again with a shorter prompt.',
          ],
        );
      }
    }();

    final draftResponse = MarketplaceAiDraftResponse.fromCopilot(
      response,
      taskType: taskType,
    );
    if (draftResponse.isUnavailable) return draftResponse;

    final sanitized = MarketplaceAiSanitize.sanitizeResponse(
      draftResponse,
      evidence: evidence,
    );

    final payload = sanitized.primaryApplyMap;
    if (payload != null && payload.isNotEmpty) {
      await _history.saveDraft(
        taskType: taskType,
        title: sanitized.title,
        summary: sanitized.summary,
        applyPayload: payload,
      );
    }

    return sanitized;
  }
}
