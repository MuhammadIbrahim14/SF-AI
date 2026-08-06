// SkillForge AI — Custom Exception Classes
// Maps Firebase error codes to user-friendly messages.

/// Base exception for all SkillForge errors.
sealed class AppException implements Exception {
  const AppException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

/// Exception thrown during authentication operations.
class AuthException extends AppException {
  const AuthException(super.message, [super.code]);

  /// Maps Firebase Auth error codes to human-readable messages.
  factory AuthException.fromCode(String code) {
    return switch (code) {
      'user-not-found' => const AuthException(
        'No account found with this email.',
        'user-not-found',
      ),
      'wrong-password' => const AuthException(
        'Incorrect password. Please try again.',
        'wrong-password',
      ),
      'invalid-credential' => const AuthException(
        'Invalid email or password.',
        'invalid-credential',
      ),
      'email-already-in-use' => const AuthException(
        'An account with this email already exists.',
        'email-already-in-use',
      ),
      'weak-password' => const AuthException(
        'Password is too weak. Use at least 8 characters.',
        'weak-password',
      ),
      'invalid-email' => const AuthException(
        'Please enter a valid email address.',
        'invalid-email',
      ),
      'user-disabled' => const AuthException(
        'This account has been disabled. Contact support.',
        'user-disabled',
      ),
      'too-many-requests' => const AuthException(
        'Too many attempts. Please try again later.',
        'too-many-requests',
      ),
      'operation-not-allowed' => const AuthException(
        'This sign-in method is not enabled in Firebase Authentication.',
        'operation-not-allowed',
      ),
      'account-exists-with-different-credential' => const AuthException(
        'An account already exists with this email using another sign-in method. Please sign in with the original provider, then link this provider from your profile later.',
        'account-exists-with-different-credential',
      ),
      'popup-closed-by-user' => const AuthException(
        'Sign-in was cancelled.',
        'popup-closed-by-user',
      ),
      'cancelled-popup-request' => const AuthException(
        'Another sign-in popup is already open.',
        'cancelled-popup-request',
      ),
      'popup-blocked' => const AuthException(
        'The sign-in popup was blocked by the browser. Please allow popups for this site and try again.',
        'popup-blocked',
      ),
      'web-context-cancelled' => const AuthException(
        'Sign-in was cancelled before it completed.',
        'web-context-cancelled',
      ),
      'web-context-already-presented' => const AuthException(
        'A sign-in window is already open.',
        'web-context-already-presented',
      ),
      'network-request-failed' => const AuthException(
        'Network error. Check your connection.',
        'network-request-failed',
      ),
      _ => AuthException('Authentication failed: $code', code),
    };
  }
}

/// Exception thrown during Firestore operations.
class FirestoreException extends AppException {
  const FirestoreException(super.message, [super.code]);

  factory FirestoreException.fromCode(String code, [String? detail]) {
    // Windows/desktop SDKs may return gRPC-style or plugin-prefixed codes.
    // Desktop often surfaces permission-denied as code "unknown" with the
    // real reason only in the message — inspect both.
    final normalized = code
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .split('/')
        .last;
    final detailLower = (detail ?? '').toLowerCase();
    final looksDenied =
        normalized == 'permission-denied' ||
        detailLower.contains('permission-denied') ||
        detailLower.contains('permission_denied') ||
        detailLower.contains('missing or insufficient permissions');
    if (looksDenied) {
      return const FirestoreException(
        'You don\'t have permission to perform this action.',
        'permission-denied',
      );
    }
    final trimmedDetail = (detail ?? '').trim();
    return switch (normalized) {
      'not-found' => const FirestoreException(
        'The requested document was not found.',
        'not-found',
      ),
      'already-exists' => const FirestoreException(
        'This document already exists.',
        'already-exists',
      ),
      'unavailable' => const FirestoreException(
        'Service temporarily unavailable. Try again.',
        'unavailable',
      ),
      // Temporarily clearer for Windows "unknown" debugging.
      _ => FirestoreException(
        trimmedDetail.isEmpty
            ? 'Database error: $normalized'
            : 'Database error: $normalized — $trimmedDetail',
        normalized,
      ),
    };
  }
}
