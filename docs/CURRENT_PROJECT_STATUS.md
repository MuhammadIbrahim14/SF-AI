# SkillForge AI — Current Project Status

**Status date:** 31 July 2026
**Companion docs:** [`PROJECT_COMPLETION.md`](../PROJECT_COMPLETION.md), [`PROJECT_STATUS_0_TO_100.md`](PROJECT_STATUS_0_TO_100.md), [`ARCHITECTURE.md`](ARCHITECTURE.md)

Yeh file **current codebase** ke hisab se project ki exact position batati hai. Sirf woh modules complete maane gaye hain jo `lib/`, `skillforge_ai_gateway/`, aur `packages/skillforge_sie/` mein maujood hain.

---

## 1. Snapshot

| Metric | Value |
|--------|------:|
| Dart files in `lib/` | ~560 |
| Feature modules | 27 |
| Global providers (`lib/providers/`) | ~30 |
| Test files (`test/`) | ~13 |

**Stack:** Flutter · Riverpod 3 · GoRouter · Firebase Auth/Firestore · Node `skillforge_ai_gateway` · `packages/skillforge_sie`

---

## 2. Core Foundation — Completed

- Flutter multi-platform project (Android, iOS, Web, Windows)
- Firebase init (once), Auth, Firestore
- Riverpod 3 + GoRouter (auth / role / onboarding redirects)
- Theme system (light/dark), design tokens
- Repository + provider architecture
- Splash, home, app onboarding, role selection, role onboarding
- Role dashboards: Student, Teacher, Freelancer, Company, Customer, Admin, Super Admin
- Profile center, App Lock/PIN, Legal pages, Support tickets
- Maintenance mode / system screens
- Firestore rules present (incl. employment / profiles paths used by hiring & bridge); ruleset size/complexity is constrained, so production deploys use `node scripts/deploy-firestore-rules.js` and keep the source near the documented ~195 KB limit
- Unified in-app notification inbox (`/notifications`), event/service writers, and navigation bell

---

## 3. LMS / Courses — Completed

- Courses, lessons, enrollments, learning screens
- MCQ assignments + grand tests (create, attempt, score)
- Project assignments + submissions
- Certificates
- Skill Scores (MCQ / project / grand test / cert evidence + titled sources)
- Teacher AI course builder + materialization
- Teacher AI tools (generate → preview → apply)
- **MCQ `questionId` uniqueness** — AI bulk-import collision fixed; answers retained across questions (load-time uniquify)

---

## 4. Student Ecosystem — Completed

- Student dashboard + learning flows
- AI Tutor feature module
- Career Intelligence dashboard (readiness, insights, skill gap, roadmap, tasks; gateway + fallback)
- **Freelancer Bridge:** eligibility → Activate (add `freelancer` role) → student/freelancer mode toggle → paid services when unlocked
- SIE (Spatial Interaction Engine) student host

---

## 5. Teacher Ecosystem — Completed

- Teacher dashboard, batches, student progress
- Course / assignment / grand test authoring
- AI course builder & AI tools
- Student paid-course hub (`/student/courses/paid`) with purchase history, receipts, access, and continue-learning links
- Teacher paid courses / earnings plus dedicated Teacher Wallet (`/teacher/wallet`): course-sale sync, pending/available balances, and demo-only release/withdraw actions stored on `teachers/{uid}`
- Teacher SIE scope
- **Teacher Batch Management Phases 1–6:** pickers/dates/detail/roster (P1–2); attendance/announcements/CSV (P3); risk digest/compare/AI draft (P4); sessions/invite codes/join requests (P5); Student My Classes hub (P6)

---

## 6. Freelancer + Customer Marketplace — Completed

- Freelancer onboarding, service editor (packages, skills, portfolio URLs), directory
- Service requests (accept/reject + notes)
- Customer dashboard / marketplace buyer UX
- Commerce: orders, delivery, escrow, invoices, payouts
- Resolution: revision / refund / dispute + freelancer resolution center
- **Marketplace AI (Phases A–D):** structured Apply-to-form for listing, request, proposal note, delivery message, resolution notes; checklist; comparison; profile improver; Career → listing deep-link; draft history; quality gates; sanitizers  
  - Rule: AI fills forms; human Publish / Submit / Pay / Message

---

## 7. Company Hiring — Completed

- Jobs create/edit/browse + applications
- Company AI hiring (job post Apply-to-form pattern)
- Candidate intelligence / compare
- Interviews + Interview Lab
- Post-hire employee lifecycle (not only offers): Company Employees (`/company/employees`) and Student/Freelancer My Employment (`/my-employment`) portals
- Offer-letter PDF preview/print/share; welcome pack; Cloudinary document vault for HR and candidate uploads; onboarding checklist; thin HR thread; optional probation; offboarding; and client-side join/document reminders
- Policy: multi-apply OK; accept one offer declines others; **max 1 active hire** (`candidate_employment`)

---

## 8. AI Platform — Completed

- `skillforge_ai_gateway`: `POST /api/copilot`, role allowlists, system prompts, mock/OpenAI/Gemini
- Copilot: intents, permissions, orchestrator, gateway taskType remaps
- AI usage credits (role monthly + per-task costs)
- Teacher / Company / Marketplace / Career / Interview Lab AI surfaces wired to gateway

---

## 9. Payments — Completed

- Demo payment finalize path
- PayFast checkout / IPN / return (gateway + Flutter UI)
- Credits, subscriptions, renewal reminders
- Teacher earnings, Teacher Wallet, student paid-course purchase history, and admin super transactions

---

## 10. SIE (Spatial Interaction Engine) — Completed (core)

- Package `packages/skillforge_sie`: gestures → intents → virtual pointer
- Pinch = click; drag/scroll hardening
- Role hosts: student, teacher, freelancer, company; admin SIE controls
- Docs under `docs/spatial_interaction_engine/`

---

## 11. Admin / Super Admin — Completed

- User management (incl. freelancer bridge revoke paths)
- Platform stats / settings surfaces
- AI usage admin
- Finance / commerce ops screens
- Email settings, interview lab admin, motion/SIE controls
- Release center

---

## 12. Remaining / Partial (honest)

Yeh items ab bhi **partial or out-of-scope polish** ho sakte hain — core product modules upar complete hain:

- Real-time chat / in-app messaging (the employment HR thread is intentionally thin, not a full chat product)
- Push notifications at production scale (the in-app inbox and event notifications are implemented)
- Full automated E2E suite across every role flow (unit/widget tests exist in parts; not 100% coverage)
- Physical-device QA matrix for every platform release
- Some commerce finance still documented as sandbox/configurable in older guides — verify live PayFast credentials per environment

---

## 13. How to Verify Locally

```bash
flutter pub get
flutter run -d chrome

cd skillforge_ai_gateway && npm install && npm run dev
```

Configure Firebase + gateway `.env` (do not commit secrets).

---

## Current Overall Position

SkillForge AI ab **multi-role product** hai: LMS + marketplace commerce + hiring + AI gateway + SIE + payments. June 2026 status docs (jo AI/courses/payments ko “not implemented” kehte the) **superseded** hain is July 2026 snapshot se.

Canonical completion map: [`../PROJECT_COMPLETION.md`](../PROJECT_COMPLETION.md).
