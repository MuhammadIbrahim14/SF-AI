import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../providers/profile_image_provider.dart';
import 'avatar_widget.dart';

class ProfileImagePicker extends ConsumerStatefulWidget {
  const ProfileImagePicker({
    super.key,
    required this.role,
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 56,
  });

  final UserRole role;
  final String? imageUrl;
  final String fallbackText;
  final double radius;

  @override
  ConsumerState<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends ConsumerState<ProfileImagePicker> {
  bool _isHovering = false;

  Future<void> _handleUpload() async {
    final state = ref.read(profileImageUploadProvider);
    if (state.isLoading) return;

    final url = await ref
        .read(profileImageUploadProvider.notifier)
        .pickAndUpload(widget.role);
    if (!mounted) return;

    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image updated.'),
          backgroundColor: AppColors.successDark,
        ),
      );
      return;
    }

    final error = ref.read(profileImageUploadProvider).errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileImageUploadProvider);
    final theme = Theme.of(context);
    // We use a responsive layout based on screen width.
    final isWide = MediaQuery.of(context).size.width > 600;

    final avatarNode = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: state.isLoading ? null : _handleUpload,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                  width: 2,
                ),
              ),
              child: AvatarWidget(
                imageUrl: widget.imageUrl,
                radius: widget.radius,
                fallbackText: widget.fallbackText,
              ),
            ),
            if (_isHovering || state.isLoading)
              Container(
                width: widget.radius * 2,
                height: widget.radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
                child: Center(
                  child: state.isLoading
                      ? const SizedBox.square(
                          dimension: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.camera_enhance_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
          ],
        ),
      ),
    );

    final detailsNode = Column(
      crossAxisAlignment: isWide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const Text(
          'PROFILE AVATAR',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload a high-resolution image to verify your identity across the SkillForge network.',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: isWide
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'JPG, PNG or WEBP. Max size: 5MB.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: state.isLoading ? null : _handleUpload,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                widget.imageUrl == null ? 'UPLOAD IDENTITY' : 'UPDATE IDENTITY',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatarNode,
                const SizedBox(width: 48),
                Expanded(child: detailsNode),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [avatarNode, const SizedBox(height: 32), detailsNode],
            ),
    );
  }
}
