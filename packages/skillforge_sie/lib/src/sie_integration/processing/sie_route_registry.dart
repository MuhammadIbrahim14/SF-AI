import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';

/// Constant-time route policy registry.
final class SieRouteRegistry {
  /// Creates registry.
  SieRouteRegistry();

  final Map<String, SieRoutePolicy> _byId = {};

  /// Register SkillForge defaults.
  void registerDefaults() {
    for (final p in SieSkillForgeRouteCatalog.defaults) {
      _byId[p.routeId] = p;
    }
  }

  /// Register / replace policy.
  void register(SieRoutePolicy policy) {
    _byId[policy.routeId] = policy;
  }

  /// Lookup (O(1)).
  SieRoutePolicy? lookup(String routeId) => _byId[routeId];

  /// Require lookup.
  SieRoutePolicy require(String routeId) {
    final p = _byId[routeId];
    if (p == null) {
      throw StateError('Unknown SIE route policy: $routeId');
    }
    return p;
  }

  /// Whether registered.
  bool contains(String routeId) => _byId.containsKey(routeId);

  /// All policies.
  List<SieRoutePolicy> get all =>
      List.unmodifiable(_byId.values.toList(growable: false));

  /// Enabled route ids.
  List<String> get enabledRouteIds => _byId.values
      .where((p) => p.allowsSie)
      .map((p) => p.routeId)
      .toList(growable: false);

  /// Disabled route ids.
  List<String> get disabledRouteIds => _byId.values
      .where((p) => !p.allowsSie)
      .map((p) => p.routeId)
      .toList(growable: false);

  /// Count.
  int get length => _byId.length;
}
