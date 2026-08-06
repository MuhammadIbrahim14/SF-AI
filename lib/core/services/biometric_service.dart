import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAvailability {
  const BiometricAvailability({
    required this.isAvailable,
    this.hasFace = false,
    this.hasFingerprint = false,
  });

  const BiometricAvailability.unavailable()
    : isAvailable = false,
      hasFace = false,
      hasFingerprint = false;

  final bool isAvailable;
  final bool hasFace;
  final bool hasFingerprint;

  String get label {
    if (hasFace && hasFingerprint) return 'Fingerprint or face unlock';
    if (hasFace) return 'Face unlock';
    if (hasFingerprint) return 'Fingerprint unlock';
    return isAvailable ? 'Biometric unlock' : 'Biometrics unavailable';
  }
}

class BiometricAuthResult {
  const BiometricAuthResult.success() : success = true, errorMessage = null;

  const BiometricAuthResult.failure([this.errorMessage]) : success = false;

  final bool success;
  final String? errorMessage;
}

class BiometricService {
  BiometricService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<BiometricAvailability> getAvailability() async {
    if (!isPlatformSupported) {
      return const BiometricAvailability.unavailable();
    }

    try {
      final deviceSupported = await _localAuthentication.isDeviceSupported();
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      if (!deviceSupported || !canCheckBiometrics) {
        return const BiometricAvailability.unavailable();
      }

      final types = await _localAuthentication.getAvailableBiometrics();
      if (types.isEmpty) {
        return const BiometricAvailability.unavailable();
      }

      return BiometricAvailability(
        isAvailable: true,
        hasFace: types.contains(BiometricType.face),
        hasFingerprint: types.contains(BiometricType.fingerprint),
      );
    } on LocalAuthException {
      return const BiometricAvailability.unavailable();
    } on PlatformException {
      return const BiometricAvailability.unavailable();
    } catch (_) {
      return const BiometricAvailability.unavailable();
    }
  }

  Future<BiometricAuthResult> authenticate() async {
    final availability = await getAvailability();
    if (!availability.isAvailable) {
      return const BiometricAuthResult.failure(
        'Biometric authentication is not available on this device.',
      );
    }

    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Unlock SkillForge AI',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? const BiometricAuthResult.success()
          : const BiometricAuthResult.failure(
              'Biometric authentication was not completed.',
            );
    } on LocalAuthException {
      return const BiometricAuthResult.failure(
        'Biometric authentication could not be completed. Use your PIN.',
      );
    } on PlatformException {
      return const BiometricAuthResult.failure(
        'Biometric authentication could not be completed. Use your PIN.',
      );
    } catch (_) {
      return const BiometricAuthResult.failure(
        'Biometric authentication is unavailable. Use your PIN.',
      );
    }
  }
}
