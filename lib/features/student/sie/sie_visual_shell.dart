import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_ai/app/router/app_router.dart';
import 'package:skillforge_ai/features/student/sie/sie_app_route_resolver.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_host_controller.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_providers.dart';
import 'package:skillforge_ai/providers/user_provider.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Live SIE visual layer — virtual cursor overlay + collapsible debug HUD.
class SieVisualShell extends ConsumerStatefulWidget {
  const SieVisualShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SieVisualShell> createState() => _SieVisualShellState();
}

class _SieVisualShellState extends ConsumerState<SieVisualShell> {
  /// Overlay-only updates — never call setState for cursor frames (avoids
  /// rebuilding the entire navigator tree at landmark rate).
  final ValueNotifier<SieCursorSnapshot?> _cursor = ValueNotifier(null);
  StreamSubscription<SieCursorSnapshot>? _cursorSub;
  bool _visualWired = false;
  bool _retrying = false;
  bool _hudCollapsed = true;
  String? _lastActivatedRoute;

  @override
  void dispose() {
    unawaited(_cursorSub?.cancel());
    _cursor.dispose();
    super.dispose();
  }

  bool _needsCameraAction(String? failure, bool available) {
    if (!available) return true;
    if (failure == null) return false;
    final lower = failure.toLowerCase();
    return lower.contains('permission') ||
        lower.contains('camera') ||
        lower.contains('siehandlandmarker') ||
        lower.contains('vision') ||
        lower.contains('mediapipe');
  }

