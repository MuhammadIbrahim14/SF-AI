import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/role_theme.dart';

class ProfileCompletionCard extends StatefulWidget {
  const ProfileCompletionCard({
    super.key,
    required this.completionPercentage,
    required this.onCompleteProfileTap,
    required this.roleTheme,
    this.isProfileImageMissing = false,
    this.missingFields = const [],
  });

  final int completionPercentage;
  final VoidCallback onCompleteProfileTap;
  final RoleThemeColors roleTheme;
  final bool isProfileImageMissing;
  final List<String> missingFields;

  @override
  State<ProfileCompletionCard> createState() => _ProfileCompletionCardState();
}

class _ProfileCompletionCardState extends State<ProfileCompletionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.completionPercentage >= 100) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            color: widget.roleTheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Identity Readiness',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.isProfileImageMissing
                            ? 'You are ${widget.completionPercentage}% ready. Upload a profile image to strengthen your professional identity.'
                            : _suggestionText(),
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(
                          begin: 0,
                          end: widget.completionPercentage / 100,
                        ),
                        builder: (context, value, child) {
                          return Stack(
                            children: [
                              // Background track
                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: widget.roleTheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                              ),
                              // Animated filled track
                              FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: widget.roleTheme.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                  final button = FilledButton.tonalIcon(
                    onPressed: widget.onCompleteProfileTap,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: const Text('Complete Now'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXl,
                        vertical: AppTheme.spacingLg,
                      ),
                      textStyle: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content,
                        const SizedBox(height: AppTheme.spacingLg),
                        button,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: content),
                      const SizedBox(width: AppTheme.spacingXl),
                      button,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _suggestionText() {
    if (widget.missingFields.isEmpty) {
      return 'You are ${widget.completionPercentage}% complete. Add more details to unlock all features.';
    }
    final suggestions = widget.missingFields.take(3).join(', ');
    return 'You are ${widget.completionPercentage}% complete. Add $suggestions to finish your profile.';
  }
}
