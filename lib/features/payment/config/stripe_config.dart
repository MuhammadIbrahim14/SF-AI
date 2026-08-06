/// Stripe **Test / Sandbox** client config.
///
/// Security: the Flutter app never holds a secret key. `sk_test_…` / `sk_live_…`
/// live only in the gateway environment. The client may optionally carry a
/// `pk_test_…` publishable key, and hosted Checkout does not even need that —
/// the gateway returns a ready Checkout URL.
class StripeConfig {
  const StripeConfig._();

  static const String provider = 'stripe';

  /// Every buyer-facing surface must say "Stripe Test (sandbox)".
  static const String label = 'Stripe Test (sandbox)';
  static const String subtitle = 'Card checkout hosted by Stripe — test mode';
  static const String demoLabel = 'Demo (sandbox)';
  static const String demoSubtitle = 'SkillForge Demo Gateway — simulated';

  /// Stripe treats PKR as a zero-decimal currency; the gateway sends whole
  /// rupees. The client only uses this as a request default.
  static const String currency = 'PKR';

  /// Shows the Demo | Stripe chooser. Turn off with
  /// `flutter run --dart-define=STRIPE_ENABLED=false` for a pure-Demo build.
  static const bool enabled = bool.fromEnvironment(
    'STRIPE_ENABLED',
    defaultValue: true,
  );

  static const String _publishableKeyRaw = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Only `pk_test_…` is accepted. A Live key is treated as unset so the app
  /// can never drive a real charge.
  static String get publishableKey {
    final value = _publishableKeyRaw.trim();
    return value.startsWith('pk_test_') ? value : '';
  }

  static bool get hasLiveKeyConfigured =>
      _publishableKeyRaw.trim().startsWith('pk_live_');

  static const String sandboxBanner =
      'STRIPE TEST MODE — sandbox card payments only. No real money moves.';

  static const String testCardHint =
      'Test card 4242 4242 4242 4242 · any future expiry · any CVC · any ZIP';

  static const String liveKeyWarning =
      'A Live Stripe publishable key is configured. SkillForge only supports '
      'Stripe Test (sandbox); the key was ignored.';

  static const String demoGatewayLabel = 'Demo Gateway (sandbox)';

  static const String redirectNotice =
      'You will be taken to Stripe\'s hosted checkout page in a new tab. '
      'Come back here once payment completes — enrollment finalizes automatically.';
}

/// Human label for a stored gateway / `paymentMethod` tag such as
/// `stripe`, `skillforge_demo` or `payfast`.
String paymentProviderLabel(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return 'Unattributed';
  final normalized = value.toLowerCase();
  if (normalized.contains('stripe')) return StripeConfig.label;
  if (normalized.contains('demo') || normalized.contains('skillforge')) {
    return StripeConfig.demoGatewayLabel;
  }
  if (normalized.contains('payfast')) return 'PayFast';
  return value;
}