  Future<void> _enableCamera() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _hudCollapsed = false;
    });
    try {
      final host = ref.read(studentSieHostControllerProvider);
      final user = ref.read(currentUserProvider).value;
      final ok = await host.retryCameraPipeline(
        platform: ref.read(studentSiePlatformProvider),
        userKey: user?.uid ?? 'anonymous-student',
      );
      if (ok && mounted) {
        // Force re-wire cursor + viewport after live pipeline starts.
        _visualWired = false;
        await _cursorSub?.cancel();
        _cursorSub = null;
        ref.invalidate(studentSieBootstrapProvider);
        final size = MediaQuery.sizeOf(context);
        await _wireVisualRuntime(size, force: true);
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _bindCursorStream(SrdcrPort root) {
    if (_cursorSub != null) return;
    _cursorSub = root.cursor.snapshots.listen((snap) {
      if (!mounted) return;
      _cursor.value = snap;
    });
  }

  Future<void> _wireVisualRuntime(Size size, {bool force = false}) async {
    if (size.isEmpty) return;
    if (_visualWired && !force) return;
    final host = ref.read(studentSieHostControllerProvider);
    if (!host.isAvailable) return;
    _visualWired = true;
    await host.ensureVisualRuntime(
      viewWidth: size.width,
      viewHeight: size.height,
    );
    _bindCursorStream(host.root);
    _syncActiveRoute(host);
  }

  void _syncActiveRoute(StudentSieHostController host) {
    try {
      final router = ref.read(routerProvider);
      if (router.routerDelegate.currentConfiguration.isEmpty) return;
      final routeId = SieAppRouteResolver.resolveFromRouter(router);
      if (routeId == null || routeId == _lastActivatedRoute) return;
      _lastActivatedRoute = routeId;
      unawaited(host.activateRoute(routeId).then((_) {
        if (!mounted) return;
        ref.read(studentSieRouteEpochProvider.notifier).bump();
      }));
    } catch (_) {
      // Router not ready yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(studentSieBootstrapProvider);
    ref.watch(studentSieGlobalControlSyncProvider);
    final host = ref.watch(studentSieHostControllerProvider);
    final availability = ref.watch(studentSieAvailabilityProvider);
    final startPipeline = ref.watch(studentSieStartPipelineProvider);
    final showCamera = _needsCameraAction(
      availability.lastFailure,
      availability.available,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (host.isAvailable && size.width > 0) {
          if (startPipeline) {
            // ignore: discarded_futures
            _wireVisualRuntime(size);
          } else {
            _syncActiveRoute(host);
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            // Cursor paints in an isolated layer so landmark frames never
            // rebuild the app tree under `widget.child`.
            IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<SieCursorSnapshot?>(
                  valueListenable: _cursor,
                  builder: (context, snap, _) {
                    if (snap == null || !_cursorVisible(snap)) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: _SieVirtualCursorPainter(snapshot: snap),
                      size: size,
                    );
                  },
                ),
              ),
            ),
            if (kDebugMode)
              Positioned(
                left: 8,
                top: 8,
                child: _hudCollapsed
                    ? _SieLiveHud(
                        collapsed: true,
                        onToggle: () =>
                            setState(() => _hudCollapsed = !_hudCollapsed),
                        availability: availability,
                        pipeline: startPipeline,
                        cursor: null,
                        showCameraButton: showCamera,
                        retrying: _retrying,
                        onEnableCamera: _enableCamera,
                      )
                    : ValueListenableBuilder<SieCursorSnapshot?>(
                        valueListenable: _cursor,
                        builder: (context, snap, _) {
                          return _SieLiveHud(
                            collapsed: false,
                            onToggle: () =>
                                setState(() => _hudCollapsed = !_hudCollapsed),
                            availability: availability,
                            pipeline: startPipeline,
                            cursor: snap,
                            showCameraButton: showCamera,
                            retrying: _retrying,
                            onEnableCamera: _enableCamera,
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }

  bool _cursorVisible(SieCursorSnapshot snap) {
    return snap.state != SieCursorState.hidden &&
        snap.visibility != SieCursorVisibilityMode.hidden &&
        snap.opacity > 0.05;
  }
}

class _SieVirtualCursorPainter extends CustomPainter {
  const _SieVirtualCursorPainter({required this.snapshot});

  final SieCursorSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final x = snapshot.position.x;
    final y = snapshot.position.y;
    if (x.isNaN || y.isNaN) return;
    final c = Offset(x.clamp(0, size.width), y.clamp(0, size.height));
    canvas.drawCircle(c, 18, Paint()..color = const Color(0x3322D3EE));
    canvas.drawCircle(
      c,
      18,
      Paint()
        ..color = const Color(0xFF22D3EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 6, Paint()..color = const Color(0xCC22D3EE));
    canvas.drawCircle(c, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SieVirtualCursorPainter oldDelegate) {
    return oldDelegate.snapshot.frameSequence != snapshot.frameSequence ||
        oldDelegate.snapshot.position.x != snapshot.position.x ||
        oldDelegate.snapshot.position.y != snapshot.position.y;
  }
}

class _SieLiveHud extends StatelessWidget {
  const _SieLiveHud({
    required this.collapsed,
    required this.onToggle,
    required this.availability,
    required this.pipeline,
    required this.cursor,
    required this.showCameraButton,
    required this.retrying,
    required this.onEnableCamera,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final ({
    bool hostEnabled,
    bool available,
    bool sieEnabled,
    String? activeRouteId,
    String? lastFailure,
  }) availability;
  final bool pipeline;
  final SieCursorSnapshot? cursor;
  final bool showCameraButton;
  final bool retrying;
  final VoidCallback onEnableCamera;

  @override
  Widget build(BuildContext context) {
    final tracking = cursor?.state.name ?? '—';
    final healthy = availability.available &&
        availability.sieEnabled &&
        availability.lastFailure == null;

    if (collapsed) {
      return Material(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gesture,
                  size: 16,
                  color: healthy ? const Color(0xFF22D3EE) : Colors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  'SIE ${availability.sieEnabled ? 'ON' : 'OFF'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.white70),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SkillForge SIE',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // No Tooltip/IconButton — SieVisualShell sits above Navigator
                    // Overlay (MaterialApp.builder), so RawTooltip would crash.
                    InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.chevron_left,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                Text('SIE: ${availability.sieEnabled ? 'ON' : 'OFF'}'),
                Text('Route: ${availability.activeRouteId ?? '—'}'),
                Text('Pipeline: ${pipeline ? 'live' : 'off'}'),
                Text('Cursor: $tracking'),
                if (cursor != null)
                  Text(
                    'Pos: ${cursor!.position.x.toStringAsFixed(0)}, '
                    '${cursor!.position.y.toStringAsFixed(0)}',
                  ),
                if (availability.lastFailure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Note: ${_shortError(availability.lastFailure!)}',
                      style: const TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ),
                if (showCameraButton) ...[
                  const SizedBox(height: 8),
                  if (_isPermissionDenied(availability.lastFailure)) ...[
                    const Text(
                      'Chrome blocked the camera for this site.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1. Click the lock / tune icon left of the URL\n'
                      '2. Set Camera → Allow\n'
                      '3. Reload, then tap Enable camera',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: retrying ? null : onEnableCamera,
                    icon: Icon(
                      retrying ? Icons.hourglass_top : Icons.videocam,
                      size: 16,
                    ),
                    label: Text(
                      retrying ? 'Starting…' : 'Enable camera',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22D3EE),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (!_isPermissionDenied(availability.lastFailure)) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Allow camera when Chrome asks',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ],
                const SizedBox(height: 6),
                const Text(
                  'MOVE: open palm, index tip up\n'
                  'CLICK: pinch thumb+index (~0.3s), then open to release\n'
                  'SCROLL: open hand, swipe index DOWN or UP once;\n'
                  '         pause briefly, then swipe again (return ignored)\n'
                  'Keep hand steady in the camera frame',
                  style: TextStyle(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortError(String raw) {
    if (raw.length <= 120) return raw;
    return '${raw.substring(0, 117)}…';
  }

  static bool _isPermissionDenied(String? raw) {
    if (raw == null) return false;
    final lower = raw.toLowerCase();
    return lower.contains('notallowed') ||
        lower.contains('permission denied') ||
        lower.contains('permission');
  }
}
