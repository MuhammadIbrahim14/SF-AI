# SkillForge AI UI Audit Report

> **Historical audit** — captured during an earlier UI pass.  
> **Current product status (25 July 2026):** see [`CURRENT_PROJECT_STATUS.md`](CURRENT_PROJECT_STATUS.md) and [`../PROJECT_COMPLETION.md`](../PROJECT_COMPLETION.md).  
> Findings below may be outdated (e.g. customer navigation and module coverage have since evolved).

> **Mode:** READ-ONLY AUDIT

> **Important constraints respected:** No app code modified, no refactors, no file renames, no UI changes, and no Firebase/notifications/AI-gateway/settlement/payment-rule edits.

## 1. Executive Summary

### Scan scope (what this report covered)
- Verified entry points and UI shell/navigation/theming integration by reading:
  - `lib/main.dart`
  - `lib/app/app.dart`
  - `lib/app/router/app_router.dart`
  - `lib/app/router/route_names.dart`
  - `lib/shared/widgets/dashboard_shell.dart`
  - `lib/shared/navigation/role_navigation_config.dart`
  - `lib/features/onboarding/presentation/role_selection_screen.dart`

### Totals
- **Total UI files found:** *Needs manual re-scan* (ripgrep missing in the tool runtime prevented full-project keyword scanning; also `lib` listing via tooling returned only directory names, not all `.dart` files.)
- **Total theme/design files found:** *Needs manual re-scan* (partial: confirmed `lib/core/theme/app_theme.dart` + theme colors referenced; full token map not completed.)
- **Total shared widget files found:** *Partial, from inspected files*: at least the following are shared/reusable UI:
  - `lib/shared/widgets/dashboard_shell.dart`
  - `lib/shared/navigation/role_navigation_config.dart`
  - `lib/shared/widgets/animated_theme_switcher.dart` (referenced)
  - (others referenced by the inspected routes likely exist but were not fully enumerated.)

### Highest impact UI files (from confirmed reads)
1. `lib/app/app.dart`
2. `lib/app/router/app_router.dart`
3. `lib/shared/widgets/dashboard_shell.dart`
4. `lib/shared/navigation/role_navigation_config.dart`
5. `lib/features/onboarding/presentation/role_selection_screen.dart`
6. `lib/app/router/route_names.dart`

### Biggest UI risks (read-only observations)
- **High impact global theming:** `SkillForgeApp` wires theme/darkTheme/themeMode + system overlay + animation preferences.
- **High complexity routing:** `app_router.dart` contains role-based redirects plus many role screens; any UI redesign must preserve redirect behavior.
- **High UI coupling:** `dashboard_shell.dart` mixes responsive layout, sidebar/rail/bottom-nav, and role styling.
- **Hardcoded styling in screens:** role selection uses many inline `Color(...)`, `EdgeInsets`, and gradients.

## 2. Theme Engine & Design System Files

### Confirmed theme engine entry points
| File | Purpose | What UI it affects | Safe to edit? | Risk level | Notes |
|---|---|---|---|---|---|
| `lib/app/app.dart` | App root: chooses `AppTheme.lightTheme(...)` / `AppTheme.darkTheme(...)`, sets `themeMode`, wraps builder in `AnimatedThemeSwitcher`, sets system UI overlay style. | **Entire app** | **No** (for UI refactor per constraint) | **High** | Acts as theme + motion orchestration. UI redesign should target `AppTheme` tokens, not root logic. |
| `lib/core/theme/app_theme.dart` *(imported)* | ThemeData factories used by `app.dart` | Entire app | Needs manual review | High | Not read in this audit run. Referenced by `app.dart`. |
| `lib/core/theme/app_colors.dart` *(imported in multiple places)* | Color tokens used in UI | App-wide palette | Needs manual review | Medium/High | Not read fully. Referenced by `app_router.dart`, role selection, and dashboard shell. |
| `lib/core/theme/role_theme.dart` *(imported)* | Per-role gradients/colors used in dashboards | Role dashboards + nav surfaces | Needs manual review | Medium | Used by `dashboard_shell.dart`. |

