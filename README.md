# SkillForge AI

Multi-role Flutter + Firebase platform for **learning, freelancing, hiring, and commerce** — with an AI gateway and Spatial Interaction Engine (SIE).

**Version:** 1.0.0+1 (`pubspec.yaml`)  
**Status:** ~90/100 product completeness — see [`PROJECT_COMPLETION.md`](PROJECT_COMPLETION.md)

---

## Roles

Student · Teacher · Freelancer · Company · Customer (buyer workspace) · Admin / Super Admin

---

## What’s in this repo

| Path | Purpose |
|------|---------|
| `lib/` | Flutter app (feature-first) |
| `skillforge_ai_gateway/` | Node AI Copilot API + demo/PayFast payments |
| `packages/skillforge_sie/` | Hand/gesture → virtual pointer engine |
| `docs/` | Architecture, status, commerce, PayFast, SIE |
| `firestore.rules` | Security rules |

---

## Quick start

```bash
flutter pub get
flutter run -d chrome

cd skillforge_ai_gateway
npm install
npm run dev
```

Configure Firebase and `skillforge_ai_gateway/.env` locally. **Do not commit secrets.**

---

## Documentation

| Doc | Use |
|-----|-----|
| [`PROJECT_COMPLETION.md`](PROJECT_COMPLETION.md) | Full completion map |
| [`docs/CURRENT_PROJECT_STATUS.md`](docs/CURRENT_PROJECT_STATUS.md) | Dated status snapshot |
| [`docs/PROJECT_STATUS_0_TO_100.md`](docs/PROJECT_STATUS_0_TO_100.md) | Scorecard |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Engineering architecture |
| [`README_DEV.md`](README_DEV.md) | Dev / agent handbook |
| [`TODO.md`](TODO.md) | Optional remaining tasks |
| [`skillforge_ai_gateway/README.md`](skillforge_ai_gateway/README.md) | Gateway setup |
| [`docs/PAYFAST_SETUP.md`](docs/PAYFAST_SETUP.md) | Payments setup |

---

## Product highlights

- **LMS** — courses, MCQ, grand tests, projects, certificates, skill scores  
- **Marketplace** — freelancer services, customer orders, escrow, disputes  
- **Marketplace AI** — AI fills forms; humans publish/submit  
- **Freelancer Bridge** — verified students unlock freelancer mode  
- **Hiring** — jobs, AI screening helpers, interviews, one active hire lock  
- **Career Intelligence** — student readiness + AI advisor  
- **SIE** — camera gesture control  
- **Payments** — demo + PayFast paths  

---

## Getting started (Flutter)

This project uses the Flutter SDK. See [flutter.dev](https://docs.flutter.dev/) for install help.

```bash
flutter analyze
flutter test
```
