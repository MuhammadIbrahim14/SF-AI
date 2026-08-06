import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/payment_intent_model.dart';
import 'demo_payment_finalize_service.dart';

/// SkillForge Demo Gateway client — server-side finalize via Admin SDK.
class PayFastCheckoutService {
  PayFastCheckoutService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    DemoPaymentFinalizeService? demoFinalize,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _demo = demoFinalize ??
            DemoPaymentFinalizeService(
              auth: auth ?? FirebaseAuth.instance,
            );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final DemoPaymentFinalizeService _demo;

  CollectionReference<Map<String, dynamic>> get _intents =>
      _firestore.collection('paymentIntents');

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
    final user = _auth.currentUser;
    if (user == null) {
      throw const PayFastCheckoutException(
        code: 'unauthenticated',
        message: 'Sign in required.',
      );
    }

    try {
      return await _demo.createCheckout(
        type: type,
        amount: amount,
        description: description,
        paymentMethod: paymentMethod,
        currency: currency,
        role: role,
        planId: planId,
        creditPackId: creditPackId,
        teacherId: teacherId,
        orderId: orderId,
        customerEmail: customerEmail,
        customerMobile: customerMobile,
        metadata: metadata,
      );
    } on DemoPaymentException catch (e) {
      throw PayFastCheckoutException(code: e.code, message: e.message);
    } catch (e) {
      throw PayFastCheckoutException(
        code: 'unavailable',
        message: 'Unable to start demo checkout. ($e)',
      );
    }
  }

  Future<Map<String, dynamic>> confirmDemoPayment({
    required String intentId,
    required String outcome,
    String? cardLast4,
    String? errorMessage,
  }) async {
    try {
      return await _demo.confirm(
        intentId: intentId,
        outcome: outcome,
        cardLast4: cardLast4,
        errorMessage: errorMessage,
      );
    } on DemoPaymentException catch (e) {
      throw PayFastCheckoutException(code: e.code, message: e.message);
    } catch (e) {
      throw PayFastCheckoutException(
        code: 'unavailable',
        message: 'Unable to confirm demo payment. ($e)',
      );
    }
  }

  Stream<PaymentIntentModel?> watchIntent(String intentId) {
    if (intentId.isEmpty) {
      return Stream.value(null);
    }
    return _intents.doc(intentId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PaymentIntentModel.fromFirestore(doc);
    });
  }

  Future<PaymentIntentModel?> getIntent(String intentId) async {
    final doc = await _intents.doc(intentId).get();
    if (!doc.exists) return null;
    return PaymentIntentModel.fromFirestore(doc);
  }

  Future<List<PaymentIntentModel>> listForUser(String userId) async {
    final snap = await _intents.where('userId', isEqualTo: userId).get();
    final items =
        snap.docs.map((d) => PaymentIntentModel.fromFirestore(d)).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<PaymentIntentModel>> listAll({int limit = 200}) async {
    final snap = await _intents.limit(limit).get();
    final items =
        snap.docs.map((d) => PaymentIntentModel.fromFirestore(d)).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<PaymentIntentModel> checkoutAndWait({
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
    Duration timeout = const Duration(minutes: 15),
    bool openBrowser = true,
  }) async {
    final session = await createCheckout(
      type: type,
      amount: amount,
      description: description,
      paymentMethod: paymentMethod,
      currency: currency,
      role: role,
      planId: planId,
      creditPackId: creditPackId,
      teacherId: teacherId,
      orderId: orderId,
      customerEmail: customerEmail,
      customerMobile: customerMobile,
      metadata: metadata,
    );

    await confirmDemoPayment(
      intentId: session.intentId,
      outcome: 'success',
      cardLast4: '4242',
    );

    final deadline = DateTime.now().add(timeout);
    await for (final intent in watchIntent(session.intentId)) {
      if (intent == null) continue;
      if (intent.isPaid || intent.isFailed) return intent;
      if (DateTime.now().isAfter(deadline)) {
        throw const PayFastCheckoutException(
          code: 'timeout',
          message:
              'Timed out waiting for demo confirmation. Check My Transactions shortly.',
        );
      }
    }

    throw const PayFastCheckoutException(
      code: 'stream-ended',
      message: 'Payment status stream ended unexpectedly.',
    );
  }
}

class PayFastCheckoutException implements Exception {
  const PayFastCheckoutException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}
