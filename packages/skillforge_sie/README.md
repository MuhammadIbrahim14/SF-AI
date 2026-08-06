# skillforge_sie

Production package for the **SkillForge AI Spatial Interaction Engine (SIE)**.

## Current scope (v1.0.0)

1. **Platform Capability Layer** — detection, permissions, feature flags  
2. **Camera Engine** — discovery, lifecycle, continuous opaque frame stream  
3. **Vision Provider** — MediaPipe Hand Landmarker → `SieVisionResult` stream  
4. **Landmark Engine** — validate / normalize / stabilize → immutable snapshots  
5. **Spatial Coordinate Engine** — Camera → Normalized → Viewport → Screen → Flutter logical  
6. **Calibration Engine** — user / camera / display / zone / sensitivity → calibrated snapshots  
7. **Confidence Engine** — fusion / hysteresis / LostTracking / Recovering → confidence snapshots  
8. **Gesture Engine** — IDS vocabulary → immutable `SieGestureEvent` stream  
9. **Intent Engine** — gestures → official interaction intents (no PointerEvents / UI)  
10. **Virtual Cursor Engine** — intents → smoothed cursor snapshots (no PointerEvents / UI)  
11. **Flutter Pointer Bridge** — cursor + intents → Flutter-compatible pointer events  
12. **Input Arbitration Engine** — multi-modal ownership (Mouse/Touch/Keyboard/SIE)  
13. **Interaction Orchestrator** — lifecycle / focus / a11y / gated dispatch into the app  
14. **SIDF** — debug overlay, telemetry, timeline, recording/exports (engineering only)  
15. **SIE Integration Framework** — sole application façade (routes, adapters, policies)  
16. **Progressive Rollout Framework** — who / when / where SIE is enabled (kill switch, canary, A/B)  
17. **Configuration & Policy Management Framework** — authoritative thresholds, profiles, policies  
18. **Service Registry & Dependency Composition Root** — sole bootstrap / DI wiring for all of the above  
19. **Student Module route catalog** — explicit IDS policies (Phase 1 host)  
20. **Teacher Module route catalog** — explicit IDS policies (Phase 2 host)  
21. **Freelancer Module route catalog** — explicit IDS policies (Phase 3 host)  
22. **Company Module route catalog** — explicit IDS policies (Phase 4 host)  
23. **Admin Module route catalog** — highest-security IDS policies (Phase 5 host)  
24. **E2E + enterprise validation harness** — latency percentiles, cross-role stress, IDS regression (**SIE 1.0 certified**)

**Hosts must bootstrap via SRDCR.** Runtime engines must not instantiate peer engines.

### SRDCR usage

```dart
final srdcr = ref.read(sieSrdcrProvider);
await srdcr.bootstrap(platform: SiePlatformKind.web);
// Optional high-frequency pipeline:
await srdcr.startRuntimePipeline();

ref.watch(sieSrdcrAvailabilityProvider); // phase / health / ready

await srdcr.shutdown();
```

**Engines should consume tunables from CPMF snapshots** (gesture/cursor/confidence/calibration), not hard-code behavioral constants in host code.

### CPMF usage

```dart
final cpmf = ref.read(sieCpmfProvider);
await cpmf.initialize(
  platform: SiePlatformKind.web,
  environment: CpmfEnvironment.production,
  profiles: [CpmfProfileId.standard],
);

await cpmf.setProfiles([CpmfProfileId.accessibility, CpmfProfileId.leftHanded]);

final gesturePolicy = cpmf.bundle.gesturePolicy;
final cursorConfig = cpmf.bundle.toCursorEngineConfig();

cpmf.evaluatePolicy(
  CpmfPolicyQuestion.pinchActivateAllowed,
  routeId: 'student.dashboard',
  securityLevel: SieSecurityLevel.l1Standard,
);

ref.watch(sieCpmfAvailabilityProvider); // profile / env / version / health
```

### Progressive Rollout usage

