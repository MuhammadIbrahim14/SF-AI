import 'dart:async';

import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_core/sie_failures.dart';
import 'package:skillforge_sie/src/sie_cpmf/logging/cpmf_logger.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_policy_context.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_snapshot.dart';
import 'package:skillforge_sie/src/sie_cpmf/ports/cpmf_port.dart';
import 'package:skillforge_sie/src/sie_cpmf/ports/cpmf_remote_config_port.dart';
import 'package:skillforge_sie/src/sie_cpmf/processing/cpmf_composer.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_diagnostics_snapshot.dart';
import 'package:skillforge_sie/src/sie_diagnostics/models/sidf_enums.dart';
import 'package:skillforge_sie/src/sie_diagnostics/ports/sidf_diagnostics_port.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// Production Configuration & Policy Management Framework.
final class SieConfigurationPolicyFramework implements CpmfPort {
  /// Creates framework.
  SieConfigurationPolicyFramework({
    CpmfRemoteConfigPort remoteConfig = const NopCpmfRemoteConfig(),
    CpmfLocalConfigPort localConfig = const NopCpmfLocalConfig(),
    SidfDiagnosticsPort? diagnostics,
    CpmfLogger logger = const DeveloperCpmfLogger(),
  })  : _remoteConfig = remoteConfig,
        _localConfig = localConfig,
        _diagnostics = diagnostics,
        _logger = logger;

  final CpmfRemoteConfigPort _remoteConfig;
  final CpmfLocalConfigPort _localConfig;
  final SidfDiagnosticsPort? _diagnostics;
  final CpmfLogger _logger;

  final StreamController<CpmfFrameworkStatus> _statusController =
      StreamController<CpmfFrameworkStatus>.broadcast();
  final StreamController<CpmfConfigurationSnapshot> _snapshotController =
      StreamController<CpmfConfigurationSnapshot>.broadcast();

  CpmfConfigurationSnapshot _snapshot = CpmfConfigurationSnapshot(
    timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    environment: CpmfEnvironment.production,
    platform: SiePlatformKind.unsupported,
    profiles: const [CpmfProfileId.standard],
    bundle: CpmfConfigurationBundle.builtInDefaults,
    source: CpmfConfigSource.builtIn,
    healthy: true,
  );
  CpmfFrameworkStatus _status = CpmfFrameworkStatus.idle();

  SiePlatformKind _platform = SiePlatformKind.unsupported;
  CpmfEnvironment _environment = CpmfEnvironment.production;
  List<CpmfProfileId> _profiles = const [CpmfProfileId.standard];
  CpmfConfigurationBundle? _buildTime;
  CpmfConfigurationBundle? _runtime;
  CpmfConfigurationBundle? _remote;
  CpmfConfigurationBundle? _localFile;
  bool _initialized = false;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();

  @override
  Stream<CpmfFrameworkStatus> get status => _statusController.stream;

  @override
  Stream<CpmfConfigurationSnapshot> get snapshots => _snapshotController.stream;

  @override
  CpmfFrameworkStatus get currentStatus => _status;

  @override
  CpmfConfigurationSnapshot get latestSnapshot => _snapshot;

  @override
  CpmfConfigurationBundle get bundle => _snapshot.bundle;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _publish(CpmfConfigurationSnapshot snap, {required String event}) {
    _snapshot = snap;
    final health = !snap.healthy
        ? CpmfHealth.degraded
        : (_initialized ? CpmfHealth.healthy : CpmfHealth.idle);
    _status = CpmfFrameworkStatus(
      health: health,
      environment: snap.environment,
      profileIds: snap.profiles,
      version: snap.version,
      lastEvent: event,
    );
    if (!_statusController.isClosed) _statusController.add(_status);
    if (!_snapshotController.isClosed) _snapshotController.add(snap);
  }

  Future<void> _reload({required String event}) async {
    final snap = CpmfComposer.resolve(
      timestamp: DateTime.now().toUtc(),
      environment: _environment,
      platform: _platform,
      profiles: _profiles,
      buildTime: _buildTime,
      runtime: _runtime,
      remote: _remote,
      localFile: _localFile,
    );
    _publish(snap, event: event);
    _emitSidf(snap, event);
  }

