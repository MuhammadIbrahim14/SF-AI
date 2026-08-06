import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieConfigurationPolicyFramework _cpmf({
  CpmfRemoteConfigPort? remote,
  CpmfLocalConfigPort? local,
}) {
  return SieConfigurationPolicyFramework(
    remoteConfig: remote ?? const NopCpmfRemoteConfig(),
    localConfig: local ?? const NopCpmfLocalConfig(),
    logger: const NopCpmfLogger(),
  );
}

void main() {
  group('CPMF — loading & snapshots', () {
    test('initialize produces immutable authoritative snapshot', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(
        platform: SiePlatformKind.web,
        environment: CpmfEnvironment.production,
      );
      expect(cpmf.latestSnapshot.healthy, isTrue);
      expect(cpmf.bundle.gestures.dwellMs, greaterThan(0));
      expect(cpmf.bundle.cursor.snapRadius, greaterThan(0));
      expect(cpmf.currentStatus.health, CpmfHealth.healthy);
      await cpmf.dispose();
    });

    test('environment override changes diagnostics for development', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(
        platform: SiePlatformKind.android,
        environment: CpmfEnvironment.production,
      );
      expect(cpmf.bundle.diagnostics.sidfEnabled, isFalse);
      await cpmf.setEnvironment(CpmfEnvironment.development);
      expect(cpmf.bundle.diagnostics.sidfEnabled, isTrue);
      expect(cpmf.currentStatus.environment, CpmfEnvironment.development);
      await cpmf.dispose();
    });
  });

  group('CPMF — profile inheritance', () {
    test('profiles compose accessibility flags', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      await cpmf.setProfiles([
        CpmfProfileId.reducedMotion,
        CpmfProfileId.largeCursor,
        CpmfProfileId.dwellMode,
      ]);
      final a11y = cpmf.bundle.accessibility;
      expect(a11y.reducedMotion, isTrue);
      expect(a11y.largeCursor, isTrue);
      expect(a11y.dwellMode, isTrue);
      expect(cpmf.bundle.dwellSelectEnabled, isTrue);
      await cpmf.dispose();
    });

    test('accessibility profile enables dwell and a11y gesture thresholds',
        () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      await cpmf.setProfiles([CpmfProfileId.accessibility]);
      expect(cpmf.bundle.dwellSelectEnabled, isTrue);
      expect(cpmf.bundle.gesturePolicyId, SieGesturePolicyId.accessibility);
      await cpmf.dispose();
    });

    test('left-handed profile sets handedness', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      await cpmf.setProfiles([CpmfProfileId.leftHanded]);
      expect(cpmf.bundle.handedness, SieCalibratedHandedness.left);
      await cpmf.dispose();
    });
  });

  group('CPMF — platform & environment overrides', () {
    test('android platform overlay sets vision fps', () {
      final snap = CpmfComposer.resolve(
        timestamp: DateTime.utc(2026, 7, 17),
        environment: CpmfEnvironment.production,
        platform: SiePlatformKind.android,
      );
      expect(snap.bundle.vision.targetFps, 24);
    });

    test('enterprise environment elevates default security', () {
      final snap = CpmfComposer.resolve(
        timestamp: DateTime.utc(2026, 7, 17),
        environment: CpmfEnvironment.enterprise,
        platform: SiePlatformKind.web,
      );
      expect(
        snap.bundle.security.defaultLevel,
        SieSecurityLevel.l2Elevated,
      );
    });
  });

  group('CPMF — policy evaluation', () {
    test('pinch blocked on L3 / payments', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      expect(
        cpmf.evaluatePolicy(
          CpmfPolicyQuestion.pinchActivateAllowed,
          routeId: 'student.dashboard',
          securityLevel: SieSecurityLevel.l1Standard,
        ),
        isTrue,
      );
      expect(
        cpmf.evaluatePolicy(
          CpmfPolicyQuestion.pinchActivateAllowed,
          routeId: 'payments',
          securityLevel: SieSecurityLevel.l3Sensitive,
        ),
        isFalse,
      );
      expect(
        cpmf.evaluatePolicy(
          CpmfPolicyQuestion.sieOperableOnRoute,
          routeId: 'admin.critical',
          securityLevel: SieSecurityLevel.l4Irreversible,
        ),
        isFalse,
      );
      await cpmf.dispose();
    });

    test('snapping disabled at L3', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      expect(
        cpmf.evaluatePolicy(
          CpmfPolicyQuestion.snappingEnabled,
          routeId: 'landing',
          securityLevel: SieSecurityLevel.l1Standard,
        ),
        isTrue,
      );
      expect(
        cpmf.evaluatePolicy(
          CpmfPolicyQuestion.snappingEnabled,
          routeId: 'landing',
          securityLevel: SieSecurityLevel.l3Sensitive,
        ),
        isFalse,
      );
      await cpmf.dispose();
    });

    test('policy evaluation is deterministic', () {
      final ctx = CpmfPolicyContext(
        routeId: 'courses',
        securityLevel: SieSecurityLevel.l1Standard,
        bundle: CpmfConfigurationBundle.builtInDefaults,
      );
      final a = CpmfPolicyEngine.evaluate(
        CpmfPolicyQuestion.dragAllowed,
        ctx,
      );
      final b = CpmfPolicyEngine.evaluate(
        CpmfPolicyQuestion.dragAllowed,
        ctx,
      );
      expect(a, b);
    });
  });

  group('CPMF — validation & migration', () {
    test('invalid runtime overrides are rejected', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      expect(
        () => cpmf.setRuntimeOverrides(
          CpmfConfigurationBundle.builtInDefaults.copyWith(
            camera: const CpmfCameraDomain(targetFps: 0),
          ),
        ),
        throwsA(isA<SieCpmfFailure>()),
      );
      await cpmf.dispose();
    });

    test('schema mismatch falls back safely', () {
      final bad = CpmfConfigurationBundle.builtInDefaults.copyWith(
        schemaVersion: 99,
        compatibilityVersion: 99,
      );
      final snap = CpmfComposer.resolve(
        timestamp: DateTime.utc(2026, 7, 17),
        environment: CpmfEnvironment.production,
        platform: SiePlatformKind.web,
        runtime: bad,
      );
      expect(snap.healthy, isFalse);
      expect(snap.bundle.schemaVersion, kCpmfSchemaVersion);
      expect(snap.bundle.changeHistory, contains('validation_fallback'));
    });

    test('migrator upgrades pre-v1 schema', () {
      final old = CpmfConfigurationBundle.builtInDefaults.copyWith(
        schemaVersion: 0,
      );
      final migrated = CpmfMigrator.migrate(old);
      expect(migrated.schemaVersion, kCpmfSchemaVersion);
      expect(migrated.changeHistory, contains('migrated:v1'));
    });
  });

  group('CPMF — config precedence', () {
    test('remote wins over runtime', () {
      final snap = CpmfComposer.resolve(
        timestamp: DateTime.utc(2026, 7, 17),
        environment: CpmfEnvironment.production,
        platform: SiePlatformKind.web,
        runtime: CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: 'runtime',
          camera: const CpmfCameraDomain(targetFps: 25),
        ),
        remote: CpmfConfigurationBundle.builtInDefaults.copyWith(
          version: 'remote',
          camera: const CpmfCameraDomain(targetFps: 28),
        ),
      );
      expect(snap.source, CpmfConfigSource.remote);
      expect(snap.bundle.camera.targetFps, 28);
      expect(snap.version, 'remote');
    });
  });

  group('CPMF — performance & concurrency', () {
    test('composer resolves 5k times under budget', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5000; i++) {
        CpmfComposer.resolve(
          timestamp: DateTime.utc(2026, 7, 17),
          environment: CpmfEnvironment.production,
          platform: SiePlatformKind.web,
          profiles: const [CpmfProfileId.standard],
        );
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('concurrent profile switches are serialized', () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      await Future.wait([
        cpmf.setProfiles([CpmfProfileId.developer]),
        cpmf.setProfiles([CpmfProfileId.qa]),
        cpmf.setEnvironment(CpmfEnvironment.qa),
      ]);
      expect(cpmf.latestSnapshot.profiles, isNotEmpty);
      await cpmf.dispose();
    });
  });

  group('CPMF — engine consumption surface', () {
    test('bundle exposes gesture policy and cursor config for engines',
        () async {
      final cpmf = _cpmf();
      await cpmf.initialize(platform: SiePlatformKind.web);
      final policy = cpmf.bundle.gesturePolicy;
      expect(policy.thresholds.isValid, isTrue);
      final cursorCfg = cpmf.bundle.toCursorEngineConfig();
      expect(cursorCfg.motion.snapEnabled, isTrue);
      final report = cpmf.diagnosticsReport();
      expect(report['thresholds'], isA<Map>());
      await cpmf.dispose();
    });
  });
}
