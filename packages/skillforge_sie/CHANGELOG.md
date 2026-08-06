# Changelog

## 1.0.0 — 2026-07-17

### Added
- **SIE Version 1.0** — official enterprise production release
- Enterprise acceptance harness: cross-role switching, platform-wide IDS denial matrix, rollout kill-switch/rollback certification
- Final acceptance report (`docs/spatial_interaction_engine/13_ENTERPRISE_ACCEPTANCE_AND_RELEASE.md`)
- Release operations pack (`docs/spatial_interaction_engine/release/`)

### Changed
- All five production modules (Student, Teacher, Freelancer, Company, Admin) certified under shared SRDCR
- No engine algorithm changes — synthetic E2E p95 remains ≪ Doc 06 budgets

### Security
- Platform-wide L3/L4 traditional-only routes verified across all modules
- PRF kill switch and manual rollback certified

## 0.23.1 — 2026-07-17

### Added
- Admin Module validation harness: protected-ops IDS denial matrix, audit/moderation dwell stress, five-module route switching in E2E + host suites
- Formal Admin validation report (`docs/spatial_interaction_engine/12_ADMIN_MODULE_VALIDATION.md`)

### Changed
- No engine algorithm changes — synthetic E2E p95 remains ≪ Doc 06 budgets; optimize-only policy retained

## 0.23.0 — 2026-07-17

### Added
- **Admin Module route catalog** (`SieAdminRouteCatalog`): highest-security SIE policies for platform governance
- IDS-aligned modes — browse/limited for users & CMS; restricted for verification/rollout/audit; billing/secrets/API keys/emergency disabled L3; account deletion & critical L4
- SkillForge defaults include Admin policies for Integration + PRF lookup
- Admin route stress regression in E2E validation harness

## 0.22.1 — 2026-07-17

### Added
- Company Module validation harness: pipeline/analytics dwell stress, enterprise IDS denial matrix in E2E + host suites
- Formal Company validation report (`docs/spatial_interaction_engine/11_COMPANY_MODULE_VALIDATION.md`)

### Changed
- No engine algorithm changes — synthetic E2E p95 remains ≪ Doc 06 budgets; optimize-only policy retained

## 0.22.0 — 2026-07-17

### Added
- **Company Module route catalog** (`SieCompanyRouteCatalog`): explicit SIE policies for Company / recruitment surfaces
- IDS-aligned modes — job publish restricted, financial reports limited, billing/roles/ownership disabled L3, account deletion L4
- SkillForge defaults include Company policies for Integration + PRF lookup
- Company route stress regression in E2E validation harness

## 0.21.1 — 2026-07-17

### Added
- Freelancer Module validation harness: project/wallet dwell stress, financial IDS denial matrix in E2E + host suites
- Formal Freelancer validation report (`docs/spatial_interaction_engine/10_FREELANCER_MODULE_VALIDATION.md`)

### Changed
- No engine algorithm changes — synthetic E2E p95 remains ≪ Doc 06 budgets; optimize-only policy retained

## 0.21.0 — 2026-07-17

### Added
- **Freelancer Module route catalog** (`SieFreelancerRouteCatalog`): explicit SIE policies for Freelancer surfaces
- IDS-aligned modes — wallet browse (limited), payouts/contract/banking disabled L3, proposal publish restricted, account deletion L4
- SkillForge defaults include Freelancer policies for Integration + PRF lookup
- Freelancer route stress regression in E2E validation harness

## 0.20.1 — 2026-07-17

### Added
- Teacher Module validation harness: full-catalog route stress, gradebook dwell stress, IDS matrix regression in `e2e_pipeline_validation_test.dart`
- Formal Teacher validation report (`docs/spatial_interaction_engine/09_TEACHER_MODULE_VALIDATION.md`)

### Changed
- No engine algorithm changes — synthetic E2E p95 remains ≪ Doc 06 budgets; optimize-only policy retained

## 0.20.0 — 2026-07-17

