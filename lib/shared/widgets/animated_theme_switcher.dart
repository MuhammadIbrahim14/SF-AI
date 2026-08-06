import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// SkillForge AI — Zero-Views Theme Transformation System
///
/// Staged "hologram eject" transition played whenever the effective theme
/// brightness flips:
///
///   1. RECEDE  — the whole screen pulls backward (scale down + dark backdrop)
///   2. IGNITE  — a neon blue/cyan frame lights up on all four sides
///   3. EXIT    — the recessed panel swings and slides off to the right
///   4. FLIP    — the palette swaps while the panel sits outside the frame
///   5. ENTER   — the newly themed panel flies back in from the left
///   6. SETTLE  — it scales back to full-bleed and the frame powers down
///
/// The outgoing half keeps painting the *previous* [ThemeData] by pinning an
/// explicit [Theme] above the app subtree, so the panel that slides out really
/// does wear the old palette. That works identically on every renderer — no GPU
/// readback, no `toImageSync`, nothing that can silently no-op on the web.
class AnimatedThemeSwitcher extends StatefulWidget {
  const AnimatedThemeSwitcher({
    super.key,
    required this.isDark,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 1100),
  });

  final bool isDark;
  final Widget child;

  /// Master switch fed by the app's own motion settings. The OS/browser
  /// "reduce motion" preference is deliberately not consulted here: the host
  /// already folds that decision into this flag, and honouring it twice used to
  /// silently cancel the sequence.
  final bool enabled;

  /// Total length of the staged sequence. Individual stages are expressed as
  /// fractions of this duration (see the `_k*` intervals below).
  final Duration duration;

  @override
  State<AnimatedThemeSwitcher> createState() => _AnimatedThemeSwitcherState();
}

// ---------------------------------------------------------------------------
// Stage choreography — every value is a fraction of [widget.duration].
// Tweak these to retime the spectacle without touching the render code.
// ---------------------------------------------------------------------------

/// Screen pulls backward.
const Interval _kRecede = Interval(0.0, 0.20, curve: Curves.easeOutCubic);

/// Neon frame ignites on all four sides.
const Interval _kIgnite = Interval(0.08, 0.34, curve: Curves.easeOutCubic);

/// Recessed panel swings out to the right.
const Interval _kExit = Interval(0.40, 0.62, curve: Curves.easeInCubic);

/// Moment the palette swaps. The panel is fully outside the frame's clip by
/// [_kExit]'s end, so the swap itself is never on screen.
const double _kFlip = 0.63;

/// New-themed panel flies in from the left.
const Interval _kEnter = Interval(0.64, 0.86, curve: Curves.easeOutCubic);

/// Panel scales back to full bleed, frame powers down.
const Interval _kSettle = Interval(0.84, 1.0, curve: Curves.easeOutCubic);

/// How far back the screen recedes at rest.
const double _kRecessedScale = 0.78;

/// Corner rounding applied while recessed.
const double _kRecessedRadius = 32.0;

/// Horizontal travel as a multiple of the viewport width. Anything past 1.0
/// puts the panel completely outside the frame's clip rect.
const double _kTravel = 1.15;

const Color _kForgeBlue = Color(0xFF5B7CFF);
const Color _kForgeCyan = Color(0xFF00D1FF);

