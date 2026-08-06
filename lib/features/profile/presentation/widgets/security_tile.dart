import 'package:flutter/material.dart';

class SecurityTile extends StatefulWidget {
  const SecurityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.accentColor,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? accentColor;
  final bool isDestructive;

  @override
  State<SecurityTile> createState() => _SecurityTileState();
}

class _SecurityTileState extends State<SecurityTile> {
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

    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: widget.title,
      child: MouseRegion(
        onEnter: widget.onTap != null
            ? (_) => setState(() => _isHovered = true)
            : null,
        onExit: widget.onTap != null
            ? (_) => setState(() => _isHovered = false)
            : null,
        child: AnimatedScale(
          scale: _isHovered ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(widget.icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: widget.isDestructive && _isHovered
                                    ? colorScheme.error
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
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
                      const SizedBox(width: 12),
                      widget.trailing ??
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
                              Icons.chevron_right_rounded,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