### Motion/animation settings integration
- `lib/app/app.dart` controls animation duration/curve and MediaQuery disable animations based on `motionSettingsStreamProvider`.

### Hardcoded colors/styles within inspected UI
From inspected screens:
- `lib/features/onboarding/presentation/role_selection_screen.dart`
  - Hardcoded background gradient colors:
    - `LinearGradient(colors: [Color(0xFF060A18), Color(0xFF0A0F1F), Color(0xFF0E142A)])`
  - Uses many inline `TextStyle`, `SizedBox`, `EdgeInsets`, `BorderRadius`.
- `lib/app/router/app_router.dart`
  - Error page uses hardcoded `AppColors.error`, icon sizes, and relies on `Theme.of(context).textTheme`.

## 3. Shared UI Components

Based on confirmed files read:

| File | Component class name(s) | Where used | UI impact | Safe for global redesign? | Risk |
|---|---|---|---|---|---|
| `lib/shared/widgets/dashboard_shell.dart` | `DashboardShell`, `RoleDashboardFrame`, `RoleDashboardBottomNav`, internal `_RoleSidebarItem`, `_StatCard`, etc. | Wraps role dashboards (student/teacher/company/freelancer/admin via redirect + layout patterns) | **Very high** (shell + nav) | **Medium** | **High** because it controls responsive layout + nav selection state + role theme styling. |
| `lib/shared/navigation/role_navigation_config.dart` | `RoleNavigationDestination`, `RoleNavigationConfig` (+ destination lists) | Drives sidebar/rail/bottom-nav destinations and icons per role | High | **Low/Medium** | **High** if edited because it impacts route paths and selection highlighting. |
| `lib/shared/widgets/animated_theme_switcher.dart` *(referenced)* | likely `AnimatedThemeSwitcher` | Global theme transitions | High | Needs manual review | Medium |

## 4. Route-to-Screen Map

### Routing control files (confirmed)
| File | Purpose |
|---|---|
| `lib/app/router/app_router.dart` | GoRouter config: redirect guards + route definitions to screens |
| `lib/app/router/route_names.dart` | Named route constants + route path constants |

### Role dashboards (confirmed from `app_router.dart` + redirect helpers)
| Role | Dashboard route (RoutePaths / RouteNames) | Screen file |
|---|---|---|
| Student | `RoutePaths.studentDashboard` / `RouteNames.studentDashboard` | `lib/features/student/presentation/student_dashboard.dart` *(not read; imported in router)* |
| Teacher | `RoutePaths.teacherDashboard` / `RouteNames.teacherDashboard` | `lib/features/teacher/presentation/teacher_dashboard.dart` *(imported)* |
| Company | `RoutePaths.companyDashboard` / `RouteNames.companyDashboard` | `lib/features/company/presentation/company_dashboard.dart` *(imported; visible tab)* |
| Freelancer | `RoutePaths.freelancerDashboard` / `RouteNames.freelancerDashboard` | `lib/features/freelancer/presentation/freelancer_dashboard.dart` *(imported)* |
| Customer | `RoutePaths.customerDashboard` / `RouteNames.customerDashboard` | `lib/features/customer/presentation/customer_dashboard.dart` *(imported)* |
| Admin | `RoutePaths.adminDashboard` / `RouteNames.adminDashboard` | `lib/features/admin/presentation/admin_dashboard.dart` *(imported)* |
| Super Admin | `RoutePaths.superAdminDashboard` / `RouteNames.superAdminDashboard` | `lib/features/admin/presentation/super_admin_dashboard.dart` *(imported)* |

> Note: `app_router.dart` contains many more role-specific routes (courses, lessons, assignments, AI course builder, jobs marketplace, wallet/payout, resolution desk, admin control panels). Full enumeration is too large for this limited tooling run and must be completed with a full file scan.

## 5. Role-wise UI File Map (partial; based on confirmed reads)

### Student
- **Main dashboard screen file:** `lib/features/student/presentation/student_dashboard.dart` *(imported by router)*
- **Shared shell:** `lib/shared/widgets/dashboard_shell.dart` (`DashboardShell` / `RoleDashboardFrame`)
- **Navigation destinations:** `lib/shared/navigation/role_navigation_config.dart` (student list)
- **Onboarding entry:** `lib/features/onboarding/presentation/role_selection_screen.dart` (step 3 student form fields)

