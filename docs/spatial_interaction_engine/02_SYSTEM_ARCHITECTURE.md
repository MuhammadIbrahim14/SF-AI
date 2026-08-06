# Spatial Interaction Engine — System Architecture Specification

| Field | Value |
|-------|-------|
| **Document** | 02 — System Architecture Specification |
| **Component** | SkillForge AI — Spatial Interaction Engine (SIE) |
| **Version** | 1.0 |
| **Status** | **Frozen** |
| **Created** | 2026-07-17 |
| **Last Updated** | 2026-07-17 |
| **Authors** | SkillForge AI Architecture Team |

---

## Purpose

Define the official system architecture for SIE as approved in Stage 1 Prompt 02. Implementation and interaction behaviour must conform to this document and to the Interaction Design Specification.

**No redesign of frozen decisions is permitted in v1.0.**

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Layered Architecture](#3-layered-architecture)
4. [Data Flow](#4-data-flow)
5. [Engine Responsibilities](#5-engine-responsibilities)
6. [Communication Model](#6-communication-model)
7. [State Management](#7-state-management)
8. [Platform Strategy](#8-platform-strategy)
9. [Integration Strategy](#9-integration-strategy)
10. [Dependency Rules](#10-dependency-rules)
11. [Error & Recovery](#11-error--recovery)
12. [Performance Architecture](#12-performance-architecture)
13. [Future Extension Points](#13-future-extension-points)
14. [Engineering Principles](#14-engineering-principles)
15. [Cross References](#15-cross-references)
16. [Glossary](#16-glossary)
17. [References](#17-references)
18. [Revision History](#18-revision-history)

---

## 1. Executive Summary

SIE is an **optional, app-scoped interaction subsystem** that converts camera frames into **normalized pointer intents** and applies them through a **virtual cursor + synthetic pointer pipeline** (**Approach A**).

**Non-goals (v1.0):**

- Sole input for Auth, payments, or admin destructive flows.  
- OS-level cursor hijacking as the primary design.  
- Coupling into Student/Teacher/Admin business use-cases.

**Metaphor:** SIE is a device driver for human hands—not a feature of courses or freelancing.

---

## 2. Architecture Overview

### Major subsystems

| Subsystem | Purpose |
|-----------|---------|
| **SIE Kernel** | Session lifecycle, mode transitions, feature flags, route allowlists |
| **Platform Adapters** | Camera, permissions, workers, capability probes |
| **Perception** | Vision, landmarks, gesture hypotheses |
| **Spatial Mapping** | Calibration, cursor smoothing |
| **Interaction Semantics** | Pointer FSM, hover/click/drag/scroll modules, Intent Bus |
| **Flutter Integration Bridge** | Hit-testing strategy, overlays, scroll/focus bridge |
| **Cross-cutting** | Config, diagnostics, analytics, accessibility, privacy |

Business features consume **interaction events**; they never import vision models.

---

## 3. Layered Architecture

```text
L5  Experience          Role UIs, dialogs, scrollables, SIE onboarding
L4  Application Integration   SIE Host, session gate, route policy, privacy UX
L3  Interaction Semantics     Intent Bus, pointer FSM, interaction modules
L2  Perception                Camera, vision, landmarks, gestures
L1  Platform Adapters         Camera/vision workers, capability probes
L0  Cross-cutting             Config, diagnostics, analytics, a11y, security policy
```

**Dependency rule:** Dependencies point **downward only**. L2 must never depend on L5 widgets or Firestore domain models.

---

## 4. Data Flow

```text
Camera → Vision → Landmarks → Gesture hypotheses
                            ↘ Cursor (via Calibration)
                                    ↓
                              Pointer FSM
                                    ↓
                         Interaction Engine → SieIntent
                                    ↓
                         Flutter Integration Bridge → UI
                                    ↓
                         Feedback (visual/audio) + Diagnostics (sampled)
```

### Timing domains (must not be conflated)

1. Capture clock (camera FPS)  
2. Vision clock (may be ≤ capture; e.g. 20–30 Hz)  
3. UI clock (display refresh; cursor may interpolate)

Samples are timestamped. UI must not block on vision.

---

## 5. Engine Responsibilities

### Consolidation (approved)

**Tier-1 engines:** Configuration, Camera, Vision, Landmark, Gesture, Calibration, Cursor, Pointer, Interaction (façade), Diagnostics, Accessibility, Analytics.

**Tier-2 modules under Interaction Engine:** Hover, Click, Drag, Scroll; Zoom & Rotation as **v2** plugins.

Hover/Click/Drag/Scroll share one FSM timeline and must not race as independent globals.

| Engine | Responsibility (summary) |
|--------|--------------------------|
| Configuration | Flags, thresholds, policies |
| Camera | Permission, stream, health |
| Vision | Model runtime off UI thread |
| Landmark | Normalize/quality-gate → HandFrame |
| Gesture | Hypotheses (pinch, fist, scroll cues, …) |
| Calibration | Hand→screen mapping profile |
| Cursor | Projection, smoothing, edges |
| Pointer | Merge cursor + gestures → phases |
| Interaction | Modules emit SieIntent; exclusivity |
| Accessibility | Dwell, tremor, reduced motion overlays |
| Diagnostics | FPS, loss, timelines (no raw video) |
| Analytics | Coarse product metrics only |

---

## 6. Communication Model

| Channel | Pattern | Use |
|---------|---------|-----|
| Frame pipe | High-frequency stream | Camera → Vision |
| Perception snapshots | Immutable DTOs | Landmarks → Gesture/Cursor |
| Intent Bus | Pub/sub events | Semantics → Integration |
| Session state | Low-frequency store | Kernel ↔ UI Host |
| Config | Immutable snapshots | All engines |

No shared mutable buffers across layers without clear ownership transfer.

---

## 7. State Management

### Global / session (UI-relevant, e.g. Riverpod)

- Enabled/disabled, session phase, consent, calibration profile id, route policy, health summary.

### Local / engine-internal (not global UI state)

- Per-frame landmarks, filter internals, gesture windows, pointer micro-state, ring buffers.

**Publishing vision at 30 FPS into global app state is forbidden.**

Cross-boundary DTOs (`HandFrame`, `CursorState`, `SieIntent`, `SieConfig`) are **immutable**.

---

## 8. Platform Strategy

| Platform | Posture |
|----------|---------|
| Flutter Web | **P0** primary demo/target |
| Android | **P0** |
| iOS / iPadOS | **P1** |
| Windows / macOS | **P1** desktop demo (still Approach A) |
| Linux | **P2** best-effort |

Required ports: Camera, VisionRuntime, Haptics/Audio feedback (optional), CapabilityProbe.

Web runtime ≠ mobile runtime behind the same VisionRuntimePort.

---

## 9. Integration Strategy

- Widgets stay idiomatic Flutter; they should not know MediaPipe.  
- Bridge synthesizes pointer-like semantics (hover, down/up, move, scroll).  
- Cursor overlay at host root.  
- Dialogs: modal capture (intents target dialog).  
- Forms: suspend click-to-type; use platform IME.  
- **Traditional input wins** on conflict.  
- Route/role policy blocks SIE commit on sensitive surfaces (see IDS security levels).

---

## 10. Dependency Rules

- Perception never imports business features or Firestore.  
- Interaction never calls camera/vision vendors directly.  
- Host depends on session façade + intents + config.  
- Platform adapters implement ports only.

Circular dependencies between Host and Vision are forbidden.

---

## 11. Error & Recovery

Phases include: permission denied, camera unavailable, unsupported device, tracking lost, low confidence, multiple hands, low FPS, paused (interruptions).

**Degradation ladder:** Full SIE → cursor-only → SIE off → feature hidden.

**Never block core SkillForge workflows** because SIE fails.

Recovering after loss suppresses commits for a grace period (defined in IDS).

---

## 12. Performance Architecture

- UI remains at display refresh for cursor interpolation.  
- Vision typically 20–30 Hz; adaptive downshift under load.  
- Intent latency budget ~50–70 ms median on mid devices.  
- Backpressure: drop frames if vision busy (keep latest).  
- Resolution ladder; coalesce move events; stop camera when session Off.

---

## 13. Future Extension Points

Same Intent Bus vocabulary for: two-hand zoom/rotate, face attention, voice, eye tracking, custom gesture packs, AI classifiers, XR controllers—via adapters, without rewriting L5 business features.

---

## 14. Engineering Principles

1. Single Responsibility  
2. Dependency Inversion  
3. Loose Coupling  
4. Event-driven intents  
5. Interface-first ports  
6. Testability without camera for L3 logic  
7. Predictable immutable DTOs  
8. Backward compatibility when SIE is off  
9. Security & privacy by design  
10. Performance isolation (vision off UI thread)  
11. Fail-open for core product  
12. Progressive enhancement (P0 surfaces first)  
13. Policy over hardcoding  
14. Observability required for CV interaction systems  

---

## 15. Cross References

- [01_RESEARCH_AND_FEASIBILITY.md](01_RESEARCH_AND_FEASIBILITY.md)  
- [03_INTERACTION_DESIGN_SPECIFICATION.md](03_INTERACTION_DESIGN_SPECIFICATION.md)  
- [04_IMPLEMENTATION_ARCHITECTURE.md](04_IMPLEMENTATION_ARCHITECTURE.md)  
- [05_ARCHITECTURE_DECISIONS.md](05_ARCHITECTURE_DECISIONS.md)  
- [README.md](README.md)  

---

## 16. Glossary

| Term | Definition |
|------|------------|
| Intent Bus | Event channel for `SieIntent` |
| Approach A | In-app virtual cursor pipeline |
| HandFrame | Normalized landmark snapshot |
| Pointer FSM | Idle/Hover/Pressed/Dragging/… |

---

## 17. References

- Stage 1 Prompt 02 (approved 2026-07-17)  
- Document 01 Feasibility (Approach A)

---

## 18. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-07-17 | Architecture Team | Initial frozen transfer of approved Prompt 02 |

---

## Future Version 1.1 Suggestions

*Non-normative.*

- Formal dual-hand module schedule.  
- Optional demo-only OS cursor plugin (never core).

---

## Footer

© 2026 SkillForge AI — SIE Documentation Set v1.0 (Frozen) — Document 02.
