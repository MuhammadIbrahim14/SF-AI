import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../ai_usage/data/ai_usage_repository.dart';
import '../config/copilot_ai_config.dart';
import '../models/copilot_ai_request_model.dart';
import '../models/copilot_ai_response_model.dart';

class AiGatewayClient {
  AiGatewayClient({
    FirebaseAuth? auth,
    http.Client? client,
    String? baseUrl,
    AiUsageRepository? aiUsageRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? CopilotAiConfig.gatewayBaseUrl,
       _aiUsageRepository =
           aiUsageRepository ?? AiUsageRepository(FirebaseFirestore.instance);

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _baseUrl;
  final AiUsageRepository _aiUsageRepository;

  String get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> healthCheck() async {
    final base = _baseUrl.trim();
    if (base.isEmpty) {
      return const {
        'ok': false,
        'status': 'unreachable',
        'message': 'AI_GATEWAY_BASE_URL is not configured.',
      };
    }
    try {
      final response = await _client
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          'ok': false,
          'status': 'unreachable',
          'message': 'Gateway health returned HTTP ${response.statusCode}.',
        };
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {'ok': decoded['ok'] == true, ...decoded};
      }
      return const {
        'ok': false,
        'status': 'validationFailed',
        'message': 'Gateway health returned invalid JSON.',
      };
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AIGateway] health check failed: $error');
      }
      return {
        'ok': false,
        'status': 'unreachable',
        'message':
            'AI Gateway is not reachable. Start gateway or configure AI_GATEWAY_BASE_URL.',
        'gatewayUrl': base,
      };
    }
  }

  Future<CopilotAiResponseModel> send(CopilotAiRequestModel request) async {
    final base = _baseUrl.trim();
    if (base.isEmpty) {
      return _unavailable(
        request,
        'AI gateway URL is not configured. Configure the SkillForge AI gateway with a real provider before using this assistant.',
      );
    }
    if (kReleaseMode && CopilotAiConfig.isLocalhostGateway) {
      return _unavailable(request, CopilotAiConfig.releaseLocalhostWarning);
    }

    AiUsageGuardResult? guard;
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && request.userId.trim().isNotEmpty) {
      try {
        guard = await _aiUsageRepository.checkGuard(
          userId: firebaseUser.uid,
          role: request.role,
          taskType: request.taskType,
          heavyCandidate: _isHeavyRequest(request),
        );
        if (kDebugMode) {
          debugPrint(
            '[AIGuard] taskType=${request.taskType} role=${request.role} '
            'cost=${guard.cost} allowed=${guard.allowed}',
          );
        }
        if (!guard.allowed) {
          if (kDebugMode) {
            debugPrint('[AIGuard] OpenAI called=no reason=${guard.reason}');
          }
          return _blocked(request, guard.reason);
        }
      } catch (error) {
        // Quota setup is advisory for UX and billing. Missing/denied quota docs
        // must never mask a working AI gateway response.
        if (kDebugMode) {
          debugPrint(
            '[AIGuard] taskType=${request.taskType} role=${request.role} '
            'using local defaults after quota read failure: $error',
          );
        }
        guard = null;
      }
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[AIGateway] OpenAI/Gateway called=yes taskType=${request.taskType}',
        );
      }
      final token = await _auth.currentUser?.getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if ((token ?? '').trim().isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse('$base/api/copilot');
      final body = jsonEncode(request.toJson());
      http.Response? response;
      Object? lastError;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          response = await _client
              .post(uri, headers: headers, body: body)
              .timeout(
                const Duration(seconds: CopilotAiConfig.requestTimeoutSeconds),
              );
          if (response.statusCode >= 500 && attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            continue;
          }
          break;
        } on TimeoutException catch (e) {
          lastError = e;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            continue;
          }
          rethrow;
        } catch (e) {
          lastError = e;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            continue;
          }
          rethrow;
        }
      }
      if (response == null) {
        throw lastError ?? StateError('AI gateway request failed');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String detail = 'AI gateway returned HTTP ${response.statusCode}.';
        Map<String, dynamic>? payload;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            payload = decoded;
            final msg = (decoded['message'] as Object?)?.toString().trim();
            if (msg != null && msg.isNotEmpty) {
              detail = msg;
            }
          }
        } catch (_) {
          // Non-JSON error body: keep the HTTP status as the detail.
        }
        if (response.statusCode == 403) {
          return _accessDenied(request, detail, payload);
        }
        return _unavailable(request, detail);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _unavailable(request, 'AI gateway returned invalid JSON.');
      }
      final model = CopilotAiResponseModel.fromJson(decoded);
      await _logUsage(request, model, guard);
      return model;
    } on TimeoutException {
      final model = _unavailable(request, 'AI gateway timed out.');
      await _logUsage(request, model, guard);
      return model;
    } catch (_) {
      final model = _unavailable(
        request,
        'AI gateway is not reachable from this browser. Make sure the gateway is running, DEV_ALLOW_LOCALHOST=true is enabled for local Flutter web, and gatewayBaseUrl is correct.',
      );
      await _logUsage(request, model, guard);
      return model;
    }
  }

  Future<void> _logUsage(
    CopilotAiRequestModel request,
    CopilotAiResponseModel response,
    AiUsageGuardResult? guard,
  ) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || guard == null) return;
    try {
      await _aiUsageRepository.logUsageAndCharge(
        userId: firebaseUser.uid,
        role: request.role,
        taskType: request.taskType,
        feature: guard.featureCost.label,
        provider: response.provider,
        status: response.status,
        fallbackUsed: false,
        usage: response.usage,
        requestedCost: guard.cost,
      );
    } catch (_) {
      // Usage logging must never break the AI draft UX.
    }
  }

  bool _isHeavyRequest(CopilotAiRequestModel request) {
    final count = request.safeAppContext?['questionCount'];
    final questionCount = count is num ? count.toInt() : 0;
    return request.taskType == 'teacherCourseBlueprint' ||
        request.taskType == 'teacherProjectAssignmentBuilder' ||
        request.taskType == 'teacherGrandTestBuilder' ||
        questionCount > 25 ||
        request.taskType.startsWith('admin');
  }

  CopilotAiResponseModel _blocked(
    CopilotAiRequestModel request,
    String reason,
  ) {
    return CopilotAiResponseModel(
      requestId: request.requestId,
      status: CopilotAiResponseStatus.blocked,
      taskType: request.taskType,
      role: request.role,
      title: 'AI Credits Required',
      message: reason,
      requiresManualReview: true,
      blockedReason: reason,
      fallbackRecommended: false,
      safetyNotes: const [
        'No OpenAI/Gemini call was made.',
        'You can request more AI Credits or retry after credits are available.',
      ],
      provider: '',
      source: 'quotaBlocked',
      safeErrorCode: 'quotaBlocked',
      usage: const {
        'model': 'none',
        'promptTokens': 0,
        'completionTokens': 0,
        'totalTokens': 0,
      },
    );
  }

  /// HTTP 403 from the gateway: the account is authenticated but its verified
  /// role/capabilities do not cover this taskType. Distinct from unreachable.
  CopilotAiResponseModel _accessDenied(
    CopilotAiRequestModel request,
    String reason,
    Map<String, dynamic>? payload,
  ) {
    final boundRole = payload?['boundRole']?.toString().trim() ?? '';
    final boundAccountType =
        payload?['boundAccountType']?.toString().trim() ?? '';
    final identity = [
      if (boundRole.isNotEmpty) 'role: $boundRole',
      if (boundAccountType.isNotEmpty) 'account: $boundAccountType',
    ].join(', ');
    final message = identity.isEmpty
        ? reason
        : '$reason (Signed in as $identity.)';
    return CopilotAiResponseModel(
      requestId: request.requestId,
      status: CopilotAiResponseStatus.blocked,
      taskType: request.taskType,
      role: request.role,
      title: 'AI access not allowed for this role',
      message: message,
      requiresManualReview: false,
      blockedReason: message,
      fallbackRecommended: false,
      suggestions: const [
        'Switch to the account or mode that owns this feature.',
        'Ask an admin to confirm the role on your account.',
      ],
      safetyNotes: const [
        'No AI action was applied.',
        'The AI gateway is reachable — this request was refused by role checks.',
      ],
      provider: '',
      source: 'roleNotAllowed',
      safeErrorCode: 'roleNotAllowed',
    );
  }

  CopilotAiResponseModel _unavailable(
    CopilotAiRequestModel request,
    String reason,
  ) {
    return CopilotAiResponseModel(
      requestId: request.requestId,
      status: CopilotAiResponseStatus.unavailable,
      taskType: request.taskType,
      role: request.role,
      title: 'AI Gateway Unavailable',
      message: reason,
      requiresManualReview: false,
      blockedReason: reason,
      fallbackRecommended: false,
      safetyNotes: const ['No AI action was applied.'],
      provider: '',
      source: 'gatewayUnreachable',
      safeErrorCode: 'gatewayUnreachable',
    );
  }
}