```dart
final prf = ref.read(sieProgressiveRolloutProvider);
await prf.initialize(
  platform: SiePlatformKind.web,
  segment: PrfUserSegment.betaTesters,
  userKey: userId,
  routeId: 'student.dashboard',
);

// Emergency
await prf.activateKillSwitch();

// Canary promote when healthy
await prf.promoteCanary();

ref.watch(sieRolloutAvailabilityProvider); // enabled / stage / flags / health
```

### Integration Framework usage

```dart
final sif = ref.read(sieIntegrationFrameworkProvider);
await sif.register(); // automatic catalog + features
await sif.initialize(availability: SieInteractionAvailability.full);
await sif.enable();
await sif.activateRoute('student.dashboard');

// Payments → SIE disabled automatically (IDS)
await sif.activateRoute('payments');
assert(!sif.currentState.sieEnabled);

// Adapters (no MediaPipe coupling)
SieButton(
  sieTargetId: 'cta.enroll',
  onPressed: () {},
  child: const Text('Enroll'),
);

ref.watch(sieIntegrationAvailabilityProvider);
```

### SIDF usage

```dart
final sidf = ref.read(sidfDiagnosticsFrameworkProvider);
await sidf.initialize(flags: SidfFeatureFlags.debugAll.copyWith(recording: true));

// Host feeds diagnostics from each engine (observer only)
sidf.ingestStage(SidfStageSample(
  stage: SidfPipelineStage.gesture,
  health: SidfStageHealth.healthy,
  timestamp: DateTime.now().toUtc(),
  processingMs: 3.2,
));
sidf.recordTimeline(SidfTimelineEvent(
  timestamp: DateTime.now().toUtc(),
  category: SidfTimelineCategory.gesture,
  name: 'pinch_commit',
));
final snap = sidf.publish();

// Overlay (IgnorePointer — never steals input)
Stack(children: [
  appContent,
  SidfDebugOverlay(
    snapshot: snap,
    visible: ref.watch(sidfAvailabilityProvider).overlayVisible,
    flags: sidf.flags,
  ),
]);

ref.watch(sidfAvailabilityProvider); // enabled / overlay / recording only
```

### Interaction Orchestrator usage

```dart
final orch = ref.read(sieInteractionOrchestratorProvider);
await orch.initialize(
  dispatcher: CallbackInteractionDispatcher(
    onDispatch: (events) async {
      // Map via SieFlutterPointerEventMapper → GestureBinding / overlay
    },
  ),
);
await orch.setLifecycle(SieAppLifecycleState.resumed);
await orch.start(
  arbitrationSnapshots: ref.read(sieInputArbitrationEngineProvider).snapshots,
  siePointerBatches: /* batched Pointer Bridge events */,
);

ref.watch(sieOrchestratorAvailabilityProvider);
```

### Input Arbitration Engine usage

```dart
final iae = ref.read(sieInputArbitrationEngineProvider);
await iae.initialize();

iae.reportClaim(SieInputActivityClaim(
  timestamp: DateTime.now().toUtc(),
  source: SieInputSource.mouse,
  kind: SieInputActivityKind.move,
));

if (iae.forwardsSiePointers) {
  // allow orchestrator to dispatch SIE pointer batches
}

ref.watch(sieArbitrationAvailabilityProvider);
```

### Flutter Pointer Bridge usage

```dart
final bridge = ref.read(sieFlutterPointerBridgeProvider);
await bridge.initialize(injector: const GestureBindingPointerInjector());
await bridge.start(
  cursorSnapshots: ref.read(sieVirtualCursorEngineProvider).snapshots,
  intentSnapshots: ref.read(sieIntentEngineProvider).snapshots,
);

ref.watch(siePointerBridgeAvailabilityProvider);
```

### Virtual Cursor Engine usage

```dart
final cursor = ref.read(sieVirtualCursorEngineProvider);
await cursor.initialize(
  config: const SieCursorEngineConfig(
    bounds: SieCursorDisplayBounds(width: 1280, height: 720),
  ),
);
await cursor.start(ref.read(sieIntentEngineProvider).snapshots);

cursor.snapshots.listen((snap) { /* overlay + pointer bridge */ });

ref.watch(sieCursorAvailabilityProvider);
```

### Intent Engine usage

