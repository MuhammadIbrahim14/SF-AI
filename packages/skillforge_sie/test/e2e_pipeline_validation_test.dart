import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

/// Doc 06 synthetic budgets (CI / host CPU — not device camera inference).
///
/// Camera + Vision MediaPipe are excluded from this harness (platform I/O).
/// Soft budgets validate CPU-side pipeline stages stay well under HCI targets.
const _stageBudgetMs = 8.0;
const _e2eP95BudgetMs = 40.0; // Doc 06: ≤120 ms p95 motion→cursor (device)
const _iterations = 120;
const _warmup = 10;

SieHandLandmark _vlm(double x, double y, [double z = 0]) =>
    SieHandLandmark(x: x, y: y, z: z);

List<SieHandLandmark> _valid21({required double tipX, required double tipY}) {
  return List<SieHandLandmark>.generate(21, (i) {
    if (i == 8) return _vlm(tipX, tipY);
    if (i == 4) return _vlm(tipX - 0.08, tipY);
    return _vlm(0.45 + i * 0.001, 0.55 + i * 0.001, i * 0.01);
  });
}

SieVisionResult _vision({
  required int sequence,
  required DateTime timestamp,
  required double tipX,
  required double tipY,
}) {
  return SieVisionResult(
    timestamp: timestamp,
    frameSequence: sequence,
    trackingState: SieVisionTrackingState.tracking,
    hands: [
      SieDetectedHand(
        landmarks: _valid21(tipX: tipX, tipY: tipY),
        handedness: SieHandedness.right,
        handednessScore: 0.95,
        handConfidence: 0.92,
        index: 0,
      ),
    ],
    inferenceMs: 8,
    detected: true,
  );
}