  @override
  Future<void> initialize({
    required SiePlatformKind platform,
    CpmfEnvironment environment = CpmfEnvironment.production,
    List<CpmfProfileId> profiles = const [CpmfProfileId.standard],
    CpmfConfigurationBundle? buildTime,
    CpmfConfigurationBundle? runtime,
  }) =>
      _serialized(() async {
        _ensureNotDisposed();
        _platform = platform;
        _environment = environment;
        _profiles = List.unmodifiable(profiles);
        _buildTime = buildTime;
        _runtime = runtime;
        try {
          _localFile = await _localConfig.load();
        } catch (e) {
          _logger.warn('local_config_load_failed', {'error': '$e'});
        }
        try {
          final remote = await _remoteConfig.fetch();
          if (remote != null) {
            _remote = CpmfMigrator.migrate(remote);
          }
        } catch (e) {
          _logger.warn('remote_config_fetch_failed', {'error': '$e'});
        }
        _initialized = true;
        await _reload(event: 'configuration_loaded');
        _logger.info('configuration_loaded', {
          'environment': environment.name,
          'platform': platform.name,
          'version': _snapshot.version,
          'source': _snapshot.source.name,
          'healthy': _snapshot.healthy,
        });
      });

  @override
  Future<void> setEnvironment(CpmfEnvironment environment) =>
      _serialized(() async {
        _ensureReady();
        _environment = environment;
        await _reload(event: 'environment_changed');
        _logger.info('environment_changed', {'environment': environment.name});
      });

  @override
  Future<void> setProfiles(List<CpmfProfileId> profiles) =>
      _serialized(() async {
        _ensureReady();
        if (profiles.isEmpty) {
          throw SieCpmfFailure(message: 'Profile stack cannot be empty');
        }
        _profiles = List.unmodifiable(profiles);
        await _reload(event: 'profile_switched');
        _logger.info('profile_switched', {
          'profiles': profiles.map((p) => p.name).toList(growable: false),
        });
      });

  @override
  Future<void> setRuntimeOverrides(CpmfConfigurationBundle runtime) =>
      _serialized(() async {
        _ensureReady();
        final issues = CpmfValidator.validate(runtime, platform: _platform);
        final hasError =
            issues.any((i) => i.severity == CpmfValidationSeverity.error);
        if (hasError) {
          _logger.error('configuration_validation_failed', {
            'issues': issues.map((i) => i.message).toList(growable: false),
          });
          throw SieCpmfFailure(
            message: 'Invalid runtime configuration overrides',
          );
        }
        _runtime = runtime;
        await _reload(event: 'policy_updated');
        _logger.info('policy_updated', {'source': 'runtime'});
      });

  @override
  Future<void> refresh() => _serialized(() async {
        _ensureReady();
        try {
          _localFile = await _localConfig.load();
          final remote = await _remoteConfig.fetch();
          if (remote != null) {
            _remote = CpmfMigrator.migrate(remote);
          }
        } catch (e) {
          _logger.warn('refresh_failed', {'error': '$e'});
        }
        await _reload(event: 'configuration_refreshed');
      });

  @override
  bool evaluatePolicy(
    CpmfPolicyQuestion question, {
    required String routeId,
    required SieSecurityLevel securityLevel,
  }) {
    return CpmfPolicyEngine.evaluate(
      question,
      CpmfPolicyContext(
        routeId: routeId,
        securityLevel: securityLevel,
        bundle: _snapshot.bundle,
      ),
    );
  }

  @override
  CpmfConfigurationBundle domainBundle() => _snapshot.bundle;

  @override
  Map<String, Object?> diagnosticsReport() => _snapshot.toDiagnostics();

  @override
  Future<void> dispose() => _serialized(() async {
        if (_disposed) return;
        _disposed = true;
        _status = const CpmfFrameworkStatus(
          health: CpmfHealth.disposed,
          environment: CpmfEnvironment.production,
          profileIds: [CpmfProfileId.standard],
          version: '0.0.0',
          lastEvent: 'disposed',
        );
        if (!_statusController.isClosed) _statusController.add(_status);
        await _statusController.close();
        await _snapshotController.close();
      });

  void _emitSidf(CpmfConfigurationSnapshot snap, String event) {
    final diag = _diagnostics;
    if (diag == null) return;
    diag.recordTimeline(
      SidfTimelineEvent(
        timestamp: snap.timestamp,
        category: SidfTimelineCategory.lifecycle,
        name: 'cpmf_$event',
        detail: '${snap.environment.name}/${snap.version}',
        metadata: {
          'source': snap.source.name,
          'healthy': snap.healthy,
        },
      ),
    );
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SieCpmfFailure(message: 'CPMF is disposed.');
    }
  }

  void _ensureReady() {
    _ensureNotDisposed();
    if (!_initialized) {
      throw SieCpmfFailure(message: 'CPMF not initialized.');
    }
  }
}
