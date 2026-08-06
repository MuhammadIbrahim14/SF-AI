import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_logger.dart';
import '../../copilot/config/copilot_ai_config.dart';
import '../config/stripe_config.dart';
import '../models/stripe_models.dart';

/// Stripe **Test (sandbox)** client for the SkillForge gateway.
///
/// Mirrors `DemoPaymentFinalizeService`: Firebase ID token auth, same gateway
/// base URL, and the gateway writes every entitlement through the shared
/// `finalizePaidIntent()` seam. The client only ever sees a hosted Checkout URL
/// and the `paymentIntents` doc id — no Stripe secret ever reaches Flutter.
class StripeCheckoutService {
  StripeCheckoutService({
    FirebaseAuth? auth,
    http.Client? client,
    String? baseUrl,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? CopilotAiConfig.gatewayBaseUrl;

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _baseUrl;

  static const provider = StripeConfig.provider;

  /// Unauthenticated capability probe. Returns `unavailable` on any failure so
  /// the checkout sheet quietly falls back to Demo-only.
  Future<StripeGatewayConfig> fetchConfig() async {
    final base = _baseUrl.trim();
    if (base.isEmpty) return const StripeGatewayConfig.unavailable();
    if (kReleaseMode && CopilotAiConfig.isLocalhostGateway) {
      return const StripeGatewayConfig.unavailable();
    }
    try {
      final response = await _client
          .get(Uri.parse('$base/api/stripe/config'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const StripeGatewayConfig.unavailable();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const StripeGatewayConfig.unavailable();
      }
      return StripeGatewayConfig.fromMap(decoded);
    } catch (error) {
      AppLogger.warn('Stripe config probe failed: $error');
      return const StripeGatewayConfig.unavailable();
    }
  }

  /// Creates the `paymentIntents` doc + Stripe Checkout Session on the gateway.
  ///
  /// The gateway derives the authoritative amount from the Firestore catalog or
  /// order, so [amount] is only a client-side hint for the summary UI.
  Future<StripeCheckoutSession> createCheckout({
    required String type,
    required double amount,
    required String description,
    String? currency,
    String? role,
    String? planId,
    String? creditPackId,
    String? teacherId,
    String? orderId,
    String? courseId,
    String? customerEmail,
    Map<String, dynamic>? metadata,
  }) async {
    final data = await _request(
      'POST',
      '/api/stripe/checkout',
      body: {
        'type': type,
        'amount': amount,
        'description': description,
        'currency': currency ?? StripeConfig.currency,
        'role': ?role,
        'planId': ?planId,
        'creditPackId': ?creditPackId,
        'teacherId': ?teacherId,
        'orderId': ?orderId,
        'courseId': ?courseId,
        'customerEmail': ?customerEmail,
        'metadata': {...?metadata, 'provider': provider, 'environment': 'test'},
      },
    );

    final session = StripeCheckoutSession.fromMap(data);
    if (session.isLive) {
      throw const StripeCheckoutException(
        code: 'live-mode-rejected',
        message:
            'Gateway returned a Live Stripe session. SkillForge only supports '
            'Stripe Test (sandbox).',
      );
    }
    if (session.checkoutUrl.isEmpty || session.intentId.isEmpty) {
      throw const StripeCheckoutException(
        code: 'invalid-session',
        message: 'Stripe gateway did not return a checkout URL.',
      );
    }
    return session;
  }

  /// Opens the hosted Checkout page — a new browser tab on web, the external
  /// browser elsewhere.
  Future<bool> openCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (error) {
      AppLogger.warn('Unable to open Stripe checkout URL: $error');
      return false;
    }
  }

  /// Phase 4 — starts (or resumes) Stripe Connect Express onboarding in test
  /// mode for a teacher or freelancer.
  Future<StripeConnectOnboardLink> startConnectOnboarding({
    required String role,
    String? returnUrl,
  }) async {
    final data = await _request(
      'POST',
      '/api/stripe/connect/onboard',
      body: {'role': role, 'returnUrl': ?returnUrl},
    );
    final link = StripeConnectOnboardLink.fromMap(data);
    if (link.url.isEmpty) {
      throw const StripeCheckoutException(
        code: 'invalid-onboard-link',
        message: 'Stripe gateway did not return an onboarding link.',
      );
    }
    return link;
  }

  /// Phase 4 — current Connect account state for the signed-in seller.
  ///
  /// Returns an `unavailable` status instead of throwing when the gateway has
  /// no Connect routes yet, so wallet screens degrade quietly.
  Future<StripeConnectStatus> connectStatus({required String role}) async {
    try {
      final data = await _request(
        'GET',
        '/api/stripe/connect/status',
        query: {'role': role},
      );
      return StripeConnectStatus.fromMap(data);
    } on StripeCheckoutException catch (e) {
      const soft = {'not-found', 'unavailable', 'stripe-unavailable'};
      if (soft.contains(e.code)) {
        return StripeConnectStatus.unavailable(e.message);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const StripeCheckoutException(
        code: 'unauthenticated',
        message: 'Sign in required.',
      );
    }

    final base = _baseUrl.trim();
    if (base.isEmpty) {
      throw const StripeCheckoutException(
        code: 'unavailable',
        message:
            'AI_GATEWAY_BASE_URL is not configured. Stripe Test checkout '
            'requires the SkillForge gateway.',
      );
    }
    if (kReleaseMode && CopilotAiConfig.isLocalhostGateway) {
      throw const StripeCheckoutException(
        code: 'misconfigured',
        message: CopilotAiConfig.releaseLocalhostWarning,
      );
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const StripeCheckoutException(
        code: 'unauthenticated',
        message: 'Unable to obtain auth token.',
      );
    }

    final uri = Uri.parse(
      '$base$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    late final http.Response response;
    try {
      final request = method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      response = await request.timeout(const Duration(seconds: 60));
    } catch (e) {
      throw StripeCheckoutException(
        code: 'unavailable',
        message:
            'Stripe gateway unreachable at $base. Start skillforge_ai_gateway '
            'with STRIPE_SECRET_KEY (sk_test_…) configured. ($e)',
      );
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (error) {
      AppLogger.warn('Stripe gateway returned invalid JSON: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StripeCheckoutException(
        code:
            data['code']?.toString() ??
            (response.statusCode == 404 ? 'not-found' : 'gateway-error'),
        message:
            data['message']?.toString() ??
            'Stripe gateway error (HTTP ${response.statusCode}).',
      );
    }

    return data;
  }
}

class StripeCheckoutException implements Exception {
  const StripeCheckoutException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
