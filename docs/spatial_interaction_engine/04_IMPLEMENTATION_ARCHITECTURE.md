# Spatial Interaction Engine — Implementation Architecture Specification

| Field | Value |
|-------|-------|
| **Document** | 04 — Implementation Architecture Specification |
| **Component** | SkillForge AI — Spatial Interaction Engine (SIE) |
| **Version** | 1.0 |
| **Status** | **Frozen** (Planning Blueprint) |
| **Created** | 2026-07-17 |
| **Last Updated** | 2026-07-17 |
| **Authors** | SkillForge AI Architecture Team |

---

## Purpose

Define how SIE must be organized in the SkillForge repository for Clean Architecture, SOLID, testability, replaceable vision providers, and long-term maintenance—**without providing implementation code**.

This blueprint respects frozen Documents 01–03 exactly.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Package Strategy](#2-package-strategy)
3. [Module Organization](#3-module-organization)
4. [Dependency Graph](#4-dependency-graph)
5. [Clean Architecture Mapping](#5-clean-architecture-mapping)
6. [Public APIs](#6-public-apis)
7. [Internal APIs](#7-internal-apis)
8. [API Governance](#8-api-governance)
9. [Configuration Strategy](#9-configuration-strategy)
10. [Plugin Architecture](#10-plugin-architecture)
11. [Platform Abstraction](#11-platform-abstraction)
12. [Naming Conventions](#12-naming-conventions)
13. [Testing Strategy](#13-testing-strategy)
14. [Diagnostics Strategy](#14-diagnostics-strategy)
15. [Versioning](#15-versioning)
16. [Engineering Standards](#16-engineering-standards)
17. [Future Version 1.1 Suggestions](#17-future-version-11-suggestions)
18. [Cross References](#18-cross-references)
19. [Glossary](#19-glossary)
20. [References](#20-references)
21. [Revision History](#21-revision-history)

---

## 1. Executive Summary

SIE is implemented as an **independent Flutter package subsystem** hosted by SkillForge—not as domain logic inside Student/Teacher/Admin features.

**Baseline package:** `/packages/skillforge_sie`  
**App role:** thin Host / Labs / route-policy wiring only.  
**Optional later split:** `skillforge_sie_flutter` when overlay/binary-size churn warrants.

Business features depend on **stable session façade + intents**, never on landmarks or model vendors.

---

## 2. Package Strategy

| Option | Verdict |
|--------|---------|
| Only under `lib/features/sie` | Reject as sole strategy (coupling risk) |
| Standalone `/packages/skillforge_sie` | **Accept baseline** |
| Many micro-packages day one | Reject initially |
| Core + thin Flutter host package | Accept as evolution path |

**Rationale:** Enforces dependency inversion at repo boundaries; isolates tests; matches “independent subsystem” (Document 02).

---

## 3. Module Organization

| Module | Purpose | Stability |
|--------|---------|-----------|
| sie_core | DTOs, phases, intent lexicon | Stable |
| sie_config | Flags, thresholds, profiles | Stable keys |
| sie_session | Kernel / lifecycle | Stable façade |
| sie_camera | Camera engine + port | Port Stable |
| sie_vision | Vision runtime + port | Port Stable; impl Volatile |
| sie_landmarks | HandFrame normalization | Stable schema |
| sie_gesture | Hypotheses + classifier port | Stable kinds |
| sie_calibration | Calibration profiles | Versioned |
| sie_cursor | CursorState | Stable |
| sie_pointer | Pointer FSM | Stable phases |
| sie_interaction | Façade + Hover/Click/Drag/Scroll modules | Stable intents |
| sie_security | L0–L4 policy evaluation | Stable levels |
| sie_accessibility | A11y overlays | Stable modes |
| sie_diagnostics | Metrics/timelines | Versioned metrics |
| sie_analytics | Coarse events sink | Stable event names |
| sie_platform | Adapter implementations | Volatile |
| sie_flutter_host | Overlay + pointer bridge | Host API Stable |
| sie_devtools | Debug UI (non-release default) | Experimental |
| sie_testing | Fakes, replay fixtures | Tooling |

Hover/Click/Drag/Scroll remain **inside** `sie_interaction` (Document 02 consolidation).

### Forbidden dependencies (examples)

- Vision/landmarks → Flutter host, Firestore, GoRouter, payment/auth features.  
- Security module does not implement PayFast; it only answers policy questions.  
- App must not import package `src/` deep paths.

---

## 4. Dependency Graph

**Direction:** Host → Session / Interaction / Security / Config → Pointer → Cursor/Gesture → Landmarks → Vision → Camera → Core.

**Event flow:** Camera → Vision → Landmarks → (Gesture ∥ Cursor) → Pointer → Interaction → Intent Bus → Host → UI.

**Ownership:** Each DTO owned by its producing module (see Document 02 data ownership).

**Ports owned by consumer side** (Dependency Inversion): CameraPort, VisionRuntimePort, GestureClassifierPort, PointerInjectionPort, FeedbackPort, AnalyticsSinkPort, Security surface resolver (app-implemented).

No circular Host ↔ Vision dependencies.

---

## 5. Clean Architecture Mapping

| Layer | Modules |
|-------|---------|
| Domain | sie_core; pure security/gesture contracts |
| Application | sie_session, sie_pointer, sie_interaction orchestration |
| Infrastructure | vision/camera vendor impls, calibration persistence, analytics adapters |
| Platform | sie_platform (permissions, workers, display, timing) |
| Presentation | sie_flutter_host, sie_devtools |
| Cross-cutting | sie_config, sie_diagnostics, sie_analytics, sie_accessibility |

---

## 6. Public APIs

App-facing Stable surface:

- Session: start / stop / pause / resume  
- Session phase + health  
- Config overrides (a11y, sounds, reduced motion)  
- Host chrome + privacy indicator  
- Register route/surface security labels  
- Optional advanced intent subscription (most apps use Host bridge only)

---

## 7. Internal APIs

Package-private: vendor raw results, filter state, frame queues, hypothesis internals.

Extension points (Stable ports): VisionRuntime, GestureClassifier, Feedback, AnalyticsSink, Camera, Security surface resolver, Interaction modules (v2 zoom/rotate).

Experimental: SwipeNav, dual-hand preview, dev replay controllers.

---

## 8. API Governance

1. Public export barrel exports Stable only.  
2. Deep `src/` imports forbidden (lint).  
3. Intent lexicon changes require RFC; additive preferred.  
4. Changelog per release.  
5. Deprecation: keep ≥ 2 minors or 90 days before removal (major for Stable).  
6. Features requesting landmark access from app code are **rejected**.

---

## 9. Configuration Strategy

Domains: feature flags, environment profiles, platform capabilities, accessibility, security route maps, performance, developer mode, demo mode.

Lifecycle: package defaults → app profile at startup → runtime overlays (a11y/degraded) via immutable snapshot swap. Security map changes require explicit reload. `sie_config` is single writer of merged snapshots.

---

## 10. Plugin Architecture

Plugins register **explicitly** at host startup. Lifecycle: register → attach → onStart → onStop → detach. Failed plugins isolate; core continues if possible.

Plugins must emit IDS-compatible hypotheses/intents and cannot bypass L3/L4 security gates.

---

## 11. Platform Abstraction

Ports for: Camera, Vision, Pointer injection (Approach A in-app), Permissions, Capabilities, Display info, Clock/timing, Traditional input probe (conflict policy).

Domain/application remain platform-independent.

---

## 12. Naming Conventions

| Kind | Convention |
|------|------------|
| Package | `skillforge_sie` |
| Modules | `sie_<area>` |
| Ports | `XxxPort` |
| Intents / states | Document 03 lexicon |
| Config keys | `sie.` prefix |
| Docs | Cite IDS gesture IDs (G01…) in behavioural PRs |
| No vendor names in public API | Prefer VisionRuntimePort |

---

## 13. Testing Strategy

| Type | Focus |
|------|-------|
| Unit | Quality gates, hysteresis, FSM, security matrix |
| Golden interaction | IDS sequences with landmark fixtures |
| Integration | Session → intent → host sink with fakes |
| Simulation / replay | Landmark JSON corpora (never raw video) |
| Performance | Latency/FPS budgets on P0 devices |
| Platform | Permission deny, background pause |

CI must run pure domain/FSM tests without camera hardware.

---

## 14. Diagnostics Strategy

Structured logs (no images); event timelines; intent replay; landmark-only gesture replay; counters (FPS, infer ms, drops); debug overlays in devtools; health checks. Production: sampling on, overlays off; privacy chip whenever camera active.

---

## 15. Versioning

SemVer on `skillforge_sie`. Experimental channel may break; Stable host/session/intent APIs freeze at engine 1.0. Behaviour contradicting IDS requires major + documentation 1.1 process. App pins package versions deliberately.

---

## 16. Engineering Standards

SOLID; DRY thresholds in config; KISS vocabulary; composition over inheritance; interface-first ports; immutable DTOs across boundaries; event-driven intents; **no per-frame Riverpod**; no business logic in adapters; no UI in vision; no Firebase in package domain/application; traditional input supremacy; loss ≠ click; security gate before Select; fail-open for core product; privacy: no raw video analytics; tests for touched IDS sequences; vision off UI thread; bounded queues.

---

## 17. Future Version 1.1 Suggestions

*Non-normative. Do not alter v1.0 law.*

1. Split `skillforge_sie_flutter` when warranted.  
2. Deferred-load web vision package.  
3. Optional desktop demo OS-cursor **plugin** (never core).  
4. Shared landmark corpus CI.  
5. Formal Intent JSON schema for tooling.  
6. Private package registry if multi-app melos.

---

## 18. Cross References

- [01_RESEARCH_AND_FEASIBILITY.md](01_RESEARCH_AND_FEASIBILITY.md)  
- [02_SYSTEM_ARCHITECTURE.md](02_SYSTEM_ARCHITECTURE.md)  
- [03_INTERACTION_DESIGN_SPECIFICATION.md](03_INTERACTION_DESIGN_SPECIFICATION.md)  
- [05_ARCHITECTURE_DECISIONS.md](05_ARCHITECTURE_DECISIONS.md)  
- [README.md](README.md)  

---

## 19. Glossary

| Term | Definition |
|------|------------|
| Host | App-side integration of SIE |
| Port | Invertible dependency interface |
| Intent Bus | Channel for SieIntent events |

---

## 20. References

- Stage 1 Prompt 04 (approved 2026-07-17)  
- Documents 01–03 (frozen)

---

## 21. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-07-17 | Architecture Team | Initial frozen transfer of approved Prompt 04 |

---

## Footer

© 2026 SkillForge AI — SIE Documentation Set v1.0 (Frozen) — Document 04.