### Teacher
- **Main dashboard screen file:** `lib/features/teacher/presentation/teacher_dashboard.dart` *(imported)*
- **Shared shell:** `lib/shared/widgets/dashboard_shell.dart`
- **Navigation destinations:** `lib/shared/navigation/role_navigation_config.dart` (teacher list)
- **Onboarding entry:** `lib/features/onboarding/presentation/role_selection_screen.dart` (teacher step 3 form fields)
- **Teacher AI course builder routes:** see `lib/app/router/app_router.dart` mapping:
  - `RoutePaths.teacherAiCourseBuilder` -> `TeacherAiCourseBuilderScreen`
  - Screen file imported: `lib/features/teacher/ai_course_builder/presentation/teacher_ai_course_builder_screen.dart`

### Company
- **Main dashboard screen file:** `lib/features/company/presentation/company_dashboard.dart` *(visible tab; imported)*
- **Shared shell:** `lib/shared/widgets/dashboard_shell.dart`
- **Navigation destinations:** `lib/shared/navigation/role_navigation_config.dart` (company list)
- **Onboarding entry:** `lib/features/onboarding/presentation/role_selection_screen.dart` (company step 3 form)

### Freelancer
- **Main dashboard screen file:** `lib/features/freelancer/presentation/freelancer_dashboard.dart` *(imported)*
- **Shared shell:** `lib/shared/widgets/dashboard_shell.dart`
- **Navigation destinations:** `lib/shared/navigation/role_navigation_config.dart` (freelancer list)
- **Onboarding entry:** `lib/features/onboarding/presentation/role_selection_screen.dart` (freelancer step 3 form)

### Customer
- **Main dashboard screen file:** `lib/features/customer/presentation/customer_dashboard.dart` *(imported)*
- **Shared navigation:** customer routes are separate (router blocks professional routes for customer)
- **Navigation destinations:** in this repo, customer nav is not implemented in `role_navigation_config.dart` (fallback isn’t customer-specific). Needs manual review.

### Admin
- **Main dashboard screen file:** `lib/features/admin/presentation/admin_dashboard.dart` *(imported)*
- **Shared shell:** may or may not use `dashboard_shell.dart`; depends on actual screen implementation (not read).
- **Admin AI Usage Control screen:** `lib/features/admin/presentation/admin_ai_usage_control_screen.dart` *(imported by router)*

### Super Admin
- **Main dashboard screen file:** `lib/features/admin/presentation/super_admin_dashboard.dart` *(imported)*

### Auth/Common
- Entry points:
  - `lib/features/auth/presentation/login_screen.dart`
  - `lib/features/auth/presentation/signup_screen.dart`
  - `lib/features/auth/presentation/forgot_password_screen.dart`
  - `lib/features/onboarding/presentation/splash_screen.dart`, `app_onboarding_screen.dart`
- App-level theming/motion:
  - `lib/app/app.dart`

## 6. Feature-wise UI Map (partial from confirmed routes/imports)

### App Shell / Navigation
- `lib/shared/widgets/dashboard_shell.dart`
- `lib/shared/navigation/role_navigation_config.dart`

### Courses/LMS (teacher + student)
- Student routes imported in `lib/app/router/app_router.dart`:
  - `StudentCoursesScreen`, `StudentEnrolledCoursesScreen`
  - `CourseDetailScreen`, `StudentCourseLearningScreen`
  - `LessonDetailScreen`, `StudentAssignmentsScreen`
  - `McqAttemptScreen`, `McqResultScreen`
  - `ProjectSubmissionScreen`, `ProjectSubmissionStatusScreen`
  - `GrandTestAttemptScreen`, `GrandTestResultScreen`, overview/results
  - `MyCertificatesScreen`, `CertificateDetailScreen`
- Teacher routes imported:
  - `TeacherCourseScreen`, `TeacherLessonsScreen`, `TeacherAssignmentsScreen`
  - `CreateEditMcqAssignmentScreen`, `AssignmentResultsScreen`
  - Project assignments/editor/review/submissions
  - Grand test editor/eligibility/attempts
  - Certificate management + eligible students

