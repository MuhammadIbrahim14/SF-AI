import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieProgressiveRolloutFramework _prf({
  SieIntegrationPort? integration,
  PrfConfig local = const PrfConfig(),
  PrfDeviceCapability? device,
}) {
  return SieProgressiveRolloutFramework(
    integration: integration,
    localDefaults: local,
    deviceProbe: StaticPrfDeviceCapabilityProbe(
      device ?? PrfDeviceCapability.capable(SiePlatformKind.web),
    ),
    logger: const NopPrfLogger(),
  );
}

Future<void> _init(
  ProgressiveRolloutPort prf, {
  SiePlatformKind platform = SiePlatformKind.web,
  PrfUserSegment segment = PrfUserSegment.publicUsers,
  String userKey = 'user-1',
  String routeId = 'landing',
  PrfConfig? runtime,
}) {
  return prf.initialize(
    platform: platform,
    segment: segment,
    userKey: userKey,
    routeId: routeId,
    runtime: runtime,
  );
}

void main() {
  group('PRF — feature flags', () {
    test('independent flags can toggle without affecting others', () async {
      final prf = _prf();
      await _init(prf);
      expect(prf.config.flags.enableSie, isTrue);
      await prf.setFeatureFlag(
        PrfFeatureFlagId.experimentalGestures,
        enabled: true,
      );
      expect(prf.config.flags.experimentalGestures, isTrue);
      expect(prf.config.flags.eyeTracking, isFalse);
      await prf.setFeatureFlag(PrfFeatureFlagId.enableSie, enabled: false);
      expect(prf.sieEnabled, isFalse);
      expect(
        prf.latestSnapshot.rejection,
        PrfRejectionReason.featureFlagDisabled,
      );
      await prf.dispose();
    });
  });

  group('PRF — platform & device', () {
    test('linux disabled by default platform policy', () async {
      final prf = _prf(
        device: PrfDeviceCapability.capable(SiePlatformKind.linux),
      );
      await _init(prf, platform: SiePlatformKind.linux);
      expect(prf.sieEnabled, isFalse);
      expect(
        prf.latestSnapshot.rejection,
        PrfRejectionReason.platformRejected,
      );
      await prf.dispose();
    });

    test('insufficient device rejects', () async {
      final prf = _prf(
        device: PrfDeviceCapability.insufficient(SiePlatformKind.web),
      );
      await _init(prf);
      expect(prf.sieEnabled, isFalse);
      expect(
        prf.latestSnapshot.rejection,
        PrfRejectionReason.deviceRejected,
      );
      await prf.dispose();
    });

    test('web + capable device enables', () async {
      final prf = _prf();
      await _init(prf);
      expect(prf.sieEnabled, isTrue);
      expect(prf.latestSnapshot.decision, PrfRolloutDecision.enable);
      await prf.dispose();
    });
  });

  group('PRF — route policies', () {
    test('payments route disables SIE', () async {
      final prf = _prf();
      await _init(prf);
      expect(prf.sieEnabled, isTrue);
      await prf.activateRoute('payments');
      expect(prf.sieEnabled, isFalse);
      expect(prf.latestSnapshot.rejection, PrfRejectionReason.routeRejected);
      await prf.dispose();
    });

    test('account deletion / critical disabled', () async {
      final prf = _prf();
      await _init(prf);
      await prf.activateRoute('admin.critical');
      expect(prf.sieEnabled, isFalse);
      await prf.dispose();
    });

    test('student dashboard enables', () async {
      final prf = _prf();
      await _init(prf, routeId: 'student.dashboard');
      expect(prf.sieEnabled, isTrue);
      await prf.dispose();
    });
  });

  group('PRF — segments', () {
    test('segment policy can exclude public users', () async {
      final prf = _prf(
        local: const PrfConfig(segments: PrfSegmentPolicy.internalOnly),
      );
      await _init(prf, segment: PrfUserSegment.publicUsers);
      expect(prf.sieEnabled, isFalse);
      expect(
        prf.latestSnapshot.rejection,
        PrfRejectionReason.segmentRejected,
      );
      await prf.setSegment(PrfUserSegment.qaTeam);
      expect(prf.sieEnabled, isTrue);
      await prf.dispose();
    });
  });

  group('PRF — canary', () {
    test('canary exclusion is deterministic for user key', () async {
      final prf = _prf(
        local: const PrfConfig(canaryPhase: PrfCanaryPhase.p1),
      );
      // Find a key that is excluded and one included.
      String? inKey;
      String? outKey;
      for (var i = 0; i < 500; i++) {
        final k = 'u$i';
        if (PrfCanaryAssigner.inCohort(k, 1)) {
          inKey ??= k;
        } else {
          outKey ??= k;
        }
        if (inKey != null && outKey != null) break;
      }
      expect(inKey, isNotNull);
      expect(outKey, isNotNull);

      await _init(prf, userKey: outKey!);
      expect(prf.sieEnabled, isFalse);
      expect(
        prf.latestSnapshot.rejection,
        PrfRejectionReason.canaryExcluded,
      );
      await prf.dispose();

      final prf2 = _prf(
        local: const PrfConfig(canaryPhase: PrfCanaryPhase.p1),
      );
      await _init(prf2, userKey: inKey!);
      expect(prf2.sieEnabled, isTrue);
      await prf2.dispose();
    });

    test('promote canary requires healthy telemetry', () async {
      final prf = _prf(
        local: const PrfConfig(canaryPhase: PrfCanaryPhase.p10),
      );
      await _init(prf, userKey: _keyInPercent(10));
      final next = await prf.promoteCanary();
      expect(next, PrfCanaryPhase.p25);
      await prf.dispose();
    });

    test('halt canary disables rollout', () async {
      final prf = _prf();
      await _init(prf);
      await prf.haltCanary();
      expect(prf.sieEnabled, isFalse);
      await prf.dispose();
    });
  });

  group('PRF — kill switch & rollback', () {
    test('local kill switch disables immediately', () async {
      final prf = _prf();
      await _init(prf);
      expect(prf.sieEnabled, isTrue);
      await prf.activateKillSwitch();
      expect(prf.sieEnabled, isFalse);
      expect(prf.latestSnapshot.decision, PrfRolloutDecision.killSwitch);
      expect(prf.currentStatus.killSwitchActive, isTrue);
      await prf.dispose();
    });

    test('dev override bypasses kill for internal developers', () async {
      final prf = _prf();
      await _init(prf, segment: PrfUserSegment.internalDevelopers);
      await prf.activateKillSwitch();
      await prf.setKillSwitchOverrides(developmentOverride: true);
      expect(prf.sieEnabled, isTrue);
      await prf.dispose();
    });

    test('manual rollback disables SIE', () async {
      final prf = _prf();
      await _init(prf);
      final snap = await prf.rollback(reason: 'test');
      expect(snap.rolledBack, isTrue);
      expect(snap.sieEnabled, isFalse);
      await prf.dispose();
    });

    test('bad telemetry triggers automatic rollback', () async {
      final prf = _prf();
      await _init(prf);
      expect(prf.sieEnabled, isTrue);
      final snap = await prf.ingestTelemetry(
        PrfTelemetrySample(
          timestamp: DateTime.utc(2026, 7, 17),
          averageFps: 5,
          cursorLatencyMs: 120,
          lostTrackingRate: 0.9,
        ),
      );
      expect(snap.sieEnabled, isFalse);
      expect(snap.rolledBack, isTrue);
      await prf.dispose();
    });
  });

  group('PRF — A/B & config precedence', () {
    test('A/B assignment is deterministic', () {
      final a = PrfAbAssigner.assign('user-42', 'cursor-adaptive');
      final b = PrfAbAssigner.assign('user-42', 'cursor-adaptive');
      expect(a, b);
      expect(
        a == PrfExperimentCohort.groupA || a == PrfExperimentCohort.groupB,
        isTrue,
      );
    });

    test('config precedence remote > runtime > build > local', () {
      final resolved = PrfConfigResolver.resolve(
        local: const PrfConfig(
          flags: PrfFeatureFlags(enableSie: false),
        ),
        buildTime: const PrfConfig(
          flags: PrfFeatureFlags(enableSie: true, debugOverlay: true),
        ),
        runtime: const PrfConfig(
          flags: PrfFeatureFlags(enableSie: true, betaFeatures: true),
        ),
        remote: const PrfConfig(
          flags: PrfFeatureFlags(enableSie: false),
          canaryPhase: PrfCanaryPhase.p50,
        ),
      );
      expect(resolved.source, PrfConfigSource.remote);
      expect(resolved.flags.enableSie, isFalse);
      expect(resolved.canaryPhase, PrfCanaryPhase.p50);
    });
  });

  group('PRF — telemetry thresholds & evaluator', () {
    test('evaluator is deterministic for identical context', () {
      final ctx = PrfEvaluationContext(
        platform: SiePlatformKind.android,
        segment: PrfUserSegment.betaTesters,
        routeId: 'teacher.dashboard',
        device: PrfDeviceCapability.capable(SiePlatformKind.android),
        config: const PrfConfig(),
        telemetry: PrfTelemetrySample.healthy(DateTime.utc(2026, 7, 17)),
        userKey: 'same',
      );
      final t = DateTime.utc(2026, 7, 17, 12);
      final a = PrfEvaluator.evaluate(ctx, timestamp: t);
      final b = PrfEvaluator.evaluate(ctx, timestamp: t);
      expect(a.sieEnabled, b.sieEnabled);
      expect(a.decision, b.decision);
      expect(a.rejection, b.rejection);
      expect(a.cohort, b.cohort);
    });

    test('performance: 10k evaluations under budget', () {
      final ctx = PrfEvaluationContext(
        platform: SiePlatformKind.web,
        segment: PrfUserSegment.publicUsers,
        routeId: 'landing',
        device: PrfDeviceCapability.capable(SiePlatformKind.web),
        config: const PrfConfig(),
        telemetry: PrfTelemetrySample.healthy(),
        userKey: 'perf',
      );
      final t = DateTime.utc(2026, 7, 17);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        PrfEvaluator.evaluate(ctx, timestamp: t);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  group('PRF — integration wiring & concurrency', () {
    test('applies enable/disable to Integration Framework', () async {
      final integration = SieIntegrationFramework(
        logger: const NopSieIntegrationLogger(),
      );
      await integration.register();
      await integration.initialize();

      final prf = _prf(integration: integration);
      await _init(prf);
      expect(integration.currentState.sieEnabled, isTrue);

      await prf.activateKillSwitch();
      expect(integration.currentState.sieEnabled, isFalse);

      await prf.dispose();
      await integration.dispose();
    });

    test('concurrent evaluate/activateRoute is serialized safely', () async {
      final prf = _prf();
      await _init(prf);
      await Future.wait([
        prf.activateRoute('student.dashboard'),
        prf.activateRoute('payments'),
        prf.evaluate(),
        prf.setFeatureFlag(PrfFeatureFlagId.betaFeatures, enabled: true),
      ]);
      expect(prf.latestSnapshot.routeId, isNotEmpty);
      await prf.dispose();
    });

    test('diagnostics report is engineering-safe', () async {
      final prf = _prf();
      await _init(prf);
      final d = prf.diagnosticsReport();
      expect(d['decision'], isNotNull);
      expect(d.containsKey('rawFrame'), isFalse);
      await prf.dispose();
    });
  });
}

String _keyInPercent(int percent) {
  for (var i = 0; i < 2000; i++) {
    final k = 'cohort-$i';
    if (PrfCanaryAssigner.inCohort(k, percent)) return k;
  }
  return 'cohort-0';
}
