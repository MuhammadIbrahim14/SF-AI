import 'package:flutter/material.dart';

class ThemeOrbButton extends StatefulWidget {
  const ThemeOrbButton({
    super.key,
    required this.isDark,
    required this.isManaged,
    required this.onToggle,
  });

  final bool isDark;
  final bool isManaged;
  final VoidCallback? onToggle;

  @override
  State<ThemeOrbButton> createState() => _ThemeOrbButtonState();
}

class _ThemeOrbButtonState extends State<ThemeOrbButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coreColor = widget.isManaged
        ? colorScheme.outlineVariant
        : colorScheme.primary;

    return Tooltip(
      message: widget.isManaged
          ? 'Theme managed by administrator'
          : 'Shift Reality',
      child: GestureDetector(
        onTap: widget.onToggle,
        onTapDown: widget.onToggle == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onToggle == null
            ? null
            : () => setState(() => _pressed = false),
        onTapUp: widget.onToggle == null
            ? null
            : (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          scale: _pressed ? 0.88 : 1.0,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final baseGlow = 0.4 + (_pulseController.value * 0.3);
              final glow = _pressed ? 1.0 : baseGlow;
              final spread = _pressed ? 8.0 : 2.0;
              final largeSpread = _pressed ? 12.0 : 5.0;
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isDark
                      ? const Color(0xFF060A18)
                      : const Color(0xFFF5F7FC),
                  boxShadow: [
                    BoxShadow(
                      color: coreColor.withValues(alpha: glow),
                      blurRadius: 15,
                      spreadRadius: spread,
                    ),
                    BoxShadow(
                      color: coreColor.withValues(alpha: glow * 0.5),
                      blurRadius: 30,
                      spreadRadius: largeSpread,
                    ),
                  ],
                  border: Border.all(
                    color: coreColor.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: coreColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: widget.isManaged
                        ? Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: Colors.black.withValues(alpha: 0.5),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