class _AnimatedThemeSwitcherState extends State<AnimatedThemeSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    // Without `preserve`, a platform-level "reduce motion" flag (Windows
    // "animation effects" off, or a `prefers-reduced-motion: reduce` browser
    // match) makes every controller run at 5% of its duration. That compressed
    // the whole 1.1s sequence into ~55ms — three frames, invisible to the eye,
    // which is exactly the "it does nothing" symptom.
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onStatus);

  /// Palette the app was painted with on the previous frame.
  ThemeData? _ambientTheme;

  /// Palette pinned onto the outgoing panel until [_kFlip].
  ThemeData? _outgoingTheme;

  bool _isAnimating = false;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Clear the flags before resetting: the reset notification rebuilds the
    // panel and must already see the idle (pass-through) state.
    _outgoingTheme = null;
    if (mounted) {
      setState(() => _isAnimating = false);
    } else {
      _isAnimating = false;
    }
    _controller.reset();
  }

  @override
  void didUpdateWidget(AnimatedThemeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (!widget.enabled) {
      if (_isAnimating) {
        _controller.stop();
        _controller.reset();
        _isAnimating = false;
        _outgoingTheme = null;
      }
      assert(() {
        if (oldWidget.isDark != widget.isDark) {
          debugPrint(
            '[ThemeSwitcher] sequence skipped: motion is switched off in '
            'settings (settings/motion → animationsEnabled / reducedMotion).',
          );
        }
        return true;
      }());
      return;
    }

    if (oldWidget.isDark == widget.isDark) return;

    // A flip that lands mid-sequence restarts the choreography, but the panel
    // that is still on its way out must keep the palette it launched with.
    if (!_isAnimating || _controller.value >= _kFlip) {
      _outgoingTheme = _ambientTheme;
    }
    _isAnimating = true;
    _controller.forward(from: 0);

    assert(() {
      final platformReducedMotion = WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;
      debugPrint(
        '[ThemeSwitcher] flip -> ${widget.isDark ? 'dark' : 'light'} '
        '(${widget.duration.inMilliseconds}ms, '
        'outgoing palette ${_outgoingTheme == null ? 'unavailable' : 'pinned'}, '
        'platform reduced-motion: $platformReducedMotion)',
      );
      return true;
    }());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remembered so the next flip knows which palette the outgoing panel wore.
    final ambient = Theme.of(context);
    _ambientTheme = ambient;

    // The tree shape below is identical whether idle or animating, so the app
    // subtree (and the Navigator inside it) keeps its element identity — and
    // therefore all of its state — across the transition.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, content) {
            final active = _isAnimating;
            final t = active ? _controller.value : 0.0;

            final recede = active ? _kRecede.transform(t) : 0.0;
            final settle = active ? _kSettle.transform(t) : 0.0;
            final depth = recede * (1 - settle);
            final scale = ui.lerpDouble(
              ui.lerpDouble(1.0, _kRecessedScale, recede)!,
              1.0,
              settle,
            )!;
            final radius = _kRecessedRadius * depth;
            final glow = active ? _kIgnite.transform(t) * (1 - settle) : 0.0;

            final holdOutgoing = active && t < _kFlip && _outgoingTheme != null;

            return Stack(
              fit: StackFit.expand,
              children: [
                _Backdrop(intensity: depth),
                Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        clipBehavior: active ? Clip.antiAlias : Clip.none,
                        child: Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..translateByDouble(
                              _panelDx(t, width, active),
                              0,
                              0,
                              1,
                            )
                            ..rotateY(_panelRotation(t, active)),
                          alignment: Alignment.center,
                          child: IgnorePointer(
                            ignoring: active,
                            child: Theme(
                              data: holdOutgoing ? _outgoingTheme! : ambient,
                              child: content!,
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _NeonFramePainter(
                            glow: glow,
                            radius: radius,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          child: RepaintBoundary(child: widget.child),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Per-stage panel maths
// ---------------------------------------------------------------------------

/// Horizontal offset of the panel inside the frame. Before [_kFlip] the panel
/// is on its way out to the right; after it, the freshly themed panel is on its
/// way in from the left. The jump between the two happens while the panel sits
/// completely outside the clip, so it is never visible.
double _panelDx(double t, double width, bool active) {
  if (!active || width <= 0) return 0;
  if (t < _kFlip) {
    final ignite = _kIgnite.transform(t);
    final exit = _kExit.transform(t);
    // Small leftward anticipation before the panel launches to the right.
    return (-width * 0.03 * ignite * (1 - exit)) + (width * _kTravel * exit);
  }
  return -width * _kTravel * (1 - _kEnter.transform(t));
}

double _panelRotation(double t, bool active) {
  if (!active) return 0;
  if (t < _kFlip) return -0.55 * _kExit.transform(t);
  return 0.55 * (1 - _kEnter.transform(t));
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Deep-space plate revealed behind the recessed panel.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) return const SizedBox.shrink();
    final a = intensity.clamp(0.0, 1.0);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.1,
            colors: [
              Color.lerp(
                const Color(0xFF0A1330),
                const Color(0xFF15346F),
                a * 0.55,
              )!.withValues(alpha: a),
              const Color(0xFF03060F).withValues(alpha: a),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blue/cyan light frame that ignites along all four edges.
class _NeonFramePainter extends CustomPainter {
  const _NeonFramePainter({required this.glow, required this.radius});

  /// 0 → dark, 1 → fully lit. Doubles as the edge-fill progress.
  final double glow;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow <= 0.01 || size.isEmpty) return;

    final rect = Offset.zero & size;
    final r = radius.clamp(0.0, size.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // Outer bloom.
    canvas.drawRRect(
      rrect.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..color = _kForgeCyan.withValues(alpha: 0.28 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Gradient rail around the whole panel.
    canvas.drawRRect(
      rrect.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kForgeBlue.withValues(alpha: 0.9 * glow),
            _kForgeCyan.withValues(alpha: 1.0 * glow),
            _kForgeBlue.withValues(alpha: 0.9 * glow),
          ],
        ).createShader(rect),
    );

    // Inner rim highlight for a machined-edge feel.
    canvas.drawRRect(
      rrect.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12 * glow),
    );

    // Edge light bars growing outward from each side's midpoint. Horizontal
    // rails strike first, vertical rails chase them a beat later.
    final fillH = (glow / 0.75).clamp(0.0, 1.0);
    final fillV = ((glow - 0.25) / 0.75).clamp(0.0, 1.0);

    final bloom = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12
      ..color = _kForgeCyan.withValues(alpha: 0.6 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final core = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.95 * glow);

    void bar(Offset a, Offset b) {
      if ((b - a).distance < 0.5) return;
      canvas.drawLine(a, b, bloom);
      canvas.drawLine(a, b, core);
    }

    final hReach = ((size.width / 2) - r).clamp(0.0, size.width) * fillH;
    final vReach = ((size.height / 2) - r).clamp(0.0, size.height) * fillV;
    final cx = size.width / 2;
    final cy = size.height / 2;

    bar(Offset(cx - hReach, 1.5), Offset(cx + hReach, 1.5));
    bar(
      Offset(cx - hReach, size.height - 1.5),
      Offset(cx + hReach, size.height - 1.5),
    );
    bar(Offset(1.5, cy - vReach), Offset(1.5, cy + vReach));
    bar(
      Offset(size.width - 1.5, cy - vReach),
      Offset(size.width - 1.5, cy + vReach),
    );

    // Corner brackets snap in once the rails have nearly met.
    final bracket = ((glow - 0.6) / 0.4).clamp(0.0, 1.0);
    if (bracket > 0) {
      final len = 22 * bracket;
      final tick = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.85 * bracket * glow);
      final inset = r * 0.72 + 1.5;
      final corners = <List<Offset>>[
        [Offset(inset, 1.5), Offset(inset + len, 1.5)],
        [Offset(1.5, inset), Offset(1.5, inset + len)],
        [
          Offset(size.width - inset, 1.5),
          Offset(size.width - inset - len, 1.5),
        ],
        [
          Offset(size.width - 1.5, inset),
          Offset(size.width - 1.5, inset + len),
        ],
        [
          Offset(inset, size.height - 1.5),
          Offset(inset + len, size.height - 1.5),
        ],
        [
          Offset(1.5, size.height - inset),
          Offset(1.5, size.height - inset - len),
        ],
        [
          Offset(size.width - inset, size.height - 1.5),
          Offset(size.width - inset - len, size.height - 1.5),
        ],
        [
          Offset(size.width - 1.5, size.height - inset),
          Offset(size.width - 1.5, size.height - inset - len),
        ],
      ];
      for (final c in corners) {
        canvas.drawLine(c[0], c[1], tick);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeonFramePainter oldDelegate) {
    return glow != oldDelegate.glow || radius != oldDelegate.radius;
  }
}
