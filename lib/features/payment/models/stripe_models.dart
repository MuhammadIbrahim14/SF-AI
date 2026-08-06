/// Response of `GET /api/stripe/config` — the unauthenticated capability probe
/// the client uses to decide whether to offer Stripe in the method chooser.
class StripeGatewayConfig {
  const StripeGatewayConfig({
    required this.available,
    required this.mode,
    required this.connectEnabled,
    this.publishableKey,
  });

  final bool available;
  final String mode;
  final bool connectEnabled;
  final String? publishableKey;

  /// Sandbox-only guard: a Live gateway is treated as unavailable.
  bool get isUsable => available && mode.toLowerCase() != 'live';

  const StripeGatewayConfig.unavailable()
    : available = false,
      mode = 'test',
      connectEnabled = false,
      publishableKey = null;

  factory StripeGatewayConfig.fromMap(Map<String, dynamic> data) {
    return StripeGatewayConfig(
      available:
          data['available'] == true ||
          (data['enabled'] == true && data['configured'] == true),
      mode: data['mode']?.toString() ?? 'test',
      connectEnabled: data['connectEnabled'] == true,
      publishableKey: data['publishableKey']?.toString(),
    );
  }
}

/// Response of `POST /api/stripe/checkout` on the SkillForge gateway.
///
/// The gateway creates the `paymentIntents` doc (same shape the Demo path uses)
/// plus a Stripe Checkout Session, so the client can keep watching the intent
/// exactly like Demo checkout does.
class StripeCheckoutSession {
  const StripeCheckoutSession({
    required this.intentId,
    required this.checkoutUrl,
    required this.sessionId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.platformFee,
    required this.sellerNet,
    required this.platformFeeRate,
    required this.mode,
    this.publishableKey,
    this.connectAccountId,
  });

  final String intentId;
  final String checkoutUrl;
  final String sessionId;
  final String status;
  final double amount;
  final String currency;
  final double platformFee;
  final double sellerNet;
  final double platformFeeRate;

  /// Always `test` for SkillForge — the gateway rejects Live keys on boot.
  final String mode;
  final String? publishableKey;

  /// Set when the seller has an onboarded Connect account and the session was
  /// created with `transfer_data.destination`.
  final String? connectAccountId;

  bool get isLive => mode.toLowerCase() == 'live';

  factory StripeCheckoutSession.fromMap(Map<String, dynamic> data) {
    final connect = data['connect'];
    return StripeCheckoutSession(
      intentId: data['intentId']?.toString() ?? '',
      checkoutUrl:
          data['checkoutUrl']?.toString() ??
          data['checkoutPageUrl']?.toString() ??
          data['url']?.toString() ??
          '',
      sessionId:
          data['sessionId']?.toString() ??
          data['stripeSessionId']?.toString() ??
          '',
      status: data['status']?.toString() ?? 'pending',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString().toUpperCase() ?? 'PKR',
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
      sellerNet: (data['sellerNet'] as num?)?.toDouble() ?? 0,
      platformFeeRate: (data['platformFeeRate'] as num?)?.toDouble() ?? 0,
      mode: data['mode']?.toString() ?? 'test',
      publishableKey: data['publishableKey']?.toString(),
      connectAccountId: connect is Map
          ? connect['accountId']?.toString()
          : data['connectAccountId']?.toString(),
    );
  }
}

class StripeConnectState {
  const StripeConnectState._();

  static const none = 'none';
  static const pending = 'pending';
  static const active = 'active';
  static const restricted = 'restricted';
  static const unavailable = 'unavailable';
}

/// Seller-side Stripe Connect (Express, **test mode**) onboarding status.
class StripeConnectStatus {
  const StripeConnectStatus({
    required this.state,
    this.accountId,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
    this.message,
  });

  final String state;
  final String? accountId;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final String? message;

  bool get isConnected => state == StripeConnectState.active && chargesEnabled;
  bool get isPending => state == StripeConnectState.pending;
  bool get isUnavailable => state == StripeConnectState.unavailable;
  bool get hasAccount => (accountId ?? '').isNotEmpty;

  String get label => switch (state) {
    StripeConnectState.active =>
      chargesEnabled ? 'Connected (test)' : 'Connected · payouts pending',
    StripeConnectState.pending => 'Onboarding incomplete',
    StripeConnectState.restricted => 'Action needed in Stripe',
    StripeConnectState.unavailable => 'Unavailable',
    _ => 'Not connected',
  };

  const StripeConnectStatus.notConnected()
    : state = StripeConnectState.none,
      accountId = null,
      chargesEnabled = false,
      payoutsEnabled = false,
      detailsSubmitted = false,
      message = null;

  const StripeConnectStatus.unavailable(String reason)
    : state = StripeConnectState.unavailable,
      accountId = null,
      chargesEnabled = false,
      payoutsEnabled = false,
      detailsSubmitted = false,
      message = reason;

  factory StripeConnectStatus.fromMap(Map<String, dynamic> data) {
    final accountId = data['accountId']?.toString().trim() ?? '';
    final chargesEnabled = data['chargesEnabled'] == true;
    final payoutsEnabled = data['payoutsEnabled'] == true;
    final detailsSubmitted = data['detailsSubmitted'] == true;

    final raw = data['status']?.toString().trim().toLowerCase() ?? '';
    final state = switch (raw) {
      'active' || 'complete' || 'enabled' => StripeConnectState.active,
      'not_started' || 'none' => StripeConnectState.none,
      'pending' || 'incomplete' || 'onboarding' => StripeConnectState.pending,
      'restricted' || 'rejected' || 'disabled' => StripeConnectState.restricted,
      _ when accountId.isEmpty => StripeConnectState.none,
      _ when chargesEnabled => StripeConnectState.active,
      _ => StripeConnectState.pending,
    };

    return StripeConnectStatus(
      state: state,
      accountId: accountId.isEmpty ? null : accountId,
      chargesEnabled: chargesEnabled,
      payoutsEnabled: payoutsEnabled,
      detailsSubmitted: detailsSubmitted,
      message: data['message']?.toString(),
    );
  }
}

/// Response of `POST /api/stripe/connect/onboard` — an Account Link to open.
class StripeConnectOnboardLink {
  const StripeConnectOnboardLink({
    required this.url,
    required this.accountId,
    this.expiresAt,
  });

  final String url;
  final String accountId;
  final DateTime? expiresAt;

  factory StripeConnectOnboardLink.fromMap(Map<String, dynamic> data) {
    final expires = data['expiresAt'];
    return StripeConnectOnboardLink(
      url: data['url']?.toString() ?? data['onboardingUrl']?.toString() ?? '',
      accountId: data['accountId']?.toString() ?? '',
      expiresAt: expires is num
          ? DateTime.fromMillisecondsSinceEpoch(expires.toInt() * 1000)
          : DateTime.tryParse(expires?.toString() ?? ''),
    );
  }
}
