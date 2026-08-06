class CopilotAiMode {
  const CopilotAiMode._();

  static const mock = 'mock';
  static const gateway = 'gateway';
  static const disabled = 'disabled';
}

class CopilotAiProvider {
  const CopilotAiProvider._();

  static const mock = 'mock';
  static const gemini = 'gemini';
  static const openai = 'openai';
}

class CopilotAiConfig {
  const CopilotAiConfig._();

  static const bool aiEnabled = bool.fromEnvironment(
    'AI_ENABLED',
    defaultValue: true,
  );
  static const String aiMode = String.fromEnvironment(
    'AI_MODE',
    defaultValue: CopilotAiMode.gateway,
  );
  static const String _gatewayBaseUrlRaw = String.fromEnvironment(
    'AI_GATEWAY_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  /// Normalized gateway base URL (no trailing slash).
  /// Also repairs a common typo: `http://localhost3001` → `http://localhost:3001`.
  static String get gatewayBaseUrl {
    var value = _gatewayBaseUrlRaw.trim();
    value = value.replaceFirstMapped(
      RegExp(r'^(https?://)(localhost|127\.0\.0\.1)(\d{2,5})(/.*)?$',
          caseSensitive: false),
      (m) => '${m[1]}${m[2]}:${m[3]}${m[4] ?? ''}',
    );
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static const String defaultProvider = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: CopilotAiProvider.openai,
  );
  static const int requestTimeoutSeconds = int.fromEnvironment(
    'AI_REQUEST_TIMEOUT_SECONDS',
    defaultValue: 130,
  );
  static const int maxPromptChars = int.fromEnvironment(
    'AI_MAX_PROMPT_CHARS',
    defaultValue: 4000,
  );

  static const bool enableTeacherAi = true;
  static const bool enableStudentAi = true;
  static const bool enableCompanyAi = true;
  static const bool enableAdminAi = true;
  static const bool enableFreelancerAi = true;
  static const bool enableCustomerAi = true;

  static bool get isLocalhostGateway {
    final value = gatewayBaseUrl.toLowerCase();
    return value.contains('localhost') ||
        value.contains('127.0.0.1') ||
        value.contains('10.0.2.2');
  }

  static const String releaseLocalhostWarning =
      'AI Gateway is configured for localhost. Use a deployed HTTPS gateway for APK/EXE/Web release.';

  // Security note:
  // Never place Gemini/OpenAI/API keys in Flutter. Real provider keys must live
  // only in the external gateway/proxy environment variables.
}
