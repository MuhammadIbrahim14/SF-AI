import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_lock_service.dart';
import '../core/services/biometric_service.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';

const _notProvided = Object();

class AppLockState {
  const AppLockState({
    this.firebaseUid,
    this.isEnabled = false,
    this.isUnlocked = true,
    this.isBiometricAvailable = false,
    this.isBiometricEnabled = false,
    this.biometricLabel = 'Biometrics unavailable',
    this.failedAttempts = 0,
    this.errorMessage,
  });

  final String? firebaseUid;
  final bool isEnabled;
  final bool isUnlocked;
  final bool isBiometricAvailable;
  final bool isBiometricEnabled;
  final String biometricLabel;
  final int failedAttempts;
  final String? errorMessage;

  AppLockState copyWith({
    String? firebaseUid,
    bool? isEnabled,
    bool? isUnlocked,
    bool? isBiometricAvailable,
    bool? isBiometricEnabled,
    String? biometricLabel,
    int? failedAttempts,
    Object? errorMessage = _notProvided,
  }) {
    return AppLockState(
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isEnabled: isEnabled ?? this.isEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      biometricLabel: biometricLabel ?? this.biometricLabel,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final appLockProvider = AsyncNotifierProvider<AppLockNotifier, AppLockState>(
  AppLockNotifier.new,
);

class AppLockNotifier extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final firebaseUser = await ref.watch(authStateProvider.future);
    if (firebaseUser == null) return const AppLockState();
    final firebaseUid = firebaseUser.uid;

    try {
      final appLockService = ref.read(appLockServiceProvider);
      final availability = await ref
          .read(biometricServiceProvider)
          .getAvailability();
      final isEnabled = await appLockService.isLockEnabled(
        firebaseUid: firebaseUid,
      );
      final biometricEnabled = isEnabled && availability.isAvailable
          ? await appLockService.isBiometricEnabled(firebaseUid: firebaseUid)
          : false;

      return AppLockState(
        firebaseUid: firebaseUid,
        isEnabled: isEnabled,
        isUnlocked: !isEnabled,
        isBiometricAvailable: availability.isAvailable,
        isBiometricEnabled: biometricEnabled,
        biometricLabel: availability.label,
      );
    } catch (error) {
      return AppLockState(
        firebaseUid: firebaseUid,
        isEnabled: true,
        isUnlocked: false,
        errorMessage:
            'App Lock storage is unavailable. Access remains locked for safety.',
      );
    }
  }

  Future<bool> enableLock(String pin) async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (kDebugMode) debugPrint('[AppLock] enableLock start');

    try {
      await ref
          .read(appLockServiceProvider)
          .enableLock(pin: pin, firebaseUid: firebaseUid);
      final availability = await ref
          .read(biometricServiceProvider)
          .getAvailability();
      state = AsyncData(
        AppLockState(
          firebaseUid: firebaseUid,
          isEnabled: true,
          isUnlocked: true,
          isBiometricAvailable: availability.isAvailable,
          biometricLabel: availability.label,
        ),
      );
      if (kDebugMode) debugPrint('[AppLock] enableLock success');
      return true;
    } catch (error) {
      state = AsyncData(current.copyWith(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  Future<bool> disableLock() async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (kDebugMode) debugPrint('[AppLock] disableLock start');

    try {
      await ref
          .read(appLockServiceProvider)
          .disableLock(firebaseUid: firebaseUid);
      state = AsyncData(
        current.copyWith(
          isEnabled: false,
          isUnlocked: true,
          isBiometricEnabled: false,
          failedAttempts: 0,
          errorMessage: null,
        ),
      );
      if (kDebugMode) debugPrint('[AppLock] disableLock success');
      return true;
    } catch (error) {
      state = AsyncData(current.copyWith(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  Future<bool> disableLockWithPin(String pin) async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (kDebugMode) debugPrint('[AppLock] disableLock start');

    if (!current.isEnabled) {
      state = AsyncData(
        current.copyWith(
          isEnabled: false,
          isUnlocked: true,
          isBiometricEnabled: false,
          failedAttempts: 0,
          errorMessage: null,
        ),
      );
      if (kDebugMode) debugPrint('[AppLock] disableLock success');
      return true;
    }

    try {
      final service = ref.read(appLockServiceProvider);
      final isValid = await service.verifyPin(
        pin: pin,
        firebaseUid: firebaseUid,
      );

      if (!isValid) {
        state = AsyncData(
          current.copyWith(
            failedAttempts: current.failedAttempts + 1,
            errorMessage: 'Incorrect PIN.',
          ),
        );
        return false;
      }

      await service.disableLock(firebaseUid: firebaseUid);
      state = AsyncData(
        current.copyWith(
          isEnabled: false,
          isUnlocked: true,
          isBiometricEnabled: false,
          failedAttempts: 0,
          errorMessage: null,
        ),
      );
      if (kDebugMode) debugPrint('[AppLock] disableLock success');
      return true;
    } catch (error) {
      state = AsyncData(current.copyWith(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (!current.isEnabled) {
      state = AsyncData(
        current.copyWith(
          isUnlocked: true,
          failedAttempts: 0,
          errorMessage: null,
        ),
      );
      return true;
    }

    try {
      final isValid = await ref
          .read(appLockServiceProvider)
          .verifyPin(pin: pin, firebaseUid: firebaseUid);

      if (isValid) {
        state = AsyncData(
          current.copyWith(
            isUnlocked: true,
            failedAttempts: 0,
            errorMessage: null,
          ),
        );
        return true;
      }

      state = AsyncData(
        current.copyWith(
          isUnlocked: current.isUnlocked,
          failedAttempts: current.failedAttempts + 1,
          errorMessage: 'Incorrect PIN.',
        ),
      );
      return false;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isUnlocked: current.isUnlocked,
          errorMessage: _errorMessage(error),
        ),
      );
      return false;
    }
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (kDebugMode) debugPrint('[AppLock] changePin start');

    if (!current.isEnabled) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Enable App Lock before changing the PIN.',
        ),
      );
      return false;
    }

    try {
      final changed = await ref
          .read(appLockServiceProvider)
          .changePin(
            currentPin: currentPin,
            newPin: newPin,
            firebaseUid: firebaseUid,
          );

      if (!changed) {
        state = AsyncData(
          current.copyWith(
            failedAttempts: current.failedAttempts + 1,
            errorMessage: 'Current PIN is incorrect.',
          ),
        );
        return false;
      }

      state = AsyncData(
        current.copyWith(
          isUnlocked: true,
          failedAttempts: 0,
          errorMessage: null,
        ),
      );
      if (kDebugMode) debugPrint('[AppLock] changePin success');
      return true;
    } catch (error) {
      state = AsyncData(current.copyWith(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  Future<bool> isLockEnabled() async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);

    try {
      final isEnabled = await ref
          .read(appLockServiceProvider)
          .isLockEnabled(firebaseUid: firebaseUid);
      state = AsyncData(
        current.copyWith(
          isEnabled: isEnabled,
          isUnlocked: isEnabled ? current.isUnlocked : true,
          isBiometricEnabled: isEnabled ? current.isBiometricEnabled : false,
          failedAttempts: isEnabled ? current.failedAttempts : 0,
          errorMessage: null,
        ),
      );
      return isEnabled;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isEnabled: true,
          isUnlocked: false,
          errorMessage:
              'App Lock storage is unavailable. Access remains locked for safety.',
        ),
      );
      return true;
    }
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);

    if (enabled && !current.isEnabled) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Enable App Lock before enabling biometrics.',
        ),
      );
      return false;
    }
    if (enabled && !current.isBiometricAvailable) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Biometric authentication is unavailable.',
        ),
      );
      return false;
    }

    try {
      await ref
          .read(appLockServiceProvider)
          .setBiometricEnabled(enabled: enabled, firebaseUid: firebaseUid);
      state = AsyncData(
        current.copyWith(isBiometricEnabled: enabled, errorMessage: null),
      );
      return true;
    } catch (error) {
      state = AsyncData(current.copyWith(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (!current.isEnabled ||
        !current.isBiometricEnabled ||
        !current.isBiometricAvailable) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Biometric unlock is not available. Use your PIN.',
        ),
      );
      return false;
    }

    final result = await ref.read(biometricServiceProvider).authenticate();
    if (result.success) {
      state = AsyncData(
        current.copyWith(
          isUnlocked: true,
          failedAttempts: 0,
          errorMessage: null,
        ),
      );
      return true;
    }

    state = AsyncData(
      current.copyWith(
        isUnlocked: false,
        errorMessage:
            result.errorMessage ??
            'Biometric authentication failed. Use your PIN.',
      ),
    );
    return false;
  }

  void lock() {
    final firebaseUid = _requireFirebaseUid();
    final current = _currentStateFor(firebaseUid);
    if (!current.isEnabled) return;

    state = AsyncData(
      current.copyWith(
        isUnlocked: false,
        failedAttempts: 0,
        errorMessage: null,
      ),
    );
  }

  void clearError() {
    final firebaseUid = _requireFirebaseUid();
    state = AsyncData(
      _currentStateFor(firebaseUid).copyWith(errorMessage: null),
    );
  }

  AppLockState get _currentState {
    return state.value ?? const AppLockState();
  }

  AppLockState _currentStateFor(String firebaseUid) {
    final current = _currentState;
    if (current.firebaseUid == firebaseUid) return current;
    return AppLockState(firebaseUid: firebaseUid);
  }

  String _requireFirebaseUid() {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      throw const AppLockException(
        'An authenticated Firebase user is required for App Lock.',
      );
    }
    return firebaseUser.uid;
  }

  String _errorMessage(Object error) {
    if (error is AppLockException) return error.message;
    return 'Unable to update App Lock settings.';
  }
}
