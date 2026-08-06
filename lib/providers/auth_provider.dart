import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/mailer/email_templates.dart';
import '../core/mailer/emailjs_provider.dart';
import '../core/services/firestore_permission_logger.dart';
import '../models/user_model.dart';
import 'repository_providers.dart';
import 'firebase_providers.dart';

/// SkillForge AI — Authentication Providers

/// Streams the current Firebase Auth state (signed-in user or null).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Notifier that handles sign-up, sign-in, and sign-out actions.
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No-op — initial state is idle.
  }

  /// Signs up a new user and creates the corresponding Firestore document.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required bool privacyAccepted,
    required bool termsAccepted,
    String accountType = UserAccountType.professional,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (!privacyAccepted || !termsAccepted) {
        throw const AuthException(
          'Please accept the Privacy Policy and Terms of Service.',
        );
      }

      final settings = await ref
          .read(firestoreProvider)
          .collection(AppConstants.settingsCollection)
          .doc('platform')
          .get();
      final settingsData = settings.data() ?? const <String, dynamic>{};
      final registrationEnabled =
          (settingsData['registrationEnabled'] ??
              settingsData['allowRegistrations']) !=
          false;
      if (!registrationEnabled) {
        throw const AuthException(
          'New registrations are temporarily disabled.',
        );
      }

      final authRepo = ref.read(authRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);

      // 1. Create Firebase Auth account
      final credential = await authRepo.signUpWithEmail(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final acceptedAt = DateTime.now();
      final normalizedAccountType = UserAccountType.normalize(accountType);

      // 2. Create Firestore user document
      final user = UserModel(
        uid: uid,
        fullName: fullName.trim(),
        email: email.trim(),
        roles: [],
        primaryRole: null,
        accountType: normalizedAccountType,
        status: AppConstants.statusActive,
        createdAt: DateTime.now(),
        profileCompleted: 0,
        onboardingCompleted: false,
        privacyAccepted: true,
        privacyAcceptedAt: acceptedAt,
        termsAccepted: true,
        termsAcceptedAt: acceptedAt,
        lastLogin: DateTime.now(),
      );

      try {
        await userRepo.createUser(user);
        await _sendAccountCreatedEmail(user);
      } catch (_) {
        await credential.user?.delete();
        rethrow;
      }
    });

    return !state.hasError;
  }

  /// Signs in an existing user with email and password.
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password);

      final uid = credential.user?.uid;
      if (uid != null) {
        try {
          await ref
              .read(userRepositoryProvider)
              .updateUser(
                uid: uid,
                data: {'lastLogin': FieldValue.serverTimestamp()},
              );
        } on FirebaseException catch (e) {
          FirestorePermissionLogger.logIfPermissionDenied(
            e,
            feature: 'Auth',
            repository: 'UserRepositoryImpl',
            operation: 'signIn.lastLogin',
            path: 'users/$uid',
            action: 'update',
            uid: uid,
          );
          if (e.code != 'permission-denied') rethrow;
        } on FirestoreException catch (e) {
          if (e.code != 'permission-denied') rethrow;
        }
        await _sendLoginEmail(
          uid: uid,
          email: credential.user?.email ?? email,
          name: credential.user?.displayName ?? '',
        );
      }
    });

    return !state.hasError;
  }

  Future<bool> signInWithGoogle({
    String accountType = UserAccountType.professional,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle();
      await _syncSocialUserProfile(
        credential: credential,
        providerId: 'google.com',
        accountType: accountType,
      );
    });
    return !state.hasError;
  }

  Future<bool> signInWithGitHub({
    String accountType = UserAccountType.professional,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref
          .read(authRepositoryProvider)
          .signInWithGitHub();
      await _syncSocialUserProfile(
        credential: credential,
        providerId: 'github.com',
        accountType: accountType,
      );
    });
    return !state.hasError;
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  /// Sends a password reset email for [email].
  Future<bool> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
    });
    return !state.hasError;
  }

  /// Extracts a user-friendly error message from the current state.
  String? get errorMessage {
    if (!state.hasError) return null;
    final error = state.error;
    if (error is AppException) return error.message;
    return 'An unexpected error occurred.';
  }

  Future<void> _syncSocialUserProfile({
    required UserCredential credential,
    required String providerId,
    required String accountType,
  }) async {
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthException('Social sign-in did not return a user.');
    }

    final userRepo = ref.read(userRepositoryProvider);
    final normalizedAccountType = UserAccountType.normalize(accountType);
    final existing = await userRepo.getUser(firebaseUser.uid);
    if (existing == null) {
      await _assertRegistrationEnabled();
      final now = DateTime.now();
      final profile = UserModel(
        uid: firebaseUser.uid,
        fullName: _displayNameFor(firebaseUser),
        email: firebaseUser.email ?? '',
        roles: const [],
        primaryRole: null,
        accountType: normalizedAccountType,
        status: AppConstants.statusActive,
        createdAt: now,
        photoUrl: firebaseUser.photoURL,
        profileCompleted: 0,
        onboardingCompleted: false,
        privacyAccepted: false,
        termsAccepted: false,
        lastLogin: now,
      );
      await userRepo.createUser(profile);
      await userRepo.updateUser(
        uid: firebaseUser.uid,
        data: {
          'authProvider': providerId,
          'providerIds': FieldValue.arrayUnion([providerId]),
          'displayName': firebaseUser.displayName,
          'emailVerified': firebaseUser.emailVerified,
          'lastLogin': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
      );
      await _sendAccountCreatedEmail(profile);
      return;
    }

    final updates = <String, dynamic>{
      'lastLogin': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'authProvider': providerId,
      'providerIds': FieldValue.arrayUnion([providerId]),
      'emailVerified': firebaseUser.emailVerified,
    };
    if (existing.fullName.trim().isEmpty &&
        (firebaseUser.displayName ?? '').trim().isNotEmpty) {
      updates['fullName'] = firebaseUser.displayName!.trim();
    }
    if ((existing.photoUrl ?? '').trim().isEmpty &&
        (firebaseUser.photoURL ?? '').trim().isNotEmpty) {
      updates['photoUrl'] = firebaseUser.photoURL;
      updates['profileImage'] = firebaseUser.photoURL;
    }
    if (existing.email.trim().isEmpty &&
        (firebaseUser.email ?? '').trim().isNotEmpty) {
      updates['email'] = firebaseUser.email!.trim();
    }

    try {
      await userRepo.updateUser(uid: firebaseUser.uid, data: updates);
    } on FirebaseException catch (e) {
      FirestorePermissionLogger.logIfPermissionDenied(
        e,
        feature: 'Auth',
        repository: 'UserRepositoryImpl',
        operation: 'socialSignIn.syncProfile',
        path: 'users/${firebaseUser.uid}',
        action: 'update',
        uid: firebaseUser.uid,
      );
      if (e.code != 'permission-denied') rethrow;
    } on FirestoreException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    await _sendLoginEmail(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? existing.email,
      name: firebaseUser.displayName ?? existing.fullName,
    );
  }

  Future<void> _sendAccountCreatedEmail(UserModel user) async {
    try {
      await ref
          .read(emailJsMailerServiceProvider)
          .send(
            SkillForgeEmailTemplates.accountCreated(
              uid: user.uid,
              toEmail: user.email,
              toName: user.fullName,
              role: user.primaryRole ?? user.accountType,
              actionUrl: '',
            ),
            triggeredBy: user.uid,
          );
    } catch (_) {
      // Email is non-blocking.
    }
  }

  Future<void> _sendLoginEmail({
    required String uid,
    required String email,
    required String name,
  }) async {
    try {
      final config = await ref.read(emailJsMailerServiceProvider).loadConfig();
      if (!config.sendLoginEmails) return;
      final now = DateTime.now();
      final dateKey =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      await ref
          .read(emailJsMailerServiceProvider)
          .send(
            SkillForgeEmailTemplates.login(
              uid: uid,
              toEmail: email,
              toName: name,
              dateKey: dateKey,
              actionUrl: '',
            ),
            triggeredBy: uid,
            config: config,
          );
    } catch (_) {
      // Email is non-blocking.
    }
  }

  Future<void> _assertRegistrationEnabled() async {
    final settings = await ref
        .read(firestoreProvider)
        .collection(AppConstants.settingsCollection)
        .doc('platform')
        .get();
    final settingsData = settings.data() ?? const <String, dynamic>{};
    final registrationEnabled =
        (settingsData['registrationEnabled'] ??
            settingsData['allowRegistrations']) !=
        false;
    if (!registrationEnabled) {
      throw const AuthException('New registrations are temporarily disabled.');
    }
  }

  String _displayNameFor(User user) {
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return 'SkillForge User';
  }
}
