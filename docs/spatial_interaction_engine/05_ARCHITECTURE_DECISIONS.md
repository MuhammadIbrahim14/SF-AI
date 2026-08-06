# Spatial Interaction Engine — Architecture Decision Records (ADR)

| Field | Value |
|-------|-------|
| **Document** | 05 — Architecture Decision Records |
| **Component** | SkillForge AI — Spatial Interaction Engine (SIE) |
| **Version** | 1.0 |
| **Status** | **Frozen** |
| **Created** | 2026-07-17 |
| **Last Updated** | 2026-07-17 |
| **Authors** | SkillForge AI Architecture Team |

---

## Purpose

Preserve the rationale behind every significant Stage 1 architectural and interaction decision. ADRs explain **why**, so future teams do not accidentally undo Version 1.0 law.

**Cross references:** [01](01_RESEARCH_AND_FEASIBILITY.md) · [02](02_SYSTEM_ARCHITECTURE.md) · [03](03_INTERACTION_DESIGN_SPECIFICATION.md) · [04](04_IMPLEMENTATION_ARCHITECTURE.md) · [README](README.md)

---

## Table of Contents

- [ADR-001](#adr-001--optional-mode-not-sole-input)
- [ADR-002](#adr-002--approach-a-in-app-virtual-cursor)
- [ADR-003](#adr-003--reject-os-cursor-as-core-approach-b)
- [ADR-004](#adr-004--sie-as-independent-subsystem)
- [ADR-005](#adr-005--standalone-package-under-packages)
- [ADR-006](#adr-006--layered-architecture-and-downward-dependencies)
- [ADR-007](#adr-007--intent-bus-normalized-verbs)
- [ADR-008](#adr-008--pointerpod-not-used-for-30-fps-vision)
- [ADR-009](#adr-009--platform-adapters-and-ports)
- [ADR-010](#adr-010--interaction-modules-nested-under-façade)
- [ADR-011](#adr-011--mouse-analogue-interaction-philosophy)
- [ADR-012](#adr-012--pinch-as-primary-select)
- [ADR-013](#adr-013--minimal-gesture-vocabulary)
- [ADR-014](#adr-014--reject-air-tap-peace-thumbs-up-as-core)
- [ADR-015](#adr-015--confidence-hysteresis)
- [ADR-016](#adr-016--recovering-state-after-tracking-loss)
- [ADR-017](#adr-017--loss-never-equals-confirm)
- [ADR-018](#adr-018--security-levels-l3l4-forbid-gesture-confirm)
- [ADR-019](#adr-019--traditional-input-supremacy)
- [ADR-020](#adr-020--mouse-and-touch-remain-supported)
- [ADR-021](#adr-021--p0-targets-web-and-android)
- [ADR-022](#adr-022--no-raw-video-in-analytics)
- [ADR-023](#adr-023--zoom-rotate-deferred-to-v2)
- [ADR-024](#adr-024--swipenav-opt-in-not-default)
- [ADR-025](#adr-025--arming-feedback-mandatory-before-click)
- [ADR Index](#adr-index)
- [Revision History](#revision-history)

---

## ADR-001 — Optional Mode, Not Sole Input

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-001 |
| **Status** | Accepted (Frozen v1.0) |
| **Date** | 2026-07-17 |
| **Decision** | SIE ships as an **optional** interaction mode, never as the only way to use SkillForge. |
| **Context** | Fatigue, precision limits, and environment variance make gesture-only UX unsafe for a multi-role SaaS. |
| **Alternatives Considered** | (a) Gesture-first entire app; (b) Optional mode; (c) Demo-only prototype never productized. |
| **Consequences** | Always provide touch/mouse/keyboard paths; feature flags and kill switch required. |
| **Future Notes** | 1.1 may expand surfaces; must not remove traditional input. |
| **Refs** | Doc 01 |

---

## ADR-002 — Approach A: In-App Virtual Cursor

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-002 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Primary architecture is **Approach A**: virtual cursor inside Flutter + synthetic intents. |
| **Context** | SkillForge is a Flutter multi-role app; control must stay sandboxed, testable, and cross-platform. |
| **Alternatives Considered** | Approach B (OS cursor); Approach C (hybrid). |
| **Consequences** | Integration Bridge owns overlays and pointer semantics; no dependency on OS accessibility mouse APIs for core. |
| **Future Notes** | OS cursor may appear only as a non-core plugin (see ADR-003). |
| **Refs** | Doc 01, 02 |

---

## ADR-003 — Reject OS Cursor as Core (Approach B)

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-003 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Native OS cursor control is **not** the core design. |
| **Context** | OS injection raises security perception, permission complexity, and poor cross-platform maintainability. |
| **Alternatives Considered** | Full OS control; hybrid kiosk SKU. |
| **Consequences** | Desktop demos still use in-app cursor unless a future 1.1 plugin is explicitly approved. |
| **Future Notes** | Document 04 lists optional demo plugin under 1.1 suggestions only. |
| **Refs** | Doc 01, 02, 04 |

---

## ADR-004 — SIE as Independent Subsystem

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-004 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | SIE is an independent subsystem; business features must not embed vision logic. |
| **Context** | SkillForge will grow; coupling CV to courses/admin would destroy maintainability. |
| **Alternatives Considered** | Feature folder per role; shared utils scattered in `lib/`. |
| **Consequences** | Clear Host boundary; forbidden imports from perception to Firestore/domain. |
| **Future Notes** | — |
| **Refs** | Doc 02, 04 |

---

## ADR-005 — Standalone Package under `/packages`

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-005 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Implement SIE primarily as `/packages/skillforge_sie` with a thin app Host. |
| **Context** | Need enforceable module boundaries and isolated testing. |
| **Alternatives Considered** | `lib/`-only; many micro-packages day one. |
| **Consequences** | Public export barrel; app pins package SemVer; deep `src/` imports forbidden. |
| **Future Notes** | Optional `skillforge_sie_flutter` split in 1.1 if needed. |
| **Refs** | Doc 04 |

---

## ADR-006 — Layered Architecture and Downward Dependencies

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-006 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Enforce L0–L5 layering with **downward-only** dependencies. |
| **Context** | Prevent UI/business from leaking into perception and vice versa. |
| **Alternatives Considered** | Flat module soup; hexagonal-only without named product layers. |
| **Consequences** | Vision never depends on widgets; Host never calls MediaPipe directly. |
| **Future Notes** | — |
| **Refs** | Doc 02 |

---

## ADR-007 — Intent Bus / Normalized Verbs

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-007 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | All modalities emit a stable **SieIntent** lexicon; UI reacts to intents, not poses. |
| **Context** | Future voice/eye/XR must not force UI rewrites. |
| **Alternatives Considered** | Widgets subscribe to raw landmarks; per-feature gesture handling. |
| **Consequences** | Intent SemVer discipline; custom packs map to existing verbs. |
| **Future Notes** | Additive intents preferred over renames. |
| **Refs** | Doc 02, 03, 04 |

---

## ADR-008 — Riverpod Does Not Process 30 FPS Vision

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-008 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Global app state (e.g. Riverpod) holds **session/config/health only**—not per-frame landmarks. |
| **Context** | Rebuilding UI trees at vision rate destroys performance and testability. |
| **Alternatives Considered** | Stream landmarks through Riverpod; Provider per finger. |
| **Consequences** | Engines keep internal mutable state; publish immutable low-rate snapshots/events. |
| **Future Notes** | — |
| **Refs** | Doc 02, 04 |

---

## ADR-009 — Platform Adapters and Ports

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-009 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Camera, vision, permissions, timing, display, feedback use **ports**; platform code implements them. |
| **Context** | Web WASM ≠ mobile native; vendors will change. |
| **Alternatives Considered** | Hard-code one SDK everywhere. |
| **Consequences** | Replaceable vision providers; domain stays pure. |
| **Future Notes** | — |
| **Refs** | Doc 02, 04 |

---

## ADR-010 — Interaction Modules Nested under Façade

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-010 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Hover/Click/Drag/Scroll are modules under **Interaction Engine**, not peer global engines. |
| **Context** | Peer engines race on shared pointer timeline. |
| **Alternatives Considered** | Twenty top-level engines as separate packages. |
| **Consequences** | Single exclusivity policy; Zoom/Rotate remain v2 plugins. |
| **Future Notes** | — |
| **Refs** | Doc 02, 04 |

---

## ADR-011 — Mouse-Analogue Interaction Philosophy

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-011 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Interaction language imitates **mouse** (and partially touch), not a wholly new OS grammar. |
| **Context** | SkillForge already uses pointer semantics; learning cost must stay low. |
| **Alternatives Considered** | Pose-based sci-fi command language. |
| **Consequences** | Point + pinch-click + drag + scroll as core loop. |
| **Future Notes** | Progressive layers allowed without changing base grammar. |
| **Refs** | Doc 03 |

---

## ADR-012 — Pinch as Primary Select

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-012 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | **Pinch** (G02–G05) is the sole primary Select gesture in v1. |
| **Context** | Need one reliable, learnable commit action with clear landmark cues. |
| **Alternatives Considered** | Air tap; dwell-only; push-to-click depth; multiple competing clicks. |
| **Consequences** | Arming + commit hysteresis required; dwell reserved for a11y mode. |
| **Future Notes** | Do not add a second default click pose in 1.0. |
| **Refs** | Doc 03 |

---

## ADR-013 — Minimal Gesture Vocabulary

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-013 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Keep v1 vocabulary intentionally **minimal** (point, pinch family, scroll intent, fist cancel, optional swipe, dwell a11y). |
| **Context** | Large pose dictionaries increase false positives and training burden (Kinect-era lesson). |
| **Alternatives Considered** | Full cinematic gesture set at launch. |
| **Consequences** | Higher reliability; packs later via plugins. |
| **Future Notes** | 1.1 opt-in packs only. |
| **Refs** | Doc 01, 03 |

---

## ADR-014 — Reject Air Tap / Peace / Thumbs Up as Core

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-014 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Air Tap, Peace, Thumbs Up, OK sign, depth push/pull are **not** v1 core gestures. |
| **Context** | Ambiguity, cultural variance, monocular depth noise, hidden-language risk. |
| **Alternatives Considered** | Include for “wow” demos as defaults. |
| **Consequences** | Demo spectacle uses feedback chrome, not extra default verbs. |
| **Future Notes** | May return as opt-in packs mapping to existing intents. |
| **Refs** | Doc 03 |

---

## ADR-015 — Confidence Engine Uses Hysteresis

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-015 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | All binary thresholds use **enter/exit hysteresis** and temporal persistence; reliability prioritized over speed. |
| **Context** | Landmark flicker causes false enters/exits without hysteresis. |
| **Alternatives Considered** | Single threshold; instantaneous pose switching. |
| **Consequences** | Slightly slower commits; far fewer false activations. |
| **Future Notes** | Numeric values tunable; ordering/hysteresis normative. |
| **Refs** | Doc 03 |

---

## ADR-016 — Recovering State After Tracking Loss

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-016 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | After LostTracking, enter **Recovering** and suppress commits for T_recover before normal Tracking/Hover. |
| **Context** | Hand reappearance often coincides with unstable landmarks and accidental pinches. |
| **Alternatives Considered** | Immediate click eligibility on reacquire. |
| **Consequences** | Mandatory UI “restored” feedback; safer sessions. |
| **Future Notes** | — |
| **Refs** | Doc 02, 03 |

---

## ADR-017 — Loss Never Equals Confirm

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-017 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Tracking loss during Pressed (no drag) **cancels**; it must not complete Select. |
| **Context** | Completing clicks on loss causes catastrophic false confirms. |
| **Alternatives Considered** | Treat loss as release-click. |
| **Consequences** | Explicit cancel semantics for drag loss as well. |
| **Future Notes** | — |
| **Refs** | Doc 03 |

---

## ADR-018 — Security Levels L3/L4 Forbid Gesture Confirmation

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-018 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Assurance levels **L3/L4** forbid gesture-based confirmation (auth secrets, payments, legal accept, irreversible admin/account actions). |
| **Context** | SkillForge handles payments, PII, and admin power; false gesture confirms are unacceptable. |
| **Alternatives Considered** | Allow gestures everywhere with “are you sure” only. |
| **Consequences** | Route policy + security module; SIE may navigate/open but not confirm; traditional input required. |
| **Future Notes** | Surface catalog extends additively. |
| **Refs** | Doc 03, 04 |

---

## ADR-019 — Traditional Input Supremacy

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-019 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | When traditional pointer/keyboard and SIE conflict, **traditional input wins**. |
| **Context** | Users must retain deterministic control; dual-input chaos is dangerous. |
| **Alternatives Considered** | SIE always overrides; merge streams naively. |
| **Consequences** | Host implements conflict policy via input probe. |
| **Future Notes** | — |
| **Refs** | Doc 03, 04 |

---

## ADR-020 — Mouse and Touch Remain Supported

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-020 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Mouse and touch remain fully supported for all core SkillForge workflows. |
| **Context** | Feasibility rejected gesture-only product. |
| **Alternatives Considered** | Deprecate mouse on demo SKUs. |
| **Consequences** | SIE off = zero behaviour change for existing users (backward compatibility principle). |
| **Future Notes** | — |
| **Refs** | Doc 01, 02 |

---

## ADR-021 — P0 Targets: Web and Android

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-021 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Platform priority: **Flutter Web and Android = P0**; iOS/desktop P1; Linux P2. |
| **Context** | Demo reach + classroom Android devices; engineering capacity limited. |
| **Alternatives Considered** | Desktop-first; iOS-first. |
| **Consequences** | Spikes and CI matrix prioritize P0. |
| **Future Notes** | Revisit after field data. |
| **Refs** | Doc 01, 02 |

---

## ADR-022 — No Raw Video in Analytics

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-022 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Analytics and test corpora must **never** store raw camera video; landmarks/events only. |
| **Context** | Camera features create trust risk; SkillForge must remain trustworthy. |
| **Alternatives Considered** | Cloud video debugging dumps. |
| **Consequences** | Replay tools use landmark JSON; privacy chip mandatory while sensing. |
| **Future Notes** | Cloud vision would need separate consent (out of v1 expectation). |
| **Refs** | Doc 03, 04 |

---

## ADR-023 — Zoom / Rotate Deferred to v2

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-023 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Two-hand Zoom and Rotation are **not** v1 core; reserved as Interaction plugins later. |
| **Context** | Fatigue, dual-hand reliability, and scope control. |
| **Alternatives Considered** | Ship dual-hand at launch. |
| **Consequences** | Intent slots `ZoomDelta`/`RotateDelta` reserved; unused in v1 grammar. |
| **Future Notes** | 1.1 opt-in packs. |
| **Refs** | Doc 02, 03 |

---

## ADR-024 — SwipeNav Opt-In, Not Default

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-024 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | `SwipeNav` is optional and **disabled by default**. |
| **Context** | High false-positive risk vs pinch/scroll. |
| **Alternatives Considered** | Global swipe navigation always on. |
| **Consequences** | Enable per showcase/lesson surface only. |
| **Future Notes** | — |
| **Refs** | Doc 03 |

---

## ADR-025 — Arming Feedback Mandatory Before Click

| Field | Value |
|-------|-------|
| **ADR Number** | ADR-025 |
| **Status** | Accepted |
| **Date** | 2026-07-17 |
| **Decision** | Entering PinchArm **must** show a visible arming progress affordance before PinchCommit. |
| **Context** | Mid-air lacks haptics; users need prediction of commit. |
| **Alternatives Considered** | Instant click on pinch without preview. |
| **Consequences** | Host/overlay contract includes arming arc; reduced-motion may substitute static badge. |
| **Future Notes** | — |
| **Refs** | Doc 03 |

---

## ADR Index

| ADR | Title |
|-----|-------|
| 001 | Optional mode, not sole input |
| 002 | Approach A in-app virtual cursor |
| 003 | Reject OS cursor as core |
| 004 | Independent subsystem |
| 005 | Standalone `/packages` strategy |
| 006 | Layered downward dependencies |
| 007 | Intent Bus normalized verbs |
| 008 | No 30 FPS Riverpod vision |
| 009 | Platform adapters / ports |
| 010 | Nested interaction modules |
| 011 | Mouse-analogue philosophy |
| 012 | Pinch primary Select |
| 013 | Minimal vocabulary |
| 014 | Reject air tap / peace / thumbs up core |
| 015 | Confidence hysteresis |
| 016 | Recovering state |
| 017 | Loss ≠ confirm |
| 018 | L3/L4 forbid gesture confirm |
| 019 | Traditional input supremacy |
| 020 | Mouse and touch remain supported |
| 021 | P0 Web + Android |
| 022 | No raw video analytics |
| 023 | Zoom/rotate deferred |
| 024 | SwipeNav opt-in |
| 025 | Mandatory arming feedback |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-07-17 | Architecture Team | Initial ADR set from Stage 1 approvals |

---

## Future Version 1.1 Suggestions

*Non-normative.*

- New ADRs for dual-hand packs, voice fusion, or OS-cursor demo plugin—each with Status Proposed before acceptance.

---

## Footer

© 2026 SkillForge AI — SIE Documentation Set v1.0 (Frozen) — Document 05.
