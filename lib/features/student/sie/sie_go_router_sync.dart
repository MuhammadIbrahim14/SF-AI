import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Resolved route location + optional GoRouter name.
typedef SieRouteContext = ({String location, String? routeName});

/// Keeps a [MaterialApp.builder] listener in sync with GoRouter navigations.
///
/// [GoRouter.of] / [GoRouterState.of] are unavailable in [MaterialApp.builder]
/// (above InheritedGoRouter). Pass the app [GoRouter] from [routerProvider].
mixin SieGoRouterSync<T extends StatefulWidget> on State<T> {
  GoRouter? _sieRouter;
  VoidCallback? _sieRouteListener;

  /// Call from [State.didChangeDependencies] with the app router instance.
  void attachSieRouteSync(GoRouter router, VoidCallback onRouteChanged) {
    if (!identical(_sieRouter, router)) {
      if (_sieRouteListener != null) {
        _sieRouter?.routerDelegate.removeListener(_sieRouteListener!);
      }
      _sieRouter = router;
      _sieRouteListener = onRouteChanged;
      router.routerDelegate.addListener(onRouteChanged);
    }
    // Router match stack is empty during first build — defer sync.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) onRouteChanged();
    });
  }

  /// Call from [State.dispose].
  void detachSieRouteSync() {
    if (_sieRouteListener != null) {
      _sieRouter?.routerDelegate.removeListener(_sieRouteListener!);
    }
    _sieRouter = null;
    _sieRouteListener = null;
  }

  /// Safe router state — null until the first route match is ready.
  GoRouterState? trySieRouterState() {
    final router = _sieRouter;
    if (router == null) return null;
    if (router.routerDelegate.currentConfiguration.isEmpty) return null;
    try {
      return router.state;
    } catch (_) {
      return null;
    }
  }

  /// Location + route name, or null before GoRouter has a match.
  SieRouteContext? trySieRouteContext() {
    final state = trySieRouterState();
    if (state != null) {
      return (location: state.uri.toString(), routeName: state.name);
    }
    final router = _sieRouter;
    if (router == null) return null;
    try {
      final uri = router.routeInformationProvider.value.uri;
      if (uri.path.isEmpty && uri.toString().isEmpty) return null;
      return (location: uri.toString(), routeName: null);
    } catch (_) {
      return null;
    }
  }
}
