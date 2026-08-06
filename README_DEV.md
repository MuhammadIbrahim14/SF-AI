# SkillForge AI – Internal Engineering Handbook

Welcome to the **SkillForge AI** developer documentation. This document serves as a comprehensive reference guide for human developers and AI coding agents operating within this repository. It provides the necessary context on architecture, user ecosystem, established patterns, and development workflows to ensure consistency and prevent context fragmentation across prompts.

---

## 1. Project Overview

**Mission**
SkillForge AI is a next-generation SaaS ecosystem designed to seamlessly merge professional learning, freelancing, and service marketplaces into one unified platform. We empower individuals to learn new skills, build dynamic portfolios, and monetize their expertise in a premium digital environment.

**Supported Platforms**
- Web (Responsive Mobile, Tablet, Desktop)
- Android (Native via Flutter)
- iOS (Native via Flutter)
- Windows/macOS/Linux (Desktop via Flutter)

**Tech Stack**
- **Framework:** Flutter (Dart)
- **Design System:** Material 3 (Strict Compliance)
- **State Management:** Riverpod
- **Routing:** GoRouter
- **Backend/Database:** Firebase (Auth, Firestore, Cloud Storage, Functions)

---

## 2. Architecture

Our architecture heavily prioritizes scalability, clean separation of concerns, and robust reactivity:

* **Feature-first structure:** Code is grouped by business domain (e.g., `lib/features/auth/`), not by layer.
* **Riverpod:** Exclusive use of Riverpod for global and local state. Complex state uses `Notifier` and `AsyncNotifier`. Avoid `StatefulWidget` where possible.
* **Repository pattern:** All external interactions (Firebase, APIs, local storage) are abstracted behind Repositories (e.g., `UserRepositoryImpl` implements `UserRepository`). UI and Providers never talk directly to Firestore.
* **Firebase:** Tightly coupled schema with strict security rules. Write operations often use batching and transactions.
* **GoRouter:** Centralized routing handling auth-guards, role-based redirects, and deep linking natively.
* **Material 3:** Beautiful, modern, and adaptive interface built directly on Flutter’s Material 3 standard.

---

## 3. Folder Structure

```
lib/
├── app/                  # App initialization, global configuration
│   └── router/           # GoRouter setup, guards, and route names
├── core/                 # Core utilities, constants, themes, and global exceptions
│   └── theme/            # Frozen design system (AppColors, AppTypography, AppTheme)
├── features/             # Business domains (feature-first) — 27 modules
│   ├── admin/            # Ops, users, AI usage, finance, SIE controls
│   ├── ai_usage/         # Credit metering
│   ├── auth/             # Login, signup, blocked states
│   ├── career_intelligence/
│   ├── commerce/         # Orders, escrow, resolution
│   ├── company/          # Hiring, AI job post, candidate intel
│   ├── copilot/          # Intent → gateway orchestrator
│   ├── courses/          # LMS, MCQ, grand tests, skill scores
│   ├── customer/         # Buyer workspace
│   ├── freelancer/       # Services, requests
│   ├── marketplace_ai/   # Apply-to-form marketplace AI
│   ├── payment/          # Credits, PayFast/demo UI
│   ├── student/          # Learning, bridge, AI tutor, SIE
│   ├── teacher/          # Courses, AI builder/tools, SIE
│   └── …                 # jobs, interviews, interview_lab, profile, etc.
├── models/               # Immutable data models with serialization logic
├── providers/            # Global providers crossing feature boundaries
├── repositories/         # Implementations of external data access
└── shared/               # Highly reusable UI components
    └── widgets/          # Buttons, forms, empty states, and dashboard shells

skillforge_ai_gateway/    # Node Copilot AI + demo/PayFast (secrets server-side)
packages/skillforge_sie/  # Spatial Interaction Engine
```

---

## 4. User Ecosystem

SkillForge AI handles complex, multi-role environments where routing and layout drastically change based on the logged-in user.

### Professional Roles
These users access dedicated, heavy-duty dashboards via `RoleDashboardFrame`.
* **Student:** The core learner. Accesses courses, LMS, resume builder, and certificates.
* **Teacher:** Course creator. Manages curricula, students, and earnings.
* **Freelancer:** Service provider. Manages public portfolio, service listings, orders, and clients.
* **Company:** Employer role. Posts jobs and scouts for talent.

### The Customer Workspace
* **Customer:** A purely transactional account type (`accountType == customer`). **The Customer is NOT a 5th professional role.** They do not select a role, and they do not see professional sidebars. They are routed to a lightweight `/dashboard/customer` to browse services and manage orders.

### Administrative Roles
* **Admin:** Oversees platform health, content moderation, and basic support.
* **Super Admin:** Ultimate root access. Controls global settings, billing overrides, and admin assignment.

---

## 5. Current Modules

The repository currently supports the following primary business modules:

