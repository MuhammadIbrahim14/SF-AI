import '../models/copilot_action_model.dart';
import '../models/copilot_intent_model.dart';
import 'copilot_permission_service.dart';

class CopilotResponseService {
  const CopilotResponseService();

  String buildResponse({
    required CopilotIntentModel intent,
    required CopilotActionModel action,
    required CopilotPermissionResult permission,
  }) {
    if (!permission.allowed) {
      final base =
          permission.reason ??
          'I cannot safely perform that action from this workspace.';
      if (intent.suggestions.isNotEmpty) {
        return '$base You can open ${intent.suggestions.join(', ')}.';
      }
      return base;
    }

    if (intent.actionLevel == CopilotActionLevel.sensitive) {
      final isSettlement =
          intent.type == CopilotIntentType.releaseEscrow ||
          intent.type == CopilotIntentType.splitSettlement;
      return isSettlement
          ? 'This is a sensitive action. I can guide you to the Resolution Desk, but you must confirm it manually. Release/Split settlement backend is currently paused until Blaze and Cloud Functions are available.'
          : 'This is a sensitive action. I can guide you to the right page, but you must confirm it manually.';
    }

    if (!action.isAvailable) {
      return action.unavailableReason ??
          '${action.label} is not available in the current build.';
    }

    final directMessage = action.message;
    if (directMessage != null && directMessage.trim().isNotEmpty) {
      return directMessage;
    }

    switch (intent.type) {
      case CopilotIntentType.explainEscrow:
        return 'Client pays first, funds go to escrow, freelancer starts work after escrow is funded, freelancer submits delivery, then the client can approve/release or request refund/dispute.';
      case CopilotIntentType.explainRefund:
        return 'Before delivery, the customer can request a refund. Admin reviews the case, freelancer can provide evidence, and admin may refund, release, split, or reject depending on backend availability and case facts.';
      case CopilotIntentType.explainDispute:
        return 'A dispute is a formal case for an order problem. Add clear evidence, explain the issue, and wait for the resolution decision.';
      case CopilotIntentType.explainPayout:
        return 'Freelancer can withdraw available balance by creating a payout request. Admin reviews and marks it paid in the sandbox/admin flow.';
      case CopilotIntentType.explainDeliveryFlow:
        return 'Freelancer starts work after escrow is funded, then submits delivery with message/files. Client reviews and decides approval, revision, refund, or dispute.';
      case CopilotIntentType.guideRefundRequest:
        return 'To request a refund, open your order or resolution center, choose the relevant case, add the reason and evidence, then submit the request.';
      case CopilotIntentType.guideOpenDispute:
        return 'Open the resolution center, choose the order, describe the issue clearly, attach proof if available, and submit the dispute.';
      case CopilotIntentType.guideSubmitDelivery:
        return 'Open your freelancer order, add the delivery notes or links, then submit delivery from the order detail screen.';
      case CopilotIntentType.guideAddEvidence:
        return 'Open the active resolution case, use the evidence area, add concise notes and proof links, then save the update.';
      case CopilotIntentType.guidePayoutRequest:
        return 'Open payouts from your freelancer wallet, check available balance, enter a sandbox destination, then submit the withdrawal request.';
      case CopilotIntentType.unknown:
        if (intent.suggestions.isNotEmpty) {
          return 'I could not find that page. Try ${intent.suggestions.join(', ')}.';
        }
        return 'I can help with navigation, escrow, refunds, disputes, payouts, orders, service requests, and support. Try asking in English or Roman Urdu.';
      default:
        if (action.targetRoute != null) {
          return 'Opening ${action.label} for you.';
        }
        return 'I can guide you through this, but there is no direct route action for it yet.';
    }
  }
}
