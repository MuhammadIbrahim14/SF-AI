/// SkillForge Demo Gateway client config (Option A).
/// No PayFast merchant ID. No real money. Clear DEMO labeling.
class PayFastConfig {
  const PayFastConfig._();

  static const String gatewayId = 'skillforge_demo';
  static const String currency = 'PKR';
  static const String merchantDisplayName = 'SkillForge AI';
  static const String environment = 'demo';
  static const bool isDemo = true;

  /// Client pause switch. Override at run time:
  /// `flutter run --dart-define=DEMO_GATEWAY_ENABLED=false`
  /// Default is true — demo checkout works without merchant keys.
  static const bool enabled = bool.fromEnvironment(
    'DEMO_GATEWAY_ENABLED',
    defaultValue: true,
  );

  static const String pausedMessage = 'Demo payments temporarily unavailable.';

  static const String demoBanner =
      'DEMO / TEST MODE — no real money. Payments are simulated.';

  static bool get isAvailable => enabled;

  /// Preferred checkout methods shown in the SkillForge-hosted demo page.
  static const List<PayFastPaymentMethod> methods = [
    PayFastPaymentMethod(
      id: 'card',
      label: 'Debit / Credit Card',
      subtitle: 'Visa, Mastercard (demo)',
      iconName: 'credit_card',
    ),
    PayFastPaymentMethod(
      id: 'jazzcash',
      label: 'JazzCash',
      subtitle: 'Pay with JazzCash wallet (demo)',
      iconName: 'wallet',
    ),
    PayFastPaymentMethod(
      id: 'easypaisa',
      label: 'Easypaisa',
      subtitle: 'Pay with Easypaisa wallet (demo)',
      iconName: 'account_balance_wallet',
    ),
    PayFastPaymentMethod(
      id: 'raast',
      label: 'Raast / Bank',
      subtitle: 'Instant bank transfer (demo)',
      iconName: 'account_balance',
    ),
  ];
}

class PayFastPaymentMethod {
  const PayFastPaymentMethod({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.iconName,
  });

  final String id;
  final String label;
  final String subtitle;
  final String iconName;
}
