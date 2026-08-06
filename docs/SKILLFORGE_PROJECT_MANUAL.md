# SkillForge AI — Project Manual

> **Version:** 1.0.0
> **Last Updated:** 2026-06-23 (historical inventory; see 31 July 2026 capability update below)
> **Platform:** Flutter (Mobile / Web / Desktop)
> **Source of Truth:** Live repository at `lib/`
> **Status:** Active — All data verified from codebase

---

## Current capability update — 31 July 2026

This manual’s detailed inventory predates several shipped surfaces. Treat the following as additive to its older screen and route counts; use [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`CURRENT_PROJECT_STATUS.md`](CURRENT_PROJECT_STATUS.md) for the canonical current map:

- **Post-hire employee lifecycle:** Company Employees (`/company/employees`) and Student/Freelancer My Employment (`/my-employment`), offer-letter PDF preview/print/share, welcome pack, Cloudinary documents, onboarding, thin HR thread, optional probation, offboarding, and client reminders.
- **Paid-course commerce:** Student Paid Courses (`/student/courses/paid`) with receipts/access and Teacher Wallet (`/teacher/wallet`) with course-sale balances stored on `teachers/{uid}`. Wallet release/withdraw is demo-only, not a bank transfer.
- **Unified in-app notifications:** `/notifications` inbox, event/service writers, and navigation bells. The employment HR thread is intentionally not a general real-time chat product.
- **Firestore rules deployment:** Rules source is size/complexity constrained; deploy with `node scripts/deploy-firestore-rules.js` and retain the documented ~195 KB source target.

---

## Table of Contents

