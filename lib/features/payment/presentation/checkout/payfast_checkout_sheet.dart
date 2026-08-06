import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../config/payfast_config.dart';
import '../../config/stripe_config.dart';
import '../../models/payment_intent_model.dart';
import '../../models/payment_models.dart';
import '../../models/stripe_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/payfast_checkout_service.dart';
import '../../services/stripe_checkout_service.dart';
import '../widgets/payment_success_toast.dart';

/// SkillForge Demo Gateway checkout used by all roles (Option A).
Future<PaymentProcessResult?> showPayFastCheckoutSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String type,
  required double amount,
  required String description,
  String currency = PayFastConfig.currency,
  String? role,
  String? planId,
  String? creditPackId,
  String? teacherId,
  String? orderId,
  Map<String, dynamic>? metadata,
  String title = 'Secure checkout',
}) async {
  if (!PayFastConfig.isAvailable) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Payments paused'),
        content: const Text(PayFastConfig.pausedMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return PaymentProcessResult(
      transactionId: '',
      paymentId: '',
      status: PaymentStatus.failed,
      message: PayFastConfig.pausedMessage,
      amount: amount,
      currency: currency,
    );
  }

  // Capture root navigator BEFORE the sheet opens/closes — after pop, the
  // caller's context can be mid-dispose on Windows and toast never paints.
  final rootNav = Navigator.of(context, rootNavigator: true);

  final result = await showModalBottomSheet<PaymentProcessResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PayFastCheckoutSheet(
      type: type,
      amount: amount,
      description: description,
      currency: currency,
      role: role,
      planId: planId,
      creditPackId: creditPackId,
      teacherId: teacherId,
      orderId: orderId,
      metadata: metadata,
      title: title,
    ),
  );

  // Single success hook for Demo + Stripe — covers course, credit pack,
  // plan, commerce order, and wallet top-up checkouts. Show toast AFTER the
  // sheet fully returns, on the root overlay (not the disposing sheet route).
  if (result != null && result.isSuccess) {
    final overlayContext = rootNav.overlay?.context;
    if (overlayContext != null && overlayContext.mounted) {
      await showPaymentSuccessToast(
        overlayContext,
        navigator: rootNav,
        message: paymentSuccessMessageForType(type),
      );
    }
  }

  return result;
}

class PayFastCheckoutSheet extends ConsumerStatefulWidget {
  const PayFastCheckoutSheet({
    required this.type,
    required this.amount,
    required this.description,
    this.currency = PayFastConfig.currency,
    this.role,
    this.planId,
    this.creditPackId,
    this.teacherId,
    this.orderId,
    this.metadata,
    this.title = 'Secure checkout',
    super.key,
  });

  final String type;
  final double amount;
  final String description;
  final String currency;
  final String? role;
  final String? planId;
  final String? creditPackId;
  final String? teacherId;
  final String? orderId;
  final Map<String, dynamic>? metadata;
  final String title;

  @override
  ConsumerState<PayFastCheckoutSheet> createState() =>
      _PayFastCheckoutSheetState();
}

enum _CheckoutStep { method, hosted, processing, stripeRedirect }

/// Checkout providers offered by the sheet. Demo always stays available.
class _ProviderId {
  const _ProviderId._();

  static const demo = 'demo';
  static const stripe = StripeConfig.provider;
}

class _PayFastCheckoutSheetState extends ConsumerState<PayFastCheckoutSheet> {
  String _provider = _ProviderId.demo;
  String _method = PayFastConfig.methods.first.id;
  _CheckoutStep _step = _CheckoutStep.method;
  bool _busy = false;
  String? _error;
  PayFastCheckoutSession? _session;
  StripeCheckoutSession? _stripeSession;
  StreamSubscription<PaymentIntentModel?>? _stripeWatch;
  bool _stripeSettled = false;
  bool _providerTouched = false;

  final _cardNumber = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(text: '12/28');
  final _cvv = TextEditingController(text: '123');
  final _walletMobile = TextEditingController(text: '03001234567');
  final _otp = TextEditingController();
  bool _otpSent = false;

  bool get _isStripe => _provider == _ProviderId.stripe;

