import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

SieIntegrationFramework _fw({
  InteractionOrchestratorPort? orch,
  InputArbitrationEnginePort? arb,
  IntentEnginePort? intent,
}) {
  return SieIntegrationFramework(
    orchestrator: orch,
    arbitration: arb,
    intent: intent,
    logger: const NopSieIntegrationLogger(),
  );
}

void main() {
  group('Integration — registration', () {
    test('register loads SkillForge routes and features', () async {
      final fw = _fw();
      await fw.register();
      expect(fw.currentStatus.phase, SieIntegrationPhase.registered);
      expect(fw.routes.contains('landing'), isTrue);
      expect(fw.routes.contains('payments'), isTrue);
      expect(fw.routes.contains('student.dashboard'), isTrue);
      expect(fw.features.isEnabled(SieIntegrationFeatureId.hover), isTrue);
      expect(fw.features.isEnabled(SieIntegrationFeatureId.debugOverlay), isFalse);
      await fw.dispose();
    });

    test('initialize is idempotent with register', () async {
      final fw = _fw();
      await fw.initialize();
      expect(fw.currentStatus.phase, SieIntegrationPhase.ready);
      expect(fw.routes.length, greaterThanOrEqualTo(10));
      await fw.dispose();
    });
  });

  group('Integration — route switching & security', () {
    test('dashboard enables SIE when host enables', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.activateRoute('student.dashboard');
      expect(fw.currentState.sieEnabled, isTrue);
      expect(fw.currentState.securityLevel, SieSecurityLevel.l1Standard);
      expect(fw.currentState.routePolicy.mode, SieRouteSieMode.enabled);
      await fw.dispose();
    });

    test('payments disables SIE automatically', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.activateRoute('payments');
      expect(fw.currentState.sieEnabled, isFalse);
      expect(fw.currentState.degradation, SieDegradationReason.routeDisabled);
      expect(fw.currentState.routePolicy.mode, SieRouteSieMode.disabled);
      await fw.dispose();
    });

    test('authentication is limited L3', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      final policy = await fw.activateRoute('authentication');
      expect(policy.mode, SieRouteSieMode.limited);
      expect(policy.securityLevel, SieSecurityLevel.l3Sensitive);
      expect(fw.currentState.sieEnabled, isTrue);
      await fw.dispose();
    });

    test('admin is restricted L2', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.activateRoute('admin.dashboard');
      expect(fw.currentState.routePolicy.mode, SieRouteSieMode.restricted);
      expect(fw.currentState.securityLevel, SieSecurityLevel.l2Elevated);
      await fw.dispose();
    });

    test('L4 policy forbids SIE', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.registerRoute(
        const SieRoutePolicy(
          routeId: 'critical.confirm',
          displayName: 'Critical',
          mode: SieRouteSieMode.enabled,
          capabilityKind: SieRouteCapabilityKind.custom,
          securityLevel: SieSecurityLevel.l4Irreversible,
          sieEnabled: true,
        ),
      );
      await fw.activateRoute('critical.confirm');
      expect(fw.currentState.sieEnabled, isFalse);
      expect(
        fw.currentState.degradation,
        SieDegradationReason.securityRestricted,
      );
      await fw.dispose();
    });

    test('settings route is configurable', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.activateRoute('settings');
      await fw.configureRoute('settings', sieEnabled: false);
      expect(fw.routes.require('settings').allowsSie, isFalse);
      expect(fw.currentState.sieEnabled, isFalse);
      await fw.dispose();
    });
  });

  group('Integration — lifecycle & accessibility', () {
    test('pause / resume lifecycle', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.pause();
      expect(fw.currentState.phase, SieIntegrationPhase.paused);
      expect(fw.currentState.lifecycle, SieAppLifecycleState.paused);
      await fw.resume();
      expect(fw.currentState.lifecycle, SieAppLifecycleState.resumed);
      await fw.dispose();
    });

    test('accessibility updates feature registry', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.setAccessibility(
        const SieAccessibilityState(
          reducedMotion: true,
          largeCursor: true,
          dwellMode: true,
        ),
      );
      expect(fw.features.isEnabled(SieIntegrationFeatureId.reducedMotion), isTrue);
      expect(fw.features.isEnabled(SieIntegrationFeatureId.largeCursor), isTrue);
      expect(fw.features.isEnabled(SieIntegrationFeatureId.dwell), isTrue);
      expect(fw.currentState.accessibility.dwellMode, isTrue);
      await fw.dispose();
    });
  });

  group('Integration — graceful degradation', () {
    test('camera unavailable disables SIE; traditional remains', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await fw.notifyCapabilities(
        availability: SieInteractionAvailability.traditionalOnly,
        permissionGranted: false,
      );
      expect(fw.currentState.sieEnabled, isFalse);
      expect(fw.currentState.traditionalAvailable, isTrue);
      expect(
        fw.currentState.degradation,
        isNot(SieDegradationReason.none),
      );
      await fw.dispose();
    });

    test('permission denial degrades without crash', () async {
      final fw = _fw();
      await fw.initialize(availability: SieInteractionAvailability.full);
      await fw.enable();
      await fw.notifyCapabilities(permissionGranted: false);
      expect(fw.currentState.sieEnabled, isFalse);
      expect(
        fw.currentState.degradation,
        SieDegradationReason.permissionDenied,
      );
      await fw.dispose();
    });
  });

  group('Integration — policy sync & diagnostics', () {
    test('policy sync builds arbitration without SIE on payments', () {
      final ctx = SieIntegrationPolicySync.arbitrationContext(
        policy: SieSkillForgeRouteCatalog.payments,
        accessibilityMode: false,
        paused: false,
        windowFocused: true,
      );
      expect(ctx.sieEnabled, isFalse);
      expect(ctx.allows(SieInputSource.sie), isFalse);
      expect(ctx.allows(SieInputSource.mouse), isTrue);
    });

    test('diagnostics report includes routes and features', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      final report = fw.diagnosticsReport();
      expect(report['enabledRoutes'], isA<List>());
      expect(report['disabledRoutes'], isA<List>());
      expect(report['features'], isA<Map>());
      expect(report['policyDecision'], isA<Map>());
      await fw.dispose();
    });

    test('future module route registration needs zero redesign', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.registerRoute(
        const SieRoutePolicy(
          routeId: 'ai.assistant',
          displayName: 'AI Assistant',
          mode: SieRouteSieMode.enabled,
          capabilityKind: SieRouteCapabilityKind.dashboard,
          securityLevel: SieSecurityLevel.l1Standard,
          module: SieAppModuleId.aiAssistant,
        ),
      );
      expect(fw.routes.contains('ai.assistant'), isTrue);
      await fw.enable();
      await fw.activateRoute('ai.assistant');
      expect(fw.currentState.module, SieAppModuleId.aiAssistant);
      await fw.dispose();
    });
  });

  group('Integration — performance & concurrency', () {
    test('route lookup is constant-time map', () async {
      final fw = _fw();
      await fw.register();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        fw.routes.lookup('student.dashboard');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100));
      await fw.dispose();
    });

    test('serialized activateRoute is thread-safe under concurrency', () async {
      final fw = _fw();
      await fw.initialize();
      await fw.enable();
      await Future.wait([
        fw.activateRoute('student.dashboard'),
        fw.activateRoute('teacher.dashboard'),
        fw.activateRoute('payments'),
        fw.activateRoute('landing'),
      ]);
      expect(fw.currentState.routePolicy.routeId, isNotEmpty);
      await fw.dispose();
    });
  });

  group('Integration — dependency isolation', () {
    test('port surface does not require camera/vision types in host API', () {
      // Compile-time isolation: host uses SieIntegrationPort only.
      SieIntegrationPort port = _fw();
      expect(port, isA<SieIntegrationFramework>());
    });

    test('framework works without wiring lower engines', () async {
      final fw = _fw(); // no orch/arb/intent
      await fw.register();
      await fw.initialize();
      await fw.enable();
      await fw.activateRoute('courses');
      expect(fw.currentState.sieEnabled, isTrue);
      await fw.shutdown();
      expect(fw.currentStatus.phase, SieIntegrationPhase.disposed);
    });
  });

  group('Integration — widget adapters', () {
    testWidgets('SieButton and SieTextField build', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SieButton(
                  sieTargetId: 'btn.ok',
                  onPressed: () {},
                  child: const Text('OK'),
                ),
                const SieTextField(sieTargetId: 'field.name'),
                SieSlider(value: 0.5, onChanged: (_) {}, sieTargetId: 'sl'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('OK'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('SieListView and SieCard build', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: SieListView(
                sieTargetId: 'list.main',
                itemCount: 3,
                itemBuilder: (context, i) => SieCard(
                  sieTargetId: 'card.$i',
                  child: Text('Item $i'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Item 0'), findsOneWidget);
    });
  });

  group('Integration — downstream sync', () {
    test('activates route on real orchestrator + arbitration', () async {
      final orch = SieInteractionOrchestrator(
        logger: const NopSieOrchestratorLogger(),
      );
      final arb = SieInputArbitrationEngine(
        logger: const NopSieArbitrationLogger(),
      );
      final intent = SieIntentEngine(logger: const NopSieIntentLogger());
      await orch.initialize();
      await arb.initialize();
      await intent.initialize();

      final fw = _fw(orch: orch, arb: arb, intent: intent);
      await fw.initialize();
      await fw.enable();
      await fw.activateRoute('payments');

      expect(orch.context.routeKind, SieRouteCapabilityKind.payment);
      expect(orch.interactionEnabled, isFalse);
      expect(arb.context.sieEnabled, isFalse);
      expect(intent.context.route.kind, SieRouteCapabilityKind.payment);

      await fw.dispose();
      await orch.dispose();
      await arb.dispose();
      await intent.dispose();
    });
  });
}