### Added
- **Teacher Module route catalog** (`SieTeacherRouteCatalog`): explicit SIE policies for every Teacher surface
- IDS-aligned modes — payments disabled, publish/review elevated, live classroom restricted, account deletion L4
- SkillForge defaults include Teacher policies for Integration + PRF lookup

## 0.19.1 — 2026-07-17

### Changed
- **SIDF telemetry**: rolling e2e distribution now includes median / p95 / p99 / min / max
- **SidfEventTimeline / e2e window**: O(1) ring trim via `Queue` (removes O(n) `removeAt(0)` on every overflow)

### Added
- `SieLatencyStats` — deterministic latency distribution helper for validation
- E2E pipeline validation harness (landmarks→pointer) + Student route stress / a11y regression tests

## 0.19.0 — 2026-07-17

### Added
- **Student Module route catalog** (`SieStudentRouteCatalog`): explicit SIE policies for every Student surface
- IDS-aligned modes — quizzes restricted, grand-test attempt / payments / account security disabled, account deletion L4
- PRF route lookup includes Student policies via SkillForge defaults

## 0.18.0 — 2026-07-17

### Added
- **Service Registry & Dependency Composition Root (SRDCR)** (`sie_srdcr`): sole authoritative bootstrap for SIE
- Central registration of every major subsystem with explicit lifetimes (singleton / scoped / transient)
- Deterministic startup & shutdown pipelines; dependency graph validation (missing, duplicate, cycles, init order)
- Platform-specific factories replaceable via overrides; `useTestDoubles` for fake camera / mock vision
- Runtime pipeline wiring (`startRuntimePipeline`) owned by composition root — engines do not construct peers
- Riverpod for phase / health / ready only (ADR-008); Riverpod is not the composition root
- Unit tests for registration, graph validation, lifetimes, mock injection, startup/shutdown, performance

## 0.17.0 — 2026-07-17

### Added
- **Configuration & Policy Management Framework (CPMF)** (`sie_cpmf`): sole authoritative source for SIE tunables
- Domain bundles (camera/vision/gestures/cursor/confidence/calibration/a11y/security/performance/diagnostics)
- Composable profiles, environment & platform overlays, deterministic policy engine
- Config precedence (built-in → local → environment → profiles → build → runtime → remote)
- Validation, schema migration, immutable `CpmfConfigurationSnapshot`
- Riverpod for active profile / environment / version / health only (ADR-008)
- Unit tests for loading, inheritance, overrides, policy, validation, migration, concurrency

## 0.16.0 — 2026-07-17

### Added
- **Progressive Rollout Framework (PRF)** (`sie_rollout`): sole authority for when/where/for whom SIE is enabled
- Feature flags, user segments, platform maturity policies, route rollout gates (IDS-aligned)
- Device capability probes, telemetry thresholds, canary phases (1→100%), deterministic A/B cohorts
- Kill switch (local/remote + dev/QA overrides), automatic rollback, config precedence (remote > runtime > build > local)
- Immutable `PrfRolloutSnapshot`; wires Integration Framework enable/disable; SIDF timeline hooks
- Riverpod for enabled / canary / platform / flags / health only (ADR-008)
- Unit tests for flags, routes, platforms, device, canary, kill switch, rollback, A/B, precedence, concurrency

## 0.15.0 — 2026-07-17

### Added
- **SIE Integration Framework** (`sie_integration`): sole host façade between SkillForge AI and SIE
- Automatic registration, SkillForge route catalog, feature registry, IDS L0–L4 security sync
- Widget adapters (`SieButton`, `SieTextField`, `SieCard`, scroll/list/dialog/menu/dropdown/slider/tab)
- Lifecycle, accessibility, graceful degradation; immutable `SieIntegrationState`
- Syncs Orchestrator / Arbitration / Intent / SIDF via DI — apps never call Camera/Vision/Gesture
- Riverpod for availability / health / policy / route capability / status only (ADR-008)
- Unit/widget tests for registration, routes, security, adapters, degradation, isolation

## 0.14.0 — 2026-07-17

