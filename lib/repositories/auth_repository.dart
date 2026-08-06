import 'package:firebase_auth/firebase_auth.dart';

/// SkillForge AI — Auth Repository Contract
/// Defines the authentication interface that data layer must implement.
abstract class AuthRepository {
  /// Returns a stream of [User] that emits when auth state changes.
  Stream<User?> get authStateChanges;

  /// Returns the currently signed-in [User], or null.
  User? get currentUser;

  /// Signs up a new user with email and password.
  /// Returns the [UserCredential] on success.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Signs in an existing user with email and password.
  /// Returns the [UserCredential] on success.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  });

  /// Signs in using Google through Firebase Authentication.
  Future<UserCredential> signInWithGoogle();

  /// Signs in using GitHub through Firebase Authentication.
  Future<UserCredential> signInWithGitHub();

  /// Signs out the current user.
  Future<void> signOut();

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email);
}
