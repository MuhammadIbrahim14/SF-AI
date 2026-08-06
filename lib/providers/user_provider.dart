import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../models/user_role.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// SkillForge AI — User & Role Providers

/// Streams the current user's Firestore document in real-time.
/// Returns `null` if the user is not authenticated or the document doesn't exist.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  // Use asData so brief auth loading does not tear down the user stream
  // (Stream.empty → null flash → dashboard content vanishes).
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return ref.watch(userRepositoryProvider).userStream(uid);
});

/// Provides the current user's primary [UserRole] enum value.
/// Returns `null` if no role is set or user is not authenticated.
final roleProvider = Provider<UserRole?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.asData?.value?.primaryRoleEnum;
});

/// Notifier for updating the user's selected role.
final roleNotifierProvider = AsyncNotifierProvider<RoleNotifier, void>(
  RoleNotifier.new,
);

class RoleNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Saves the selected [role] to the current user's Firestore document.
  Future<bool> selectRole(UserRole role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firebaseUser = ref.read(authRepositoryProvider).currentUser;
      if (firebaseUser == null) throw Exception('User not authenticated');

      await ref
          .read(userRepositoryProvider)
          .updateUserRole(
            uid: firebaseUser.uid,
            roles: [role.name],
            primaryRole: role.name,
          );
    });

    return !state.hasError;
  }

  /// Freelancer Bridge mode switch: changes [primaryRole] only.
  /// Never removes existing roles (student stays when switching to freelancer).
  Future<bool> setPrimaryRoleOnly(UserRole role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firebaseUser = ref.read(authRepositoryProvider).currentUser;
      if (firebaseUser == null) throw Exception('User not authenticated');

      final current = await ref
          .read(userRepositoryProvider)
          .getUser(firebaseUser.uid);
      if (current == null) throw Exception('User profile not found');

      final unlocked =
          current.freelancerUnlocked ||
          current.roles.any(
            (value) => value.trim().toLowerCase() == 'freelancer',
          );
      if (role == UserRole.freelancer && !unlocked) {
        throw Exception(
          'Freelancer mode unlocks after you Activate Showcase from Freelancer Bridge.',
        );
      }
      if (role != UserRole.student && role != UserRole.freelancer) {
        throw Exception(
          'Only Student and Freelancer modes are supported here.',
        );
      }

      final roles = List<String>.from(current.roles);
      if (role == UserRole.freelancer &&
          !roles.map((r) => r.trim().toLowerCase()).contains('freelancer')) {
        roles.add(UserRole.freelancer.name);
      }
      if (!roles.map((r) => r.trim().toLowerCase()).contains('student') &&
          (current.primaryRoleEnum == UserRole.student ||
              current.freelancerUnlocked)) {
        roles.add(UserRole.student.name);
      }

      await ref
          .read(userRepositoryProvider)
          .updateUser(
            uid: firebaseUser.uid,
            data: {
              'primaryRole': role.name,
              'roles': roles,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
    });

    return !state.hasError;
  }
}
