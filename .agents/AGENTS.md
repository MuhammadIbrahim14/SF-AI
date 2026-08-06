# Project Overview

**Vision**
SkillForge AI is a premium, next-generation platform integrating professional learning, freelancing, and service marketplaces into a single seamless experience. The goal is to provide a world-class, dynamic, and visually stunning SaaS application that empowers students, teachers, companies, and freelancers.

**Architecture Philosophy**
The architecture is designed for scale, maintainability, and clear separation of concerns. We strictly adhere to feature-first directory structures, immutable state, and reactive UI patterns. We prioritize reusing existing patterns over inventing new ones.

**Repository Purpose**
This repository houses the entire SkillForge AI client application, encompassing complex routing, multiple user roles, a unified design system, and deep Firebase integrations. It is intended to be a robust, enterprise-grade codebase.

---

# Core Principles

* **Never break existing features:** Regressions are unacceptable. Always test the impact of your changes on adjacent systems.
* **Backward compatibility first:** If you modify a shared component or provider, ensure all existing consumers remain fully functional.
* **Production-ready code:** Write code as if it will be deployed to millions of users today. No shortcuts, no "TODOs" without explicit user approval.
* **Material 3 compliance:** Strictly adhere to the Flutter Material 3 design language.
* **Mobile-first responsive design:** Every screen must flawlessly adapt from mobile phones up to large desktop monitors.
* **Reuse existing architecture before creating new components:** Always search the codebase for an existing widget, provider, or repository that achieves the goal before building a new one from scratch.

---

# Coding Standards

* **Naming conventions:** Use `camelCase` for variables/methods, `PascalCase` for classes/enums, and `snake_case` for file/directory names.
* **Folder structure:** Strictly feature-first (`lib/features/feature_name/`). Shared resources belong in `lib/shared/` or `lib/core/`.
* **Feature-first architecture:** Group by feature, not by layer. Inside a feature, use `presentation`, `providers`, and `domain` (if needed) subdirectories.
* **Riverpod usage:** Use Riverpod exclusively for state management. Avoid `StatefulWidget` where a `ConsumerWidget` + `Notifier` can cleanly handle state. Use `AsyncNotifier` for async state.
* **Repository pattern:** All data fetching and external API/Firebase calls must go through a Repository class (`feature_repository.dart` and `feature_repository_impl.dart`).
* **Model conventions:** Place data models in `lib/models/`. Always implement `fromFirestore` and `toMap` (or `toJson`/`fromJson`).
* **Null safety:** Strictly enforce sound null safety. Avoid the `!` operator unless absolute certainty exists; prefer safe unwrapping or fallback values.
* **Immutable models where appropriate:** Use `copyWith` methods for state mutation. Models should be highly immutable.

---

# UI Rules

* **Frozen design system:** The core UI system (`AppColors`, `AppTypography`, `AppTheme`) is locked. Do not introduce raw hex codes or random styling tweaks.
* **Material 3 only:** Leverage modern Material 3 widgets (`FilledButton`, `Card.filled`, `NavigationBar`, etc.).
* **Use shared widgets first:** Before building a button, empty state, or header, check `lib/shared/widgets/`.
* **Avoid hardcoded colors:** Always use `Theme.of(context).colorScheme.something`.
* **Responsive breakpoints:** Use layout builders or existing responsive wrappers (like `ResponsiveLayout`) to handle Mobile (<600px), Tablet (600px–900px), and Desktop (>900px).
* **SafeArea compliance:** Ensure content is never obscured by device notches, status bars, or home indicators. Wrap root body elements in `SafeArea`.
* **Accessibility:** Ensure sufficient contrast, tap target sizes (min 48x48), and proper semantics where necessary.
* **Empty states:** Always provide a premium empty state (using `DashboardEmptyState` or similar) when lists or data are empty.
* **Skeleton loading:** Prefer shimmer/skeleton loading states over basic `CircularProgressIndicator` for complex data fetches.
* **Error states:** Always handle errors gracefully with user-friendly messages and retry actions.

---

# Flutter Rules

