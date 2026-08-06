# Spatial Interaction Engine — Project Preparation & Dependency Audit

| Field | Value |
|-------|-------|
| **Document** | 06 — Project Preparation & Dependency Audit (Stage 2 — Prompt 05) |
| **Component** | SkillForge AI — Spatial Interaction Engine (SIE) |
| **Version** | 1.0 (Audit) |
| **Status** | Living readiness record — **does not modify** frozen Design Docs 01–05 |
| **Created** | 2026-07-17 |
| **Last Updated** | 2026-07-17 |
| **Authors** | SkillForge AI Architecture / Platform / CV / Build Engineering |
| **Scope** | Pre-implementation readiness only — **no production feature code** |

---

## Purpose

Determine whether SkillForge AI is technically prepared to begin Stage 2 SIE implementation. Identify dependencies, compatibility gaps, integration risks, and engineering decisions that must be finalized before writing production features.

**Frozen source of truth (do not redesign):** Documents 01–05 (Research, System Architecture, IDS, Implementation Architecture, ADRs). Improvements discovered here are recorded only under [Future Version 1.1 Suggestions](#12-future-version-11-suggestions).

---

## Executive Verdict (Preview)

| Item | Result |
|------|--------|
| Design / architecture freeze | **Ready** |
| Host app Flutter/Dart environment | **Ready** |
| Concrete package selections | **Needs Decision** |
| Windows continuous frame streaming | **Blocked** (known plugin gap) |
| Multi-platform vision provider strategy | **Needs Decision** |
| Overall recommendation | **NO-GO** for unrestricted Stage 2 feature implementation |

**Interpretation:** Architecture is approved. The repository and SDK are healthy enough to start **controlled scaffolding and platform spikes** after closing the decisions in Section 10. Full multi-platform production implementation must not begin until the blockers below are resolved or explicitly de-scoped.

---

## Evidence Baseline (This Repository)

Audited on **2026-07-17** against the SkillForge host project.

| Evidence | Observed |
|----------|----------|
| Flutter SDK (local) | **3.44.4** stable (Engine a10d8ac38d, 2026-06) |
| Dart SDK (local) | **3.12.2** (DevTools 2.57.0) |
| `pubspec.yaml` SDK constraint | `sdk: ^3.11.5` |
| State / routing | `flutter_riverpod: ^3.3.1`, `go_router: ^17.2.3` |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore` present |
| Camera / vision / ML packages | **None** (no `camera`, MediaPipe, TFLite, OpenCV) |
| Related existing package | `image_picker: ^1.2.1` only (unsuitable for continuous SIE stream) |
| Logging / math / diagnostics packages | **None** dedicated |
| `/packages/skillforge_sie` | **Does not exist yet** (expected pre-implementation) |
| Analysis | `flutter_lints: ^6.0.0` via default `analysis_options.yaml` |
| CI workflows | **Not present** in repo (no `.github` CI detected) |

---

## Table of Contents

1. [Flutter Environment Audit](#1-flutter-environment-audit)
2. [Package Evaluation](#2-package-evaluation)
3. [Platform Compatibility Matrix](#3-platform-compatibility-matrix)
4. [Performance Budget](#4-performance-budget)
5. [Dependency Risks](#5-dependency-risks)
6. [Integration Audit](#6-integration-audit)
7. [Development Tooling](#7-development-tooling)
8. [Security Audit](#8-security-audit)
9. [Implementation Order](#9-implementation-order)
10. [Readiness Checklist](#10-readiness-checklist)
11. [Go / No-Go Decision](#11-go--no-go-decision)
12. [Future Version 1.1 Suggestions](#12-future-version-11-suggestions)
13. [Revision History](#13-revision-history)

---

## 1. Flutter Environment Audit

### 1.1 Flutter SDK compatibility

| Aspect | Assessment |
|--------|------------|
| Current stable in use | Flutter **3.44.4** — suitable for enterprise multi-platform work |
| Impeller / Skia | Desktop and mobile on current stable use modern rendering; Impeller maturity on iOS/Android is acceptable for overlay cursor work |
| Multi-view / web | Flutter Web remains a first-class SkillForge surface; CanvasKit/Skwasm choice affects frame cost of overlays |
| Package ecosystem lag | New Flutter majors occasionally break plugins; pin a **team-wide minimum** and bump intentionally |

**Recommendation — minimum Flutter:** **3.32.0** (floor for recent `camera_*` / Firebase stack compatibility); **target / CI pin:** **3.44.x stable** (current verified workstation).

**Justification:** Host already runs 3.44.4. Flooring too aggressively (e.g. 3.16) invites incompatible transitive plugins. Pinning CI to the same minor as developers reduces “works on my machine” for camera/FFI.

### 1.2 Dart SDK compatibility

| Aspect | Assessment |
|--------|------------|
| Constraint | `^3.11.5` |
| Runtime | 3.12.2 |
| Language features | Records, sealed classes, patterns — useful for SIE DTOs/FSMs per Document 04 |

**Recommendation — minimum Dart:** **3.11.5** (match pubspec); **preferred:** **3.12.x** with Flutter 3.44.

**Justification:** Aligns with existing constraint; avoids forcing a host SDK bump solely for SIE.

### 1.3 Rendering backend considerations

| Surface | Notes for SIE |
|---------|----------------|
| Mobile / desktop | Overlay cursor + hit-test visualization must stay on UI isolate; avoid per-frame full-tree rebuilds (ADR-008) |
| Web | Overlay cost + JS vision interop; prefer lightweight custom paint over heavy widget trees at vision rate |
| Texture / PlatformView | Camera preview may use texture; pointer bridge must not depend on preview visibility (preview optional / privacy-minimized) |

### 1.4 Desktop support maturity

Desktop Flutter is production-capable for SkillForge dashboards. **Camera + continuous image streaming** is the immature seam—not Flutter UI itself. Windows official `camera_windows` historically lacks reliable `startImageStream` parity with Android/iOS. Community `camera_desktop` documents **image streaming: No on Windows**. This is the primary platform engineering risk for Approach A on Windows.

### 1.5 Flutter Web limitations

- Camera via `getUserMedia` + `camera_web` (browser permission UX differs from OS).
- MediaPipe Tasks Vision is mature on **Web/JS**; Flutter must bridge via JS interop / worker (main-thread inference blocks UI — Document 04 requires off-UI work).
- No true background camera when tab hidden; must pause session (aligns with IDS privacy).
- WASM / COOP-COEP / SharedArrayBuffer constraints may affect advanced workers depending on hosting headers.

### 1.6 Platform channel / FFI requirements

Document 04 expects replaceable vision providers. Anticipate:

| Mechanism | Use |
|-----------|-----|
| Dart FFI / JNI / native libs | Android (and later desktop) MediaPipe / TFLite |
| Method channels | Permissions, capability probes, privacy indicators |
| JS interop | Web MediaPipe Tasks |
| Isolates | Dart-side smoothing / coordinate math (not heavy CV if native owns inference) |

### 1.7 Build system compatibility

| Platform | Notes |
|----------|-------|
| Android | Gradle + NDK if native MediaPipe/TFLite; watch minSdk vs camera/ML |
| Windows | CMake / Visual Studio for any custom capture/vision native code |
| Web | Asset bundling for `.task` / WASM models; CDN vs local model policy |
| Host monorepo | Melos or path dependency for `/packages/skillforge_sie` — **decision needed** (tooling Section 7) |

---

## 2. Package Evaluation

> Rule: evaluate multiple candidates; recommend one mature path for Version 1. Selections below are **recommendations for decision**, not code additions.

### 2.1 Camera

| Candidate | Reliability | Desktop | Web | Performance | Maintenance | Adoption |
|-----------|-------------|---------|-----|-------------|-------------|----------|
| **`camera` (official)** | High on Android/iOS; preview solid | Weak without add-ons; Windows streaming gap | Yes (`camera_web`) | Good when streaming works | flutter.dev | Highest |
| **`camera` + `camera_windows`** | Preview OK; **streaming incomplete / unreliable** | Windows only add-on | N/A | Streaming blocked for CV | Official but incomplete | Moderate |
| **`camera` + `camera_desktop`** | Good preview; **Windows image streaming = No** (package docs) | Win/macOS/Linux unified | N/A | macOS/Linux stream possible; Win no | Community | Growing |
| **`image_picker` (existing)** | Fine for photos | OK | OK | N/A for SIE | Official | High — **wrong tool** |
| **Custom platform capture** | Highest control | Can fix Windows | Separate | Best if done well | Team-owned cost | N/A |

**Recommendation (v1):**

1. **Facade port** as designed (`sie_camera`) — never call plugins from interaction engines.  
2. **Default plugins:** `camera` for Android + Web; evaluate `camera_desktop` for macOS/Linux streaming.  
3. **Windows:** do **not** assume `camera` / `camera_windows` / `camera_desktop` provide SIE-grade frame streaming today. Treat Windows as requiring either:
   - a **spike-proven** custom Media Foundation (or equivalent) frame source behind the same port, **or**
   - **explicit de-scope** of Windows SIE until streaming exists.

**Why:** Official `camera` is the only maintainable baseline for Android/Web. Desktop packaging is fragmented; Windows streaming is an evidence-backed gap, not a rumor. Betting Stage 2 on undocumented streaming will create false progress.

### 2.2 Hand tracking

| Technology | Fit for SIE v1 | Pros | Cons |
|------------|----------------|------|------|
| **MediaPipe Hand Landmarker (Tasks)** | **Best conceptual fit** | 21 landmarks, VIDEO mode, Google-maintained models, Web JS path exists | No single official Flutter multi-platform package |
| **`hand_landmarker` (pub)** | Android spike only | JNI MediaPipe, background thread, bundled model | **Android-only** — not a multi-platform strategy |
| **`hand_detection` (TFLite MediaPipe models)** | Strong cross-native candidate | Claims Android/iOS/macOS/Windows/Linux; local; 21 pts | Community package; Windows still needs camera stream; Web path different; must validate FPS/quality |
| **Raw TensorFlow Lite custom** | Heavy | Full control | Model + postprocess ownership cost too high for v1 |
| **OpenCV pipelines** | Poor primary | Classic CV | Brittle under lighting; not landmark-quality HCI |
| **Custom ML from scratch** | Reject for v1 | — | Research project, not product |

**Recommendation (v1):**

- **Architecture:** MediaPipe-class **Hand Landmarker** behind `VisionProvider` port (Documents 01–04).  
- **Implementation strategy (multi-adapter, not one plugin):**
  - **Web:** `@mediapipe/tasks-vision` Hand Landmarker via JS interop + worker.  
  - **Android:** MediaPipe Tasks native (`hand_landmarker` or first-party JNI) after spike.  
  - **Desktop (macOS/Linux/Windows):** Spike `hand_detection` **and/or** native MediaPipe C++ **only after** camera frame source is proven.  
- **Reject as sole v1 path:** OpenCV-only; cloud vision; custom trained models.

**Why:** Feasibility (Doc 01) already selected MediaPipe-class landmarks. Ecosystem reality in mid-2026 still requires **platform adapters**, which matches Document 04 plugin architecture. Choosing one pub package as “the” solution would violate frozen replaceability and fail Web or Windows.

### 2.3 State management (Riverpod)

| Question | Verdict |
|----------|---------|
| Is existing Riverpod sufficient? | **Yes** for host session/config/health |
| Per-frame landmarks in Riverpod? | **Forbidden** (ADR-008) — remains valid |
| Gesture FSM / cursor / pointer bridge | **Outside** Riverpod — streams/controllers inside `skillforge_sie` |
| GoRouter security levels L0–L4 | Riverpod/router **policy inputs**; evaluation inside `sie_security` |

**Belongs in Riverpod (host):**

- SIE enabled / session phase (coarse)  
- Permission / capability summary  
- Active calibration profile id  
- Diagnostics toggles (dev)  
- Route security level mapping inputs  

**Must stay outside Riverpod:**

- Camera frames, landmarks, filters, gesture hypotheses at 15–30 Hz  
- Cursor continuous position  
- Pointer FSM micro-states  

**Validation:** Frozen ADR-008 and Document 02 session vs realtime split remain correct. No change for v1.0.

### 2.4 Mathematical utilities

| Need | Candidates | Recommendation |
|------|------------|----------------|
| Vectors / matrices | `vector_math` (Flutter transitive / explicit), hand-rolled | **`vector_math`** — mature, used by Flutter engine ecosystem |
| Interpolation / smoothing | Custom EMA/One-Euro in `sie_landmarks` / cursor | **In-package algorithms**; optional tiny helpers only |
| Coordinate conversion | Domain code in Spatial Coordinate Engine | **No extra package** |
| Geometry (pinch distance) | `vector_math` + domain | Prefer domain clarity over heavy CAS libs |

**Do not add:** `ml_linalg`, Eigen bindings, or game-engine stacks unless a spike proves need.

### 2.5 Logging

| Approach | Pros | Cons |
|----------|------|------|
| `dart:developer` `log` | Zero dep, zone-friendly | Unstructured across team |
| `logging` package | Standard levels, hierarchical loggers | Less “structured fields” by default |
| `logger` package | Pretty console | Weaker for production sinks |
| Custom `SieLog` façade → host sink | Matches Doc 04 analytics boundary | Small team code |

**Recommendation:** Thin **`SieLogger` port** in package + host adapter. Prefer **`logging`** (or `dart:developer` + structured JSON fields) with levels: error/warn/info/fine. **Never log images, frames, or landmark dumps in production.** Dev-only landmark sampling behind diagnostics flag.

### 2.6 Diagnostics

| Need | Recommendation |
|------|----------------|
| FPS / infer ms / drops | In-package counters (`sie_diagnostics`) per Document 04 |
| Frame timing | `SchedulerBinding` / `FrameTiming` for UI FPS; vision clock separate |
| Profiling | Flutter DevTools CPU/memory; timeline events via `Timeline` / `dart:developer` |
| Debug overlays | `sie_devtools` only; off in release by default |
| Performance overlay | Flutter built-in for UI; do not confuse with vision FPS |

---

## 3. Platform Compatibility Matrix

| Topic | Flutter Web | Windows | Android | Linux | macOS |
|-------|-------------|---------|---------|-------|-------|
| **Camera support** | `getUserMedia` via `camera_web`; good for demos | Preview possible; **continuous streaming not production-ready via standard plugins** | Strong (`camera` + CameraX path) | Possible via `camera_desktop` + V4L2 | Possible via `camera_desktop` / AVFoundation |
| **Permission model** | Browser prompt; sticky deny; secure context (HTTPS/localhost) | OS privacy settings + app manifest capabilities | Runtime CAMERA permission | Portal / device nodes vary by distro | TCC camera privacy |
| **Expected performance** | 15–30 vision FPS mid-tier; UI 60 if worker used | Potentially excellent CPU if native path exists; **blocked until frames** | 20–30 vision FPS mid-tier phones | Highly hardware-dependent | Good on Apple Silicon |
| **Known limitations** | Tab freeze/pause; main-thread JS risk; CORS/model load | Streaming gap; thermal less issue than mobile | Thermal/battery; orientation EXIF | Driver chaos; CI hardware rare | Notarization / entitlement for camera |
| **Missing APIs** | Background camera; OS cursor control (out of scope) | Reliable `onStreamedFrameAvailable` | — | Consistent sandbox camera | — |
| **Platform risks** | Autoplay/permission UX; Safari variance | False assumption that `camera` works like Android | OEM camera quirks | Lab-only support risk | Entitlements misconfig |
| **Recommended strategy** | **Primary early spike + demo platform** with MediaPipe Tasks JS | **Spike custom frame source or de-scope v1** | **Primary mobile production path** | Best-effort after macOS | Secondary desktop after Android/Web |

### Per-platform strategy notes

**Web — implement early.** Aligns with MediaPipe official web guide; proves Approach A end-to-end without waiting on Windows capture.

**Android — implement as first “native” production path.** Closest to maintainable MediaPipe packaging (`hand_landmarker` or equivalent).

**Windows — do not schedule full Gesture→Pointer stack until frame source spike passes.** Architecture ports can be written; vision adapter remains stub/fail-soft (`unsupported` capability).

**macOS / Linux — follow desktop camera streaming proof;** lower product priority than Web + Android unless desktop labs demand it.

**iPadOS (future):** Out of v1 commitment; expect `camera` + Apple permissions; track separately.

---

## 4. Performance Budget

Targets align with Document 02 performance architecture and IDS responsiveness. Justifications assume mid-tier 2024–2026 laptops/phones and optional mode (not always-on).

| Budget | Target (v1) | Justification |
|--------|-------------|----------------|
| Camera capture clock | **30 FPS** preferred; **15 FPS** minimum usable | Landmark models expect video cadence; 15 FPS still usable with smoothing |
| Vision inference clock | **15–30 FPS** sustained; drop frames rather than queue-build | Bounded queues (Doc 02); latency over backlog |
| UI / overlay FPS | **60 FPS** desktop aspirational; **≥30 FPS** minimum under load | Cursor must feel attached; UI isolate free of inference |
| End-to-end motion-to-cursor latency | **≤80 ms** p50; **≤120 ms** p95 (device-dependent) | HCI research: >100–150 ms feels laggy for pointing |
| Pinch→Select latency | **≤50 ms** after gesture confirm thresholds met | Click must feel intentional, not sluggish after hysteresis |
| Memory (SIE session active) | **≤150 MB** incremental budget on mobile; **≤250 MB** desktop (model + buffers) | Coexist with Firebase-heavy host |
| CPU (SIE active) | **≤30%** one big core average on mid laptop; peak spikes OK | Optional mode must not cook devices |
| Battery (mobile) | Session auto-pause background; warn on long continuous use (>15–20 min) | Continuous camera + NN is expensive |
| Thermal | Adaptive resolution / FPS ladder when infer ms rises | Prevents runaway throttle |
| Background | **Camera off, session Paused/Off** | IDS + OS policy; no silent capture |
| Queue depth | **1–2** frames max coalesce | Prevents latency wind-up |

**Non-goals for v1:** matching mouse 1000 Hz polling; perfect 60 FPS vision on low-end Android.

---

## 5. Dependency Risks

| Risk | Likelihood | Impact | Mitigation | Fallback |
|------|------------|--------|------------|----------|
| Package abandonment (`hand_detection`, `camera_desktop`) | Medium | High | Ports + thin adapters; vendor behind interface | Swap adapter; keep domain |
| Breaking MediaPipe Tasks API | Medium | Medium | Pin model + Tasks version; golden landmark fixtures | Rebuild adapter only |
| Platform camera inconsistency | **High** | **Critical** | Capability matrix at runtime; fail-soft UX | Disable SIE per platform |
| Browser `getUserMedia` restrictions | Medium | High | Clear UX; HTTPS; permission recovery flow | Mouse/touch only |
| Permission denial / sticky deny | High | Medium | IDS copy + settings deep-link where possible | Non-SIE product remains full |
| Gradle/NDK/FFI build conflicts with Firebase | Medium | High | Spike Android release + debug builds early | Delay Android SIE; keep Web |
| Performance bottlenecks (main-thread JS / Dart) | High | High | Workers/isolates; frame drop; resolution ladder | Lower FPS mode / disable |
| Hardware variation (webcams, IR, dual cams) | High | Medium | Front-camera preference; calibration; confidence engine | Unsupported device state |
| Flutter stable upgrades break plugins | Medium | Medium | CI pin Flutter; scheduled upgrades | Hold pin until adapters green |
| Windows streaming never lands upstream | Medium | Critical for Win SKU | Custom capture spike in roadmap | Ship Web+Android first |
| Model binary size / license | Low–Med | Medium | Asset audit; license review before ship | Smaller model / fewer platforms |
| Accidental Firebase coupling in package | Medium | High | Package dependency ban (Doc 04) + CI grep | Refactor host adapters |

---

## 6. Integration Audit

| Integration point | Risk | Assessment |
|-------------------|------|------------|
| **Riverpod** | Perf regression if misused | Safe if only coarse session; enforce code review rule “no landmarks in providers” |
| **GoRouter** | Security level maps stale | Need single source for L0–L4 route classification; avoid scattering string checks |
| **Firebase Auth** | None direct in SIE package | Host passes auth-gated route policy; SIE must not read Firebase |
| **Firestore / Storage** | Temptation to store clips | **Forbidden** by IDS; calibration prefs only via host storage port if needed |
| **Dashboards** | Overlay hit-testing vs dense UI | Large touch targets; avoid relying on tiny icon-only controls for SIE-primary paths |
| **Shared widgets** | Accidental SIE imports in domain widgets | Widgets consume intents/focus; never MediaPipe |
| **Theme engine** | Cursor contrast | Cursor/hover rings must meet contrast in light/dark themes |
| **Role-based architecture** | Admin destroy / payments | L3/L4 **no gesture confirm** (IDS) — host must tag routes before enable |
| **PayFast / commerce** | Critical money flows | Keep traditional input only for confirm; SIE navigation at most if ever allowed by policy |
| **Existing `image_picker`** | Confusion | Do not reuse for SIE stream; separate permission messaging |

**Possible issues before implementation:**

1. No central **route security registry** yet for L0–L4.  
2. No host **Labs / settings** entry point reserved (product decision).  
3. App may run heavily on **Web** today — good for spike, bad if team assumes Windows desktop parity.  
4. Absence of monorepo package tooling may slow `/packages/skillforge_sie` adoption.

---

## 7. Development Tooling

> Recommend only — **do not configure in this audit.**

| Area | Recommendation |
|------|----------------|
| Lint rules | Keep `flutter_lints`; add package-local stricter rules: `avoid_print`, `unawaited_futures`, `cancel_subscriptions`, public API docs on `sie_*` façades |
| Static analysis | `flutter analyze` on host + package in CI; optionally `dart_code_metrics` / custom lint forbidding `firebase_*` imports under package domain |
| Formatting | `dart format` mandatory; CI fail on drift |
| Documentation | Dartdoc on public ports; keep frozen docs authoritative for behaviour |
| Architecture validation | Dependency smoke tests / import rules; “no Riverpod in vision modules” |
| Dependency auditing | `dart pub outdated`; periodic license review for native models; pin MediaPipe Tasks |
| CI | Matrix: analyze + unit tests (no camera); optional integration job with recorded fixtures; Flutter version pin |
| Code review checklist | IDS sequences touched? security gate? loss≠confirm? no frame logging? platform capability checked? perf budget considered? tests for FSM? |

---

## 8. Security Audit (IDS Alignment)

| Control | IDS expectation | Readiness |
|---------|-----------------|-----------|
| Camera permissions | Explicit opt-in | **Needs Decision** on UX copy ownership (host vs package) |
| Permission denial | Fail-open product; SIE unavailable | Design ready; implementation not started |
| Privacy indicators | Persistent while camera active | Design ready |
| Sensitive screens L3/L4 | No gesture confirmation | Design ready; **route registry missing** |
| Auth routes | Traditional input for secrets | Aligns; mark routes L3+ |
| Data protection | No raw video analytics | Aligns; enforce in logging guidelines |
| Local processing | On-device v1 expectation | Aligns with MediaPipe/TFLite choice |
| No video storage | Mandatory | Aligns; forbid Storage uploads of frames |
| Compliance | Disclose processing; kill switch | Needs legal/privacy review of final copy |

**Conclusion:** Security **design** is ready; security **engineering prerequisites** (route policy registry, privacy strings, permission UX owner) are **Needs Decision**, not Blocked by missing crypto.

---

## 9. Implementation Order

Dependency-safe sequence (Document 04 modules). Do not reorder casually.

| Order | Work item | Why this order |
|-------|-----------|----------------|
| 0 | **Decisions closed** (Section 10 blockers) | Avoid building on sand |
| 1 | **Platform Layer** (`sie_platform` capability probe) | Everything gates on capabilities |
| 2 | **Package skeleton** `/packages/skillforge_sie` + ports only | Boundary before features |
| 3 | **Camera Engine** + proven frame source per launch platform | No vision without frames |
| 4 | **Vision Provider** adapter (Web and/or Android first) | Landmarks feed all upper engines |
| 5 | **Landmark Engine** (normalize, mirror, filter) | Stable schema for tests |
| 6 | **Spatial Coordinate Engine** | Screen mapping depends on landmarks + calibration |
| 7 | **Calibration Engine** | Unlocks accurate pointing |
| 8 | **Confidence Engine** | Gates gestures before intent |
| 9 | **Gesture Engine** | Pinch vocabulary etc. |
| 10 | **Intent Engine** | Security-aware intent emission |
| 11 | **Cursor Engine** | Approach A visual pointing |
| 12 | **Flutter Pointer Bridge** | Delivers synthetic pointer to Flutter |
| 13 | **Hover Engine** | Built on bridge + dwell rules |
| 14 | **Click Engine** | After hover; IDS confirm rules |
| 15 | **Drag Engine** | Depends on click/hold semantics |
| 16 | **Scroll Engine** | Separate axis mapping; after click stability |
| 17 | **Diagnostics** | Instrument once pipeline exists |
| 18 | **Developer Tools** | Overlays on real metrics |
| 19 | **Accessibility** | Modes after core intents stable |
| 20 | **Optimization** | Resolution/FPS ladder with measurements |
| 21 | **Testing** (expand continuously; fixture replay from Landmark Engine onward) | Pure tests early; hardware late |

**Justification:** Lower layers produce contracts upper layers consume. Interaction before camera creates untestable mocks-as-product. Windows-specific native capture inserts at step 3 for that platform only.

---

## 10. Readiness Checklist

| # | Item | Status |
|---|------|--------|
| 1 | Flutter version confirmed (3.44.x class / ≥3.32 floor) | **Ready** |
| 2 | Dart SDK constraint compatible (`^3.11.5`) | **Ready** |
| 3 | Frozen docs 01–05 approved as v1.0 | **Ready** |
| 4 | Approach A / optional mode / L3–L4 rules understood | **Ready** |
| 5 | Camera package strategy approved | **Needs Decision** |
| 6 | Windows frame-streaming approach approved or Windows de-scoped | **Blocked** |
| 7 | Vision provider per-platform adapters chosen | **Needs Decision** |
| 8 | Launch platform order approved (recommended: Web → Android → desktop) | **Needs Decision** |
| 9 | Riverpod vs realtime boundary accepted (ADR-008) | **Ready** |
| 10 | Math/logging/diagnostics dependency set approved | **Needs Decision** |
| 11 | Performance targets approved by eng leads | **Needs Decision** |
| 12 | Security / privacy copy + route L0–L4 registry owner | **Needs Decision** |
| 13 | `/packages/skillforge_sie` path + monorepo wiring approach | **Needs Decision** |
| 14 | Architecture validated against host (no Firebase in domain) | **Ready** (design) |
| 15 | Testing strategy defined (Doc 04) | **Ready** (design) |
| 16 | CI Flutter pin + analyze plan | **Needs Decision** |
| 17 | Dependency risks accepted by tech lead | **Needs Decision** |
| 18 | Legal/privacy review of camera disclosure | **Needs Decision** |
| 19 | Hardware lab devices identified (Win / Android / mac) | **Needs Decision** |
| 20 | Stage 2 implementation kickoff authorized | **Blocked** (pending above) |

---

## 11. Go / No-Go Decision

### Scores (/10)

| Dimension | Score | Notes |
|-----------|------:|-------|
| **Architecture readiness** | **9** | Docs 01–05 frozen; ports and ADRs clear |
| **Platform readiness** | **4** | Web/Android promising; Windows streaming blocked |
| **Dependency readiness** | **3** | No camera/vision deps selected or spiked |
| **Security readiness** | **7** | IDS solid; host policy registry missing |
| **Performance readiness** | **6** | Budgets proposed; not measured on device |
| **Maintainability readiness** | **8** | Package boundary well specified |
| **Overall readiness** | **5.5 / 10** | Design-ready, engineering-not-ready |

### Technical debt assessment (pre-SIE)

- Host is a large Firebase app without package workspace yet — adding SIE as a path package is manageable but new process debt.  
- No CI — regressions in adapters will be costly without early pipelines.  
- Relying on `image_picker` mental model for camera would create UX/permission debt if confused with SIE.

### Remaining unknowns

1. Exact Windows capture technology and effort (person-weeks).  
2. Whether `hand_detection` meets FPS/quality bars on target hardware.  
3. Web worker + Flutter interop latency on production hosting.  
4. Binary size impact of bundling Hand Landmarker assets per platform.  
5. Which SkillForge surfaces are in v1 Labs vs production roles.

### Final recommendation

# NO-GO

**Why:** Stage 2 **production feature implementation** is not authorized while (a) camera/vision packages are unchosen, (b) Windows continuous frame acquisition is unresolved or undeclared out of scope, and (c) launch platform order + performance/security owners are unapproved.

**What is allowed under NO-GO (optional, still no production features):**

- Close Section 10 decisions in a short architecture council.  
- Time-boxed **spikes** (throwaway or behind ports): Web MediaPipe Tasks; Android `camera` + landmarker; Windows capture feasibility.  
- Create empty package skeleton **only after** launch platform order is approved.

**Flip to GO when:**

1. Launch platforms for v1 are written down (recommended: **Web + Android**, desktop best-effort).  
2. Windows is either **de-scoped** or has a **spike report** proving ≥15 FPS frames into Dart/native vision.  
3. Named package choices for camera + vision adapters are recorded (can live as ADR addendum / decision log without rewriting Docs 01–05).  
4. Performance budgets and L0–L4 route registry ownership accepted.

---

## 12. Future Version 1.1 Suggestions

> Not part of frozen v1.0 design. Do not implement as silent redesign.

1. Official Flutter-endorsed desktop camera streaming would simplify Windows/macOS/Linux adapters.  
2. First-party SkillForge-maintained MediaPipe Tasks bindings (all desktop) if community packages lag.  
3. SharedArrayBuffer / COOP-COEP hosting profile documented for Web workers.  
4. Melos (or equivalent) workspace standards for multiple `skillforge_*` packages.  
5. Formal privacy impact assessment template tied to SIE analytics events.  
6. iPadOS capability matrix when that SKU is scheduled.

---

## 13. Revision History

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-07-17 | Initial Stage 2 Prompt 05 readiness audit; **NO-GO** pending decisions |

---

## Cross References

- [01 Research & Feasibility](01_RESEARCH_AND_FEASIBILITY.md)  
- [02 System Architecture](02_SYSTEM_ARCHITECTURE.md)  
- [03 Interaction Design Specification](03_INTERACTION_DESIGN_SPECIFICATION.md)  
- [04 Implementation Architecture](04_IMPLEMENTATION_ARCHITECTURE.md)  
- [05 Architecture Decisions](05_ARCHITECTURE_DECISIONS.md)  
- [README](README.md)