* **Authentication:** Sign-up, sign-in, account locking, role onboarding.
* **Profiles:** Multi-tenant profiles tailored by active role.
* **LMS:** Courses, lessons, MCQ, grand tests, projects, certificates, skill scores.
* **Teacher AI:** Course builder + AI tools (preview → apply).
* **Marketplace:** Freelancer services, customer browse/request flows.
* **Commerce:** Orders, escrow, invoices, payouts, revision/refund/dispute.
* **Marketplace AI:** Structured Apply-to-form drafts (listing, request, notes); human publish/submit only.
* **Freelancer Bridge:** Eligible students unlock freelancer mode without losing student role.
* **Jobs / Hiring:** Listings, applications, interviews, Interview Lab, company AI hiring, employment lock.
* **Career Intelligence:** Student readiness + AI advisor dashboard.
* **Copilot + AI gateway:** Allowlisted tasks, credits, OpenAI/Gemini/mock.
* **Payments:** Demo finalize + PayFast paths; credits/subscriptions/earnings.
* **SIE:** Camera gesture → virtual pointer (`packages/skillforge_sie`).
* **Wallet / Orders / Support / Legal / Settings / Customer Workspace / Admin:** As implemented under `lib/features/`.

**Status docs:** `PROJECT_COMPLETION.md`, `docs/CURRENT_PROJECT_STATUS.md`, `docs/PROJECT_STATUS_0_TO_100.md` (~90/100).

---

## 6. Frozen Systems

The following architectural systems are considered **frozen**. AI agents and developers must **not** redesign, rebuild, or drastically modify these without explicit overriding approval:

* **UI & Theme System:** `AppColors`, `AppTypography`, and `AppTheme` are locked. Do not introduce raw hex colors or ad-hoc text styles.
* **Navigation:** `GoRouter` path structures, guards, and redirection logic.
* **Dashboard Architecture:** `RoleDashboardFrame` and `CustomerWorkspaceShell`. Do not create new wrapper shells unnecessarily.
* **Shared Widgets:** `lib/shared/widgets/` acts as the source of truth for buttons, inputs, empty states, and standard containers.

---

## 7. Development Workflow

Strictly adhere to this 5-step process when tackling new features:

1. **Audit:** Analyze existing providers, repositories, and UI elements.
2. **Architecture Approval:** For new domains, present the Firestore schema and route structure for sign-off.
3. **Implementation:** Write the logic (Models -> Repositories -> Providers -> UI).
4. **UI Polish:** Ensure the interface is breathtaking, animated, and compliant with the frozen theme.
5. **QA:** Perform `flutter analyze` and mental/manual testing for responsive behavior and edge cases.

---

## 8. AI Collaboration Strategy

When utilizing multi-agent setups, tasks should generally follow this division of labor:

* **Codex (Logic & Backend):** Complex state machines, Riverpod providers, GoRouter setup, Firebase repositories, transaction logic, and core bug fixes.
* **Gemini (Frontend & Polish):** High-end UI design, micro-animations, Material 3 refinement, responsiveness (Mobile/Tablet/Desktop), layout QA, and visual audits.
* **Claude (Content & Context):** Documentation generation, email templates, marketing copy, system design blueprints, and semantic context structuring.

---

## 9. Prompt Strategy

To optimize context windows and prevent AI confusion:
* **One large module per prompt:** Do not ask an agent to build "Orders" and "LMS" simultaneously.
* **Bundle related work:** "Fix the routing guard and the profile logout button" is efficient.
* **Avoid repeated repository analysis:** Rely on this `README_DEV.md` and the `AGENTS.md` guide instead of asking agents to analyze the entire repository continuously.
* **Always review after implementation:** Check the `task.md` and `walkthrough.md` generated by the agent.

---

## 10. Required Validation

Before any task is considered complete, ensure:
* **`flutter analyze`:** Code must yield 0 issues.
* **Build:** The application compiles successfully.
* **Responsive QA:** Check behaviors on Mobile (<600px), Tablet (600px–900px), and Desktop (>900px).
* **Navigation QA:** Verify browser back-buttons, deep links, and role guards operate seamlessly.
* **Theme QA:** No hardcoded colors or misaligned typography.

---

## 11. Future Roadmap

Upcoming modules scheduled for integration:
* **Notifications:** Global push and in-app notification center.
* **Mailer:** Triggered email workflows (receipts, welcomes, warnings).
* **Update Management:** Force-update mechanisms and maintenance mode toggles.
* **AI Features:** Integration of LLMs directly into the LMS and Resume Studio.
* **Future Enhancements:** Advanced analytics dashboard, subscription management, and localized i18n support.

---

## 12. Repository Commands

Commonly used local development commands:

```bash
# Fetch dependencies
flutter pub get

# Run on available device (Chrome/Edge/Simulator)
flutter run

# Run code analysis (Must pass before commit)
flutter analyze

# Clean build cache (Fixes stale generation issues)
flutter clean && flutter pub get

# Build production web bundle
flutter build web --release

# Build Android APK
flutter build apk --release
```

---

## 13. Best Practices

* **Extend, Don't Duplicate:** If `DashboardHeader` almost works, add an optional parameter. Do not make `DashboardHeader2`.
* **Graceful Degradation:** Always provide fallback UI when data fails to load or is null.
* **Safety First:** Validate all user inputs client-side, but assume Firestore rules are the absolute source of truth.
* **Const Everywhere:** Maximize Flutter rendering performance by aggressively using the `const` keyword for immutable widgets.
* **Leave it better than you found it:** If you spot an unrelated typo or minor deprecation warning nearby, fix it.