> UI file specifics for those screens must be enumerated by reading each imported screen file; this run stopped at shell/navigation + theme integration.

### AI / Copilot
- Router imports:
  - `TeacherAiCourseBuilderScreen`
- Copilot module entry:
  - `lib/features/copilot/config/copilot_ai_config.dart` *(visible tab; not read in this run)*

### Marketplace / Orders / Wallet / Resolution / Dispute
- Router imports multiple commerce screens under `lib/features/commerce/presentation/*` and resolution center screens.
- Exact UI files require manual follow-up reads.

### Admin Controls
- Router imports admin control panels + settings:
  - `AdminDashboard`, `AdminInboxScreen`, `AdminAiUsageControlScreen`
  - `AdminThemeSettingsScreen`, `AdminMotionSettingsScreen`, `AdminLanguageSettingsScreen`
  - `AuditLogsScreen`, `AdminLegalEditorScreen`, etc.

## 7. Hardcoded Style Audit (confirmed in inspected files)

| File | Hardcoded style patterns | Suggested tokenization target |
|---|---|---|
| `lib/features/onboarding/presentation/role_selection_screen.dart` | `Color(0xFF060A18)` etc; inline `TextStyle(fontSize: 11/16/...)`; repeated `EdgeInsets`, `BorderRadius.circular(14/16/20/22)`; inline button gradient + boxShadow | Move to design tokens: gradients, spacings, radii, typography, card/button elevations |
| `lib/shared/widgets/dashboard_shell.dart` | inline paddings/widths (48/272/280/88); boxShadow values; uses role theme gradient but also inline sizes | Create shared constants for layout widths/spacing; ensure shell uses theme radii/elevation |
| `lib/app/router/app_router.dart` | Error page uses hardcoded icon size `64`, sizes `16`, and `AppColors.error` | Ensure error page uses theme tokens |

## 8. UI Quality Review (partial)

### Auth/Onboarding/Common
- `RoleSelectionScreen`: visual maturity appears **polished** (glassmorphism cards, animated step header, role-specific gradients).
- Potential issues: heavy inline styling and hardcoded gradients make global redesign harder.

### App shell/navigation
- `dashboard_shell.dart`: **good** architecture for responsive navigation (sidebar/rail/bottom nav) and role-aware styling.
- Potential issues: many inline sizes/shadows; risk when adjusting global theme because it’s coupled to roleTheme.

## 9. Top 30 High-Impact UI Files

> Only the following can be confidently ranked from the limited confirmed reads.

1. `lib/app/app.dart`
   - Affects: themeMode, ThemeData factories, global animation + MediaQuery.
   - Improve: unify tokens for typography/colors/button/input.
   - Risk: High
2. `lib/app/router/app_router.dart`
   - Affects: redirects, role landing, error UI, route->screen map.
   - Improve: route-level theming consistency, unify error/loading states.
   - Risk: High
3. `lib/shared/widgets/dashboard_shell.dart`
   - Affects: role shell layout, navigation surfaces, responsive frame.
   - Improve: extract layout constants, replace inline radii/shadows with tokens.
   - Risk: High
4. `lib/shared/navigation/role_navigation_config.dart`
   - Affects: destination sets, icons/labels, selection logic.
   - Improve: centralize labels/icon styles via theme; ensure accessibility.
   - Risk: High
5. `lib/features/onboarding/presentation/role_selection_screen.dart`
   - Affects: premium onboarding visuals; inputs/buttons.
   - Improve: reduce inline styles; use shared input/button styles.
   - Risk: Medium/High
6. `lib/app/router/route_names.dart`
   - Affects: route constants used across UI.
   - Improve: n/a for UI (stability important).
   - Risk: Low

(Remaining top-30 items are marked **needs manual review** because full-screen file enumeration wasn’t possible in this run.)

## 10. Safe UI Refactor Plan

No edits performed (read-only audit).

Suggested safe editing targets (conceptually):
- Design token / theme files referenced by `AppTheme` and `AppColors`.
- Shared UI widgets (inputs/buttons/cards) once identified.
- Shell layout constants inside `dashboard_shell.dart` (if allowed in a future refactor phase).

