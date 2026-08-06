import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/errors/app_exceptions.dart';
import 'auth_repository.dart';

/// SkillForge AI — Firebase Auth Repository Implementation
/// Wraps [FirebaseAuth] and maps errors to [AuthException].
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    } catch (e) {
      throw AuthException('An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    } catch (e) {
      throw AuthException('An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        return await _auth.signInWithPopup(provider);
      }

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final account = await googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw const AuthException(
          'Google sign-in did not return a valid identity token.',
          'missing-google-id-token',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      throw _mapGoogleSignInException(e);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    } on UnsupportedError {
      throw const AuthException(
        'Google sign-in is not supported on this platform yet.',
        'google-platform-unsupported',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Google sign-in failed: ${e.toString()}');
    }
  }

  @override
  Future<UserCredential> signInWithGitHub() async {
    try {
      final provider = GithubAuthProvider()..addScope('read:user');
      if (kIsWeb) {
        return await _auth.signInWithPopup(provider);
      }
      return await _auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    } on UnsupportedError {
      throw const AuthException(
        'GitHub sign-in is not supported on this platform yet. Try web for GitHub OAuth.',
        'github-platform-unsupported',
      );
    } catch (e) {
      throw AuthException('GitHub sign-in failed: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut().timeout(
            const Duration(seconds: 2),
          );
        } catch (_) {
          // Firebase sign-out is still the source of truth.
        }
      }
      await _auth.signOut().timeout(const Duration(seconds: 5));
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    } catch (e) {
      throw AuthException('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    } catch (e) {
      throw AuthException('Failed to send reset email: ${e.toString()}');
    }
  }
}

AuthException _mapGoogleSignInException(GoogleSignInException error) {
  return switch (error.code) {
    GoogleSignInExceptionCode.canceled => const AuthException(
      'Google sign-in was cancelled.',
      'google-sign-in-cancelled',
    ),
    GoogleSignInExceptionCode.interrupted => const AuthException(
      'Google sign-in was interrupted. Please try again.',
      'google-sign-in-interrupted',
    ),
    GoogleSignInExceptionCode.uiUnavailable => const AuthException(
      'Google sign-in UI is unavailable on this device.',
      'google-sign-in-ui-unavailable',
    ),
    GoogleSignInExceptionCode.clientConfigurationError => const AuthException(
      'Google sign-in is not configured correctly. Check Firebase, SHA fingerprints, and OAuth client IDs.',
      'google-client-configuration-error',
    ),
    GoogleSignInExceptionCode.providerConfigurationError => const AuthException(
      'Google provider configuration is missing or invalid.',
      'google-provider-configuration-error',
    ),
    GoogleSignInExceptionCode.userMismatch => const AuthException(
      'Google sign-in account mismatch. Please sign out and try again.',
      'google-user-mismatch',
    ),
    GoogleSignInExceptionCode.unknownError => const AuthException(
      'Google sign-in failed. Please try again.',
      'google-sign-in-failed',
    ),
  };
}
