import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_ai/app/router/app_router.dart';
import 'package:skillforge_ai/features/student/sie/sie_go_router_sync.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_providers.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';

/// App-level Student SIE binder — activates policies on Student routes only.
///
/// Mount once under [MaterialApp.router] so assessments without role shells
/// still receive IDS route policies. Non-student routes are untouched.
///
/// Production path avoids Stack + availability watches (debug chip only).
class StudentSieRouteListener extends ConsumerStatefulWidget {
  /// Creates listener.
  const StudentSieRouteListener({required this.child, super.key});

  /// App subtree.
  final Widget child;

  @override
  ConsumerState<StudentSieRouteListener> createState() =>
      _StudentSieRouteListenerState();
}

class _StudentSieRouteListenerState
    extends ConsumerState<StudentSieRouteListener> with SieGoRouterSync {
  String? _boundRouteId;
  String? _lastLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    attachSieRouteSync(ref.read(routerProvider), _syncRoute);
  }

  @override
  void dispose() {
    detachSieRouteSync();
    super.dispose();
  }

  void _syncRoute() {
    if (!mounted) return;
    final ctx = trySieRouteContext();
    if (ctx == null) return;
    final location = ctx.location;
    // Skip mapper work when the location string is unchanged.
    if (_lastLocation == location) return;
    _lastLocation = location;

    if (!StudentSieRouteMapper.isStudentLocation(location)) {
      _boundRouteId = null;
      return;
    }
    final routeId = StudentSieRouteMapper.resolve(
      location: location,
      routeName: ctx.routeName,
    );
    if (_boundRouteId == routeId) return;
    _boundRouteId = routeId;
    final controller = ref.read(studentSieHostControllerProvider);
    // ignore: discarded_futures
    controller.activateRoute(routeId).then((_) {
      if (!mounted) return;
      ref.read(studentSieRouteEpochProvider.notifier).bump();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = trySieRouteContext();
    if (ctx == null) return widget.child;
    final location = ctx.location;
    final onStudent = StudentSieRouteMapper.isStudentLocation(location);

    if (onStudent) {
      // Ensure one-time bootstrap; FutureProvider caches after first resolve.
      ref.watch(studentSieBootstrapProvider);
    }

    // Release / profile: zero overlay overhead.
    if (!kDebugMode || !onStudent) {
      return widget.child;
    }

    final availability = ref.watch(studentSieAvailabilityProvider);
    if (!availability.available) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 8,
          bottom: 8,
          child: IgnorePointer(
            child: _StudentSieDebugChip(
              sieEnabled: availability.sieEnabled,
              routeId: availability.activeRouteId,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentSieDebugChip extends StatelessWidget {
  const _StudentSieDebugChip({
    required this.sieEnabled,
    required this.routeId,
  });

  final bool sieEnabled;
  final String? routeId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'SIE ${sieEnabled ? 'ON' : 'OFF'} · ${routeId ?? '—'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
