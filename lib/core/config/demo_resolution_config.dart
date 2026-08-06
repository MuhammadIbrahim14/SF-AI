class DemoResolutionConfig {
  const DemoResolutionConfig._();

  static const bool isDemoResolutionExecutorEnabled = true;
  static const String demoModeLabel = 'Demo Settlement Mode';
  static const bool blockRealMoneyTransfer = true;

  static const String bannerMessage =
      'Demo Settlement Mode: This updates SkillForge demo wallet/order records only. No real money is transferred.';
}
