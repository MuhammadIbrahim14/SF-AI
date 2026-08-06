import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// SkillForge AI — Primary Gradient Button
/// A full-width button with gradient background, loading state, and premium hover/press effects.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.width,
    this.height = 56,
    this.gradient,
    this.backgroundColor,
    this.textColor,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final double? width;
  final double height;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled =
        widget.isEnabled && !widget.isLoading && widget.onPressed != null;

    final effectiveGradient = widget.backgroundColor != null
        ? null
        : (widget.gradient ??
              LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ));

    // Calculate scale and elevation based on state
    final scale = _isPressed ? 0.98 : (_isHovered ? 1.02 : 1.0);
    final elevationBlur = _isHovered ? 24.0 : 12.0;
    final elevationOffset = _isHovered ? 8.0 : 4.0;
    final shadowOpacity = _isHovered ? 0.4 : 0.25;

    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: enabled ? scale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.width ?? double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: enabled ? effectiveGradient : null,
              color: enabled
                  ? widget.backgroundColor
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: _isHovered ? 0.3 : 0.1)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: (widget.backgroundColor ?? colorScheme.primary)
                            .withValues(alpha: shadowOpacity * 1.5),
                        blurRadius: elevationBlur * 1.5,
                        spreadRadius: _isHovered ? 2.0 : 0.0,
                        offset: Offset(0, elevationOffset),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: widget.textColor ?? Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: enabled
                                      ? (widget.textColor ?? Colors.white)
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.38,
                                        ),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
