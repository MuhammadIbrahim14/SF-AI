import 'package:flutter/material.dart';

class ProfileNavigationCard extends StatefulWidget {
  const ProfileNavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.index = 0,
    this.accentColor,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int index;
  final Color? accentColor;
  final Widget? trailing;
  final bool isDestructive;

  @override
  State<ProfileNavigationCard> createState() => _ProfileNavigationCardState();
}

class _ProfileNavigationCardState extends State<ProfileNavigationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final baseColor = widget.isDestructive
        ? colorScheme.error
        : (widget.accentColor ?? colorScheme.primary);

    final color = widget.onTap == null
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : baseColor;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (widget.index * 60)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: MouseRegion(
        onEnter: widget.onTap != null
            ? (_) => setState(() => _isHovered = true)
            : null,
        onExit: widget.onTap != null
            ? (_) => setState(() => _isHovered = false)
            : null,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: widget.isDestructive && _isHovered
                  ? colorScheme.errorContainer.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: widget.onTap,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                splashColor: color.withValues(alpha: 0.1),
                highlightColor: color.withValues(alpha: 0.05),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isHovered
                          ? color.withValues(alpha: 0.6)
                          : colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: _isHovered ? 1.5 : 1.0,
                    ),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.15),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(widget.icon, color: color, size: 24),
                          ),
                          if (widget.trailing != null)
                            widget.trailing!
                          else if (widget.onTap != null)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(_isHovered ? 8 : 4),
                              decoration: BoxDecoration(
                                color: _isHovered
                                    ? color.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: _isHovered
                                    ? color
                                    : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: widget.isDestructive && _isHovered
                              ? colorScheme.error
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.isDestructive && _isHovered
                              ? colorScheme.error.withValues(alpha: 0.8)
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
