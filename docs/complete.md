# SkillForge AI — Project Completion Status

**Updated:** 31 July 2026
**Canonical maps:** [`../PROJECT_COMPLETION.md`](../PROJECT_COMPLETION.md) · [`CURRENT_PROJECT_STATUS.md`](CURRENT_PROJECT_STATUS.md)

Yeh file current codebase mein **implement ho chuke** major blocks ki summary hai.

---

## 1. Core Architecture & Setup
- Firebase Auth + Firestore; multi-platform `firebase_options`
- Riverpod 3 state management
- GoRouter with auth / role / onboarding guards (`app_router.dart`, `route_names.dart`)
- App entry: `main.dart`, `app.dart` + theme + router
- Feature-first layout under `lib/features/` (**27** modules)
- Node gateway: `skillforge_ai_gateway/`
- Local package: `packages/skillforge_sie/`

## 2. Theming & Utilities
- Centralized colors, typography, light/dark themes
- Shared exceptions, constants, validators
- Shared dashboard shells / role frames / reusable widgets

## 3. Auth, Onboarding, Profiles
- Login, signup, forgot password, account blocked
- Splash, public home, app intro, role selection, role onboarding
- Role dashboards + profile edit (all professional roles)
- Customer workspace (accountType customer — not a 5th professional role)
- App Lock / PIN, Legal pages, Support

## 4. LMS (`courses` + teacher/student)
- Courses, lessons, enrollments, learning UI
- MCQ assignments & grand tests (unique question IDs; AI import hardened)
- Project assignments & submissions
- Certificates
- Skill Scores with titled evidence sources
- Teacher AI course builder + AI tools (preview → apply)
- Student Paid Courses (`/student/courses/paid`): purchase history, receipts, paid access, and continue learning
- Teacher Wallet (`/teacher/wallet`): paid-course sales sync, pending/available balances, and demo-only release/withdraw history on `teachers/{uid}`

## 5. Marketplace & Commerce
- Freelancer services, packages, publish/draft
- Service requests + notes
- Orders, delivery, escrow, invoices, payouts
- Revision / refund / dispute resolution centers
- Customer marketplace dashboard

## 6. Marketplace AI (`marketplace_ai`)
- Gateway `structuredData` + Flutter Apply-to-form
- Service listing Create/Improve with AI (fill all fillable fields → human Publish)
- Service request, proposal note, delivery message, resolution Notes Apply
- Checklist, comparison, scope, profile improver
- Draft history, quality gates, sanitizers
- Safety: no auto-publish / pay / message / escrow

## 7. Student extras
- AI Tutor
- Career Intelligence
- Freelancer Bridge (eligibility → unlock → mode toggle)
- SIE host

## 8. Company hiring
- Jobs + applications
- Company AI job post Apply
- Candidate intelligence
- Interviews + Interview Lab
- Post-hire lifecycle: Company Employees and Student/Freelancer My Employment portals; offer PDF preview/print/share; welcome pack; HR/candidate Cloudinary documents; onboarding; thin HR thread; optional probation; offboarding; client reminders
- Hiring lifecycle + max 1 active employment

## 9. AI platform
- Copilot intents / permissions / orchestrator
- AI usage credits
- Gateway allowlists + system prompts (OpenAI / Gemini / mock)

## 10. In-app notifications
- Unified `/notifications` inbox with `NotificationService` / `NotificationEvents` writers and navigation bells
- Employment HR messages and lifecycle events notify the relevant company/candidate; this is not a full real-time chat product

## 11. Payments
- Demo finalize + PayFast paths
- Credits, subscriptions, teacher earnings, Teacher Wallet, student paid-course purchases, admin transactions

## 12. Admin / Super Admin
- Users, AI usage, finance/commerce, email, SIE/motion, release center

## 13. Intentionally not a full product yet
- Dedicated real-time chat product
- Production push-notification mesh
- 100% automated E2E coverage

---

*For scored % and remaining-to-100, see `PROJECT_STATUS_0_TO_100.md`.*
