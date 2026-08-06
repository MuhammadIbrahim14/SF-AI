class SettlementExecutorConfig {
  const SettlementExecutorConfig._();

  static const bool settlementBackendAvailable = false;
  static const String settlementExecutorMode = 'pendingBackend';

  static const String pendingBackendMessage =
      'Backend executor required. Enable Blaze and deploy Cloud Functions to activate this action.';

  static const String pendingBackendBanner =
      'Resolution settlement backend is pending. Release/Split will activate after Cloud Functions deployment.';
}