### Added
- **SIDF** (`sie_diagnostics`): Spatial Interaction Debug & Diagnostics Framework
- Passive observer for every SIE pipeline stage (overlay, skeleton, coordinates, cursor, timeline)
- Performance telemetry with rolling windows; pipeline health inspector
- Optional engineering recording (no raw camera frames) + JSON / CSV / health exports
- Feature flags (all off in release by default); structured logging without frame payloads
- Riverpod for framework enabled / overlay visibility / recording status only (ADR-008)
- Unit/widget tests for overlay lifecycle, metrics, timeline, exports, privacy, overhead

## 0.13.0 — 2026-07-17

### Added
- **Interaction Orchestrator** (`sie_orchestrator`): single gateway from IAE → SkillForge AI
- Lifecycle, route/security, focus, modal, accessibility, and feature-availability coordination
- Gated ordered dispatch of SIE pointer events via `InteractionDispatchPort` (traditional OS input unchanged)
- Graceful degradation when camera/SIE unavailable; immutable `SieOrchestrationSnapshot`
- Riverpod for availability / mode / lifecycle / health only (ADR-008)
- Unit tests for lifecycle, gating, dispatch ordering, modal, recovery, determinism

## 0.12.0 — 2026-07-17

### Added
- **Input Arbitration Engine** (`sie_arbitration`): sole authority for multi-modal input ownership
- Version 1 sources: Mouse, Touch, Keyboard, SIE; future modality interfaces only
- Policies: last-active-wins, locked, manual override, accessibility priority, application/route
- ADR-019 traditional input supremacy on simultaneous conflicts; route presets (auth/payment restrict SIE)
- Immutable `SieArbitrationSnapshot` with `forwardsSiePointers` gate; Riverpod for owner/policy/health only
- Unit tests for ownership, conflicts, LostTracking, route restrictions, policies, determinism

## 0.11.0 — 2026-07-17

### Added
- **Flutter Pointer Bridge** (`sie_pointer`): sole gateway from Virtual Cursor + Intents → Flutter-compatible pointer events
- Deterministic pointer lifecycle (added / hover / move / down / up / scroll / cancel / removed)
- LostTracking cleanup (cancel ≠ confirm), pointer recreation, scroll/drag/select translation
- `PointerInjectionPort` + `SieFlutterPointerEventMapper` / optional `GestureBindingPointerInjector`
- Immutable `SiePointerEvent` / `SiePointerBridgeSnapshot`; Riverpod for availability / lifecycle / health only (ADR-008)
- Unit tests for lifecycle, hover, press/release, drag, scroll, LostTracking, mapper, determinism

## 0.10.0 — 2026-07-17

### Added
- **Virtual Cursor Engine** (`sie_cursor`): canonical cursor model from Intent Engine snapshots
- Motion filtering (adaptive EMA, jitter/spike suppression), capped prediction, soft acceleration
- Optional magnetic snap with hysteresis; screen clamp + edge resistance
- IDS-aligned cursor states, visibility/fade, themes (appearance-only), reduced-motion animations
- Immutable `SieCursorSnapshot`; Riverpod for availability / state / theme / health only (ADR-008)
- Unit tests for smoothing, prediction disable, snap, clamp, LostTracking, recovering, determinism

## 0.9.0 — 2026-07-17

### Added
- **Intent Engine** (`sie_intent`): gesture events → official Version 1 interaction intents
- Immutable `SieIntentEvent` / `SieIntentFrameSnapshot` (sole semantics authority for Cursor / Pointer Bridge)
- Route capability policies, IDS security L0–L4, intent policies (standard / accessibility / restricted / debug)
- Deterministic select/drag FSM, conflict resolution, future intents interface-only (not activated)
- Riverpod for availability / interaction mode / policy / health only (ADR-008)
- Unit tests for intents, security/route gates, recovering suppress, drag threshold, determinism

## 0.8.0 — 2026-07-17

