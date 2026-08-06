import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/cloudinary_service.dart';
import '../models/user_role.dart';
import 'profile_provider.dart';

enum ProfileImageUploadStatus { idle, loading, success, error }

class ProfileImageUploadState {
  const ProfileImageUploadState({
    this.status = ProfileImageUploadStatus.idle,
    this.imageUrl,
    this.errorMessage,
  });

  final ProfileImageUploadStatus status;
  final String? imageUrl;
  final String? errorMessage;

  bool get isLoading => status == ProfileImageUploadStatus.loading;
}

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  final service = CloudinaryService();
  ref.onDispose(service.dispose);
  return service;
});

final profileImageUploadProvider =
    NotifierProvider<ProfileImageUploadNotifier, ProfileImageUploadState>(
      ProfileImageUploadNotifier.new,
    );

class ProfileImageUploadNotifier extends Notifier<ProfileImageUploadState> {
  @override
  ProfileImageUploadState build() => const ProfileImageUploadState();

  Future<String?> pickAndUpload(UserRole role) async {
    if (state.isLoading) return null;

    try {
      final service = ref.read(cloudinaryServiceProvider);
      final image = await service.pickImageFromGallery();
      if (image == null) {
        state = const ProfileImageUploadState();
        return null;
      }

      state = const ProfileImageUploadState(
        status: ProfileImageUploadStatus.loading,
      );
      final secureUrl = await service.uploadProfileImage(image);
      final saved = await ref
          .read(profileActionProvider.notifier)
          .saveProfile(
            role: role,
            userData: {'profileImage': secureUrl},
            roleData: role == UserRole.company
                ? {'logo': secureUrl, 'logoUrl': secureUrl}
                : const {},
          );
      if (!saved) {
        final message =
            ref.read(profileActionProvider.notifier).errorMessage ??
            'The image uploaded, but the profile could not be updated.';
        throw CloudinaryException(message);
      }

      state = ProfileImageUploadState(
        status: ProfileImageUploadStatus.success,
        imageUrl: secureUrl,
      );
      return secureUrl;
    } on CloudinaryException catch (error) {
      state = ProfileImageUploadState(
        status: ProfileImageUploadStatus.error,
        errorMessage: error.message,
      );
      return null;
    } catch (error) {
      state = ProfileImageUploadState(
        status: ProfileImageUploadStatus.error,
        errorMessage: 'Unable to update profile image: $error',
      );
      return null;
    }
  }

  void reset() {
    state = const ProfileImageUploadState();
  }
}