* **Preferred widgets:** Use `CustomScrollView` and `Slivers` for complex scrollable layouts. Use `Wrap` for dynamic chips.
* **State management rules:** Keep UI declarative. Business logic lives in Riverpod Notifiers, not inside the `build` method.
* **Navigation rules:** Use `go_router`. Pass IDs as path parameters. Avoid passing complex objects through routing arguments.
* **Responsive rules:** Never assume screen width. Fluidly adjust columns and spacing using `LayoutBuilder` or `MediaQuery`.
* **Animation rules:** Use subtle micro-animations (e.g., `AnimatedContainer`, `Hero`, `FadeIn`) to make the interface feel alive and premium.
* **Performance guidelines:** Use `const` constructors everywhere possible. Avoid deep widget trees. Do not put heavy computations in the `build` method.

---

# Firebase Rules

* **Never change schema without approval:** The Firestore structure is tightly coupled. Propose schema changes in a plan and await explicit approval before modifying.
* **Keep security rules safe:** Assume all client actions will be validated by Firestore rules.
* **Avoid duplicate writes:** Use batching (`WriteBatch`) when updating multiple dependent documents to ensure consistency.
* **Repository ownership:** UI components should never import Firebase SDKs directly. All Firebase interaction must be encapsulated inside Repositories.
* **Firestore transaction guidance:** Use transactions (`FirebaseFirestore.instance.runTransaction`) for operations requiring read-modify-write atomicity (e.g., updating balances, decrementing inventory).

---

# Routing Rules

* **GoRouter conventions:** All routing logic lives in `lib/app/router/app_router.dart` and `route_names.dart`.
* **Public routes:** Routes that do not require authentication (e.g., `/login`, `/signup`, `/services`).
* **Professional routes:** Prefixed by role (e.g., `/student/*`, `/teacher/*`, `/freelancer/*`). Strictly guarded to prevent cross-role access.
* **Customer Workspace:** Located at `/dashboard/customer`. Customers bypass role selection and professional dashboards.
* **Admin routes:** Strictly protected. Accessible only to `accountType == admin`.

---

# Feature Development Rules

* **Analyze before coding:** Read existing implementations of similar features before writing new code.
* **Preserve existing logic:** When adding a feature, do not inadvertently delete or disable existing validations or workflows.
* **Extend rather than rewrite:** If an existing widget ALMOST does what you need, extend it with optional parameters rather than creating a duplicate.
* **Keep changes localized:** Touch only the files necessary to complete the task. Minimize blast radius.

---

# Testing Rules

* **`flutter analyze`:** Code must pass `flutter analyze` with 0 issues before considering a task complete.
* **Build validation:** Ensure the app compiles successfully without syntax or type errors.
* **Navigation validation:** Verify that routing guards, redirects, and back-button behaviors work logically.
* **Responsive QA:** Test layouts mentally (or via tools) against mobile and desktop constraints.
* **Edge cases:** Actively look for and handle null data, network failures, and unauthorized access scenarios.

---

# Prompt Execution Rules

Every implementation should:

1. **Analyze existing code**: Use `grep_search` and `view_file` to thoroughly map dependencies before touching files.
2. **Reuse existing architecture**: Piggyback on established Providers, Shells, and Repositories.
3. **Implement fully**: Do not leave partial implementations or `// TODO: implement later` comments.
4. **Fix introduced errors**: If your changes introduce linter errors or break existing dependencies, fix them immediately.
5. **Run analyzer/build if possible**: Always run `flutter analyze` after complex changes.
6. **Return changed files only**: Keep tool usage focused. Do not modify files unnecessarily.

---

# Things Never To Do

* **Don't redesign frozen UI:** Do not alter established visual languages without explicit instructions.
* **Don't replace providers unnecessarily:** If a `FutureProvider` works, don't randomly upgrade it to an `AsyncNotifier` unless required by the task.
* **Don't duplicate widgets:** Do not create `CustomButton2` when `CustomButton` exists.
* **Don't add packages without approval:** Standardize on current dependencies. Adding a package introduces maintenance debt.
* **Don't modify Firebase schema without approval:** Schema changes are structural and require human sign-off.
* **Don't break existing routes:** Never break deep-linking or existing navigation flows.

---

# Response Format

Every AI implementation should finish with:

* **Files changed**: A summary list of what was created or modified.
* **Analyzer result**: Confirmation that the code passes linting.
* **Remaining risks**: Highlight any potential edge cases, backward-compatibility issues, or missing tests that the user should be aware of.
