import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_enums.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_registry_snapshot.dart';
import 'package:skillforge_sie/src/sie_srdcr/models/srdcr_service_descriptor.dart';

/// Resolves a registered service by id (constructor injection helper).
typedef SrdcrResolve = Object Function(SrdcrServiceId id);

/// Factory that constructs a service using [resolve] for dependencies.
typedef SrdcrFactory = Object Function(SrdcrResolve resolve);

/// Thread-safe-ish service registry (single-threaded Flutter isolate + mutex queue externally).
final class SrdcrServiceRegistry {
  /// Creates empty registry.
  SrdcrServiceRegistry();

  final Map<SrdcrServiceId, SrdcrServiceDescriptor> _descriptors = {};
  final Map<SrdcrServiceId, SrdcrFactory> _factories = {};
  final Map<SrdcrServiceId, Object> _singletons = {};
  final Map<SrdcrServiceId, Object> _scoped = {};
  bool _scopeActive = false;
  bool _sealed = false;

  /// Registered descriptors.
  List<SrdcrServiceDescriptor> get descriptors =>
      List.unmodifiable(_descriptors.values.toList(growable: false));

  /// Registered ids.
  List<SrdcrServiceId> get registeredIds =>
      _descriptors.keys.toList(growable: false);

  /// Whether sealed (no further registration).
  bool get isSealed => _sealed;

  /// Register descriptor + factory. Services may not self-register after seal.
  void register(
    SrdcrServiceDescriptor descriptor,
    SrdcrFactory factory,
  ) {
    if (_sealed) {
      throw SieSrdcrFailure(
        message: 'Cannot register ${descriptor.id.name}: registry is sealed',
      );
    }
    if (_descriptors.containsKey(descriptor.id)) {
      throw SieSrdcrFailure(
        message: 'Duplicate registration: ${descriptor.id.name}',
      );
    }
    _descriptors[descriptor.id] = descriptor;
    _factories[descriptor.id] = factory;
  }

  /// Replace factory for testing (before seal / construct).
  void overrideFactory(SrdcrServiceId id, SrdcrFactory factory) {
    if (_sealed && _singletons.containsKey(id)) {
      throw SieSrdcrFailure(
        message: 'Cannot override ${id.name}: already constructed',
      );
    }
    if (!_descriptors.containsKey(id)) {
      throw SieSrdcrFailure(
        message: 'Cannot override unregistered service: ${id.name}',
      );
    }
    _factories[id] = factory;
    _singletons.remove(id);
    _scoped.remove(id);
  }

  /// Validate graph; throws [SieSrdcrFailure] on issues.
  void validateOrThrow() {
    final issues = SrdcrGraphValidator.validate(descriptors);
    if (issues.isNotEmpty) {
      throw SieSrdcrFailure(
        message: issues.map((i) => i.message).join('; '),
      );
    }
  }

  /// Seal registrations.
  void seal() {
    validateOrThrow();
    _sealed = true;
  }

  /// Begin scoped lifetime window.
  void beginScope() {
    _scopeActive = true;
    _scoped.clear();
  }

  /// End scope (dispose scoped instances if they expose dispose — host duty).
  void endScope() {
    _scoped.clear();
    _scopeActive = false;
  }

  /// Resolve service (constructs as needed).
  T resolve<T extends Object>(SrdcrServiceId id) {
    final desc = _descriptors[id];
    if (desc == null) {
      throw SieSrdcrFailure(message: 'Service not registered: ${id.name}');
    }
    switch (desc.lifetime) {
      case SrdcrLifetime.singleton:
        final existing = _singletons[id];
        if (existing != null) return existing as T;
        final created = _create(id);
        _singletons[id] = created;
        return created as T;
      case SrdcrLifetime.scoped:
        if (!_scopeActive) {
          throw SieSrdcrFailure(
            message: 'Scoped resolve without active scope: ${id.name}',
          );
        }
        final existing = _scoped[id];
        if (existing != null) return existing as T;
        final created = _create(id);
        _scoped[id] = created;
        return created as T;
      case SrdcrLifetime.transient:
        return _create(id) as T;
    }
  }

  /// Whether constructed.
  bool isConstructed(SrdcrServiceId id) =>
      _singletons.containsKey(id) || _scoped.containsKey(id);

  /// Construct all singletons in init order.
  void constructAllSingletons() {
    if (!_sealed) seal();
    final order = SrdcrGraphValidator.sortedInitOrder(descriptors);
    for (final id in order) {
      final desc = _descriptors[id]!;
      if (desc.lifetime == SrdcrLifetime.singleton) {
        resolve<Object>(id);
      }
    }
  }

  /// Clear constructed instances (after shutdown).
  void clearInstances() {
    _singletons.clear();
    _scoped.clear();
  }

  /// Full reset — allows a subsequent bootstrap after shutdown or failure.
  void reset() {
    _descriptors.clear();
    _factories.clear();
    _singletons.clear();
    _scoped.clear();
    _scopeActive = false;
    _sealed = false;
    _constructing.clear();
  }

  Object _create(SrdcrServiceId id) {
    final factory = _factories[id];
    if (factory == null) {
      throw SieSrdcrFailure(message: 'No factory for ${id.name}');
    }
    // Guard re-entrancy / cycles during construction
    if (_constructing.contains(id)) {
      throw SieSrdcrFailure(
        message: 'Circular dependency while constructing ${id.name}',
      );
    }
    _constructing.add(id);
    try {
      return factory(resolve);
    } finally {
      _constructing.remove(id);
    }
  }

  final Set<SrdcrServiceId> _constructing = {};
}
