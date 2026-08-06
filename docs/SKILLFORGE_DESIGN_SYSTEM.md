# SkillForge AI — Design System

> **Version:** 1.0.0
> **Last Updated:** 2026-06-23
> **Source of Truth:** `lib/core/theme/` + `lib/shared/widgets/`
> **Status:** Active — All values extracted from live codebase

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Color System](#2-color-system)
3. [Role Color System](#3-role-color-system)
4. [Typography System](#4-typography-system)
5. [Gradient System](#5-gradient-system)
6. [Surface & Background System](#6-surface--background-system)
7. [Semantic Color System](#7-semantic-color-system)
8. [Overlay & Utility Colors](#8-overlay--utility-colors)
9. [Shared UI Component Library](#9-shared-ui-component-library)
10. [LMS UI Component Library](#10-lms-ui-component-library)
11. [Dashboard Component Standards](#11-dashboard-component-standards)
12. [Theme File Reference](#12-theme-file-reference)
13. [Action Color Standards](#13-action-color-standards)
14. [Dashboard Metric Color Standards](#14-dashboard-metric-color-standards)
15. [Color Restrictions](#15-color-restrictions)
16. [Role Authority Hierarchy](#16-role-authority-hierarchy)
17. [Role Color Usage Rules](#17-role-color-usage-rules)

---

## 1. Design Philosophy

SkillForge AI follows a **dark-futuristic premium aesthetic** with full light-theme support. The design system is built on three pillars:

| Pillar | Description |
|--------|-------------|
| **Role Identity** | Every user role has a distinct color identity that permeates their entire experience — dashboards, cards, badges, and accents all reflect who the user is. |
| **Dual-Theme Architecture** | Every color token exists in both dark and light variants. The system never relies on a single hardcoded background or text color. |
| **Component Consistency** | All UI is constructed from a shared widget library (`shared/widgets/`) and a specialized LMS widget library (`shared/widgets/lms_ui/`). Ad-hoc styling is prohibited. |

### Source Files

| File | Path | Purpose |
|------|------|---------|
| `app_colors.dart` | `lib/core/theme/app_colors.dart` | Centralized color constants (dark, light, semantic, role-specific) |
| `app_theme.dart` | `lib/core/theme/app_theme.dart` | `ThemeData` assembly for dark and light modes |
| `app_typography.dart` | `lib/core/theme/app_typography.dart` | `TextTheme` built from Google Fonts (Outfit + Inter) |

---

## 2. Color System

### 2.1 — Primary Palette

The primary palette is the brand identity of SkillForge AI. It is used for primary actions, navigation highlights, active states, and branding elements.

| Token | Hex | Swatch | Usage |
|-------|-----|--------|-------|
| `primary` | `#5B7CFF` | 🔵 | Primary buttons, active navigation, app bar accents |
| `primaryLight` | `#8DA3FF` | 🔵 | Hover states, secondary highlights, lighter accents |
| `primaryDark` | `#3A5AE0` | 🔵 | Pressed states, darker accents, emphasis |

### 2.2 — Secondary Palette

The secondary palette provides visual contrast and is used for supporting UI elements.

| Token | Hex | Swatch | Usage |
|-------|-----|--------|-------|
| `secondary` | `#8A5CFF` | 🟣 | Secondary actions, gradient endpoints, badges |
| `secondaryLight` | `#AD8AFF` | 🟣 | Lighter secondary accents |
| `secondaryDark` | `#6B3FDB` | 🟣 | Pressed secondary states, emphasis |

### 2.3 — Accent Palette

The accent palette is used for eye-catching highlights, call-to-action elements, and data visualization.

| Token | Hex | Swatch | Usage |
|-------|-----|--------|-------|
| `accent` | `#00D1FF` | 🩵 | Accent highlights, links, special callouts |
| `accentLight` | `#66E3FF` | 🩵 | Lighter accent variants |
| `accentDark` | `#009EC2` | 🩵 | Pressed accent states |

---

## 3. Role Color System

Each user role has a dedicated color identity defined in `app_colors.dart`. These colors are injected into dashboards, profile elements, badges, and role-specific UI.

### 3.1 — Role Color Map

| Role | Primary | Secondary | Swatch |
|------|---------|-----------|--------|
| **Student** | `#5B7CFF` | `#3A5AE0` | 🔵 Blue |
| **Teacher** | `#8A5CFF` | `#6B3FDB` | 🟣 Purple |
| **Freelancer** | `#00D1FF` | `#0099CC` | 🩵 Cyan |
| **Company** | `#00E676` | `#00C853` | 🟢 Green |
| **Admin** | `#EF4444` | `#DC2626` | 🔴 Red |
| **Super Admin** | `#8B5CF6` | `#7C3AED` | 🟣 Purple |

### 3.2 — Role Color Tokens

```
AppColors.studentPrimary    → Color(0xFF5B7CFF)
AppColors.studentSecondary  → Color(0xFF3A5AE0)
AppColors.teacherPrimary    → Color(0xFF8A5CFF)
AppColors.teacherSecondary  → Color(0xFF6B3FDB)
AppColors.freelancerPrimary → Color(0xFF00D1FF)
AppColors.freelancerSecondary → Color(0xFF0099CC)
AppColors.companyPrimary    → Color(0xFF00E676)
AppColors.companySecondary  → Color(0xFF00C853)
AppColors.adminPrimary      → Color(0xFFEF4444)
AppColors.adminSecondary    → Color(0xFFDC2626)
AppColors.superAdminPrimary → Color(0xFF8B5CF6)
AppColors.superAdminSecondary → Color(0xFF7C3AED)
```

### 3.3 — Role Color Usage Map

| Role | Files That Use Role Colors |
|------|---------------------------|
| **Student** | `student_dashboard.dart`, `student_profile_screen.dart`, `student_edit_profile_screen.dart`, `student_onboarding_screen.dart`, student course learning screens |
| **Teacher** | `teacher_dashboard.dart`, `teacher_profile_screen.dart`, `teacher_edit_profile_screen.dart`, `teacher_onboarding_screen.dart`, course creation and analytics screens |
| **Freelancer** | `freelancer_dashboard.dart`, `freelancer_profile_screen.dart`, `freelancer_edit_profile_screen.dart`, `freelancer_onboarding_screen.dart` |
| **Company** | `company_dashboard.dart`, `company_profile_screen.dart`, `company_edit_profile_screen.dart`, `company_onboarding_screen.dart`, job posting and hiring pipeline screens |

### 3.4 — Admin & Super Admin

Admin and Super Admin now have dedicated role color tokens for platform governance and system ownership.

---

## 4. Typography System

### 4.1 — Font Families

| Category | Font | Source | Usage |
|----------|------|--------|-------|
| **Display & Headlines** | Outfit | Google Fonts | `displayLarge`, `displayMedium`, `displaySmall`, `headlineLarge`, `headlineMedium`, `headlineSmall` |
| **Body, Title & Labels** | Inter | Google Fonts | `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, `labelSmall` |

### 4.2 — Type Scale

#### Display Styles (Outfit)

| Token | Size | Weight | Letter Spacing | Line Height |
|-------|------|--------|----------------|-------------|
| `displayLarge` | 57 | w700 | -0.25 | 1.12 |
| `displayMedium` | 45 | w600 | — | 1.16 |
| `displaySmall` | 36 | w600 | — | 1.22 |

#### Headline Styles (Outfit)

| Token | Size | Weight | Letter Spacing | Line Height |
|-------|------|--------|----------------|-------------|
| `headlineLarge` | 32 | w600 | — | 1.25 |
| `headlineMedium` | 28 | w500 | — | 1.29 |
| `headlineSmall` | 24 | w500 | — | 1.33 |

#### Title Styles (Inter)

| Token | Size | Weight | Letter Spacing | Line Height |
|-------|------|--------|----------------|-------------|
| `titleLarge` | 22 | w600 | — | 1.27 |
| `titleMedium` | 16 | w600 | 0.15 | 1.5 |
| `titleSmall` | 14 | w600 | 0.1 | 1.43 |

#### Body Styles (Inter)

| Token | Size | Weight | Letter Spacing | Line Height |
|-------|------|--------|----------------|-------------|
| `bodyLarge` | 16 | w400 | 0.5 | 1.5 |
| `bodyMedium` | 14 | w400 | 0.25 | 1.43 |
| `bodySmall` | 12 | w400 | 0.4 | 1.33 |

#### Label Styles (Inter)

| Token | Size | Weight | Letter Spacing | Line Height |
|-------|------|--------|----------------|-------------|
| `labelLarge` | 14 | w600 | 0.1 | 1.43 |
| `labelMedium` | 12 | w600 | 0.5 | 1.33 |
| `labelSmall` | 11 | w500 | 0.5 | 1.45 |

### 4.3 — Typography Source

Defined in: `lib/core/theme/app_typography.dart`

The `AppTypography.textTheme` getter returns a complete `TextTheme` for injection into `ThemeData`.

---

## 5. Gradient System

All gradients are defined as `static const LinearGradient` in `app_colors.dart`.

### 5.1 — Shared Gradients

| Token | Colors | Direction | Usage |
|-------|--------|-----------|-------|
| `primaryGradient` | `primary` → `secondary` (`#5B7CFF` → `#8A5CFF`) | topLeft → bottomRight | Primary action buttons, hero headers, featured elements |
| `accentGradient` | `accent` → `primary` (`#00D1FF` → `#5B7CFF`) | topLeft → bottomRight | Accent highlights, special callouts |
| `surfaceGradient` | `surface` → `background` (`#121A2E` → `#0A0F1F`) | topCenter → bottomCenter | Page backgrounds (dark theme) |
| `cardGradient` | `cardLight` → `card` (`#1A2540` → `#121A2E`) | topLeft → bottomRight | Card backgrounds (dark theme) |

### 5.2 — Light Theme Gradients

| Token | Colors | Direction | Usage |
|-------|--------|-----------|-------|
| `lightSurfaceGradient` | `lightSurface` → `lightBackground` (`#FFFFFF` → `#F3F4F6`) | topCenter → bottomCenter | Page backgrounds (light theme) |
| `lightCardGradient` | `lightCard` → `lightCardLight` (`#FFFFFF` → `#F9FAFB`) | topLeft → bottomRight | Card backgrounds (light theme) |

---

## 6. Surface & Background System

### 6.1 — Dark Theme Surfaces

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#0A0F1F` | App-wide background |
| `scaffoldBackground` | `#0A0F1F` | Scaffold background (matches `background`) |
| `surface` | `#121A2E` | Elevated surfaces, dialogs, bottom sheets |
| `elevatedSurface` | `#18233D` | Higher-elevation surfaces |
| `card` | `#121A2E` | Card backgrounds |
| `cardLight` | `#1A2540` | Lighter card variant |
| `cardBorder` | `#1E2A45` | Card border color |

### 6.2 — Dark Theme Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `textPrimary` | `#FFFFFF` | Primary text on dark surfaces |
| `textSecondary` | `#B0B8CD` | Secondary/subtitle text |
| `textTertiary` | `#6B7494` | Hints, captions, de-emphasized text |
| `textDisabled` | `#3D4560` | Disabled state text |

### 6.3 — Light Theme Surfaces

| Token | Hex | Usage |
|-------|-----|-------|
| `lightBackground` | `#F3F4F6` | App-wide background (light) |
| `lightScaffoldBackground` | `#F3F4F6` | Scaffold background (light) |
| `lightSurface` | `#FFFFFF` | Elevated surfaces (light) |
| `lightElevatedSurface` | `#FFFFFF` | Higher-elevation surfaces (light) |
| `lightCard` | `#FFFFFF` | Card backgrounds (light) |
| `lightCardLight` | `#F9FAFB` | Lighter card variant (light) |
| `lightCardBorder` | `#E5E7EB` | Card border color (light) |

### 6.4 — Light Theme Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `lightTextPrimary` | `#0F172A` | Primary text on light surfaces |
| `lightTextSecondary` | `#334155` | Secondary/subtitle text (light) |
| `lightTextTertiary` | `#475569` | Hints, captions (light) |
| `lightTextDisabled` | `#94A3B8` | Disabled state text (light) |

---

## 7. Semantic Color System

Semantic colors communicate meaning independent of the role or theme context. Defined in `app_colors.dart`.

| Category | Token | Hex | Usage |
|----------|-------|-----|-------|
| **Success** | `success` | `#00E676` | Positive actions, completion states, passed tests |
| **Success** | `successDark` | `#00C853` | Pressed/emphasis success variant |
| **Warning** | `warning` | `#FFAB00` | Cautionary alerts, pending states |
| **Warning** | `warningDark` | `#FF8F00` | Pressed/emphasis warning variant |
| **Error** | `error` | `#FF5252` | Destructive actions, failures, validation errors |
| **Error** | `errorDark` | `#D32F2F` | Pressed/emphasis error variant |
| **Info** | `info` | `#448AFF` | Informational alerts, neutral callouts |

---

## 8. Overlay & Utility Colors

| Token | Value | Usage |
|-------|-------|-------|
| `overlay` | `Black @ 80% opacity` (`0x80000000`) | Modal overlays, dimmed backgrounds |
| `lightOverlay` | `Black @ 40% opacity` (`0x40000000`) | Lighter overlays |
| `divider` | `#1E2A45` | Divider lines (dark theme) |
| `lightDivider` | `#E2E6F0` | Divider lines (light theme) |
| `shimmerBase` | `#1A2540` | Shimmer loading base (dark) |
| `shimmerHighlight` | `#2A3555` | Shimmer loading highlight (dark) |
| `lightShimmerBase` | `#E8EBF2` | Shimmer loading base (light) |
| `lightShimmerHighlight` | `#F5F7FC` | Shimmer loading highlight (light) |

---

## 9. Shared UI Component Library

All shared widgets live in `lib/shared/widgets/`. These are role-agnostic, reusable building blocks.

### 9.1 — Component Inventory

| Component | File | Purpose |
|-----------|------|---------|
| **PrimaryButton** | `primary_button.dart` | Standard primary action button used across the app |
| **CustomTextField** | `custom_text_field.dart` | Styled text input with validation support |
| **DashboardShell** | `dashboard_shell.dart` | Scaffold wrapper for all role dashboards |
| **DashboardHeader** | `dashboard_header.dart` | Standard header with greeting, avatar, and role indicator |
| **DashboardSection** | `dashboard_section.dart` | Titled section container for dashboard content blocks |
| **DashboardEmptyState** | `dashboard_empty_state.dart` | Empty state placeholder for dashboards with no data |
| **MetricCard** | `metric_card.dart` | Numeric stat display card (courses enrolled, jobs posted, etc.) |
| **RecentActivityCard** | `recent_activity_card.dart` | Activity feed item card |
| **QuickActionCard** | `quick_action_card.dart` | Tappable shortcut card for common actions |
| **AnimatedThemeSwitcher** | `animated_theme_switcher.dart` | Animated toggle for dark/light theme switching |
| **AvatarWidget** | `avatar_widget.dart` | User avatar display with fallback initials |
| **LoadingOverlay** | `loading_overlay.dart` | Full-screen loading state overlay |
| **ProfileCompletionCard** | `profile_completion_card.dart` | Progress card showing profile completion percentage |
| **ProfileImagePicker** | `profile_image_picker.dart` | Image picker widget for profile photos |
| **ResponsivePair** | `responsive_pair.dart` | Responsive two-column layout helper |
| **RoleEditProfileForm** | `role_edit_profile_form.dart` | Shared form widget for role-based profile editing |
| **RoleProfileView** | `role_profile_view.dart` | Shared widget for viewing role-specific profiles |

### 9.2 — Profile Feature Widgets

Located in `lib/features/profile/presentation/widgets/`:

| Component | File | Purpose |
|-----------|------|---------|
| **LockStatusCard** | `lock_status_card.dart` | Displays app lock/security status |
| **ProfileNavigationCard** | `profile_navigation_card.dart` | Navigation card within profile settings |
| **ProfileSectionScaffold** | `profile_section_scaffold.dart` | Scaffold for profile sub-sections |
| **SecurityTile** | `security_tile.dart` | Individual security setting row |

### 9.3 — Admin Feature Widgets

Located in `lib/features/admin/presentation/widgets/`:

| Component | File | Purpose |
|-----------|------|---------|
| **AdminControlScaffold** | `admin_control_scaffold.dart` | Scaffold wrapper for admin control panels |

### 9.4 — Job Feature Widgets

Located in `lib/features/jobs/presentation/widgets/`:

| Component | File | Purpose |
|-----------|------|---------|
| **JobCard** | `job_card.dart` | Job listing card component |

### 9.5 — Application Feature Widgets

Located in `lib/features/applications/presentation/widgets/`:

| Component | File | Purpose |
|-----------|------|---------|
| **ApplicantCard** | `applicant_card.dart` | Card displaying applicant info (company view) |
| **ApplicationCard** | `application_card.dart` | Card displaying application status (student/freelancer view) |

---

## 10. LMS UI Component Library

The LMS (Learning Management System) UI library lives in `lib/shared/widgets/lms_ui/`. These components implement a glassmorphism-inspired design language for course-related interfaces.

### 10.1 — LMS Component Inventory

| Component | File | Purpose |
|-----------|------|---------|
| **LmsCourseCard** | `lms_course_card.dart` | Course listing card with progress indicator |
| **LmsAssignmentCard** | `lms_assignment_card.dart` | Assignment listing card with status |
| **LmsTestCard** | `lms_test_card.dart` | Grand test listing card |
| **LmsGlassPageScaffold** | `lms_glass_page_scaffold.dart` | Glassmorphism page scaffold for LMS screens |
| **LmsHeroHeader** | `lms_hero_header.dart` | Large hero header for course/lesson detail screens |
| **LmsProgressCard** | `lms_progress_card.dart` | Visual progress tracking card |
| **LmsSectionCard** | `lms_section_card.dart` | Section container for LMS content |
| **LmsActionTile** | `lms_action_tile.dart` | Tappable action tile for LMS workflows |
| **LmsStatusBadge** | `lms_status_badge.dart` | Status indicator badge (completed, in progress, locked) |
| **LmsEmptyState** | `lms_empty_state.dart` | Empty state for LMS screens with no content |

### 10.2 — Design Language

The LMS UI library uses:

- **Glassmorphism** — Semi-transparent surfaces with blur effects via `LmsGlassPageScaffold`
- **Hero headers** — Large gradient headers with course metadata via `LmsHeroHeader`
- **Status badges** — Color-coded status indicators via `LmsStatusBadge`
- **Progress visualization** — Linear and radial progress indicators via `LmsProgressCard`

---

## 11. Dashboard Component Standards

Every role dashboard follows a standardized composition pattern using shared widgets.

### 11.1 — Dashboard Composition

```
DashboardShell
├── DashboardHeader (greeting, avatar, role badge)
├── MetricCard × N (role-specific KPIs)
├── DashboardSection
│   ├── LmsCourseCard / QuickActionCard / JobCard (varies by role)
│   └── ...
├── RecentActivityCard × N
└── ProfileCompletionCard (if profile incomplete)
```

### 11.2 — Dashboard File Map

| Role | Dashboard File | Theme Color Token |
|------|---------------|-------------------|
| Student | `features/student/presentation/student_dashboard.dart` | `AppColors.studentPrimary` |
| Teacher | `features/teacher/presentation/teacher_dashboard.dart` | `AppColors.teacherPrimary` |
| Company | `features/company/presentation/company_dashboard.dart` | `AppColors.companyPrimary` |
| Freelancer | `features/freelancer/presentation/freelancer_dashboard.dart` | `AppColors.freelancerPrimary` |
| Admin | `features/admin/presentation/admin_dashboard.dart` | Platform primary palette |
| Super Admin | `features/admin/presentation/super_admin_dashboard.dart` | Platform primary palette |

---

## 12. Theme File Reference

### 12.1 — Complete Theme File Index

| File | Path | Contents |
|------|------|----------|
| `app_colors.dart` | `lib/core/theme/app_colors.dart` | All color constants: primary, secondary, accent, semantic, surfaces (dark + light), overlays, shimmer, role-specific, gradients |
| `app_theme.dart` | `lib/core/theme/app_theme.dart` | `ThemeData` assembly — composes colors and typography into dark and light `ThemeData` objects |
| `app_typography.dart` | `lib/core/theme/app_typography.dart` | Complete `TextTheme` from Google Fonts Outfit (display/headline) and Inter (body/title/label) |

### 12.2 — Theme Provider

| File | Path | Purpose |
|------|------|---------|
| `theme_provider.dart` | `lib/providers/theme_provider.dart` | Riverpod `NotifierProvider` that manages `ThemeMode` (dark/light/system) |

### 12.3 — Theme Switcher Widget

| File | Path | Purpose |
|------|------|---------|
| `animated_theme_switcher.dart` | `lib/shared/widgets/animated_theme_switcher.dart` | Animated toggle widget for switching between dark and light themes |

---

## 13. Action Color Standards

### Role Primary Color
Used for:
- main page identity
- hero accents
- selected navigation
- primary CTA
- role badges

### Semantic Colors
Used for:
- status
- warnings
- success
- failure
- destructive actions

### Action Colors

- **Courses:** Role Primary Color
- **Lessons:** `AppColors.info`
- **Assignments:** `AppColors.warning`
- **Projects:** `AppColors.accent`
- **Grand Tests:** `AppColors.secondary`
- **Certificates:** Gold / Achievement color (If no gold token exists, use future token: `AppColors.certificateGold = #F59E0B`)
- **Analytics:** `AppColors.primary` or Indigo-style platform analytics color
- **Jobs:** `AppColors.companyPrimary` or `AppColors.success`
- **Interviews:** Teal / Cyan (Prefer `AppColors.accent` if no teal token exists)
- **Users:** `AppColors.info`
- **Verification:** `AppColors.success`
- **Audit Logs:** Neutral / textSecondary / slate style
- **Settings:** Neutral / platform primary
- **Danger:** `AppColors.error` / `AppColors.errorDark`

---

## 14. Dashboard Metric Color Standards

- **Total Users:** `AppColors.info`
- **Active Users:** `AppColors.success`
- **Courses:** Role Primary Color
- **Assignments:** `AppColors.warning`
- **Projects:** `AppColors.accent`
- **Grand Tests:** `AppColors.secondary`
- **Certificates:** `AppColors.certificateGold` future token or `#F59E0B`
- **Jobs:** `AppColors.companyPrimary`
- **Applications:** `AppColors.info`
- **Interviews:** `AppColors.accent`
- **Revenue / Growth:** `AppColors.success`
- **System Health:** `AppColors.success`
- **Warnings:** `AppColors.warning`
- **Errors / Critical:** `AppColors.error`

---

## 15. Color Restrictions

### Gold
**Reserved for:**
- certificates
- achievements
- excellence
- awards

**Do not use Gold for:**
- normal buttons
- generic dashboard accents
- destructive actions

### Red
**Reserved for:**
- admin identity
- destructive actions
- failures
- critical warnings
- recovery center

**Do not use Red for:**
- normal CTAs
- success states
- neutral actions

### Green
**Reserved for:**
- company identity
- success
- verification
- growth

**Do not use Green for:**
- warning states
- destructive actions

### Purple
**Reserved for:**
- teacher identity
- grand tests
- super admin identity

**Do not use Purple randomly for unrelated cards.**

### Cyan
**Reserved for:**
- freelancer identity
- projects
- innovation/AI/accent experiences

---

## 16. Role Authority Hierarchy

- **Student:** Level 1 — Learning identity. Friendly, gamified, progress-heavy.
- **Teacher:** Level 2 — Academic authority. Structured, analytical, mentorship-focused.
- **Freelancer:** Level 2 — Independent professional. Portfolio, project, skill showcase focused.
- **Company:** Level 3 — Hiring authority. Pipeline, candidate, business metrics focused.
- **Admin:** Level 4 — Platform governance. Moderation, security, control focused.
- **Super Admin:** Level 5 — System ownership. Critical controls, platform health, global settings focused.

---

## 17. Role Color Usage Rules

- **Student:**
  - Use `studentPrimary` for page identity and main CTAs.
  - Use semantic colors for status only.
- **Teacher:**
  - Use `teacherPrimary` for teacher dashboard identity.
  - Assignments/projects/grand tests may use semantic action colors, but `teacherPrimary` should remain the page identity.
- **Company:**
  - Use `companyPrimary` for hiring identity.
  - Interviews/jobs can use action colors while keeping `companyPrimary` as root identity.
- **Freelancer:**
  - Use `freelancerPrimary` for freelancer identity.
  - Portfolio/projects can use accent/cyan.
- **Admin:**
  - Use `adminPrimary` for admin identity.
  - Use `error` only for destructive actions.
- **Super Admin:**
  - Use `superAdminPrimary` for system ownership identity.
  - Use `error` only for destructive or emergency actions.

---

> **End of Design System Document**
>
> This document reflects the current state of the SkillForge AI design system as implemented in the repository. All values were extracted directly from source files. No values were invented or assumed.