1. [Project Identity](#1-project-identity)
2. [Technology Stack](#2-technology-stack)
3. [Project Structure](#3-project-structure)
4. [Architecture](#4-architecture)
5. [Module Inventory](#5-module-inventory)
6. [User Roles](#6-user-roles)
7. [Feature Inventory](#7-feature-inventory)
8. [Routing System](#8-routing-system)
9. [Provider Architecture](#9-provider-architecture)
10. [Repository Layer](#10-repository-layer)
11. [Model Layer](#11-model-layer)
12. [Services Layer](#12-services-layer)
13. [Theme System](#13-theme-system)
14. [Dashboard System](#14-dashboard-system)
15. [Screen Inventory](#15-screen-inventory)

---

## 1. Project Identity

| Field | Value |
|-------|-------|
| **Project Name** | SkillForge AI |
| **Package Name** | `skillforge_ai` |
| **Description** | Multi-role ecosystem platform for Students, Teachers, Freelancers, and Companies |
| **Version** | 1.0.0+1 |
| **Platform Type** | Flutter Application (Mobile / Web / Desktop) |
| **Core Vision** | Role isolation, shared foundations, AI-first features, Admin sovereignty, offline resilience, scalability |
| **Publish** | Private (`publish_to: 'none'`) |

---

## 2. Technology Stack

### 2.1 — Core

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Flutter | SDK ^3.11.5 |
| Language | Dart | ^3.11.5 |
| State Management | flutter_riverpod | ^3.3.1 |
| Routing | go_router | ^17.2.3 |

### 2.2 — Firebase

| Service | Package | Version |
|---------|---------|---------|
| Core | firebase_core | ^4.9.0 |
| Authentication | firebase_auth | ^6.5.1 |
| Database | cloud_firestore | ^6.4.1 |

### 2.3 — UI & Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| google_fonts | ^6.2.1 | Typography (Outfit + Inter) |
| cupertino_icons | ^1.0.8 | iOS-style icons |
| image_picker | ^1.2.1 | Profile photo selection |
| intl | ^0.20.2 | Date/number formatting, localization |
| http | ^1.6.0 | HTTP client for external APIs |
| flutter_secure_storage | ^10.3.1 | Secure local key-value storage |
| crypto | ^3.0.7 | Hashing utilities |
| local_auth | ^3.0.1 | Biometric authentication |

---

## 3. Project Structure

### 3.1 — Root Directory

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Generated Firebase config
├── app/                               # Application shell (router, app widget)
├── core/                              # Cross-cutting concerns (theme, constants, utils, services)
├── features/                          # Feature modules (role-specific + shared)
├── models/                            # Global data models
├── providers/                         # Global Riverpod providers
├── repositories/                      # Global repository interfaces + implementations
└── shared/                            # Shared UI widgets
```

### 3.2 — App Layer

```
app/
├── app.dart                           # Root MaterialApp.router widget
└── router/
    ├── app_router.dart                # GoRouter configuration + redirect guards
    └── route_names.dart               # RouteNames + RoutePaths constants
```

### 3.3 — Core Layer

```
core/
├── config/
│   └── cloudinary_config.dart         # Cloudinary service configuration
├── constants/
│   └── app_constants.dart             # App-wide constant values
├── errors/
│   └── app_exceptions.dart            # Application exception hierarchy
├── services/
│   ├── app_lock_service.dart          # App lock (PIN) management
│   ├── biometric_service.dart         # Biometric authentication service
│   └── cloudinary_service.dart        # Cloudinary upload service
├── theme/
│   ├── app_colors.dart                # Centralized color system (dark + light)
│   ├── app_theme.dart                 # ThemeData assembly
│   └── app_typography.dart            # TextTheme (Outfit + Inter)
└── utils/
    ├── profile_completion.dart        # Profile completion calculation
    └── validators.dart                # Input validation (email, password, etc.)
```

### 3.4 — Features Layer

```
features/
├── admin/                             # Admin + Super Admin
├── applications/                      # Job applications
├── auth/                              # Authentication (login, signup, etc.)
├── company/                           # Company role
├── courses/                           # LMS: courses, lessons, assignments, tests, certificates
├── freelancer/                        # Freelancer role
├── home/                              # Public landing screen
├── interviews/                        # Interview scheduling and evaluation
├── jobs/                              # Job listings and management
├── legal/                             # Legal pages (privacy, terms, deletion)
├── onboarding/                        # Splash, app onboarding, role selection
├── profile/                           # Shared profile management
├── security/                          # App lock, PIN management
├── settings/                          # App settings (theme, language, motion)
├── student/                           # Student role
├── system/                            # System screens (maintenance)
└── teacher/                           # Teacher role
```

### 3.5 — Shared Layer

```
shared/
└── widgets/
    ├── animated_theme_switcher.dart
    ├── avatar_widget.dart
    ├── custom_text_field.dart
    ├── dashboard_empty_state.dart
    ├── dashboard_header.dart
    ├── dashboard_section.dart
    ├── dashboard_shell.dart
    ├── loading_overlay.dart
    ├── metric_card.dart
    ├── primary_button.dart
    ├── profile_completion_card.dart
    ├── profile_image_picker.dart
    ├── quick_action_card.dart
    ├── recent_activity_card.dart
    ├── responsive_pair.dart
    ├── role_edit_profile_form.dart
    ├── role_profile_view.dart
    └── lms_ui/
        ├── lms_action_tile.dart
        ├── lms_assignment_card.dart
        ├── lms_course_card.dart
        ├── lms_empty_state.dart
        ├── lms_glass_page_scaffold.dart
        ├── lms_hero_header.dart
        ├── lms_progress_card.dart
        ├── lms_section_card.dart
        ├── lms_status_badge.dart
        └── lms_test_card.dart
```

---

## 4. Architecture

### 4.1 — Architectural Pattern

SkillForge AI uses a **hybrid architecture** combining:

- **Layer-first** organization at the global level (`core/`, `models/`, `providers/`, `repositories/`)
- **Feature-first** organization inside `features/` with each feature potentially containing its own `data/`, `domain/`, `presentation/`, and `providers/` sub-directories

### 4.2 — Dependency Flow

```
features/ → providers/ → repositories/ → core/
                ↕
           shared/widgets/
```

Dependencies flow **inward**. Features depend on global providers and repositories. Features **do not** import from other features.

### 4.3 — Feature Module Contract

Every feature module follows this structure:

```
features/<feature_name>/
├── data/                    # (Optional) Models and repositories
│   ├── models/
│   ├── repositories/
│   └── services/
├── domain/                  # (Optional) Business logic services
│   └── services/
├── presentation/            # (Mandatory) Screens and widgets
│   ├── <screen>.dart
│   └── widgets/
└── providers/               # (Optional) Feature-local Riverpod providers
```

### 4.4 — Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| Global `models/` directory | Models like `UserModel` are shared across all features; co-locating with one feature would create cross-feature imports |
| Global `providers/` directory | Providers used by the router or 2+ features must be globally accessible |
| Global `repositories/` directory | Repository interfaces and implementations are shared infrastructure |
| Feature-local `providers/` | Providers used by exactly one feature are kept inside that feature for encapsulation |
| Feature-local `data/` | Feature-specific models and repositories (e.g., course models inside `features/courses/`) are co-located with the feature |

---

## 5. Module Inventory

### 5.1 — Complete Module List

| Module | Path | Purpose | Has Data Layer | Has Providers |
|--------|------|---------|:-:|:-:|
| `auth` | `features/auth/` | Login, signup, password reset, account blocked | ✗ (uses global) | ✗ |
| `onboarding` | `features/onboarding/` | Splash, app intro, role selection | ✗ | ✗ |
| `student` | `features/student/` | Student dashboard, profile, onboarding | ✗ | ✗ |
| `teacher` | `features/teacher/` | Teacher dashboard, profile, onboarding | ✗ | ✗ |
| `company` | `features/company/` | Company dashboard, profile, onboarding | ✗ | ✗ |
| `freelancer` | `features/freelancer/` | Freelancer dashboard, profile, onboarding | ✗ | ✗ |
| `admin` | `features/admin/` | Admin + Super Admin dashboards, user management, settings | ✗ | ✗ |
| `courses` | `features/courses/` | Full LMS: courses, lessons, assignments, projects, grand tests, certificates, skill scores, resumes | ✔ | ✔ |
| `jobs` | `features/jobs/` | Job listings, creation, editing, job matching | ✔ (services) | ✗ |
| `interviews` | `features/interviews/` | Interview scheduling, evaluation, hiring pipeline | ✗ | ✗ |
| `applications` | `features/applications/` | Job applications (student/freelancer + company views) | ✗ | ✗ |
| `profile` | `features/profile/` | Shared profile sections (personal, professional, security, settings) | ✗ | ✗ |
| `settings` | `features/settings/` | Theme, language, motion settings | ✔ | ✔ |
| `security` | `features/security/` | App lock, PIN management | ✗ | ✗ |
| `legal` | `features/legal/` | Privacy policy, terms of service, account deletion policy | ✗ | ✗ |
| `home` | `features/home/` | Public landing screen | ✗ | ✗ |
| `system` | `features/system/` | Maintenance screen | ✗ | ✗ |

---

## 6. User Roles

### 6.1 — Role Definitions

| Role | Purpose | Scope |
|------|---------|-------|
| **Student** | Learn courses, complete assignments, earn certificates, build smart resumes | Access to LMS student views, job applications |
| **Teacher** | Create courses, manage content, evaluate students, track progress | Access to LMS teacher views, course management |
| **Company** | Post jobs, manage hiring pipelines, schedule and evaluate interviews | Access to job management, applicant tracking, interviews |
| **Freelancer** | Build portfolio, apply for jobs | Access to freelancer profile, job applications |
| **Admin** | Moderate platform, manage users, review verification requests, view audit logs | Access to admin dashboard, user management, settings |
| **Super Admin** | Full platform control — manage admins, system configuration, all admin capabilities | Access to super admin dashboard, admin management, all admin features |

### 6.2 — Role Key Screens

| Role | Dashboard | Profile | Onboarding | Edit Profile |
|------|-----------|---------|------------|--------------|
| Student | `student_dashboard.dart` | `student_profile_screen.dart` | `student_onboarding_screen.dart` | `student_edit_profile_screen.dart` |
| Teacher | `teacher_dashboard.dart` | `teacher_profile_screen.dart` | `teacher_onboarding_screen.dart` | `teacher_edit_profile_screen.dart` |
| Company | `company_dashboard.dart` | `company_profile_screen.dart` | `company_onboarding_screen.dart` | `company_edit_profile_screen.dart` |
| Freelancer | `freelancer_dashboard.dart` | `freelancer_profile_screen.dart` | `freelancer_onboarding_screen.dart` | `freelancer_edit_profile_screen.dart` |
| Admin | `admin_dashboard.dart` | — | — | — |
| Super Admin | `super_admin_dashboard.dart` | — | — | — |

### 6.3 — Role Color Identity

| Role | Primary Color | Secondary Color |
|------|--------------|-----------------|
| Student | `#5B7CFF` | `#3A5AE0` |
| Teacher | `#8A5CFF` | `#6B3FDB` |
| Freelancer | `#00D1FF` | `#0099CC` |
| Company | `#00E676` | `#00C853` |
| Admin | Platform primary | Platform primary |
| Super Admin | Platform primary | Platform primary |

---

## 7. Feature Inventory

### 7.1 — Student Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| Course Discovery | Implemented | `student_course_discovery_screen.dart` |
| Course Enrollment | Implemented | `student_enrolled_courses_screen.dart`, `enrollment_model.dart` |
| Course Learning | Implemented | `student_course_learning_screen.dart`, `lesson_detail_screen.dart` |
| MCQ Assignments | Implemented | `mcq_attempt_screen.dart`, `mcq_result_screen.dart`, `mcq_assignment_model.dart` |
| Project Assignments | Implemented | `project_submission_screen.dart`, `project_submission_status_screen.dart` |
| Grand Tests | Implemented | `student_grand_test_overview_screen.dart`, `grand_test_attempt_screen.dart`, `grand_test_result_screen.dart` |
| Certificates | Implemented | `my_certificates_screen.dart`, `certificate_detail_screen.dart`, `certificate_model.dart` |
| Skill Scores | Implemented | `my_skill_scores_screen.dart`, `skill_score_detail_screen.dart`, `skill_score_model.dart` |
| Smart Resume | Implemented | `smart_resume_screen.dart`, `resume_preview_screen.dart`, `smart_resume_model.dart` |
| Job Applications | Implemented | `my_applications_screen.dart`, `application_card.dart` |
| Interviews | Implemented | `my_interviews_screen.dart`, `interview_detail_screen.dart` |

### 7.2 — Teacher Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| Course Management | Implemented | `teacher_course_screen.dart`, `course_model.dart` |
| Lesson Builder | Implemented | `teacher_lessons_screen.dart`, `lesson_editor_screen.dart`, `lesson_model.dart` |
| MCQ Assignment Management | Implemented | `teacher_assignments_screen.dart`, `create_edit_mcq_assignment_screen.dart` |
| Project Assignment Management | Implemented | `project_assignments_screen.dart`, `project_assignment_editor_screen.dart` |
| Project Evaluation | Implemented | `project_submissions_screen.dart`, `project_review_screen.dart` |
| Grand Test Management | Implemented | `teacher_grand_tests_screen.dart`, `create_edit_grand_test_screen.dart` |
| Grand Test Eligibility | Implemented | `grand_test_eligibility_screen.dart`, `eligible_students_screen.dart` |
| Certificate Management | Implemented | `certificate_management_screen.dart` |
| Student Progress Analytics | Implemented | Route: `teacher-student-progress` |
| Assignment Results | Implemented | `assignment_results_screen.dart` |

### 7.3 — Company Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| Job Posting | Implemented | `create_edit_job_screen.dart`, `company_jobs_screen.dart`, `job_model.dart` |
| Job Listings | Implemented | `job_list_screen.dart`, `job_detail_screen.dart` |
| Applicant Management | Implemented | `job_applicants_screen.dart`, `applicant_card.dart` |
| Hiring Pipeline | Implemented | `hiring_pipeline_screen.dart` |
| Interview Scheduling | Implemented | `schedule_interview_screen.dart` |
| Interview Evaluation | Implemented | `candidate_evaluation_screen.dart` |
| Job Matching | Implemented | `job_matching_service.dart`, `job_match_model.dart` |

### 7.4 — Freelancer Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| Freelancer Profile | Implemented | `freelancer_profile_screen.dart`, `freelancer_edit_profile_screen.dart` |
| Job Applications | Implemented | `my_applications_screen.dart` (shared with Student) |

### 7.5 — Admin Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| User Management | Implemented | `user_management_screen.dart`, `admin_user_management_screen.dart` |
| Admin Management | Implemented | `admin_management_screen.dart` |
| Verification Center | Implemented | `verification_center_screen.dart`, `verification_request.dart` |
| Audit Logs | Implemented | `audit_logs_screen.dart`, `audit_log.dart` |
| Platform Settings | Implemented | `platform_settings_screen.dart`, `admin_platform_settings_screen.dart` |
| Theme Settings | Implemented | `admin_theme_settings_screen.dart`, `theme_settings_model.dart` |
| Motion Settings | Implemented | `admin_motion_settings_screen.dart`, `motion_settings_model.dart` |
| Language Settings | Implemented | `admin_language_settings_screen.dart`, `language_settings_model.dart` |
| Admin Recovery | Implemented | `admin_recovery_screen.dart` |

### 7.6 — Shared / Cross-Role Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| Authentication | Implemented | `login_screen.dart`, `signup_screen.dart`, `forgot_password_screen.dart`, `account_blocked_screen.dart` |
| Onboarding | Implemented | `splash_screen.dart`, `app_onboarding_screen.dart`, `role_selection_screen.dart` |
| Profile Management | Implemented | `personal_information_screen.dart`, `professional_information_screen.dart`, `skills_portfolio_screen.dart`, `account_settings_screen.dart`, `notification_settings_screen.dart`, `preference_settings_screen.dart`, `security_settings_screen.dart` |
| App Security | Implemented | `app_lock_screen.dart`, `pin_management_screen.dart` |
| Legal | Implemented | `privacy_policy_screen.dart`, `terms_of_service_screen.dart`, `account_deletion_policy_screen.dart` |
| Maintenance | Implemented | `maintenance_screen.dart` |

---

## 8. Routing System

### 8.1 — Architecture

| Aspect | Value |
|--------|-------|
| Library | `go_router` ^17.2.3 |
| Configuration File | `lib/app/router/app_router.dart` |
| Constants File | `lib/app/router/route_names.dart` |
| Guard Architecture | Centralized redirect guards (auth, role, onboarding, admin) |

### 8.2 — Route Name Constants (`RouteNames`)

#### Public & Auth Routes

| Constant | Value |
|----------|-------|
| `splash` | `'splash'` |
| `home` | `'home'` |
| `appOnboarding` | `'app-onboarding'` |
| `login` | `'login'` |
| `signup` | `'signup'` |
| `forgotPassword` | `'forgot-password'` |
| `accountBlocked` | `'account-blocked'` |
| `maintenance` | `'maintenance'` |
| `appLock` | `'app-lock'` |
| `roleSelection` | `'role-selection'` |

#### Legal Routes

| Constant | Value |
|----------|-------|
| `privacyPolicy` | `'privacy-policy'` |
| `termsOfService` | `'terms-of-service'` |
| `accountDeletionPolicy` | `'account-deletion-policy'` |

#### Onboarding Routes

| Constant | Value |
|----------|-------|
| `studentOnboarding` | `'student-onboarding'` |
| `teacherOnboarding` | `'teacher-onboarding'` |
| `freelancerOnboarding` | `'freelancer-onboarding'` |
| `companyOnboarding` | `'company-onboarding'` |

#### Dashboard Routes

| Constant | Value |
|----------|-------|
| `studentDashboard` | `'student-dashboard'` |
| `teacherDashboard` | `'teacher-dashboard'` |
| `freelancerDashboard` | `'freelancer-dashboard'` |
| `companyDashboard` | `'company-dashboard'` |
| `adminDashboard` | `'admin-dashboard'` |
| `superAdminDashboard` | `'super-admin-dashboard'` |

#### Student Sub-Routes

| Constant | Value |
|----------|-------|
| `studentCourses` | `'student-courses'` |
| `studentCourseDetail` | `'student-course-detail'` |
| `studentEnrolledCourses` | `'student-enrolled-courses'` |
| `studentCourseLearn` | `'student-course-learn'` |
| `studentLessonDetail` | `'student-lesson-detail'` |
| `studentAssignments` | `'student-assignments'` |
| `studentAssignmentAttempt` | `'student-assignment-attempt'` |
| `studentAssignmentResult` | `'student-assignment-result'` |
| `studentProjectSubmission` | `'student-project-submission'` |
| `studentProjectStatus` | `'student-project-status'` |
| `studentGrandTestOverview` | `'student-grand-test-overview'` |
| `studentGrandTestAttempt` | `'student-grand-test-attempt'` |
| `studentGrandTestResult` | `'student-grand-test-result'` |
| `studentCertificates` | `'student-certificates'` |
| `studentCertificateDetail` | `'student-certificate-detail'` |
| `studentSkillScores` | `'student-skill-scores'` |
| `studentSkillScoreDetail` | `'student-skill-score-detail'` |
| `studentResume` | `'student-resume'` |
| `studentResumePreview` | `'student-resume-preview'` |

#### Teacher Sub-Routes

| Constant | Value |
|----------|-------|
| `teacherCourses` | `'teacher-courses'` |
| `teacherCourseCreate` | `'teacher-course-create'` |
| `teacherCourseEdit` | `'teacher-course-edit'` |
| `teacherCourseDetail` | `'teacher-course-detail'` |
| `teacherCourseLessons` | `'teacher-course-lessons'` |
| `teacherLessonCreate` | `'teacher-lesson-create'` |
| `teacherLessonEdit` | `'teacher-lesson-edit'` |
| `teacherAssignments` | `'teacher-assignments'` |
| `teacherAssignmentCreate` | `'teacher-assignment-create'` |
| `teacherAssignmentEdit` | `'teacher-assignment-edit'` |
| `teacherAssignmentResults` | `'teacher-assignment-results'` |
| `teacherProjectAssignments` | `'teacher-project-assignments'` |
| `teacherProjectAssignmentCreate` | `'teacher-project-assignment-create'` |
| `teacherProjectAssignmentEdit` | `'teacher-project-assignment-edit'` |
| `teacherProjectSubmissions` | `'teacher-project-submissions'` |
| `teacherProjectReview` | `'teacher-project-review'` |
| `teacherGrandTests` | `'teacher-grand-tests'` |
| `teacherGrandTestCreate` | `'teacher-grand-test-create'` |
| `teacherGrandTestEdit` | `'teacher-grand-test-edit'` |
| `teacherGrandTestEligibility` | `'teacher-grand-test-eligibility'` |
| `teacherGrandTestAttempts` | `'teacher-grand-test-attempts'` |
| `teacherCertificates` | `'teacher-certificates'` |
| `teacherCertificateEligible` | `'teacher-certificate-eligible'` |
| `teacherStudentProgress` | `'teacher-student-progress'` |
| `teacherStudentProgressDetail` | `'teacher-student-progress-detail'` |

#### Profile & Security Routes

| Constant | Value |
|----------|-------|
| `studentProfile` | `'student-profile'` |
| `studentEditProfile` | `'student-edit-profile'` |
| `teacherProfile` | `'teacher-profile'` |
| `teacherEditProfile` | `'teacher-edit-profile'` |
| `freelancerProfile` | `'freelancer-profile'` |
| `freelancerEditProfile` | `'freelancer-edit-profile'` |
| `companyProfile` | `'company-profile'` |
| `companyEditProfile` | `'company-edit-profile'` |
| `securitySettings` | `'security-settings'` |
| `setupPin` | `'setup-pin'` |
| `changePin` | `'change-pin'` |
| `disablePin` | `'disable-pin'` |
| `profilePersonal` | `'profile-personal'` |
| `profileProfessional` | `'profile-professional'` |
| `profilePortfolio` | `'profile-portfolio'` |
| `profilePreferences` | `'profile-preferences'` |
| `profileNotifications` | `'profile-notifications'` |
| `profileAccountSettings` | `'profile-account-settings'` |

#### Admin Routes

| Constant | Value |
|----------|-------|
| `adminUserManagement` | `'admin-user-management'` |
| `adminManagement` | `'admin-management'` |
| `adminRecovery` | `'admin-recovery'` |
| `adminVerification` | `'admin-verification'` |
| `adminSettings` | `'admin-settings'` |
| `adminThemeSettings` | `'admin-theme-settings'` |
| `adminMotionSettings` | `'admin-motion-settings'` |
| `adminLanguageSettings` | `'admin-language-settings'` |
| `adminAuditLogs` | `'admin-audit-logs'` |

#### Job & Interview Routes

| Constant | Value |
|----------|-------|
| `jobList` | `'job-list'` |
| `jobDetail` | `'job-detail'` |
| `createJob` | `'create-job'` |
| `editJob` | `'edit-job'` |
| `companyJobs` | `'company-jobs'` |
| `hiringPipeline` | `'hiring-pipeline'` |
| `jobHiringPipeline` | `'job-hiring-pipeline'` |
| `scheduleInterview` | `'schedule-interview'` |
| `interviewDetail` | `'interview-detail'` |
| `evaluateInterview` | `'evaluate-interview'` |
| `myApplications` | `'my-applications'` |
| `jobApplicants` | `'job-applicants'` |
| `myInterviews` | `'my-interviews'` |
| `myInterviewDetail` | `'my-interview-detail'` |

### 8.3 — Route Paths (`RoutePaths`)

#### Public & Auth Paths

| Path | Destination |
|------|-------------|
| `/` | Splash screen |
| `/home` | Public landing |
| `/app-onboarding` | App introduction |
| `/login` | Login screen |
| `/signup` | Signup screen |
| `/forgot-password` | Password reset |
| `/account-blocked` | Account blocked screen |
| `/maintenance` | Maintenance screen |
| `/app-lock` | App lock screen |
| `/role-selection` | Role selection |

#### Legal Paths

| Path | Destination |
|------|-------------|
| `/legal/privacy-policy` | Privacy policy |
| `/legal/terms-of-service` | Terms of service |
| `/legal/account-deletion-policy` | Account deletion policy |

#### Onboarding Paths

| Path | Destination |
|------|-------------|
| `/onboarding/student` | Student onboarding |
| `/onboarding/teacher` | Teacher onboarding |
| `/onboarding/freelancer` | Freelancer onboarding |
| `/onboarding/company` | Company onboarding |

#### Dashboard Paths

| Path | Destination |
|------|-------------|
| `/dashboard/student` | Student dashboard |
| `/dashboard/teacher` | Teacher dashboard |
| `/dashboard/freelancer` | Freelancer dashboard |
| `/dashboard/company` | Company dashboard |
| `/dashboard/admin` | Admin dashboard |
| `/dashboard/super-admin` | Super Admin dashboard |

#### Student LMS Paths

| Path | Destination |
|------|-------------|
| `/student/courses` | Course discovery |
| `/student/courses/detail/:courseId` | Course detail |
| `/student/courses/enrolled` | Enrolled courses |
| `/student/courses/learn/:courseId` | Course learning |
| `/student/courses/lesson/:courseId/:lessonId` | Lesson detail |
| `/student/courses/assignments/:courseId` | Assignments list |
| `/student/courses/assignments/mcq/:courseId/:assignmentId` | MCQ attempt |
| `/student/courses/assignments/result/:courseId/:assignmentId` | Assignment result |
| `/student/courses/project/submit/:courseId/:assignmentId` | Project submission |
| `/student/courses/project/status/:courseId/:assignmentId` | Project status |
| `/student/courses/grand-test/:courseId` | Grand test overview |
| `/student/courses/grand-test/attempt/:courseId/:grandTestId` | Grand test attempt |
| `/student/courses/grand-test/result/:courseId/:grandTestId` | Grand test result |
| `/student/certificates` | Certificates list |
| `/student/certificates/detail/:certificateId` | Certificate detail |
| `/student/skill-scores` | Skill scores list |
| `/student/skill-scores/detail/:skillName` | Skill score detail |
| `/student/resume` | Smart resume |
| `/student/resume/preview` | Resume preview |

#### Teacher LMS Paths

| Path | Destination |
|------|-------------|
| `/teacher/courses` | Teacher courses |
| `/teacher/courses/create` | Create course |
| `/teacher/courses/edit/:courseId` | Edit course |
| `/teacher/courses/detail/:courseId` | Course detail |
| `/teacher/courses/lessons/:courseId` | Lessons list |
| `/teacher/courses/lessons/create/:courseId` | Create lesson |
| `/teacher/courses/lessons/edit/:courseId/:lessonId` | Edit lesson |
| `/teacher/courses/assignments/:courseId` | Assignments list |
| `/teacher/courses/assignments/create/:courseId` | Create MCQ assignment |
| `/teacher/courses/assignments/edit/:courseId/:assignmentId` | Edit MCQ assignment |
| `/teacher/courses/assignments/results/:courseId/:assignmentId` | Assignment results |
| `/teacher/courses/assignments/project/:courseId` | Project assignments |
| `/teacher/courses/assignments/project/create/:courseId` | Create project assignment |
| `/teacher/courses/assignments/project/edit/:courseId/:assignmentId` | Edit project assignment |
| `/teacher/courses/assignments/project/submissions/:courseId/:assignmentId` | Project submissions |
| `/teacher/courses/assignments/project/review/:courseId/:assignmentId/:studentId` | Project review |
| `/teacher/courses/grand-tests/:courseId` | Grand tests list |
| `/teacher/courses/grand-tests/create/:courseId` | Create grand test |
| `/teacher/courses/grand-tests/edit/:courseId/:grandTestId` | Edit grand test |
| `/teacher/courses/grand-tests/eligibility/:courseId/:grandTestId` | Grand test eligibility |
| `/teacher/courses/grand-tests/attempts/:courseId/:grandTestId` | Grand test attempts |
| `/teacher/certificates/:courseId` | Certificate management |
| `/teacher/certificates/eligible/:courseId` | Eligible students |
| `/teacher/analytics/students` | Student progress |
| `/teacher/analytics/students/:studentId` | Student progress detail |

#### Profile Paths

| Path | Destination |
|------|-------------|
| `/profile/student` | Student profile |
| `/profile/student/edit` | Edit student profile |
| `/profile/teacher` | Teacher profile |
| `/profile/teacher/edit` | Edit teacher profile |
| `/profile/freelancer` | Freelancer profile |
| `/profile/freelancer/edit` | Edit freelancer profile |
| `/profile/company` | Company profile |
| `/profile/company/edit` | Edit company profile |
| `/settings/security` | Security settings |
| `/profile/security/setup-pin` | PIN setup |
| `/profile/security/change-pin` | PIN change |
| `/profile/security/disable-pin` | PIN disable |
| `/settings/profile/personal` | Personal information |
| `/settings/profile/professional` | Professional information |
| `/settings/profile/portfolio` | Skills & portfolio |
| `/settings/profile/preferences` | Preferences |
| `/settings/profile/notifications` | Notification settings |
| `/settings/profile/account` | Account settings |

#### Admin Paths

| Path | Destination |
|------|-------------|
| `/admin/users` | User management |
| `/admin/admins` | Admin management |
| `/admin/recovery` | Admin recovery |
| `/admin/verification` | Verification center |
| `/admin/settings` | Platform settings |
| `/admin/settings/theme` | Theme settings |
| `/admin/settings/motion` | Motion settings |
| `/admin/settings/language` | Language settings |
| `/admin/audit-logs` | Audit logs |

#### Job & Interview Paths

| Path | Destination |
|------|-------------|
| `/jobs` | Job listings |
| `/jobs/detail/:id` | Job detail |
| `/jobs/create` | Create job |
| `/jobs/edit/:id` | Edit job |
| `/company-jobs` | Company's jobs |
| `/company/hiring` | Hiring pipeline |
| `/company/jobs/:jobId/pipeline` | Job-specific pipeline |
| `/company/interviews/schedule/:applicationId` | Schedule interview |
| `/company/interviews/detail/:interviewId` | Interview detail |
| `/company/interviews/evaluate/:interviewId` | Evaluate interview |
| `/my-applications` | My applications |
| `/job-applicants/:id` | Job applicants |
| `/my-interviews` | My interviews |
| `/my-interviews/detail/:interviewId` | My interview detail |

---

## 9. Provider Architecture

### 9.1 — Global Providers (`lib/providers/`)

#### Core Infrastructure

| Provider File | Purpose |
|---------------|---------|
| `firebase_providers.dart` | Firebase instance providers (`FirebaseAuth`, `FirebaseFirestore`) |
| `repository_providers.dart` | Repository instance providers |
| `auth_provider.dart` | Authentication state management |
| `user_provider.dart` | Current user state (Firestore user document) |
| `theme_provider.dart` | Theme mode management (dark/light/system) |
| `app_lock_provider.dart` | App lock (PIN/biometric) state |
| `dashboard_provider.dart` | Dashboard data orchestration |
| `profile_provider.dart` | Profile data management |
| `profile_image_provider.dart` | Profile image upload/management |

#### Role-Specific Providers

| Provider File | Purpose |
|---------------|---------|
| `student_provider.dart` | Student-specific data and operations |
| `teacher_provider.dart` | Teacher-specific data and operations |
| `company_provider.dart` | Company-specific data and operations |
| `freelancer_provider.dart` | Freelancer-specific data and operations |
| `admin_provider.dart` | Admin operations (user management, verification, settings) |

#### Entity Providers

| Provider File | Purpose |
|---------------|---------|
| `job_provider.dart` | Job CRUD and listing |
| `interview_provider.dart` | Interview scheduling and management |
| `application_provider.dart` | Application submission and tracking |
| `job_matching_provider.dart` | AI-powered job matching |

### 9.2 — Feature-Local Providers

#### Courses Feature (`lib/features/courses/providers/`)

| Provider File | Purpose |
|---------------|---------|
| `course_provider.dart` | Course CRUD operations |
| `lesson_provider.dart` | Lesson management |
| `enrollment_provider.dart` | Course enrollment |
| `assignment_provider.dart` | Assignment management |
| `grand_test_provider.dart` | Grand test management |
| `certificate_provider.dart` | Certificate operations |
| `skill_score_provider.dart` | Skill score calculations |
| `resume_provider.dart` | Smart resume generation |

#### Settings Feature (`lib/features/settings/providers/`)

| Provider File | Purpose |
|---------------|---------|
| `settings_providers.dart` | Settings state management |
| `language_provider.dart` | Language/locale management |

---

## 10. Repository Layer

### 10.1 — Global Repositories (`lib/repositories/`)

Each repository follows an interface + implementation pattern.

| Repository | Interface | Implementation | Purpose |
|------------|-----------|----------------|---------|
| Auth | `auth_repository.dart` | `auth_repository_impl.dart` | Firebase Auth operations |
| User | `user_repository.dart` | `user_repository_impl.dart` | User document CRUD |
| Student | `student_repository.dart` | `student_repository_impl.dart` | Student profile operations |
| Teacher | `teacher_repository.dart` | `teacher_repository_impl.dart` | Teacher profile operations |
| Company | `company_repository.dart` | `company_repository_impl.dart` | Company profile operations |
| Freelancer | `freelancer_repository.dart` | `freelancer_repository_impl.dart` | Freelancer profile operations |
| Admin | `admin_repository.dart` | `admin_repository_impl.dart` | Admin operations |
| Job | `job_repository.dart` | `job_repository_impl.dart` | Job CRUD |
| Interview | `interview_repository.dart` | `interview_repository_impl.dart` | Interview operations |
| Application | `application_repository.dart` | `application_repository_impl.dart` | Application operations |

### 10.2 — Feature-Local Repositories (`lib/features/courses/data/repositories/`)

| Repository | Purpose |
|------------|---------|
| `course_repository.dart` | Course CRUD operations |
| `lesson_repository.dart` | Lesson CRUD operations |
| `enrollment_repository.dart` | Enrollment management |
| `assignment_repository.dart` | Assignment CRUD operations |
| `grand_test_repository.dart` | Grand test operations |
| `certificate_repository.dart` | Certificate operations |

### 10.3 — Feature-Local Repositories (Settings)

| Repository | Path | Purpose |
|------------|------|---------|
| `settings_repository.dart` | `features/settings/data/repositories/` | Settings interface |
| `settings_repository_impl.dart` | `features/settings/data/repositories/` | Settings implementation |

---

## 11. Model Layer

### 11.1 — Global Models (`lib/models/`)

| Model | File | Purpose |
|-------|------|---------|
| `UserModel` | `user_model.dart` | Core user document (shared by all features) |
| `UserRole` | `user_role.dart` | User role enum |
| `StudentModel` | `student_model.dart` | Student profile data |
| `TeacherModel` | `teacher_model.dart` | Teacher profile data |
| `CompanyModel` | `company_model.dart` | Company profile data |
| `FreelancerModel` | `freelancer_model.dart` | Freelancer profile data |
| `AdminModel` | `admin_model.dart` | Admin data |
| `JobModel` | `job_model.dart` | Job posting data |
| `JobMatchModel` | `job_match_model.dart` | Job matching results |
| `InterviewModel` | `interview_model.dart` | Interview data |
| `ApplicationModel` | `application_model.dart` | Job application data |
| `AuditLog` | `audit_log.dart` | Audit trail entries |
| `PlatformSettings` | `platform_settings.dart` | Platform configuration |
| `PlatformStats` | `platform_stats.dart` | Platform statistics |
| `VerificationRequest` | `verification_request.dart` | User verification requests |

### 11.2 — Course Feature Models (`lib/features/courses/data/models/`)

| Model | File | Purpose |
|-------|------|---------|
| `CourseModel` | `course_model.dart` | Course data |
| `LessonModel` | `lesson_model.dart` | Lesson data |
| `EnrollmentModel` | `enrollment_model.dart` | Enrollment records |
| `McqAssignmentModel` | `mcq_assignment_model.dart` | MCQ assignment definition |
| `McqAttemptModel` | `mcq_attempt_model.dart` | MCQ attempt data |
| `ProjectAssignmentModel` | `project_assignment_model.dart` | Project assignment definition |
| `ProjectSubmissionModel` | `project_submission_model.dart` | Project submission data |
| `GrandTestModel` | `grand_test_model.dart` | Grand test definition |
| `GrandTestAttemptModel` | `grand_test_attempt_model.dart` | Grand test attempt data |
| `GrandTestEligibilityModel` | `grand_test_eligibility_model.dart` | Grand test eligibility data |
| `CertificateModel` | `certificate_model.dart` | Certificate data |
| `SkillScoreModel` | `skill_score_model.dart` | Skill score data |
| `SmartResumeModel` | `smart_resume_model.dart` | Smart resume data |

### 11.3 — Settings Feature Models (`lib/features/settings/data/models/`)

| Model | File | Purpose |
|-------|------|---------|
| `ThemeSettingsModel` | `theme_settings_model.dart` | Theme preferences |
| `MotionSettingsModel` | `motion_settings_model.dart` | Animation preferences |
| `LanguageSettingsModel` | `language_settings_model.dart` | Language/locale preferences |

---

## 12. Services Layer

### 12.1 — Core Services (`lib/core/services/`)

| Service | File | Purpose |
|---------|------|---------|
| `AppLockService` | `app_lock_service.dart` | PIN storage, validation, and app lock management |
| `BiometricService` | `biometric_service.dart` | Biometric authentication (fingerprint/face) |
| `CloudinaryService` | `cloudinary_service.dart` | Image upload to Cloudinary |

### 12.2 — Feature-Local Services

#### Courses (`lib/features/courses/data/services/`)

| Service | File | Purpose |
|---------|------|---------|
| `SkillScoreService` | `skill_score_service.dart` | Skill score calculation logic |
| `ResumeIntelligenceService` | `resume_intelligence_service.dart` | Smart resume generation logic |

#### Jobs (`lib/features/jobs/services/`)

| Service | File | Purpose |
|---------|------|---------|
| `JobMatchingService` | `job_matching_service.dart` | Job matching algorithm |

### 12.3 — Core Utilities (`lib/core/utils/`)

| Utility | File | Purpose |
|---------|------|---------|
| `ProfileCompletion` | `profile_completion.dart` | Profile completion percentage calculation |
| `Validators` | `validators.dart` | Input validation (email, password, name, phone) |

### 12.4 — Core Configuration (`lib/core/config/`)

| Config | File | Purpose |
|--------|------|---------|
| `CloudinaryConfig` | `cloudinary_config.dart` | Cloudinary API configuration |

---

## 13. Theme System

### 13.1 — File Map

| File | Path | Purpose |
|------|------|---------|
| `app_colors.dart` | `lib/core/theme/app_colors.dart` | All color constants (131 lines) |
| `app_theme.dart` | `lib/core/theme/app_theme.dart` | `ThemeData` assembly for dark and light modes |
| `app_typography.dart` | `lib/core/theme/app_typography.dart` | `TextTheme` from Google Fonts (130 lines) |

### 13.2 — Theme Switching

- Provider: `lib/providers/theme_provider.dart`
- Widget: `lib/shared/widgets/animated_theme_switcher.dart`
- Admin control: `lib/features/admin/presentation/admin_theme_settings_screen.dart`

### 13.3 — Color Architecture

The color system is organized into:

1. **Primary / Secondary / Accent palettes** — Brand identity
2. **Dark theme surface and text colors** — Dark mode UI
3. **Light theme surface and text colors** — Light mode UI
4. **Semantic colors** — Success, warning, error, info
5. **Role-specific colors** — Student (blue), Teacher (purple), Freelancer (cyan), Company (green)
6. **Gradients** — Reusable `LinearGradient` presets
7. **Overlays and shimmer** — Loading and modal support

---

## 14. Dashboard System

### 14.1 — Dashboard Composition Pattern

Every role dashboard is composed from shared widget components:

| Layer | Widget | Purpose |
|-------|--------|---------|
| Shell | `DashboardShell` | Top-level scaffold with padding, scroll, and safe area |
| Header | `DashboardHeader` | Greeting, avatar, role badge, theme switcher |
| Metrics | `MetricCard` | Key performance indicators (course count, job count, etc.) |
| Content | `DashboardSection` | Titled grouped content area |
| Activity | `RecentActivityCard` | Recent activity feed items |
| Actions | `QuickActionCard` | Shortcut action tiles |
| Empty | `DashboardEmptyState` | Placeholder for empty sections |
| Profile | `ProfileCompletionCard` | Profile completion progress |

### 14.2 — Dashboard File Index

| Dashboard | File Path | Role Color |
|-----------|-----------|------------|
| Student | `lib/features/student/presentation/student_dashboard.dart` | `studentPrimary` (#5B7CFF) |
| Teacher | `lib/features/teacher/presentation/teacher_dashboard.dart` | `teacherPrimary` (#8A5CFF) |
| Company | `lib/features/company/presentation/company_dashboard.dart` | `companyPrimary` (#00E676) |
| Freelancer | `lib/features/freelancer/presentation/freelancer_dashboard.dart` | `freelancerPrimary` (#00D1FF) |
| Admin | `lib/features/admin/presentation/admin_dashboard.dart` | Platform primary |
| Super Admin | `lib/features/admin/presentation/super_admin_dashboard.dart` | Platform primary |

---

## 15. Screen Inventory

### 15.1 — Complete Screen Count by Feature

| Feature | Screen Count | Screens |
|---------|:----:|---------|
| **Auth** | 4 | `login_screen`, `signup_screen`, `forgot_password_screen`, `account_blocked_screen` |
| **Onboarding** | 3 | `splash_screen`, `app_onboarding_screen`, `role_selection_screen` |
| **Student** | 4 | `student_dashboard`, `student_profile_screen`, `student_edit_profile_screen`, `student_onboarding_screen` |
| **Teacher** | 4 | `teacher_dashboard`, `teacher_profile_screen`, `teacher_edit_profile_screen`, `teacher_onboarding_screen` |
| **Company** | 4 | `company_dashboard`, `company_profile_screen`, `company_edit_profile_screen`, `company_onboarding_screen` |
| **Freelancer** | 4 | `freelancer_dashboard`, `freelancer_profile_screen`, `freelancer_edit_profile_screen`, `freelancer_onboarding_screen` |
| **Admin** | 13 | `admin_dashboard`, `super_admin_dashboard`, `user_management_screen`, `admin_user_management_screen`, `admin_management_screen`, `audit_logs_screen`, `platform_settings_screen`, `admin_platform_settings_screen`, `verification_center_screen`, `admin_recovery_screen`, `admin_theme_settings_screen`, `admin_motion_settings_screen`, `admin_language_settings_screen` |
| **Courses** | 28 | See Section 7.1 and 7.2 for full list |
| **Jobs** | 4 | `job_list_screen`, `job_detail_screen`, `create_edit_job_screen`, `company_jobs_screen` |
| **Interviews** | 5 | `my_interviews_screen`, `interview_detail_screen`, `schedule_interview_screen`, `candidate_evaluation_screen`, `hiring_pipeline_screen` |
| **Applications** | 2 | `my_applications_screen`, `job_applicants_screen` |
| **Profile** | 7 | `personal_information_screen`, `professional_information_screen`, `skills_portfolio_screen`, `account_settings_screen`, `notification_settings_screen`, `preference_settings_screen`, `security_settings_screen` |
| **Security** | 2 | `app_lock_screen`, `pin_management_screen` |
| **Legal** | 3 | `privacy_policy_screen`, `terms_of_service_screen`, `account_deletion_policy_screen` |
| **Home** | 1 | `home_screen` |
| **System** | 1 | `maintenance_screen` |

### 15.2 — Total Counts

| Category | Count |
|----------|:-----:|
| Feature Modules | 17 |
| Presentation Screens | ~89 |
| Global Models | 15 |
| Feature-Local Models | 16 |
| Global Repositories | 10 (20 files with impls) |
| Feature-Local Repositories | 6 |
| Global Providers | 16 |
| Feature-Local Providers | 10 |
| Shared Widgets | 17 |
| LMS UI Widgets | 10 |
| Named Routes | 126 |
| Core Services | 3 |
| Feature Services | 3 |

---

> **End of Project Manual**
>
> This document reflects the current state of the SkillForge AI project as verified from the repository. All file paths, route names, provider names, and model names are extracted directly from the codebase. No information was invented or assumed.
