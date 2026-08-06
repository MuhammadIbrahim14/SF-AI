# SkillForge AI — SIE Visual Usage Guide

**For:** running the app with live hand-gesture interaction (not automated tests)

---

## Quick start (Chrome — recommended)

```powershell
cd "d:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project"
flutter pub get
flutter run -d chrome
```

1. Log in as any role (Student, Teacher, Freelancer, Company, Admin).
2. When the browser asks for **camera permission → Allow**.
3. Open that role’s **dashboard** (where `SieInteractive` cards exist).
4. Top-left HUD shows **SIE: ON**, **Pipeline: live**, **Cursor: …**
5. Cyan virtual cursor follows your index finger.
6. **Pinch** (thumb + index) = click/select on dashboard cards.
7. **Open palm + move** = scroll (where scroll targets exist).
8. **Mouse and keyboard always work** — SIE is optional.

---

## What you should see

| UI element | Meaning |
|------------|---------|
| Top-left **SkillForge SIE — Live** HUD | Camera pipeline active (debug builds) |
| Bottom-right **SIE-S / T / F / C / A** chip | Route policy for current module |
| **SIE: OFF** on billing/payments | Correct — sensitive routes block gesture |
| Cyan cursor ring | Hand tracking active |

---

## Roles & dashboards

| Role | Dashboard path | Gesture targets |
|------|----------------|-----------------|
| Student | `/dashboard/student` | Quick action cards |
| Teacher | `/dashboard/teacher` | Command cards |
| Freelancer | Freelancer dashboard | Opportunity cards |
| Company | Company dashboard | Command actions |
| Admin | Admin dashboard | Workspace grid panels |

Navigate normally with mouse; use gestures on wrapped cards.

---

## If camera does not start

1. Check browser permission (lock icon → Camera → Allow).
2. Use **HTTPS or localhost** (Chrome requires secure context).
3. Close other apps using the webcam.
4. Restart: `R` in terminal or hot restart.
5. Read HUD **Note:** line for error text.

---

## Android

```powershell
flutter run -d android
```

Grant camera permission when prompted. Same gestures as Web.

---

## Windows desktop

Desktop uses **fake camera** (test doubles) — no real hand tracking.  
For visual gesture use, prefer **Chrome** or **Android**.

---

## Gesture vocabulary (IDS)

| Gesture | Action |
|---------|--------|
| Index point + move | Move virtual cursor |
| Pinch (thumb + index close) | Select / click |
| Open palm + vertical move | Scroll |
| Fist / lost hand | Cursor hides, recovers when hand returns |

---

## Protected routes (gesture blocked)

These always show **SIE: OFF** — use mouse/keyboard only:

- Payments, billing, finance
- API keys, secrets, admin emergency
- Account deletion
- Contract signing, payouts (Freelancer)

---

## Debug vs release

| | Debug (Web/Android) | Release |
|--|---------------------|---------|
| Camera pipeline | Auto-start | Off by default |
| Live HUD | Yes | Hidden |
| PRF segment | Internal developers | Beta/public via rollout |

---

## Related docs

- [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md)
- [SUPPORT_GUIDE.md](SUPPORT_GUIDE.md)
- [13_ENTERPRISE_ACCEPTANCE_AND_RELEASE.md](../13_ENTERPRISE_ACCEPTANCE_AND_RELEASE.md)
