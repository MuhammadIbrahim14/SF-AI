import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../core/utils/profile_completion.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../repositories/user_repository.dart';
import 'company_provider.dart';
import 'freelancer_provider.dart';
import 'repository_providers.dart';
import 'student_provider.dart';
import 'teacher_provider.dart';
import 'user_provider.dart';

class ProfileData {
  const ProfileData({
    required this.user,
    required this.role,
    required this.details,
    required this.completion,
  });

  final UserModel user;
  final UserRole role;
  final Map<String, dynamic> details;
  final ProfileCompletionResult completion;
}

final profileDataProvider = Provider<AsyncValue<ProfileData?>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  if (userAsync.isLoading) return const AsyncLoading();
  if (userAsync.hasError) {
    return AsyncError(userAsync.error!, userAsync.stackTrace!);
  }

  final user = userAsync.asData?.value;
  final role = user?.primaryRoleEnum;
  if (user == null || role == null) return const AsyncData(null);

  return switch (role) {
    UserRole.student => _combineProfile(
      user,
      role,
      ref.watch(studentProvider),
      (value) => value.toJson(),
    ),
    UserRole.teacher => _combineProfile(
      user,
      role,
      ref.watch(teacherProvider),
      (value) => value.toJson(),
    ),
    UserRole.freelancer => _combineProfile(
      user,
      role,
      ref.watch(freelancerProvider),
      (value) => value.toJson(),
    ),
    UserRole.company => _combineProfile(
      user,
      role,
      ref.watch(companyProvider),
      (value) => value.toJson(),
    ),
    _ => AsyncData(
      ProfileData(
        user: user,
        role: role,
        details: const {},
        completion: ProfileCompletion.evaluate(
          userData: user.toJson(),
          role: role.name,
          roleData: const {},
        ),
      ),
    ),
  };
});

AsyncValue<ProfileData?> _combineProfile<T>(
  UserModel user,
  UserRole role,
  AsyncValue<T?> roleAsync,
  Map<String, dynamic> Function(T value) toJson,
) {
  return roleAsync.when(
    data: (value) {
      final details = value == null ? const <String, dynamic>{} : toJson(value);
      return AsyncData(
        ProfileData(
          user: user,
          role: role,
          details: details,
          completion: ProfileCompletion.evaluate(
            userData: user.toJson(),
            role: role.name,
            roleData: details,
          ),
        ),
      );
    },
    error: AsyncError.new,
    loading: AsyncLoading.new,
  );
}

final profileCompletionSyncProvider = Provider<void>((ref) {
  final profile = ref.watch(profileDataProvider).value;
  if (profile == null) return;

  final calculated = profile.completion.profileCompletionPercentage;
  if (profile.user.profileCompleted == calculated) return;

  final request = _ProfileCompletionSyncRequest(
    userId: profile.user.uid,
    completion: calculated,
  );
  if (_profileCompletionSyncs.contains(request)) return;

  _profileCompletionSyncs.add(request);
  unawaited(
    _syncProfileCompletion(
      ref.read(userRepositoryProvider),
      request,
    ).whenComplete(() => _profileCompletionSyncs.remove(request)),
  );
});

final Set<_ProfileCompletionSyncRequest> _profileCompletionSyncs = {};

Future<void> _syncProfileCompletion(
  UserRepository userRepository,
  _ProfileCompletionSyncRequest request,
) async {
  try {
    await userRepository.updateUser(
      uid: request.userId,
      data: {
        'profileCompleted': request.completion,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  } catch (_) {
    // The live calculation remains available to the UI. A later profile
    // refresh retries persistence without blocking the current screen.
  }
}

class _ProfileCompletionSyncRequest {
  const _ProfileCompletionSyncRequest({
    required this.userId,
    required this.completion,
  });

  final String userId;
  final int completion;

  @override
  bool operator ==(Object other) {
    return other is _ProfileCompletionSyncRequest &&
        other.userId == userId &&
        other.completion == completion;
  }

  @override
  int get hashCode => Object.hash(userId, completion);
}

final profileActionProvider =
    AsyncNotifierProvider<ProfileActionNotifier, void>(
      ProfileActionNotifier.new,
    );

class ProfileActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveProfile({
    required UserRole role,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> roleData,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _saveProfile(role: role, userData: userData, roleData: roleData);
    });
    return !state.hasError;
  }

  String? get errorMessage {
    final error = state.error;
    if (error is AppException) return error.message;
    return error?.toString();
  }

  Future<void> _saveProfile({
    required UserRole role,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> roleData,
  }) async {
    final firebaseUser = ref.read(authRepositoryProvider).currentUser;
    if (firebaseUser == null) {
      throw const AuthException('User is not authenticated.');
    }

    final userRepository = ref.read(userRepositoryProvider);
    final currentUser = await userRepository.getUser(firebaseUser.uid);
    final existingUserData = currentUser?.toJson() ?? <String, dynamic>{};
    final existingRoleData = await _getRoleData(role, firebaseUser.uid);
    final mergedUserData = {
      ...existingUserData,
      'email': firebaseUser.email ?? existingUserData['email'] ?? '',
      'primaryRole': role.name,
      ...userData,
    };
    final mergedRoleData = {...existingRoleData, ...roleData};
    final completion = ProfileCompletion.calculate(
      userData: mergedUserData,
      role: role.name,
      roleData: mergedRoleData,
    );

    await _updateRoleData(role, firebaseUser.uid, {
      ...roleData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await userRepository.updateUser(
      uid: firebaseUser.uid,
      data: {
        ...userData,
        'profileCompleted': completion,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<Map<String, dynamic>> _getRoleData(
    UserRole role,
    String userId,
  ) async {
    return switch (role) {
      UserRole.student =>
        (await ref.read(studentRepositoryProvider).getStudent(userId))
                ?.toJson() ??
            const {},
      UserRole.teacher =>
        (await ref.read(teacherRepositoryProvider).getTeacher(userId))
                ?.toJson() ??
            const {},
      UserRole.freelancer =>
        (await ref.read(freelancerRepositoryProvider).getFreelancer(userId))
                ?.toJson() ??
            const {},
      UserRole.company =>
        (await ref.read(companyRepositoryProvider).getCompany(userId))
                ?.toJson() ??
            const {},
      _ => const {},
    };
  }

  Future<void> _updateRoleData(
    UserRole role,
    String userId,
    Map<String, dynamic> data,
  ) {
    return switch (role) {
      UserRole.student =>
        ref
            .read(studentRepositoryProvider)
            .updateStudent(userId: userId, data: data),
      UserRole.teacher =>
        ref
            .read(teacherRepositoryProvider)
            .updateTeacher(userId: userId, data: data),
      UserRole.freelancer =>
        ref
            .read(freelancerRepositoryProvider)
            .updateFreelancer(userId: userId, data: data),
      UserRole.company =>
        ref
            .read(companyRepositoryProvider)
            .updateCompany(userId: userId, data: data),
      _ => Future.value(),
    };
  }
}