### Added
- **Gesture Engine** (`sie_gesture`): IDS G01–G09 vocabulary recognition
- Pinch family FSM (Arm → Commit → Hold → Release), FistCancel, ScrollIntent, OpenHandPoint
- Feature-flagged SwipeNavigation; accessibility DwellSelect
- Conflict resolution per IDS priorities; immutable `SieGestureEvent`
- Riverpod for availability / activity / policy / health only (ADR-008)
- Unit tests for arming, commit, hold, release, cancel, scroll, dwell, conflicts, recovery suppress

## 0.7.0 — 2026-07-17

### Added
- **Confidence Engine** (`sie_confidence`): fusion, temporal stability, hysteresis, tracking reliability
- IDS states: Disabled / Idle / Tracking / Stable / Degraded / LostTracking / Recovering / Error
- Immutable `SieConfidenceFrameSnapshot` with `mayConsume`, `gestureReady`, recovery grace (ADR-015/016)
- Policies: standard / precision / accessibility / debug (thresholds only)
- Riverpod for availability / tracking state / policy / health only (ADR-008)
- Unit tests for hysteresis, loss/recovery, fusion, noise, performance

## 0.6.0 — 2026-07-17

### Added
- **Calibration Engine** (`sie_calibration`): user / camera / display / handedness / interaction-zone / sensitivity
- Immutable `SieCalibratedFrameSnapshot` with original + calibrated coordinates
- Versioned profile persistence (`CalibrationStorePort`), migrator, guided sessions
- Soft recalibration recommendations (never silent mutation during interaction)
- Riverpod for availability / profile / health only (ADR-008)
- Unit tests for persistence, migration, profiles, handedness, resize, performance

## 0.5.0 — 2026-07-17

### Added
- **Spatial Coordinate Engine** (`sie_spatial`): Camera → Normalized → Viewport → Screen → Flutter logical
- Immutable `SieSpatialFrameSnapshot` / `SieSpatialHandSnapshot` / `SieSpatialLandmark`
- Mirror policy, orientation, contain/cover fit, safe margins, clamping
- Riverpod for availability / viewport / orientation / health only (ADR-008)
- Unit tests for mapping stages, mirror, orientation, aspect ratio, DPI, bounds

## 0.4.0 — 2026-07-17

### Added
- **Landmark Engine** (`sie_landmarks`): validate, normalize, stabilize Vision output
- Immutable `SieLandmarkFrameSnapshot` / `SieHandLandmarkSnapshot`
- EMA temporal stabilizer (configurable alpha), integrity validator, unit-square normalizer
- Riverpod for engine availability/status only (ADR-008)
- Unit tests for NaN/Inf/count/collapse/timestamp preservation/stabilization

## 0.3.0 — 2026-07-17

### Added
- **Vision Provider** (`sie_vision`): MediaPipe Hand Landmarker behind ports
- `VisionRuntimePort` + `HandLandmarkerBackendPort` (Web JS Tasks, Android JNI, Mock)
- Opaque `SieVisionResult` stream with inference back-pressure (not Riverpod — ADR-008)
- Tracking states: searching / tracking / recovering / lost
- Web bridge: `web/sie_hand_landmarker_bridge.js`
- Unit tests for mock provider, multi-hand, failures, back-pressure

## 0.2.0 — 2026-07-17

### Added
- **Camera Engine** (`sie_camera`): discovery, selection, lifecycle, streaming, recovery
- `CameraPort` + `CameraPlatformAdapterPort` (Web/Android Flutter adapter; unsupported stub for desktop)
- Opaque `SieCameraFrame` stream with back-pressure (not Riverpod — ADR-008)
- Riverpod providers for camera status / selection / config only
- Fake adapter + unit tests for lifecycle and permission failures

## 0.1.0 — 2026-07-17

### Added
- Platform Capability Layer (`sie_platform` + `sie_config` + `sie_core` foundations)
- Platform detection, capability probe, camera permission manager, feature flags
- Immutable platform profiles (Web/Android P0; Windows/desktop fail-soft)
- Riverpod providers for capability / permission / config (ADR-008 compliant)
- Unit tests for detection, evaluation, permissions, flags, providers