void main() {
  group('E2E pipeline validation — stage latency', () {
    test('measures landmarks→…→pointer distribution under budgets', () async {
      final landmarks = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      final spatial =
          SieSpatialCoordinateEngine(logger: const NopSieSpatialLogger());
      final calibration =
          SieCalibrationEngine(logger: const NopSieCalibrationLogger());
      final confidence =
          SieConfidenceEngine(logger: const NopSieConfidenceLogger());
      final gestures = SieGestureEngine(logger: const NopSieGestureLogger());
      final intent = SieIntentEngine(logger: const NopSieIntentLogger());
      final cursor =
          SieVirtualCursorEngine(logger: const NopSieCursorLogger());
      final pointer =
          SieFlutterPointerBridge(logger: const NopSiePointerLogger());

      await landmarks.initialize();
      await spatial.initialize(
        viewport: const SieViewportGeometry(
          viewWidth: 800,
          viewHeight: 600,
          cameraAspectRatio: 16 / 9,
        ),
      );
      await calibration.initialize();
      await confidence.initialize();
      await gestures.initialize();
      await intent.initialize();
      await cursor.initialize();
      await pointer.initialize();

      final stageSamples = <String, List<double>>{
        'landmarks': [],
        'spatial': [],
        'calibration': [],
        'confidence': [],
        'gesture': [],
        'intent': [],
        'cursor': [],
        'pointer': [],
        'e2e': [],
      };

      var t = DateTime.utc(2026, 7, 17, 12);
      for (var i = 0; i < _warmup + _iterations; i++) {
        final tipX = 0.4 + (i % 40) * 0.005;
        final tipY = 0.35 + (i % 20) * 0.002;
        final vision = _vision(
          sequence: i + 1,
          timestamp: t,
          tipX: tipX,
          tipY: tipY,
        );

        final e2e = Stopwatch()..start();

        var sw = Stopwatch()..start();
        final lm = landmarks.process(vision);
        sw.stop();
        final landmarksMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        final sp = spatial.process(lm);
        sw.stop();
        final spatialMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        final cal = calibration.process(sp);
        sw.stop();
        final calMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        final conf = confidence.process(cal);
        sw.stop();
        final confMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        final gest = gestures.process(conf);
        sw.stop();
        final gestMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        final ints = intent.process(gest);
        sw.stop();
        final intentMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        final cur = cursor.process(ints);
        sw.stop();
        final cursorMs = sw.elapsedMicroseconds / 1000.0;

        sw = Stopwatch()..start();
        pointer.process(
          SiePointerBridgeInput(
            cursor: cur,
            intents: ints.events,
          ),
        );
        sw.stop();
        final pointerMs = sw.elapsedMicroseconds / 1000.0;

        e2e.stop();
        final e2eMs = e2e.elapsedMicroseconds / 1000.0;

        if (i >= _warmup) {
          stageSamples['landmarks']!.add(landmarksMs);
          stageSamples['spatial']!.add(spatialMs);
          stageSamples['calibration']!.add(calMs);
          stageSamples['confidence']!.add(confMs);
          stageSamples['gesture']!.add(gestMs);
          stageSamples['intent']!.add(intentMs);
          stageSamples['cursor']!.add(cursorMs);
          stageSamples['pointer']!.add(pointerMs);
          stageSamples['e2e']!.add(e2eMs);
        }

        t = t.add(const Duration(milliseconds: 33));
      }

      final report = <String, SieLatencyDistribution>{
        for (final e in stageSamples.entries)
          e.key: SieLatencyStats.fromSamples(e.value),
      };

      // Emit for validation report capture (test runner stdout).
      // ignore: avoid_print
      print('SIE_E2E_BENCHMARK_JSON=${{
        for (final e in report.entries) e.key: e.value.toJson(),
      }}');

      for (final stage in [
        'landmarks',
        'spatial',
        'calibration',
        'confidence',
        'gesture',
        'intent',
        'cursor',
        'pointer',
      ]) {
        final d = report[stage]!;
        expect(d.count, _iterations, reason: stage);
        expect(
          d.p95Ms,
          lessThan(_stageBudgetMs),
          reason: '$stage p95=${d.p95Ms}ms exceeds ${_stageBudgetMs}ms',
        );
      }

      final e2e = report['e2e']!;
      expect(e2e.p95Ms, lessThan(_e2eP95BudgetMs));
      expect(e2e.medianMs, lessThan(_e2eP95BudgetMs));
      expect(e2e.averageMs, lessThan(_e2eP95BudgetMs));
      // Raw max is informational under GC / suite contention — do not gate on it.
      expect(e2e.maxMs, greaterThan(0));
      expect(e2e.p99Ms, lessThan(_e2eP95BudgetMs * 4));

      await landmarks.dispose();
      await spatial.dispose();
      await calibration.dispose();
      await confidence.dispose();
      await gestures.dispose();
      await intent.dispose();
      await cursor.dispose();
      await pointer.dispose();
    });

    test('fault injection: empty hands still completes without throw', () async {
      final landmarks = SieLandmarkEngine(logger: const NopSieLandmarkLogger());
      final spatial =
          SieSpatialCoordinateEngine(logger: const NopSieSpatialLogger());
      final calibration =
          SieCalibrationEngine(logger: const NopSieCalibrationLogger());
      final confidence =
          SieConfidenceEngine(logger: const NopSieConfidenceLogger());
      await landmarks.initialize();
      await spatial.initialize(
        viewport: const SieViewportGeometry(
          viewWidth: 800,
          viewHeight: 600,
          cameraAspectRatio: 16 / 9,
        ),
      );
      await calibration.initialize();
      await confidence.initialize();

      final lost = SieVisionResult.none(
        timestamp: DateTime.utc(2026, 7, 17),
        frameSequence: 1,
        trackingState: SieVisionTrackingState.lost,
        inferenceMs: 0,
      );
      final conf = confidence.process(
        calibration.process(spatial.process(landmarks.process(lost))),
      );
      expect(conf.trackingState, isNot(SieTrackingReliabilityState.stable));

      await landmarks.dispose();
      await spatial.dispose();
      await calibration.dispose();
      await confidence.dispose();
    });
  });

  group('Student route policy regression (package catalog)', () {
    test('every student route has explicit allowsSie decision', () {
      final all = [
        SieSkillForgeRouteCatalog.studentDashboard,
        ...SieStudentRouteCatalog.all,
      ];
      for (final p in all) {
        // Touch decision — no nulls; L4 / disabled must deny.
        final allowed = p.allowsSie;
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(allowed, isFalse, reason: p.routeId);
        }
        expect(PrfRouteCatalog.allowsSie(p.routeId), allowed, reason: p.routeId);
      }
    });

    test('rapid route activation stress via Integration Framework', () async {
      final sif = SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'student.dashboard',
        'student.courses',
        'student.courses.lesson',
        'student.courses.assignment.attempt',
        'student.courses.grand_test.attempt',
        'student.payments',
        'student.ai_tutor',
        'student.profile',
        'student.account_deletion',
      ];

      final sw = Stopwatch()..start();
      for (var round = 0; round < 20; round++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final pay = await sif.activateRoute('student.payments');
      expect(pay.allowsSie, isFalse);
      final gt = await sif.activateRoute('student.courses.grand_test.attempt');
      expect(gt.allowsSie, isFalse);

      await sif.dispose();
    });
  });

  group('Teacher route policy regression (package catalog)', () {
    test('every teacher route has explicit allowsSie decision', () {
      final all = [
        SieSkillForgeRouteCatalog.teacherDashboard,
        ...SieTeacherRouteCatalog.all,
      ];
      for (final p in all) {
        final allowed = p.allowsSie;
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(allowed, isFalse, reason: p.routeId);
        }
        expect(PrfRouteCatalog.allowsSie(p.routeId), allowed, reason: p.routeId);
      }
    });

    test('teacher IDS matrix: payments L3, publish L2, live restricted', () {
      expect(SieTeacherRouteCatalog.plans.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.paymentMethods.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.earnings.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.accountSecurity.allowsSie, isFalse);
      expect(SieTeacherRouteCatalog.accountDeletion.allowsSie, isFalse);
      expect(
        SieTeacherRouteCatalog.accountDeletion.securityLevel,
        SieSecurityLevel.l4Irreversible,
      );
      expect(
        SieTeacherRouteCatalog.coursePublish.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieTeacherRouteCatalog.coursePublish.securityLevel,
        SieSecurityLevel.l2Elevated,
      );
      expect(
        SieTeacherRouteCatalog.liveClassroom.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieTeacherRouteCatalog.projectReview.mode,
        SieRouteSieMode.limited,
      );
    });

    test('rapid teacher route activation stress (full catalog rounds)', () async {
      final sif = SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'teacher.dashboard',
        ...SieTeacherRouteCatalog.all.map((p) => p.routeId),
      ];

      final sw = Stopwatch()..start();
      for (var round = 0; round < 8; round++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      // Full catalog × 8 rounds must stay interactive under synthetic load.
      expect(sw.elapsedMilliseconds, lessThan(8000));

      final pay = await sif.activateRoute('teacher.plans');
      expect(pay.allowsSie, isFalse);
      final publish = await sif.activateRoute('teacher.courses.publish');
      expect(publish.allowsSie, isTrue); // restricted still allows SIE under policy
      expect(publish.mode, SieRouteSieMode.restricted);
      final del = await sif.activateRoute('teacher.account_deletion');
      expect(del.allowsSie, isFalse);

      await sif.dispose();
    });

    test('gradebook-style rapid scroll route dwell stays under budget', () async {
      final sif = SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        await sif.activateRoute('teacher.courses.assignment.results');
        if (i % 10 == 0) {
          await sif.activateRoute('teacher.analytics.students');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(3000));
      await sif.dispose();
    });
  });

  group('Freelancer route policy regression (package catalog)', () {
    test('every freelancer route has explicit allowsSie decision', () {
      final all = [
        SieSkillForgeRouteCatalog.freelancerDashboard,
        ...SieFreelancerRouteCatalog.all,
      ];
      for (final p in all) {
        final allowed = p.allowsSie;
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(allowed, isFalse, reason: p.routeId);
        }
        expect(PrfRouteCatalog.allowsSie(p.routeId), allowed, reason: p.routeId);
      }
    });

    test('freelancer IDS: payouts deny, wallet limited, contract traditional', () {
      expect(SieFreelancerRouteCatalog.payouts.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.contractAccept.allowsSie, isFalse);
      expect(SieFreelancerRouteCatalog.wallet.mode, SieRouteSieMode.limited);
      expect(SieFreelancerRouteCatalog.wallet.allowsSie, isTrue);
      expect(
        SieFreelancerRouteCatalog.proposalPublish.mode,
        SieRouteSieMode.restricted,
      );
    });

    test('rapid freelancer route activation stress (full catalog rounds)',
        () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'freelancer.dashboard',
        ...SieFreelancerRouteCatalog.all.map((p) => p.routeId),
      ];

      final sw = Stopwatch()..start();
      for (var round = 0; round < 6; round++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(8000));

      final payout = await sif.activateRoute('freelancer.payouts');
      expect(payout.allowsSie, isFalse);
      await sif.dispose();
    });

    test('freelancer project-list / wallet dwell stress', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 250; i++) {
        await sif.activateRoute('freelancer.orders');
        if (i % 8 == 0) {
          await sif.activateRoute('freelancer.wallet');
        }
        if (i % 13 == 0) {
          await sif.activateRoute('freelancer.invoices');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4000));

      expect(
        (await sif.activateRoute('freelancer.payouts')).allowsSie,
        isFalse,
      );
      expect(
        (await sif.activateRoute('freelancer.contracts.accept')).allowsSie,
        isFalse,
      );
      await sif.dispose();
    });
  });

  group('Company route policy regression (package catalog)', () {
    test('every company route has explicit allowsSie decision', () {
      final all = [
        SieSkillForgeRouteCatalog.companyDashboard,
        ...SieCompanyRouteCatalog.all,
      ];
      for (final p in all) {
        final allowed = p.allowsSie;
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(allowed, isFalse, reason: p.routeId);
        }
        expect(PrfRouteCatalog.allowsSie(p.routeId), allowed, reason: p.routeId);
      }
    });

    test('company IDS: billing deny, job create restricted, financial browse',
        () {
      expect(SieCompanyRouteCatalog.billing.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.roles.allowsSie, isFalse);
      expect(SieCompanyRouteCatalog.ownership.allowsSie, isFalse);
      expect(
        SieCompanyRouteCatalog.jobCreate.mode,
        SieRouteSieMode.restricted,
      );
      expect(
        SieCompanyRouteCatalog.financialReports.mode,
        SieRouteSieMode.limited,
      );
      expect(SieCompanyRouteCatalog.financialReports.allowsSie, isTrue);
    });

    test('rapid company route activation stress (full catalog rounds)',
        () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'company.dashboard',
        ...SieCompanyRouteCatalog.all.map((p) => p.routeId),
      ];

      final sw = Stopwatch()..start();
      for (var round = 0; round < 6; round++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(8000));

      final bill = await sif.activateRoute('company.billing');
      expect(bill.allowsSie, isFalse);
      await sif.dispose();
    });

    test('company pipeline / analytics dwell stress', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 300; i++) {
        await sif.activateRoute('company.pipeline');
        if (i % 6 == 0) {
          await sif.activateRoute('company.analytics');
        }
        if (i % 9 == 0) {
          await sif.activateRoute('company.reports');
        }
        if (i % 12 == 0) {
          await sif.activateRoute('company.documents');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4500));

      expect(
        (await sif.activateRoute('company.ownership')).allowsSie,
        isFalse,
      );
      expect(
        (await sif.activateRoute('company.permissions')).allowsSie,
        isFalse,
      );
      await sif.dispose();
    });
  });

  group('Admin route policy regression (package catalog)', () {
    test('every admin route has explicit allowsSie decision', () {
      final all = [
        SieSkillForgeRouteCatalog.adminDashboard,
        ...SieAdminRouteCatalog.all,
      ];
      for (final p in all) {
        final allowed = p.allowsSie;
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(allowed, isFalse, reason: p.routeId);
        }
        expect(PrfRouteCatalog.allowsSie(p.routeId), allowed, reason: p.routeId);
      }
    });

    test('admin IDS: billing/secrets/emergency deny; dashboard restricted', () {
      expect(SieAdminRouteCatalog.billing.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.secrets.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.emergency.allowsSie, isFalse);
      expect(SieAdminRouteCatalog.critical.allowsSie, isFalse);
      expect(
        SieSkillForgeRouteCatalog.adminDashboard.mode,
        SieRouteSieMode.restricted,
      );
      expect(SieAdminRouteCatalog.users.mode, SieRouteSieMode.limited);
    });

    test('rapid admin route activation stress (full catalog rounds)', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final routes = [
        'admin.dashboard',
        ...SieAdminRouteCatalog.all.map((p) => p.routeId),
      ];

      final sw = Stopwatch()..start();
      for (var round = 0; round < 5; round++) {
        for (final id in routes) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(8000));

      final bill = await sif.activateRoute('admin.billing');
      expect(bill.allowsSie, isFalse);
      await sif.dispose();
    });

    test('admin IDS protected-ops denial matrix (Prompt 30)', () {
      const denied = [
        'admin.api_keys',
        'admin.secrets',
        'admin.environment',
        'admin.database',
        'admin.backup_restore',
        'admin.billing',
        'admin.auth_settings',
        'admin.security_center',
        'admin.role_assignment',
        'admin.delete_ops',
        'admin.shutdown',
        'admin.emergency',
        'admin.ai_usage_control',
        'admin.incidents.write',
        'admin.account_deletion',
        'admin.critical',
      ];
      for (final id in denied) {
        expect(PrfRouteCatalog.allowsSie(id), isFalse, reason: id);
      }
      for (final p in SieAdminRouteCatalog.all) {
        if (p.securityLevel == SieSecurityLevel.l4Irreversible ||
            p.mode == SieRouteSieMode.disabled) {
          expect(p.allowsSie, isFalse, reason: p.routeId);
        }
      }
    });

    test('admin audit / moderation dwell stress under budget', () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 300; i++) {
        await sif.activateRoute('admin.audit_logs');
        if (i % 6 == 0) {
          await sif.activateRoute('admin.moderation.courses');
        }
        if (i % 9 == 0) {
          await sif.activateRoute('admin.moderation.marketplace');
        }
        if (i % 12 == 0) {
          await sif.activateRoute('admin.progressive_rollout');
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final emergency = await sif.activateRoute('admin.emergency');
      expect(emergency.allowsSie, isFalse);
      await sif.dispose();
    });
  });

  group('Accessibility non-regression', () {
    test('CPMF accessibility profiles compose without error', () async {
      final cpmf = SieConfigurationPolicyFramework(
        logger: const NopCpmfLogger(),
      );
      await cpmf.initialize(platform: SiePlatformKind.web);
      await cpmf.setProfiles([
        CpmfProfileId.reducedMotion,
        CpmfProfileId.largeCursor,
        CpmfProfileId.highContrast,
        CpmfProfileId.dwellMode,
        CpmfProfileId.leftHanded,
      ]);
      expect(cpmf.bundle.accessibility.reducedMotion, isTrue);
      expect(cpmf.bundle.accessibility.largeCursor, isTrue);
      expect(cpmf.bundle.accessibility.highContrast, isTrue);
      expect(cpmf.bundle.dwellSelectEnabled, isTrue);
      expect(cpmf.bundle.handedness, SieCalibratedHandedness.left);
      await cpmf.dispose();
    });
  });

  group('Enterprise acceptance (Prompt 31)', () {
    test('full platform catalog count and module coverage', () {
      final defaults = SieSkillForgeRouteCatalog.defaults;
      expect(defaults.length, greaterThan(100));

      final modules = defaults.map((p) => p.module).toSet();
      expect(modules.contains(SieAppModuleId.student), isTrue);
      expect(modules.contains(SieAppModuleId.teacher), isTrue);
      expect(modules.contains(SieAppModuleId.freelancer), isTrue);
      expect(modules.contains(SieAppModuleId.company), isTrue);
      expect(modules.contains(SieAppModuleId.admin), isTrue);
    });

    test('cross-role rapid route activation under Integration Framework',
        () async {
      final sif =
          SieIntegrationFramework(logger: const NopSieIntegrationLogger());
      await sif.register();
      await sif.initialize(availability: SieInteractionAvailability.full);
      await sif.enable();

      const cycle = [
        'student.dashboard',
        'teacher.dashboard',
        'freelancer.dashboard',
        'company.dashboard',
        'admin.dashboard',
        'student.ai_tutor',
        'teacher.plans',
        'freelancer.payouts',
        'company.billing',
        'admin.secrets',
      ];

      final sw = Stopwatch()..start();
      for (var round = 0; round < 25; round++) {
        for (final id in cycle) {
          await sif.activateRoute(id);
        }
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(10000));

      expect((await sif.activateRoute('admin.billing')).allowsSie, isFalse);
      expect((await sif.activateRoute('student.dashboard')).allowsSie, isTrue);
      await sif.dispose();
    });

    test('all L4 irreversible routes deny across modules', () {
      final l4 = SieSkillForgeRouteCatalog.defaults
          .where((p) => p.securityLevel == SieSecurityLevel.l4Irreversible);
      expect(l4, isNotEmpty);
      for (final p in l4) {
        expect(p.allowsSie, isFalse, reason: p.routeId);
        expect(PrfRouteCatalog.allowsSie(p.routeId), isFalse, reason: p.routeId);
      }
    });
  });
}
