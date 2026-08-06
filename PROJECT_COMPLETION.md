# SkillForge AI — Project Completion Overview

**Project:** SkillForge AI (`skillforge_ai` v1.0.0+1)  
**Tagline:** Multi-role ecosystem for Students, Teachers, Freelancers, Companies, Customers & Admins  
**Document date:** 31 July 2026 (synced with status doc refresh)
**Purpose:** Single completion file — what this project is, what was built, and where it lives.

> Related deeper docs: [`docs/SKILLFORGE_PROJECT_MANUAL.md`](docs/SKILLFORGE_PROJECT_MANUAL.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/CURRENT_PROJECT_STATUS.md`](docs/CURRENT_PROJECT_STATUS.md), [`docs/PROJECT_STATUS_0_TO_100.md`](docs/PROJECT_STATUS_0_TO_100.md), [`README.md`](README.md), [`TODO.md`](TODO.md).

---

## 1. What SkillForge AI Is

SkillForge AI is a **Flutter + Firebase** learning-and-work platform where:

- **Students** learn (LMS), prove skills (MCQ / projects / grand tests / certificates), use AI Career Intelligence, can unlock **Freelancer** mode via a bridge, and track purchased courses.
- **Teachers** create courses (manual + AI course builder), assignments, grand tests, track progress, earn via paid courses, and view a dedicated sandbox course-sales wallet.
- **Freelancers** publish services, handle requests/orders, use Marketplace AI to fill forms, and resolve disputes.
- **Customers** hire freelancers via marketplace commerce (escrow, delivery, revision/refund/dispute).
- **Companies** post jobs, run AI hiring, candidate intelligence, interviews, and the post-hire employee lifecycle (Employees, onboarding, HR, probation, and offboarding).
- **Admin / Super Admin** operate users, AI usage, finance, SIE, email, and platform controls.

**North-star AI rule (marketplace & copilot):** AI **fills forms / drafts**; humans **Publish / Submit / Pay / Message**. No auto-escrow or auto-publish.

---

## 2. Tech Stack

| Layer | Technology |
|-------|------------|
| Client app | Flutter (Android, iOS, Web, Windows) |
| State | Riverpod 3 |
| Routing | GoRouter |
| Auth / DB | Firebase Auth + Cloud Firestore |
| AI / payments server | Node.js `skillforge_ai_gateway` (OpenAI / Gemini / mock) |
| Spatial gestures | Local package `packages/skillforge_sie` |
| Extra | Cloud Functions (`functions/`), portfolio web (`portfolio_web/`) |

---

## 3. Roles Completed

| Role | Status | Notes |
|------|--------|--------|
| Student | Done | LMS, AI tutor, career, skill scores, paid courses, My Employment, SIE, freelancer bridge |
| Teacher | Done | Courses, AI tools, batches, earnings, Teacher Wallet, SIE |
| Freelancer | Done | Services, requests, commerce, Marketplace AI, My Employment, SIE |
| Customer | Done | Marketplace buyer UX (commerce persona) |
| Company | Done | Jobs, AI hiring, interviews, Employees and post-hire lifecycle, SIE |
| Admin / Super Admin | Done | Ops dashboards, AI usage, finance, SIE controls |

---

## 4. Feature Modules (`lib/features/`) — What Was Built

| Module | Work completed |
|--------|----------------|
| **auth** | Login, signup, forgot password, account blocked, Firestore user recovery |
| **onboarding** | Splash, app tour, role selection, role-specific onboarding |
| **home** | Public landing / entry |
| **student** | Dashboard, learning UX, AI tutor, career roadmap, **freelancer bridge** (eligibility → unlock → mode toggle), SIE host |
| **teacher** | Dashboard, batches, student progress, **AI course builder / AI tools**, SIE |
| **courses** | Full LMS: courses, lessons, enrollments, **MCQ assignments**, **grand tests**, project assignments, certificates, marketplace course widgets, **skill scores** |
| **freelancer** | Onboarding, service editor/listings, directory, service requests, SIE |
| **customer** | Customer dashboard + AI assistant entry |
| **commerce** | Orders, escrow finance, invoices, delivery, revision/refund/dispute, freelancer resolution & payout centers |
| **marketplace_ai** | Professional AI workflows: **service listing fill-all-fields**, request/proposal/delivery/resolution Apply, checklist, comparison, profile improver, draft history, quality gates, sanitizers |
| **jobs** | Job create/edit/browse/detail |
| **applications** | Apply + company applicant flows + Student/Freelancer My Employment portal |
| **company** | Profile + **AI hiring** (job post Apply), **candidate intelligence**, **hiring lifecycle** (Employees, offer PDF, welcome/docs/onboarding/HR/probation/offboarding, employment lock), SIE |
| **interviews** | Live hiring interviews / evaluation pipeline |
| **interview_lab** | AI practice interview lab + history/reports |
| **career_intelligence** | Student career readiness, insights, skill gap, roadmap, resume/portfolio tips, market, tasks; deep-link to listing builder |
| **copilot** | Intent detection → gateway `taskType` (remapped to allowlist), permissions, orchestrator |
| **payment** | Credits, subscriptions, demo + **PayFast** checkout, Teacher Wallet, teacher earnings, renewals, admin transactions |
| **notifications** | Unified in-app inbox, event writers, and role/customer navigation bells |
| **ai_usage** | Role monthly credits + per-task feature costs |
| **profile** | Profile, portfolio builder, notifications, account settings |
| **admin** | User management (incl. freelancer revoke), AI usage, email, finance/commerce, SIE/motion, interview lab, release |
| **support** | Contact + support tickets |
| **security** | App lock + PIN |
| **settings** | App settings layer |
| **legal** | Privacy, refund, account deletion |
| **release_center** | In-app release notes |
| **system** | Maintenance mode |

---

## 5. Major Completed Workstreams (High Level)

### 5.1 Core platform
- Flutter project + Firebase (multi-platform options)
- Theme / design system (light & dark)
- Auth, splash, routing, role dashboards
- Repository + provider architecture

### 5.2 LMS (Teacher ↔ Student)
- Courses, lessons, enrollments
- MCQ assignments & grand tests (create, attempt, score)
- Project assignments & submissions
- Certificates
- **Skill Scores** — weighted evidence (MCQ / project / grand test / cert) with titled sources
- **MCQ questionId uniqueness fix** (AI import collision on Windows) — answers retained across all questions
- Teacher AI course builder + materialization into real course content
- Teacher AI tools (generate → preview → apply)

### 5.3 Freelancer marketplace & commerce
- Freelancer services (create/edit/publish, packages, skills, portfolio URLs)
- Service requests → accept/reject with notes
- Orders, delivery, escrow, invoices
- Revision / refund / dispute resolution centers
- Customer marketplace UX

### 5.4 Student → Freelancer Bridge
- Eligibility gates (skills @70+, project, cert/grand test, profile %, readiness)
- Activate: add `freelancer` role, seed profile, unlock flags (keep student + toggle `primaryRole`)
- Paid services only when unlocked + freelancer mode
- Public preview; admin revoke path
- Firestore payload split for `publicProfiles` / `freelancerShowcases` rules

### 5.5 Marketplace AI (Phases A–D)
- Gateway `structuredData` for listing and marketplace tasks
- **Create/Improve with AI** on service editor → Apply all fillable fields → human Publish
- Customer service request AI fill
- Proposal → freelancer note; delivery → order message; resolution Notes Apply
- Split chips (revision / refund / dispute / improver / profile / etc.)
- Acceptance checklist, evidence-only comparison, scope review, profile Apply
- Career → listing deep-link, pricing advisory, draft history, soft quality gates
- Client sanitizers (no invented URLs / cert IDs / verified badge)

### 5.6 Company hiring
- Jobs + applications
- Company AI job post builder (Apply-to-form pattern)
- Candidate intelligence / compare
- Interviews + Interview Lab
- Post-hire lifecycle: Company Employees (`/company/employees`) and Student/Freelancer My Employment (`/my-employment`), offer PDF preview/print/share, welcome pack, HR/candidate Cloudinary documents, onboarding checklist, thin HR thread, optional 90-day probation, offboarding, and client-side reminders
- Hiring policy: multi-apply OK; accept one offer → decline others; **max 1 active hire** via `candidate_employment`

### 5.7 Career Intelligence (Student)
- Dashboard: readiness, insights, skill gap, roadmap, resume/portfolio, market, tasks
- Gateway `studentCareerAdvisor` with evidence fallback
- Layout / timeout hardening so empty-page crashes don’t hide the feature

### 5.8 Spatial Interaction Engine (SIE)
- Package `packages/skillforge_sie`: camera → gestures → intents → virtual pointer
- Pinch = click; drag/scroll fixes (pixel thresholds, stroke-latched scroll)
- Role hosts: student, teacher, freelancer, company, admin controls

### 5.9 Payments & AI gateway
- `skillforge_ai_gateway`: Copilot API, auth allowlists, system prompts, mock/OpenAI/Gemini
- Demo payment finalize + **PayFast** (checkout, IPN, fees)
- Flutter payment UI, subscriptions, student paid-course purchases/receipts, Teacher Wallet, teacher earnings, admin transactions
- Teacher Wallet state is stored on `teachers/{uid}` (`courseWallet` / `courseWalletTransactions`); release and withdraw actions are sandbox/demo only, not bank transfers
- AI credit metering per role/task

### 5.10 Copilot
- Role-aware intents and permissions
- Gateway taskType alignment (marketplace naming remaps)
- Guided actions / chat panel integration

### 5.11 Teacher Batch Management (Phases 1–6)
- **P1–P2:** pickers, dates, detail, roster sync, filter semantics
- **P3:** attendance, announcements, CSV export
- **P4:** risk digest, compare batches, AI announcement draft
- **P5:** sessions, invite codes, join requests
- **P6:** Student My Classes hub (list/detail/nav/join status/session read)
- See `docs/ARCHITECTURE.md` Appendix A.3.9 / A.5 for schema and paths

### 5.12 Unified in-app notifications
- `/notifications` inbox backed by `user_notifications`, `NotificationService`, and `NotificationEvents`
- Bell entry points in professional role navigation and the customer app bar; lifecycle, payment, commerce, classroom, and HR event writers notify in-app
- The thin employment HR thread is not a general real-time chat product

---

## 6. Backend / Packages Outside Flutter App

| Path | Purpose |
|------|---------|
| [`skillforge_ai_gateway/`](skillforge_ai_gateway/) | AI Copilot + payments server (keys stay off-device) |
| [`packages/skillforge_sie/`](packages/skillforge_sie/) | Hand / gesture / pointer engine |
| [`functions/`](functions/) | Cloud Functions (where present) |
| [`portfolio_web/`](portfolio_web/) | Portfolio web surface |
| [`firestore.rules`](firestore.rules) | Security rules (incl. employment / profiles); size/complexity constrained — deploy production rules with `node scripts/deploy-firestore-rules.js` and preserve the documented ~195 KB source target |
| [`docs/`](docs/) | Architecture, commerce, PayFast, SIE, status manuals |

---

## 7. Safety & Product Rules Locked In

- AI never auto-publishes services, auto-sends messages, or executes escrow/refund/release.
- Marketplace Apply is preview → fill form → human action.
- Hiring: one active employment; pending offers auto-decline on accept.
- Employment lifecycle is additive after hire; optional probation is never auto-started from the job duration.
- Teacher Wallet release/withdraw remains sandbox-only; it does not initiate a bank payout.
- Freelancer bridge is **additive** (student + freelancer), not a silent role wipe.
- Skill / cert / portfolio claims in AI drafts must come from real context (sanitized).
- MCQ answers keyed by **unique** `questionId` (fixed for AI-generated bulk import).

---

## 8. How to Run (Quick)

```bash
# Flutter app
flutter pub get
flutter run -d chrome   # or device of choice

# AI / Pay gateway
cd skillforge_ai_gateway
npm install
npm run dev
```

Configure Firebase + `skillforge_ai_gateway/.env` (never commit secrets).

---

## 9. Completion Snapshot

| Area | Completion |
|------|------------|
| Core / auth / roles / themes | Complete |
| LMS + MCQ + grand tests + certificates + skill scores | Complete |
| Teacher AI course / tools | Complete |
| Freelancer + customer commerce | Complete |
| Freelancer bridge (student unlock) | Complete |
| Marketplace AI (A–D Apply workflows) | Complete |
| Company hiring + AI + post-hire employment lifecycle + employment lock | Complete |
| Student Paid Courses + Teacher Wallet | Complete |
| Career Intelligence | Complete |
| SIE gestures / pointer | Complete (core + role hosts) |
| Payments (demo + PayFast path) | Complete |
| Admin ops | Complete |
| Copilot + AI gateway | Complete |
| Teacher Batch Management (Phases 1–6) | Complete |
| Unified in-app notifications | Complete |

This file is a **project-level completion map**, not a substitute for per-module manuals. For engineering detail use `docs/ARCHITECTURE.md`; for older dated checklists see `docs/CURRENT_PROJECT_STATUS.md`.

---

*SkillForge AI — Aptech Vision 2026*