  @override
  void initState() {
    super.initState();
    // Preselect Stripe once the gateway confirms usable test keys, per the
    // Stripe plan. Demo stays one tap away and wins if the user picks it.
    ref.listenManual<AsyncValue<bool>>(stripePaymentsEnabledProvider, (
      previous,
      next,
    ) {
      if (!mounted || _providerTouched) return;
      if (next.value != true) return;
      if (_step != _CheckoutStep.method || _isStripe) return;
      setState(() => _provider = _ProviderId.stripe);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _stripeWatch?.cancel();
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _walletMobile.dispose();
    _otp.dispose();
    super.dispose();
  }

  double get _estimatedPlatformFee {
    switch (widget.type) {
      case PaymentType.plan:
      case PaymentType.creditPack:
      case 'wallet_topup':
        return widget.amount;
      case PaymentType.course:
        return widget.amount * 0.2;
      case 'commerce_order':
        return widget.amount * 0.1;
      default:
        return 0;
    }
  }

  String get _headerTitle {
    if (_step == _CheckoutStep.stripeRedirect) return StripeConfig.label;
    if (_step == _CheckoutStep.hosted) return 'SkillForge Demo Gateway';
    return widget.title;
  }

  String get _headerSubtitle {
    if (_step == _CheckoutStep.stripeRedirect) {
      return 'Hosted Checkout · ${PayFastConfig.merchantDisplayName}';
    }
    if (_step == _CheckoutStep.hosted) {
      return 'Hosted checkout · ${PayFastConfig.merchantDisplayName}';
    }
    return _isStripe
        ? 'Powered by Stripe — test mode'
        : 'Powered by SkillForge Demo Gateway';
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'account_balance_wallet':
        return Icons.wallet_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      default:
        return Icons.credit_card_rounded;
    }
  }

  String get _cardLast4 {
    final digits = _cardNumber.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '4242';
    return digits.substring(digits.length - 4);
  }

  Future<void> _startHosted() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(payFastCheckoutServiceProvider);
      final session = await service.createCheckout(
        type: widget.type,
        amount: widget.amount,
        description: widget.description,
        paymentMethod: _method,
        currency: widget.currency,
        role: widget.role,
        planId: widget.planId,
        creditPackId: widget.creditPackId,
        teacherId: widget.teacherId,
        orderId: widget.orderId,
        metadata: {
          ...?widget.metadata,
          'isDemo': true,
          'environment': 'demo',
          'gateway': PayFastConfig.gatewayId,
        },
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _step = _CheckoutStep.hosted;
        _busy = false;
        _otpSent = false;
        _otp.clear();
      });
    } on PayFastCheckoutException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirm({required bool success}) async {
    final session = _session;
    if (session == null) return;

    if (_method == 'card' || _method == 'jazzcash' || _method == 'easypaisa') {
      if (!_otpSent) {
        setState(() {
          _error = 'Enter details and request the demo OTP first.';
        });
        return;
      }
      if (_otp.text.trim() != '123456') {
        setState(() {
          _error = 'Invalid demo OTP. Use 123456.';
        });
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
      _step = _CheckoutStep.processing;
    });

    try {
      final service = ref.read(payFastCheckoutServiceProvider);
      await service.confirmDemoPayment(
        intentId: session.intentId,
        outcome: success ? 'success' : 'failed',
        cardLast4: _method == 'card' ? _cardLast4 : null,
        errorMessage: success ? null : 'Demo payment declined by customer.',
      );

      PaymentIntentModel? intent = await service.getIntent(session.intentId);
      if (intent == null || (!intent.isPaid && !intent.isFailed)) {
        await for (final value in service.watchIntent(session.intentId)) {
          intent = value;
          if (intent == null) continue;
          if (intent.isPaid || intent.isFailed) break;
        }
      }

      if (!mounted) return;

      if (intent != null && intent.isPaid) {
        await _notifyCheckout(
          success: true,
          amount: intent.amount,
          currency: intent.currency,
          intentId: intent.intentId,
        );
        if (!mounted) return;
        Navigator.of(context).pop(
          PaymentProcessResult(
            transactionId: intent.transactionId ?? session.transactionId,
            paymentId: intent.paymentId ?? session.paymentId,
            status: PaymentStatus.success,
            message:
                'DEMO payment confirmed via SkillForge Demo Gateway. No real money moved.',
            amount: intent.amount,
            currency: intent.currency,
            intentId: intent.intentId,
            platformFee: intent.platformFee,
            sellerNet: intent.sellerNet,
          ),
        );
        return;
      }

      final failMessage = intent?.errorMessage ?? 'Demo payment failed.';
      await _notifyCheckout(
        success: false,
        amount: widget.amount,
        currency: widget.currency,
        intentId: session.intentId,
        errorMessage: failMessage,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _CheckoutStep.hosted;
        _error = failMessage;
      });
    } on PayFastCheckoutException catch (e) {
      await _notifyCheckout(
        success: false,
        amount: widget.amount,
        currency: widget.currency,
        intentId: _session?.intentId,
        errorMessage: e.message,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _CheckoutStep.hosted;
        _error = e.message;
      });
    } catch (e) {
      await _notifyCheckout(
        success: false,
        amount: widget.amount,
        currency: widget.currency,
        intentId: _session?.intentId,
        errorMessage: e.toString(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _CheckoutStep.hosted;
        _error = e.toString();
      });
    }
  }

  /// Stripe Test (sandbox): the gateway creates the intent + Checkout Session,
  /// we open the hosted page and keep watching the same `paymentIntents` doc
  /// the Demo path uses. The Stripe webhook finalizes on the server.
  Future<void> _startStripe() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final service = ref.read(stripeCheckoutServiceProvider);
      final session = await service.createCheckout(
        type: widget.type,
        amount: widget.amount,
        description: widget.description,
        currency: widget.currency,
        role: widget.role,
        planId: widget.planId,
        creditPackId: widget.creditPackId,
        teacherId: widget.teacherId,
        orderId: widget.orderId,
        courseId: widget.metadata?['courseId']?.toString(),
        metadata: {
          ...?widget.metadata,
          'isDemo': false,
          'environment': 'test',
          'gateway': StripeConfig.provider,
        },
      );

      if (!mounted) return;
      setState(() {
        _stripeSession = session;
        _stripeSettled = false;
        _step = _CheckoutStep.stripeRedirect;
        _busy = false;
      });

      _watchStripeIntent(session.intentId);
      final opened = await service.openCheckout(session.checkoutUrl);
      if (!opened && mounted) {
        setState(() {
          _error =
              'Could not open the Stripe checkout tab automatically. Use '
              '"Open Stripe checkout" below or copy the link.';
        });
      }
    } on StripeCheckoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  void _watchStripeIntent(String intentId) {
    _stripeWatch?.cancel();
    _stripeWatch = ref
        .read(payFastCheckoutServiceProvider)
        .watchIntent(intentId)
        .listen((intent) {
      if (intent == null) return;
      if (intent.isPaid) {
        _settleStripe(intent, success: true);
      } else if (intent.isFailed) {
        _settleStripe(intent, success: false);
      }
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to track Stripe payment. $error');
    });
  }

  Future<void> _refreshStripeIntent() async {
    final session = _stripeSession;
    if (session == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(payFastCheckoutServiceProvider)
          .getIntent(session.intentId);
      if (!mounted) return;
      if (intent != null && (intent.isPaid || intent.isFailed)) {
        await _settleStripe(intent, success: intent.isPaid);
        return;
      }
      setState(() {
        _busy = false;
        _error =
            'Stripe has not confirmed this payment yet. Finish the checkout '
            'tab, then refresh again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _settleStripe(
    PaymentIntentModel intent, {
    required bool success,
  }) async {
    if (_stripeSettled) return;
    _stripeSettled = true;
    await _stripeWatch?.cancel();
    _stripeWatch = null;

    await _notifyCheckout(
      success: success,
      amount: intent.amount == 0 ? widget.amount : intent.amount,
      currency: intent.currency,
      intentId: intent.intentId,
      errorMessage: success ? null : intent.errorMessage,
    );
    if (!mounted) return;

    if (!success) {
      // A failed intent is terminal, so drop the dead session and let the
      // buyer pick a provider again — retrying mints a fresh Stripe session.
      setState(() {
        _busy = false;
        _stripeSettled = false;
        _stripeSession = null;
        _step = _CheckoutStep.method;
        _error = intent.errorMessage ?? 'Stripe Test payment failed.';
      });
      return;
    }

    Navigator.of(context).pop(
      PaymentProcessResult(
        transactionId:
            intent.transactionId ?? _stripeSession?.sessionId ?? intent.intentId,
        paymentId: intent.paymentId ?? intent.intentId,
        status: PaymentStatus.success,
        message:
            'Payment confirmed via ${StripeConfig.label}. No real money moved.',
        amount: intent.amount,
        currency: intent.currency,
        intentId: intent.intentId,
        platformFee: intent.platformFee,
        sellerNet: intent.sellerNet,
      ),
    );
  }

  Future<void> _cancelStripe() async {
    await _stripeWatch?.cancel();
    _stripeWatch = null;
    if (!mounted) return;
    setState(() {
      _stripeSession = null;
      _stripeSettled = false;
      _busy = false;
      _error = null;
      _step = _CheckoutStep.method;
    });
  }

  Future<void> _copyStripeLink() async {
    final url = _stripeSession?.checkoutUrl ?? '';
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stripe checkout link copied.')),
    );
  }

  Future<void> _notifyCheckout({
    required bool success,
    required double amount,
    required String currency,
    String? intentId,
    String? errorMessage,
  }) async {
    try {
      final payerId = ref.read(authStateProvider).value?.uid ?? '';
      if (payerId.isEmpty) return;
      await ref.read(demoPaymentNotificationHelperProvider).notifyCheckoutOutcome(
        payerId: payerId,
        type: widget.type,
        success: success,
        amount: amount,
        currency: currency,
        description: widget.description,
        intentId: intentId,
        planId: widget.planId,
        creditPackId: widget.creditPackId,
        teacherId: widget.teacherId,
        orderId: widget.orderId,
        errorMessage: errorMessage,
        metadata: widget.metadata,
      );
    } catch (_) {
      // Never block checkout UX on inbox write.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stripeEnabled =
        ref.watch(stripePaymentsEnabledProvider).value ?? false;
    final fee = _stripeSession?.platformFee ??
        _session?.platformFee ??
        _estimatedPlatformFee;
    final total = widget.amount;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SandboxBanner(theme: theme, stripe: _isStripe),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headerTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _headerSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SummaryCard(
              description: widget.description,
              currency: widget.currency,
              subtotal: total,
              platformFee: fee,
              showSellerNet: widget.type == PaymentType.course ||
                  widget.type == 'commerce_order',
              sellerNet: total - fee,
            ),
            const SizedBox(height: 16),
            if (_step == _CheckoutStep.method) ...[
              if (stripeEnabled) ...[
                Text(
                  'Checkout provider',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _ProviderChooser(
                  provider: _provider,
                  busy: _busy,
                  onChanged: (value) => setState(() {
                    _provider = value;
                    _providerTouched = true;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (_isStripe) ...[
                _StripeIntroCard(theme: theme),
                if (StripeConfig.hasLiveKeyConfigured) ...[
                  const SizedBox(height: 8),
                  Text(
                    StripeConfig.liveKeyWarning,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Creating Stripe Test checkout session…',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ] else ...[
                Text(
                  'Payment method',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...PayFastConfig.methods.map((method) {
                  final selected = _method == method.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _busy
                            ? null
                            : () => setState(() => _method = method.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                _iconFor(method.iconName),
                                color: selected
                                    ? AppColors.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      method.label,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      method.subtitle,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? AppColors.primary
                                    : theme.colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Starting SkillForge Demo Gateway session…',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
            if (_step == _CheckoutStep.stripeRedirect &&
                _stripeSession != null) ...[
              _StripeWaitingCard(theme: theme, session: _stripeSession!),
            ],
            if (_step == _CheckoutStep.hosted ||
                _step == _CheckoutStep.processing) ...[
              _HostedPaymentForm(
                method: _method,
                busy: _busy,
                otpSent: _otpSent,
                cardNumber: _cardNumber,
                expiry: _expiry,
                cvv: _cvv,
                walletMobile: _walletMobile,
                otp: _otp,
                onSendOtp: () {
                  setState(() {
                    _otpSent = true;
                    _error = null;
                    _otp.text = '123456';
                  });
                },
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Processing demo payment… Finalizing invoice & history.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_step == _CheckoutStep.method)
              FilledButton.icon(
                onPressed: _busy ? null : (_isStripe ? _startStripe : _startHosted),
                icon: Icon(
                  _isStripe ? Icons.open_in_new_rounded : Icons.payments_rounded,
                ),
                label: Text(
                  _busy
                      ? 'Processing…'
                      : _isStripe
                          ? 'Pay with Stripe · ${widget.currency} ${total.toStringAsFixed(2)}'
                          : 'Continue · ${widget.currency} ${total.toStringAsFixed(2)}',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (_step == _CheckoutStep.stripeRedirect &&
                _stripeSession != null) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _refreshStripeIntent,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _busy ? 'Checking Stripe…' : 'I completed payment — refresh',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => ref
                        .read(stripeCheckoutServiceProvider)
                        .openCheckout(_stripeSession!.checkoutUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open Stripe checkout'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _copyStripeLink,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Copy link'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _busy ? null : _cancelStripe,
                      child: const Text('Change provider'),
                    ),
                  ),
                ],
              ),
            ],
            if (_step == _CheckoutStep.hosted && !_busy) ...[
              FilledButton.icon(
                onPressed: () => _confirm(success: true),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  'Pay ${widget.currency} ${total.toStringAsFixed(2)} (Demo Success)',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _confirm(success: false),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Simulate payment failure'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _step = _CheckoutStep.method;
                  _session = null;
                  _otpSent = false;
                  _error = null;
                }),
                child: const Text('Change payment method'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _isStripe
                  ? '${StripeConfig.label} — card details are entered on Stripe, never in SkillForge. Test cards only.'
                  : 'DEMO MODE — card/wallet details are never charged. SkillForge never stores full card numbers.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SandboxBanner extends StatelessWidget {
  const _SandboxBanner({required this.theme, required this.stripe});

  final ThemeData theme;
  final bool stripe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE69C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF856404), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stripe ? StripeConfig.sandboxBanner : PayFastConfig.demoBanner,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF856404),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase 3 chooser — Demo stays first so the exhibition path is one tap away.
class _ProviderChooser extends StatelessWidget {
  const _ProviderChooser({
    required this.provider,
    required this.busy,
    required this.onChanged,
  });

  final String provider;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProviderTile(
          id: _ProviderId.demo,
          label: StripeConfig.demoLabel,
          subtitle: StripeConfig.demoSubtitle,
          icon: Icons.science_rounded,
          selected: provider == _ProviderId.demo,
          busy: busy,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        _ProviderTile(
          id: _ProviderId.stripe,
          label: StripeConfig.label,
          subtitle: StripeConfig.subtitle,
          icon: Icons.credit_score_rounded,
          selected: provider == _ProviderId.stripe,
          busy: busy,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.busy,
    required this.onChanged,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : () => onChanged(id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? AppColors.primary : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripeIntroCard extends StatelessWidget {
  const _StripeIntroCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  StripeConfig.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            StripeConfig.redirectNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            StripeConfig.testCardHint,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeWaitingCard extends StatelessWidget {
  const _StripeWaitingCard({required this.theme, required this.session});

  final ThemeData theme;
  final StripeCheckoutSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Waiting for Stripe confirmation',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete the payment in the Stripe tab with a test card. This '
            'sheet closes itself as soon as the webhook finalizes your order.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            StripeConfig.testCardHint,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (session.sessionId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Session ${session.sessionId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HostedPaymentForm extends StatelessWidget {
  const _HostedPaymentForm({
    required this.method,
    required this.busy,
    required this.otpSent,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.walletMobile,
    required this.otp,
    required this.onSendOtp,
  });

  final String method;
  final bool busy;
  final bool otpSent;
  final TextEditingController cardNumber;
  final TextEditingController expiry;
  final TextEditingController cvv;
  final TextEditingController walletMobile;
  final TextEditingController otp;
  final VoidCallback onSendOtp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            method == 'card'
                ? 'Card details'
                : method == 'raast'
                    ? 'Bank / Raast transfer'
                    : 'Wallet payment',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (method == 'card') ...[
            TextField(
              controller: cardNumber,
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                LengthLimitingTextInputFormatter(19),
              ],
              decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: '4242 4242 4242 4242',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: expiry,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      hintText: 'MM/YY',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: cvv,
                    enabled: !busy,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (method == 'raast') ...[
            Text(
              'Demo bank transfer reference will be generated on success. No real transfer occurs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            TextField(
              controller: walletMobile,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: method == 'jazzcash'
                    ? 'JazzCash mobile number'
                    : 'Easypaisa mobile number',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (method != 'raast') ...[
            const SizedBox(height: 12),
            if (!otpSent)
              OutlinedButton.icon(
                onPressed: busy ? null : onSendOtp,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Send demo OTP'),
              )
            else ...[
              TextField(
                controller: otp,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  hintText: '123456',
                  helperText: 'Demo OTP is always 123456',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.description,
    required this.currency,
    required this.subtotal,
    required this.platformFee,
    required this.showSellerNet,
    required this.sellerNet,
  });

  final String description;
  final String currency;
  final double subtotal;
  final double platformFee;
  final bool showSellerNet;
  final double sellerNet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _row(theme, 'Subtotal', '$currency ${subtotal.toStringAsFixed(2)}'),
          _row(
            theme,
            'Platform fee',
            '$currency ${platformFee.toStringAsFixed(2)}',
          ),
          if (showSellerNet)
            _row(
              theme,
              'Seller receives',
              '$currency ${sellerNet.toStringAsFixed(2)}',
            ),
          const Divider(height: 20),
          _row(
            theme,
            'You pay',
            '$currency ${subtotal.toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
