class EmailJsConfig {
  const EmailJsConfig({
    required this.enabled,
    required this.serviceId,
    required this.publicKey,
    required this.templateId,
    this.fromName = 'SkillForge AI',
    this.replyTo = '',
    this.sendLoginEmails = false,
    this.sendCourseUpdateEmails = true,
    this.sendHiringEmails = true,
    this.sendMarketplaceEmails = true,
  });

  static const defaultServiceId = 'service_1ui81vg';
  static const defaultPublicKey = 'rpFJlRRej7pvIQNgz';
  static const defaultTemplateId = 'template_sjgbdih';
  static const defaultFromName = 'SkillForge AI';
  static const defaultReplyTo = 'foraptech080@gmail.com';

  static const dartDefineServiceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: defaultServiceId,
  );
  static const dartDefinePublicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: defaultPublicKey,
  );
  static const dartDefineTemplateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: defaultTemplateId,
  );

  final bool enabled;
  final String serviceId;
  final String publicKey;
  final String templateId;
  final String fromName;
  final String replyTo;
  final bool sendLoginEmails;
  final bool sendCourseUpdateEmails;
  final bool sendHiringEmails;
  final bool sendMarketplaceEmails;

  bool get isConfigured =>
      enabled &&
      serviceId.trim().isNotEmpty &&
      publicKey.trim().isNotEmpty &&
      templateId.trim().isNotEmpty;

  factory EmailJsConfig.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final hasFirestoreConfig =
        (map['serviceId']?.toString().trim().isNotEmpty ?? false) ||
        (map['publicKey']?.toString().trim().isNotEmpty ?? false) ||
        (map['templateId']?.toString().trim().isNotEmpty ?? false);
    return EmailJsConfig(
      enabled: map['enabled'] == true || (!hasFirestoreConfig && hasDartDefine),
      serviceId: _string(map['serviceId'], dartDefineServiceId),
      publicKey: _string(map['publicKey'], dartDefinePublicKey),
      templateId: _string(map['templateId'], dartDefineTemplateId),
      fromName: _string(map['fromName'], defaultFromName),
      replyTo: _string(map['replyTo'], defaultReplyTo),
      sendLoginEmails: map['sendLoginEmails'] == true,
      sendCourseUpdateEmails: map['sendCourseUpdateEmails'] != false,
      sendHiringEmails: map['sendHiringEmails'] != false,
      sendMarketplaceEmails: map['sendMarketplaceEmails'] != false,
    );
  }

  static bool get hasDartDefine =>
      dartDefineServiceId.trim().isNotEmpty &&
      dartDefinePublicKey.trim().isNotEmpty &&
      dartDefineTemplateId.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'serviceId': serviceId.trim(),
      'publicKey': publicKey.trim(),
      'templateId': templateId.trim(),
      'fromName': fromName.trim(),
      'replyTo': replyTo.trim(),
      'sendLoginEmails': sendLoginEmails,
      'sendCourseUpdateEmails': sendCourseUpdateEmails,
      'sendHiringEmails': sendHiringEmails,
      'sendMarketplaceEmails': sendMarketplaceEmails,
    };
  }
}

String _string(Object? value, [String fallback = '']) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback.trim();
}
