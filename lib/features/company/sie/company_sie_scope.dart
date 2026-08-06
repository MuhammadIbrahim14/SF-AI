import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_ai/app/router/app_router.dart';
import 'package:skillforge_ai/features/company/sie/company_sie_providers.dart';
import 'package:skillforge_ai/features/company/sie/company_sie_route_mapper.dart';
import 'package:skillforge_ai/features/student/sie/sie_go_router_sync.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_providers.dart';

/// App-level Company SIE binder — activates Company route policies only.
///
/// Reuses the Student Module SRDCR / host controller. Mount alongside
/// Freelancer / Teacher / Student listeners.
class CompanySieRouteListener extends ConsumerStatefulWidget {
  /// Creates listener.
  const CompanySieRouteListener({required this.child, super.key});

  /// App subtree.
  final Widget child;

  @override
  ConsumerState<CompanySieRouteListener> createState() =>
      _CompanySieRouteListenerState();
}

class _CompanySieRouteListenerState
    extends ConsumerState<CompanySieRouteListener> with SieGoRouterSync {
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
    if (_lastLocation == location) return;
    _lastLocation = location;

    if (!CompanySieRouteMapper.isCompanyLocation(location)) {
      _boundRouteId = null;
      return;
    }
    final routeId = CompanySieRouteMapper.resolve(
      location: location,
      routeName: ctx.routeName,
    );
    if (_boundRouteId == routeId) return;
    _boundRouteId = routeId;
    final controller = ref.read(studentSieHostControllerProvider);
    unawaited(controller.activateRoute(routeId).then((_) {
      if (!mounted) return;
      ref.read(studentSieRouteEpochProvider.notifier).bump();
      setState(() {});
    }));
  }

  @override
  Widget build(BuildContext context) {
    final ctx = trySieRouteContext();
    if (ctx == null) return widget.child;
    final location = ctx.location;
    final onCompany = CompanySieRouteMapper.isCompanyLocation(location);

    if (onCompany) {
      ref.watch(companySieBootstrapProvider);
    }

    if (!kDebugMode || !onCompany) {
      return widget.child;
    }

    final availability = ref.watch(companySieAvailabilityProvider);
    if (!availability.available) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 8,
          bottom: 28,
          child: IgnorePointer(
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'SIE-C ${availability.sieEnabled ? 'ON' : 'OFF'} · '
                  '${availability.activeRouteId ?? '—'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
