import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../copilot/models/copilot_ai_request_model.dart';
import '../../../copilot/models/copilot_ai_response_model.dart';
import '../../../copilot/services/ai_gateway_client.dart';
import '../models/company_ai_hiring_models.dart';
import 'company_ai_fair_hiring_safety_service.dart';

class CompanyAiHiringService {
  CompanyAiHiringService({
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
    CompanyAiFairHiringSafetyService? safetyService,
  }) : _gatewayClient = gatewayClient ?? AiGatewayClient(),
       _auth = auth ?? FirebaseAuth.instance,
       _safetyService =
           safetyService ?? const CompanyAiFairHiringSafetyService();

  final AiGatewayClient _gatewayClient;
  final FirebaseAuth _auth;
  final CompanyAiFairHiringSafetyService _safetyService;

  Future<CompanyAiHiringResponseModel> generate(
    CompanyAiHiringRequestModel request,
  ) async {
    final aiRequest = CopilotAiRequestModel(
      requestId: 'company_ai_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? request.context.companyId,
      role: 'company',
      accountType: 'professional',
      taskType: request.taskType,
      userMessage: _buildUserMessage(request),
      pageContext: request.toSafeContext(),
      safeAppContext: request.toSafeContext(),
      languageHint: request.context.languagePreference,
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'Do not auto-hire or auto-reject candidates.',
        'Do not send messages automatically.',
        'Do not change candidate status.',
        'Use only role-relevant job/application evidence.',
        'Ignore protected attributes.',
        'Human review is required.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await () async {
      try {
        return await _gatewayClient.send(aiRequest);
      } catch (_) {
        AppLogger.warn('Company AI gateway request failed.');
        return _gatewayUnavailable(request);
      }
    }();

    AppLogger.debug('Company AI response received.');

    if (!response.isSuccess || response.structuredData.isEmpty) {
      return CompanyAiHiringResponseModel.fromCopilot(
        response,
        taskType: request.taskType,
      );
    }

    return _safetyService.sanitize(
      CompanyAiHiringResponseModel.fromCopilot(
        response,
        taskType: request.taskType,
      ),
    );
  }

  String _buildUserMessage(CompanyAiHiringRequestModel request) {
    return '''
SkillForge Company AI Hiring Assistant taskType=${request.taskType}.
Company prompt: ${request.prompt}
Safe hiring context: ${request.toSafeContext()}
Return structuredData for this task only. No markdown. No writes. Manual review required.
''';
  }

  CopilotAiResponseModel _gatewayUnavailable(
    CompanyAiHiringRequestModel request,
  ) {
    return CopilotAiResponseModel(
      requestId: 'company_ai_error_${DateTime.now().microsecondsSinceEpoch}',
      status: CopilotAiResponseStatus.error,
      taskType: request.taskType,
      role: 'company',
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
}