## 11. Risky Files — Edit Carefully

| File | Risk reason |
|---|---|
| `lib/app/app.dart` | Global theme + motion + system overlay. Small changes affect all screens. |
| `lib/app/router/app_router.dart` | Redirect guard logic + many routes. UI changes can break navigation consistency. |
| `lib/shared/widgets/dashboard_shell.dart` | Mixes responsive scaffolds + nav + role theme + scroll layout. |
| `lib/shared/navigation/role_navigation_config.dart` | Route path mapping drives UI navigation correctness. |
| `lib/features/onboarding/presentation/role_selection_screen.dart` | Heavy inline gradients/text styles; refactor could subtly change visuals/validation UX. |

## 12. Gemini-Ready UI Improvement Targets (initial, file-specific)

### Target 1 — Global Theme Upgrade (Theme tokens)
Files:
- `lib/app/app.dart` (integration reference only)
- `lib/core/theme/app_theme.dart` *(needs read)*
- `lib/core/theme/app_colors.dart` *(needs read)*
- `lib/core/theme/role_theme.dart` *(needs read)*
Goal:
- Extract consistent tokens for palette, typography, input decoration, button, card, shadows.
Do not touch:
- `lib/app/router/app_router.dart` redirect/route logic
- Firebase rules, notifications, AI gateway, settlement/payment logic
Prompt summary:
- "Modernize SkillForge AI theme tokens (light/dark) using existing AppTheme factories. Preserve component behavior and routing. Consolidate scattered colors and provide consistent styles for buttons, cards, inputs, and surfaces."

### Target 2 — Dashboard Shell & Navigation Modernization
Files:
- `lib/shared/widgets/dashboard_shell.dart`
- `lib/shared/navigation/role_navigation_config.dart`
Goal:
- Align sidebar/rail/bottom-nav surfaces with theme tokens; reduce inline dimensions.
Do not touch:
- Route paths / selection logic in `RoleNavigationConfig`
Prompt summary:
- "Refine dashboard shell UI consistency: unify paddings/radii/shadows and typography for role navigation. Keep route selection behavior identical."

### Target 3 — Role Selection Onboarding Polish
Files:
- `lib/features/onboarding/presentation/role_selection_screen.dart`
- Shared widgets it already uses (verify once scanned):
  - `lib/shared/widgets/custom_text_field.dart` *(referenced)*
  - `lib/shared/widgets/loading_overlay.dart` *(referenced)*
  - `lib/shared/widgets/profile_image_picker.dart` *(referenced)*
Goal:
- Replace hardcoded onboarding gradients/text styles with theme-backed tokens; standardize input/button appearance.
Do not touch:
- profile-saving/providers
Prompt summary:
- "Unify role selection UI with app design system: convert hardcoded colors/spacings to theme tokens; keep validation and Firestore save logic unchanged."

> Additional targets (15+) require full project scan (theme/input/button/card/dialog/widgets identification) which was not completed due to missing `ripgrep` in the environment.

## 13. Recommended Order of UI Redesign
1. `lib/core/theme/app_theme.dart` / `app_colors.dart` / `role_theme.dart`
2. `lib/shared/widgets/dashboard_shell.dart`
3. Shared widgets (inputs/buttons/cards) once identified
4. High-traffic role screens (student/teacher/company/freelancer/customer/admin)

## 14. Files Not To Touch For UI Work
- `firestore.rules`
- `lib/app/router/app_router.dart` **logic**
- Any Firebase service/repository files (not enumerated in this run)
- Notifications code (not touched)
- AI gateway (not touched)
- Settlement/payment logic (not touched)

---

## Audit completeness disclaimer
This audit run could not perform a full-project file scan for UI/theme patterns due to a tooling limitation (`ripgrep` missing). As a result:
- UI file totals are **not complete**.
- Theme/design system file enumeration is **partial**.
- Shared component inventory beyond the confirmed shells is **partial**.

A complete version requires enabling file scanning (ripgrep or equivalent) and reading the discovered theme/widgets/screen files.