```dart
final intents = ref.read(sieIntentEngineProvider);
await intents.initialize();
await intents.start(ref.read(sieGestureEngineProvider).snapshots);

intents.events.listen((e) {
  if (!e.isActionable) return;
});

ref.watch(sieIntentAvailabilityProvider);
```

### Gesture Engine usage

```dart
final gestures = ref.read(sieGestureEngineProvider);
await gestures.initialize();
await gestures.start(ref.read(sieConfidenceEngineProvider).snapshots);

// High-frequency — NOT Riverpod
gestures.snapshots.listen((snap) { /* Intent Engine */ });

ref.watch(sieGestureAvailabilityProvider);
```

### Confidence Engine usage

```dart
final confidence = ref.read(sieConfidenceEngineProvider);
await confidence.initialize();
await confidence.start(ref.read(sieCalibrationEngineProvider).snapshots);

// High-frequency — NOT Riverpod
confidence.snapshots.listen((snap) {
  if (!snap.mayConsume) return;
  // Gesture Engine — respect snap.commitsSuppressed / gestureReady
});

ref.watch(sieConfidenceAvailabilityProvider);
```

### Calibration Engine usage

```dart
final calibration = ref.read(sieCalibrationEngineProvider);
await calibration.initialize(loadPersisted: true);
await calibration.start(ref.read(sieSpatialCoordinateEngineProvider).snapshots);

// Optional guided session
await calibration.beginSession();
await calibration.updateHandednessCalibration(
  const SieHandednessCalibration(preference: SieCalibratedHandedness.right),
);
await calibration.completeSession();

// High-frequency — NOT Riverpod
calibration.snapshots.listen((snap) { /* Confidence Engine */ });

ref.watch(sieCalibrationAvailabilityProvider);
```

### Spatial Coordinate Engine usage

```dart
final spatial = ref.read(sieSpatialCoordinateEngineProvider);
ref.read(sieSpatialViewportProvider.notifier).update(
  const SieViewportGeometry(
    viewWidth: 800,
    viewHeight: 600,
    cameraAspectRatio: 16 / 9,
    mirrorHorizontal: true,
  ),
);
await spatial.initialize();
await spatial.start(ref.read(sieLandmarkEngineProvider).snapshots);

// High-frequency — NOT Riverpod
spatial.snapshots.listen((snap) { /* Calibration / Confidence later */ });

ref.watch(sieSpatialEngineAvailabilityProvider);
```

### Landmark Engine usage

```dart
final landmarks = ref.read(sieLandmarkEngineProvider);
await landmarks.initialize();
await landmarks.start(ref.read(sieVisionRuntimeProvider).results);

// High-frequency — NOT Riverpod
landmarks.snapshots.listen((snap) { /* Spatial Coordinate Engine */ });

ref.watch(sieLandmarkEngineStatusProvider);
```

### Vision Provider usage

```dart
final vision = ref.read(sieVisionRuntimeProvider);
await vision.initialize();
await vision.start(ref.read(sieCameraEngineProvider).frames);

// High-frequency — NOT Riverpod
vision.results.listen((result) { /* Landmark Engine later */ });

// Low-frequency
ref.watch(sieVisionStatusProvider);
```

### Web host requirement

Include the MediaPipe bridge before Flutter bootstrap:

```html
<script type="module" src="sie_hand_landmarker_bridge.js"></script>
```

Copy from `packages/skillforge_sie/web/sie_hand_landmarker_bridge.js`.


## Usage (host)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

// Read capabilities
final caps = await ref.read(siePlatformCapabilitiesProvider.future);

// Feature flags
ref.read(sieFeatureFlagServiceProvider.notifier)
  .setEnabled(SieFeatureId.debugOverlay, enabled: true);

// Permissions
await ref.read(siePermissionStateProvider.notifier).request();
```

Add to the app `pubspec.yaml`:

```yaml
dependencies:
  skillforge_sie:
    path: packages/skillforge_sie
```

Do **not** import `package:skillforge_sie/src/...` from the app.

## Architecture

Follows frozen docs 01–06: ports + adapters, Clean Architecture, fail-open for the core product when SIE is unavailable.
