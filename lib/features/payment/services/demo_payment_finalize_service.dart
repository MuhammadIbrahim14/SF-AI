import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/utils/app_logger.dart';
import '../../copilot/config/copilot_ai_config.dart';
import '../models/payment_intent_model.dart';

/// SkillForge Demo Gateway client.
///
/// All paid grants (payments, subscriptions, entitlements, course purchases,
/// credit top-ups) are written by the gateway Admin SDK — never from the client.
class DemoPaymentFinalizeService {
  DemoPaymentFinalizeService({
    FirebaseAuth? auth,
    http.Client? client,
    String? baseUrl,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? CopilotAiConfig.gatewayBaseUrl;

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _baseUrl;

  static const gatewayId = 'skillforge_demo';

  Future<PayFastCheckoutSession> createCheckout({
    required String type,
    required double amount,
    required String description,
    required String paymentMethod,
    String? currency,
    String? role,
    String? planId,
    String? creditPackId,
    String? teacherId,
    String? orderId,
    String? customerEmail,
    String? customerMobile,
    Map<String, dynamic>? metadata,
  }) async {
    final data = await _postJson('/api/demo/checkout', {
      'type': type,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'currency': ?currency,
      'role': ?role,
      'planId': ?planId,
      'creditPackId': ?creditPackId,
      'teacherId': ?teacherId,
      'orderId': ?orderId,
      'customerEmail': ?customerEmail,
      'customerMobile': ?customerMobile,
      'metadata': ?metadata,
    });

    return PayFastCheckoutSession.fromMap(data);
  }

  Future<Map<String, dynamic>> confirm({
    required String intentId,
    required String outcome,
    String? cardLast4,
    String? errorMessage,
  }) async {
    return _postJson('/api/demo/confirm', {
      'intentId': intentId,
      'outcome': outcome,
      'cardLast4': ?cardLast4,
      'errorMessage': ?errorMessage,
    });
  }

  Future<Map<String, dynamic>> cancelSubscription() async {
    return _postJson('/api/demo/subscription/cancel', const {});
  }

  Future<Map<String, dynamic>> finalizeSubscriptionExpiry() async {
    return _postJson('/api/demo/subscription/finalize-expiry', const {});
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const DemoPaymentException(
        code: 'unauthenticated',
        message: 'Sign in required.',
      );
    }

    final base = _baseUrl.trim();
    if (base.isEmpty) {
      throw const DemoPaymentException(
        code: 'unavailable',
        message:
            'AI_GATEWAY_BASE_URL is not configured. Demo payments require the SkillForge gateway.',
      );
    }
    if (kReleaseMode && CopilotAiConfig.isLocalhostGateway) {
      throw const DemoPaymentException(
        code: 'misconfigured',
        message: CopilotAiConfig.releaseLocalhostWarning,
      );
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const DemoPaymentException(
        code: 'unauthenticated',
        message: 'Unable to obtain auth token.',
      );
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$base$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw DemoPaymentException(
        code: 'unavailable',
        message:
            'Demo gateway unreachable at $base. Start skillforge_ai_gateway and ensure Firebase Admin is configured. ($e)',
      );
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (error) {
      AppLogger.warn('Demo payment gateway returned invalid JSON: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DemoPaymentException(
        code: data['code']?.toString() ?? 'gateway-error',
        message:
            data['message']?.toString() ??
            'Demo gateway error (HTTP ${response.statusCode}).',
      );
    }

    return data;
  }
}

class DemoPaymentException implements Exception {
  const DemoPaymentException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
