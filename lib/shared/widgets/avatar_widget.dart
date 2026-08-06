import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackText;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.radius = 24.0,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      fallbackText,
      style: AppTypography.titleMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: fallback),
              ),
            ),
    );
  }
}
