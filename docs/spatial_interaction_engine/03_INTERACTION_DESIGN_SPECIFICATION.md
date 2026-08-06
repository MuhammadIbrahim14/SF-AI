# Spatial Interaction Engine — Interaction Design Specification (IDS)

| Field | Value |
|-------|-------|
| **Document** | 03 — Interaction Design Specification |
| **Component** | SkillForge AI — Spatial Interaction Engine (SIE) |
| **Version** | 1.0 |
| **Status** | **Frozen** (Behavioural Law) |
| **Created** | 2026-07-17 |
| **Last Updated** | 2026-07-17 |
| **Authors** | SkillForge AI Architecture / HCI Team |

---

## Purpose

Define the official **interaction language** for SIE: states, gestures, confidence, intent resolution, cursor behaviour, security, accessibility, feedback, and privacy.

Multiple engineering teams implementing SIE independently must produce **consistent behaviour** by following this specification.

Architecture (Document 02) remains unchanged. This document defines **behaviour only**.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Interaction Philosophy](#2-interaction-philosophy)
3. [Interaction States](#3-interaction-states)
4. [Gesture Vocabulary](#4-gesture-vocabulary)
5. [Gesture Grammar](#5-gesture-grammar)
6. [Confidence Engine](#6-confidence-engine)
7. [Intent Resolution](#7-intent-resolution)
8. [Cursor Behaviour](#8-cursor-behaviour)
9. [Security Policies](#9-security-policies)
10. [Accessibility](#10-accessibility)
11. [Error Prevention](#11-error-prevention)
12. [User Experience](#12-user-experience)
13. [Visual Feedback](#13-visual-feedback)
14. [Audio Feedback](#14-audio-feedback)
15. [Privacy & Trust](#15-privacy--trust)
16. [Future Expansion](#16-future-expansion)
17. [Engineering Principles](#17-engineering-principles)
18. [Cross References](#18-cross-references)
19. [Glossary](#19-glossary)
20. [References](#20-references)
21. [Revision History](#21-revision-history)

---

## 1. Executive Summary

SIE’s language is **pointer-first, gesture-confirmed**:

- Continuous control **imitates a mouse** (move, hover, drag, scroll).  
- Primary select gesture is **Pinch** (single primary click).  
- Not a sci-fi pose dictionary for daily use.  
- **Reliability > speed > spectacle.**

**v1 Core Vocabulary:** `OpenHandPoint`, `PinchArm`, `PinchCommit`, `PinchHold`, `PinchRelease`, `ScrollIntent`, `FistCancel`, optional `SwipeNav`, a11y `DwellSelect`.

**Rejected for v1 core:** Peace, Thumbs Up, Air Tap as primary click, OK sign, global Rotation/Zoom.

**Security:** Gestures are never sufficient alone for auth secrets, payments, or irreversible admin/account destruction.

---

## 2. Interaction Philosophy

| Question | Decision |
|----------|----------|
| Imitate mouse? | **Yes** — primary metaphor |
| Imitate touch? | **Partially** — timing/scroll physics; prefer pinch over air-tap |
| New model entirely? | **No** as base; progressive layer later |

Principles: one primary Select; positional continuous control; explicit feedback before irreversible commit; SIE optional; traditional input always available; sensitive actions need elevated assurance.

---

## 3. Interaction States

| State | Purpose |
|-------|---------|
| Disabled | Off by policy/user/platform |
| Idle | Session on; no usable hand yet |
| Tracking | Hand present; cursor may move |
| Hover | Over interactive target |
| Focused | Optional a11y/desktop focus |
| Armed | Pinch forming; not committed |
| Pressed | Click committed / drag may start |
| Dragging | Pressed + movement past threshold |
| Scrolling | Scroll modality active |
| Zooming / Rotating | v2 only |
| Paused | Temporary suspend |
| LostTracking | Hand missing; intents suppressed |
| Recovering | Reacquired; grace before clicks |
| Degraded | Low confidence/FPS; limited verbs |
| Error | Hard failure |

### Key transition rules

- **Illegal:** Disabled→Pressed; LostTracking→Pressed/Dragging; Paused→commit; Scrolling→Dragging without Pressed.  
- **Loss during Pressed (no drag):** treat as **cancel**, not click.  
- **Recovering:** suppress Select/Drag/Scroll commits for T_recover (recommended 400–700 ms).

UI expectations: status chip, arming arc when Armed, faded cursor when LostTracking, amber chip when Degraded.

---

## 4. Gesture Vocabulary

### Design decisions

| Candidate | v1 | Rationale |
|-----------|----|----|
| Open hand / point | Keep | Locomotion |
| Pinch family | Keep | Best click/drag reliability |
| Fist | Keep | Cancel |
| Swipes | Limit | False positives; opt-in |
| Dwell | A11y mode | Inclusive |
| Air tap / peace / thumbs up / depth push | Reject core | Noise, culture, depth error |
| Zoom / rotate | v2 | Two-hand; fatigue |

### Gesture cards (normative summary)

**G01 OpenHandPoint** — Cursor locomotion; continuous; high reliability.  

**G02 PinchArm** — Distance entering arm zone; progress arc **mandatory**; not yet Select.  

**G03 PinchCommit** — Primary click; confidence ≥ commit threshold for T_commit; refractory T_reclick.  

**G04 PinchHold** — Sustain Pressed; enable drag if moved.  

**G05 PinchRelease** — Hysteresis above commit; clean release ends click/drag.  

**G06 ScrollIntent** — Vertical modality over scrollable; large deadzone; not while Pressed.  

**G07 FistCancel** — Cancel Armed/Drag; high priority over Scroll.  

**G08 SwipeNav** — Optional; disabled by default; page-level only; invalid on security/forms.  

**G09 DwellSelect** — Accessibility mode only; dwell ring mandatory.

---

## 5. Gesture Grammar

### Valid sequences

1. Click: Tracking → Hover → PinchArm → PinchCommit → PinchRelease  
2. Drag: … → PinchCommit → move > D_drag → Dragging → PinchRelease  
3. Scroll: Tracking/Hover → ScrollIntent* (never while Pressed)  
4. Cancel arming/drag via FistCancel or early release  
5. Loss → LostTracking → Recovering → Tracking  
6. A11y: Hover → DwellSelect  

### Invalid

Scroll while Pressed/Dragging; SwipeNav while Armed/Pressed; Zoom/Rotate in v1; Fist as Select; reclick faster than T_reclick.

### Priorities (high → low)

Safety gates > FistCancel > Pinch family / Drag > ScrollIntent > SwipeNav > locomotion-only.

---

## 6. Confidence Engine

**Priority:** Reliability → Predictability → Speed.

- Scores in [0, 1]; use **weakest-link** gating.  
- **Hysteresis** on enter/exit (track, pinch).  
- Temporal persistence: N frames / time T before state change.  
- Once Pressed, hold threshold may be slightly lower (anti-chatter).  
- After loss: rebuild via Recovering—no instant click.  
- Low light / blur / occlusion → Degraded or LostTracking; raise commit thresholds or disable pinch.  
- False clicks mitigated by arming + commit time + hover-target requirement + refractory.

Relative ordering of thresholds is normative; exact floats are tunable implementation details.

---

## 7. Intent Resolution

When multiple hypotheses fire, apply §5 priorities.

| Situation | Winner |
|-----------|--------|
| Pinch + slight move | Pinch (click) if < D_drag |
| Pinch + large move | Drag after threshold |
| Swipe vs Armed | Pinch wins |
| Instability | Suppress commits |
| SIE + traditional input | **Traditional wins** |

Stable intent lexicon: `MoveCursor`, `HoverEnter/Exit`, `Select`, `Cancel`, `DragStart/Update/End`, `ScrollDelta`, `ZoomDelta`, `RotateDelta` (v2), `NavigateRelative`, `PauseSie`, `FocusTarget`.

---

## 8. Cursor Behaviour

- Calibration maps hand plane → screen.  
- Smoothing always on; mild capped prediction; UI-rate interpolation.  
- Soft acceleration; precision near small targets; fast gain only when not Armed.  
- Light magnetic snap on large targets only—**disabled** on dense admin/security.  
- Hover acquisition with T_hover stability.  
- Clamp to screen; dead zones at frame edges → LostTracking rather than wild jumps.  
- Optional rest zone (hand lowered) to reduce fatigue.

---

## 9. Security Policies

### Assurance levels

| Level | Meaning | Gesture Select? |
|-------|---------|-----------------|
| L0 Public | Marketing/demos | Yes |
| L1 Standard | Dashboards, browsing | Yes |
| L2 Elevated | Profile edits, publishing | Yes with confirms |
| L3 Sensitive | Auth secrets, payments, legal accept, role changes | **No gesture commit** |
| L4 Irreversible | Account deletion, admin destroy, payouts, grants | **SIE disabled for activate/confirm** |

### Concrete rules

- Password/PIN/OTP: no gesture Select for entry.  
- PayFast / payment confirm: browse may be allowed; **confirm forbidden** via gesture.  
- Account deletion / admin mutate / legal accept: traditional input required.  
- Soft delete with Undo: gesture Select allowed.  
- SIE may open a dialog but cannot confirm L3/L4.  
- Auto-pause SIE on background and on L3/L4 routes.

---

## 10. Accessibility

Modes: Standard; Tremor-tolerant; Dwell; Left/Right hand; Large cursor; Reduced motion; Short-reach calibration.

SIE is never required to use SkillForge. Critical flows must work without camera. Handedness is first-class.

---

## 11. Error Prevention

Arming arc, commit delay, hover requirement, drag threshold, scroll deadzone, SwipeNav off by default, prediction clamps, rest/pause, cancel semantics on loss, single primary click gesture, traditional input supremacy.

---

## 12. User Experience

Users should feel in control, calm, confident, lightly futuristic, respected (privacy). Never tricked or punished by false activations. Tone: precision instrument, not party trick.

---

## 13. Visual Feedback

| Signal | When |
|--------|------|
| Camera/SIE chip | Session on |
| Neutral cursor | Tracking |
| Target hover glow | Hover |
| Arming progress arc | PinchArm (**mandatory**) |
| Click pulse | PinchCommit |
| Drag trail / grab glyph | Dragging |
| Hand lost / restored | LostTracking / Recovering |
| Amber limited accuracy | Degraded |
| Calibration guide | Calibration |
| Error panel | Error |

Reduced motion: static badges instead of trails.

---

## 14. Audio Feedback

Optional, sparse: soft tick on commit/cancel; no continuous move/scroll sounds; respect mute and “SIE sounds off”; visuals always available. No payment-success implication via gesture sound.

---

## 15. Privacy & Trust

Persistent camera indicator; clear permission copy; **no raw video** in analytics; coarse metrics only; one-tap Pause/Stop; auto-stop on background and L3/L4; transparency on on-device processing. v1 expectation: on-device vision; cloud vision would need separate consent (out of v1 expectation).

---

## 16. Future Expansion

New modalities map to the **same intent lexicon**. Custom packs must not create silent L3/L4 powers. Two-hand → Zoom/Rotate intents; voice/eye/XR → same verbs.

---

## 17. Engineering Principles

Predictability over cleverness; consistency over novelty; reliability over speed; accessibility mandatory; security before convenience; user control over automation; no hidden gestures; graceful failure; explicit feedback; natural movement; one primary Select; hysteresis on binary thresholds; **loss never equals confirm**; traditional input supremacy; SIE additive never required; privacy indicators while sensing; stricter policy on dense/security UIs—not more gestures.

---

## 18. Cross References

- [01_RESEARCH_AND_FEASIBILITY.md](01_RESEARCH_AND_FEASIBILITY.md)  
- [02_SYSTEM_ARCHITECTURE.md](02_SYSTEM_ARCHITECTURE.md)  
- [04_IMPLEMENTATION_ARCHITECTURE.md](04_IMPLEMENTATION_ARCHITECTURE.md)  
- [05_ARCHITECTURE_DECISIONS.md](05_ARCHITECTURE_DECISIONS.md)  

---

## 19. Glossary

| ID / Term | Meaning |
|-----------|---------|
| G03 | PinchCommit (primary Select) |
| Armed | Pre-commit pinch state |
| T_recover | Post-loss commit suppression window |
| L3/L4 | Security levels forbidding gesture confirm |

---

## 20. References

- Stage 1 Prompt 03 (approved 2026-07-17)  
- Document 02 System Architecture  

---

## 21. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-07-17 | Architecture / HCI Team | Initial frozen transfer of approved Prompt 03 |

---

## Future Version 1.1 Suggestions

*Non-normative.*

- Opt-in dual-hand zoom/rotate packs.  
- Refined numeric threshold appendix after field tuning.

---

## Footer

© 2026 SkillForge AI — SIE Documentation Set v1.0 (Frozen) — Document 03.
