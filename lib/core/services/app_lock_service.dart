import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockException implements Exception {
  const AppLockException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppLockService {
  AppLockService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String enabledKey = 'app_lock_enabled';
  static const String pinHashKey = 'app_lock_pin_hash';
  static const String biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _storage;

  Future<void> enableLock({
    required String pin,
    required String firebaseUid,
  }) async {
    _validateFirebaseUid(firebaseUid);
    _validatePin(pin);

    final pinHash = _hashPin(pin: pin, firebaseUid: firebaseUid);
    final scopedEnabledKey = _scopedKey(enabledKey, firebaseUid);
    final scopedPinHashKey = _scopedKey(pinHashKey, firebaseUid);

    try {
      await _storage.write(key: scopedPinHashKey, value: pinHash);
      await _storage.write(key: scopedEnabledKey, value: 'true');
    } catch (error) {
      try {
        await _storage.delete(key: scopedEnabledKey);
        await _storage.delete(key: scopedPinHashKey);
      } catch (_) {
        // Preserve the original secure-storage failure.
      }
      throw AppLockException('Unable to enable App Lock: $error');
    }
  }

  Future<void> disableLock({required String firebaseUid}) async {
    _validateFirebaseUid(firebaseUid);

    try {
      // Remove the enabled flag first so a partial cleanup never leaves the
      // application locked without a usable PIN hash.
      await _storage.delete(key: _scopedKey(enabledKey, firebaseUid));
      await _storage.delete(key: _scopedKey(pinHashKey, firebaseUid));
      await _storage.delete(key: _scopedKey(biometricEnabledKey, firebaseUid));
    } catch (error) {
      throw AppLockException('Unable to disable App Lock: $error');
    }
  }

  Future<bool> verifyPin({
    required String pin,
    required String firebaseUid,
  }) async {
    _validateFirebaseUid(firebaseUid);
    _validatePin(pin);

    try {
      if (!await isLockEnabled(firebaseUid: firebaseUid)) return false;

      final storedHash = await _storage.read(
        key: _scopedKey(pinHashKey, firebaseUid),
      );
      if (storedHash == null || storedHash.isEmpty) return false;

      final candidateHash = _hashPin(pin: pin, firebaseUid: firebaseUid);
      return _constantTimeEquals(storedHash, candidateHash);
    } catch (error) {
      if (error is AppLockException) rethrow;
      throw AppLockException('Unable to verify the App Lock PIN: $error');
    }
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
    required String firebaseUid,
  }) async {
    _validateFirebaseUid(firebaseUid);
    _validatePin(newPin);

    final currentPinMatches = await verifyPin(
      pin: currentPin,
      firebaseUid: firebaseUid,
    );
    if (!currentPinMatches) return false;

    try {
      final newHash = _hashPin(pin: newPin, firebaseUid: firebaseUid);
      await _storage.write(
        key: _scopedKey(pinHashKey, firebaseUid),
        value: newHash,
      );
      return true;
    } catch (error) {
      throw AppLockException('Unable to change the App Lock PIN: $error');
    }
  }

  Future<bool> isLockEnabled({required String firebaseUid}) async {
    _validateFirebaseUid(firebaseUid);

    try {
      final values = await Future.wait([
        _storage.read(key: _scopedKey(enabledKey, firebaseUid)),
        _storage.read(key: _scopedKey(pinHashKey, firebaseUid)),
      ]);

      return values[0] == 'true' && (values[1]?.isNotEmpty ?? false);
    } catch (error) {
      throw AppLockException('Unable to read App Lock settings: $error');
    }
  }

  Future<void> setBiometricEnabled({
    required bool enabled,
    required String firebaseUid,
  }) async {
    _validateFirebaseUid(firebaseUid);

    try {
      if (enabled && !await isLockEnabled(firebaseUid: firebaseUid)) {
        throw const AppLockException(
          'Enable App Lock before enabling biometric unlock.',
        );
      }

      final key = _scopedKey(biometricEnabledKey, firebaseUid);
      if (enabled) {
        await _storage.write(key: key, value: 'true');
      } else {
        await _storage.delete(key: key);
      }
    } catch (error) {
      if (error is AppLockException) rethrow;
      throw AppLockException(
        'Unable to update the biometric preference: $error',
      );
    }
  }

  Future<bool> isBiometricEnabled({required String firebaseUid}) async {
    _validateFirebaseUid(firebaseUid);

    try {
      if (!await isLockEnabled(firebaseUid: firebaseUid)) return false;
      return await _storage.read(
            key: _scopedKey(biometricEnabledKey, firebaseUid),
          ) ==
          'true';
    } catch (error) {
      if (error is AppLockException) rethrow;
      throw AppLockException('Unable to read the biometric preference: $error');
    }
  }

  static bool isValidPin(String pin) {
    return RegExp(r'^(?:\d{4}|\d{6})$').hasMatch(pin);
  }

  void _validatePin(String pin) {
    if (!isValidPin(pin)) {
      throw const AppLockException('PIN must contain exactly 4 or 6 digits.');
    }
  }

  void _validateFirebaseUid(String firebaseUid) {
    if (firebaseUid.trim().isEmpty) {
      throw const AppLockException(
        'An authenticated Firebase user is required for App Lock.',
      );
    }
  }

  String _hashPin({required String pin, required String firebaseUid}) {
    final saltedPin = utf8.encode('${firebaseUid.trim()}:$pin');
    return sha256.convert(saltedPin).toString();
  }

  String _scopedKey(String key, String firebaseUid) {
    return '${key}_${firebaseUid.trim()}';
  }

  bool _constantTimeEquals(String storedHash, String candidateHash) {
    if (storedHash.length != candidateHash.length) return false;

    var difference = 0;
    for (var index = 0; index < storedHash.length; index++) {
      difference |=
          storedHash.codeUnitAt(index) ^ candidateHash.codeUnitAt(index);
    }
    return difference == 0;
  }
}
